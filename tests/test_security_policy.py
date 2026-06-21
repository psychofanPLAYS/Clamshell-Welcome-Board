from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class SecurityPolicyTests(unittest.TestCase):
    def test_security_policy_documents_read_only_port_boundary(self) -> None:
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        policy_path = REPO_ROOT / "SECURITY.md"

        self.assertIn("SECURITY.md", readme)
        self.assertTrue(policy_path.exists(), "GitHub should see a root SECURITY.md")

        policy = policy_path.read_text(encoding="utf-8")
        for expected in (
            "No firewall changes",
            "read-only",
            "wb ports scan",
            "wb ports explain",
            "wb ports plan",
            "does not install a daemon",
            "listen on a socket",
            "expose a web UI",
            "enable tunnels",
            "WELCOME_BOARD_ALLOW_UNTRUSTED_BOARD_FILE",
            "Do not report secrets",
        ):
            self.assertIn(expected, policy)


if __name__ == "__main__":
    unittest.main()
