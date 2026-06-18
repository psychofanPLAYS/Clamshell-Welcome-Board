# Install With Codex Or Claude

Copy this into Codex, Claude Code, or another coding agent when you want it to install and customize this repo for you.

```text
You are helping me install and customize this terminal welcome board:
https://github.com/psychofanPLAYS/Clamshell-Welcome-Board

Please work safely and show me what will change before editing my shell startup files.

Do this:
1. Clone the repo into a normal projects folder.
2. Read README.md, docs/PORT_SECURITY_MODEL.md, docs/SECTION_SDK.md, and docs/LLM_EXTENSION_GUIDE.md.
3. Ask me for these choices before setup:
   - display name
   - banner text
   - color theme: cyan-dark, amber-terminal, green-phosphor, light-paper, or mono-safe
   - rendered board sections; the board currently shows MACHINE, NETWORK, SECURITY, SERVICES, AUTOMATION, HERMES, and COMMANDS
   - tmux workflow and any custom tmux commands I use
   - custom commands or path shortcuts I want visible at a glance
   - service ports I intentionally run and want watched, as name:port pairs
   - whether I use Hermes; if yes, ask for my master command aliases such as m1, m1c, m1s, m1g, m1up, m1down, m1re, m2, m2c, m2s, m2g, m2up, m2down, and m2re
   - whether I want to create a reviewed port baseline with wb ports snapshot
   - whether I want a separate future default-deny firewall plan
4. Show me exactly which files will change before editing shell startup files.
5. Run ./install.sh, then run wb setup using my answers.
6. If I gave custom commands, write them to a config file in the documented LABEL|command|hint format and point WB_CUSTOM_COMMANDS_FILE at it.
7. Run wb help, wb theme, wb sections, and wb doctor so I know the commands work and the install is healthy.
8. Run wb ports explain. Ask before running wb ports snapshot; snapshot is read-only but creates the reviewed warning baseline file.
9. Run a render preview and check that text is aligned inside the frame.
10. Run the test command from README.md before calling the install done.

Do not change firewall rules, close ports, edit SSH settings, edit system services, or run a port-lockdown command beyond scan/explain/plan/snapshot unless I explicitly approve that exact future change. Treat default-deny as a separate reviewed plan with rollback, never as shell startup behavior.

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
