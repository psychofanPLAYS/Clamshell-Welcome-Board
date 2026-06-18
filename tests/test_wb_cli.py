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


def write_fake_ss(home: Path) -> None:
    bin_dir = home / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    ss = bin_dir / "ss"
    ss.write_text(
        "#!/usr/bin/env bash\n"
        "cat <<'EOF'\n"
        "Netid State  Recv-Q Send-Q Local Address:Port Peer Address:Port Process\n"
        "tcp   LISTEN 0      4096   127.0.0.1:3000      0.0.0.0:*    users:((\"node\",pid=111,fd=7))\n"
        "tcp   LISTEN 0      128    0.0.0.0:22          0.0.0.0:*    users:((\"sshd\",pid=222,fd=3))\n"
        "tcp   LISTEN 0      128    0.0.0.0:8080        0.0.0.0:*    users:((\"python\",pid=333,fd=4))\n"
        "tcp   LISTEN 0      128    100." "64.0.2:443       0.0.0.0:*    users:((\"tailscale\",pid=334,fd=4))\n"
        "udp   UNCONN 0      0      0.0.0.0:5353        0.0.0.0:*    users:((\"mdns\",pid=444,fd=5))\n"
        "EOF\n",
        encoding="utf-8",
    )
    ss.chmod(0o755)


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
        self.assertIn("wb doctor", result.stdout)
        self.assertIn("wb ports scan", result.stdout)
        self.assertIn("wb ports snapshot", result.stdout)
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
            answers = (
                "Alex\n"
                "WORKBOX\n"
                "green-phosphor\n"
                "machine tmux ports\n"
                "/tmp/custom-commands\n"
                "api:8000 dashboard:6900\n"
                "Hermes local\n"
                "/tmp/openclaw\n"
                "/tmp/ports-baseline.txt\n"
            )
            result = run_wb("setup", input_text=answers, home=home)
            self.assertEqual(result.returncode, 0, result.stderr)
            config = (home / ".config" / "welcome-board" / "config").read_text(encoding="utf-8")
            self.assertIn('WB_DISPLAY_NAME="Alex"', config)
            self.assertIn('WB_BANNER_TEXT="WORKBOX"', config)
            self.assertIn('WB_THEME="green-phosphor"', config)
            self.assertIn('WB_SECTIONS="machine tmux ports"', config)
            self.assertIn('WB_CUSTOM_COMMANDS_FILE="/tmp/custom-commands"', config)
            self.assertIn('WB_SERVICE_PORTS="api:8000 dashboard:6900"', config)
            self.assertIn('WB_HERMES_LABEL="Hermes local"', config)
            self.assertIn('WB_OPENCLAW_PATH="/tmp/openclaw"', config)
            self.assertIn('WB_PORT_BASELINE_FILE="/tmp/ports-baseline.txt"', config)

    def test_doctor_reports_readiness_without_mutating(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            result = run_wb("doctor", home=home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Welcome Board doctor", result.stdout)
            self.assertIn("platform:", result.stdout)
            self.assertIn("config:", result.stdout)
            self.assertIn("board:", result.stdout)
            self.assertIn("commands:", result.stdout)
            self.assertIn("No files, services, ports, or firewall rules were changed.", result.stdout)
            self.assertFalse((home / ".config" / "welcome-board" / "config").exists())

            bad_board = home / "bad-board.sh"
            bad_board.write_text("printf bad\\n", encoding="utf-8")
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["WELCOME_BOARD_CONFIG"] = str(home / ".config" / "welcome-board" / "config")
            env["WELCOME_BOARD_BOARD_FILE"] = str(bad_board)
            render_result = subprocess.run(
                [str(WB), "render"],
                text=True,
                capture_output=True,
                env=env,
                check=False,
            )
            self.assertEqual(render_result.returncode, 2)
            self.assertIn("Refusing to source unexpected board file", render_result.stderr)

    def test_ports_unknown_command_does_not_apply_anything(self) -> None:
        result = run_wb("ports", "apply")
        self.assertEqual(result.returncode, 2)
        self.assertIn("not implemented because it would be mutating", result.stderr)

    def test_ports_explain_classifies_listeners_without_mutating(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            write_fake_ss(home)
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{home / 'bin'}:{env.get('PATH', '')}"
            env["WELCOME_BOARD_CONFIG"] = str(home / ".config" / "welcome-board" / "config")

            result = subprocess.run(
                [str(WB), "ports", "explain"],
                text=True,
                capture_output=True,
                env=env,
                check=False,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Read-only port explanation", result.stdout)
        self.assertIn("loopback", result.stdout)
        self.assertIn("127.0.0.1:3000", result.stdout)
        self.assertIn("LAN-visible", result.stdout)
        self.assertIn("0.0.0.0:8080", result.stdout)
        self.assertIn("VPN/private", result.stdout)
        self.assertIn("SSH", result.stdout)
        self.assertIn("No firewall changes were made", result.stdout)

    def test_ports_plan_prints_dry_run_only_and_no_apply_command_runs(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            write_fake_ss(home)
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{home / 'bin'}:{env.get('PATH', '')}"
            env["WELCOME_BOARD_CONFIG"] = str(home / ".config" / "welcome-board" / "config")

            result = subprocess.run(
                [str(WB), "ports", "plan"],
                text=True,
                capture_output=True,
                env=env,
                check=False,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Dry-run port lockdown plan", result.stdout)
        self.assertIn("review these LAN-visible listeners", result.stdout)
        self.assertIn("0.0.0.0:22", result.stdout)
        self.assertIn("0.0.0.0:8080", result.stdout)
        self.assertIn("SSH: do not block until you have another login path", result.stdout)
        self.assertIn("No commands were executed", result.stdout)
        self.assertNotIn("ufw enable", result.stdout)

    def test_ports_snapshot_writes_review_baseline_without_firewall_changes(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            write_fake_ss(home)
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{home / 'bin'}:{env.get('PATH', '')}"
            env["WELCOME_BOARD_CONFIG"] = str(home / ".config" / "welcome-board" / "config")

            result = subprocess.run(
                [str(WB), "ports", "snapshot"],
                text=True,
                capture_output=True,
                env=env,
                check=False,
            )

            baseline = home / ".local" / "state" / "welcome-board" / "ports-baseline.txt"
            baseline_exists = baseline.exists()
            saved = baseline.read_text(encoding="utf-8") if baseline_exists else ""
            result_again = subprocess.run(
                [str(WB), "ports", "snapshot"],
                text=True,
                capture_output=True,
                env=env,
                check=False,
            )
            backups = list(baseline.parent.glob("ports-baseline.txt.bak.*"))

            config = home / ".config" / "welcome-board" / "config"
            config.parent.mkdir(parents=True, exist_ok=True)
            config.write_text('WB_PORT_BASELINE_FILE="/tmp/wb-outside-baseline.txt"\n', encoding="utf-8")
            refused = subprocess.run(
                [str(WB), "ports", "snapshot"],
                text=True,
                capture_output=True,
                env=env,
                check=False,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result_again.returncode, 0, result_again.stderr)
        self.assertTrue(baseline_exists)
        self.assertIn("SSH:22(sshd)", saved)
        self.assertIn("common dev server:8080(python)", saved)
        self.assertIn("Saved reviewed port baseline", result.stdout)
        self.assertIn("No firewall changes were made", result.stdout)
        self.assertTrue(backups)
        self.assertEqual(refused.returncode, 2)
        self.assertIn("Refusing WB_PORT_BASELINE_FILE outside $HOME", refused.stderr)


if __name__ == "__main__":
    unittest.main()
