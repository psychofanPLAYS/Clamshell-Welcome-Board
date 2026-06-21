# Security Review - 2026-06-18

Scope reviewed:

- `welcome-board.sh`
- `bin/wb`
- `bin/welcomeboard`
- `install.sh`
- `codex-claude-daily-update`
- `skills/welcome-board-installer/SKILL.md`
- `prompts/install-with-agent.md`

Review mode: report-only. No executable files were changed.

Threat model: a public Bash project that is sourced into users' interactive shells at login. The highest-risk class is untrusted bytes reaching a terminal at shell startup.

## Severity Summary

- Critical: 0
- High: 1
- Medium: 5
- Low: 2

## Findings

### HIGH - Terminal escape/control injection through row printers and probe output

Locations:

- `welcome-board.sh:107`
- `welcome-board.sh:119`
- `welcome-board.sh:262`
- `welcome-board.sh:297`
- `welcome-board.sh:299`
- `welcome-board.sh:641`
- `welcome-board.sh:653`
- `welcome-board.sh:663`
- `welcome-board.sh:693`
- `bin/wb:199`
- `bin/wb:287`
- `bin/wb:356`
- `codex-claude-daily-update:302`
- `codex-claude-daily-update:307`

Issue:

`__wb_plainrow` and `__wb_zrow` print row content with `printf '%b'`. That interprets backslash escapes in the row content. Several row fragments come from untrusted or user-controlled sources: tmux session names, `tailscale status`, hostnames, config values, service names, automation labels, GPU names, the custom commands file, and `ss`/`lsof`/`netstat` process names.

`%b` makes backslash-encoded payloads dangerous, for example a tmux session named with `\033]52;...` can become a real OSC sequence. Even if `%b` is changed to `%s`, literal ESC/control bytes from probe output still need to be stripped before printing. The Python update-history notifier has the same terminal-output problem if its JSON state/log is tampered with or a tool prints a hostile version string.

Concrete exploit scenario:

An attacker with local account access, compromised automation, or a malicious project hook creates a tmux session, process name, config value, or custom command row containing terminal control sequences. On the next login, the board is sourced from the interactive shell and prints the payload. Depending on terminal support/settings, this can fake security output, move the cursor, alter title text, hide following lines, or attempt clipboard injection.

Fix:

Use `%s` in row printers. Keep trusted color constants as literal ESC bytes, but sanitize every untrusted fragment before it is interpolated into a painted row. Add the same terminal-text sanitizer to `bin/wb` and the Python update notifier.

Patch snippet:

