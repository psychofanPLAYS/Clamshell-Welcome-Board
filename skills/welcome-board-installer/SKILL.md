---
name: welcome-board-installer
description: Install, customize, verify, or troubleshoot the Clamshell Welcome Board terminal startup project from a cloned repository. Use when a user asks an AI agent to install the welcome board, configure display name/banner/theme/sections, tmux reminders, custom commands, Hermes personalization, port baselines, preview the render, run wb/welcomeboard commands, verify Linux/macOS readiness, or inspect the read-only port scan/explain/plan/snapshot helpers.
---

# Welcome Board Installer

## Workflow

1. Read README.md, docs/PORT_SECURITY_MODEL.md, docs/SECTION_SDK.md, and docs/LLM_EXTENSION_GUIDE.md before changing anything.
2. Ask the user for display name, banner text, preferred theme, the rendered sections they should expect, tmux workflow, custom commands, service ports, Hermes usage, whether to create a reviewed port baseline, and whether they want a separate future default-deny firewall plan.
3. Show the user what files may change before running install or setup.
4. Run ./install.sh.
5. Run wb setup and answer with the user's chosen values.
6. If the user gave custom commands, write a user-local custom command file using `LABEL|command|hint` rows and configure `WB_CUSTOM_COMMANDS_FILE`.
7. If the user gave service ports, configure `WB_SERVICE_PORTS` with `name:port` pairs.
8. If the user uses Hermes, configure a label and preserve their command family, for example `m1 m1c m1s m1g m1up m1down m1re` and `m2 m2c m2s m2g m2up m2down m2re`.
9. Run wb help, wb theme, and wb sections.
10. Run wb doctor.
11. Run `wb ports explain`. Ask before running `wb ports snapshot`; it writes only the reviewed drift baseline.
12. Render a preview and check that text stays inside the frame.
13. Run verification:

```bash
bash -n welcome-board.sh bin/wb bin/welcomeboard install.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
git diff --check
```

## Safety Rules

- Do not change firewall rules, close ports, edit SSH settings, edit system services, or edit shell startup files without explicit approval for that exact change.
- Treat wb ports scan, wb ports explain, wb ports plan, and wb ports snapshot as read-only security helpers; snapshot writes only the reviewed warning baseline.
- Keep default-deny firewall work as a separate explicit plan with rollback commands, never as shell startup behavior.
- Do not invent user-specific machine names, private IPs, aliases, or secrets.
- Keep personal customizations in the user's config, not in committed defaults.
- If optional tools are missing, keep the install graceful and explain the degraded row or command.

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
- shell startup lines the user still needs to approve or add
- render preview result
- test result
- whether port baseline warnings are active
- whether wb doctor found missing optional tools
