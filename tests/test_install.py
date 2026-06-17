from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALL = REPO_ROOT / "install.sh"


class InstallTests(unittest.TestCase):
    def test_install_copies_commands_without_editing_shell_startup(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["WELCOME_BOARD_BIN_DIR"] = str(home / "bin")
            env["WELCOME_BOARD_DATA_DIR"] = str(home / "share" / "welcome-board")
            env["WELCOME_BOARD_AGENT_BIN_DIR"] = str(home / "agents-bin")

            result = subprocess.run(
                [str(INSTALL)],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((home / "bin" / "wb").exists())
            self.assertTrue((home / "bin" / "welcomeboard").exists())
            self.assertTrue((home / "share" / "welcome-board" / "welcome-board.sh").exists())
            self.assertTrue((home / "agents-bin" / "codex-claude-daily-update").exists())
            self.assertIn("No shell startup files, services, ports, or firewall rules were changed.", result.stdout)

            help_result = subprocess.run(
                [str(home / "bin" / "wb"), "help"],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(help_result.returncode, 0, help_result.stderr)
            self.assertIn("terminal welcome board helper", help_result.stdout)


if __name__ == "__main__":
    unittest.main()
