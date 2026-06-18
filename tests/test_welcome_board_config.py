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


def _make_bin_dir(home: Path) -> Path:
    """Create a bin/ dir with deterministic mocks for all external tools."""
    bin_dir = home / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)

    # tmux: no sessions
    (bin_dir / "tmux").write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")

    # tailscale: returns a fixed status table
    (bin_dir / "tailscale").write_text(
        "#!/usr/bin/env bash\n"
        'if [ "$1" = "ip" ]; then printf "10.0.0.10\\n"; exit 0; fi\n'
        "cat <<'EOF'\n"
        "10.0.0.10   workstation user linux -\n"
        "10.0.0.15   laptop user macOS -\n"
        "10.0.0.20   server     user windows offline\n"
        "EOF\n",
        encoding="utf-8",
    )

    # who: zero remote logins
    (bin_dir / "who").write_text(
        "#!/usr/bin/env bash\n"
        "exit 0\n",
        encoding="utf-8",
    )

    # ss: reports a few known ports so SERVICES can check them
    (bin_dir / "ss").write_text(
        "#!/usr/bin/env bash\n"
        "cat <<'EOF'\n"
        "tcp LISTEN 0 128 0.0.0.0:22 0.0.0.0:* users:((\"sshd\",pid=1,fd=1))\n"
        "tcp LISTEN 0 128 127.0.0.1:6900 0.0.0.0:* users:((\"python\",pid=2,fd=1))\n"
        "tcp LISTEN 0 128 127.0.0.1:6333 0.0.0.0:* users:((\"qdrant\",pid=3,fd=1))\n"
        "EOF\n",
        encoding="utf-8",
    )

    # systemctl: pretend no user timers (simplest deterministic option)
    (bin_dir / "systemctl").write_text(
        "#!/usr/bin/env bash\n"
        'if [ "$1" = "--user" ] && [ "$2" = "show-environment" ]; then exit 0; fi\n'
        'if [ "$1" = "--user" ] && [ "$2" = "list-timers" ]; then\n'
        "  printf 'NEXT LEFT LAST PASSED UNIT ACTIVATES\\n'\n"
        "  exit 0\n"
        "fi\n"
        "exit 0\n",
        encoding="utf-8",
    )

    # crontab: empty
    (bin_dir / "crontab").write_text(
        "#!/usr/bin/env bash\n"
        'if [ "$1" = "-l" ]; then exit 1; fi\n'
        "exit 0\n",
        encoding="utf-8",
    )

    for path in bin_dir.iterdir():
        path.chmod(0o755)

    return bin_dir


def render_with_config(home: Path, config_text: str) -> str:
    config = home / ".config" / "welcome-board" / "config"
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(config_text, encoding="utf-8")

    bin_dir = _make_bin_dir(home)

    env = os.environ.copy()
    env["HOME"] = str(home)
    env["WELCOME_BOARD_CONFIG"] = str(config)
    env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
    result = subprocess.run(
        ["bash", "-c", f"source {SCRIPT}; __wb_render"],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


def render_without_config(home: Path) -> str:
    bin_dir = _make_bin_dir(home)

    env = os.environ.copy()
    env["HOME"] = str(home)
    env.pop("WELCOME_BOARD_CONFIG", None)
    env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
    result = subprocess.run(
        ["bash", "-c", f"source {SCRIPT}; __wb_render"],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


class WelcomeBoardConfigTests(unittest.TestCase):
    def test_default_board_shows_new_section_headers(self) -> None:
        """The new design has MACHINE/NETWORK/SECURITY/SERVICES/AUTOMATION/HERMES/COMMANDS."""
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_without_config(Path(raw_tmp))

        # New section headers
        self.assertIn("MACHINE", rendered)
        self.assertIn("NETWORK", rendered)
        self.assertIn("SECURITY", rendered)
        self.assertIn("SERVICES", rendered)
        self.assertIn("AUTOMATION", rendered)
        self.assertIn("HERMES", rendered)
        self.assertIn("COMMANDS", rendered)

        # Old headers must NOT appear
        self.assertNotIn("YOU ARE ON", rendered)
        self.assertNotIn("HEALTH", rendered)
        self.assertNotIn("NOTES", rendered)
        self.assertNotIn("MEMORY-DISK", rendered)
        self.assertNotIn("PRESSURE", rendered)
        self.assertNotIn("CLOCKS", rendered)

        # ssh remote-logins row appears in NETWORK
        self.assertIn("remote", rendered)
        # tmux row appears in NETWORK
        self.assertIn("tmux", rendered)
        # Hermes shortcuts use m1c / m2c shortcuts
        self.assertTrue(
            "m1c" in rendered or "m#c" in rendered,
            "Expected Hermes m1c or m#c shortcut in rendered output",
        )

        # "shim dash" must never appear (label is webdash)
        self.assertNotIn("shim dash", rendered)

        # All framed rows must be exactly 82 display columns
        framed_rows = [line for line in rendered.splitlines() if line.startswith("  │")]
        self.assertTrue(framed_rows)
        self.assertEqual({len(line) for line in framed_rows}, {82})

    def test_config_name_appears_in_greeting(self) -> None:
        """WB_DISPLAY_NAME from config must appear in the greeting line."""
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_with_config(
                Path(raw_tmp),
                "\n".join([
                    'WB_DISPLAY_NAME="Alex"',
                    'WB_BANNER_TEXT="WORKSTATION"',
                    'WB_SERVICE_PORTS="ssh:22 webdash:6900 qdrant:6333"',
                    "",
                ]),
            )

        self.assertIn("Alex", rendered)
        self.assertNotIn("shim dash", rendered)

    def test_new_section_headers_all_present_with_config(self) -> None:
        """Full render with a custom config still shows all 7 new section headers."""
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_with_config(
                Path(raw_tmp),
                "\n".join([
                    'WB_DISPLAY_NAME="Alex"',
                    'WB_BANNER_TEXT="WORKSTATION"',
                    'WB_SERVICE_PORTS="ssh:22 webdash:6900 qdrant:6333"',
                    "",
                ]),
            )

        for hdr in ("MACHINE", "NETWORK", "SECURITY", "SERVICES", "AUTOMATION", "HERMES", "COMMANDS"):
            self.assertIn(hdr, rendered)

        # webdash label present, not "shim dash"
        self.assertIn("webdash", rendered)
        self.assertNotIn("shim dash", rendered)

        # ssh remote-logins row
        self.assertIn("remote", rendered)

        # Hermes shortcuts appear
        self.assertTrue(
            "m1c" in rendered or "m#c" in rendered,
            "Expected Hermes m1c or m#c shortcut in rendered output",
        )

        # All framed rows must be 82 cols
        framed_rows = [line for line in rendered.splitlines() if line.startswith("  │")]
        self.assertTrue(framed_rows)
        self.assertEqual({len(line) for line in framed_rows}, {82})


if __name__ == "__main__":
    unittest.main()
