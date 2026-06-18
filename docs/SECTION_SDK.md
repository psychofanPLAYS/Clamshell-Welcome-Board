# Section SDK

This project is intentionally a single-file shell board, but sections follow a
small SDK-style contract so humans and AI agents can extend it safely.

## Section Contract

Every section should have:

- one render function named `__wb_<section>()`
- one config token in `WB_SECTIONS`
- graceful behavior when tools are missing
- a focused test or render smoke
- no slow unbounded network calls
- no private defaults committed to the repo

Render functions should use the shared row helpers instead of hand-building
frames:

```bash
__wb_hdr "SECTION"
__wb_zreset
__wb_zrow "${WB_LBL}$(printf '%-10s' 'label')${WB_FR}${WB_WHT}value${WB_DM} detail"
__wb_plainrow "${WB_DM}secondary note"
```

## Row Types

Use these patterns:

- **status row**: label + `up/down/check` + short detail
- **metric row**: label + `__wb_bar` + percent + `__wb_hist_graph`
- **command row**: label + cyan command + dim explanation
- **note row**: label + short operational note
- **alert row**: label + yellow/red status + exact next command

## Adding A Graph

Use the existing metric helper when the value is a percentage:

```bash
__wb_mrow "RAM" "$pct" "$(__wb_hist_graph ram "$pct")" "${WB_WHT}${used}${WB_DM}/${total}"
```

Rules:

- graph key must be stable and lowercase
- value must be clamped with `__wb_pct`
- graph width stays 8 cells
- detail text must fit inside the frame

## Adding Commands

For one machine or one person, put commands in a config file instead of hardcoding
them:

```text
WORK|cd ~/work|open my work folder
AGENTS|cd ~/.AGENTS|open operator notes
```

Then set:

```bash
WB_SECTIONS="machine services security tmux custom notes"
WB_CUSTOM_COMMANDS_FILE="$HOME/.config/welcome-board/custom-commands"
```

The board renders this as the `CUSTOM` section.

## Adding Personal Integrations

Optional integrations belong in config:

```bash
WB_HERMES_LABEL="Hermes local helper"
WB_OPENCLAW_PATH="$HOME/_openCLAW/_OPENCLAW-HOME"
WB_SERVICE_PORTS="webdash:6900 app:3000"
```

The installer or AI assistant should ask before adding these. Do not assume every
user has Hermes, OpenClaw, tmux aliases, or the same service ports.

## Port Baseline

The startup board must not change firewall rules. To watch for drift:

```bash
wb ports explain
wb ports snapshot
```

`snapshot` saves the reviewed listener set. Later renders warn if new listeners
appear. Any deny-by-default firewall change must be a separate, explicit,
reviewed operation with rollback steps.

## Verification

After adding or changing a section:

```bash
bash -n welcome-board.sh bin/wb bin/welcomeboard install.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
git diff --check
```
