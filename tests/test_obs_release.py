from __future__ import annotations

import importlib.util
import sys
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("lyra_obs_release", ROOT / "scripts/obs-release.py")
assert SPEC and SPEC.loader
obs_release = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = obs_release
SPEC.loader.exec_module(obs_release)


class FakeObs:
    def __init__(self, documents: dict[str, str]) -> None:
        self.documents = documents

    def api_xml(self, path: str) -> ET.Element:
        return ET.fromstring(self.documents[path])


class ManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = obs_release.Manifest.load()

    def test_project_inventory_matches_beta_two_contract(self) -> None:
        self.assertEqual([project.id for project in self.manifest.projects], ["lyra", "vega", "fina"])
        self.assertEqual(len(self.manifest.project("lyra").packages), 8)
        self.assertNotIn("calamares", self.manifest.project("lyra").packages)
        self.assertEqual(self.manifest.project("fina").targets[1].name, "openSUSE_Tumbleweed")

    def test_staging_is_never_an_iso_consumer(self) -> None:
        for project in self.manifest.projects:
            metadata = obs_release.render_project_meta(self.manifest, project)
            self.assertIn("Not consumed by Lyra ISO", metadata)
            self.assertNotIn(project.release + "</", metadata)

    def test_local_priority_contract_is_current(self) -> None:
        obs_release.check_local_priorities(self.manifest)


class BuildGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.project = obs_release.Manifest.load().project("lyra")
        self.target = self.project.targets[0]

    def test_multibuild_parent_may_be_excluded_when_all_flavors_succeed(self) -> None:
        statuses = []
        for package in self.project.packages:
            code = "excluded" if package == "lyra-theme" else "succeeded"
            statuses.append(f'<status package="{package}" code="{code}"/>')
        statuses.extend(
            [
                '<status package="lyra-theme:lyra-os-icons" code="succeeded"/>',
                '<status package="lyra-theme:lyra-os-theme" code="succeeded"/>',
            ]
        )
        path = (
            "/build/home:example/_result?repository=openSUSE_Leap_16.0"
            "&arch=x86_64&view=status"
        )
        document = (
            '<resultlist><result code="published" state="published">'
            + "".join(statuses)
            + "</result></resultlist>"
        )
        obs_release.check_target_result(FakeObs({path: document}), self.project, "home:example", self.target, "x86_64")

    def test_failed_flavor_blocks_promotion(self) -> None:
        statuses = [
            f'<status package="{package}" code="succeeded"/>'
            for package in self.project.packages
            if package != "lyra-theme"
        ]
        statuses.extend(
            [
                '<status package="lyra-theme" code="excluded"/>',
                '<status package="lyra-theme:lyra-os-icons" code="failed"/>',
            ]
        )
        path = (
            "/build/home:example/_result?repository=openSUSE_Leap_16.0"
            "&arch=x86_64&view=status"
        )
        document = '<resultlist><result code="published">' + "".join(statuses) + "</result></resultlist>"
        with self.assertRaisesRegex(obs_release.PolicyError, "build gate failed"):
            obs_release.check_target_result(
                FakeObs({path: document}), self.project, "home:example", self.target, "x86_64"
            )

    def test_unpublished_repository_blocks_promotion(self) -> None:
        path = (
            "/build/home:example/_result?repository=openSUSE_Leap_16.0"
            "&arch=x86_64&view=status"
        )
        document = '<resultlist><result code="building" state="building"/></resultlist>'
        with self.assertRaisesRegex(obs_release.PolicyError, "not published"):
            obs_release.check_target_result(
                FakeObs({path: document}), self.project, "home:example", self.target, "x86_64"
            )


class SafetyTests(unittest.TestCase):
    def test_mutation_is_a_plan_without_execute(self) -> None:
        obs = obs_release.Obs("https://api.opensuse.org", execute=False)
        self.assertEqual(obs.run(["request", "accept", "123"], mutating=True), "")

    def test_command_formatter_does_not_interpolate_shell(self) -> None:
        rendered = obs_release.Obs.format_command(["osc", "-m", "test; $(bad)"])
        self.assertEqual(rendered, "osc -m 'test; $(bad)'")


if __name__ == "__main__":
    unittest.main()