```diff
diff --git a/welcome-board.sh b/welcome-board.sh
--- a/welcome-board.sh
+++ b/welcome-board.sh
@@
 __wb_vis() {
   local s
   s=$(printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*m//g' | tr -d "$WB_DM")
   LC_ALL=C.UTF-8 printf '%s' "$s" | wc -m | awk '{print $1}'
 }
+__wb_safe_text() {
+  local s="${1-}"
+  s="${s//$'\r'/ }"
+  s="${s//$'\n'/ }"
+  s="${s//$'\t'/ }"
+  s="${s//$'\e'/}"
+  LC_ALL=C printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037\177'
+}
+__wb_safe_token() {
+  local max="${2:-160}" s
+  s="$(__wb_safe_text "${1-}")"
+  printf '%s' "${s:0:max}"
+}
@@
-  printf '  %s│%s %b%*s%s│%s\n' "$WB_AC" "$WB_R" "$c" "$pad" '' "$WB_AC" "$WB_R"
+  printf '  %s│%s %s%*s%s│%s\n' "$WB_AC" "$WB_R" "$c" "$pad" '' "$WB_AC" "$WB_R"
@@
-  printf '  %s│%s %b%*s%s│%s\n' "$WB_AC" "$bg" "$c" "$pad" '' "$WB_AC" "$WB_R"
+  printf '  %s│%s %s%*s%s│%s\n' "$WB_AC" "$bg" "$c" "$pad" '' "$WB_AC" "$WB_R"
@@
-  for e in $WB_SERVICE_PORTS; do
-    n="${e%:*}"; p="${e##*:}"; ntot=$((ntot+1))
+  for e in $WB_SERVICE_PORTS; do
+    n="$(__wb_safe_token "${e%:*}" 32)"; p="${e##*:}"
+    [[ "$p" =~ ^[0-9]+$ ]] || continue
+    ntot=$((ntot+1))
@@
-    local label=""; [ -n "${WB_AUTOMATION_LABEL:-}" ] && label=" ${WB_DM}— ${WB_AUTOMATION_LABEL}"
+    local label=""; [ -n "${WB_AUTOMATION_LABEL:-}" ] && label=" ${WB_DM}- $(__wb_safe_token "$WB_AUTOMATION_LABEL" 80)"
@@
-    [ -n "${WB_AUTOMATION_DAILY:-}" ] && __wb_zrow "${WB_LBL}$(printf '%-9s' 'daily')${WB_FR}${WB_DM}${WB_AUTOMATION_DAILY}"
+    [ -n "${WB_AUTOMATION_DAILY:-}" ] && __wb_zrow "${WB_LBL}$(printf '%-9s' 'daily')${WB_FR}${WB_DM}$(__wb_safe_token "$WB_AUTOMATION_DAILY" 120)"
@@
-  local name="${WB_DISPLAY_NAME:-friend}" hi msg up
+  local name hi msg up
+  name="$(__wb_safe_token "${WB_DISPLAY_NAME:-friend}" 40)"
@@
-  self=$(hostname 2>/dev/null | cut -d. -f1)
+  self="$(__wb_safe_token "$(hostname 2>/dev/null | cut -d. -f1)" 32)"
@@
-    __wb_zrow "${WB_LBL}$(printf '%-6s' "${self:0:6}")${WB_FR} ${WB_WHT}$(printf '%-16s' "${ip:-?}")${WB_DM}· this machine"
+    ip="$(__wb_safe_token "${ip:-?}" 64)"
+    __wb_zrow "${WB_LBL}$(printf '%-6s' "${self:0:6}")${WB_FR} ${WB_WHT}$(printf '%-16s' "$ip")${WB_DM}· this machine"
@@
-    __wb_zrow "${WB_LBL}$(printf '%-6s' "${nm:0:6}")${WB_FR} ${WB_WHT}$(printf '%-16s' "${ip:-—}")${WB_FR}${st}"
+    local shown_nm shown_ip
+    shown_nm="$(__wb_safe_token "$nm" 32)"
+    shown_ip="$(__wb_safe_token "${ip:-—}" 64)"
+    __wb_zrow "${WB_LBL}$(printf '%-6s' "${shown_nm:0:6}")${WB_FR} ${WB_WHT}$(printf '%-16s' "$shown_ip")${WB_FR}${st}"
@@
-  tnames=$(tmux ls 2>/dev/null | sed 's/:.*//' | paste -sd, - | sed 's/,/, /g')
+  tnames="$(tmux ls 2>/dev/null | sed 's/:.*//' | paste -sd, - | sed 's/,/, /g')"
+  tnames="$(__wb_safe_token "$tnames" 180)"
@@
-      __wb_cmdrow "${cl:0:9}" "${WB_CYN}${cc}${WB_FR}${ch:+   ${WB_D}${ch}}"
+      cl="$(__wb_safe_token "$cl" 32)"
+      cc="$(__wb_safe_token "$cc" 100)"
+      ch="$(__wb_safe_token "$ch" 100)"
+      __wb_cmdrow "${cl:0:9}" "${WB_CYN}${cc}${WB_FR}${ch:+   ${WB_D}${ch}}"
```

