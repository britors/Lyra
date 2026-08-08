from __future__ import annotations

import importlib.machinery
import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "kiwi/root/usr/libexec/lyra-report-redact"
LOADER = importlib.machinery.SourceFileLoader("lyra_report_redact", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC
redact_module = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(redact_module)


class RedactorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = (ROOT / "tests/fixtures/lyra-report/secrets.txt").read_text(encoding="utf-8")
        self.redactor = redact_module.Redactor("alice", "orion-workstation")

    def test_removes_fixture_secrets_and_personal_identifiers(self) -> None:
        redacted = self.redactor.redact(self.fixture)
        forbidden = (
            "orion-workstation",
            "/home/alice",
            "alice@example.invalid",
            "My Private WiFi",
            "hunter2-example",
            "tok_example_123456789",
            "bearer-example-secret",
            "repo-user",
            "repo-password",
            "192.0.2.42",
            "192.0.2.1",
            "2001:db8::42",
            "52:54:00:12:34:56",
            "550e8400-e29b-41d4-a716-446655440000",
            "github_pat_exampleexampleexample1234",
            "fake-private-key-material",
        )
        for value in forbidden:
            self.assertNotIn(value, redacted)
        for category in (
            "<hostname-1>",
            "<user-1>",
            "<email-1>",
            "<ssid-1>",
            "<credential-1>",
            "<url-credential-1>",
            "<ipv4-1>",
            "<ipv6-1>",
            "<mac-1>",
            "<uuid-1>",
            "<private-key-1>",
        ):
            self.assertIn(category, redacted)

    def test_repeated_values_keep_a_stable_token(self) -> None:
        redacted = self.redactor.redact("first=192.0.2.42 second=192.0.2.42")
        self.assertEqual(redacted.count("<ipv4-1>"), 2)

    def test_known_network_names_are_removed_from_unstructured_logs(self) -> None:
        redactor = redact_module.Redactor("alice", "orion-workstation", ("Cafe WiFi",))
        redacted = redactor.redact('NetworkManager activated connection "Cafe WiFi"')
        self.assertNotIn("Cafe WiFi", redacted)
        self.assertIn("<network-name-1>", redacted)

    def test_tree_contains_only_redacted_files_and_a_safe_summary(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "raw"
            destination = Path(directory) / "report"
            source.mkdir()
            (source / "journal.txt").write_text(self.fixture, encoding="utf-8")
            redact_module.redact_tree(source, destination, self.redactor)
            redact_module.write_summary(destination, self.redactor)
            report = (destination / "journal.txt").read_text(encoding="utf-8")
            summary = (destination / "redaction-summary.txt").read_text(encoding="utf-8")
            self.assertNotIn("hunter2-example", report)
            self.assertNotIn("hunter2-example", summary)
            self.assertIn("credential:", summary)
            self.assertEqual((destination / "journal.txt").stat().st_mode & 0o777, 0o600)

    def test_existing_output_is_never_removed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "raw"
            destination = Path(directory) / "existing"
            source.mkdir()
            destination.mkdir()
            marker = destination / "keep.txt"
            marker.write_text("keep", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "output already exists"):
                redact_module.redact_tree(source, destination, self.redactor)
            self.assertEqual(marker.read_text(encoding="utf-8"), "keep")


if __name__ == "__main__":
    unittest.main()
