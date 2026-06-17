from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class ContributionArtifactsTests(unittest.TestCase):
    def test_public_contribution_files_exist_and_are_safety_first(self) -> None:
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        contributing = REPO_ROOT / "CONTRIBUTING.md"
        bug = REPO_ROOT / ".github" / "ISSUE_TEMPLATE" / "bug_report.md"
        feature = REPO_ROOT / ".github" / "ISSUE_TEMPLATE" / "feature_request.md"
        pull_request = REPO_ROOT / ".github" / "pull_request_template.md"

        self.assertIn("CONTRIBUTING.md", readme)
        for path in (contributing, bug, feature, pull_request):
            self.assertTrue(path.exists(), f"{path.relative_to(REPO_ROOT)} should exist")

        contribution_text = contributing.read_text(encoding="utf-8")
        self.assertIn("PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v", contribution_text)
        self.assertIn("bash -n welcome-board.sh bin/wb bin/welcomeboard install.sh", contribution_text)
        self.assertIn("license", contribution_text.lower())
        self.assertIn("read-only", contribution_text.lower())
        self.assertIn("do not change firewall", contribution_text.lower())

        template_text = "\n".join(
            path.read_text(encoding="utf-8") for path in (bug, feature, pull_request)
        ).lower()
        for required in ("platform", "expected behavior", "verification", "safety"):
            self.assertIn(required, template_text)
        for forbidden in ("ufw enable", "iptables", "pfctl -e", "sudo rm"):
            self.assertNotIn(forbidden, template_text)


if __name__ == "__main__":
    unittest.main()
