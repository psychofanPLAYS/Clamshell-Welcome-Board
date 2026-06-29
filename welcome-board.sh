#!/usr/bin/env bash
# ============================================================================
#  WELCOME BOARD  (v4 — operator board: glanceable, symmetrical, cross-platform)
#  Prints on interactive shell start / SSH login. Sourced from ~/.bashrc.
#  Works on Linux + macOS. FAST + failure-tolerant: local checks only, every
#  field wrapped 2>/dev/null with a fallback. The board NEVER errors out and
#  NEVER blocks the prompt — a failed probe shows as "—", never a crash.
#  Self-contained; also runs via `wb render` / `welcomeboard`. Defines the
#  welcomeBoard / welcomeHelp / hkeys user commands when sourced.
#
#  Design rules (dark mode, 13" hi-dpi, dyslexia/ADHD, glance-first):
#   - few rows, aligned columns, ONE crisp outer frame, gold titles on dividers
#   - SYMMETRY LAW: only width-1 glyphs inside framed rows (box-drawing, █░,
#     ● ○ ▲ ✓ → ·). No emoji / no width-2 glyphs — keeps the right edge exact.
#   - color legend:  cyan = copyable command · green ok · yellow check
#                    red problem · pink tip · grey label.  NO dark blue.
#   - show real status, never narration; no fake peers, no placeholder data.
# ============================================================================

# ---- config (portable: values come from ~/.config/welcome-board/config) -----
__wb_config_value() {
  local raw="$1"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  if [[ "$raw" == \"*\" && "$raw" == *\" ]]; then
    raw="${raw#\"}"; raw="${raw%\"}"
    raw="${raw//\\\"/\"}"; raw="${raw//\\\\/\\}"
  fi
  printf '%s' "$raw"
}
__wb_default_banner_text() {
  local host
  host="$(hostname -s 2>/dev/null || printf WORKSTATION)"
  host="${host%%.*}"
  host="${host:-WORKSTATION}"
  printf '%s' "$host"
}
__wb_load_config() {
  [ "${_WB_CONFIG_LOADED:-0}" = 1 ] && return 0
  _WB_CONFIG_LOADED=1
  local cfg="${WELCOME_BOARD_CONFIG:-$HOME/.config/welcome-board/config}" key raw value
  if [ -r "$cfg" ]; then
    while IFS='=' read -r key raw || [ -n "$key" ]; do
      case "$key" in
        WB_DISPLAY_NAME|WB_BANNER_TEXT|WB_THEME|WB_SERVICE_PORTS|WB_EXPECTED_PORTS|\
WB_PEERS|WB_PORT_BASELINE_FILE|WB_HERMES_LABEL|WB_AUTOMATION_MATCH|WB_AUTOMATION_LABEL|WB_AUTOMATION_DAILY|WB_FRAME_INNER|\
WB_TAILSCALE_TIMEOUT|WB_PEER_PROBE_TIMEOUT|WB_NETWORK_COMMAND_TIMEOUT|WB_NETRATE_DELAY|WB_CPU_SAMPLE_DELAY|\
WB_STARTUP_LISTENER_TIMEOUT)
          value="$(__wb_config_value "$raw")"; printf -v "$key" '%s' "$value" ;;
      esac
    done < "$cfg"
  fi
  : "${WB_DISPLAY_NAME:=${USER:-friend}}"
  : "${WB_BANNER_TEXT:=$(__wb_default_banner_text)}"
  : "${WB_THEME:=cyan-dark}"
  : "${WB_FRAME_INNER:=78}"
  [[ "$WB_FRAME_INNER" =~ ^[0-9]+$ ]] || WB_FRAME_INNER=78
  [ "$WB_FRAME_INNER" -ge 50 ] 2>/dev/null || WB_FRAME_INNER=78
  [ "$WB_FRAME_INNER" -le 140 ] 2>/dev/null || WB_FRAME_INNER=78
  : "${WB_SERVICE_PORTS:=ssh:22 webdash:6900 embedder:6901 reranker:6902 honcho:6903 kenny-gate:6913 hermes:6916 cockpit:36900 qdrant:6333}"
  : "${WB_PORT_BASELINE_FILE:=$HOME/.local/state/welcome-board/ports-baseline.txt}"
  : "${WB_AUTOMATION_MATCH:=oppy superbrain kenny darkfactory trading codex claude hermes lcm curator reindex secondbrain news update-safe xtreme resource-recycler}"
}

# ---- palette (256-colour, tuned per theme) ----------------------------------
__wb_paint() {
  WB_R=$'\e[0m'; WB_B=$'\e[1m'; WB_FR=$'\e[22;24;39m'
  WB_GRN=$'\e[38;5;78m'; WB_RED=$'\e[38;5;203m'
  case "${WB_THEME:-cyan-dark}" in
    amber-terminal)
      WB_D=$'\e[38;5;244m'; WB_YEL=$'\e[38;5;220m'; WB_CYN=$'\e[38;5;214m'
      WB_PNK=$'\e[38;5;209m'; WB_GRY=$'\e[38;5;250m'; WB_WHT=$'\e[38;5;254m'
      WB_HDR=$'\e[38;5;222m'; WB_AC=$'\e[38;5;214m'; WB_LBL=$'\e[1m\e[38;5;222m'
      WB_DEV=$'\e[38;5;180m'; WB_GOLD=$'\e[1m\e[38;5;220m'; WB_NEON_ORANGE=$'\e[1m\e[38;5;208m'
      ;;
    green-phosphor)
      WB_D=$'\e[38;5;242m'; WB_YEL=$'\e[38;5;190m'; WB_CYN=$'\e[38;5;84m'
      WB_PNK=$'\e[38;5;120m'; WB_GRY=$'\e[38;5;250m'; WB_WHT=$'\e[38;5;255m'
      WB_HDR=$'\e[38;5;120m'; WB_AC=$'\e[38;5;48m'; WB_LBL=$'\e[1m\e[38;5;120m'
      WB_DEV=$'\e[38;5;150m'; WB_GOLD=$'\e[1m\e[38;5;154m'; WB_NEON_ORANGE=$'\e[1m\e[38;5;118m'
      ;;
    light-paper)
      WB_D=$'\e[38;5;240m'; WB_YEL=$'\e[38;5;136m'; WB_CYN=$'\e[38;5;31m'
      WB_PNK=$'\e[38;5;125m'; WB_GRY=$'\e[38;5;238m'; WB_WHT=$'\e[38;5;233m'
      WB_HDR=$'\e[38;5;25m'; WB_AC=$'\e[38;5;31m'; WB_LBL=$'\e[1m\e[38;5;25m'
      WB_DEV=$'\e[38;5;94m'; WB_GOLD=$'\e[1m\e[38;5;130m'; WB_NEON_ORANGE=$'\e[1m\e[38;5;166m'
      ;;
    mono-safe)
      WB_D=$'\e[38;5;245m'; WB_YEL=$'\e[38;5;250m'; WB_CYN=$'\e[38;5;250m'
      WB_PNK=$'\e[38;5;250m'; WB_GRY=$'\e[38;5;245m'; WB_WHT=$'\e[38;5;253m'
      WB_HDR=$'\e[38;5;253m'; WB_AC=$'\e[38;5;245m'; WB_LBL=$'\e[1m\e[38;5;253m'
      WB_DEV=$'\e[38;5;250m'; WB_GOLD=$'\e[1m\e[38;5;253m'; WB_NEON_ORANGE=$'\e[1m\e[38;5;253m'
      ;;
    *)
      WB_D=$'\e[38;5;245m'; WB_YEL=$'\e[38;5;221m'; WB_CYN=$'\e[38;5;81m'
      WB_PNK=$'\e[38;5;211m'; WB_GRY=$'\e[38;5;250m'; WB_WHT=$'\e[38;5;253m'
      WB_HDR=$'\e[38;5;117m'; WB_AC=$'\e[38;5;81m'; WB_LBL=$'\e[1m\e[38;5;111m'
      WB_DEV=$'\e[38;5;180m'; WB_GOLD=$'\e[1m\e[38;5;220m'; WB_NEON_ORANGE=$'\e[1m\e[38;5;208m'
      ;;
  esac
  WB_DM=$'\006'                 # sentinel for adaptive-dim grey (swapped per stripe)
}

# ---- platform ---------------------------------------------------------------
__wb_os() { case "$(uname -s 2>/dev/null)" in Darwin) echo macos;; *) echo linux;; esac; }
__wb_run_timeout() {
  local seconds="$1" timeout_bin; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout_bin=timeout
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_bin=gtimeout
  fi
  if [ -n "${timeout_bin:-}" ]; then
    "$timeout_bin" "$seconds" "$@"
  else
    "$@"
  fi
}
__wb_seconds() {
  local value="${1:-}" fallback="${2:-1}"
  [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] && printf '%s' "$value" || printf '%s' "$fallback"
}

# ---- tiny state + startup UX helpers ---------------------------------------
__wb_state_file() {
  printf '%s' "${WELCOME_BOARD_STATE_FILE:-$HOME/.local/state/welcome-board/settings.state}"
}
__wb_state_get() {
  local key="$1" default="${2:-}" file value
  file="$(__wb_state_file)"
  if [ -r "$file" ]; then
    value=$(awk -F= -v k="$key" '$1==k {print substr($0, length(k)+2); found=1} END{exit found?0:1}' "$file" 2>/dev/null) \
      && { printf '%s' "$value"; return; }
  fi
  printf '%s' "$default"
}
__wb_state_set() {
  local key="$1" value="$2" file dir tmp
  [[ "$key" =~ ^[A-Za-z0-9_]+$ ]] || return 2
  value="$(__wb_safe_token "$value" 200)"
  file="$(__wb_state_file)"; dir=$(dirname "$file")
  mkdir -p "$dir" 2>/dev/null || return 0
  tmp="${file}.tmp.$$"
  if [ -r "$file" ]; then awk -F= -v k="$key" '$1!=k {print}' "$file" > "$tmp" 2>/dev/null || : > "$tmp"; else : > "$tmp"; fi
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$file" 2>/dev/null || rm -f "$tmp"
}
__wb_state_increment() {
  local key="$1" value
  value="$(__wb_state_get "$key" 0)"
  [[ "$value" =~ ^[0-9]+$ ]] || value=0
  value=$((value + 1))
  __wb_state_set "$key" "$value"
  printf '%s' "$value"
}
__wb_interactive_terminal() { [[ $- == *i* ]] && [ -t 0 ] && [ -t 1 ]; }
__wb_quiet_start() {
  [ "${WB_HIDE_INPUT_DURING_RENDER:-1}" != 0 ] || return 0
  [ -t 0 ] && [ -t 1 ] || return 0
  _WB_STTY_SAVED=$(stty -g </dev/tty 2>/dev/null || true)
  [ -n "$_WB_STTY_SAVED" ] && stty -echo </dev/tty 2>/dev/null || true
}
__wb_quiet_stop() {
  [ -n "${_WB_STTY_SAVED:-}" ] && stty "$_WB_STTY_SAVED" </dev/tty 2>/dev/null || true
  _WB_STTY_SAVED=""
}
# ---- frame + row primitives -------------------------------------------------
__wb_repeat() {
  local ch="$1" n="$2" out; ((n < 0)) && n=0
  printf -v out '%*s' "$n" ''; printf '%s' "${out// /$ch}"
}
__wb_frame_top()    { printf '  %s┌%s┐%s\n' "$WB_AC" "$(__wb_repeat '─' "$WB_FRAME_INNER")" "$WB_R"; }
__wb_frame_bottom() { printf '  %s└%s┘%s\n' "$WB_AC" "$(__wb_repeat '─' "$WB_FRAME_INNER")" "$WB_R"; }
__wb_lbl() { printf '%s%-11s%s' "$WB_GRY" "$1" "$WB_R"; }