```diff
diff --git a/bin/wb b/bin/wb
--- a/bin/wb
+++ b/bin/wb
@@
 wb_config_quote() {
@@
 }
+
+wb_terminal_filter() {
+  LC_ALL=C tr -d '\000-\010\013\014\016-\037\177' | sed $'s/\x1b//g'
+}
+wb_terminal_text() {
+  printf '%s' "${1-}" | wb_terminal_filter
+}
@@
 wb_ports_scan() {
   if command -v ss >/dev/null 2>&1; then
-    ss -tuln
+    ss -tuln | wb_terminal_filter
   elif command -v lsof >/dev/null 2>&1; then
-    lsof -iTCP -sTCP:LISTEN -P -n
+    lsof -iTCP -sTCP:LISTEN -P -n | wb_terminal_filter
   elif command -v netstat >/dev/null 2>&1; then
-    netstat -an
+    netstat -an | wb_terminal_filter
@@
-    printf '%s:%s(%s)\n' "$(wb_ports_short_name "$port")" "$port" "$process"
+    process="$(wb_terminal_text "$process")"
+    printf '%s:%s(%s)\n' "$(wb_ports_short_name "$port")" "$port" "$process"
@@
-    printf '%s  %s:%s  process=%s  %s\n' "$scope" "$addr" "$port" "$process" "$known"
+    addr="$(wb_terminal_text "$addr")"
+    process="$(wb_terminal_text "$process")"
+    printf '%s  %s:%s  process=%s  %s\n' "$scope" "$addr" "$port" "$process" "$known"
```

```diff
diff --git a/codex-claude-daily-update b/codex-claude-daily-update
--- a/codex-claude-daily-update
+++ b/codex-claude-daily-update
@@
 import re
@@
 MAX_LOG_READ_BYTES = _bounded_env_int(
@@
 )
+ANSI_RE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\)|[@-Z\\-_])")
+CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
+
+
+def _terminal_text(value: Any, limit: int = 120) -> str:
+    text = str(value or "")
+    text = ANSI_RE.sub("", text)
+    text = text.replace("\r", " ").replace("\n", " ").replace("\t", " ")
+    text = CONTROL_RE.sub("", text)
+    return text[:limit]
@@
-            label = str(entry.get("label") or entry.get("key") or "Tool")
-            before = str(entry.get("before") or "unknown")
-            after = str(entry.get("after") or "unknown")
+            label = _terminal_text(entry.get("label") or entry.get("key") or "Tool", 40)
+            before = _terminal_text(entry.get("before") or "unknown", 80)
+            after = _terminal_text(entry.get("after") or "unknown", 80)
```

### MEDIUM - Installer prints shell-startup code with unescaped, environment-controlled paths

Locations:

- `install.sh:5`
- `install.sh:6`
- `install.sh:7`
- `install.sh:22`
- `install.sh:23`
- `install.sh:24`

Issue:

The install script does not edit shell startup files directly, which is good. However, it prints shell code that the user is expected to paste. The paths in that shell code come from `WELCOME_BOARD_DATA_DIR` and `WELCOME_BOARD_AGENT_BIN_DIR` and are expanded inside a here-doc without shell quoting.

Concrete exploit scenario:

A wrapper, compromised environment, or copied command runs the installer with a crafted directory containing a double quote and shell syntax. The installer prints a startup line that looks official. If the user pastes it into `~/.bashrc`, the injected shell fragment runs on every new terminal.

Fix:

Shell-quote paths when printing startup snippets. Do not use an expanding here-doc for shell code.

Patch snippet:

