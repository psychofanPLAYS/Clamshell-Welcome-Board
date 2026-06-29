#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${WELCOME_BOARD_BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${WELCOME_BOARD_DATA_DIR:-$HOME/.local/share/welcome-board}"
AGENT_BIN_DIR="${WELCOME_BOARD_AGENT_BIN_DIR:-$HOME/.AGENTS/bin}"
CONFIG_DIR="${WELCOME_BOARD_CONFIG_DIR:-$HOME/.config/welcome-board}"

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

want_updater_cron() {
  local choice="${WELCOME_BOARD_INSTALL_UPDATER_CRON:-}"
  case "$choice" in
    yes|YES|y|Y|1|true|TRUE) return 0 ;;
    no|NO|n|N|0|false|FALSE) return 1 ;;
  esac
  if [ -t 0 ] && [ -t 1 ]; then
    printf 'Install optional Claude Code + Codex update checks 4x/day (03:45,09:45,15:45,21:45)? [y/N] '
    read -r choice
    case "$choice" in yes|YES|y|Y) return 0 ;; esac
  fi
  return 1
}

install_updater_cron() {
  local updater_file="$1" quoted_updater state_dir backup current next cron_line
  state_dir="$HOME/.local/state/welcome-board"
  mkdir -p "$state_dir"
  mkdir -p "$HOME/.AGENTS/logs"
  backup="$state_dir/crontab-before-codex-claude-update-$(date +%Y%m%d%H%M%S).txt"
  current="$(mktemp)"
  next="$(mktemp)"
  crontab -l > "$current" 2>/dev/null || : > "$current"
  cp "$current" "$backup"
  grep -vF "$updater_file" "$current" > "$next" || true
  quoted_updater="$(shell_quote "$updater_file")"
  cron_line="45 3,9,15,21 * * * $quoted_updater >> \$HOME/.AGENTS/logs/codex-claude-daily-update.cron.log 2>&1"
  printf '%s\n' "$cron_line" >> "$next"
  crontab "$next"
  rm -f "$current" "$next"
  printf 'Installed optional Claude Code + Codex updater cron: %s\n' "$cron_line"
  printf 'Crontab backup: %s\n' "$backup"
}

write_install_notes() {
  local notes_file="$CONFIG_DIR/INSTALL_NOTES.md"
  mkdir -p "$CONFIG_DIR"
  if [ ! -e "$notes_file" ]; then
    cat > "$notes_file" <<'EOF'
# Welcome Board Install Notes

Use this as the project memory for a Welcome Board install/customization. If an
AI helps across multiple sessions, it should read this file first, update the
checklist as it works, and leave exact next actions before stopping.

## Checklist

- [ ] Read README.md, SECURITY.md, docs/PORT_SECURITY_MODEL.md, docs/SECTION_SDK.md, and docs/LLM_EXTENSION_GUIDE.md.
- [ ] Ask for display name, banner text, theme, services, peers, custom commands, updater-cron choice, animation preference, and Hermes usage.
- [ ] Confirm shell-startup lines before editing any shell startup file.
- [ ] Run ./install.sh and record whether the optional Claude Code + Codex updater cron was installed or skipped.
- [ ] Run wb setup with the user's chosen values.
- [ ] Ask whether to run read-only `wb ports explain` to review running apps/listening ports for possible exposure.
- [ ] Ask separately before `wb ports snapshot`; it writes the reviewed baseline file.
- [ ] Verify `wb help`, `wb theme`, `wb sections`, `wb doctor`, and a render preview.
- [ ] Check banner art, binary subtitle, centering, colors, and frame symmetry.
- [ ] Run the README test command and record the result.

## Progress Log

- Created by install.sh. No shell startup files, services, ports, firewall rules,
  SSH settings, tunnels, or daemons were changed by creating this note.

## Next Action

- Continue from the first unchecked item above.
EOF
  fi
  printf '%s\n' "$notes_file"
}

require_home_path "$BIN_DIR" WELCOME_BOARD_BIN_DIR
require_home_path "$DATA_DIR" WELCOME_BOARD_DATA_DIR
require_home_path "$AGENT_BIN_DIR" WELCOME_BOARD_AGENT_BIN_DIR
require_home_path "$CONFIG_DIR" WELCOME_BOARD_CONFIG_DIR

mkdir -p "$BIN_DIR" "$DATA_DIR" "$AGENT_BIN_DIR" "$CONFIG_DIR"

backup_if_exists "$DATA_DIR/welcome-board.sh"
backup_if_exists "$AGENT_BIN_DIR/codex-claude-daily-update"
backup_if_exists "$BIN_DIR/wb"
backup_if_exists "$BIN_DIR/welcomeboard"
backup_if_exists "$BIN_DIR/clamshell-ssh-sessions"
backup_if_exists "$BIN_DIR/ssh-sessions"
backup_if_exists "$BIN_DIR/ssh-reap"

cp "$REPO_ROOT/welcome-board.sh" "$DATA_DIR/welcome-board.sh"
cp "$REPO_ROOT/codex-claude-daily-update" "$AGENT_BIN_DIR/codex-claude-daily-update"
cp "$REPO_ROOT/bin/wb" "$BIN_DIR/wb"
cp "$REPO_ROOT/bin/welcomeboard" "$BIN_DIR/welcomeboard"
cp "$REPO_ROOT/bin/clamshell-ssh-sessions" "$BIN_DIR/clamshell-ssh-sessions"
cp "$REPO_ROOT/bin/ssh-sessions" "$BIN_DIR/ssh-sessions"
cp "$REPO_ROOT/bin/ssh-reap" "$BIN_DIR/ssh-reap"
chmod +x "$DATA_DIR/welcome-board.sh" "$AGENT_BIN_DIR/codex-claude-daily-update" "$BIN_DIR/wb" "$BIN_DIR/welcomeboard" "$BIN_DIR/clamshell-ssh-sessions" "$BIN_DIR/ssh-sessions" "$BIN_DIR/ssh-reap"

printf 'Installed welcome-board files.\n\n'
notes_file="$(write_install_notes)"
printf 'Installer project memory:\n'
printf '  %s\n\n' "$notes_file"
printf 'Run setup:\n'
printf '  %s/wb setup\n\n' "$BIN_DIR"

printf 'Add these lines to your shell startup file after reviewing them:\n\n'
board_file="$DATA_DIR/welcome-board.sh"
updater_file="$AGENT_BIN_DIR/codex-claude-daily-update"
printf '[[ $- == *i* ]] && [ -f %s ] && WELCOME_BOARD_DEFER_NUDGE=1 source %s\n' "$(shell_quote "$board_file")" "$(shell_quote "$board_file")"
printf '[[ $- == *i* ]] && [ -x %s ] && %s --notify-shell\n' "$(shell_quote "$updater_file")" "$(shell_quote "$updater_file")"
printf '[[ $- == *i* ]] && type welcomeBoardQuickSettings >/dev/null 2>&1 && welcomeBoardQuickSettings\n'
printf '[[ $- == *i* ]] && printf '\''\\n'\''\n'

if want_updater_cron; then
  install_updater_cron "$updater_file"
else
  printf '\nSkipped optional Claude Code + Codex updater cron. Default, if enabled later: 45 3,9,15,21 * * *\n'
fi

printf '\nNo shell startup files, services, ports, or firewall rules were changed.\n'
printf 'After setup, an agent can ask whether to run wb ports explain to review listening apps. That review is read-only.\n'
