from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class PublicArtifactsTests(unittest.TestCase):
    def test_readme_links_checked_in_demo_output(self) -> None:
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        demo_path = REPO_ROOT / "docs" / "demo-output.txt"

        self.assertIn("docs/demo-output.txt", readme)
        self.assertTrue(demo_path.exists(), "docs/demo-output.txt should show a public-safe render preview")

        demo = demo_path.read_text(encoding="utf-8")
        for expected in ("WORKSTATION", "PRESSURE", "TEMP", "CLOCKS", "TMUX", "COMMANDS"):
            self.assertIn(expected, demo)
        forbidden_values = (
            "claw" + "ski",
            "Da" + "wid",
            "192." + "168.",
            "100.",
            "/home/" + "claw" + "ski",
            "histo" + "ry",
            "hit" + "ory",
            "sam" + "ple",
            "8sam" + "ple",
            "tr" + "end",
        )
        for forbidden in forbidden_values:
            self.assertNotIn(forbidden.lower(), demo.lower())


if __name__ == "__main__":
    unittest.main()