```diff
diff --git a/install.sh b/install.sh
--- a/install.sh
+++ b/install.sh
@@
 AGENT_BIN_DIR="${WELCOME_BOARD_AGENT_BIN_DIR:-$HOME/.AGENTS/bin}"
+
+shell_quote() {
+  printf '%q' "$1"
+}
@@
 printf 'Add these lines to your shell startup file after reviewing them:\n\n'
-cat <<EOF
-[[ \$- == *i* ]] && [ -f "$DATA_DIR/welcome-board.sh" ] && source "$DATA_DIR/welcome-board.sh"
-[[ \$- == *i* ]] && [ -x "$AGENT_BIN_DIR/codex-claude-daily-update" ] && "$AGENT_BIN_DIR/codex-claude-daily-update" --notify-shell
-[[ \$- == *i* ]] && printf '\\n\\n'
-EOF
+board_file="$DATA_DIR/welcome-board.sh"
+updater_file="$AGENT_BIN_DIR/codex-claude-daily-update"
+printf '[[ $- == *i* ]] && [ -f %s ] && source %s\n' "$(shell_quote "$board_file")" "$(shell_quote "$board_file")"
+printf '[[ $- == *i* ]] && [ -x %s ] && %s --notify-shell\n' "$(shell_quote "$updater_file")" "$(shell_quote "$updater_file")"
+printf '[[ $- == *i* ]] && printf '\\''\\n\\n'\\''\n'
```

### MEDIUM - "Safe" install/snapshot writes can target unexpected paths and overwrite existing files

Locations:

- `install.sh:5`
- `install.sh:6`
- `install.sh:7`
- `install.sh:11`
- `install.sh:12`
- `install.sh:13`
- `install.sh:14`
- `bin/wb:293`
- `bin/wb:296`
- `bin/wb:297`

Issue:

Default paths are user-local, but the installer accepts destination directories from the environment and overwrites files with `cp`. `wb ports snapshot` accepts `WB_PORT_BASELINE_FILE` from config and writes to that path. There is no `$HOME` boundary check, backup, symlink check, or "already exists" warning.

Concrete exploit scenario:

An agent following the installer skill or prompt runs the installer under a stale environment where one destination variable points outside normal user-local storage. The script silently overwrites that path. Separately, a config can point `WB_PORT_BASELINE_FILE` at an unexpected file, and `wb ports snapshot` clobbers it while being described as safe/read-only. This is especially risky if a user runs the installer through `sudo` despite the project not requiring it.

Fix:

Refuse outside-`$HOME` install and snapshot destinations by default. Allow an explicit override only for advanced users. Back up files before overwriting.

Patch snippet:

```diff
diff --git a/install.sh b/install.sh
--- a/install.sh
+++ b/install.sh
@@
 AGENT_BIN_DIR="${WELCOME_BOARD_AGENT_BIN_DIR:-$HOME/.AGENTS/bin}"
+
+require_home_path() {
+  local path="$1" label="$2"
+  case "$path" in
+    "$HOME"|"$HOME"/*) ;;
+    *)
+      if [ "${WELCOME_BOARD_ALLOW_OUTSIDE_HOME:-0}" != 1 ]; then
+        printf 'Refusing %s outside $HOME: %s\n' "$label" "$path" >&2
+        printf 'Set WELCOME_BOARD_ALLOW_OUTSIDE_HOME=1 only after reviewing the path.\n' >&2
+        exit 2
+      fi
+      ;;
+  esac
+}
+backup_if_exists() {
+  local path="$1"
+  [ -e "$path" ] || return 0
+  cp -p "$path" "$path.bak.$(date +%Y%m%d%H%M%S)"
+}
+
+require_home_path "$BIN_DIR" WELCOME_BOARD_BIN_DIR
+require_home_path "$DATA_DIR" WELCOME_BOARD_DATA_DIR
+require_home_path "$AGENT_BIN_DIR" WELCOME_BOARD_AGENT_BIN_DIR
@@
-cp "$REPO_ROOT/welcome-board.sh" "$DATA_DIR/welcome-board.sh"
-cp "$REPO_ROOT/codex-claude-daily-update" "$AGENT_BIN_DIR/codex-claude-daily-update"
-cp "$REPO_ROOT/bin/wb" "$BIN_DIR/wb"
-cp "$REPO_ROOT/bin/welcomeboard" "$BIN_DIR/welcomeboard"
+backup_if_exists "$DATA_DIR/welcome-board.sh"
+backup_if_exists "$AGENT_BIN_DIR/codex-claude-daily-update"
+backup_if_exists "$BIN_DIR/wb"
+backup_if_exists "$BIN_DIR/welcomeboard"
+cp "$REPO_ROOT/welcome-board.sh" "$DATA_DIR/welcome-board.sh"
+cp "$REPO_ROOT/codex-claude-daily-update" "$AGENT_BIN_DIR/codex-claude-daily-update"
+cp "$REPO_ROOT/bin/wb" "$BIN_DIR/wb"
+cp "$REPO_ROOT/bin/welcomeboard" "$BIN_DIR/welcomeboard"
```

