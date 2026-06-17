# Clamshell Welcome Board

Private shell startup dashboard for `clamshell`.

It prints a fast, glanceable terminal board for interactive shells:

- CLAMSHELL ASCII masthead
- machine stats: CPU, GPU, VRAM, RAM, swap, disk, load
- network and service status
- useful command reminders
- Hermes profile shortcuts
- optional Claude/Codex rolling 7-day update notice

The board is tuned for a black terminal background and fast reading: bold labels,
zebra rows, gold section dividers, and consistent box rails.

## Files

- `welcome-board.sh` - bash welcome-board renderer and helper commands.
- `codex-claude-daily-update` - optional updater/history helper for Claude Code and Codex CLI.

## Install

Copy the files into the shared operator area:

```bash
mkdir -p ~/.AGENTS/bin
cp welcome-board.sh ~/.AGENTS/welcome-board.sh
cp codex-claude-daily-update ~/.AGENTS/bin/codex-claude-daily-update
chmod +x ~/.AGENTS/welcome-board.sh ~/.AGENTS/bin/codex-claude-daily-update
```

Then source the board from `~/.bashrc` for interactive shells:

```bash
[[ $- == *i* ]] && [ -f ~/.AGENTS/welcome-board.sh ] && source ~/.AGENTS/welcome-board.sh
```

Optional update notice:

```bash
[[ $- == *i* ]] && [ -x ~/.AGENTS/bin/codex-claude-daily-update ] && ~/.AGENTS/bin/codex-claude-daily-update --notify-shell
```

The notice reads update receipts and prints only recent version changes. It does
not run update commands when a shell opens.

Optional final spacing after all startup output:

```bash
[[ $- == *i* ]] && printf '\n\n'
```

## Local Checks

```bash
bash -n welcome-board.sh
python3 -m py_compile codex-claude-daily-update
python3 -m unittest discover -s tests -v
```

Render a plain preview:

```bash
bash welcome-board.sh | sed -r 's/\x1B\[[0-9;]*[mK]//g'
```
