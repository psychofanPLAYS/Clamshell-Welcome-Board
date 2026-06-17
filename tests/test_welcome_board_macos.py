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


def render_macos_machine(home: Path) -> str:
    bin_dir = home / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    (bin_dir / "uname").write_text("#!/usr/bin/env bash\nprintf 'Darwin\\n'\n", encoding="utf-8")
    (bin_dir / "sysctl").write_text(
        "#!/usr/bin/env bash\n"
        "case \"$*\" in\n"
        "  *machdep.cpu.brand_string*) printf 'Apple M2\\n' ;;\n"
        "  *hw.logicalcpu*) printf '8\\n' ;;\n"
        "  *hw.memsize*) printf '17179869184\\n' ;;\n"
        "  *) exit 1 ;;\n"
        "esac\n",
        encoding="utf-8",
    )
    (bin_dir / "vm_stat").write_text(
        "#!/usr/bin/env bash\n"
        "cat <<'EOF'\n"
        "Mach Virtual Memory Statistics: (page size of 4096 bytes)\n"
        "Pages active:                               900000.\n"
        "Pages wired down:                           300000.\n"
        "Pages speculative:                          100000.\n"
        "Pages occupied by compressor:               200000.\n"
        "EOF\n",
        encoding="utf-8",
    )
    (bin_dir / "df").write_text(
        "#!/usr/bin/env bash\n"
        "cat <<'EOF'\n"
        "Filesystem 512-blocks      Used Available Capacity iused ifree %iused Mounted on\n"
        "/dev/disk3s1 976490576 244122644 732367932    25% 100000 100000 50% /\n"
        "EOF\n",
        encoding="utf-8",
    )
    for path in bin_dir.iterdir():
        path.chmod(0o755)

    env = os.environ.copy()
    env["HOME"] = str(home)
    env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
    command = f"source {SCRIPT}; __wb_paint; WB_FRAME_ON=1; WB_FRAME_INNER=78; WB_W=78; WB_ZW=78; __wb_machine"
    result = subprocess.run(
        ["bash", "-c", command],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    return ANSI_RE.sub("", result.stdout).replace("\x06", "")


class MacOSMachineTests(unittest.TestCase):
    def test_macos_machine_render_uses_darwin_probes_and_stays_aligned(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            rendered = render_macos_machine(Path(raw_tmp))

        self.assertIn("Apple M2", rendered)
        self.assertIn("macOS", rendered)
        self.assertIn("8t", rendered)
        self.assertIn("PRESSURE", rendered)
        self.assertIn("RAM", rendered)
        self.assertIn("DISK", rendered)
        self.assertIn("CLOCKS", rendered)
        self.assertIn("not exposed", rendered)
        self.assertNotIn("/proc", rendered)

        framed_rows = [line for line in rendered.splitlines() if line.startswith("  │")]
        self.assertTrue(framed_rows)
        self.assertEqual({len(line) for line in framed_rows}, {82})


if __name__ == "__main__":
    unittest.main()
