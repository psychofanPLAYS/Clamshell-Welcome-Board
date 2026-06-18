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


def _write_network_support_mocks(bin_dir: Path) -> None:
    """Write deterministic mocks for tools used by __wb_network besides tmux."""
    # tailscale: minimal output so the self-row and peer rows render quickly
    (bin_dir / "tailscale").write_text(
        "#!/usr/bin/env bash\n"
        'if [ "$1" = "ip" ]; then printf "10.0.0.10\\n"; exit 0; fi\n'
        "cat <<'EOF'\n"
        "10.0.0.10   workstation  user linux  -\n"
        "10.0.0.15   laptop user macOS  offline\n"
        "10.0.0.20   server     user windows offline\n"
        "EOF\n",
        encoding="utf-8",
    )
    # who: zero remote logins
    (bin_dir / "who").write_text(
        "#!/usr/bin/env bash\nexit 0\n",
        encoding="utf-8",
    )
    for path in bin_dir.iterdir():
        path.chmod(0o755)


def render_network_section(home: Path, tmux_script: str) -> str:
    bin_dir = home / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)

    # Write tmux mock first, then support mocks
    tmux = bin_dir / "tmux"
    tmux.write_text(tmux_script, encoding="utf-8")
    tmux.chmod(0o755)

    _write_network_support_mocks(bin_dir)

    env = os.environ.copy()
    env["HOME"] = str(home)
    env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
    # Render __wb_network; WB_PEERS kept at default (includes mac + server)
    command = (
        f"source {SCRIPT}; __wb_paint; "
        "WB_FRAME_ON=1; WB_FRAME_INNER=78; WB_W=78; WB_ZW=78; "
        "__wb_network"
    )
    result = subprocess.run(
        ["bash", "-c", command],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


class TmuxSectionTests(unittest.TestCase):
    def test_tmux_sessions_render_count_and_names(self) -> None:
        """When tmux ls lists sessions, the tmux row shows the count and names."""
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_network_section(
                Path(raw_tmp),
                "#!/usr/bin/env bash\n"
                'if [ "$1" = "ls" ]; then\n'
                "  printf 'work: 3 windows (created Mon)\\n'\n"
                "  printf 'ops: 1 windows (created Mon)\\n'\n"
                "  exit 0\n"
                "fi\n"
                "exit 1\n",
            )
            unsafe_rendered = render_network_section(
                Path(raw_tmp),
                "#!/usr/bin/env bash\n"
                'if [ "$1" = "ls" ]; then\n'
                "  printf 'work\\033]52;c;boom\\a: 1 windows (created Mon)\\n'\n"
                "  exit 0\n"
                "fi\n"
                "exit 1\n",
            )

        # tmux row must appear in NETWORK output
        self.assertIn("tmux", rendered)

        # Session count (2 sessions)
        self.assertIn("2", rendered)

        # Session names appear somewhere in the tmux row
        tmux_line = next(
            (l for l in rendered.splitlines() if "tmux" in l and "session" in l),
            None,
        )
        self.assertIsNotNone(tmux_line, "tmux session(s) row not found")
        self.assertIn("work", tmux_line)
        self.assertIn("ops", tmux_line)

        # All framed rows are 82 display columns
        framed_rows = [line for line in rendered.splitlines() if line.startswith("  │")]
        self.assertTrue(framed_rows)
        self.assertEqual({len(line) for line in framed_rows}, {82})
        self.assertNotIn("\x1b", unsafe_rendered)
        self.assertNotIn("\x07", unsafe_rendered)

    def test_tmux_no_sessions_is_explicit(self) -> None:
        """When tmux ls exits non-zero, the tmux row says 'no sessions'."""
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_network_section(
                Path(raw_tmp),
                "#!/usr/bin/env bash\nexit 1\n",
            )

        # Must indicate no sessions
        self.assertIn("no sessions", rendered)

        # The start command hint is shown
        self.assertIn("tmux new", rendered)

        # All framed rows are 82 display columns
        framed_rows = [line for line in rendered.splitlines() if line.startswith("  │")]
        self.assertTrue(framed_rows)
        self.assertEqual({len(line) for line in framed_rows}, {82})


if __name__ == "__main__":
    unittest.main()
