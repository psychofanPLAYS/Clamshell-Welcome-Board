from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class BashCompatibilityTests(unittest.TestCase):
    def test_public_shell_scripts_avoid_bash4_only_constructs(self) -> None:
        checked = [
            REPO_ROOT / "welcome-board.sh",
            REPO_ROOT / "bin" / "wb",
            REPO_ROOT / "bin" / "welcomeboard",
            REPO_ROOT / "install.sh",
        ]
        forbidden = ["local -n", "declare -A", "local -A", "mapfile", "readarray"]

        for path in checked:
            text = path.read_text(encoding="utf-8")
            for needle in forbidden:
                self.assertNotIn(needle, text, f"{path.name} uses Bash 4-only construct: {needle}")

    def test_ci_runs_on_linux_and_macos(self) -> None:
        workflow = (REPO_ROOT / ".github" / "workflows" / "test.yml").read_text(encoding="utf-8")
        self.assertIn("ubuntu-latest", workflow)
        self.assertIn("macos-latest", workflow)
        self.assertIn("matrix.os", workflow)


if __name__ == "__main__":
    unittest.main()
