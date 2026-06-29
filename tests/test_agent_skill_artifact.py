from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class AgentSkillArtifactTests(unittest.TestCase):
    def test_optional_ai_skill_is_present_linked_and_safety_first(self) -> None:
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        skill_path = REPO_ROOT / "skills" / "welcome-board-installer" / "SKILL.md"

        self.assertIn("skills/welcome-board-installer/SKILL.md", readme)
        self.assertTrue(skill_path.exists(), "missing optional AI skill artifact")

        skill = skill_path.read_text(encoding="utf-8")
        self.assertRegex(skill, r"(?s)^---\nname: welcome-board-installer\ndescription: .+?\n---")
        for required in (
            "Read README.md",
            "docs/SECTION_SDK.md",
            "Ask the user",
            "tmux",
            "custom commands",
            "default-deny",
            "Hermes",
            "wb ports snapshot",
            "read-only running-app/listening-port exposure review",
            "~/.config/welcome-board/INSTALL_NOTES.md",
            "project memory",
            "Run ./install.sh",
            "Run wb setup",
            "Run wb doctor",
            "Do not change firewall rules",
            "psychofanPLAYS/update-all",
            "do not install it unless separately requested",
            "PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v",
        ):
            self.assertIn(required, skill)
        private_tool_name = "Open" + "Claw"
        # Private/deleted internal tools must NOT ship in the public skill.
        self.assertNotIn(private_tool_name, skill)
        self.assertIsNone(re.search(r"\b(claw" + r"ski|Da" + r"wid|192\.168\.|/home/claw" + r"ski)\b", skill))


if __name__ == "__main__":
    unittest.main()
