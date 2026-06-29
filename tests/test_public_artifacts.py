from __future__ import annotations

import unittest
from pathlib import Path
import subprocess


REPO_ROOT = Path(__file__).resolve().parents[1]


class PublicArtifactsTests(unittest.TestCase):
    def test_readme_links_checked_in_demo_output(self) -> None:
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        demo_path = REPO_ROOT / "docs" / "demo-output.txt"

        self.assertIn("docs/demo-output.txt", readme)
        self.assertTrue(demo_path.exists(), "docs/demo-output.txt should show a public-safe render preview")

        demo = demo_path.read_text(encoding="utf-8")
        for expected in ("MACHINE", "NETWORK", "SECURITY", "SERVICES",
                         "AUTOMATION", "HERMES", "COMMANDS", "CPU", "tmux"):
            self.assertIn(expected, demo)
        self.assertNotIn("LOCAL AI", demo)
        for stale_heading in ("PRESSURE", "CLOCKS", "MEMORY / DISK", "YOU ARE ON"):
            self.assertNotIn(stale_heading, demo)
        forbidden_values = (
            "claw" + "ski",
            "Da" + "wid",
            "192." + "168.",
            "100.",
            "/home/" + "claw" + "ski",
            "histo" + "ry",
            "hit" + "ory",
            "sam" + "ple",
            "8sam" + "ple",
            "tr" + "end",
        )
        for forbidden in forbidden_values:
            self.assertNotIn(forbidden.lower(), demo.lower())

    def test_screenshot_redactor_only_touches_network_ips(self) -> None:
        sample = (
            "├─ MACHINE ─\n"
            "│ host 198.51.100.44 stays for non-network tests │\n"
            "├─ NETWORK ─\n"
            "│ self 203.0.113.10 · this machine │\n"
            "│ peer fd7a:115c:a1e0::1 online │\n"
            "├─ SECURITY ─\n"
            "│ port 127.0.0.1 is not in network anymore │\n"
        )
        proc = subprocess.run(
            ["python3", "tools/redact-network-ips.py"],
            input=sample,
            text=True,
            cwd=REPO_ROOT,
            check=True,
            stdout=subprocess.PIPE,
        )
        redacted = proc.stdout
        self.assertIn("198.51.100.44", redacted)
        self.assertIn("127.0.0.1", redacted)
        self.assertNotIn("203.0.113.10", redacted)
        self.assertNotIn("fd7a:115c:a1e0::1", redacted)
        self.assertIn("xxxxxxxxxxxx", redacted)


if __name__ == "__main__":
    unittest.main()