```diff
diff --git a/bin/wb b/bin/wb
--- a/bin/wb
+++ b/bin/wb
@@
 wb_config_quote() {
@@
 }
+
+wb_require_home_path() {
+  local path="$1" label="$2"
+  case "$path" in
+    "$HOME"|"$HOME"/*) ;;
+    *)
+      if [ "${WELCOME_BOARD_ALLOW_OUTSIDE_HOME:-0}" != 1 ]; then
+        printf 'Refusing %s outside $HOME: %s\n' "$label" "$path" >&2
+        return 2
+      fi
+      ;;
+  esac
+}
@@
   baseline="$(wb_config_get WB_PORT_BASELINE_FILE)"
   baseline="${baseline:-$HOME/.local/state/welcome-board/ports-baseline.txt}"
+  wb_require_home_path "$baseline" WB_PORT_BASELINE_FILE
   dir="$(dirname -- "$baseline")"
   mkdir -p "$dir"
+  [ ! -e "$baseline" ] || cp -p "$baseline" "$baseline.bak.$(date +%Y%m%d%H%M%S)"
   wb_ports_summary_lines > "$baseline"
```

### MEDIUM - Several login-time probes are synchronous and unbounded

Locations:

- `welcome-board.sh:286`
- `welcome-board.sh:294`
- `welcome-board.sh:375`
- `welcome-board.sh:556`
- `welcome-board.sh:659`
- `welcome-board.sh:660`

Issue:

The board is sourced inline during interactive shell startup, but several probes can block without a timeout: `ss`, `systemctl --user list-timers`, `crontab -l`, `nvidia-smi`, and two separate `tmux ls` calls. There are already timeouts around `tailscale status` and the peer TCP probe, which is the right pattern.

Concrete exploit scenario:

A wedged GPU driver, stuck user systemd bus, bad NSS/PAM/crontab path, or hung tmux server makes every new terminal appear frozen because the board runs before the prompt.

Fix:

Route non-trivial probes through a short timeout wrapper and collect `tmux ls` once. Keep fast local `/proc` and `/sys` reads as-is.

Patch snippet:

```diff
diff --git a/welcome-board.sh b/welcome-board.sh
--- a/welcome-board.sh
+++ b/welcome-board.sh
@@
 __wb_os() { case "$(uname -s 2>/dev/null)" in Darwin) echo macos;; *) echo linux;; esac; }
+__wb_run_timeout() {
+  local seconds="$1"; shift
+  if command -v timeout >/dev/null 2>&1; then
+    timeout "$seconds" "$@"
+  else
+    "$@"
+  fi
+}
@@
-    local tl; tl=$(systemctl --user list-timers --no-pager 2>/dev/null | grep -E '\.timer' | grep -vEi 'launchpadlib|man-db|fwupd|fstrim|logrotate')
+    local tl; tl=$(__wb_run_timeout 1 systemctl --user list-timers --no-pager 2>/dev/null | grep -E '\.timer' | grep -vEi 'launchpadlib|man-db|fwupd|fstrim|logrotate')
@@
-  ncron=$(crontab -l 2>/dev/null | grep -vcE '^\s*#|^\s*$')
+  ncron=$(__wb_run_timeout 1 crontab -l 2>/dev/null | grep -vcE '^\s*#|^\s*$')
@@
-    WB_LISTEN=$(ss -tlnH 2>/dev/null); WB_LISTENP=$(ss -tlnHp 2>/dev/null)
+    WB_LISTEN=$(__wb_run_timeout 1 ss -tlnH 2>/dev/null)
+    WB_LISTENP=$(__wb_run_timeout 1 ss -tlnHp 2>/dev/null)
@@
-  gpu=$(nvidia-smi --query-gpu=name,pstate,utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.gr,clocks.max.gr,clocks.mem,clocks.max.mem,power.draw,enforced.power.limit --format=csv,noheader,nounits 2>/dev/null | head -1)
+  gpu=$(__wb_run_timeout 2 nvidia-smi --query-gpu=name,pstate,utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.gr,clocks.max.gr,clocks.mem,clocks.max.mem,power.draw,enforced.power.limit --format=csv,noheader,nounits 2>/dev/null | head -1)
@@
-  local nssh sc ntmux tnames
+  local nssh sc ntmux tnames tmux_list
@@
-  ntmux=$(tmux ls 2>/dev/null | wc -l | tr -d ' '); : "${ntmux:=0}"
-  tnames=$(tmux ls 2>/dev/null | sed 's/:.*//' | paste -sd, - | sed 's/,/, /g')
+  tmux_list="$(__wb_run_timeout 1 tmux ls 2>/dev/null)"
+  ntmux=$(printf '%s\n' "$tmux_list" | sed '/^$/d' | wc -l | tr -d ' '); : "${ntmux:=0}"
+  tnames=$(printf '%s\n' "$tmux_list" | sed 's/:.*//' | paste -sd, - | sed 's/,/, /g')
```

