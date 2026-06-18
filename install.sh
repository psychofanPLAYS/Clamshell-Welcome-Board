#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${WELCOME_BOARD_BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${WELCOME_BOARD_DATA_DIR:-$HOME/.local/share/welcome-board}"
AGENT_BIN_DIR="${WELCOME_BOARD_AGENT_BIN_DIR:-$HOME/.AGENTS/bin}"

shell_quote() {
  printf '%q' "$1"
}

require_home_path() {
  local path="$1" label="$2"
  case "$path" in
    "$HOME"|"$HOME"/*) ;;
    *)
      if [ "${WELCOME_BOARD_ALLOW_OUTSIDE_HOME:-0}" != 1 ]; then
        printf 'Refusing %s outside $HOME: %s\n' "$label" "$path" >&2
        printf 'Set WELCOME_BOARD_ALLOW_OUTSIDE_HOME=1 only after reviewing the path.\n' >&2
        exit 2
      fi
      ;;
  esac
}

backup_if_exists() {
  local path="$1"
  [ -e "$path" ] || return 0
  cp -p "$path" "$path.bak.$(date +%Y%m%d%H%M%S)"
}

require_home_path "$BIN_DIR" WELCOME_BOARD_BIN_DIR
require_home_path "$DATA_DIR" WELCOME_BOARD_DATA_DIR
require_home_path "$AGENT_BIN_DIR" WELCOME_BOARD_AGENT_BIN_DIR

mkdir -p "$BIN_DIR" "$DATA_DIR" "$AGENT_BIN_DIR"

backup_if_exists "$DATA_DIR/welcome-board.sh"
backup_if_exists "$AGENT_BIN_DIR/codex-claude-daily-update"
backup_if_exists "$BIN_DIR/wb"
backup_if_exists "$BIN_DIR/welcomeboard"

cp "$REPO_ROOT/welcome-board.sh" "$DATA_DIR/welcome-board.sh"
cp "$REPO_ROOT/codex-claude-daily-update" "$AGENT_BIN_DIR/codex-claude-daily-update"
cp "$REPO_ROOT/bin/wb" "$BIN_DIR/wb"
cp "$REPO_ROOT/bin/welcomeboard" "$BIN_DIR/welcomeboard"
chmod +x "$DATA_DIR/welcome-board.sh" "$AGENT_BIN_DIR/codex-claude-daily-update" "$BIN_DIR/wb" "$BIN_DIR/welcomeboard"

printf 'Installed welcome-board files.\n\n'
printf 'Run setup:\n'
printf '  %s/wb setup\n\n' "$BIN_DIR"

printf 'Add these lines to your shell startup file after reviewing them:\n\n'
board_file="$DATA_DIR/welcome-board.sh"
updater_file="$AGENT_BIN_DIR/codex-claude-daily-update"
printf '[[ $- == *i* ]] && [ -f %s ] && source %s\n' "$(shell_quote "$board_file")" "$(shell_quote "$board_file")"
printf '[[ $- == *i* ]] && [ -x %s ] && %s --notify-shell\n' "$(shell_quote "$updater_file")" "$(shell_quote "$updater_file")"
printf '[[ $- == *i* ]] && printf '\''\\n\\n'\''\n'

printf '\nNo shell startup files, services, ports, or firewall rules were changed.\n'
