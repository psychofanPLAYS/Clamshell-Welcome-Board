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
    command = f"source {SCRIPT}; __wb_paint; WB_FRAME_ON=1; WB_FRAME_INNER=78; WB_W=78; WB_ZW=78; __wb_machine"
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
        "WB_W=78; WB_ZW=78; __wb_loadrow 15 1.25 1.07 1.05 '1d 23h 3m' '▁▁▁▁▁▁▁▂'"
    )
    result = subprocess.run(
        ["bash", "-c", command],
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


class MachineSectionTests(unittest.TestCase):
    def test_load_legend_is_centered_under_load_values(self) -> None:
        rendered = render_load_row()
        load_line = next(line for line in rendered.splitlines() if "LOAD" in line)
        load_legend = next(line for line in rendered.splitlines() if "1m" in line and "15m" in line)

        for value, label in (("1.25", "1m"), ("1.07", "5m"), ("1.05", "15m")):
            self.assertEqual(load_line.index(value), load_legend.index(label))
        self.assertNotIn("·", load_legend)
        self.assertNotIn("(", load_legend)
        self.assertNotIn(")", load_legend)

    def test_machine_rows_are_grouped_have_graphs_and_stay_aligned(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            home = Path(raw_tmp)
            (home / "bin").mkdir()
            (home / "bin" / "uname").write_text(
                "#!/usr/bin/env bash\nprintf 'Linux\\n'\n",
                encoding="utf-8",
            )
            (home / "bin" / "nproc").write_text(
                "#!/usr/bin/env bash\nprintf '8\\n'\n",
                encoding="utf-8",
            )
            (home / "bin" / "free").write_text(
                "#!/usr/bin/env bash\n"
                "cat <<'EOF'\n"
                "              total        used        free      shared  buff/cache   available\n"
                "Mem:          16000        8000        2000         100        6000        7000\n"
                "Swap:          8000        2000        6000\n"
                "EOF\n",
                encoding="utf-8",
            )
            (home / "bin" / "df").write_text(
                "#!/usr/bin/env bash\n"
                "if [ \"$1\" = \"-BG\" ]; then\n"
                "  printf ' Used 1B-blocks Use%%\\n80 400 20\\n'\n"
                "else\n"
                "  /bin/df \"$@\" 2>/dev/null || /usr/bin/df \"$@\"\n"
                "fi\n",
                encoding="utf-8",
            )
            (home / "bin" / "nvidia-smi").write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\n' 'NVIDIA GeForce GTX 1060, P8, 19, 49, 3830, 6078, 139, 1911, 405, 4004, 18.2'\n",
                encoding="utf-8",
            )
            for path in (home / "bin").iterdir():
                path.chmod(0o755)

            first = render_machine_section(home)
            second = render_machine_section(home)

        self.assertIn("CPU", second)
        self.assertIn("GPU", second)
        self.assertIn("MEMORY / DISK", second)
        self.assertNotIn("PRESSURE", second)
        self.assertNotIn("CLOCKS", second)
        self.assertRegex(second, r"TEMP\s+[█░]{8}\s+\d+%\s+[▁▂▃▄▅▆▇█]{8}.*CPU")
        self.assertRegex(second, r"USAGE\s+[█░]{8}\s+\d+%\s+[▁▂▃▄▅▆▇█]{8}.*8t")
        self.assertRegex(second, r"TEMP\s+[█░]{8}\s+49%\s+[▁▂▃▄▅▆▇█]{8}.*GPU")
        self.assertRegex(second, r"CORE\s+.*139/1911 MHz")
        self.assertRegex(second, r"USAGE\s+[█░]{8}\s+19%\s+[▁▂▃▄▅▆▇█]{8}.*GTX 1060")
        self.assertRegex(second, r"VRAM\s+[█░]{8}\s+63%\s+[▁▂▃▄▅▆▇█]{8}")
        self.assertRegex(second, r"MEMCLK\s+.*405/4004 MHz")
        self.assertRegex(second, r"RAM\s+[█░]{8}\s+\d+%\s+[▁▂▃▄▅▆▇█]{8}")
        self.assertRegex(second, r"SWAP\s+[█░]{8}\s+\d+%\s+[▁▂▃▄▅▆▇█]{8}")
        self.assertRegex(second, r"DISK\s+[█░]{8}\s+\d+%\s+[▁▂▃▄▅▆▇█]{8}")
        self.assertRegex(second, r"LOAD\s+[█░]{8}\s+\d+%\s+[▁▂▃▄▅▆▇█]{8}")

        cpu_header = second.index("CPU")
        ctemp_row = second.index("TEMP", cpu_header)
        usage_row = second.index("USAGE")
        load_row = second.index("LOAD")
        gpu_header = second.index("GPU", load_row)
        gtemp_row = second.index("TEMP", gpu_header)
        core_row = second.index("CORE")
        guse_row = second.index("USAGE", core_row)
        vram_row = second.index("VRAM")
        memclk_row = second.index("MEMCLK")
        memory_header = second.index("MEMORY / DISK")
        ram_row = second.index("RAM", memory_header)
        swap_row = second.index("SWAP")
        disk_row = second.index("DISK", swap_row)
        self.assertLess(cpu_header, ctemp_row)
        self.assertLess(ctemp_row, usage_row)
        self.assertLess(usage_row, load_row)
        self.assertLess(load_row, gpu_header)
        self.assertLess(gpu_header, gtemp_row)
        self.assertLess(gtemp_row, core_row)
        self.assertLess(core_row, guse_row)
        self.assertLess(guse_row, vram_row)
        self.assertLess(vram_row, memclk_row)
        self.assertLess(memclk_row, memory_header)
        self.assertLess(memory_header, ram_row)
        self.assertLess(ram_row, swap_row)
        self.assertLess(swap_row, disk_row)

        for confusing_label in ("history", "hitory", "sample", "8sample", "trend"):
            self.assertNotIn(confusing_label, second.lower())

        framed_rows = [line for line in second.splitlines() if line.startswith("  │")]
        self.assertTrue(framed_rows)
        self.assertEqual({len(line) for line in framed_rows}, {82})


if __name__ == "__main__":
    unittest.main()
