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
        "'NVIDIA GeForce GTX 1060, P8, 19, 49, 3830, 6078, 139, 1911, 405, 4004, 18.2'\n",
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

        # Inline load legend present (no separate misaligned legend line anymore).
        self.assertIn("1m", rendered)
        self.assertIn("15m", rendered)

        # Each metric row carries an 8-cell █░ gauge bar followed by a percent.
        import re as _re
        bar_re = _re.compile(r"[█░]{8}\s+\d+%")
        for label in ("USAGE", "TEMP", "LOAD", "USED", "SWAP", "VRAM", "CORE", "MEMCLK", "ROOT"):
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


if __name__ == "__main__":
    unittest.main()
