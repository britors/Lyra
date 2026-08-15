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
        release = sample_release(stage="alpha", iteration=4)
        self.assertEqual(release.version_id, "2026.08-alpha4")
        self.assertEqual(release.tag, "v2026.08-alpha4")
        self.assertEqual(release.iso_filename, "lyra-os.x86_64-2026.08-alpha4.iso")
        self.assertEqual(release.volume_id, "LYRA_OS_2026_08_ALPHA4")
        self.assertEqual(release.pretty_name, "Lyra OS Alpha 4 (Odisseia)")

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

    def test_desktop_schedule_has_no_obsolete_2026_final_date(self) -> None:
        schedule_files = (
            ROOT / "PROMPT-LYRA-OS.md",
            ROOT / "docs/roadmap.md",
            ROOT / "docs/nvidia-iso.md",
        )
        for path in schedule_files:
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("20/09/2026", text, path)
        self.assertIn(
            "~26/jan/2027",
            (ROOT / "docs/release-versioning.md").read_text(encoding="utf-8"),
        )

    def test_server_schedule_uses_the_same_release_cadence(self) -> None:
        versioning = (ROOT / "docs/release-versioning.md").read_text(encoding="utf-8")
        server = versioning.split("## Lyra OS Server 1.0", 1)[1].split(
            "## Lyra OS 1.1", 1
        )[0]
        for duration in ("3 semanas", "4 semanas", "2 semanas"):
            self.assertIn(duration, server)
        for stage in ("alpha1", "alpha2", "beta1", "beta2", "beta3", "rc1", "rc2"):
            self.assertIn(f"| {stage} |", server)
        self.assertIn("~26/jan/2027", server)
        self.assertIn("~16/fev/2027", server)

    def test_nvidia_post_install_replaces_the_dedicated_iso(self) -> None:
        prompt = (ROOT / "PROMPT-LYRA-OS.md").read_text(encoding="utf-8")
        roadmap = (ROOT / "docs/roadmap.md").read_text(encoding="utf-8")
        versioning = (ROOT / "docs/release-versioning.md").read_text(encoding="utf-8")
        nvidia_iso = (ROOT / "docs/nvidia-iso.md").read_text(encoding="utf-8")

        for text in (prompt, roadmap, versioning, nvidia_iso):
            self.assertIn("Alpha 5", text)
        self.assertIn("pós-instalação", prompt)
        self.assertIn("sem driver proprietário embutido na ISO padrão", prompt)
        self.assertIn("uma única ISO Desktop", nvidia_iso)
        self.assertIn("proposta cancelada", nvidia_iso)

    def test_desktop_features_and_i18n_freeze_before_beta1(self) -> None:
        versioning = (ROOT / "docs/release-versioning.md").read_text(encoding="utf-8")
        roadmap = (ROOT / "docs/roadmap.md").read_text(encoding="utf-8")
        prompt = (ROOT / "PROMPT-LYRA-OS.md").read_text(encoding="utf-8")

        for text in (versioning, roadmap, prompt):
            self.assertIn("13/10/2026", text)
            self.assertIn("congelamento funcional", text.lower())
        for locale in ("pt-BR", "en-US"):
            self.assertIn(locale, versioning)
            self.assertIn(locale, prompt)

    def test_installer_language_scope_and_future_expansion_are_documented(self) -> None:
        versioning = (ROOT / "docs/release-versioning.md").read_text(encoding="utf-8")
        roadmap = (ROOT / "docs/roadmap.md").read_text(encoding="utf-8")
        prompt = (ROOT / "PROMPT-LYRA-OS.md").read_text(encoding="utf-8")

        for text in (versioning, roadmap, prompt):
            for locale in ("en-US", "pt-BR", "es-ES"):
                self.assertIn(locale, text)
            self.assertIn("ciclo futuro", text)
        self.assertIn("`en-US`", roadmap)
        self.assertIn("como padrão e fallback", roadmap)
        self.assertIn("Alpha 6", roadmap)
        self.assertNotIn("A meta principal da Beta 3", roadmap)
        self.assertIn("não recebem novas features", prompt)

    def test_release_artifact_signing_starts_at_beta1(self) -> None:
        adr = (ROOT / "docs/adr/0005-release-signing-starts-at-beta1.md").read_text(
            encoding="utf-8"
        )
        alpha4 = (
            ROOT / "docs/releases/lyra-os-desktop-2026.08-alpha4.md"
        ).read_text(encoding="utf-8")
        uploader = (
            ROOT / "scripts/upload-desktop-alpha4-sourceforge.sh"
        ).read_text(encoding="utf-8")

        self.assertIn("sem `*.iso.sha256.asc`", adr)
        self.assertIn("começa na Beta 1", alpha4)
        self.assertNotIn('"$PREFIX.iso.sha256.asc"', uploader)

    def test_alpha4_build_prepares_the_complete_upload_bundle(self) -> None:
        builder = (ROOT / "scripts/build-desktop-alpha4.sh").read_text(encoding="utf-8")
        self.assertIn("--artifacts-only", builder)
        self.assertIn("release-artifacts.py generate", builder)
        self.assertIn("docs/releases/lyra-os-desktop-$EXPECTED_VERSION.md", builder)
        for suffix in (".iso.sha256", ".cdx.json", ".spdx.json", ".report"):
            self.assertIn(suffix, builder)

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
