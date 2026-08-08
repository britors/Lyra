from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import tempfile
import types
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "kiwi/root/usr/bin/lyra-performance"
LOADER = importlib.machinery.SourceFileLoader("lyra_performance", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC
performance = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(performance)


class PerformanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.budget = performance.read_toml(ROOT / "performance.toml")

    def test_image_budget_matches_source(self) -> None:
        source = (ROOT / "performance.toml").read_bytes()
        image = (ROOT / "kiwi/root/usr/share/lyra-os/performance.toml").read_bytes()
        self.assertEqual(source, image)
        performance.validate_budget(self.budget)

    def test_installation_trace_produces_stage_durations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            trace = Path(directory) / "trace.jsonl"
            stages = (("start", 10), ("storage", 13), ("rootfs", 23), ("target", 28), ("boot", 36), ("complete", 40))
            trace.write_text(
                "".join(json.dumps({"stage": stage, "monotonic_seconds": value}) + "\n" for stage, value in stages),
                encoding="utf-8",
            )
            metrics = performance.parse_installation_trace(trace)
            self.assertEqual(metrics["installation_total_seconds"], 30)
            self.assertEqual(metrics["installation_rootfs_seconds"], 10)
            self.assertEqual(metrics["installation_boot_seconds"], 8)

    def test_mark_start_replaces_an_old_trace(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            trace = Path(directory) / "trace.jsonl"
            trace.write_text('{"stage":"old"}\n', encoding="utf-8")
            args = types.SimpleNamespace(stage="start", trace=trace)
            self.assertEqual(performance.mark(args), 0)
            events = [json.loads(line) for line in trace.read_text(encoding="utf-8").splitlines()]
            self.assertEqual([event["stage"] for event in events], ["start"])

    def write_runs(self, directory: Path, multiplier: float = 1.0, noisy: bool = False) -> list[Path]:
        directory.mkdir(parents=True, exist_ok=True)
        values = [100, 101, 99, 100, 100]
        if noisy:
            values = [70, 85, 100, 115, 130]
        paths: list[Path] = []
        for index, value in enumerate(values):
            document = {
                "schema_version": 1,
                "phase": "installed",
                "source": {
                    "version": "2026.08-beta2",
                    "commit": "a" * 40,
                    "dirty": False,
                    "kernel": "6.12.0-reference",
                },
                "environment": {"cpu": "reference", "memory": 8192},
                "metrics": {
                    "boot_to_desktop_seconds": value * multiplier,
                    "boot_userspace_seconds": 20 * multiplier,
                    "idle_memory_mib": 1000 * multiplier,
                    "cpu_busy_percent": 2 * multiplier,
                    "disk_read_mib_per_second": 0,
                    "disk_write_mib_per_second": 0,
                },
            }
            path = directory / f"run-{index}.json"
            path.write_text(json.dumps(document), encoding="utf-8")
            paths.append(path)
        return paths

    def aggregate_args(self, inputs: list[Path], output: Path, baseline: Path | None = None) -> types.SimpleNamespace:
        return types.SimpleNamespace(inputs=inputs, output=output, baseline=baseline, fail_on="blocking")

    def test_aggregate_records_median_and_dispersion(self) -> None:
        with tempfile.TemporaryDirectory() as directory_name:
            directory = Path(directory_name)
            inputs = self.write_runs(directory)
            output = directory / "summary.json"
            self.assertEqual(performance.aggregate(self.aggregate_args(inputs, output), self.budget), 0)
            summary = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(summary["run_count"], 5)
            self.assertEqual(summary["metrics"]["boot_to_desktop_seconds"]["median"], 100)
            self.assertEqual(summary["metrics"]["boot_to_desktop_seconds"]["median_absolute_deviation"], 0)
            self.assertFalse(summary["noisy"])

    def test_budget_blocks_twenty_percent_regression(self) -> None:
        with tempfile.TemporaryDirectory() as directory_name:
            directory = Path(directory_name)
            baseline_runs = self.write_runs(directory / "baseline")
            baseline = directory / "baseline.json"
            self.assertEqual(performance.aggregate(self.aggregate_args(baseline_runs, baseline), self.budget), 0)
            current_runs = self.write_runs(directory / "current", multiplier=1.25)
            output = directory / "current.json"
            result = performance.aggregate(self.aggregate_args(current_runs, output, baseline), self.budget)
            self.assertEqual(result, 2)
            summary = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(summary["budget"]["status"], "blocking")

    def test_noisy_series_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory_name:
            directory = Path(directory_name)
            inputs = self.write_runs(directory, noisy=True)
            output = directory / "summary.json"
            self.assertEqual(performance.aggregate(self.aggregate_args(inputs, output), self.budget), 2)
            self.assertTrue(json.loads(output.read_text(encoding="utf-8"))["noisy"])

    def test_aggregate_requires_five_runs(self) -> None:
        with tempfile.TemporaryDirectory() as directory_name:
            directory = Path(directory_name)
            inputs = self.write_runs(directory)[:4]
            with self.assertRaisesRegex(ValueError, "at least 5 runs"):
                performance.aggregate(self.aggregate_args(inputs, directory / "summary.json"), self.budget)


if __name__ == "__main__":
    unittest.main()
