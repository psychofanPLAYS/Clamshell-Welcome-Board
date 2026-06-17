from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
WB = REPO_ROOT / "bin" / "wb"
WELCOMEBOARD = REPO_ROOT / "bin" / "welcomeboard"


def run_wb(*args: str, input_text: str = "", home: Path | None = None) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    if home is not None:
        env["HOME"] = str(home)
        env["WELCOME_BOARD_CONFIG"] = str(home / ".config" / "welcome-board" / "config")
    return subprocess.run(
        [str(WB), *args],
        input=input_text,
        text=True,
        capture_output=True,
        env=env,
        check=False,
    )


def run_welcomeboard(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(WELCOMEBOARD), *args],
        text=True,
        capture_output=True,
        check=False,
    )


class WbCliTests(unittest.TestCase):
    def test_help_lists_safe_commands(self) -> None:
        result = run_wb("help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("wb setup", result.stdout)
        self.assertIn("wb theme", result.stdout)
        self.assertIn("wb ports scan", result.stdout)
        self.assertIn("read-only", result.stdout)

    def test_welcomeboard_wrapper_reaches_wb(self) -> None:
        result = run_welcomeboard("help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("terminal welcome board helper", result.stdout)

    def test_theme_set_writes_config(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            result = run_wb("theme", "amber-terminal", home=home)
            self.assertEqual(result.returncode, 0, result.stderr)
            config = home / ".config" / "welcome-board" / "config"
            self.assertIn('WB_THEME="amber-terminal"', config.read_text(encoding="utf-8"))

    def test_theme_rejects_unknown_value(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            result = run_wb("theme", "rainbow-surprise", home=Path(raw_tmp))
            self.assertEqual(result.returncode, 2)
            self.assertIn("Unknown theme", result.stderr)

    def test_setup_writes_name_banner_theme_and_sections(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            answers = "Alex\nWORKBOX\ngreen-phosphor\nmachine tmux ports\n"
            result = run_wb("setup", input_text=answers, home=home)
            self.assertEqual(result.returncode, 0, result.stderr)
            config = (home / ".config" / "welcome-board" / "config").read_text(encoding="utf-8")
            self.assertIn('WB_DISPLAY_NAME="Alex"', config)
            self.assertIn('WB_BANNER_TEXT="WORKBOX"', config)
            self.assertIn('WB_THEME="green-phosphor"', config)
            self.assertIn('WB_SECTIONS="machine tmux ports"', config)

    def test_ports_unknown_command_does_not_apply_anything(self) -> None:
        result = run_wb("ports", "apply")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unknown ports command", result.stderr)


if __name__ == "__main__":
    unittest.main()