### MEDIUM - Custom commands file is unbounded input at login

Locations:

- `welcome-board.sh:689`
- `welcome-board.sh:691`
- `welcome-board.sh:693`
- `skills/welcome-board-installer/SKILL.md:15`
- `prompts/install-with-agent.md:27`

Issue:

The custom commands file is intentionally user-local and not executed, which is good. But it is read on every render with no row count, file size, or line length cap. Because the board is sourced at login, a very large custom-commands file can make new shells slow or noisy. Combined with the terminal-injection issue above, this file is also a high-value display sink.

Concrete exploit scenario:

An automation step or confused installer agent writes a huge commands file or includes copied hostile terminal text. Every new shell reads it and renders rows until the file ends.

Fix:

Cap file size, rows, and per-field length. Update the installer skill and prompt to say custom command values are displayed only and must be plain printable text.

Patch snippet:

```diff
diff --git a/welcome-board.sh b/welcome-board.sh
--- a/welcome-board.sh
+++ b/welcome-board.sh
@@
-  local ccf="${WB_CUSTOM_COMMANDS_FILE:-$HOME/.config/welcome-board/commands}" cl cc ch
-  if [ -r "$ccf" ]; then
-    while IFS='|' read -r cl cc ch || [ -n "$cl" ]; do
+  local ccf="${WB_CUSTOM_COMMANDS_FILE:-$HOME/.config/welcome-board/commands}" cl cc ch n=0
+  if [ -r "$ccf" ] && [ "$(wc -c < "$ccf" 2>/dev/null || echo 0)" -le 16384 ]; then
+    while IFS='|' read -r cl cc ch || [ -n "$cl" ]; do
+      n=$((n+1)); [ "$n" -le 20 ] || break
       [ -z "$cl" ] && continue; case "$cl" in \#*) continue;; esac
-      __wb_cmdrow "${cl:0:9}" "${WB_CYN}${cc}${WB_FR}${ch:+   ${WB_D}${ch}}"
+      cl="$(__wb_safe_token "$cl" 32)"
+      cc="$(__wb_safe_token "$cc" 100)"
+      ch="$(__wb_safe_token "$ch" 100)"
+      __wb_cmdrow "${cl:0:9}" "${WB_CYN}${cc}${WB_FR}${ch:+   ${WB_D}${ch}}"
     done < "$ccf"
   fi
 }
```

