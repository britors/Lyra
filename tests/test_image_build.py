from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("lyra_image_build", ROOT / "scripts/image-build.py")
assert SPEC and SPEC.loader
image_build = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = image_build
SPEC.loader.exec_module(image_build)


class ImagePolicyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = image_build.Manifest.load()

    def test_canonical_sources_pass_repository_and_signature_policy(self) -> None:
        image_build.validate_sources(self.manifest)

    def test_obs_is_restricted_to_ordered_rpm_package_sources(self) -> None:
        self.assertEqual(self.manifest.obs_role, "packages-only")
        projects = [source.project for source in self.manifest.package_sources]
        self.assertEqual(projects[0], "home:rodrigosbrito:lyra")
        self.assertEqual(projects[-1], "Virtualization:Appliances:Builder")
        self.assertFalse(hasattr(self.manifest, "project"))
        self.assertFalse(hasattr(self.manifest, "package"))

    def test_distribution_policy_uses_github_and_sourceforge(self) -> None:
        self.assertEqual(self.manifest.source_repository, "https://github.com/britors/Lyra")
        self.assertEqual(self.manifest.iso_provider, "sourceforge")
        help_text = image_build.parser().format_help()
        self.assertNotIn("publish", help_text)
        self.assertNotIn("check-remote", help_text)

    def test_manifest_rejects_an_obs_image_publication_target(self) -> None:
        source = (ROOT / "image-build.toml").read_text(encoding="utf-8")
        source = source.replace(
            'role = "packages-only"',
            'project = "home:rodrigosbrito:lyra:images"\nrole = "packages-only"',
        )
        with tempfile.TemporaryDirectory() as temporary:
            manifest = Path(temporary) / "image-build.toml"
            manifest.write_text(source, encoding="utf-8")
            with self.assertRaisesRegex(image_build.PolicyError, "publication targets"):
                image_build.Manifest.load(manifest)

    def test_live_module_is_part_of_the_installed_image(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        image_packages = root.find("packages[@type='image']")
        assert image_packages is not None
        self.assertIsNotNone(image_packages.find("package[@name='dracut-kiwi-live']"))
        self.assertIsNone(root.find("packages[@type='iso']/package[@name='dracut-kiwi-live']"))

    def test_beta_two_uses_only_the_rust_installer(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        packages = {node.attrib["name"] for node in root.findall("packages/package")}
        self.assertIn("lyra-installer", packages)
        self.assertNotIn("calamares", packages)
        self.assertFalse((ROOT / "kiwi/root/etc/calamares").exists())
        self.assertFalse(
            (ROOT / "kiwi/root/usr/share/applications/calamares.desktop").exists()
        )

        autostart = (
            ROOT / "kiwi/root/etc/xdg/autostart/lyra-installer-autostart.desktop"
        ).read_text(encoding="utf-8")
        self.assertIn("TryExec=/usr/bin/lyra-installer", autostart)
        self.assertIn("Exec=/usr/bin/lyra-install-lock /usr/bin/lyra-installer", autostart)
        self.assertNotIn("pkexec", autostart)

        packaged_wrapper = ROOT / "installer/packaging/lyra-install-lock"
        image_wrapper = ROOT / "kiwi/root/usr/bin/lyra-install-lock"
        self.assertEqual(image_wrapper.read_bytes(), packaged_wrapper.read_bytes())
        wrapper = image_wrapper.read_text(encoding="utf-8")
        self.assertIn("XDG_RUNTIME_DIR", wrapper)
        self.assertNotIn("/run/lock/lyra-install.lock", wrapper)
        self.assertNotEqual(image_wrapper.stat().st_mode & 0o111, 0)

        packaged_launcher = ROOT / "installer/packaging/org.lyraos.LyraInstaller.desktop"
        image_launcher = (
            ROOT
            / "kiwi/root/usr/share/applications/org.lyraos.LyraInstaller.desktop"
        )
        self.assertEqual(image_launcher.read_bytes(), packaged_launcher.read_bytes())

        packaged_icon = ROOT / "installer/src-tauri/icons/256x256.png"
        image_icon = (
            ROOT
            / "kiwi/root/usr/share/icons/hicolor/256x256/apps"
            / "org.lyraos.LyraInstaller.png"
        )
        self.assertEqual(image_icon.read_bytes(), packaged_icon.read_bytes())

    def test_export_is_derived_from_canonical_kiwi_without_duplicate_package_list(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "export"
            real_git = image_build.git
            with mock.patch.object(
                image_build,
                "git",
                side_effect=lambda *args: "" if args[0] == "status" else real_git(*args),
            ):
                image_build.export(self.manifest, destination, "HEAD", allow_dirty=False)
            image_build.verify_export(self.manifest, destination)
            canonical = ET.parse(ROOT / "kiwi/config.xml").getroot()
            exported = ET.parse(destination / self.manifest.description).getroot()
            canonical_packages = [node.attrib["name"] for node in canonical.findall("packages/package")]
            exported_packages = [node.attrib["name"] for node in exported.findall("packages/package")]
            self.assertEqual(exported_packages, canonical_packages)
            self.assertFalse((destination / "_multibuild").exists())
            self.assertEqual(
                image_build.sha256(destination / "config.xml"),
                image_build.sha256(ROOT / "kiwi/config.xml"),
            )
            source = json.loads((destination / "build-source.json").read_text(encoding="utf-8"))
            self.assertRegex(source["commit"], r"^[0-9a-f]{40}$")
            self.assertFalse(source["dirty"])
            self.assertTrue((destination / "root.tar.gz").is_file())

    def test_root_archive_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            first = Path(temporary) / "first"
            second = Path(temporary) / "second"
            real_git = image_build.git
            with mock.patch.object(
                image_build,
                "git",
                side_effect=lambda *args: "" if args[0] == "status" else real_git(*args),
            ):
                image_build.export(self.manifest, first, "HEAD", allow_dirty=False)
                image_build.export(self.manifest, second, "HEAD", allow_dirty=False)
            self.assertEqual(
                image_build.sha256(first / "root.tar.gz"),
                image_build.sha256(second / "root.tar.gz"),
            )

    def test_export_refuses_nonempty_destination(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary)
            (destination / "existing").write_text("keep", encoding="utf-8")
            with self.assertRaisesRegex(image_build.PolicyError, "not empty"):
                image_build.export(self.manifest, destination, "HEAD", allow_dirty=True)

    def test_dirty_inspection_export_cannot_pass_verification(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "export"
            real_git = image_build.git
            with mock.patch.object(
                image_build,
                "git",
                side_effect=lambda *args: " M kiwi/config.xml" if args[0] == "status" else real_git(*args),
            ):
                image_build.export(self.manifest, destination, "HEAD", allow_dirty=True)
            with self.assertRaisesRegex(image_build.PolicyError, "source identity"):
                image_build.verify_export(self.manifest, destination)

class ArtifactTests(unittest.TestCase):
    def test_manifest_hashes_all_evidence_and_records_exact_package_sources(self) -> None:
        manifest = image_build.Manifest.load()
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "lyra.iso").write_bytes(b"iso")
            (directory / "lyra.packages").write_text(
                "fina|(none)|0.4.0|12.1|x86_64|obs://build.opensuse.org/"
                "home:rodrigosbrito:fina/repo/revision-fina|MIT\n",
                encoding="utf-8",
            )
            (directory / "lyra.verified").write_text("verified\n", encoding="utf-8")
            (directory / "lyra.report").write_text("<report/>\n", encoding="utf-8")
            (directory / "lyra.iso.sha256").write_text("checksum  lyra.iso\n", encoding="utf-8")
            (directory / "lyra.iso.sha256.asc").write_text("signature\n", encoding="utf-8")
            (directory / "lyra.cdx.json").write_text("{}\n", encoding="utf-8")
            (directory / "lyra.spdx.json").write_text("{}\n", encoding="utf-8")
            test_result = directory / "smoke.json"
            test_result.write_text('{"result":"pass"}\n', encoding="utf-8")
            output = directory / "manifest.json"
            image_build.artifact_manifest(
                manifest, directory, output, [f"smoke={test_result}"]
            )
            document = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(set(document["artifacts"]), set(manifest.required_artifacts))
            self.assertEqual(document["packages"][0]["license"], "MIT")
            self.assertIn("revision-fina", document["packages"][0]["source"])
            self.assertIn("smoke", document["test_results"])


if __name__ == "__main__":
    unittest.main()
