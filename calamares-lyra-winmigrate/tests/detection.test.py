"""Testes de detecção (PROMPT-CALAMARES-MIGRACAO-WINDOWS.md §8).

Roda com `python -m unittest detection.test` (ou descoberta padrão do
unittest) a partir deste diretório. Não depende de libcalamares nem de
mount real: a chamada de `mount` é interceptada por um `run` falso, e o
"mountpoint" é um diretório temporário já populado com o conteúdo
esperado — equivalente ao efeito de montar de verdade.
"""

import os
import sys
import tempfile
import unittest
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "winmigrate-detect"))

import detection


class FakeCompletedProcess:
    def __init__(self, stdout="", returncode=0):
        self.stdout = stdout
        self.stderr = ""
        self.returncode = returncode


def make_fake_run(ntfs_devices, bitlocker_devices=()):
    """Constrói um `run` falso: lsblk lista `ntfs_devices`, blkid reporta
    BitLocker para os devices em `bitlocker_devices`, mount/umount são no-op.
    """
    def fake_run(cmd, **kwargs):
        if cmd[0] == "lsblk":
            stdout = "\n".join(f"{dev} ntfs" for dev in ntfs_devices)
            return FakeCompletedProcess(stdout=stdout)
        if cmd[0] == "blkid":
            device = cmd[-1]
            return FakeCompletedProcess(stdout="BitLocker" if device in bitlocker_devices else "ntfs")
        if cmd[0] in ("mount", "umount"):
            return FakeCompletedProcess()
        raise AssertionError(f"comando inesperado: {cmd}")
    return fake_run


DEFAULT_MAPPING = {
    "items": [
        {"id": "documents", "source": "Documents", "dest": "Documentos/Do Windows",
         "default": True, "kind": "directory"},
        {"id": "browser_bookmarks", "source": "AppData/Local", "dest": ".mozilla/firefox/__PROFILE__/x.html",
         "default": True, "kind": "browser-bookmarks",
         "browser_candidates": ["Google/Chrome/User Data/Default/Bookmarks"]},
    ],
    "excluded_profiles": ["Default", "Public", "All Users"],
}


def populate_windows_profile(mount_root, device_basename, profile_name, with_documents=True):
    mountpoint = os.path.join(mount_root, device_basename)
    os.makedirs(os.path.join(mountpoint, "Windows", "System32"), exist_ok=True)
    profile_dir = os.path.join(mountpoint, "Users", profile_name)
    os.makedirs(profile_dir, exist_ok=True)
    if with_documents:
        docs = os.path.join(profile_dir, "Documents")
        os.makedirs(docs, exist_ok=True)
        with open(os.path.join(docs, "resume.docx"), "w") as handle:
            handle.write("x" * 100)
    return mountpoint


class DetectionTests(unittest.TestCase):
    def test_no_ntfs_partition_returns_not_found(self):
        run = make_fake_run(ntfs_devices=[])
        result = detection.detect(DEFAULT_MAPPING, mount_root="/unused", run=run)
        self.assertEqual(result, {"found": False})

    def test_positive_detection_single_profile(self):
        with tempfile.TemporaryDirectory() as mount_root:
            populate_windows_profile(mount_root, "sda1", "alice")
            run = make_fake_run(ntfs_devices=["/dev/sda1"])

            result = detection.detect(DEFAULT_MAPPING, mount_root=mount_root, run=run)

            self.assertTrue(result["found"])
            self.assertEqual(list(result["profiles"]), ["alice"])
            doc_item = next(i for i in result["profiles"]["alice"] if i["id"] == "documents")
            self.assertEqual(doc_item["size_bytes"], 100)

    def test_multiple_profiles_excludes_system_profiles(self):
        with tempfile.TemporaryDirectory() as mount_root:
            mountpoint = populate_windows_profile(mount_root, "sda1", "alice")
            os.makedirs(os.path.join(mountpoint, "Users", "bob", "Documents"), exist_ok=True)
            os.makedirs(os.path.join(mountpoint, "Users", "Public"), exist_ok=True)
            os.makedirs(os.path.join(mountpoint, "Users", "Default"), exist_ok=True)
            run = make_fake_run(ntfs_devices=["/dev/sda1"])

            result = detection.detect(DEFAULT_MAPPING, mount_root=mount_root, run=run)

            self.assertEqual(sorted(result["profiles"]), ["alice", "bob"])

    def test_bitlocker_treated_as_not_detected(self):
        with tempfile.TemporaryDirectory() as mount_root:
            populate_windows_profile(mount_root, "sda1", "alice")
            run = make_fake_run(ntfs_devices=["/dev/sda1"], bitlocker_devices=["/dev/sda1"])

            result = detection.detect(DEFAULT_MAPPING, mount_root=mount_root, run=run)

            self.assertEqual(result, {"found": False})

    def test_active_hibernation_treated_as_not_detected(self):
        with tempfile.TemporaryDirectory() as mount_root:
            mountpoint = populate_windows_profile(mount_root, "sda1", "alice")
            with open(os.path.join(mountpoint, "hiberfil.sys"), "wb") as handle:
                handle.write(b"\x00" * 2048)
            run = make_fake_run(ntfs_devices=["/dev/sda1"])

            result = detection.detect(DEFAULT_MAPPING, mount_root=mount_root, run=run)

            self.assertEqual(result, {"found": False})

    def test_empty_hiberfil_does_not_abort(self):
        with tempfile.TemporaryDirectory() as mount_root:
            mountpoint = populate_windows_profile(mount_root, "sda1", "alice")
            open(os.path.join(mountpoint, "hiberfil.sys"), "wb").close()
            run = make_fake_run(ntfs_devices=["/dev/sda1"])

            result = detection.detect(DEFAULT_MAPPING, mount_root=mount_root, run=run)

            self.assertTrue(result["found"])

    def test_no_user_profiles_treated_as_not_detected(self):
        with tempfile.TemporaryDirectory() as mount_root:
            mountpoint = os.path.join(mount_root, "sda1")
            os.makedirs(os.path.join(mountpoint, "Windows", "System32"), exist_ok=True)
            run = make_fake_run(ntfs_devices=["/dev/sda1"])

            result = detection.detect(DEFAULT_MAPPING, mount_root=mount_root, run=run)

            self.assertEqual(result, {"found": False})

    def test_missing_source_folder_not_offered(self):
        with tempfile.TemporaryDirectory() as mount_root:
            populate_windows_profile(mount_root, "sda1", "alice", with_documents=False)
            run = make_fake_run(ntfs_devices=["/dev/sda1"])

            result = detection.detect(DEFAULT_MAPPING, mount_root=mount_root, run=run)

            ids = [item["id"] for item in result["profiles"]["alice"]]
            self.assertNotIn("documents", ids)


if __name__ == "__main__":
    unittest.main()
