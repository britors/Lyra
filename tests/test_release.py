from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("lyra_release", ROOT / "scripts/release.py")
assert SPEC and SPEC.loader
release_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = release_module
SPEC.loader.exec_module(release_module)
Release = release_module.Release


def sample_release(**overrides: object) -> Release:
    values: dict[str, object] = {
        "calendar_version": "2026.08",
        "stage": "beta",
        "iteration": 2,
        "codename": "Odisseia",
        "codename_id": "odisseia",
        "image_name": "lyra-os",
        "architecture": "x86_64",
    }
    values.update(overrides)
    release = Release(**values)
    release.validate()
    return release


class ReleaseConventionTests(unittest.TestCase):
    def test_alpha_identifiers(self) -> None:
        release = sample_release(stage="alpha", iteration=3)
        self.assertEqual(release.version_id, "2026.08-alpha3")
        self.assertEqual(release.tag, "v2026.08-alpha3")
        self.assertEqual(release.iso_filename, "lyra-os.x86_64-2026.08-alpha3.iso")
        self.assertEqual(release.volume_id, "LYRA_OS_2026_08_ALPHA3")
        self.assertEqual(release.pretty_name, "Lyra OS Alpha 3 (Odisseia)")

    def test_beta_identifiers(self) -> None:
        release = sample_release()
        self.assertEqual(release.version_id, "2026.08-beta2")
        self.assertEqual(release.tag, "v2026.08-beta2")
        self.assertEqual(release.iso_filename, "lyra-os.x86_64-2026.08-beta2.iso")
        self.assertEqual(release.volume_id, "LYRA_OS_2026_08_BETA2")
        self.assertEqual(release.pretty_name, "Lyra OS Beta 2 (Odisseia)")

    def test_rc_identifiers(self) -> None:
        release = sample_release(stage="rc", iteration=1)
        self.assertEqual(release.version_id, "2026.08-rc1")
        self.assertEqual(release.stage_label, "RC 1")

    def test_final_identifiers(self) -> None:
        release = sample_release(stage="release", iteration=0)
        self.assertEqual(release.version_id, "2026.08")
        self.assertEqual(release.tag, "v2026.08")
        self.assertEqual(release.pretty_name, "Lyra OS 2026.08 (Odisseia)")

    def test_prerelease_requires_iteration(self) -> None:
        with self.assertRaisesRegex(ValueError, "positive iteration"):
            sample_release(iteration=0)

    def test_final_rejects_iteration(self) -> None:
        with self.assertRaisesRegex(ValueError, "iteration = 0"):
            sample_release(stage="release", iteration=1)

    def test_iteration_must_be_an_integer(self) -> None:
        with self.assertRaisesRegex(ValueError, "must be an integer"):
            sample_release(iteration="2")


class RepositoryMetadataTests(unittest.TestCase):
    def test_generated_files_are_current(self) -> None:
        release = Release.from_file()
        for path, expected in release_module.render_files(release).items():
            self.assertTrue(path.exists(), path)
            self.assertEqual(path.read_text(encoding="utf-8"), expected, path)

    def test_build_manifest_is_traceable(self) -> None:
        release = Release.from_file()
        with tempfile.TemporaryDirectory() as directory:
            iso = Path(directory) / release.iso_filename
            iso.write_bytes(b"test ISO payload")
            output = Path(directory) / "build.json"
            self.assertEqual(release_module.write_build_manifest(release, iso, output), 0)
            document = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(document["version"], release.version_id)
            self.assertEqual(document["iso"]["filename"], release.iso_filename)
            self.assertEqual(
                document["iso"]["sha256"],
                "1d39ee59b83b0847958cdee279101b6ac2531d8575839a6e3fa72167be729661",
            )
            self.assertRegex(document["source"]["commit"], r"^[0-9a-f]{40}$")
            self.assertIn("built_at", document)


if __name__ == "__main__":
    unittest.main()
