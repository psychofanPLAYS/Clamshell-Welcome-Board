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
    def test_default_render_uses_animation_until_user_turns_it_off(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            proc = run_bash(
                f"""
                source {SCRIPT}
                __wb_load_config
                __wb_paint
                __wb_probe_listeners() {{ :; }}
                __wb_animate_banner() {{ printf 'ANIM\\n'; }}
                __wb_banner() {{ printf 'STATIC\\n'; }}
                __wb_frame_top() {{ :; }}
                __wb_frame_bottom() {{ :; }}
                __wb_greeting_row() {{ :; }}
                __wb_machine() {{ :; }}
                __wb_network() {{ :; }}
                __wb_local_ai() {{ :; }}
                __wb_security() {{ :; }}
                __wb_services() {{ :; }}
                __wb_automation() {{ :; }}
                __wb_hermes() {{ :; }}
                __wb_commands() {{ :; }}
                __wb_footer() {{ :; }}
                __wb_render
                __wb_state_set animation_enabled 0
                __wb_render
                """,
                home,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        lines = [line for line in proc.stdout.splitlines() if line in {"ANIM", "STATIC"}]
        self.assertEqual(lines, ["ANIM", "STATIC"])

    def test_animation_nudge_schedule_is_three_six_nine_then_rare(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            proc = run_bash(
                f"""
                source {SCRIPT}
                __wb_state_set start_count 2
                __wb_state_set animation_prompt_count 0
                __wb_state_increment start_count >/dev/null
                __wb_animation_nudge_due && printf 'due3\\n'
                __wb_state_set start_count 6
                __wb_state_set animation_prompt_count 1
                __wb_animation_nudge_due && printf 'due6\\n'
                __wb_state_set start_count 9
                __wb_state_set animation_prompt_count 2
                __wb_animation_nudge_due && printf 'due9\\n'
                __wb_state_set start_count 10
                __wb_state_set animation_prompt_count 3
                __wb_animation_nudge_due || printf 'notrare\\n'
                WB_NUDGE_RARE_FORCE=1 __wb_animation_nudge_due && printf 'rare\\n'
                """,
                home,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.splitlines(), ["due3", "due6", "due9", "notrare", "rare"])

    def test_animation_nudge_choices_are_strict_one_two_three(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            proc = run_bash(
                f"""
                source {SCRIPT}
                __wb_state_set animation_enabled 1
                __wb_apply_animation_choice 2
                printf 'after2=%s\\n' "$(__wb_state_get animation_enabled 1)"
                __wb_apply_animation_choice x
                printf 'afterx=%s\\n' "$(__wb_state_get animation_enabled 1)"
                __wb_apply_animation_choice 1
                printf 'after1=%s\\n' "$(__wb_state_get animation_enabled 0)"
                __wb_apply_animation_choice 3
                printf 'after3=%s\\n' "$(__wb_state_get animation_enabled 0)"
                """,
                home,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.splitlines(), ["after2=0", "afterx=0", "after1=1", "after3=1"])

    def test_animation_nudge_box_is_centered_and_color_boxed(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            proc = run_bash(
                f"""
                source {SCRIPT}
                __wb_load_config
                __wb_paint
                __wb_animation_nudge_box
                """,
                home,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        plain = ANSI_RE.sub("", proc.stdout).replace("\x06", "")
        lines = [line.rstrip() for line in plain.splitlines()]
        self.assertEqual(len(lines), 6)
        self.assertTrue(lines[0].startswith("            +"))
        self.assertIn("QUICK SETTINGS", lines[1])
        self.assertIn("1 keep animation", plain)
        self.assertIn("anything else vanishes", plain)
        self.assertEqual({len(line) for line in lines}, {72})


if __name__ == "__main__":
    unittest.main()
