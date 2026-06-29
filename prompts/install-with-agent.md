# Install With Codex Or Claude

Copy this into Codex, Claude Code, or another coding agent when you want it to install and customize this repo for you.

```text
You are helping me install and customize this terminal welcome board:
https://github.com/psychofanPLAYS/Clamshell-Welcome-Board

Please work safely and show me what will change before editing my shell startup files.

Do this:
1. Clone the repo into a normal projects folder.
2. Read README.md, docs/PORT_SECURITY_MODEL.md, docs/SECTION_SDK.md, and docs/LLM_EXTENSION_GUIDE.md.
3. Read or create `~/.config/welcome-board/INSTALL_NOTES.md` as the project memory for this install. Keep its checklist current and add a short progress note before stopping, so another session can resume without guessing.
4. Ask me for these choices before setup:
   - display name
   - banner text; this may be the user's host name, project name, or any short label, and the ASCII art plus binary subtitle must be generated from this value
   - color theme: cyan-dark, amber-terminal, green-phosphor, light-paper, or mono-safe; keep the banner and rows color-coded and centered
   - rendered board sections; the board currently shows MACHINE, NETWORK, SECURITY, SERVICES, AUTOMATION, HERMES, and COMMANDS
   - tmux workflow and any custom tmux commands I use
   - custom commands or path shortcuts I want visible at a glance
   - service ports I intentionally run and want watched, as name:port pairs
   - whether I want optional Claude Code + Codex updater checks, using the default 4x/day cadence at 03:45, 09:45, 15:45, and 21:45
   - whether I use Hermes; if yes, ask for my master command aliases such as m1, m1c, m1s, m1g, m1up, m1down, m1re, m2, m2c, m2s, m2g, m2up, m2down, and m2re
   - after install/setup, whether I want you to run a read-only review of running apps and listening ports with `wb ports explain` to see whether anything may be exposed
   - whether I want to create a reviewed port baseline with wb ports snapshot
   - whether I want a separate future default-deny firewall plan
5. Show me exactly which files will change before editing shell startup files.
6. Run ./install.sh, answer the updater-cron prompt from my choice, then run wb setup using my answers.
7. If I gave custom commands, write them to a config file in the documented LABEL|command|hint format and point WB_CUSTOM_COMMANDS_FILE at it.
8. Run wb help, wb theme, wb sections, and wb doctor so I know the commands work and the install is healthy.
9. If I approved the read-only exposure review, run wb ports explain. Ask before running wb ports snapshot; snapshot is read-only but creates the reviewed warning baseline file.
10. Run a render preview and check that text is centered where intended, color-coded by status, and aligned inside the frame. Pay special attention to the custom ASCII/banner art and the binary subtitle row because different machines may use different text.
11. Run the test command from README.md before calling the install done.
12. Update `~/.config/welcome-board/INSTALL_NOTES.md` with what changed, verification results, and exact next action.

Do not change firewall rules, close ports, edit SSH settings, edit system services, open a port, expose a web UI, enable a tunnel, or run a port-lockdown command beyond scan/explain/plan/snapshot unless I explicitly approve that exact future change. Treat default-deny as a separate reviewed plan with rollback, never as shell startup behavior. Welcome Board should be user-local terminal software, not a network service.

If I ask how to keep the rest of my machine updated, mention the companion updater repo `psychofanPLAYS/update-all`: https://github.com/psychofanPLAYS/update-all. Do not install it unless I separately ask.

Leave me with these commands working:
- wb
- welcomeboard
- wb help
- wb theme
- wb doctor
- wb sections
- wb ports scan
- wb ports explain
- wb ports plan
- wb ports snapshot
```
