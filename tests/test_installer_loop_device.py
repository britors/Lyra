from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "installer/service/test-loop-device.sh"


class InstallerLoopDeviceTestContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = SCRIPT.read_text(encoding="utf-8")

    def test_shell_syntax_is_valid(self) -> None:
        subprocess.run(["bash", "-n", str(SCRIPT)], check=True)

    def test_mandatory_audits_are_fail_closed(self) -> None:
        for assertion in ("usuário lyra", "sudoers", "initramfs"):
            self.assertIn(f'audit_fail "{assertion}', self.text)
        self.assertNotIn('|| echo "FALHA:', self.text)

    def test_service_and_audit_failures_are_distinct(self) -> None:
        self.assertIn("FALHA DO SERVIÇO", self.text)
        self.assertIn("FALHA NA AUDITORIA", self.text)
        self.assertIn('SERVICE_STATUS="${PIPESTATUS[1]}"', self.text)

    def test_cleanup_covers_the_temporary_audit_mount(self) -> None:
        cleanup = self.text.split("cleanup() {", 1)[1].split("}\ntrap cleanup", 1)[0]
        self.assertIn('umount "$AUDIT_MOUNT"', cleanup)
        self.assertIn('rmdir "$AUDIT_MOUNT"', cleanup)


if __name__ == "__main__":
    unittest.main()
