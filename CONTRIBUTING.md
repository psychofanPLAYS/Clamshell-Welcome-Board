# Contributing

Thanks for helping improve Clamshell Welcome Board.

This project is a local-first shell tool, so changes should be boring in the best way: fast startup, graceful fallbacks, clean terminal output, and no surprise system changes.

## Current License Status

The project license is not finalized yet. Do not copy large external code into this repository or assume redistribution rights until a `LICENSE` file is added by the project owner.

## Safety Rules

- Do not change firewall rules, SSH settings, system services, cron jobs, or shell startup files without a separate explicit approval flow.
- Keep `wb ports scan`, `wb ports explain`, and `wb ports plan` read-only.
- Keep personal names, private IPs, private hostnames, private paths, and secrets out of committed defaults.
- Make missing tools degrade gracefully instead of crashing the board.
- Keep shell startup fast. Slow probes need a timeout or should move behind an explicit command.

## Development Setup

```bash
git clone https://github.com/psychofanPLAYS/Clamshell-Welcome-Board.git
cd Clamshell-Welcome-Board
./install.sh
wb setup
wb doctor
```

The installer copies files and prints shell hook lines. It does not edit shell startup files by itself.

## Verification

Run these before opening a pull request:

```bash
bash -n welcome-board.sh bin/wb bin/welcomeboard install.sh
python3 -m py_compile codex-claude-daily-update
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
git diff --check
```

For visual changes, also render a stripped preview and check that rows stay aligned:

```bash
bash welcome-board.sh | sed -r 's/\x1B\[[0-9;]*[mK]//g'
```

## Adding A Section

1. Add a probe that returns plain values and accepts missing tools.
2. Add a renderer that fits inside the frame.
3. Gate the section behind config.
4. Add focused tests for the enabled and missing-tool paths.
5. Update `docs/LLM_EXTENSION_GUIDE.md` if the section introduces new conventions.

## Pull Request Checklist

- Explain the user-visible change.
- Include the verification commands you ran.
- Mention Linux and macOS impact.
- Note any safety/privacy concerns.
- Confirm no firewall, SSH, service, cron, shell-startup, license, or repository-visibility change is included unless that is the explicit purpose of the PR.
