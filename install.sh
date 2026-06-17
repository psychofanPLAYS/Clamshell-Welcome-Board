#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${WELCOME_BOARD_BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${WELCOME_BOARD_DATA_DIR:-$HOME/.local/share/welcome-board}"
AGENT_BIN_DIR="${WELCOME_BOARD_AGENT_BIN_DIR:-$HOME/.AGENTS/bin}"

mkdir -p "$BIN_DIR" "$DATA_DIR" "$AGENT_BIN_DIR"

cp "$REPO_ROOT/welcome-board.sh" "$DATA_DIR/welcome-board.sh"
cp "$REPO_ROOT/codex-claude-daily-update" "$AGENT_BIN_DIR/codex-claude-daily-update"
cp "$REPO_ROOT/bin/wb" "$BIN_DIR/wb"
cp "$REPO_ROOT/bin/welcomeboard" "$BIN_DIR/welcomeboard"
chmod +x "$DATA_DIR/welcome-board.sh" "$AGENT_BIN_DIR/codex-claude-daily-update" "$BIN_DIR/wb" "$BIN_DIR/welcomeboard"

printf 'Installed welcome-board files.\n\n'
printf 'Run setup:\n'
printf '  %s/wb setup\n\n' "$BIN_DIR"

printf 'Add these lines to your shell startup file after reviewing them:\n\n'
cat <<EOF
[[ \$- == *i* ]] && [ -f "$DATA_DIR/welcome-board.sh" ] && source "$DATA_DIR/welcome-board.sh"
[[ \$- == *i* ]] && [ -x "$AGENT_BIN_DIR/codex-claude-daily-update" ] && "$AGENT_BIN_DIR/codex-claude-daily-update" --notify-shell
[[ \$- == *i* ]] && printf '\\n\\n'
EOF

printf '\nNo shell startup files, services, ports, or firewall rules were changed.\n'
