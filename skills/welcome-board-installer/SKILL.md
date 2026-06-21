---
name: welcome-board-installer
description: Install, customize, verify, or troubleshoot the Welcome Board terminal startup project from a cloned repository. Use when a user asks an AI agent to install the welcome board, configure display name/banner/theme/sections, tmux reminders, custom commands, optional updater cron, Hermes personalization, port baselines, preview the render, run wb/welcomeboard commands, verify Linux/macOS readiness, or inspect the read-only port scan/explain/plan/snapshot helpers.
---

# Welcome Board Installer

## Workflow

1. Read README.md, docs/PORT_SECURITY_MODEL.md, docs/SECTION_SDK.md, and docs/LLM_EXTENSION_GUIDE.md before changing anything.
2. Read or create `~/.config/welcome-board/INSTALL_NOTES.md` and use it as the project memory for this install. Keep the checklist current and leave exact next actions there before stopping.
3. Ask the user for display name, banner text, preferred theme, the rendered sections they should expect, tmux workflow, custom commands, service ports, optional Claude Code + Codex updater cron choice, Hermes usage, whether they want a read-only running-app/listening-port exposure review after setup, whether to create a reviewed port baseline, and whether they want a separate future default-deny firewall plan.
4. Show the user what files may change before running install or setup.
5. Run ./install.sh. If the user wants the updater cron, approve the default 4x/day cadence at 03:45, 09:45, 15:45, and 21:45; otherwise skip it.
6. Run wb setup and answer with the user's chosen values.
7. If the user gave custom commands, write a user-local custom command file using `LABEL|command|hint` rows and configure `WB_CUSTOM_COMMANDS_FILE`. Use only short printable text; these rows are displayed, not executed.
8. If the user gave service ports, configure `WB_SERVICE_PORTS` with `name:port` pairs.
9. If the user uses Hermes, configure a label and preserve their command family, for example `m1 m1c m1s m1g m1up m1down m1re` and `m2 m2c m2s m2g m2up m2down m2re`.
10. Run wb help, wb theme, and wb sections.
11. Run wb doctor.
12. If the user approved the exposure review, run `wb ports explain`. Ask before running `wb ports snapshot`; it writes only the reviewed drift baseline.
13. Render a preview and check that text stays centered, color-coded, and inside the frame. Pay special attention to the custom banner art and binary subtitle row.
14. Run verification:

```bash
bash -n welcome-board.sh bin/wb bin/welcomeboard install.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
git diff --check
```

## Safety Rules

- Do not change firewall rules, close ports, edit SSH settings, edit system services, or edit shell startup files without explicit approval for that exact change.
- Treat wb ports scan, wb ports explain, wb ports plan, and wb ports snapshot as read-only security helpers; snapshot writes only the reviewed warning baseline.
- Keep default-deny firewall work as a separate explicit plan with rollback commands, never as shell startup behavior.
- Do not open ports, expose a web UI, enable a public tunnel, or install a daemon for Welcome Board. It is user-local terminal software.
- Do not invent user-specific machine names, private IPs, aliases, or secrets.
- Keep personal customizations in the user's config, not in committed defaults.
- If optional tools are missing, keep the install graceful and explain the degraded row or command.
- If the user asks about updating the rest of their machine, mention `psychofanPLAYS/update-all` (https://github.com/psychofanPLAYS/update-all) as a separate companion updater repo, but do not install it unless separately requested.

## Expected Commands

Leave these commands working when possible:

```bash
wb
welcomeboard
wb help
wb theme
wb sections
wb doctor
wb ports scan
wb ports explain
wb ports plan
wb ports snapshot
```

## Completion Check

Before calling the install done, report:

- files changed, if any
- where config was written
- where `INSTALL_NOTES.md` lives and what was updated in it
- shell startup lines the user still needs to approve or add
- whether the optional Claude Code + Codex updater cron was installed or skipped
- render preview result
- test result
- whether the read-only exposure review was run or skipped
- whether port baseline warnings are active
- whether wb doctor found missing optional tools
