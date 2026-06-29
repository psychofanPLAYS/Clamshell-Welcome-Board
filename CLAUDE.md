# CLAUDE.md — Clamshell-Welcome-Board

Pure-Bash single-screen terminal status board that prints on interactive shell / SSH login
(machine pressure, network peers, security drift, services, automation, command cheat-sheet).
Linux + macOS, no daemons, no deps beyond a stock shell.

## Layout
- `welcome-board.sh` — the board itself (~58K, sourced from `~/.bashrc`; also runs via `wb render`). All section logic lives here.
- `bin/wb` — operator CLI (`wb`, `wb animate`, `wb doctor`, `wb ports explain|snapshot`); `bin/welcomeboard` thin wrapper.
- `install.sh` — copies user-local files + prints shell-hook lines; **edits nothing itself**.
- `tests/` — Python `unittest` suite; `skills/`, `prompts/` — agent install brief; `docs/` — SECTION_SDK, LLM_EXTENSION_GUIDE, security model.
- Runtime config lives in `~/.config/welcome-board/config` (see `examples/config.example`), never in the repo.

## Commands
```bash
bash -n welcome-board.sh bin/wb bin/welcomeboard install.sh        # syntax check
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v # full suite
bash welcome-board.sh | python3 tests/check_symmetry.py           # prove frame symmetry
```

## Gotchas
- **SYMMETRY LAW (CI-enforced):** every framed row is identical display width. Only width-1 glyphs inside the frame — no emoji, no width-2 chars. `tests/check_symmetry.py` fails the build otherwise.
- **Bash 3.2 safe:** macOS stock `/bin/bash`. No `mapfile`, no associative arrays. CI runs ubuntu + macos.
- Every probe is wrapped `2>/dev/null` with a fallback (`—`). The board must NEVER error or block the prompt.
- Port features are **read-only** (scan/explain/plan/snapshot) — never open/close/firewall anything.
- `welcome-board.sh.bak-20260618-showpiece` is an OLD snapshot, not live — don't edit it.
