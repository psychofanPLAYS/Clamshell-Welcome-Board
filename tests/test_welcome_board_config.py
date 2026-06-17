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


def render_with_config(home: Path, config_text: str) -> str:
    config = home / ".config" / "welcome-board" / "config"
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(config_text, encoding="utf-8")

    bin_dir = home / "bin"
    bin_dir.mkdir()
    (bin_dir / "tmux").write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
    (bin_dir / "tmux").chmod(0o755)

    env = os.environ.copy()
    env["HOME"] = str(home)
    env["WELCOME_BOARD_CONFIG"] = str(config)
    env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
    result = subprocess.run(
        ["bash", "-lc", f"source {SCRIPT}; __wb_render"],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


class WelcomeBoardConfigTests(unittest.TestCase):
    def test_config_controls_name_banner_theme_and_sections(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_with_config(
                Path(raw_tmp),
                '\n'.join(
                    [
                        'WB_DISPLAY_NAME="Alex"',
                        'WB_BANNER_TEXT="WORKBOX"',
                        'WB_THEME="mono-safe"',
                        'WB_SECTIONS="tmux"',
                        "",
                    ]
                ),
            )

        self.assertIn("ALEX", rendered)
        self.assertIn("WORKBOX", rendered)
        self.assertIn("TMUX", rendered)
        self.assertIn("no sessions", rendered)
        self.assertNotIn("DAWID", rendered)
        self.assertNotIn("MACHINE", rendered)
        self.assertNotIn("PRESSURE", rendered)


if __name__ == "__main__":
    unittest.main()