```diff
diff --git a/skills/welcome-board-installer/SKILL.md b/skills/welcome-board-installer/SKILL.md
--- a/skills/welcome-board-installer/SKILL.md
+++ b/skills/welcome-board-installer/SKILL.md
@@
-- If the user gave custom commands, write a user-local custom command file using `LABEL|command|hint` rows and configure `WB_CUSTOM_COMMANDS_FILE`.
+- If the user gave custom commands, write a user-local custom command file using `LABEL|command|hint` rows and configure `WB_CUSTOM_COMMANDS_FILE`. Use only short printable text; these rows are displayed, not executed.
```

### MEDIUM - `wb render` can source an arbitrary file from environment override

Locations:

- `bin/wb:7`
- `bin/wb:8`
- `bin/wb:376`

Issue:

`WELCOME_BOARD_BOARD_FILE` can point `wb render` at any readable Bash file, and `wb_render` sources it. This is useful for development, but in a public installer helper it is also a code-execution footgun. The installer prompt and skill may lead agents to run `wb render` after setup while inheriting a polluted environment.

Concrete exploit scenario:

A malicious wrapper sets `WELCOME_BOARD_BOARD_FILE` to a different script before invoking `wb render`. The helper sources that file as the current user.

Fix:

Restrict the override to the repo copy or installed `$HOME/.local/share/welcome-board` copy by default. Add an explicit `WELCOME_BOARD_ALLOW_UNTRUSTED_BOARD_FILE=1` escape hatch for development.

Patch snippet:

```diff
diff --git a/bin/wb b/bin/wb
--- a/bin/wb
+++ b/bin/wb
@@
 WB_BOARD_FILE="${WELCOME_BOARD_BOARD_FILE:-$WB_REPO_ROOT/welcome-board.sh}"
 if [ ! -r "$WB_BOARD_FILE" ] && [ -r "$HOME/.local/share/welcome-board/welcome-board.sh" ]; then
   WB_BOARD_FILE="$HOME/.local/share/welcome-board/welcome-board.sh"
 fi
+case "$WB_BOARD_FILE" in
+  "$WB_REPO_ROOT/welcome-board.sh"|"$HOME/.local/share/welcome-board/welcome-board.sh") ;;
+  *)
+    if [ "${WELCOME_BOARD_ALLOW_UNTRUSTED_BOARD_FILE:-0}" != 1 ]; then
+      printf 'Refusing to source unexpected board file: %s\n' "$WB_BOARD_FILE" >&2
+      printf 'Set WELCOME_BOARD_ALLOW_UNTRUSTED_BOARD_FILE=1 only for local development.\n' >&2
+      exit 2
+    fi
+    ;;
+esac
```

### LOW - Peer probe still interpolates validated data into `bash -c`

Locations:

- `welcome-board.sh:648`
- `welcome-board.sh:649`

Issue:

The peer TCP probe validates host and port before using `/dev/tcp`, and it has a timeout. I did not find a practical shell-injection path through the current regexes. Still, interpolating config-derived values into a `bash -c` string is avoidable.

Concrete exploit scenario:

Current exploitability is low because `phost` is restricted to `[A-Za-z0-9._-]+` and `pport` to digits. If a future edit relaxes validation, the `bash -c` interpolation becomes dangerous.

Fix:

Pass host and port as positional parameters to the child shell and validate the port range.

Patch snippet:

```diff
diff --git a/welcome-board.sh b/welcome-board.sh
--- a/welcome-board.sh
+++ b/welcome-board.sh
@@
-    if [ -n "$probe" ] && [[ "$phost" =~ ^[A-Za-z0-9._-]+$ ]] && [[ "$pport" =~ ^[0-9]+$ ]] \
-       && timeout 0.8 bash -c "exec 3<>/dev/tcp/${phost}/${pport}" 2>/dev/null; then
+    if [ -n "$probe" ] && [[ "$phost" =~ ^[A-Za-z0-9._-]+$ ]] && [[ "$pport" =~ ^[0-9]+$ ]] \
+       && [ "$pport" -ge 1 ] 2>/dev/null && [ "$pport" -le 65535 ] 2>/dev/null \
+       && timeout 0.8 bash -c 'exec 3<>"/dev/tcp/$1/$2"' bash "$phost" "$pport" 2>/dev/null; then
```

