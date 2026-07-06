"""Lógica pura de detecção de instalação Windows (PROMPT-CALAMARES-MIGRACAO-WINDOWS.md §3).

Sem dependência de `libcalamares` para permitir testes unitários isolados
(ver tests/detection.test.py). O glue code que fala com o Calamares fica
em main.py, que importa este módulo.
"""

import os
import subprocess

MIN_HIBERFIL_BYTES = 1024
EXCLUDED_PROFILES_FALLBACK = ("Default", "Default User", "Public", "All Users")


class DetectionAborted(Exception):
    """BitLocker habilitado ou hibernação ativa — tratar como não-detectado (§3)."""


def list_ntfs_partitions(run=subprocess.run):
    """Retorna lista de devices com sistema de arquivos NTFS, via lsblk."""
    proc = run(
        ["lsblk", "-rno", "PATH,FSTYPE"],
        capture_output=True, text=True, check=True,
    )
    partitions = []
    for line in proc.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].lower() == "ntfs":
            partitions.append(parts[0])
    return partitions


def blkid_type(device, run=subprocess.run):
    proc = run(
        ["blkid", "-o", "value", "-s", "TYPE", device],
        capture_output=True, text=True, check=False,
    )
    return proc.stdout.strip()


def is_bitlocker(device, run=subprocess.run):
    return blkid_type(device, run=run).lower() == "bitlocker"


def mount_readonly(device, mountpoint, run=subprocess.run):
    os.makedirs(mountpoint, exist_ok=True)
    run(
        ["mount", "-t", "ntfs-3g", "-o", "ro,noload", device, mountpoint],
        check=True,
    )


def unmount(mountpoint, run=subprocess.run):
    run(["umount", mountpoint], check=False)


def has_active_hibernation(mountpoint):
    hiberfil = os.path.join(mountpoint, "hiberfil.sys")
    return os.path.exists(hiberfil) and os.path.getsize(hiberfil) >= MIN_HIBERFIL_BYTES


def is_windows_install(mountpoint):
    return os.path.isdir(os.path.join(mountpoint, "Windows", "System32"))


def list_user_profiles(mountpoint, excluded_profiles=EXCLUDED_PROFILES_FALLBACK):
    users_dir = os.path.join(mountpoint, "Users")
    if not os.path.isdir(users_dir):
        return []
    excluded_lower = {name.lower() for name in excluded_profiles}
    profiles = []
    for name in sorted(os.listdir(users_dir)):
        path = os.path.join(users_dir, name)
        if name.lower() in excluded_lower or not os.path.isdir(path):
            continue
        profiles.append(name)
    return profiles


def directory_size_bytes(path):
    """Soma o tamanho de um diretório, tolerando entradas ilegíveis (§4)."""
    total = 0
    for root, dirs, files in os.walk(path, onerror=lambda e: None):
        for filename in files:
            try:
                total += os.path.getsize(os.path.join(root, filename))
            except OSError:
                continue
    return total


def find_bookmarks_file(profile_dir, browser_candidates):
    for candidate in browser_candidates:
        path = os.path.join(profile_dir, "AppData", "Local", candidate)
        if os.path.isfile(path):
            return path
    return None


def collect_profile_items(mountpoint, profile, mapping):
    """Para um perfil, retorna a lista de itens oferecíveis com tamanho (§4).

    Só inclui na lista itens cuja origem realmente existe no perfil —
    itens ausentes não aparecem como opção desabilitada, simplesmente
    não são oferecidos.
    """
    profile_dir = os.path.join(mountpoint, "Users", profile)
    items = []
    for entry in mapping["items"]:
        if entry["kind"] == "directory":
            source_path = os.path.join(profile_dir, entry["source"])
            if not os.path.isdir(source_path):
                continue
            items.append({
                "id": entry["id"],
                "source_path": source_path,
                "dest": entry["dest"],
                "default": entry["default"],
                "kind": "directory",
                "size_bytes": directory_size_bytes(source_path),
            })
        elif entry["kind"] == "browser-bookmarks":
            bookmarks_path = find_bookmarks_file(profile_dir, entry["browser_candidates"])
            if bookmarks_path is None:
                continue
            items.append({
                "id": entry["id"],
                "source_path": bookmarks_path,
                "dest": entry["dest"],
                "default": entry["default"],
                "kind": "browser-bookmarks",
                "size_bytes": os.path.getsize(bookmarks_path),
            })
    return items


def detect(mapping, mount_root="/run/lyra-winmigrate", run=subprocess.run):
    """Executa a detecção completa (§3) e retorna o dicionário salvo em GS.

    Estrutura de retorno:
        {"found": False} — nenhuma partição Windows utilizável
        {"found": True, "device": ..., "mountpoint": ...,
         "profiles": {profile_name: [items...]}}
    """
    excluded = mapping.get("excluded_profiles", list(EXCLUDED_PROFILES_FALLBACK))

    for device in list_ntfs_partitions(run=run):
        if is_bitlocker(device, run=run):
            continue

        mountpoint = os.path.join(mount_root, os.path.basename(device))
        try:
            mount_readonly(device, mountpoint, run=run)
        except subprocess.CalledProcessError:
            continue

        if not is_windows_install(mountpoint):
            unmount(mountpoint, run=run)
            continue

        if has_active_hibernation(mountpoint):
            unmount(mountpoint, run=run)
            continue

        profiles = list_user_profiles(mountpoint, excluded)
        if not profiles:
            unmount(mountpoint, run=run)
            continue

        return {
            "found": True,
            "device": device,
            "mountpoint": mountpoint,
            "profiles": {
                profile: collect_profile_items(mountpoint, profile, mapping)
                for profile in profiles
            },
        }

    return {"found": False}
