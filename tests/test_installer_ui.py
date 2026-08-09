from __future__ import annotations

import re
import unittest
from html.parser import HTMLParser
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "installer" / "ui"


class IdCollector(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: list[str] = []

    def handle_starttag(self, _tag: str, attrs: list[tuple[str, str | None]]) -> None:
        element_id = dict(attrs).get("id")
        if element_id:
            self.ids.append(element_id)


class InstallerUiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.html = (UI / "index.html").read_text(encoding="utf-8")
        self.css = (UI / "styles.css").read_text(encoding="utf-8")
        self.javascript = (UI / "app.js").read_text(encoding="utf-8")

    def test_element_ids_are_unique(self) -> None:
        parser = IdCollector()
        parser.feed(self.html)
        duplicates = sorted({element_id for element_id in parser.ids if parser.ids.count(element_id) > 1})
        self.assertEqual(duplicates, [])

    def test_final_install_flow_lives_in_bottom_action_area(self) -> None:
        footer = self.html.split('<footer class="actions">', 1)[1].split("</footer>", 1)[0]
        controls = ("install-confirm", "install", "install-status", "reboot")
        positions = []
        for element_id in controls:
            marker = re.search(rf'id="{re.escape(element_id)}"', footer)
            self.assertIsNotNone(marker, f"{element_id} must be in the bottom action area")
            positions.append(marker.start())
        self.assertEqual(positions, sorted(positions))
        self.assertNotIn("execution-events", self.html)

    def test_final_flow_replaces_each_control_in_sequence(self) -> None:
        self.assertIn(
            "installConfirmControl.hidden=current!==6||installConfirm.checked||installing||installationTerminal",
            self.javascript,
        )
        self.assertIn(
            "install.hidden=current!==6||!installConfirm.checked||installing||installationTerminal",
            self.javascript,
        )
        self.assertIn("installStatus.hidden=true;\n      reboot.hidden=false;", self.javascript)
        self.assertNotIn("executionEvents", self.javascript)

    def test_final_controls_are_right_aligned(self) -> None:
        self.assertRegex(
            self.css,
            r"\.final-actions\{[^}]*justify-content:flex-end",
        )
        self.assertRegex(self.css, r"\.install-confirm\{[^}]*text-align:right")
        self.assertRegex(self.css, r"\.install-status\{[^}]*text-align:right")

    def test_text_and_select_controls_use_larger_consistent_type(self) -> None:
        self.assertIn("--form-control-font-size:13px", self.css)
        selectors = (
            ".form-grid input",
            ".keyboard-search input",
            ".region-form select",
            ".manual-entry-row input",
            ".lvm-preset-row select",
            ".lv-row input",
            ".lv-row select",
        )
        rule = ",".join(selectors) + "{font-size:var(--form-control-font-size)}"
        self.assertIn(rule, self.css)


if __name__ == "__main__":
    unittest.main()
