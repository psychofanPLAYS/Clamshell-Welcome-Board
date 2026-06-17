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
        self.assertIn("wb setup", prompt)
        self.assertIn("render preview", prompt)


if __name__ == "__main__":
    unittest.main()
