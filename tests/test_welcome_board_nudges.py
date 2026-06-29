from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "welcome-board.sh"
ANSI_RE = re.compile(r"\x1B\[[0-9;]*m")


def run_bash(script: str, home: Path) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["WELCOME_BOARD_CONFIG"] = str(home / ".config" / "welcome-board" / "config")
    return subprocess.run(
        ["bash", "-c", script],
        cwd=REPO_ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


class WelcomeBoardNudgeTests(unittest.TestCase):
    def test_footer_shows_weekly_update_history_from_notifier(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            notifier = home / "notifier"
            notifier.write_text(
                "#!/usr/bin/env bash\n"
                "printf 'AGENT CLI UPDATE HISTORY - last 7 days\\n'\n"
                "printf 'TODAY 06:45  Claude: 2.1.178 -> 2.1.179\\n'\n"
                "printf 'TODAY 06:45  Codex: 0.42.0 -> 0.43.0\\n'\n",
                encoding="utf-8",
            )
            notifier.chmod(0o700)

            proc = run_bash(
                f"""
                source {SCRIPT}
                WELCOME_BOARD_UPDATE_NOTIFIER={notifier}
                __wb_footer
                """,
                home,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        plain = ANSI_RE.sub("", proc.stdout)
        self.assertIn("AGENT CLI UPDATE HISTORY - last 7 days", plain)
        self.assertIn("Claude: 2.1.178 -> 2.1.179", plain)
        self.assertIn("Codex: 0.42.0 -> 0.43.0", plain)

    def test_footer_stays_quiet_when_there_are_no_update_results(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            notifier = home / "notifier"
            notifier.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            notifier.chmod(0o700)

            proc = run_bash(
                f"""
                source {SCRIPT}
                WELCOME_BOARD_UPDATE_NOTIFIER={notifier}
                __wb_footer
                """,
                home,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        plain = ANSI_RE.sub("", proc.stdout)
        self.assertNotIn("agent updater", plain.lower())
        self.assertNotIn("manual Codex", plain)
        self.assertNotIn("manual Claude", plain)
        self.assertEqual(plain, "")


if __name__ == "__main__":
    unittest.main()