### LOW - Config parsing is allowlisted, but values are not validated by type

Locations:

- `welcome-board.sh:36`
- `welcome-board.sh:38`
- `welcome-board.sh:40`
- `bin/wb:138`
- `bin/wb:140`

Issue:

The project does the important thing correctly: it does not `source` the config file. It reads allowlisted keys and assigns values with `printf -v`. That avoids direct shell execution. However, the loaded values are later used as loop inputs, labels, frame widths, and display text without type validation.

Concrete exploit scenario:

A malformed `WB_FRAME_INNER`, `WB_SERVICE_PORTS`, or `WB_PEERS` value can break layout, cause noisy output, or increase render work. This is more reliability hardening than command-injection prevention.

Fix:

Validate numeric fields and documented structured fields immediately after config loading.

Patch snippet:

```diff
diff --git a/welcome-board.sh b/welcome-board.sh
--- a/welcome-board.sh
+++ b/welcome-board.sh
@@
   : "${WB_DISPLAY_NAME:=${USER:-friend}}"
   : "${WB_BANNER_TEXT:=WORKSTATION}"
   : "${WB_THEME:=cyan-dark}"
   : "${WB_FRAME_INNER:=78}"
+  [[ "$WB_FRAME_INNER" =~ ^[0-9]+$ ]] || WB_FRAME_INNER=78
+  [ "$WB_FRAME_INNER" -ge 50 ] 2>/dev/null || WB_FRAME_INNER=78
+  [ "$WB_FRAME_INNER" -le 140 ] 2>/dev/null || WB_FRAME_INNER=78
   : "${WB_SERVICE_PORTS:=ssh:22 webdash:6900 embedder:6901 reranker:6902 honcho:6903 kenny-gate:6913 hermes:6916 cockpit:36900 qdrant:6333}"
```

## `wb ports` Read-Only Assessment

Confirmed: `wb ports scan`, `wb ports explain`, and `wb ports plan` do not change firewall rules, SSH settings, services, or sockets. `wb ports apply` and `wb ports rollback` are refused at `bin/wb:396`.

Important nuance: `wb ports snapshot` is read-only with respect to the network/firewall, but it writes a baseline file (`bin/wb:297`). That is accurately documented in the README, skill, prompt, and `docs/PORT_SECURITY_MODEL.md`; the path-hardening finding above is about where that file may be written.

## Privilege Assessment

- No `sudo` use found in the reviewed files.
- No firewall commands (`ufw`, `pfctl`, `iptables`, `nft`) are executed.
- No system service edits are performed by the installer or `wb ports`.
- Default install destinations are user-local: `$HOME/.local/bin`, `$HOME/.local/share/welcome-board`, and `$HOME/.AGENTS/bin`.
- `install.sh` copies and chmods files, but does not edit shell startup files itself.

## Looks Good

- Config is not sourced. `welcome-board.sh` reads only allowlisted keys and assigns them with `printf -v`.
- The peer `/dev/tcp` probe validates host and port and is already time-bounded.
- The installer prints startup lines for review instead of modifying shell startup files automatically.
- The agent skill and install prompt explicitly forbid firewall, SSH, service, and shell-startup mutation without exact approval.
- The Python updater uses `subprocess.run([...])` argv lists rather than shell strings, has subprocess timeouts, bounds log reads, and writes state atomically.
- `wb ports plan` is a dry-run explanation and does not print blind-paste firewall commands.
- `wb ports apply` and `wb ports rollback` intentionally fail closed.

## Recommended Fix Order

1. Fix terminal output first: switch `%b` to `%s`, add terminal sanitizers, and sanitize every probe/config/custom-command value before rendering.
2. Add timeouts around all non-trivial login probes.
3. Harden installer path printing and write boundaries.
4. Restrict `WELCOME_BOARD_BOARD_FILE` sourcing by default.
5. Add config/custom-command caps and field validation.
