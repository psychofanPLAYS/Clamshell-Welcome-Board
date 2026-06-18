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
        ["bash", "-c", f"source {SCRIPT}; __wb_render"],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


def render_without_config(home: Path) -> str:
    hermes_dir = home / ".hermes"
    hermes_dir.mkdir()
    (hermes_dir / "active_profile").write_text("master-1-codex\n", encoding="utf-8")

    bin_dir = home / "bin"
    bin_dir.mkdir()
    (bin_dir / "tmux").write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
    (bin_dir / "tmux").chmod(0o755)
    (bin_dir / "tailscale").write_text(
        "#!/usr/bin/env bash\n"
        "if [ \"$1\" = \"ip\" ]; then printf '100.118.201.91\\n'; exit 0; fi\n"
        "cat <<'EOF'\n"
        "100.118.201.91 clamshell user linux -\n"
        "100.117.254.106 m2-mac-air user macOS -\n"
        "100.103.31.3 xtreme user windows offline\n"
        "EOF\n",
        encoding="utf-8",
    )
    (bin_dir / "who").write_text(
        "#!/usr/bin/env bash\n"
        "cat <<'EOF'\n"
        "dawid pts/1 2026-06-18 01:00 00:05 1234 (100.117.254.106)\n"
        "EOF\n",
        encoding="utf-8",
    )
    (bin_dir / "ss").write_text(
        "#!/usr/bin/env bash\n"
        "cat <<'EOF'\n"
        "tcp LISTEN 0 4096 127.0.0.1:6333 0.0.0.0:* users:((\"qdrant\",pid=10,fd=7))\n"
        "tcp LISTEN 0 4096 100.118.201.91:6900 0.0.0.0:* users:((\"python\",pid=11,fd=7))\n"
        "tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:* users:((\"sshd\",pid=12,fd=7))\n"
        "EOF\n",
        encoding="utf-8",
    )
    for path in bin_dir.iterdir():
        path.chmod(0o755)

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
    def test_default_board_shows_online_and_ports_at_a_glance(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_without_config(Path(raw_tmp))

        self.assertIn("YOU ARE ON", rendered)
        self.assertIn("SECURITY", rendered)
        self.assertIn("SERVICES", rendered)
        self.assertIn("HEALTH", rendered)
        self.assertIn("HERMES", rendered)
        self.assertIn("NOTES", rendered)
        self.assertIn("host", rendered)
        self.assertIn("ip", rendered)
        self.assertIn("pts/1", rendered)
        self.assertIn("LAN/ALL", rendered)
        self.assertIn("SSH:22", rendered)
        self.assertIn("loopback", rendered)
        self.assertIn("qdrant", rendered)
        self.assertIn("sshd", rendered)
        self.assertIn("new open", rendered)
        self.assertIn("ports snapshot", rendered)
        self.assertIn("m1g", rendered)
        self.assertIn("m2s", rendered)

    def test_custom_commands_and_optional_project_notes_render_from_config(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            commands = home / "commands.txt"
            commands.write_text(
                "WORK|cd ~/work|open my work folder\n"
                "AGENTS|cd ~/.AGENTS|open operator notes\n",
                encoding="utf-8",
            )
            openclaw = home / "OpenClaw"
            openclaw.mkdir()
            rendered = render_with_config(
                home,
                "\n".join(
                    [
                        'WB_DISPLAY_NAME="Alex"',
                        'WB_BANNER_TEXT="WORKBOX"',
                        'WB_THEME="cyan-dark"',
                        'WB_SECTIONS="custom notes"',
                        f'WB_CUSTOM_COMMANDS_FILE="{commands}"',
                        f'WB_OPENCLAW_PATH="{openclaw}"',
                        'WB_HERMES_LABEL="Hermes local helper"',
                        "",
                    ]
                ),
            )

        self.assertIn("CUSTOM", rendered)
        self.assertIn("WORK", rendered)
        self.assertIn("cd ~/work", rendered)
        self.assertIn("AGENTS", rendered)
        self.assertIn("Hermes local helper", rendered)
        self.assertIn("OpenClaw", rendered)
        self.assertIn("configured", rendered)

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
