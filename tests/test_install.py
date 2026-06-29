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
            env["WELCOME_BOARD_CONFIG_DIR"] = str(home / "config" / "welcome-board")
            existing = home / "bin" / "wb"
            existing.parent.mkdir(parents=True, exist_ok=True)
            existing.write_text("old wb\n", encoding="utf-8")

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
            self.assertTrue((home / "bin" / "clamshell-ssh-sessions").exists())
            self.assertTrue((home / "bin" / "ssh-sessions").exists())
            self.assertTrue((home / "bin" / "ssh-reap").exists())
            self.assertTrue((home / "share" / "welcome-board" / "welcome-board.sh").exists())
            self.assertTrue((home / "agents-bin" / "codex-claude-daily-update").exists())
            notes = home / "config" / "welcome-board" / "INSTALL_NOTES.md"
            self.assertTrue(notes.exists())
            notes_text = notes.read_text(encoding="utf-8")
            self.assertIn("Welcome Board Install Notes", notes_text)
            self.assertIn("project memory", notes_text)
            self.assertIn("read-only `wb ports explain`", notes_text)
            self.assertIn("Installer project memory:", result.stdout)
            self.assertTrue(list((home / "bin").glob("wb.bak.*")))
            self.assertIn("No shell startup files, services, ports, or firewall rules were changed.", result.stdout)
            self.assertIn("WELCOME_BOARD_DEFER_NUDGE=1 source", result.stdout)
            self.assertIn("welcomeBoardQuickSettings", result.stdout)
            self.assertIn("wb ports explain", result.stdout)
            self.assertIn("read-only", result.stdout)
            self.assertIn("Skipped optional Claude Code + Codex updater cron", result.stdout)
            first_snippet_path = result.stdout.split("[[ $- == *i* ]] && [ -f ", 1)[1].split(" ]", 1)[0]
            self.assertNotIn('"', first_snippet_path)

            help_result = subprocess.run(
                [str(home / "bin" / "wb"), "help"],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(help_result.returncode, 0, help_result.stderr)
            self.assertIn("terminal welcome board helper", help_result.stdout)

        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["WELCOME_BOARD_DATA_DIR"] = "/tmp/welcome-board-outside-home"

            result = subprocess.run(
                [str(INSTALL)],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 2)
            self.assertIn("Refusing WELCOME_BOARD_DATA_DIR outside $HOME", result.stderr)

    def test_install_can_opt_into_four_times_daily_updater_cron(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            fake_bin = home / "fake-bin"
            fake_bin.mkdir()
            cron_store = home / "crontab.txt"
            (fake_bin / "crontab").write_text(
                "#!/usr/bin/env bash\n"
                "store=\"$HOME/crontab.txt\"\n"
                "if [ \"${1:-}\" = \"-l\" ]; then [ -f \"$store\" ] && cat \"$store\"; exit 0; fi\n"
                "cat \"$1\" > \"$store\"\n",
                encoding="utf-8",
            )
            (fake_bin / "crontab").chmod(0o755)

            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{fake_bin}:{env.get('PATH', '')}"
            env["WELCOME_BOARD_INSTALL_UPDATER_CRON"] = "yes"
            env["WELCOME_BOARD_BIN_DIR"] = str(home / "bin")
            env["WELCOME_BOARD_DATA_DIR"] = str(home / "share" / "welcome-board")
            env["WELCOME_BOARD_AGENT_BIN_DIR"] = str(home / "agents-bin")
            env["WELCOME_BOARD_CONFIG_DIR"] = str(home / "config" / "welcome-board")

            result = subprocess.run(
                [str(INSTALL)],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            cron_text = cron_store.read_text(encoding="utf-8")
            self.assertIn("45 3,9,15,21 * * *", cron_text)
            self.assertIn("codex-claude-daily-update", cron_text)
            self.assertIn("Installed optional Claude Code + Codex updater cron", result.stdout)
            backups = list((home / ".local" / "state" / "welcome-board").glob("crontab-before-codex-claude-update-*.txt"))
            self.assertTrue(backups)


if __name__ == "__main__":
    unittest.main()
