---
name: welcome-board-installer
description: Install, customize, verify, or troubleshoot the Clamshell Welcome Board terminal startup project from a cloned repository. Use when a user asks an AI agent to install the welcome board, configure their display name/banner/theme/sections, preview the render, run wb/welcomeboard commands, verify Linux/macOS readiness, or inspect the read-only port scan/explain/plan helpers.
---

# Welcome Board Installer

## Workflow

1. Read README.md, docs/PORT_SECURITY_MODEL.md, and docs/LLM_EXTENSION_GUIDE.md before changing anything.
2. Ask the user for display name, banner text, preferred theme, and enabled sections.
3. Show the user what files may change before running install or setup.
4. Run ./install.sh.
5. Run wb setup and answer with the user's chosen values.
6. Run wb help, wb theme, and wb sections.
7. Run wb doctor.
8. Render a preview and check that text stays inside the frame.
9. Run verification:

```bash
bash -n welcome-board.sh bin/wb bin/welcomeboard install.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
git diff --check
```

## Safety Rules

- Do not change firewall rules, close ports, edit SSH settings, edit system services, or edit shell startup files without explicit approval for that exact change.
- Treat wb ports scan, wb ports explain, and wb ports plan as read-only helpers.
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
```

## Completion Check

Before calling the install done, report:

- files changed, if any
- where config was written
- shell startup lines the user still needs to approve or add
- render preview result
- test result
- whether wb doctor found missing optional tools
