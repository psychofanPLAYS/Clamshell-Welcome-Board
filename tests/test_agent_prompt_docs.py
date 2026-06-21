from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class AgentPromptDocsTests(unittest.TestCase):
    def test_agent_install_prompt_exists_and_is_linked_from_readme(self) -> None:
        prompt_path = REPO_ROOT / "prompts" / "install-with-agent.md"
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")

        self.assertTrue(prompt_path.exists(), "missing prompts/install-with-agent.md")
        prompt = prompt_path.read_text(encoding="utf-8")
        self.assertIn("Codex Or Claude", readme)
        self.assertIn("prompts/install-with-agent.md", readme)
        self.assertIn("Do not change firewall rules", prompt)
        self.assertIn("display name", prompt)
        self.assertIn("tmux", prompt)
        self.assertIn("custom commands", prompt)
        self.assertIn("default-deny", prompt)
        self.assertIn("Hermes", prompt)
        private_tool_name = "Open" + "Claw"
        # Private/deleted internal tools must NOT appear in the public install prompt.
        self.assertNotIn(private_tool_name, prompt)
        self.assertIn("wb ports snapshot", prompt)
        self.assertIn("wb setup", prompt)
        self.assertIn("render preview", prompt)
        self.assertIn("read-only review of running apps and listening ports", prompt)
        self.assertIn("psychofanPLAYS/update-all", prompt)
        self.assertIn("Do not install it unless I separately ask", prompt)
        self.assertIn("~/.config/welcome-board/INSTALL_NOTES.md", prompt)
        self.assertIn("project memory", prompt)


if __name__ == "__main__":
    unittest.main()