# visible width = code points after stripping ANSI + the dim sentinel.
# SYMMETRY LAW keeps every framed glyph width-1, so this equals display columns.
__wb_vis() {
  local s
  s=$(printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*m//g' | tr -d "$WB_DM")
  LC_ALL=C.UTF-8 printf '%s' "$s" | wc -m | awk '{print $1}'
}
__wb_safe_text() {
  local s="${1-}"
  s="${s//$'\r'/ }"
  s="${s//$'\n'/ }"
  s="${s//$'\t'/ }"
  s="${s//$'\e'/}"
  LC_ALL=C printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037\177'
}
__wb_safe_token() {
  local max="${2:-160}" s
  s="$(__wb_safe_text "${1-}")"
  printf '%s' "${s:0:max}"
}
__wb_uint() {
  local n="${1:-0}"
  [[ "$n" =~ ^[0-9]+$ ]] || n=0
  printf '%s' "$n"
}
# escape-aware clip: trims painted content to <= $2 VISIBLE columns, never cuts
# mid-escape, appends a dim ellipsis. Overflow safety net so NO row breaks the frame.
__wb_clip() {
  local s="$1" max="$2" out="" vis=0 n i ch
  n=${#s}
  for ((i=0;i<n;i++)); do
    ch="${s:i:1}"
    if [ "$ch" = $'\e' ]; then
      out+="$ch"; ((i++))
      while ((i<n)); do ch="${s:i:1}"; out+="$ch"; case "$ch" in [a-zA-Z]) break;; esac; ((i++)); done
      continue
    fi
    [ "$ch" = $'\006' ] && { out+="$ch"; continue; }     # dim sentinel = zero width
    if ((vis>=max-1)); then out+="…"; break; fi
    out+="$ch"; ((vis++))
  done
  printf '%s' "$out"
}
__wb_plainrow() {
  local c="$1" zw=${WB_ZW:-72} vis pad
  c=${c//$WB_DM/$WB_D}; vis=$(__wb_vis "$c")
  if (( vis > zw-1 )); then c=$(__wb_clip "$c" $((zw-1))); vis=$(__wb_vis "$c"); fi
  pad=$(( zw - 1 - vis )); ((pad<0)) && pad=0
  printf '  %s│%s %s%*s%s│%s\n' "$WB_AC" "$WB_R" "$c" "$pad" '' "$WB_AC" "$WB_R"
}
_WB_ZEB=0
__wb_zreset() { _WB_ZEB=0; }
__wb_zrow() {                                         # $1 = WB_FR-reset content
  local c="$1" bg dim zw=${WB_ZW:-72} vis pad
  if ((_WB_ZEB%2==0)); then bg=$'\e[48;5;236m'; dim=$'\e[38;5;109m'
  else                       bg=$'\e[48;5;233m'; dim=$'\e[38;5;116m'; fi
  _WB_ZEB=$(( _WB_ZEB+1 ))
  c=${c//$WB_DM/$dim}; c=${c//$WB_R/$WB_FR}; vis=$(__wb_vis "$c")
  if (( vis > zw-1 )); then c=$(__wb_clip "$c" $((zw-1))); vis=$(__wb_vis "$c"); fi
  pad=$(( zw - 1 - vis )); ((pad<0)) && pad=0
  printf '  %s│%s %s%*s%s│%s\n' "$WB_AC" "$bg" "$c" "$pad" '' "$WB_AC" "$WB_R"
}

# ---- time-aware greeting (first name only, from config) ---------------------

# ---- BANNER (machine mark; figlet-style block art + binary subtitle) --------
__wb_banner_baked() {   # legacy ANSI-Shadow art used only when explicitly wired
  cat <<'ART'
  ██████╗██╗      █████╗ ███╗   ███╗███████╗██╗  ██╗███████╗██╗     ██╗
 ██╔════╝██║     ██╔══██╗████╗ ████║██╔════╝██║  ██║██╔════╝██║     ██║
 ██║     ██║     ███████║██╔████╔██║███████╗███████║█████╗  ██║     ██║
 ██║     ██║     ██╔══██║██║╚██╔╝██║╚════██║██╔══██║██╔══╝  ██║     ██║
 ╚██████╗███████╗██║  ██║██║ ╚═╝ ██║███████║██║  ██║███████╗███████╗███████╗
  ╚═════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝
ART
}
__wb_banner_art() {   # echoes the banner art lines (no colour).
  local txt upper
  txt="$(__wb_safe_token "${WB_BANNER_TEXT:-$(__wb_default_banner_text)}" 40)"
  [ -n "$txt" ] || txt="WORKSTATION"
  upper="$(printf '%s' "$txt" | tr '[:lower:]' '[:upper:]')"
  [ "$upper" = "CLAMSHELL" ] && { __wb_banner_baked; return; }
  if command -v figlet >/dev/null 2>&1; then
    figlet -w 120 -- "$txt" 2>/dev/null | grep -v '^[[:space:]]*$'
  elif command -v toilet >/dev/null 2>&1; then
    toilet -w 120 -f standard -- "$txt" 2>/dev/null | grep -v '^[[:space:]]*$'
  else
    printf '  >>>  %s  <<<\n' "$txt"
  fi
}
__wb_banner_color_lines() {
  case "${WB_THEME:-cyan-dark}" in
    amber-terminal) printf '%s\n' $'\e[38;5;220m' $'\e[38;5;214m' $'\e[38;5;208m' $'\e[38;5;202m' $'\e[38;5;166m' $'\e[38;5;130m' ;;
    green-phosphor) printf '%s\n' $'\e[38;5;154m' $'\e[38;5;120m' $'\e[38;5;84m' $'\e[38;5;48m' $'\e[38;5;40m' $'\e[38;5;34m' ;;
    light-paper) printf '%s\n' $'\e[38;5;25m' $'\e[38;5;31m' $'\e[38;5;37m' $'\e[38;5;94m' $'\e[38;5;130m' $'\e[38;5;166m' ;;
    mono-safe) printf '%s\n' $'\e[38;5;253m' $'\e[38;5;250m' $'\e[38;5;248m' $'\e[38;5;246m' $'\e[38;5;244m' $'\e[38;5;242m' ;;
    *) printf '%s\n' $'\e[38;5;45m' $'\e[38;5;81m' $'\e[38;5;75m' $'\e[38;5;39m' $'\e[38;5;33m' $'\e[38;5;69m' ;;
  esac
}
# binary subtitle = the banner word as 8-bit ASCII (pure bash, bash-3.2 safe)
__wb_banner_binary() {
  local txt b="" i j ch code byte
  txt=$(printf '%s' "$(__wb_safe_token "${WB_BANNER_TEXT:-$(__wb_default_banner_text)}" 40)" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'); : "${txt:=workstation}"
  txt="${txt:0:12}"
  for ((i=0; i<${#txt}; i++)); do
    ch="${txt:i:1}"; printf -v code '%d' "'$ch"; byte=""
    for ((j=7; j>=0; j--)); do byte="$byte$(( (code>>j)&1 ))"; done
    b="${b:+$b }$byte"
  done
  printf '%s' "$b"
}
__wb_banner() {
  local binary; binary=$(__wb_banner_binary)
  local -a art=(); local __l; while IFS= read -r __l; do art+=("$__l"); done < <(__wb_banner_art)
  local -a g=(); while IFS= read -r __l; do g+=("$__l"); done < <(__wb_banner_color_lines)
  local i line lead minlead=99 max_art=0 fw=$(( WB_FRAME_INNER + 2 )) pad bpad
  # normalize: strip the common leading whitespace so the art block is flush-left
  for line in "${art[@]}"; do lead="${line%%[![:space:]]*}"; (( ${#lead} < minlead )) && minlead=${#lead}; done
  (( minlead == 99 )) && minlead=0
  for i in "${!art[@]}"; do art[i]="${art[i]:minlead}"; (( ${#art[i]} > max_art )) && max_art=${#art[i]}; done
  # center the banner block within the frame box (cols 2..81 = 2-space indent + 80-col box)
  pad=$(( 2 + (fw - max_art) / 2 )); ((pad < 0)) && pad=0
  for i in "${!art[@]}"; do printf '%*s%s%s%s\n' "$pad" '' "${g[i]}" "${art[i]}" "$WB_R"; done
  # center the binary subtitle the same way
  bpad=$(( 2 + (fw - ${#binary}) / 2 )); ((bpad < 0)) && bpad=0
  printf '%*s%s%s%s\n' "$bpad" '' "$WB_HDR" "$binary" "$WB_R"
}

# ---- MACHINE helpers --------------------------------------------------------
__wb_grad() {
  local p="$1" col; [[ "$p" =~ ^[0-9]+$ ]] || p=0
  if   ((p<17)); then col=78;  elif ((p<34)); then col=113; elif ((p<50)); then col=149
  elif ((p<64)); then col=185; elif ((p<76)); then col=214; elif ((p<86)); then col=208
  elif ((p<94)); then col=202; else col=160; fi
  printf '\e[38;5;%sm' "$col"
}
__wb_bar() {
  local pct="$1" w=8 fill i bar; [[ "$pct" =~ ^[0-9]+$ ]] || pct=0
  fill=$(( pct*w/100 )); ((fill>w))&&fill=w; ((fill<0))&&fill=0
  bar="$(__wb_grad "$pct")"; for ((i=0;i<fill;i++)); do bar+="█"; done
  bar+="$WB_DM"; for ((i=fill;i<w;i++)); do bar+="░"; done
  printf '%s%s' "$bar" "$WB_FR"
}
__wb_tcol() { local t="${1:-0}"; [[ "$t" =~ ^[0-9]+$ ]] || { printf '%s' "$WB_GRY"; return; }
  if ((t>=80)); then printf '%s' "$WB_RED"; elif ((t>=70)); then printf '%s' "$WB_YEL"; else printf '%s' "$WB_GRN"; fi; }
__wb_cpu_load_fallback() {
  awk -v n="$(nproc 2>/dev/null || echo 1)" '
    { n=(n+0<1)?1:n; p=($1+0)/n*100; p=(p<0)?0:p; p=(p>100)?100:p; printf "%d", p }
  ' /proc/loadavg 2>/dev/null || printf '0'
}
__wb_cpubusy() {
  local t1 i1 t2 i2 dt di delay stat_file
  stat_file="${WB_CPU_STAT_FILE:-/proc/stat}"
  delay="$(__wb_seconds "${WB_CPU_SAMPLE_DELAY:-0.20}" 0.20)"
  if [ "$delay" = 0 ] || [ ! -r "$stat_file" ]; then
    __wb_cpu_load_fallback
    return
  fi
  read -r t1 i1 < <(awk '/^cpu /{idle=$5+$6;tot=0;for(i=2;i<=NF;i++)tot+=$i;print tot,idle}' "$stat_file" 2>/dev/null)
  sleep "$delay" 2>/dev/null
  read -r t2 i2 < <(awk '/^cpu /{idle=$5+$6;tot=0;for(i=2;i<=NF;i++)tot+=$i;print tot,idle}' "$stat_file" 2>/dev/null)
  [[ "${t1:-}" =~ ^[0-9]+$ && "${i1:-}" =~ ^[0-9]+$ && "${t2:-}" =~ ^[0-9]+$ && "${i2:-}" =~ ^[0-9]+$ ]] || { __wb_cpu_load_fallback; return; }
  dt=$(( ${t2:-0}-${t1:-0} )); di=$(( ${i2:-0}-${i1:-0} ))
  if ((dt>0)); then
    awk -v p="$(( (100*(dt-di))/dt ))" 'BEGIN{p=(p<0)?0:p; p=(p>100)?100:p; printf "%d", p}'
  else
    __wb_cpu_load_fallback
  fi
}

# ---- MACHINE (Linux: full gauges; macOS: graceful subset) -------------------

# ---- NETWORK + SESSIONS (real probes only — tailscale + TCP + who + tmux) ----

# ---- SECURITY (curated, intelligent alerts — not raw port dumps) ------------
__wb_portname() {
  case "$1" in
    22) echo SSH;; 53) echo DNS;; 139|445) echo Samba;; 631) echo printing;;
    5432) echo Postgres;; 6333) echo vector-DB;; 6900) echo webdash;;
    6901) echo embedder;; 6902) echo reranker;; 6903) echo memory;;
    6904|6905|6907) echo proxy;; 6911) echo xtreme-proxy;; 6913) echo kenny-gate;;
    6916) echo Hermes;; 36900) echo cockpit;; 37360) echo media;; *) echo "port $1";;
  esac
}
__wb_group() {  # $1 = ports, $2 = name colour. Lists unique friendly names, port-sorted.
  local p n out="" seen=$'\n'
  for p in $(echo "$1" | tr ' ' '\n' | sort -nu); do
    n=$(__wb_portname "$p")
    case "$seen" in *"$n"$'\n'*) continue;; esac; seen="$seen$n"$'\n'
    out="$out${WB_DM}, ${2}${n}"
  done
  printf '%s' "${out#${WB_DM}, }"
}
__wb_security() {
  __wb_hdr "SECURITY"
  __wb_zreset
  if [ "$(__wb_os)" = macos ] || ! command -v ss >/dev/null 2>&1; then
    __wb_zrow "${WB_DM}listener scan needs Linux ${WB_CYN}ss${WB_DM} — skipped on this host"
    return
  fi
  local expected=" 22 139 445 631 6900 6901 6902 6903 6904 6905 6907 6913 6916 36900 37360 "
  local lan="" alert="" rygel_ports="" line port addr proc seen=" "
  while read -r line; do
    read -r _ _ _ addr _ proc <<<"$line"
    port="${addr##*:}"; addr="${addr%:*}"; addr="${addr%\%*}"; addr="${addr//[\[\]]/}"
    case "$addr" in 127.*|::1|100.*|fd7a:*|fe80:*) continue;; esac
    case "$seen" in *" $port "*) continue;; esac; seen="$seen$port "
    if [[ "$proc" == *rygel* ]]; then rygel_ports="$rygel_ports $port"
    elif [[ "$expected" == *" $port "* ]]; then lan="$lan $port"
    else alert="$alert $port"; fi
  done < <(echo "$WB_LISTENP")
  if [ -n "$alert" ]; then
    __wb_zrow "${WB_RED}${WB_B}▲ Unrecognized door:${WB_FR} ${WB_RED}$(__wb_group "$alert" "$WB_RED")${WB_DM} — investigate"
  else
    __wb_zrow "${WB_GRN}${WB_B}✓ Locked.${WB_FR} ${WB_DM}LAN doors ok: ${WB_WHT}$(__wb_group "$lan" "$WB_WHT")"
    __wb_zrow "${WB_DM}rest is loopback (this PC) or Tailscale VPN only — no strangers."
  fi
  [ -n "$rygel_ports" ] && __wb_zrow "${WB_DM}known service: ${WB_WHT}media server${WB_DM} on ${WB_WHT}${rygel_ports# }"
}

