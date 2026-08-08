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

    def test_project_paths_are_ordered_and_standard_is_the_only_gate(self) -> None:
        metadata = ET.fromstring(image_build.project_meta(self.manifest))
        repository = metadata.find("repository")
        assert repository is not None
        paths = [(node.attrib["project"], node.attrib["repository"]) for node in repository.findall("path")]
        self.assertEqual(paths[0][0], "home:rodrigosbrito:lyra")
        self.assertEqual(paths[-1][0], "Virtualization:Appliances:Builder")
        self.assertEqual(self.manifest.required_flavor, "standard")
        self.assertIn("nvidia", self.manifest.optional_flavors)

    def test_project_prefers_the_live_module_from_the_kiwi_repository(self) -> None:
        config = image_build.project_config()
        self.assertIn("Prefer: dracut-kiwi-live\n", config)
        self.assertIn("Support: dracut-kiwi-live\n", config)

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
            flavors = [node.text for node in ET.parse(destination / "_multibuild").getroot()]
            self.assertEqual(flavors, ["standard"])
            source = json.loads((destination / "build-source.json").read_text(encoding="utf-8"))
            self.assertRegex(source["commit"], r"^[0-9a-f]{40}$")
            self.assertFalse(source["dirty"])

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

    def test_obs_project_uses_static_image_links(self) -> None:
        config = image_build.project_config()
        self.assertIn("Type: kiwi\n", config)
        self.assertIn("Repotype: staticlinks\n", config)
        self.assertIn("Prefer: plymouth-branding-openSUSE\n", config)
        self.assertIn("Prefer: MozillaFirefox-branding-openSUSE\n", config)


class ArtifactTests(unittest.TestCase):
    def test_manifest_hashes_all_evidence_and_records_exact_package_sources(self) -> None:
        manifest = image_build.Manifest.load()
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "lyra.iso").write_bytes(b"iso")
            (directory / "lyra.packages").write_text(
                "fina|(none)|0.4.0|12.1|x86_64|obs://build.opensuse.org/"
                "home:rodrigosbrito:fina/repo/revision-fina|MIT|MIT\n",
                encoding="utf-8",
            )
            (directory / "lyra.verified").write_text("verified\n", encoding="utf-8")
            (directory / "lyra.changes").write_text("changes\n", encoding="utf-8")
            (directory / "kiwi.result.json").write_text("{}\n", encoding="utf-8")
            test_result = directory / "smoke.json"
            test_result.write_text('{"result":"pass"}\n', encoding="utf-8")
            output = directory / "manifest.json"
            image_build.artifact_manifest(
                manifest, directory, output, [f"smoke={test_result}"]
            )
            document = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(set(document["artifacts"]), set(manifest.required_artifacts))
            self.assertEqual(document["packages"][0]["source_package"], "MIT")
            self.assertIn("revision-fina", document["packages"][0]["source"])
            self.assertIn("smoke", document["test_results"])


if __name__ == "__main__":
    unittest.main()
