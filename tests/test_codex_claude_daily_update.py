from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import re
import tempfile
import unittest
import uuid
from datetime import date as real_date
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "codex-claude-daily-update"
ANSI_RE = re.compile(r"\x1B\[[0-9;]*[mK]")


class FixedDate(real_date):
    @classmethod
    def today(cls) -> "FixedDate":
        return cls(2026, 6, 17)


def receipt(day: str, before: str, after: str, changed: bool = True) -> dict:
    updated = []
    if changed:
        updated.append(
            {
                "key": "claude",
                "label": "Claude",
                "before": before,
                "after": after,
                "changed": True,
            }
        )
    return {
        "date": day,
        "timestamp": f"{day}T06:45:00-04:00",
        "tools": [],
        "updated": updated,
    }


def load_module(tmpdir: Path, history_days: str = "7"):
    log_path = tmpdir / "updates.jsonl"
    state_path = tmpdir / "state.json"
    env = {
        "CODEX_CLAUDE_UPDATE_LOG": str(log_path),
        "CODEX_CLAUDE_UPDATE_STATE": str(state_path),
        "CODEX_CLAUDE_UPDATE_HISTORY_DAYS": history_days,
    }
    with patch.dict(os.environ, env, clear=False):
        name = f"codex_claude_daily_update_{uuid.uuid4().hex}"
        loader = importlib.machinery.SourceFileLoader(name, str(SCRIPT_PATH))
        spec = importlib.util.spec_from_loader(name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
    module.date = FixedDate
    return module


class RollingHistoryTests(unittest.TestCase):
    def write_log(self, path: Path, receipts: list[dict | str]) -> None:
        with path.open("w", encoding="utf-8") as handle:
            for item in receipts:
                if isinstance(item, str):
                    handle.write(item + "\n")
                else:
                    handle.write(json.dumps(item) + "\n")

    def test_rolling_seven_days_excludes_old_future_unchanged_and_bad_rows(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmpdir:
            tmpdir = Path(raw_tmpdir)
            module = load_module(tmpdir)
            self.write_log(
                module.LOG_PATH,
                [
                    receipt("2026-06-10", "2.1.170", "2.1.171"),
                    receipt("2026-06-11", "2.1.171", "2.1.172"),
                    receipt("2026-06-16", "2.1.177", "2.1.178"),
                    receipt("2026-06-17", "2.1.178", "2.1.179"),
                    receipt("2026-06-18", "2.1.179", "2.1.180"),
                    receipt("2026-06-17", "0.140.0", "0.140.0", changed=False),
                    "{bad json",
                ],
            )

            recent = module._load_recent_update_receipts()
            self.assertEqual([item["date"] for item in recent], ["2026-06-17", "2026-06-16", "2026-06-11"])

    def test_notify_shell_renders_pretty_centered_history_box(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmpdir:
            tmpdir = Path(raw_tmpdir)
            module = load_module(tmpdir)
            self.write_log(
                module.LOG_PATH,
                [
                    receipt("2026-06-16", "2.1.177", "2.1.178"),
                    receipt("2026-06-17", "2.1.178", "2.1.179"),
                ],
            )

            buffer = io.StringIO()
            with contextlib.redirect_stdout(buffer):
                self.assertEqual(module.notify_shell(), 0)

            plain = ANSI_RE.sub("", buffer.getvalue())
            lines = [line.rstrip() for line in plain.splitlines()]
            self.assertEqual(lines[0], "                 +-----------------------------------------------+")
            self.assertIn("| AGENT CLI UPDATE HISTORY - last 7 days        |", lines[1])
            self.assertIn("|     TODAY 06:45  Claude: 2.1.178 -> 2.1.179   |", plain)
            self.assertIn("| YESTERDAY 06:45  Claude: 2.1.177 -> 2.1.178   |", plain)
            self.assertTrue(all(line.startswith("                 ") for line in lines if line))

    def test_one_day_window_uses_singular_label_and_only_today(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmpdir:
            tmpdir = Path(raw_tmpdir)
            module = load_module(tmpdir, history_days="1")
            self.write_log(
                module.LOG_PATH,
                [
                    receipt("2026-06-16", "2.1.177", "2.1.178"),
                    receipt("2026-06-17", "2.1.178", "2.1.179"),
                ],
            )

            buffer = io.StringIO()
            with contextlib.redirect_stdout(buffer):
                self.assertEqual(module.notify_shell(), 0)

            plain = ANSI_RE.sub("", buffer.getvalue())
            self.assertIn("last 1 day", plain)
            self.assertIn("TODAY", plain)
            self.assertNotIn("YESTERDAY", plain)

    def test_state_receipt_is_used_when_log_is_missing(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmpdir:
            tmpdir = Path(raw_tmpdir)
            module = load_module(tmpdir)
            module.STATE_PATH.write_text(json.dumps(receipt("2026-06-17", "2.1.178", "2.1.179")), encoding="utf-8")

            recent = module._load_recent_update_receipts()
            self.assertEqual(len(recent), 1)
            self.assertEqual(recent[0]["date"], "2026-06-17")

    def test_recent_log_reader_skips_partial_first_line_when_truncated(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmpdir:
            tmpdir = Path(raw_tmpdir)
            module = load_module(tmpdir)
            old_line = json.dumps(receipt("2026-06-10", "2.1.170", "2.1.171"))
            new_line = json.dumps(receipt("2026-06-17", "2.1.178", "2.1.179"))
            module.LOG_PATH.write_text(old_line + "\n" + new_line + "\n", encoding="utf-8")

            lines = module._read_recent_log_lines(max_bytes=len(new_line) + 4)
            self.assertEqual(lines, [new_line])


if __name__ == "__main__":
    unittest.main()