# ---- SERVICES (config-driven; webdash label; real listener check) -----------
__wb_services() {
  __wb_hdr "SERVICES"
  local -a uplist=() downlist=(); local e n p nup=0 ntot=0
  for e in $WB_SERVICE_PORTS; do
    n="$(__wb_safe_token "${e%:*}" 32)"; p="${e##*:}"
    [[ "$p" =~ ^[0-9]+$ ]] || continue
    ntot=$((ntot+1))
    if echo "$WB_LISTEN" | grep -q ":$p "; then uplist+=("$n"); nup=$((nup+1)); else downlist+=("$n"); fi
  done
  __wb_zreset
  if [ "${#downlist[@]}" -gt 0 ]; then
    __wb_zrow "${WB_RED}${WB_B}▲ ${#downlist[@]} down:${WB_FR} ${WB_RED}${downlist[*]}${WB_FR}   ${WB_DM}(${nup}/${ntot} up)"
  else
    __wb_zrow "${WB_GRN}${WB_B}✓ All ${ntot} up.${WB_FR}"
  fi
  # list service names, wrapped so the row never overflows the frame
  local row="" rowvis=0 w
  for w in "${uplist[@]}"; do
    if (( rowvis + ${#w} + 3 > 66 )) && [ -n "$row" ]; then __wb_zrow "$row"; row=""; rowvis=0; fi
    if [ -z "$row" ]; then row="${WB_WHT}$w"; rowvis=${#w}
    else row="$row${WB_DM} · ${WB_WHT}$w"; rowvis=$(( rowvis + 3 + ${#w} )); fi
  done
  [ -n "$row" ] && __wb_zrow "$row"
}

# ---- AUTOMATION (OUR scheduled jobs — Claude/Codex/Hermes loops + cron) ------
#  Sources: `systemctl --user list-timers` (user scope already excludes system
#  timers) + `crontab -l`. No system bus, ever.
__wb_automation() {
  __wb_hdr "AUTOMATION"
  __wb_zreset
  local have_timer=0
  command -v systemctl >/dev/null 2>&1 && __wb_run_timeout 1 systemctl --user show-environment >/dev/null 2>&1 && have_timer=1
  local ntimers=0 ncron=0 nextlist=""
  if [ "$have_timer" = 1 ]; then
    local tl; tl=$(__wb_run_timeout 1 systemctl --user list-timers --no-pager 2>/dev/null | grep -E '\.timer' | grep -vEi 'launchpadlib|man-db|fwupd|fstrim|logrotate' || true)
    ntimers=$(printf '%s\n' "$tl" | grep -cE '\.timer')
    local u names=() pretty="" x
    while read -r u; do [ -n "$u" ] && names+=("${u%.timer}"); done \
      < <(printf '%s\n' "$tl" | awk '{for(i=1;i<=NF;i++) if($i ~ /\.timer$/){print $i; break}}' | head -3)
    for x in "${names[@]}"; do x="$(__wb_safe_token "$x" 80)"; pretty="$pretty${WB_DM}, ${WB_WHT}${x}"; done
    nextlist="${pretty#${WB_DM}, }"
  fi
  ncron=$(__wb_run_timeout 1 crontab -l 2>/dev/null | grep -vcE '^\s*#|^\s*$' || true)
  if [ "$have_timer" = 1 ] || [ "${ncron:-0}" -gt 0 ]; then
    local label=""; [ -n "${WB_AUTOMATION_LABEL:-}" ] && label=" ${WB_DM}— $(__wb_safe_token "$WB_AUTOMATION_LABEL" 80)"
    __wb_zrow "${WB_LBL}$(printf '%-9s' 'jobs')${WB_FR}${WB_WHT}${ntimers}${WB_DM} loops · ${WB_WHT}${ncron}${WB_DM} cron${label}"
    [ -n "$nextlist" ] && __wb_zrow "${WB_LBL}$(printf '%-9s' 'next up')${WB_FR}${nextlist}"
    [ -n "${WB_AUTOMATION_DAILY:-}" ] && __wb_zrow "${WB_LBL}$(printf '%-9s' 'daily')${WB_FR}${WB_DM}$(__wb_safe_token "$WB_AUTOMATION_DAILY" 120)"
  else
    __wb_zrow "${WB_DM}no user scheduler configured on this host"
  fi
}

# ---- HERMES shortcut cheat-sheet (aphasia aid) ------------------------------
__hkeys_frame_cmd() {
  local suf="$1" desc="$2" tok vis pad
  tok="${WB_CYN}m${WB_B}${WB_YEL}#${WB_FR}${WB_CYN}${suf}${WB_FR}"
  vis=$(( 2 + ${#suf} )); pad=$(( 13 - vis )); ((pad < 1)) && pad=1
  __wb_zrow "   ${tok}$(printf '%*s' "$pad" '')${WB_WHT}${desc}"
}
__hkeys_frame_head() { __wb_zrow " ${WB_HDR}${WB_B}$1${WB_FR}"; }
__hkeys_frame_gap()  { __wb_plainrow ""; }
__wb_hermes_full() {
  __wb_hdr "HERMES"
  __wb_zreset
  __wb_zrow " ${WB_B}${WB_YEL}#${WB_FR} ${WB_WHT}= brother number${WB_DM}; use ${WB_B}${WB_YEL}1${WB_FR}${WB_DM}=master-1-codex, ${WB_B}${WB_YEL}2${WB_FR}${WB_DM}=master-2-local"
  __wb_zrow " ${WB_DM}typed for real: ${WB_CYN}m1c${WB_FR}${WB_DM} or ${WB_CYN}m2c${WB_FR}${WB_DM}; base works too: ${WB_CYN}m1 status${WB_FR}"
  __hkeys_frame_gap
  __hkeys_frame_head "EVERYDAY"
  __hkeys_frame_cmd c "chat with the brother"
  __hkeys_frame_cmd s "status"
  __hkeys_frame_cmd g "gateway  (add: start / stop / restart / status)"
  __hkeys_frame_cmd d "dashboard"
  __hkeys_frame_cmd k "kanban  (shared task board)"
  __hkeys_frame_gap
  __hkeys_frame_head "TURN ON / OFF · FIX-IT"
  __hkeys_frame_cmd up     "gateway start   ${WB_DM}(m#down stop · m#re restart)"
  __hkeys_frame_cmd doctor "check config + dependencies  ${WB_DM}(try this first)"
  __hkeys_frame_cmd setup  "interactive setup wizard"
  __wb_zrow " ${WB_DM}reprint this section any time: ${WB_CYN}hkeys${WB_FR}${WB_DM} (or ${WB_CYN}keys${WB_FR}${WB_DM})"
}

# ---- COMMANDS (cyan = copyable; tmux + operator commands) -------------------

# ---- FOOTER (update notice — below the board so it never confuses hierarchy) -

# ============================ render =========================================
__wb_probe_listeners() {
  local timeout_seconds="${1:-${WB_LISTENER_TIMEOUT:-1}}" with_processes="${2:-1}"
  if [ "$(__wb_os)" = linux ] && command -v ss >/dev/null 2>&1; then
    WB_LISTEN=$(__wb_run_timeout "$timeout_seconds" ss -tlnH 2>/dev/null || true)
    if [ "$with_processes" = 1 ]; then
      WB_LISTENP=$(__wb_run_timeout "$timeout_seconds" ss -tlnHp 2>/dev/null || true)
    else
      WB_LISTENP="$WB_LISTEN"
    fi
  else WB_LISTEN=""; WB_LISTENP=""; fi
}
__wb_render_body() {
  _WB_HDR_COUNT=0
  _WB_HIST_TRIMMED=""
  __wb_frame_top || true
  __wb_greeting_row || true
  __wb_machine || true
  __wb_network || true
  __wb_security || true
  __wb_services || true
  __wb_automation || true
  __wb_hermes || true
  __wb_commands || true
  __wb_frame_bottom || true
  __wb_footer || true
}
__wb_render() {
  local mode="${1:-auto}" body_file startup_fast=0
  if [ "$mode" = startup ]; then
    startup_fast=1
    mode=auto
  fi
  [ "$mode" = startup-fast ] && { startup_fast=1; mode=auto; }
  local WB_STARTUP_FAST="${WB_STARTUP_FAST:-$startup_fast}"
  if [ "$startup_fast" = 1 ]; then
    local WB_CPU_SAMPLE_DELAY="${WB_CPU_SAMPLE_DELAY:-0.08}"
    local WB_NETRATE_DELAY="${WB_NETRATE_DELAY:-0}"
    local WB_CPU_RECENT_SOURCE="${WB_CPU_RECENT_SOURCE:-history}"
    local WB_LISTENER_TIMEOUT="${WB_LISTENER_TIMEOUT:-0.12}"
    local WB_TAILSCALE_TIMEOUT="${WB_TAILSCALE_TIMEOUT:-0.2}"
    local WB_PEER_PROBE_TIMEOUT="${WB_PEER_PROBE_TIMEOUT:-0.05}"
    local WB_NETWORK_COMMAND_TIMEOUT="${WB_NETWORK_COMMAND_TIMEOUT:-0.2}"
  fi
  __wb_load_config; __wb_paint
  WB_FRAME_ON=1; WB_W=$WB_FRAME_INNER; WB_ZW=$WB_FRAME_INNER

  __wb_quiet_start
  trap '__wb_quiet_stop; trap - RETURN INT TERM' RETURN INT TERM

  body_file=$(mktemp "${TMPDIR:-/tmp}/welcome-board-body.XXXXXX" 2>/dev/null || printf '')
  if [ -n "$body_file" ]; then
    { __wb_probe_listeners "${WB_LISTENER_TIMEOUT:-1}" 1; __wb_render_body; } > "$body_file" 2>/dev/null
    printf '\n'
    __wb_banner
    cat "$body_file"
    rm -f "$body_file"
  else
    __wb_probe_listeners "${WB_LISTENER_TIMEOUT:-1}" 1
    printf '\n'
    __wb_banner
    __wb_render_body
  fi

  if __wb_interactive_terminal; then
    __wb_state_increment start_count >/dev/null
  fi
  __wb_quiet_stop
  WB_FRAME_ON=0
  trap - RETURN INT TERM
}

__wb_startup_cache_file() {
  printf '%s' "${WELCOME_BOARD_STARTUP_CACHE_FILE:-$HOME/.cache/welcome-board/startup-render.txt}"
}
__wb_startup_cache_ttl() {
  local ttl="${WELCOME_BOARD_STARTUP_CACHE_TTL:-300}"
  [[ "$ttl" =~ ^[0-9]+$ ]] || ttl=300
  printf '%s' "$ttl"
}
__wb_startup_cache_update() {
  [ "${WELCOME_BOARD_STARTUP_CACHE:-1}" = 1 ] || return 1
  local cache_file cache_dir tmp
  cache_file="$(__wb_startup_cache_file)"
  cache_dir="$(dirname "$cache_file")"
  mkdir -p "$cache_dir" 2>/dev/null || return 1
  tmp="${cache_file}.tmp.$$"
  WELCOME_BOARD_STARTUP_CACHE=0 __wb_render startup >"$tmp" 2>/dev/null || {
    rm -f "$tmp" 2>/dev/null || true
    return 1
  }
  mv "$tmp" "$cache_file" 2>/dev/null || {
    rm -f "$tmp" 2>/dev/null || true
    return 1
  }
}
__wb_startup_cache_render() {
  [ "${WELCOME_BOARD_STARTUP_CACHE:-1}" = 1 ] || {
    __wb_render startup
    return
  }
  local cache_file cache_dir tmp
  cache_file="$(__wb_startup_cache_file)"
  cache_dir="$(dirname "$cache_file")"
  mkdir -p "$cache_dir" 2>/dev/null || {
    __wb_render startup
    return
  }
  tmp="${cache_file}.tmp.$$"
  WELCOME_BOARD_STARTUP_CACHE=0 __wb_render startup >"$tmp" 2>/dev/null || {
    rm -f "$tmp" 2>/dev/null || true
    __wb_render startup
    return
  }
  cat "$tmp"
  mv "$tmp" "$cache_file" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
}
__wb_startup_cache_refresh_async() {
  local cache_file lock_dir
  cache_file="$(__wb_startup_cache_file)"
  lock_dir="${cache_file}.lock"
  {
    (
      mkdir "$lock_dir" 2>/dev/null || exit 0
      trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
      __wb_startup_cache_update >/dev/null 2>&1 || true
    ) >/dev/null 2>&1 &
    disown "$!" 2>/dev/null || true
  } 2>/dev/null
}
__wb_startup_cache_print() {
  [ "${WELCOME_BOARD_STARTUP_CACHE:-1}" = 1 ] || return 1
  local cache_file ttl now mtime age
  cache_file="$(__wb_startup_cache_file)"
  [ -r "$cache_file" ] || return 1
  cat "$cache_file" || return 1
  ttl="$(__wb_startup_cache_ttl)"
  mtime="$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || printf '0')"
  [[ "$mtime" =~ ^[0-9]+$ ]] || mtime=0
  now="$(__wb_now)"
  age=$((now - mtime))
  if [ "$age" -ge "$ttl" ] 2>/dev/null; then
    __wb_startup_cache_refresh_async
  fi
  return 0
}

# ---- user commands ----------------------------------------------------------
welcomeBoard() {
  case "${1:-}" in
    startup) __wb_startup_cache_print || __wb_startup_cache_render;;
    *) __wb_render auto;;
  esac
  printf '\n'
}
welcomeBoardQuickSettings() {
  return 0
}
hkeys() { __wb_load_config; __wb_paint; WB_FRAME_ON=1; WB_W=$WB_FRAME_INNER; WB_ZW=$WB_FRAME_INNER
  __wb_frame_top; __wb_hermes_full; __wb_frame_bottom; WB_FRAME_ON=0; }
keys() { hkeys; }
welcomeHelp() {
  __wb_load_config; __wb_paint
  printf '\n  %s▌%s %sWELCOME BOARD — FULL REFERENCE%s\n' "$WB_AC" "$WB_R" "$WB_HDR$WB_B" "$WB_R"
  local -a sec=(
    "BOARD" 'wb|reprint the welcome board'
    'welcomeBoard|same board as a sourced helper' 'hkeys / keys|reprint the Hermes shortcuts'
    "UPDATE / INSTALL"
    'update-all|apt·brew·snap·node·npm·uv·pipx·gh + claude + codex'
    'npm i -g @openai/codex@latest|install / upgrade Codex CLI'
    'npm i -g @anthropic-ai/claude-code@latest|install / upgrade Claude Code CLI'
    "TMUX  (named sessions survive disconnect)"
    'tmux new -s work|start a session called work' 'tmux attach -t work|re-join after reconnect'
    'tmux ls|list sessions' 'Ctrl-b then d|detach (leave running in background)'
    'tmux kill-session -t work|delete the session'
    "HERMES PROFILES  (# = 1=master-1-codex, 2=master-2-local)"
    'm1 / m2|base — add ANY word, e.g. m1 status' 'm#c|chat' 'm#s|status'
    'm#g|gateway (add start/stop/restart/status)' 'm#d|dashboard' 'm#k|kanban'
    'm#up / m#down / m#re|gateway start / stop / restart'
    'm#doctor|check config + deps (try first)' 'm#setup|setup wizard'
    "SECURITY / PORTS"
    'wb ports explain|plain-English listener review' 'wb ports snapshot|save the drift baseline'
    'ssh-sessions|who is connected' 'ssh-reap|kill ghost sessions (keeps this + tmux)'
    "REMOTE" 'ssh mac|open the Mac' 'ssh xtreme|open the 4090 box'
  )
  local e c d
  for e in "${sec[@]}"; do
    if [[ "$e" != *"|"* ]]; then printf '\n  %s▌%s %s%s%s\n' "$WB_AC" "$WB_R" "$WB_HDR$WB_B" "$e" "$WB_R"
    else c="${e%%|*}"; d="${e##*|}"; printf '   %s%-34s%s%s%s%s\n' "$WB_CYN" "$c" "$WB_R" "$WB_D" "$d" "$WB_R"; fi
  done; echo
}

# ---- auto-render: interactive shells, or when executed directly -------------

# ===========================================================================
#  FUSED OVERRIDE LAYER (appended before the auto-render guard).
#  Later bash definitions WIN, so the original table-drawing engine
#  (__wb_zrow / __wb_plainrow / frame / clip / palette) is left untouched.
#  This layer only restores CONTENT: expanded 5-group machine + history
#  graphs, neon name, funnier welcome, 2-above-1-below section spacing.
# ===========================================================================

# --- palette fallbacks for helpers called before __wb_paint ------------------
WB_GOLD=$'\e[1m\e[38;5;220m'          # bold gold — group sub-headers
WB_NEON_ORANGE=$'\e[1m\e[38;5;208m'   # bold neon orange — the name, pops

# --- section header: first section gets two blank rows; later sections get one
__wb_hdr() {
  local lbl="$1" rule
  rule=$(( WB_FRAME_INNER - ${#lbl} - 3 )); ((rule < 4)) && rule=4
  __wb_plainrow ""
  if [ "${_WB_HDR_COUNT:-0}" -eq 0 ]; then __wb_plainrow ""; fi
  _WB_HDR_COUNT=$(( ${_WB_HDR_COUNT:-0} + 1 ))
  printf '  %s├%s─ %s%s%s %s%s┤%s\n' \
    "$WB_AC" "$WB_D" "$WB_YEL$WB_B" "$lbl" "$WB_R$WB_D" \
    "$(__wb_repeat '─' "$rule")" "$WB_AC" "$WB_R"
  __wb_plainrow ""
}

# --- funnier / smarter time-aware greeting (name inserted neon by caller) ---
__wb_greeting() {   # echoes: HELLO<TAB>TAGLINE
  local h; h=$((10#$(date +%H 2>/dev/null || echo 12))); local -a hi msg
  if   ((h>=5 && h<12)); then
    hi=("Good morning" "Rise and grind" "Morning" "Up and at it" "Dawn shift")
    msg=("the factory held all night." "all loops survived till sunrise." "fresh window, clean slate." "the night crew kept watch." "coffee's the only dependency unmet.")
  elif ((h>=12 && h<17)); then
    hi=("Afternoon" "Good afternoon" "Back at the helm" "Midday" "Console's warm")
    msg=("steady state, no fires." "everything important is on deck." "tools sharpened, lane open." "the grind continues." "let's bend some metal.")
  elif ((h>=17 && h<22)); then
    hi=("Evening" "Good evening" "Golden hour" "Wind-down" "Dusk shift")
    msg=("the day's still got moves left." "ship one thing before dark." "the box is yours." "quiet hum, green lights." "one more good push?")
  else
    hi=("Working late" "Burning the oil" "Night owl" "Witching hour" "Still here")
    msg=("sleep is a config flag - leave it set." "the machines don't blink; you should." "low light, high focus." "the LAN never sleeps; you can." "make it count, then rack out.")
  fi
  printf '%s\t%s' "${hi[RANDOM % ${#hi[@]}]}" "${msg[RANDOM % ${#msg[@]}]}"
}
__wb_greeting_row() {
  local name hi msg up
  name="$(__wb_safe_token "${WB_DISPLAY_NAME:-friend}" 40)"
  IFS=$'\t' read -r hi msg < <(__wb_greeting)
  up=$(uptime -p 2>/dev/null | sed 's/^up //;s/ hours\?/h/;s/ minutes\?/m/;s/ days\?/d/;s/ weeks\?/w/;s/,//g' || echo '?')
  __wb_plainrow ""
  __wb_plainrow "${WB_HDR}${hi}, ${WB_NEON_ORANGE}${name}${WB_FR}${WB_HDR}.${WB_R} ${WB_WHT}${msg}${WB_R}"
  __wb_plainrow "${WB_DM}up ${up} · $(date '+%a %d %b · %H:%M' 2>/dev/null)"
}

# --- machine helpers (history sparkline engine, ported intact) ---------------
__wb_pct() { local p="${1:-0}"; [[ "$p" =~ ^-?[0-9]+$ ]] || p=0; ((p<0))&&p=0; ((p>100))&&p=100; printf '%s' "$p"; }
__wb_clock_pct() { local c="${1:-0}" m="${2:-0}"; [[ "$c" =~ ^[0-9]+$ ]]||c=0; [[ "$m" =~ ^[0-9]+$ ]]||m=0; ((m>0)) && __wb_pct $((c*100/m)) || printf '0'; }
# temp → % of the 30→100°C thermal range, so the gauge means "thermal headroom used" (NOT raw °C as %)
__wb_temppct() { local t="${1:-0}"; [[ "$t" =~ ^[0-9]+$ ]] || t=0; local p=$(( (t-30)*100/70 )); ((p<0))&&p=0; ((p>100))&&p=100; printf '%s' "$p"; }
__wb_hist_path() { printf '%s' "${WELCOME_BOARD_MACHINE_HISTORY:-$HOME/.local/state/welcome-board/machine-series.tsv}"; }
__wb_now() { printf '%s' "${WB_NOW:-$(date +%s 2>/dev/null || echo 0)}"; }
__wb_hist_trim() {
  local p="$1" t
  [ -f "$p" ] || return 0
  [ "${_WB_HIST_TRIMMED:-}" = "$p" ] && return 0
  _WB_HIST_TRIMMED="$p"
  t="${p}.tmp.$$"
  tail -n 1024 "$p" >"$t" 2>/dev/null && mv "$t" "$p"
  rm -f "$t" 2>/dev/null || true
}
__wb_hist_add()  { local k="$1" v; v="$(__wb_pct "$2")"; local p d; p="$(__wb_hist_path)"; d=$(dirname "$p"); mkdir -p "$d" 2>/dev/null||return 0; printf '%s\t%s\t%s\n' "$(__wb_now)" "$k" "$v" >>"$p" 2>/dev/null||return 0; }
# history sparkline (width + glyphs come from WB_SPARK_N / WB_SPARK globals)
: "${WB_SPARK:=▁▂▃▄▅▆▇█}"; : "${WB_SPARK_N:=8}"
__wb_hist_graph() {
  local key="$1" value path vals count pad v idx out="" levels="${WB_SPARK}" n="${WB_SPARK_N}" fb=""
  value="$(__wb_pct "$2")"; path="$(__wb_hist_path)"
  if [ "${WB_STARTUP_FAST:-0}" = 1 ]; then
    idx=$((value*7/100))
    for ((v=0; v<n; v++)); do out+="$(__wb_grad "$value")${levels:idx:1}"; done
    printf '%s%s' "$out" "$WB_FR"
    return 0
  fi
  __wb_hist_add "$key" "$value"; __wb_hist_trim "$path"
  vals=$(awk -F '\t' -v k="$key" '$2==k {print $3}' "$path" 2>/dev/null | tail -n "$n")
  count=$(printf '%s\n' "$vals" | sed '/^$/d' | wc -l | awk '{print $1}')
  pad=$((n - count)); while ((pad>0)); do vals=$(printf '0\n%s' "$vals"); pad=$((pad-1)); done
  # colour each cell by its own value (green→red), so the trend is reactive like the gauge bar
  while read -r v; do [ -z "$v" ] && continue; v=$(__wb_pct "$v"); idx=$((v*7/100)); out+="$(__wb_grad "$v")${levels:idx:1}"; done <<< "$vals"
  for ((v=0;v<n;v++)); do fb+="$(__wb_grad 0)${levels:0:1}"; done
  printf '%s%s' "${out:-$fb}" "$WB_FR"
}
__wb_recent_label() {
  local now="${1:-0}" first="${2:-0}" span mins
  [[ "$now" =~ ^[0-9]+$ ]] || now=0
  [[ "$first" =~ ^[0-9]+$ ]] || first="$now"
  span=$((now - first))
  ((span < 60)) && span=60
  ((span > 7200)) && span=7200
  if ((span >= 7200)); then
    printf '2H'
  else
    mins=$(((span + 59) / 60))
    ((mins < 1)) && mins=1
    printf '%sM' "$mins"
  fi
}
__wb_recent_graph_values() {
  local vals="$1" width="${WB_RECENT_GRAPH_WIDTH:-24}" count pad v idx out="" levels="${WB_SPARK}"
  [[ "$width" =~ ^[0-9]+$ ]] || width=24
  ((width < 8)) && width=8
  ((width > 32)) && width=32
  vals="$(printf '%s\n' "$vals" | sed '/^$/d' | tail -n "$width")"
  count=$(printf '%s\n' "$vals" | sed '/^$/d' | wc -l | awk '{print $1}')
  pad=$((width - count))
  while ((pad > 0)); do vals=$(printf '0\n%s' "$vals"); pad=$((pad - 1)); done
  while read -r v; do
    [ -z "$v" ] && continue
    v="$(__wb_pct "$v")"
    idx=$((v * 7 / 100))
    out+="$(__wb_grad "$v")${levels:idx:1}"
  done <<< "$vals"
  printf '%s%s' "$out" "$WB_FR"
}
__wb_recent_history_series() {
  local key="$1" now cutoff path first vals graph label
  now="$(__wb_now)"
  cutoff=$((now - 7200))
  path="$(__wb_hist_path)"
  [ -r "$path" ] || return 1
  first="$(awk -F '\t' -v k="$key" -v c="$cutoff" -v n="$now" '$2==k && $1>=c && $1<=n {print $1; exit}' "$path" 2>/dev/null)"
  [ -n "$first" ] || return 1
  vals="$(awk -F '\t' -v k="$key" -v c="$cutoff" -v n="$now" '$2==k && $1>=c && $1<=n {print $3}' "$path" 2>/dev/null)"
  [ -n "$vals" ] || return 1
  label="$(__wb_recent_label "$now" "$first")"
  graph="$(__wb_recent_graph_values "$vals")"
  printf '%s %s' "$label" "$graph"
}
__wb_recent_sar_cpu_series() {
  [ "${WB_CPU_RECENT_SOURCE:-auto}" = history ] && return 1
  command -v sar >/dev/null 2>&1 || return 1
  command -v date >/dev/null 2>&1 || return 1
  local now start start_hms raw line ts cpu idle val first_time first_epoch vals graph label timeout
  now="$(__wb_now)"
  start=$((now - 7200))
  start_hms="$(date -d "@$start" +%H:%M:%S 2>/dev/null)" || return 1
  timeout="$(__wb_seconds "${WB_RECENT_SAR_TIMEOUT:-0.25}" 0.25)"
  raw="$(__wb_run_timeout "$timeout" sar -u -s "$start_hms" 2>/dev/null)" || return 1
  while read -r line; do
    set -- $line
    ts="${1:-}"; cpu="${2:-}"; for idle do :; done
    [ "$cpu" = all ] || continue
    [[ "$idle" =~ ^[0-9]+([.][0-9]+)?$ ]] || continue
    val="$(awk -v idle="$idle" 'BEGIN{p=100-(idle+0); if(p<0)p=0; if(p>100)p=100; printf "%d", p}')"
    [ -n "$first_time" ] || first_time="$ts"
    if [ -n "$vals" ]; then vals="${vals}"$'\n'"${val}"; else vals="$val"; fi
  done <<< "$raw"
  [ -n "$vals" ] || return 1
  first_epoch="$(date -d "$(date +%F) $first_time" +%s 2>/dev/null)" || return 1
  label="$(__wb_recent_label "$now" "$first_epoch")"
  graph="$(__wb_recent_graph_values "$vals")"
  printf '%s %s' "$label" "$graph"
}
__wb_recent_series() {
  local _mode="${1:-graph}" key="${2:-cpu}"
  if [ "$key" = cpu ] && __wb_recent_sar_cpu_series; then
    return 0
  fi
  __wb_recent_history_series "$key" || printf 'NOW %s' "$(__wb_recent_graph_values 0)"
}
# (__wb_mrow + __wb_msub are VARIANT-specific; defined below)

# --- network throughput (real /proc/net/dev delta; no mocks) -----------------
__wb_netrate() {   # echoes: iface rxKBs txKBs  (sum non-loopback over a tiny delta)
  local net_dev_file="${WB_NET_DEV_FILE:-/proc/net/dev}"
  [ -r "$net_dev_file" ] || { printf 'net 0 0'; return; }
  local r1 t1 r2 t2 nif delay
  delay="$(__wb_seconds "${WB_NETRATE_DELAY:-0.20}" 0.20)"
  read -r r1 t1 < <(awk 'NR>2{gsub(":"," "); if($1!="lo"){rx+=$2;tx+=$10}} END{print rx+0,tx+0}' "$net_dev_file" 2>/dev/null)
  [ "$delay" != 0 ] && sleep "$delay" 2>/dev/null
  read -r r2 t2 < <(awk 'NR>2{gsub(":"," "); if($1!="lo"){rx+=$2;tx+=$10}} END{print rx+0,tx+0}' "$net_dev_file" 2>/dev/null)
  nif=$(__wb_run_timeout 0.2 ip route 2>/dev/null | awk '/^default/{print $5; exit}'); : "${nif:=net}"
  awk -v a="${r1:-0}" -v b="${r2:-0}" -v c="${t1:-0}" -v d="${t2:-0}" -v i="$nif" \
    -v delay="$delay" 'BEGIN{dly=(delay+0>0)?delay:1; printf "%s %.0f %.0f", i, (b-a)/dly/1024, (d-c)/dly/1024}'
}

# --- load row routes through __wb_mrow so it matches each variant's style ----
__wb_center() {
  local width="$1" text="$2" len left right
  len=${#text}
  ((len >= width)) && { printf '%s' "$text"; return; }
  left=$(( (width - len) / 2 ))
  right=$(( width - len - left ))
  printf '%*s%s%*s' "$left" "" "$text" "$right" ""
}

__wb_loadrow() {
  local pct="$1" l1="$2" l5="$3" l15="$4" _up="${5:-}" graph="${6:-}"
  local f1 f5 f15 k1 k5 k15 prefix
  printf -v f1 '%5s' "$l1"
  printf -v f5 '%5s' "$l5"
  printf -v f15 '%5s' "$l15"
  k1="$(__wb_center 5 "1m")"
  k5="$(__wb_center 5 "5m")"
  k15="$(__wb_center 5 "15m")"
  printf -v prefix '%31s' ''

  __wb_mrow "LOAD" "$pct" "$graph" "${WB_WHT}${f1} ${WB_DM}· ${WB_WHT}${f5} ${WB_DM}· ${WB_WHT}${f15}"
  __wb_zrow "${prefix}${WB_DM}${k1}   ${k5}   ${k15}"
}

# --- MACHINE: five segregated groups, real probes, history graphs -----------
__wb_machine() {
  [ "$(__wb_os)" = macos ] && { __wb_machine_macos; return; }
  __wb_hdr "MACHINE"; __wb_zreset
  # CPU
  local cbrand cores ctemp cfcur cfmax cbusy
  cbrand=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | sed -E 's/.*: //; s/\(R\)//g; s/\(TM\)//g; s/Intel //; s/Core //; s/ CPU.*//; s/  */ /g; s/^ //'); : "${cbrand:=CPU}"
  cbrand="$(__wb_safe_token "$cbrand" 80)"
  cores=$(nproc 2>/dev/null || echo '?')
  [[ "$cores" =~ ^[0-9]+$ ]] || cores=1
  ctemp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1); [ -n "$ctemp" ] && ctemp=$((ctemp/1000))
  [[ "${ctemp:-}" =~ ^[0-9]+$ ]] || ctemp=""
  # live freq = fastest core right now (shows turbo under load; avg sits flat at base)
  cfcur=$(awk -F: '/cpu MHz/{v=$2+0; if(v>m)m=v} END{if(m)printf "%.2f",m/1000}' /proc/cpuinfo 2>/dev/null)
  [ -z "$cfcur" ] && cfcur=$(awk '$1>m{m=$1} END{if(m)printf "%.2f",m/1e6}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)
  cfmax=$(awk '{printf "%.2f",$1/1e6}' /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
  cbusy=$(__wb_cpubusy)
  cbusy="$(__wb_pct "$cbusy")"
  # RAM / SWAP
  local mu mtot rpct su stot spct ruGB rtGB suGB stGB
  read -r mu mtot < <(free -m 2>/dev/null | awk '/^Mem:/{u=($7 ~ /^[0-9]+$/)?$2-$7:$3; print u,$2}')
  [ -n "$mtot" ] && [ "$mtot" -gt 0 ] 2>/dev/null && rpct=$(( ${mu:-0}*100/mtot )) || rpct=0
  read -r su stot < <(free -m 2>/dev/null | awk '/^Swap:/{print $3,$2}')
  [ -n "$stot" ] && [ "$stot" -gt 0 ] 2>/dev/null && spct=$(( ${su:-0}*100/stot )) || spct=0
  rpct="$(__wb_pct "$rpct")"; spct="$(__wb_pct "$spct")"
  ruGB=$(awk -v u="${mu:-0}" 'BEGIN{printf "%.1f",u/1024}'); rtGB=$(awk -v t="${mtot:-0}" 'BEGIN{printf "%.0f",t/1024}')
  suGB=$(awk -v u="${su:-0}" 'BEGIN{printf "%.1f",u/1024}'); stGB=$(awk -v t="${stot:-0}" 'BEGIN{printf "%.0f",t/1024}')
  # GPU
  local gpu gname gp gutil gtemp vu vt cgr cgrmax cm cmmax gpw gpl vpct ppct gclk_pct mclk_pct v
  gpu=$(__wb_run_timeout 2 nvidia-smi --query-gpu=name,pstate,utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.gr,clocks.max.gr,clocks.mem,clocks.max.mem,power.draw,enforced.power.limit --format=csv,noheader,nounits 2>/dev/null | head -1)
  IFS=',' read -r gname gp gutil gtemp vu vt cgr cgrmax cm cmmax gpw gpl <<<"$gpu"
  gname=$(printf '%s' "$gname" | sed -E 's/^ *//; s/NVIDIA //; s/GeForce //'); : "${gname:=no GPU}"
  gname="$(__wb_safe_token "$gname" 80)"
  for v in gp gutil gtemp vu vt cgr cgrmax cm cmmax gpw gpl; do printf -v "$v" '%s' "${!v// /}"; done
  for v in gutil gtemp vu vt cgr cgrmax cm cmmax gpw gpl; do printf -v "$v" '%s' "${!v%.*}"; [[ "${!v}" =~ ^[0-9]+$ ]] || printf -v "$v" '0'; done
  [ -n "$vt" ] && [ "$vt" -gt 0 ] 2>/dev/null && vpct=$(( ${vu:-0}*100/vt )) || vpct=0
  [ -n "$gpl" ] && [ "$gpl" -gt 0 ] 2>/dev/null && ppct=$(( ${gpw:-0}*100/gpl )) || ppct=0
  vpct="$(__wb_pct "$vpct")"; ppct="$(__wb_pct "$ppct")"
  gclk_pct=$(__wb_clock_pct "$cgr" "$cgrmax"); mclk_pct=$(__wb_clock_pct "$cm" "$cmmax")
  # DISK
  local du dt dp
  read -r du dt dp < <(df -BG --output=used,size,pcent / 2>/dev/null | tail -1 | tr -d 'G%')
  dp="$(__wb_pct "$dp")"
  # LOAD
  local l1 l5 l15 lpct up
  read -r l1 l5 l15 _ < /proc/loadavg 2>/dev/null
  lpct=$(awk -v n="${cores:-1}" -v x="${l1:-0}" 'BEGIN{n=(n+0<1)?1:n;p=(x+0)/n*100;p=(p<0)?0:p;p=(p>100)?100:p;printf "%d",p}')
  up=$(uptime -p 2>/dev/null | sed 's/^up //;s/ hours\?/h/;s/ minutes\?/m/;s/ days\?/d/;s/ weeks\?/w/;s/,//g')

  # hardware names live in the group sub-headers; every metric row's VALUE starts in the
  # same column so the section reads as clean, even columns.
  __wb_msub "CPU" "${cbrand}"
  __wb_mrow  "USAGE" "${cbusy:-0}" "$(__wb_hist_graph cpu "${cbusy:-0}")" "${WB_WHT}${cfcur:-?}${WB_DM}/${cfmax:-?} GHz ${WB_DM}· ${WB_WHT}${cores}${WB_DM} threads"
  __wb_mrow  "TEMP"  "$(__wb_temppct "${ctemp:-0}")" "$(__wb_hist_graph ctemp "$(__wb_temppct "${ctemp:-0}")")" "${WB_FR}$(__wb_tcol "$ctemp")${ctemp:-?}${WB_DM} °C"
  __wb_loadrow "${lpct:-0}" "${l1:-?}" "${l5:-?}" "${l15:-?}" "${up:-?}" "$(__wb_hist_graph load "${lpct:-0}")"
  [ "${WB_STARTUP_FAST:-0}" = 1 ] || __wb_mrow  "RECENT" "${cbusy:-0}" "$(__wb_recent_series graph cpu)" "${WB_WHT}CPU${WB_DM} sampled history"
  __wb_plainrow ""
  __wb_msub "RAM"
  __wb_mrow  "USED"  "${rpct}" "$(__wb_hist_graph ram "${rpct:-0}")"  "$(__wb_grad "$rpct")${ruGB}${WB_DM}/${rtGB} GB"
  __wb_mrow  "SWAP"  "${spct}" "$(__wb_hist_graph swap "${spct:-0}")" "$(__wb_grad "$spct")${suGB}${WB_DM}/${stGB} GB"
  __wb_plainrow ""
  __wb_msub "GPU" "${gname}"
  __wb_mrow  "USAGE" "${gutil:-0}" "$(__wb_hist_graph gpu "${gutil:-0}")" "${WB_DM}perf state ${WB_WHT}${gp:-?}"
  [ "${WB_STARTUP_FAST:-0}" = 1 ] || __wb_mrow  "RECENT" "${gutil:-0}" "$(__wb_recent_series graph gpu)" "${WB_WHT}GPU${WB_DM} board samples"
  __wb_mrow  "POWER" "${ppct:-0}" "$(__wb_hist_graph gpow "${ppct:-0}")" "$(__wb_grad "${ppct:-0}")${gpw:-?}${WB_DM}/${gpl:-?} W"
  __wb_mrow  "TEMP"  "$(__wb_temppct "${gtemp:-0}")" "$(__wb_hist_graph gtemp "$(__wb_temppct "${gtemp:-0}")")" "${WB_FR}$(__wb_tcol "$gtemp")${gtemp:-?}${WB_DM} °C"
  __wb_mrow  "VRAM"  "${vpct}" "$(__wb_hist_graph vram "${vpct:-0}")"  "$(__wb_grad "$vpct")${vu:-?}${WB_DM}/${vt:-?} MB"
  __wb_mrow  "CORE"  "$gclk_pct" "$(__wb_hist_graph gclk "$gclk_pct")" "${WB_WHT}${cgr:-?}${WB_DM}/${cgrmax:-?} MHz"
  __wb_mrow  "MEMCLK" "$mclk_pct" "$(__wb_hist_graph mclk "$mclk_pct")" "${WB_WHT}${cm:-?}${WB_DM}/${cmmax:-?} MHz"
  __wb_plainrow ""
  __wb_msub "DISK"
  __wb_mrow  "ROOT"  "${dp:-0}" "$(__wb_hist_graph disk "${dp:-0}")"  "$(__wb_grad "${dp:-0}")${du:-?}${WB_DM}/${dt:-?} GB"
}

__wb_machine_macos() {
  __wb_hdr "MACHINE"; __wb_zreset
  local cbrand cores mtot_b ctot psize mu_pages mu rpct btot bused dt du dp l1 l5 l15 lpct up
  cbrand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | sed -E 's/ +\(.*\)$//; s/  */ /g'); : "${cbrand:=Apple Silicon}"
  cbrand="$(__wb_safe_token "$cbrand" 80)"
  cores=$(sysctl -n hw.logicalcpu 2>/dev/null || echo '?')
  mtot_b=$(sysctl -n hw.memsize 2>/dev/null); ctot=$(( ${mtot_b:-0}/1073741824 ))
  psize=$(vm_stat 2>/dev/null | awk -F'of ' '/page size/{gsub(/[^0-9]/,"",$2);print $2;exit}'); : "${psize:=4096}"
  mu_pages=$(vm_stat 2>/dev/null | awk '/Pages active/{a=$3}/Pages wired/{w=$4}/occupied by compressor/{c=$5} END{gsub(/\./,"",a);gsub(/\./,"",w);gsub(/\./,"",c);print (a+w+c)+0}')
  mu=$(( ${mu_pages:-0} * ${psize:-4096} / 1073741824 ))
  [ "${ctot:-0}" -gt 0 ] && rpct=$(( mu*100/ctot )) || rpct=0
  read -r btot bused < <(df / 2>/dev/null | awk 'NR==2{print $2,$3}')
  dt=$(( ${btot:-0}*512/1000000000 )); du=$(( ${bused:-0}*512/1000000000 ))
  [ "${btot:-0}" -gt 0 ] && dp=$(( bused*100/btot )) || dp=0
  read -r l1 l5 l15 < <(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | awk '{print $1,$2,$3}')
  lpct=$(awk -v n="${cores:-1}" -v x="${l1:-0}" 'BEGIN{n=(n+0<1)?1:n;p=(x+0)/n*100;p=(p>100)?100:p;printf "%d",p}')
  up=$(uptime 2>/dev/null | sed -E 's/.*up *//; s/,? *[0-9]+ users?.*//; s/,? *load aver.*//; s/  */ /g; s/^ //; s/, *$//')
  __wb_msub "CPU"
  __wb_mrow "USAGE" "${lpct:-0}" "$(__wb_hist_graph cpu "${lpct:-0}")" "${WB_DEV}${cbrand}  ${WB_DM}${cores}t · ${WB_WHT}macOS"
  __wb_loadrow "${lpct:-0}" "${l1:-?}" "${l5:-?}" "${l15:-?}" "${up:-?}" "$(__wb_hist_graph load "${lpct:-0}")"
  __wb_msub "RAM"
  __wb_mrow "USED" "${rpct}" "$(__wb_hist_graph ram "${rpct:-0}")" "$(__wb_grad "$rpct")${mu:-?}${WB_DM}/${ctot:-?} GB"
  __wb_msub "GPU"
  __wb_mrow "USAGE" "0" "$(__wb_hist_graph gpu 0)" "${WB_DEV}Apple/Metal${WB_DM} · stats not exposed"
  __wb_msub "DISK"
  __wb_mrow "ROOT" "${dp:-0}" "$(__wb_hist_graph disk "${dp:-0}")" "$(__wb_grad "${dp:-0}")${du:-?}${WB_DM}/${dt:-?} GB · /"
}

# ===========================================================================
#  POLISH OVERRIDES — holistic cleanup of the whole list.
#  Consolidate networking into ONE section, tighten HERMES, dedupe COMMANDS,
#  kill the redundant footer. (Table-drawing engine still untouched.)
# ===========================================================================

# --- NETWORK: throughput graph (real /proc/net/dev) + connectivity, one home -
__wb_tailscale_ip() {
  local status="$1" match="$2"
  [ -n "$match" ] || return 1
  awk -v m="$match" 'index($0, m) {print $1; exit}' <<< "$status"
}
__wb_tailscale_active() {
  local status="$1" match="$2"
  [ -n "$match" ] || return 1
  awk -v m="$match" 'index($0, m) && tolower($0) ~ /active/ {found=1} END{exit found?0:1}' <<< "$status"
}
__wb_peer_probe() {
  local probe="$1" probe_timeout phost pport
  [ "${WB_STARTUP_FAST:-0}" = 1 ] && return 1
  [ -n "$probe" ] || return 1
  [[ "$probe" == *:* ]] || return 1
  probe_timeout="$(__wb_seconds "${WB_PEER_PROBE_TIMEOUT:-0.2}" 0.2)"
  phost="${probe%:*}"; pport="${probe##*:}"
  [[ "$phost" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [[ "$pport" =~ ^[0-9]+$ ]] || return 1
  [ "$pport" -ge 1 ] 2>/dev/null && [ "$pport" -le 65535 ] 2>/dev/null || return 1
  __wb_run_timeout "$probe_timeout" bash -c 'exec 3<>"/dev/tcp/$1/$2"' bash "$phost" "$pport" 2>/dev/null
}
__wb_ssh_summary() {
  local raw active stale reaped count timeout line
  timeout="$(__wb_seconds "${WB_NETWORK_COMMAND_TIMEOUT:-0.45}" 0.45)"
  if command -v clamshell-ssh-sessions >/dev/null 2>&1; then
    raw=$(__wb_run_timeout "$timeout" clamshell-ssh-sessions summary --format env 2>/dev/null || true)
    active="$(printf '%s\n' "$raw" | awk -F= '$1=="SSH_ACTIVE" {print $2; exit}')"
    stale="$(printf '%s\n' "$raw" | awk -F= '$1=="SSH_STALE" {print $2; exit}')"
    reaped="$(printf '%s\n' "$raw" | awk -F= '$1=="SSH_AUTO_REAPED_TODAY" {print $2; exit}')"
    active="$(__wb_uint "$active")"
    stale="$(__wb_uint "$stale")"
    reaped="$(__wb_uint "$reaped")"
    printf '%s active · %s stale · %s auto-reaped today\t%s\t%s\t%s\n' "$active" "$stale" "$reaped" "$active" "$stale" "$reaped"
    return 0
  fi

  count=$(__wb_run_timeout "$timeout" who 2>/dev/null | grep -cE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)' || true)
  count="$(__wb_uint "$count")"
  line="${count} active · 0 stale · 0 auto-reaped today"
  printf '%s\t%s\t0\t0\n' "$line" "$count"
}
__wb_tmux_spot() {
  local session="$1" spot
  if command -v tmux-spots >/dev/null 2>&1; then
    spot=$(__wb_run_timeout 0.2 tmux-spots spot-of "$session" 2>/dev/null || true)
    [[ "$spot" =~ ^[0-9]+$ ]] && { printf '%s' "$spot"; return; }
  fi
  [[ "$session" =~ ^[0-9]+$ ]] && { printf '%s' "$session"; return; }
  printf '?'
}
__wb_tmux_title() {
  local pane="$1" fallback="$2" title
  if command -v tmux-title-broker >/dev/null 2>&1; then
    title=$(__wb_run_timeout 0.2 tmux-title-broker title-for-pane "$pane" "$fallback" 2>/dev/null || true)
  fi
  [ -n "${title:-}" ] || title="$fallback"
  __wb_safe_token "$title" 120
}
__wb_tmux_rows() {
  local timeout tmux_rows tmux_list count names row session attached created pane cmd title spot state shown_cmd shown_title line n
  timeout="$(__wb_seconds "${WB_NETWORK_COMMAND_TIMEOUT:-0.45}" 0.45)"
  if [ "${WB_STARTUP_FAST:-0}" = 1 ]; then
    tmux_list="$(__wb_run_timeout "$timeout" tmux ls 2>/dev/null || true)"
    count=$(printf '%s\n' "$tmux_list" | sed '/^$/d' | wc -l | tr -d ' ')
    count="$(__wb_uint "$count")"
    if [ "$count" -gt 0 ] 2>/dev/null; then
      names=$(printf '%s\n' "$tmux_list" | sed 's/:.*//' | paste -sd, - | sed 's/,/, /g')
      names="$(__wb_safe_token "$names" 180)"
      __wb_zrow "${WB_LBL}$(printf '%-6s' 'tmux')${WB_FR} ${WB_WHT}${count}${WB_FR} ${WB_DM}session(s): ${names}"
    else
      __wb_zrow "${WB_LBL}$(printf '%-6s' 'tmux')${WB_FR} ${WB_DM}no sessions · start: ${WB_CYN}tmux new -s work"
    fi
    return 0
  fi
  tmux_rows="$(__wb_run_timeout "$timeout" tmux list-sessions -F '#{session_name}	#{session_attached}	#{session_created}	#{pane_id}	#{pane_current_command}	#{pane_title}' 2>/dev/null || true)"
  count=$(printf '%s\n' "$tmux_rows" | sed '/^$/d' | wc -l | tr -d ' ')
  count="$(__wb_uint "$count")"

  if [ "$count" -gt 0 ] 2>/dev/null; then
    __wb_zrow "${WB_LBL}$(printf '%-6s' 'tmux')${WB_FR} ${WB_WHT}${count}${WB_FR} ${WB_DM}session(s) · join ${WB_CYN}tmux 2${WB_FR}${WB_DM} · nuke ${WB_CYN}tmux nuke"
    n=0
    while IFS=$'\t' read -r session attached created pane cmd title || [ -n "$session" ]; do
      [ -n "$session" ] || continue
      n=$((n + 1))
      [ "$n" -le 4 ] || continue
      spot="$(__wb_tmux_spot "$session")"
      if [ "$(__wb_uint "$attached")" -gt 0 ] 2>/dev/null; then state="${WB_GRN}●"; else state="${WB_DM}○"; fi
      case "$cmd" in node) shown_cmd=codex;; claude) shown_cmd=claude;; bash|zsh|sh|fish|dash|"") shown_cmd=shell;; *) shown_cmd="$cmd";; esac
      shown_cmd="$(__wb_safe_token "$shown_cmd" 12)"
      shown_title="$(__wb_tmux_title "$pane" "$title")"
      line="${WB_YEL}${WB_B}[$spot]${WB_FR} ${state}${WB_FR} ${WB_CYN}$(printf '%-6s' "$shown_cmd")${WB_FR} ${WB_WHT}${shown_title}"
      __wb_zrow "$line"
    done <<< "$tmux_rows"
    [ "$count" -gt 4 ] 2>/dev/null && __wb_zrow "${WB_DM}… $((count - 4)) more · full list: ${WB_CYN}tmux-spots ls"
    return 0
  fi

  tmux_list="$(__wb_run_timeout "$timeout" tmux ls 2>/dev/null || true)"
  count=$(printf '%s\n' "$tmux_list" | sed '/^$/d' | wc -l | tr -d ' ')
  count="$(__wb_uint "$count")"
  if [ "$count" -gt 0 ] 2>/dev/null; then
    names=$(printf '%s\n' "$tmux_list" | sed 's/:.*//' | paste -sd, - | sed 's/,/, /g')
    names="$(__wb_safe_token "$names" 180)"
    __wb_zrow "${WB_LBL}$(printf '%-6s' 'tmux')${WB_FR} ${WB_WHT}${count}${WB_FR} ${WB_DM}session(s): ${names}"
  else
    __wb_zrow "${WB_LBL}$(printf '%-6s' 'tmux')${WB_FR} ${WB_DM}no sessions · start: ${WB_CYN}tmux new -s work"
  fi
}
__wb_network() {
  __wb_hdr "NETWORK"; __wb_zreset
  local nif nrx ntx npct
  read -r nif nrx ntx < <(__wb_netrate)
  nif="$(__wb_safe_token "${nif:-—}" 40)"
  npct=$(awk -v r="${nrx:-0}" -v t="${ntx:-0}" 'BEGIN{m=(r>t)?r:t;p=m/12500*100;p=(p>100)?100:p;printf "%d",p}')
  __wb_mrow "RATE" "${npct}" "$(__wb_hist_graph net "${npct}")" "${WB_DEV}${nif:-—}  ${WB_DM}down ${WB_WHT}${nrx:-0}${WB_DM} · up ${WB_WHT}${ntx:-0}${WB_DM} KB/s"
  local ts="" self peer nm match probe ip st
  if [ -n "${WB_PEERS:-}" ] && command -v tailscale >/dev/null 2>&1; then
    ts=$(__wb_run_timeout "$(__wb_seconds "${WB_TAILSCALE_TIMEOUT:-0.45}" 0.45)" tailscale status 2>/dev/null || true)
  fi
  self="$(__wb_safe_token "$(hostname 2>/dev/null | cut -d. -f1)" 32)"
  if [ -n "$self" ]; then
    ip="$(__wb_tailscale_ip "$ts" "$self")"; : "${ip:=$(__wb_run_timeout 0.2 hostname -I 2>/dev/null | awk '{print $1}')}"
    ip="$(__wb_safe_token "${ip:-?}" 64)"
    __wb_zrow "${WB_LBL}$(printf '%-6s' "${self:0:6}")${WB_FR} ${WB_WHT}$(printf '%-16s' "$ip")${WB_DM}· this machine"
  fi
  local IFS_SAVE="$IFS"
  for peer in ${WB_PEERS:-}; do
    IFS='|' read -r nm match probe <<<"$peer"; IFS="$IFS_SAVE"
    ip="$(__wb_tailscale_ip "$ts" "$match")"
    if __wb_peer_probe "$probe"; then
      st="${WB_GRN}● serving ${WB_DM}:${probe##*:}"
    elif __wb_tailscale_active "$ts" "$match"; then st="${WB_GRN}● online"
    else st="${WB_DM}○ offline"; fi
    local shown_nm shown_ip
    shown_nm="$(__wb_safe_token "$nm" 32)"
    shown_ip="$(__wb_safe_token "${ip:-—}" 64)"
    __wb_zrow "${WB_LBL}$(printf '%-6s' "${shown_nm:0:6}")${WB_FR} ${WB_WHT}$(printf '%-16s' "$shown_ip")${WB_FR}${st}"
  done
  IFS="$IFS_SAVE"
  local nssh sc ssh_active ssh_stale ssh_reaped
  IFS=$'\t' read -r nssh ssh_active ssh_stale ssh_reaped < <(__wb_ssh_summary)
  nssh="$(__wb_safe_token "${nssh:-0 active · 0 stale · 0 auto-reaped today}" 120)"
  ssh_active="$(__wb_uint "$ssh_active")"
  ssh_stale="$(__wb_uint "$ssh_stale")"
  sc=$WB_WHT
  [ "$ssh_stale" -gt 0 ] 2>/dev/null && sc=$WB_RED
  [ "$ssh_stale" -eq 0 ] 2>/dev/null && [ "$ssh_active" -ge 4 ] 2>/dev/null && sc=$WB_YEL
  __wb_zrow "${WB_LBL}$(printf '%-6s' 'ssh')${WB_FR} ${sc}${nssh}${WB_FR} ${WB_DM}· reap ${WB_CYN}ssh-reap"
  __wb_tmux_rows
}

# --- HERMES: consolidated to 4 tight rows (full sheet still behind `hkeys`) --
__wb_hermes() {
  __wb_hdr "HERMES"; __wb_zreset
  __wb_zrow "${WB_DM}two brothers — ${WB_B}${WB_YEL}1${WB_FR}${WB_DM}=codex, ${WB_B}${WB_YEL}2${WB_FR}${WB_DM}=local. ${WB_DM}type ${WB_CYN}m1c${WB_FR}${WB_DM}/${WB_CYN}m2s${WB_FR}${WB_DM} (the ${WB_B}${WB_YEL}#${WB_FR}${WB_DM} is the brother)"
  __wb_zrow "${WB_CYN}m#c${WB_FR} ${WB_WHT}chat${WB_DM}   ${WB_CYN}m#s${WB_FR} ${WB_WHT}status${WB_DM}   ${WB_CYN}m#g${WB_FR} ${WB_WHT}gateway${WB_DM}   ${WB_CYN}m#d${WB_FR} ${WB_WHT}dashboard${WB_DM}   ${WB_CYN}m#k${WB_FR} ${WB_WHT}kanban"
  __wb_zrow "${WB_CYN}m#up${WB_FR}${WB_DM}/${WB_CYN}down${WB_FR}${WB_DM}/${WB_CYN}re${WB_FR} ${WB_WHT}gateway on·off·restart${WB_DM}   ${WB_CYN}m#doctor${WB_FR} ${WB_WHT}diagnose${WB_DM}   ${WB_CYN}m#setup${WB_FR} ${WB_WHT}wizard"
  __wb_zrow "${WB_DM}full cheat-sheet any time: ${WB_CYN}hkeys"
}

# --- COMMANDS: universal defaults + the user's own shortcuts from a config file
#  Personal shortcuts (ssh hosts, secrets, lid, etc.) live in
#  ${WB_CUSTOM_COMMANDS_FILE:-~/.config/welcome-board/commands} as 'label|command|hint'
#  rows — so the SHIPPED default stays generic and nobody's machine names leak.
__wb_cmdrow() {
  local label
  label="$(__wb_safe_token "$1" 32)"
  __wb_zrow "${WB_PNK}${WB_B}$(printf '%-9s' "$label")${WB_FR} ${2}"
}
__wb_commands() {
  __wb_hdr "COMMANDS"; __wb_zreset
  __wb_cmdrow "update"  "${WB_CYN}update-all${WB_FR} ${WB_D}system + AI CLIs${WB_FR}   ${WB_CYN}restart${WB_FR} ${WB_D}reload shell"
  __wb_cmdrow "board"   "${WB_CYN}wb${WB_FR} ${WB_D}reprint${WB_FR}   ${WB_CYN}welcomeHelp${WB_FR} ${WB_D}all commands"
  __wb_cmdrow "tmux"    "${WB_CYN}tmux${WB_FR} ${WB_D}list${WB_FR}  ${WB_CYN}tmux 2${WB_FR} ${WB_D}join${WB_FR}  ${WB_CYN}tmux new -s work${WB_FR}  ${WB_CYN}kill 1 2${WB_FR}  ${WB_D}detach ${WB_CYN}C-b d"
  __wb_cmdrow "network" "${WB_CYN}ssh-sessions${WB_FR} ${WB_D}who's on${WB_FR}  ${WB_CYN}ssh-reap${WB_FR} ${WB_D}kill ghosts${WB_FR}  ${WB_CYN}wb ports explain"
  local ccf="${WB_CUSTOM_COMMANDS_FILE:-$HOME/.config/welcome-board/commands}" cl cc ch n=0
  if [ -r "$ccf" ] && [ "$(wc -c < "$ccf" 2>/dev/null || echo 0)" -le 16384 ]; then
    while IFS='|' read -r cl cc ch || [ -n "$cl" ]; do
      n=$((n+1)); [ "$n" -le 20 ] || break
      [ -z "$cl" ] && continue; case "$cl" in \#*) continue;; esac
      cl="$(__wb_safe_token "$cl" 32)"
      cc="$(__wb_safe_token "$cc" 100)"
      ch="$(__wb_safe_token "$ch" 100)"
      __wb_cmdrow "${cl:0:9}" "${WB_CYN}${cc}${WB_FR}${ch:+   ${WB_D}${ch}}"
    done < "$ccf"
  fi
}

# --- FOOTER: updater notice below the board ---------------------------------
__wb_footer() {
  local notifier="" notice=""
  if [ -n "${WELCOME_BOARD_UPDATE_NOTIFIER:-}" ] && [ -x "$WELCOME_BOARD_UPDATE_NOTIFIER" ]; then
    notifier="$WELCOME_BOARD_UPDATE_NOTIFIER"
  elif [ -x "$HOME/.local/share/welcome-board/codex-claude-daily-update" ]; then
    notifier="$HOME/.local/share/welcome-board/codex-claude-daily-update"
  elif command -v codex-claude-daily-update >/dev/null 2>&1; then
    notifier="$(command -v codex-claude-daily-update)"
  fi

  if [ -n "$notifier" ]; then
    notice="$("$notifier" --notify-shell 2>/dev/null || true)"
  fi
  if [ -n "$notice" ]; then
    printf '%s\n' "$notice"
    return 0
  fi

  return 0
}

# --- VARIANT A: classic gauge + 8-cell history spark, inline gold sub-headers
WB_SPARK="▁▂▃▄▅▆▇█"; WB_SPARK_N=8
__wb_mrow() {
  local g="${3:-▁▁▁▁▁▁▁▁}"
  __wb_zrow "${WB_LBL}$(printf '%-6s' "$1")${WB_FR} $(__wb_bar "$2") ${WB_B}${WB_WHT}$(printf '%3s' "${2:-0}")%${WB_FR} ${g}${WB_FR}  $4"
}
__wb_msub() { local s=""; [ -n "${2:-}" ] && s="  ${WB_DM}${2}${WB_FR}"; __wb_plainrow "${WB_GOLD}$(printf '%-6s' "$1")${WB_FR}${s}"; }

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  __wb_render auto
fi
