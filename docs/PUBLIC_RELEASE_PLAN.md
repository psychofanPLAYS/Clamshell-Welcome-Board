# Public Release Plan

This repo started as a personal shell board. The public version needs a config-first shape.

## Requirements From The Current Goal

- README starts with a prompt users can paste into Codex or Claude.
- Setup asks for user name and banner text.
- Banner regenerates from the configured text.
- Setup asks for a color theme and offers a few choices.
- Commands exist: `welcomeboard`, `wb`, `wb help`, `wb theme`, `wb doctor`, and `wb ports snapshot`.
- Support command exists: `wb doctor`.
- Setup explains the rendered sections instead of writing stale ignored section flags.
- Machine, network, local AI, curated security, services, automation, Hermes, and commands sections are implemented.
- Port lockdown is available as safe read-only scan/explain/plan/snapshot commands. Apply/rollback are intentionally not implemented in this version.
- Future LLMs know how to add sections safely through `docs/SECTION_SDK.md`.
- Repo is safe to make public only after personal defaults are removed.

## Proposed File Layout

```text
README.md
LICENSE
install.sh
bin/wb
lib/welcome-board.sh
lib/themes.sh
lib/probes-linux.sh
lib/probes-macos.sh
lib/ports.sh
docs/
tests/
examples/config.example
```

The current single-file `welcome-board.sh` can stay during the transition, but public install should eventually source smaller `lib/` files.

## Config Shape

```bash
WB_DISPLAY_NAME="Alex"
WB_BANNER_TEXT="WORKSTATION"
WB_THEME="cyan-dark"
WELCOME_BOARD_MACHINE_HISTORY="$HOME/.local/state/welcome-board/machine-series.tsv"
WB_PORT_BASELINE_FILE="$HOME/.local/state/welcome-board/ports-baseline.txt"
WB_SERVICE_PORTS="ssh:22 webdash:6900 embedder:6901 reranker:6902"
WB_CUSTOM_COMMANDS_FILE="$HOME/.config/welcome-board/custom-commands"
WB_HERMES_LABEL="Hermes local helper"
WB_AUTOMATION_LABEL="backups · agents · updater"
```

## Installer Shape

`install.sh` should:

1. Detect Linux or macOS.
2. Ask before editing shell files.
3. Ask display name.
4. Ask banner text.
5. Ask theme.
6. Explain enabled board sections.
7. Ask tmux workflow, custom commands, watched service ports, optional Claude Code + Codex updater cron, Hermes usage, and port baseline choice.
8. Install `wb` into `~/.local/bin`.
9. Install config under `~/.config/welcome-board/config`.
10. Print exact shell hook lines.
11. Run a render preview and check centering, color coding, and custom banner/binary subtitle alignment.

## Tmux Section

The tmux section should show:

```text
TMUX
work                             3 windows · attached
server                           1 window  · detached
jump                             tmux 3 or tmux3 · join numbered session
manage                           tmux kill 1 2 · tmux rename 3 work
leave                            Ctrl-b d detach · exit close pane
```

If tmux is missing:

```text
TMUX
not installed
```

If tmux is installed but no server is running:

```text
TMUX
no sessions
```

## Port Security

Port security must follow `docs/PORT_SECURITY_MODEL.md`.

Public command shape:

```bash
wb ports scan
wb ports explain
wb ports plan
wb ports snapshot
```

The board shows curated `SECURITY` summaries and drift warnings, not raw socket dumps. Shell startup must stay read-only.
Any future apply/rollback flow must be a separate, explicit, reversible command that asks for user approval and is covered by tests.

## CPU/GPU Notes

The current Linux machine row displays:

- `8t`: eight CPU threads.
- NVIDIA `P8`: NVIDIA performance state 8, normally a low-power idle state.
- CPU clock pair: current/max GHz, not base/max. For example, `2.70/3.50 GHz` means the current average is near 2.70 GHz and the kernel reports 3.50 GHz as the max/turbo limit.
- `CORE`: GPU graphics/core clock as current/max MHz.
- `MEMCLK`: GPU memory clock as current/max MHz.

For broad user support, the board should detect unavailable GPU data and render `no GPU` instead of failing.

## Completion Gates

The repo is public-ready only when:

- No committed defaults contain personal names, private IPs, private hostnames, or private paths.
- Installer works from a clean temp home.
- `wb help`, `wb theme`, and `welcomeboard` work.
- Tmux section is implemented and tested, including numbered-session commands.
- Port scan/explain/plan/snapshot are read-only by default and tested.
- `wb doctor` reports readiness without mutating files or system state.
- README install path matches real commands.
- `docs/SECTION_SDK.md` exists and the agent prompt/skill tell installing LLMs to read it.
- License exists.
- A screenshot or demo output artifact exists.
- Secret scan passes.
- GitHub Actions are green on Linux and macOS.
- GitHub visibility is changed only after explicit user approval.
