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


def render_machine_section(home: Path) -> str:
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["PATH"] = f"{home / 'bin'}:{env.get('PATH', '')}"
    command = (
        f"source {SCRIPT}; __wb_paint; "
        "WB_FRAME_ON=1; WB_FRAME_INNER=78; WB_W=78; WB_ZW=78; __wb_machine"
    )
    result = subprocess.run(
        ["bash", "-c", command],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


def render_load_row() -> str:
    command = (
        f"source {SCRIPT}; __wb_paint; WB_FRAME_ON=1; WB_FRAME_INNER=78; "
        "WB_W=78; WB_ZW=78; __wb_loadrow 15 1.25 1.07 1.05 '1d 23h 3m'"
    )
    result = subprocess.run(
        ["bash", "-c", command],
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


def run_board_function(function_body: str, env: dict[str, str]) -> str:
    command = f"source {SCRIPT}; __wb_paint >/dev/null; {function_body}"
    result = subprocess.run(
        ["bash", "-c", command],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout.strip()


def _write_linux_mocks(bin_dir: Path) -> None:
    (bin_dir / "uname").write_text(
        "#!/usr/bin/env bash\nprintf 'Linux\\n'\n",
        encoding="utf-8",
    )
    (bin_dir / "nproc").write_text(
        "#!/usr/bin/env bash\nprintf '8\\n'\n",
        encoding="utf-8",
    )
    (bin_dir / "free").write_text(
        "#!/usr/bin/env bash\n"
        "cat <<'EOF'\n"
        "              total        used        free      shared  buff/cache   available\n"
        "Mem:          16000        8000        2000         100        6000        7000\n"
        "Swap:          8000        2000        6000\n"
        "EOF\n",
        encoding="utf-8",
    )
    (bin_dir / "df").write_text(
        "#!/usr/bin/env bash\n"
        'if [ "$1" = "-BG" ]; then\n'
        "  printf ' Used 1B-blocks Use%%\\n80 400 20\\n'\n"
        "else\n"
        "  /bin/df \"$@\" 2>/dev/null || /usr/bin/df \"$@\"\n"
        "fi\n",
        encoding="utf-8",
    )
    (bin_dir / "nvidia-smi").write_text(
        "#!/usr/bin/env bash\n"
        "printf '%s\\n' "
        "'NVIDIA GeForce GTX 1060, P8, 19, 49, 3830, 6078, 139, 1911, 405, 4004, 18.2, 120.0'\n",
        encoding="utf-8",
    )
    for path in bin_dir.iterdir():
        path.chmod(0o755)


class MachineSectionTests(unittest.TestCase):
    def test_load_legend_appears(self) -> None:
        """The LOAD row must be followed by a legend line with 1m / 5m / 15m."""
        rendered = render_load_row()
        self.assertIn("LOAD", rendered)
        lines = rendered.splitlines()
        load_line = next((l for l in lines if "LOAD" in l), None)
        self.assertIsNotNone(load_line, "LOAD row not found")
        legend_line = next((l for l in lines if "1m" in l and "15m" in l), None)
        self.assertIsNotNone(legend_line, "Load legend (1m/15m) not found")
        # Legend must contain the three period labels
        self.assertIn("5m", legend_line)
        self.assertNotIn("up 1d", load_line)
        self.assertEqual(load_line.index("1.25"), legend_line.index("1m"))
        self.assertEqual(load_line.index("1.07"), legend_line.index("5m"))
        self.assertEqual(load_line.index("1.05"), legend_line.index("15m"))

    def test_machine_rows_have_gauge_bars_and_correct_rows(self) -> None:
        """Linux MACHINE: segregated CPU/RAM/GPU/DISK groups; each metric row has an 8-cell bar."""
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            bin_dir = home / "bin"
            bin_dir.mkdir()
            _write_linux_mocks(bin_dir)

            rendered = render_machine_section(home)

        # The four segregated group sub-headers must all appear.
        for group in ("CPU", "RAM", "GPU", "DISK"):
            self.assertIn(group, rendered)

        # Load legend is on its own aligned row below the three readings.
        self.assertIn("1m", rendered)
        self.assertIn("15m", rendered)

        # Each metric row carries an 8-cell █░ gauge bar followed by a percent.
        import re as _re
        bar_re = _re.compile(r"[█░]{8}\s+\d+%")
        for label in ("USAGE", "POWER", "TEMP", "LOAD", "USED", "SWAP", "VRAM", "CORE", "MEMCLK", "ROOT"):
            # Rows look like:  │ LABEL  ████░░░░  NN%  <spark>  detail
            label_line = next(
                (l for l in rendered.splitlines() if re.search(r"│ " + label + r"\b", l)),
                None,
            )
            self.assertIsNotNone(label_line, f"Metric row for {label} not found")
            self.assertRegex(
                label_line,
                bar_re,
                f"{label} row should contain an 8-cell bar and percent",
            )

        # Old subheaders / merged group from previous designs must NOT appear.
        self.assertNotIn("MEMORY / DISK", rendered)
        self.assertNotIn("PRESSURE", rendered)
        self.assertNotIn("CLOCKS", rendered)

        # All framed rows are 82 display columns.
        framed_rows = [line for line in rendered.splitlines() if line.startswith("  │")]
        self.assertTrue(framed_rows)
        self.assertEqual({len(line) for line in framed_rows}, {82})

    def test_cpu_usage_samples_proc_stat_with_real_delay(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            bin_dir = home / "bin"
            bin_dir.mkdir()
            stat_file = home / "stat"
            sleep_marker = home / "sleep-called"
            stat_file.write_text("cpu  1000 0 0 900 0 0 0 0 0 0\n", encoding="utf-8")
            (bin_dir / "sleep").write_text(
                "#!/usr/bin/env bash\n"
                f"printf called > {sleep_marker}\n"
                f"printf 'cpu  1100 0 0 950 0 0 0 0 0 0\\n' > {stat_file}\n",
                encoding="utf-8",
            )
            (bin_dir / "sleep").chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
            env["WB_CPU_STAT_FILE"] = str(stat_file)

            output = run_board_function("__wb_cpubusy", env)

            self.assertEqual(output, "66")
            self.assertTrue(sleep_marker.exists(), "CPU usage must wait for a second /proc/stat sample")

    def test_network_rate_samples_proc_net_dev_with_positive_default_delay(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            bin_dir = home / "bin"
            bin_dir.mkdir()
            net_file = home / "net-dev"
            sleep_marker = home / "sleep-called"
            net_file.write_text(
                "Inter-|   Receive                                                |  Transmit\n"
                " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
                "test0: 1000 0 0 0 0 0 0 0 2000 0 0 0 0 0 0 0\n",
                encoding="utf-8",
            )
            (bin_dir / "sleep").write_text(
                "#!/usr/bin/env bash\n"
                f"printf called > {sleep_marker}\n"
                f"cat > {net_file} <<'EOF'\n"
                "Inter-|   Receive                                                |  Transmit\n"
                " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
                "test0: 205800 0 0 0 0 0 0 0 104400 0 0 0 0 0 0 0\n"
                "EOF\n",
                encoding="utf-8",
            )
            (bin_dir / "ip").write_text(
                "#!/usr/bin/env bash\nprintf 'default via 192.0.2.1 dev test0\\n'\n",
                encoding="utf-8",
            )
            for path in bin_dir.iterdir():
                path.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
            env["WB_NET_DEV_FILE"] = str(net_file)

            output = run_board_function("__wb_netrate", env)

            self.assertEqual(output, "test0 1000 500")
            self.assertTrue(sleep_marker.exists(), "Network rate must wait for a second counter sample")

    def test_recent_window_label_grows_to_two_hour_cap(self) -> None:
        env = os.environ.copy()
        output = run_board_function(
            "__wb_recent_label 1700007200 1700006600; printf '\\n'; "
            "__wb_recent_label 1700007200 1700000000; printf '\\n'; "
            "__wb_recent_label 1700007200 1699990000",
            env,
        )

        self.assertEqual(output.splitlines(), ["10M", "2H", "2H"])

    def test_recent_gpu_graph_uses_board_samples_and_honest_window_label(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            hist_file = home / "machine-series.tsv"
            hist_file.write_text(
                "1700000000\tgpu\t0\n"
                "1700003600\tgpu\t25\n"
                "1700006900\tgpu\t75\n"
                "1700007200\tgpu\t100\n",
                encoding="utf-8",
            )
            env = os.environ.copy()
            env["WELCOME_BOARD_MACHINE_HISTORY"] = str(hist_file)
            env["WB_NOW"] = "1700007200"
            output = run_board_function("__wb_recent_series graph gpu", env)
            plain_output = ANSI_RE.sub("", output)

        self.assertIn("2H", plain_output)
        self.assertRegex(plain_output, r"[▁▂▃▄▅▆▇█]{4,}")

    def test_machine_section_adds_cpu_and_gpu_recent_rows(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            bin_dir = home / "bin"
            bin_dir.mkdir()
            _write_linux_mocks(bin_dir)
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
            env["WB_NOW"] = "1700007200"
            env["WELCOME_BOARD_MACHINE_HISTORY"] = str(home / "machine-series.tsv")
            env["WB_CPU_RECENT_SOURCE"] = "history"
            command = (
                f"source {SCRIPT}; __wb_paint; WB_FRAME_ON=1; WB_FRAME_INNER=78; "
                "WB_W=78; WB_ZW=78; "
                "__wb_hist_add cpu 10; __wb_hist_add gpu 19; __wb_machine"
            )
            result = subprocess.run(
                ["bash", "-c", command],
                env=env,
                text=True,
                capture_output=True,
                check=True,
            )
            rendered = ANSI_RE.sub("", result.stdout).replace("\x06", "")

        recent_lines = [line for line in rendered.splitlines() if "RECENT" in line]
        self.assertGreaterEqual(len(recent_lines), 2)
        self.assertTrue(any("CPU" in line for line in recent_lines))
        self.assertTrue(any("GPU" in line for line in recent_lines))


if __name__ == "__main__":
    unittest.main()
