from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "kiwi/root/usr/bin/lyra-hardware-matrix"
LOADER = importlib.machinery.SourceFileLoader("lyra_hardware_matrix", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC
hardware_matrix = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(hardware_matrix)


class HardwareMatrixTests(unittest.TestCase):
    @staticmethod
    def checks(kind: str) -> list[str]:
        names = hardware_matrix.CORE_CHECKS | hardware_matrix.DEVICE_CHECKS
        if kind == "notebook":
            names |= hardware_matrix.NOTEBOOK_CHECKS
        return [f"{name}=passed" for name in sorted(names)]

    def scenario(
        self, machine: str, kind: str, cpu: str, gpus: list[str]
    ) -> dict[str, object]:
        return hardware_matrix.scenario_document(
            machine=machine,
            kind=kind,
            iso_filename="lyra-os.x86_64-2026.08-beta2.iso",
            iso_sha256="a" * 64,
            source_commit="b" * 40,
            checks=self.checks(kind),
            detected_cpu_vendor=cpu,
            detected_gpu_vendors=gpus,
        )

    def write_scenarios(self, directory: Path) -> list[Path]:
        documents = (
            self.scenario("desktop-amd", "desktop", "amd", ["amd"]),
            self.scenario("notebook-intel", "notebook", "intel", ["intel"]),
            self.scenario("notebook-amd", "notebook", "amd", ["amd"]),
        )
        paths = []
        for index, document in enumerate(documents):
            path = directory / f"scenario-{index}.json"
            path.write_text(json.dumps(document), encoding="utf-8")
            paths.append(path)
        return paths

    def test_complete_matrix_requires_real_machine_and_vendor_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            paths = self.write_scenarios(Path(temporary))
            result = hardware_matrix.aggregate(paths)
            self.assertEqual(result["status"], "passed")
            self.assertEqual(result["coverage"]["desktops"], 1)
            self.assertEqual(result["coverage"]["notebooks"], 2)
            self.assertEqual(result["coverage"]["cpu_vendors"], ["amd", "intel"])

    def test_core_checks_cannot_be_marked_not_applicable(self) -> None:
        checks = self.checks("desktop")
        checks[checks.index("installation=passed")] = (
            "installation=not-applicable:not attempted"
        )
        result = hardware_matrix.scenario_document(
            machine="desktop-amd",
            kind="desktop",
            iso_filename="lyra.iso",
            iso_sha256="a" * 64,
            source_commit="b" * 40,
            checks=checks,
            detected_cpu_vendor="amd",
            detected_gpu_vendors=["amd"],
        )
        self.assertEqual(result["status"], "failed")

    def test_not_applicable_device_requires_a_reason(self) -> None:
        with self.assertRaisesRegex(hardware_matrix.MatrixError, "requires a reason"):
            hardware_matrix.parse_check("webcam=not-applicable")

    def test_aggregate_rejects_different_candidate_images(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            paths = self.write_scenarios(Path(temporary))
            changed = json.loads(paths[-1].read_text(encoding="utf-8"))
            changed["iso"]["sha256"] = "c" * 64
            paths[-1].write_text(json.dumps(changed), encoding="utf-8")
            with self.assertRaisesRegex(hardware_matrix.MatrixError, "exact same"):
                hardware_matrix.aggregate(paths)

    def test_detects_common_cpu_and_gpu_vendors_without_serials(self) -> None:
        self.assertEqual(
            hardware_matrix.cpu_vendor("Vendor ID: GenuineIntel"), "intel"
        )
        self.assertEqual(
            hardware_matrix.gpu_vendors(
                "VGA compatible controller: Intel Corporation\n"
                "3D controller: NVIDIA Corporation"
            ),
            ["intel", "nvidia"],
        )


if __name__ == "__main__":
    unittest.main()
