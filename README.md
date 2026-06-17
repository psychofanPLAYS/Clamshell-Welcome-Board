# Copy This Into Codex Or Claude

```text
You are helping me install and customize this terminal welcome board:
https://github.com/psychofanPLAYS/Clamshell-Welcome-Board

Please do this safely:
1. Clone the repo into a normal projects folder.
2. Read README.md, docs/PORT_SECURITY_MODEL.md, and docs/LLM_EXTENSION_GUIDE.md.
3. Ask me for my display name, banner text, preferred color theme, and which sections I want.
4. Run the install/setup flow only after showing me what files will change.
5. Do not change firewall rules, close ports, edit SSH settings, or make security changes unless I explicitly approve a separate future security change.
6. Run the repo tests and a render preview before calling it done.
7. Leave me with the commands `wb`, `welcomeboard`, `wb help`, and `wb theme`.
```

Prompt file: [prompts/install-with-agent.md](prompts/install-with-agent.md)

# Clamshell Welcome Board

[![test](https://github.com/psychofanPLAYS/Clamshell-Welcome-Board/actions/workflows/test.yml/badge.svg)](https://github.com/psychofanPLAYS/Clamshell-Welcome-Board/actions/workflows/test.yml)

A fast, pretty terminal welcome board for Linux and macOS shells.

It is designed for people who want a useful first screen when they open a terminal: machine pressure, temperature, memory, disk, shell helpers, tmux sessions, and optional update notices, all in a compact dark-terminal layout.

> Public-release status: **in progress**. The current code is generalized for Linux/macOS installs and tested in CI, but the license and final public-release gate still need an explicit project-owner decision.

## What It Does

- Prints a framed startup board for interactive shells.
- Shows CPU, GPU, VRAM, RAM, swap, disk, load, CPU temperature, GPU temperature, and GPU clocks when available.
- Keeps tiny local rolling metric points for fixed-width mini line graphs.
- Provides an optional rolling 7-day Claude/Codex CLI update notice.
- Includes a reusable `wb` / `welcomeboard` command with setup, help, theme, sections, doctor, and read-only port scan commands.
- Treats port lockdown as a safe read-only wizard: scan, explain, and dry-run plan only.

## Target Experience

See a fuller public-safe render preview in [docs/demo-output.txt](docs/demo-output.txt).

```text
PRESSURE
CPU   ██░░░░░░  32% ▁▁▁▁▁▂▂▃  i7-6700HQ  8t · 2.70/3.50 GHz
GPU   ░░░░░░░░   0% ▁▁▁▁▁▁▁▁  GTX 1060  P8 · 4 W
VRAM  ███████░  98% ▁▁▁▁▁▇▇▇  6059/6144 MB
RAM   ████░░░░  55% ▁▁▁▁▁▄▄▄  8.6/16 GB

TEMP
CTEMP ███░░░░░  45% ▁▁▁▁▁▄▄▄  CPU · 45°C
GTEMP ███░░░░░  38% ▁▁▁▁▁▃▃▃  GPU · 38°C

CLOCKS
GCLK  ░░░░░░░░   7% ▁▁▁▁▁▁▁▁  graphics · 139/1911 MHz
MCLK  ░░░░░░░░  10% ▁▁▁▁▁▁▁▁  memory · 405/4004 MHz
```

How to read the machine rows:

- `8t` means eight CPU threads/logical CPUs.
- NVIDIA `P8` is a GPU performance state, usually a low-power idle state.
- The CPU clock pair is current/max GHz. On an i7-6700HQ, for example, `2.70/3.50 GHz` means the current average is near 2.70 GHz and the kernel reports a 3.50 GHz max/turbo limit.
- `CTEMP` and `GTEMP` are CPU and GPU temperatures.
- `GCLK` and `MCLK` are GPU graphics and memory clocks as current/max MHz.

## First Run

Clone the repo, install the commands, then run setup:

```bash
git clone https://github.com/psychofanPLAYS/Clamshell-Welcome-Board.git
cd Clamshell-Welcome-Board
./install.sh
wb setup
wb doctor
```

`wb doctor` is read-only. It reports platform, config, installed command paths, optional tools, and which port scanner is available.

## Install Details

```bash
./install.sh
wb setup
```

The installer copies files and prints shell hook lines. It does not edit shell startup files by itself.

Manual install:

```bash
mkdir -p ~/.AGENTS/bin
cp welcome-board.sh ~/.AGENTS/welcome-board.sh
cp codex-claude-daily-update ~/.AGENTS/bin/codex-claude-daily-update
cp bin/wb ~/.local/bin/wb
cp bin/welcomeboard ~/.local/bin/welcomeboard
chmod +x ~/.AGENTS/welcome-board.sh ~/.AGENTS/bin/codex-claude-daily-update
chmod +x ~/.local/bin/wb ~/.local/bin/welcomeboard
```

Add this near the end of `~/.bashrc`:

```bash
[[ $- == *i* ]] && [ -f ~/.AGENTS/welcome-board.sh ] && source ~/.AGENTS/welcome-board.sh
[[ $- == *i* ]] && [ -x ~/.AGENTS/bin/codex-claude-daily-update ] && ~/.AGENTS/bin/codex-claude-daily-update --notify-shell
[[ $- == *i* ]] && printf '\n\n'
```

## Setup Flow

The `wb setup` command asks:

- Your display name.
- Banner text.
- Theme: `cyan-dark`, `amber-terminal`, `green-phosphor`, or `mono-safe`.
- Sections to enable in the board: `machine`, `tmux`, `network`, `locks`, `services`, `commands`.
- Port scanning stays separate as `wb ports scan`, `wb ports explain`, and `wb ports plan`; the update notice stays separate as the shell hook shown above.

Commands:

```bash
wb
welcomeboard
wb help
wb setup
wb theme
wb sections
wb doctor
wb ports scan
wb ports explain
wb ports plan
```

`wb ports scan`, `wb ports explain`, and `wb ports plan` are read-only. `wb ports apply` is intentionally not implemented because it would mutate firewall state. Port safety rules live in [docs/PORT_SECURITY_MODEL.md](docs/PORT_SECURITY_MODEL.md).

## Common Commands

```bash
bash -n welcome-board.sh
python3 -m py_compile codex-claude-daily-update
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
wb doctor
```

Render a plain preview:

```bash
bash welcome-board.sh | sed -r 's/\x1B\[[0-9;]*[mK]//g'
```

## Platform Notes

Linux:

- CPU and memory use `/proc`, `/sys`, `free`, `df`, and `uptime`.
- NVIDIA GPU details use `nvidia-smi` when available.
- Tmux section will use `tmux list-sessions` and `tmux list-windows`.
- Port scanning should use `ss` where available.

macOS:

- CPU, memory, disk, load, and tmux sections are supported with native macOS probes.
- GPU memory, temperatures, and clocks are limited by Apple tooling and degrade gracefully when unavailable.
- Port scanning should use `lsof` / `netstat` equivalents.

## Safety And Privacy

- No cloud upload by default.
- No secrets should be stored in the repo.
- Firewall/port lockdown is not applied by this version; port commands are read-only scan/explain/plan helpers.
- Local machine names, private IPs, and personal aliases should live in user config, not committed defaults.
- AI agents should follow [docs/LLM_EXTENSION_GUIDE.md](docs/LLM_EXTENSION_GUIDE.md) before editing.

## Reliability Notes

- CI runs shell syntax and unit tests on Ubuntu and macOS.
- Public shell scripts avoid Bash 4-only constructs so macOS `/bin/bash` 3.2 can run them.
- Missing optional tools degrade gracefully: no `tmux` means an explicit `not installed` row, no NVIDIA tooling means GPU details fall back instead of crashing, and Apple GPU temperature/clock data renders as `not exposed`.
- `wb doctor` is the first support command to run on a new machine.

## Roadmap

- Pick and add a `LICENSE` file before public redistribution.
- Add an optional PNG screenshot once the public theme set is stable.
- Expand non-NVIDIA GPU probes where the OS exposes reliable metrics.

## License

License is not finalized yet. Do not assume redistribution rights until a `LICENSE` file is added.
