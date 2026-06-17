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


def render_tmux_section(home: Path, tmux_script: str) -> str:
    bin_dir = home / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    tmux = bin_dir / "tmux"
    tmux.write_text(tmux_script, encoding="utf-8")
    tmux.chmod(0o755)

    env = os.environ.copy()
    env["HOME"] = str(home)
    env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
    command = f"source {SCRIPT}; __wb_paint; WB_FRAME_ON=1; WB_FRAME_INNER=78; WB_W=78; WB_ZW=78; __wb_tmux"
    result = subprocess.run(
        ["bash", "-lc", command],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


class TmuxSectionTests(unittest.TestCase):
    def test_tmux_sessions_render_in_aligned_rows(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_tmux_section(
                Path(raw_tmp),
                "#!/usr/bin/env bash\n"
                "printf 'work\\t3\\tattached\\nvery-long-session-name\\t1\\tdetached\\n'\n",
            )

        self.assertIn("TMUX", rendered)
        self.assertRegex(rendered, r"work\s+3 windows · attached")
        self.assertRegex(rendered, r"very-long-s\.\.\.\s+1 window · detached")
        framed_rows = [line for line in rendered.splitlines() if line.startswith("  │")]
        self.assertTrue(framed_rows)
        self.assertEqual({len(line) for line in framed_rows}, {82})

    def test_tmux_no_sessions_is_explicit(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_tmux_section(
                Path(raw_tmp),
                "#!/usr/bin/env bash\nexit 1\n",
            )

        self.assertIn("no sessions", rendered)


if __name__ == "__main__":
    unittest.main()
