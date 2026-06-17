#!/usr/bin/env bash
# ============================================================================
#  CLAMSHELL WELCOME BOARD  (v3 — compact, table-based, glanceable)
#  Prints on interactive shell start / SSH login. Sourced from ~/.bashrc.
#  FAST + failure-tolerant: local checks only, every field 2>/dev/null + fallback.
#  Optional network rows use local command output only and fail closed.
#  Self-contained; also runs via `clamboard`. Defines clamboard / clamhelp.
#
#  Design rules: dark mode, compact terminals, glance-first:
#   - few rows, aligned columns, crisp box rules (NO fuzzy figlet headers)
#   - color legend:  cyan = copyable command · green ok · yellow check
#                    red problem · pink tip · grey label.  NO dark blue.
#   - show real status, not narration.
# ============================================================================

__wb_config_value() {
  local raw="$1"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  if [[ "$raw" == \"*\" && "$raw" == *\" ]]; then
    raw="${raw#\"}"
    raw="${raw%\"}"
    raw="${raw//\\\"/\"}"
    raw="${raw//\\\\/\\}"
  fi
  printf '%s' "$raw"
}

__wb_load_config() {
  [ "${_WB_CONFIG_LOADED:-0}" = 1 ] && return 0
  _WB_CONFIG_LOADED=1
  local cfg="${WELCOME_BOARD_CONFIG:-$HOME/.config/welcome-board/config}" key raw value
  if [ -r "$cfg" ]; then
    while IFS='=' read -r key raw || [ -n "$key" ]; do
      case "$key" in
        WB_DISPLAY_NAME|WB_BANNER_TEXT|WB_THEME|WB_SECTIONS|WB_EXPECTED_PORTS|WB_SERVICE_PORTS|WELCOME_BOARD_MACHINE_HISTORY)
          value="$(__wb_config_value "$raw")"
          printf -v "$key" '%s' "$value"
          ;;
      esac
    done < "$cfg"
  fi
  : "${WB_DISPLAY_NAME:=${USER:-friend}}"
  : "${WB_BANNER_TEXT:=CLAMSHELL}"
  : "${WB_THEME:=cyan-dark}"
  : "${WB_SECTIONS:=machine tmux commands}"
}

__wb_upper() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

__wb_paint() {
  WB_R=$'\e[0m'; WB_B=$'\e[1m'; WB_D=$'\e[38;5;245m'   # soft grey, not SGR-2
  WB_GRN=$'\e[38;5;78m'; WB_RED=$'\e[38;5;203m'; WB_YEL=$'\e[38;5;221m'
  WB_CYN=$'\e[38;5;81m'; WB_PNK=$'\e[38;5;211m'; WB_GRY=$'\e[38;5;250m'
  WB_WHT=$'\e[38;5;253m'; WB_HDR=$'\e[38;5;117m'; WB_AC=$'\e[38;5;81m'
  WB_LBL=$'\e[1m\e[38;5;111m'   # bold cornflower — name column (CPU/GPU/…), pops, not yellow
  WB_DEV=$'\e[38;5;180m'        # warm tan — device-name column (i7-6700HQ / GTX 1060)
  WB_GOLD=$'\e[1m\e[38;5;220m'  # bold gold — major section dividers
  WB_NEON_ORANGE=$'\e[1m\e[38;5;208m'  # bold neon orange — display name
  WB_FR=$'\e[22;24;39m'         # fg-only reset: clears bold/underline/colour but KEEPS the row's zebra bg
  WB_DM=$'\006'                 # sentinel for "adaptive dim grey" — __wb_zrow swaps it per stripe so it stays readable on both shades
  case "${WB_THEME:-cyan-dark}" in
    amber-terminal)
      WB_CYN=$'\e[38;5;214m'; WB_HDR=$'\e[38;5;215m'; WB_AC=$'\e[38;5;208m'
      WB_LBL=$'\e[1m\e[38;5;220m'; WB_DEV=$'\e[38;5;180m'
      WB_NEON_ORANGE=$'\e[1m\e[38;5;202m'
      ;;
    green-phosphor)
      WB_CYN=$'\e[38;5;120m'; WB_HDR=$'\e[38;5;121m'; WB_AC=$'\e[38;5;42m'
      WB_LBL=$'\e[1m\e[38;5;119m'; WB_DEV=$'\e[38;5;151m'
      WB_GOLD=$'\e[1m\e[38;5;154m'; WB_NEON_ORANGE=$'\e[1m\e[38;5;118m'
      ;;
    mono-safe)
      WB_GRN=$'\e[38;5;252m'; WB_RED=$'\e[38;5;252m'; WB_YEL=$'\e[38;5;252m'
      WB_CYN=$'\e[38;5;252m'; WB_PNK=$'\e[38;5;252m'; WB_HDR=$'\e[38;5;252m'
      WB_AC=$'\e[38;5;250m'; WB_LBL=$'\e[1m\e[38;5;252m'; WB_DEV=$'\e[38;5;250m'
      WB_GOLD=$'\e[1m\e[38;5;252m'; WB_NEON_ORANGE=$'\e[1m\e[38;5;252m'
      ;;
  esac
}

# crisp single-line section header:  ▌ LABEL ───────────────
__wb_repeat() {
  local ch="$1" n="$2" out
  ((n < 0)) && n=0
  printf -v out '%*s' "$n" ''
  printf '%s' "${out// /$ch}"
}
__wb_frame_top() {
  printf '  %s┌%s┐%s\n' "$WB_AC" "$(__wb_repeat '─' "$WB_FRAME_INNER")" "$WB_R"
}
__wb_frame_bottom() {
  printf '  %s└%s┘%s\n' "$WB_AC" "$(__wb_repeat '─' "$WB_FRAME_INNER")" "$WB_R"
}
__wb_hdr() {
  local lbl="$1" rule
  if [ "${WB_FRAME_ON:-0}" = 1 ]; then
    rule=$(( WB_FRAME_INNER - ${#lbl} - 4 )); ((rule < 4)) && rule=4
    __wb_plainrow ""
    __wb_plainrow ""
    printf '  %s╞══ %s%s%s %s╡%s\n' \
      "$WB_AC" "$WB_GOLD" "$lbl" "$WB_FR$WB_AC" "$(__wb_repeat '═' "$rule")" "$WB_R"
    __wb_plainrow ""
    return
  fi
  rule=$(( WB_W - ${#lbl} - 6 )); [ "$rule" -lt 4 ] && rule=4
  printf '\n  %s▌%s %s%-s%s %s' "$WB_AC" "$WB_R" "$WB_HDR$WB_B" "$lbl" "$WB_R" "$WB_HDR$WB_D"
  printf '%s' "$(__wb_repeat '─' "$rule")"; printf '%s\n' "$WB_R"
}
__wb_row() { printf '   %b\n' "$1"; }       # indented body row
__wb_lbl() { printf '%s%-11s%s' "$WB_GRY" "$1" "$WB_R"; }   # fixed grey label col

# ---- time-aware rotating greeting (first name only, never surname) ----------
__wb_pick() {
  local name="$1" count idx
  eval "count=\${#$name[@]}"
  [ "${count:-0}" -gt 0 ] 2>/dev/null || return 0
  idx=$((RANDOM % count))
  eval "printf '%s' \"\${$name[$idx]}\""
}
__wb_greeting_parts() {
  local h; h=$((10#$(date +%H)))
  local -a hello msg
  if [ "$h" -ge 5 ] && [ "$h" -lt 12 ]; then
    hello=(
      "Good morning" "Morning" "Rise and shine" "Welcome back" "Hello"
      "Fresh boot energy" "New day online" "Command deck awake"
      "Systems are up" "Ready for the morning run" "Bright morning"
      "Early console, clear signal"
    )
    msg=(
      "the board is awake." "coffee-mode systems are green."
      "fresh signal, clean start." "today is ready to be shaped."
      "your command deck is warm." "quiet systems, sharp tools."
      "we have a clean runway." "small steps, heavy hits."
      "focus lane is open." "the shell kept watch."
      "let's make the morning count." "steady hands, clear screen."
    )
  elif [ "$h" -ge 12 ] && [ "$h" -lt 17 ]; then
    hello=(
      "Good afternoon" "Afternoon" "Welcome back" "Hello" "Hi"
      "Midday check-in" "Console ready" "CLAMSHELL reporting"
      "Back at the board" "Systems waiting" "Command deck ready"
      "Afternoon signal locked"
    )
    msg=(
      "the machine is steady." "your tools are lined up."
      "we are in the work lane." "clean signal, no drama."
      "everything important is on deck." "the board has your back."
      "focus mode is available." "ready for the next move."
      "the shell is warm and listening." "small command, big leverage."
      "the afternoon is still yours." "we can make this one count."
    )
  elif [ "$h" -ge 17 ] && [ "$h" -lt 22 ]; then
    hello=(
      "Good evening" "Evening" "Welcome back" "Hello" "Night desk warming"
      "Late-day systems ready" "Evening console online" "CLAMSHELL standing by"
      "Back for the evening run" "Signal still clean" "Command deck lit"
      "Evening watch is live"
    )
    msg=(
      "steady lights, sharp tools." "the day still has room."
      "we can land this clean." "quiet power, clear path."
      "your board is still awake." "the evening lane is open."
      "no rush, just good moves." "systems are calm and ready."
      "let's close the loop." "the shell is holding steady."
      "one clean pass at a time." "bring the next idea in."
    )
  else
    hello=(
      "Working late" "Late night" "Night shift" "Still here" "Hello"
      "Moonlight console" "After-hours deck" "Quiet-hours signal"
      "CLAMSHELL night watch" "Late console online" "Midnight systems ready"
      "Night lane open"
    )
    msg=(
      "low noise, high focus." "the quiet hours are yours."
      "steady screen, steady mind." "we keep it gentle and sharp."
      "night mode is holding." "the shell is still with you."
      "one careful move at a time." "dim lights, clear signal."
      "we can keep this simple." "the machine is calm."
      "no rush in the dark." "soft focus, strong hands."
    )
  fi
  printf '%s\t%s' "$(__wb_pick hello)" "$(__wb_pick msg)"
}

# ---- BANNER (brand mark so SSH login ≠ macOS login) ------------------------
__wb_banner_custom() {
  local title="$(__wb_upper "${WB_BANNER_TEXT:-WORKSTATION}")" width=76 inner rule pad
  title=$(printf '%s' "$title" | tr -cd '[:alnum:] _.-' | cut -c1-40)
  : "${title:=WORKSTATION}"
  if command -v figlet >/dev/null 2>&1; then
    figlet -w 96 "$title" 2>/dev/null | while IFS= read -r line; do
      printf '  %s%s%s\n' "$WB_HDR" "$line" "$WB_R"
    done
    printf '  %s%s%s\n' "$WB_HDR" "$title" "$WB_R"
    return
  fi
  inner="  ${title}  "
  rule="$(__wb_repeat '═' "${#inner}")"
  pad=$(( (width - ${#inner} - 2) / 2 ))
  ((pad < 0)) && pad=0
  printf '%*s%s╔%s╗%s\n' "$pad" '' "$WB_AC" "$rule" "$WB_R"
  printf '%*s%s║%s%s%s║%s\n' "$pad" '' "$WB_AC" "$WB_HDR$WB_B" "$inner" "$WB_AC" "$WB_R"
  printf '%*s%s╚%s╝%s\n' "$pad" '' "$WB_AC" "$rule" "$WB_R"
}

__wb_banner() {
  if [ "$(__wb_upper "${WB_BANNER_TEXT:-CLAMSHELL}")" != "CLAMSHELL" ]; then
    __wb_banner_custom
    return
  fi
  local binary='01100011 01101100 01100001 01101101 01110011 01101000 01100101 01101100 01101100'
  local -a art=(
'  ██████╗██╗      █████╗ ███╗   ███╗███████╗██╗  ██╗███████╗██╗     ██╗     '
' ██╔════╝██║     ██╔══██╗████╗ ████║██╔════╝██║  ██║██╔════╝██║     ██║     '
' ██║     ██║     ███████║██╔████╔██║███████╗███████║█████╗  ██║     ██║     '
' ██║     ██║     ██╔══██║██║╚██╔╝██║╚════██║██╔══██║██╔══╝  ██║     ██║     '
' ╚██████╗███████╗██║  ██║██║ ╚═╝ ██║███████║██║  ██║███████╗███████╗███████╗'
'  ╚═════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝'
  )
  local -a g=($'\e[38;5;45m' $'\e[38;5;81m' $'\e[38;5;75m' $'\e[38;5;39m' $'\e[38;5;33m' $'\e[38;5;69m')
  local i line max_art=0 pad art_pad=""
  for line in "${art[@]}"; do
    ((${#line} > max_art)) && max_art=${#line}
  done
  pad=$(( (2 + ${#binary} - max_art) / 2 ))
  ((pad > 0)) && printf -v art_pad '%*s' "$pad" ''
  for i in "${!art[@]}"; do printf '%s%s%s%s\n' "${g[i]}" "$art_pad" "${art[i]}" "$WB_R"; done
  # binary subtitle: the word "clamshell" as real ASCII bytes (c l a m s h e l l).
  # figlet's 'binary' font isn't installed; this is the same idea, zero-deps,
  # tinted to the art's last gradient stop so it reads as a quiet subtitle.
  printf '  %s%s%s\n' "$WB_HDR" "$binary" "$WB_R"
}
__wb_greeting_row() {
  local parts hello msg up now name
  IFS=$'\t' read -r hello msg < <(__wb_greeting_parts)
  up=$(uptime -p 2>/dev/null | sed 's/^up //;s/ hours\?/h/;s/ minutes\?/m/;s/ days\?/d/;s/,//g' || echo '?')
  now=$(date '+%a %d %b · %H:%M')
  name="$(__wb_upper "${WB_DISPLAY_NAME:-${USER:-friend}}")"
  __wb_plainrow ""
  __wb_plainrow "${WB_HDR}${hello}, ${WB_NEON_ORANGE}${name}${WB_FR}${WB_HDR}.${WB_R} ${WB_WHT}${msg}${WB_R}"
  __wb_plainrow "${WB_DM}up ${up} · ${now}"
}

# ---- GENERIC SHADED TABLE (reusable across sections) -----------------------
#  A section = a coloured title (via __wb_hdr) + zebra-striped rows.
#  Row colours by column:  name=WB_LBL · device=WB_DEV · value=WB_WHT ·
#  unit/sep=WB_D · gauge/temp=green/yellow/red (status).  Rows alternate two
#  shades of the SAME dark tone (A,B,A,B) so the eye tracks one row straight
#  across every column.  IMPORTANT: build row content with WB_FR (not WB_R) to
#  reset colour WITHOUT wiping the row's background shade; __wb_zrow lays the
#  shade down, pads the row full-width, then does the real reset at line end.
_WB_ZEB=0
__wb_zreset() { _WB_ZEB=0; }                         # call once at the top of a section
__wb_vis() {
  local s
  s=$(printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*m//g' | tr -d "$WB_DM")
  LC_ALL=C.UTF-8 printf '%s' "$s" | wc -m | awk '{print $1}'
}
__wb_plainrow() {
  local c="$1" zw=${WB_ZW:-72} vis pad
  c=${c//$WB_DM/$WB_D}
  vis=$(__wb_vis "$c")
  if [ "${WB_FRAME_ON:-0}" = 1 ]; then
    pad=$(( zw - 1 - vis )); ((pad<0)) && pad=0
    printf '  %s│%s %b%*s%s│%s\n' "$WB_AC" "$WB_R" "$c" "$pad" '' "$WB_AC" "$WB_R"
  else
    printf '   %b\n' "$c"
  fi
}
__wb_zrow() {                                         # $1 = pre-built, WB_FR-reset content
  local c="$1" bg dim zw=${WB_ZW:-72} vis pad
  # A = lighter band (bg 236) -> dim grey goes DARKER (240) so it reads
  # B = darker  band (bg 233) -> dim grey goes BRIGHTER (249) so it reads
  # dim = teal-grey (blue+green tint) so secondary text stays visible on BOTH bands.
  # lighter band gets a mid teal, darker band a brighter teal — readable either way.
  if ((_WB_ZEB%2==0)); then bg=$'\e[48;5;236m'; dim=$'\e[38;5;109m'
  else                       bg=$'\e[48;5;233m'; dim=$'\e[38;5;116m'; fi
  _WB_ZEB=$(( _WB_ZEB+1 ))
  c=${c//$WB_DM/$dim}                                 # swap the adaptive-dim sentinel for this stripe's grey
  c=${c//$WB_R/$WB_FR}
  vis=$(__wb_vis "$c")
  if [ "${WB_FRAME_ON:-0}" = 1 ]; then
    pad=$(( zw - 1 - vis )); ((pad<0)) && pad=0
    printf '  %s│%s %b%*s%s│%s\n' "$WB_AC" "$bg" "$c" "$pad" '' "$WB_AC" "$WB_R"
  else
    pad=$(( zw-vis )); ((pad<0)) && pad=0
    printf '   %s %s%*s%s\n' "$bg" "$c" "$pad" '' "$WB_R"
  fi
}

# ---- MACHINE helpers -------------------------------------------------------
# fullness ramp:  $1 pct -> 256-colour fg, smooth green(low) -> dark orange/red(full)
__wb_grad() {
  local p="$1" col
  [[ "$p" =~ ^[0-9]+$ ]] || p=0
  if   ((p<17)); then col=78    # green
  elif ((p<34)); then col=113   # soft green
  elif ((p<50)); then col=149   # green-yellow
  elif ((p<64)); then col=185   # yellow
  elif ((p<76)); then col=214   # amber
  elif ((p<86)); then col=208   # orange
  elif ((p<94)); then col=202   # red-orange
  else            col=160; fi   # dark red
  printf '\e[38;5;%sm' "$col"
}
# 8-cell gauge:  $1 pct (0-100) -> filled █ on the green→red ramp, empty ░ adaptive grey.
# Ends on WB_FR so it never clears the zebra background underneath it.
__wb_bar() {
  local pct="$1" w=8 fill i bar
  [[ "$pct" =~ ^[0-9]+$ ]] || pct=0
  fill=$(( pct*w/100 )); ((fill>w))&&fill=w; ((fill<0))&&fill=0
  bar="$(__wb_grad "$pct")"; for ((i=0;i<fill;i++)); do bar+="█"; done
  bar+="$WB_DM";  for ((i=fill;i<w;i++)); do bar+="░"; done
  printf '%s%s' "$bar" "$WB_FR"
}
__wb_tcol() { local t="${1:-0}"; [[ "$t" =~ ^[0-9]+$ ]] || { printf '%s' "$WB_GRY"; return; }
  if ((t>=80)); then printf '%s' "$WB_RED"; elif ((t>=70)); then printf '%s' "$WB_YEL"; else printf '%s' "$WB_GRN"; fi; }
# one aligned, zebra-striped panel row:  $1 name  $2 pct  $3 sparkline  $4 device+detail (WB_FR resets)
__wb_mrow() {
  local c graph="$3"
  [ -z "$graph" ] && graph="▁▁▁▁▁▁▁▁"
  c="${WB_LBL}$(printf '%-5s' "$1")${WB_FR} $(__wb_bar "$2") ${WB_B}${WB_WHT}$(printf '%3s' "${2:-?}")%${WB_FR} ${WB_CYN}${graph}${WB_FR}  $4"
  __wb_zrow "$c"
}
__wb_msub() {
  __wb_plainrow "${WB_DM}$(printf '%21s' '')${WB_GOLD}${1}${WB_FR}"
}
__wb_center() {
  local w="$1" text="$2" pad right
  pad=$(( (w - ${#text}) / 2 )); ((pad < 0)) && pad=0
  right=$(( w - ${#text} - pad )); ((right < 0)) && right=0
  printf '%*s%s%*s' "$pad" '' "$text" "$right" ''
}
__wb_loadrow() {
  local pct="$1" l1="$2" l5="$3" l15="$4" up="$5" graph="$6" c labels
  [ -z "$graph" ] && graph="▁▁▁▁▁▁▁▁"
  c="${WB_LBL}$(printf '%-5s' 'LOAD')${WB_FR} $(__wb_bar "$pct") ${WB_B}${WB_WHT}$(printf '%3s' "${pct:-0}")%${WB_FR} ${WB_CYN}${graph}${WB_FR}  ${WB_WHT}$(printf '%5s %5s %5s' "${l1:-?}" "${l5:-?}" "${l15:-?}")${WB_DM} · up ${up:-?}"
  labels="${WB_D}$(printf '%30s' '')${WB_WHT}$(__wb_center 5 '1m') $(__wb_center 5 '5m') $(__wb_center 5 '15m')${WB_R}"
  __wb_zrow "$c"
  __wb_plainrow "$labels"
}
__wb_pct() {
  local p="${1:-0}"
  [[ "$p" =~ ^-?[0-9]+$ ]] || p=0
  ((p < 0)) && p=0
  ((p > 100)) && p=100
  printf '%s' "$p"
}
__wb_clock_pct() {
  local cur="${1:-0}" max="${2:-0}"
  [[ "$cur" =~ ^[0-9]+$ ]] || cur=0
  [[ "$max" =~ ^[0-9]+$ ]] || max=0
  if ((max > 0)); then
    __wb_pct $((cur * 100 / max))
  else
    printf '0'
  fi
}
__wb_hist_path() {
  printf '%s' "${WELCOME_BOARD_MACHINE_HISTORY:-$HOME/.local/state/welcome-board/machine-series.tsv}"
}
__wb_hist_trim() {
  local path="$1" tmp
  [ -f "$path" ] || return 0
  tmp="${path}.tmp.$$"
  tail -n 512 "$path" > "$tmp" 2>/dev/null && mv "$tmp" "$path"
  rm -f "$tmp" 2>/dev/null || true
}
__wb_hist_add() {
  local key="$1" value="$(__wb_pct "$2")" path dir now
  path="$(__wb_hist_path)"
  dir=$(dirname "$path")
  mkdir -p "$dir" 2>/dev/null || return 0
  now=$(date +%s 2>/dev/null || echo 0)
  printf '%s\t%s\t%s\n' "$now" "$key" "$value" >> "$path" 2>/dev/null || return 0
}
__wb_hist_graph() {
  local key="$1" value="$(__wb_pct "$2")" path vals count pad v idx out="" levels="▁▂▃▄▅▆▇█"
  path="$(__wb_hist_path)"
  __wb_hist_add "$key" "$value"
  __wb_hist_trim "$path"
  vals=$(awk -F '\t' -v k="$key" '$2==k {print $3}' "$path" 2>/dev/null | tail -n 8)
  count=$(printf '%s\n' "$vals" | sed '/^$/d' | wc -l | awk '{print $1}')
  pad=$((8 - count))
  while ((pad > 0)); do
    vals=$(printf '0\n%s' "$vals")
    pad=$((pad - 1))
  done
  while read -r v; do
    [ -z "$v" ] && continue
    v=$(__wb_pct "$v")
    idx=$((v * 7 / 100))
    out+="${levels:idx:1}"
  done <<< "$vals"
  printf '%s' "${out:-▁▁▁▁▁▁▁▁}"
}
# instantaneous CPU busy% from a short /proc/stat delta (falls back to load proxy)
__wb_cpubusy() {
  local a b t1 i1 t2 i2 dt di
  read -r t1 i1 < <(awk '/^cpu /{idle=$5+$6;tot=0;for(i=2;i<=NF;i++)tot+=$i;print tot,idle}' /proc/stat 2>/dev/null)
  sleep 0.1 2>/dev/null
  read -r t2 i2 < <(awk '/^cpu /{idle=$5+$6;tot=0;for(i=2;i<=NF;i++)tot+=$i;print tot,idle}' /proc/stat 2>/dev/null)
  dt=$(( ${t2:-0}-${t1:-0} )); di=$(( ${i2:-0}-${i1:-0} ))
  if ((dt>0)); then echo $(( (100*(dt-di))/dt ))
  else awk -v n="$(nproc 2>/dev/null||echo 1)" '{p=$1/n*100;p=(p>100)?100:p;printf "%d",p}' /proc/loadavg 2>/dev/null; fi
}

__wb_macos_load() {
  uptime 2>/dev/null | awk -F'load averages?: ' '{split($2,a," "); print a[1],a[2],a[3]}' | awk '{print $1,$2,$3}'
}

__wb_machine_macos() {
  __wb_hdr "MACHINE"; __wb_zreset
  local cbrand cores mem_bytes vm page_size active wired compressed used_pages used_gb total_gb rpct
  local du dt dp l1 l5 l15 lpct up
  cbrand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
  : "${cbrand:=Apple CPU}"
  cores=$(sysctl -n hw.logicalcpu 2>/dev/null)
  : "${cores:=?}"

  mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
  vm=$(vm_stat 2>/dev/null)
  page_size=$(printf '%s\n' "$vm" | awk '/page size of/{gsub(/[^0-9]/,"",$8); print $8; exit}')
  : "${page_size:=4096}"
  active=$(printf '%s\n' "$vm" | awk '/Pages active/{gsub(/[^0-9]/,"",$3); print $3; exit}')
  wired=$(printf '%s\n' "$vm" | awk '/Pages wired down/{gsub(/[^0-9]/,"",$4); print $4; exit}')
  compressed=$(printf '%s\n' "$vm" | awk '/Pages occupied by compressor/{gsub(/[^0-9]/,"",$5); print $5; exit}')
  used_pages=$(( ${active:-0} + ${wired:-0} + ${compressed:-0} ))
  used_gb=$(awk -v p="$used_pages" -v s="$page_size" 'BEGIN{printf "%.1f", p*s/1024/1024/1024}')
  total_gb=$(awk -v b="${mem_bytes:-0}" 'BEGIN{if(b>0)printf "%.0f", b/1024/1024/1024; else printf "?"}')
  rpct=$(awk -v u="$used_gb" -v t="$total_gb" 'BEGIN{if(t>0)printf "%d", u*100/t; else printf 0}')

  read -r dt du dp < <(df -P / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); printf "%.0f %.0f %s", $2*512/1024/1024/1024, $3*512/1024/1024/1024, $5}')
  read -r l1 l5 l15 < <(__wb_macos_load)
  lpct=$(awk -v n="${cores:-1}" -v x="${l1:-0}" 'BEGIN{if(n<1)n=1; p=x/n*100; if(p>100)p=100; printf "%d", p}')
  up=$(uptime 2>/dev/null | sed -E 's/^.* up  *//; s/, *[0-9]+ users?.*$//; s/load averages?:.*$//; s/  */ /g; s/,$//')

  __wb_msub "PRESSURE"
  __wb_mrow "CPU"  "${lpct:-0}" "$(__wb_hist_graph cpu "${lpct:-0}")" "${WB_DEV}${cbrand}  ${WB_DM}${cores}t · ${WB_WHT}macOS"
  __wb_mrow "GPU"  "0"          "$(__wb_hist_graph gpu 0)" "${WB_DEV}Apple/Metal GPU${WB_DM} · not exposed"
  __wb_mrow "VRAM" "0"          "$(__wb_hist_graph vram 0)" "${WB_DM}shared memory on Apple/Metal systems"
  __wb_mrow "RAM"  "${rpct:-0}" "$(__wb_hist_graph ram "${rpct:-0}")" "$(__wb_grad "${rpct:-0}")${used_gb}${WB_DM}/${total_gb} GB"
  __wb_mrow "SWAP" "0"          "$(__wb_hist_graph swap 0)" "${WB_DM}macOS manages swap dynamically"
  __wb_mrow "DISK" "${dp:-0}"   "$(__wb_hist_graph disk "${dp:-0}")" "$(__wb_grad "${dp:-0}")${du:-?}${WB_DM}/${dt:-?} GB · root fs"
  __wb_loadrow "${lpct:-0}" "${l1:-?}" "${l5:-?}" "${l15:-?}" "${up:-?}" "$(__wb_hist_graph load "${lpct:-0}")"
  __wb_msub "TEMP"
  __wb_mrow "CTEMP" "0" "$(__wb_hist_graph ctemp 0)" "${WB_DEV}CPU${WB_DM} · not exposed"
  __wb_mrow "GTEMP" "0" "$(__wb_hist_graph gtemp 0)" "${WB_DEV}GPU${WB_DM} · not exposed"
  __wb_msub "CLOCKS"
  __wb_mrow "GCLK" "0" "$(__wb_hist_graph gclk 0)" "${WB_DEV}graphics${WB_DM} · not exposed"
  __wb_mrow "MCLK" "0" "$(__wb_hist_graph mclk 0)" "${WB_DEV}memory${WB_DM} · not exposed"
}

# ---- MACHINE (full geek panel: aligned gauges + every pollable stat) --------
__wb_machine() {
  if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
    __wb_machine_macos
    return
  fi
  __wb_hdr "MACHINE"; __wb_zreset
  # --- CPU ---
  local cbrand cores ctemp cfcur cfmax cbusy
  cbrand=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null \
           | sed -E 's/.*: //; s/\(R\)//g; s/\(TM\)//g; s/Intel //; s/Core //; s/ CPU.*//; s/  */ /g; s/^ //')
  : "${cbrand:=CPU}"
  cores=$(nproc 2>/dev/null || echo '?')
  ctemp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1); [ -n "$ctemp" ] && ctemp=$((ctemp/1000))
  cfcur=$(awk '{s+=$1;n++} END{if(n)printf "%.2f",s/n/1e6}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)
  cfmax=$(awk '{printf "%.2f",$1/1e6}' /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
  cbusy=$(__wb_cpubusy)
  # --- GPU (single nvidia-smi poll, parsed) ---
  local gpu gname gp gutil gtemp vu vt cgr cgrmax cm cmmax gpw vpct
  gpu=$(nvidia-smi --query-gpu=name,pstate,utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.gr,clocks.max.gr,clocks.mem,clocks.max.mem,power.draw \
        --format=csv,noheader,nounits 2>/dev/null | head -1)
  IFS=',' read -r gname gp gutil gtemp vu vt cgr cgrmax cm cmmax gpw <<<"$gpu"
  gname=$(printf '%s' "$gname" | sed -E 's/^ *//; s/NVIDIA //; s/GeForce //'); : "${gname:=no GPU}"
  for v in gp gutil gtemp vu vt cgr cgrmax cm cmmax gpw; do printf -v "$v" '%s' "${!v// /}"; done
  [ -n "$vt" ] && [ "$vt" -gt 0 ] 2>/dev/null && vpct=$(( ${vu:-0}*100/vt )) || vpct=0
  gpw=${gpw%.*}
  local gclk_pct mclk_pct
  gclk_pct=$(__wb_clock_pct "$cgr" "$cgrmax")
  mclk_pct=$(__wb_clock_pct "$cm" "$cmmax")
  # --- RAM / SWAP / DISK / LOAD ---
  local mu mtot rpct su stot spct du dt dp up l1 l5 l15 lpct ruGB rtGB suGB stGB
  read -r mu mtot < <(free -m 2>/dev/null | awk '/^Mem:/{print $3,$2}')
  [ -n "$mtot" ] && [ "$mtot" -gt 0 ] 2>/dev/null && rpct=$(( ${mu:-0}*100/mtot )) || rpct=0
  read -r su stot < <(free -m 2>/dev/null | awk '/^Swap:/{print $3,$2}')
  [ -n "$stot" ] && [ "$stot" -gt 0 ] 2>/dev/null && spct=$(( ${su:-0}*100/stot )) || spct=0
  read -r du dt dp < <(df -BG --output=used,size,pcent / 2>/dev/null | tail -1 | tr -d 'G%')
  read -r l1 l5 l15 _ < /proc/loadavg 2>/dev/null
  lpct=$(awk -v n="${cores:-1}" -v x="${l1:-0}" 'BEGIN{p=x/n*100;p=(p>100)?100:p;printf "%d",p}')
  up=$(uptime -p 2>/dev/null | sed 's/^up //;s/ hours\?/h/;s/ minutes\?/m/;s/ days\?/d/;s/ weeks\?/w/;s/,//g')
  ruGB=$(awk -v u="${mu:-0}" 'BEGIN{printf "%.1f", u/1024}')
  rtGB=$(awk -v t="${mtot:-0}" 'BEGIN{printf "%.0f", t/1024}')
  suGB=$(awk -v u="${su:-0}" 'BEGIN{printf "%.1f", u/1024}')
  stGB=$(awk -v t="${stot:-0}" 'BEGIN{printf "%.0f", t/1024}')
  # --- render: gauges align in one column; in each used/total pair the USED
  #     value is bright/gradient and the TOTAL is dim, so the two never blend ---
  __wb_msub "PRESSURE"
  __wb_mrow "CPU"  "${cbusy:-0}" "$(__wb_hist_graph cpu "${cbusy:-0}")" "${WB_DEV}${cbrand}  ${WB_DM}${cores}t · ${WB_WHT}${cfcur:-?}${WB_DM}/${cfmax:-?} GHz"
  __wb_mrow "GPU"  "${gutil:-0}" "$(__wb_hist_graph gpu "${gutil:-0}")" "${WB_DEV}${gname}  ${WB_DM}${gp:-?} · ${WB_WHT}${gpw:-?}${WB_DM} W"
  __wb_mrow "VRAM" "${vpct}"     "$(__wb_hist_graph vram "${vpct:-0}")" "$(__wb_grad "$vpct")${vu:-?}${WB_DM}/${vt:-?} MB"
  __wb_mrow "RAM"  "${rpct}"     "$(__wb_hist_graph ram "${rpct:-0}")" "$(__wb_grad "$rpct")${ruGB}${WB_DM}/${rtGB} GB"
  __wb_mrow "SWAP" "${spct}"     "$(__wb_hist_graph swap "${spct:-0}")" "$(__wb_grad "$spct")${suGB}${WB_DM}/${stGB} GB"
  __wb_mrow "DISK" "${dp:-0}"    "$(__wb_hist_graph disk "${dp:-0}")" "$(__wb_grad "${dp:-0}")${du:-?}${WB_DM}/${dt:-?} GB · root fs"
  __wb_loadrow "${lpct:-0}" "${l1:-?}" "${l5:-?}" "${l15:-?}" "${up:-?}" "$(__wb_hist_graph load "${lpct:-0}")"
  __wb_msub "TEMP"
  __wb_mrow "CTEMP" "$(__wb_pct "${ctemp:-0}")" "$(__wb_hist_graph ctemp "${ctemp:-0}")" "${WB_DEV}CPU${WB_DM} · ${WB_FR}$(__wb_tcol "$ctemp")${ctemp:-?}°C"
  __wb_mrow "GTEMP" "$(__wb_pct "${gtemp:-0}")" "$(__wb_hist_graph gtemp "${gtemp:-0}")" "${WB_DEV}GPU${WB_DM} · ${WB_FR}$(__wb_tcol "$gtemp")${gtemp:-?}°C"
  __wb_msub "CLOCKS"
  __wb_mrow "GCLK" "$gclk_pct" "$(__wb_hist_graph gclk "$gclk_pct")" "${WB_DEV}graphics${WB_DM} · ${WB_WHT}${cgr:-?}${WB_DM}/${cgrmax:-?} MHz"
  __wb_mrow "MCLK" "$mclk_pct" "$(__wb_hist_graph mclk "$mclk_pct")" "${WB_DEV}memory${WB_DM} · ${WB_WHT}${cm:-?}${WB_DM}/${cmmax:-?} MHz"
}

# ---- NETWORK (local VPN/SSH glance, no hardcoded machines) -----------------
__wb_network() {
  __wb_hdr "NETWORK"
  local ts self nssh sc
  ts=$(timeout 1 tailscale status 2>/dev/null)
  self=$(timeout 1 tailscale ip -4 2>/dev/null | head -1)
  nssh=$(who 2>/dev/null | grep -cE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)')
  sc=$WB_WHT; [ "${nssh:-0}" -ge 4 ] 2>/dev/null && sc=$WB_YEL
  __wb_zreset
  if [ -n "$self" ]; then
    __wb_zrow "${WB_LBL}$(printf '%-10s' 'vpn')${WB_FR}${WB_WHT}$(printf '%-16s' "$self")${WB_DM}local VPN address"
  elif command -v tailscale >/dev/null 2>&1; then
    __wb_zrow "${WB_LBL}$(printf '%-10s' 'vpn')${WB_FR}${WB_DM}installed, no local address"
  else
    __wb_zrow "${WB_LBL}$(printf '%-10s' 'vpn')${WB_FR}${WB_DM}not installed"
  fi
  __wb_zrow "${WB_LBL}$(printf '%-10s' 'ssh now')${WB_FR}${sc}${nssh:-0} active${WB_FR} ${WB_DM}remote terminal sessions"
}

# ---- LOCKS (security at a glance) ------------------------------------------
__wb_portname() {
  case "$1" in
    22) echo SSH;; 53) echo DNS;; 139|445) echo Samba;;
    631) echo printing;; 5432) echo Postgres;; 6379) echo Redis;;
    6333) echo "vector DB";;
    37360) echo media;; *) echo "port $1";;
  esac
}
__wb_group() {  # $1 ports, $2 name-color
  local ports="$1" color="$2" out="" p n
  for p in $(printf '%s\n' "$ports" | tr ' ' '\n' | sed '/^$/d' | sort -nu); do
    n=$(__wb_portname "$p")
    out="$out${WB_DM}, ${color}${n}${WB_DM}:${p}"
  done
  printf '%s' "${out#${WB_DM}, }"
}
__wb_locks() {
  __wb_hdr "LOCKS"
  local expected=" ${WB_EXPECTED_PORTS:-} "
  local lan="" alert="" rygel_ports="" seen_ports="" line port addr proc
  while read -r line; do
    read -r _ _ _ addr _ proc <<<"$line"
    port="${addr##*:}"
    addr="${addr%:*}"
    addr="${addr%\%*}"
    addr="${addr//[\[\]]/}"
    case "$addr" in 127.*|::1|100.*|fd7a:*|fe80:*) continue;; esac
    case " $seen_ports " in *" $port "*) continue;; esac
    seen_ports="$seen_ports $port"
    if [[ "$proc" == rygel* || "$proc" == *rygel* ]]; then
      rygel_ports="$rygel_ports $port"
    elif [[ "$expected" == *" $port "* ]]; then
      lan="$lan $port"
    else
      alert="$alert $port"
    fi
  done < <(echo "$WB_LISTENP")
  __wb_zreset
  if [ -n "$alert" ]; then
    __wb_zrow "${WB_YEL}${WB_B}Visible LAN ports:${WB_FR} ${WB_YEL}$(__wb_group "$alert" "$WB_YEL")${WB_DM} — review before lockdown"
  else
    __wb_zrow "${WB_GRN}${WB_B}✓ No unapproved LAN ports seen.${WB_FR} ${WB_DM}expected: ${WB_WHT}$(__wb_group "$lan" "$WB_WHT")"
    __wb_zrow "${WB_DM}loopback, VPN, and link-local listeners are not counted as LAN exposure."
  fi
  if [ -n "$rygel_ports" ]; then
    __wb_zrow "${WB_DM}known dynamic service: ${WB_WHT}Rygel media server${WB_DM} on ${WB_WHT}${rygel_ports# }"
  fi
}

# ---- SERVICES (is anything broken?) ----------------------------------------
__wb_services() {
  __wb_hdr "SERVICES"
  local -a svc=()
  local e
  for e in ${WB_SERVICE_PORTS:-}; do svc+=("$e"); done
  if [ "${#svc[@]}" -eq 0 ]; then
    __wb_zreset
    __wb_zrow "${WB_LBL}$(printf '%-10s' 'services')${WB_FR}${WB_DM}set WB_SERVICE_PORTS=\"name:port name:port\" to monitor apps"
    return
  fi
  local up="" down="" e n p
  for e in "${svc[@]}"; do n="${e%:*}"; p="${e##*:}"
    if echo "$WB_LISTEN" | grep -q ":$p "; then up="$up, $n"; else down="$down, $n"; fi; done
  __wb_zreset
  if [ -z "$down" ]; then __wb_zrow "${WB_GRN}${WB_B}✓ All up.${WB_FR} ${WB_DM}${up#,}"
  else __wb_zrow "${WB_RED}${WB_B}⚠ Down:${WB_FR}${WB_RED}${down#,}${WB_FR}   ${WB_DM}up:${up#,}"; fi
}

# ---- TMUX (active terminal sessions) ---------------------------------------
__wb_tmux() {
  __wb_hdr "TMUX"
  __wb_zreset
  if ! command -v tmux >/dev/null 2>&1; then
    __wb_zrow "${WB_LBL}$(printf '%-10s' 'tmux')${WB_FR}${WB_DM}not installed"
    return
  fi

  local sessions line name shown windows attached color noun
  sessions=$(tmux list-sessions -F '#S	#{session_windows}	#{?session_attached,attached,detached}' 2>/dev/null || true)
  if [ -z "$sessions" ]; then
    __wb_zrow "${WB_LBL}$(printf '%-10s' 'tmux')${WB_FR}${WB_DM}no sessions"
    return
  fi

  while IFS=$'\t' read -r name windows attached; do
    [ -z "$name" ] && continue
    shown="$name"
    [ "${#shown}" -gt 14 ] && shown="${shown:0:11}..."
    noun="windows"
    [ "${windows:-0}" = "1" ] && noun="window"
    color="$WB_DM"
    [ "$attached" = "attached" ] && color="$WB_GRN"
    __wb_zrow "${WB_LBL}$(printf '%-15s' "$shown")${WB_FR} ${WB_WHT}${windows:-?} ${noun}${WB_DM} · ${color}${attached:-detached}${WB_FR}"
  done <<< "$sessions"
}

# ---- COMMANDS (cyan = copyable). tmux reminders kept. ----------------------
__wb_cmdrow() {
  local label="$1" body="$2"
  __wb_zrow "${WB_PNK}${WB_B}$(printf '%-8s' "$label")${WB_FR} ${body}"
}
__wb_commands() {
  __wb_hdr "COMMANDS"
  __wb_zreset
  __wb_cmdrow "BOARD"  "${WB_CYN}wb${WB_FR} ${WB_D}render${WB_FR}   ${WB_CYN}wb help${WB_FR}   ${WB_CYN}welcomeboard${WB_FR}"
  __wb_cmdrow "SETUP"  "${WB_CYN}wb setup${WB_FR} ${WB_D}name, banner, theme, sections${WB_FR}   ${WB_CYN}wb theme${WB_FR}"
  __wb_cmdrow "PORTS"  "${WB_CYN}wb ports explain${WB_FR} ${WB_D}read-only map${WB_FR}   ${WB_CYN}wb ports plan${WB_FR} ${WB_D}dry run${WB_FR}"
  __wb_cmdrow "TMUX"   "${WB_D}new:${WB_FR} ${WB_CYN}tmux new -s work${WB_FR}   ${WB_D}join:${WB_FR} ${WB_CYN}tmux attach -t work${WB_FR}"
  __wb_cmdrow ""       "${WB_D}detach:${WB_FR} ${WB_CYN}Ctrl-b d${WB_FR}   ${WB_D}list:${WB_FR} ${WB_CYN}tmux ls${WB_FR}"
  __wb_cmdrow "CHECK"  "${WB_CYN}bash -n welcome-board.sh${WB_FR}   ${WB_CYN}python3 -m unittest discover -s tests -v${WB_FR}"
  [ "${WB_FRAME_ON:-0}" = 1 ] || echo
}

# ============================ render =========================================
__wb_top_space() {
  printf '\n\n'
}

__wb_bottom_space() {
  printf '\n\n'
}

__wb_render() {
  __wb_load_config
  __wb_paint
  WB_FRAME_ON=1
  WB_FRAME_INNER=78
  WB_W=$WB_FRAME_INNER
  WB_ZW=$WB_FRAME_INNER   # zebra stripe width inside the outer frame
  WB_LISTEN=$(ss -tlnH 2>/dev/null)
  WB_LISTENP=$(ss -tlnHp 2>/dev/null)
  __wb_top_space
  __wb_banner
  __wb_frame_top
  __wb_greeting_row
  __wb_section_enabled machine && __wb_machine
  __wb_section_enabled network && __wb_network
  __wb_section_enabled locks && __wb_locks
  __wb_section_enabled services && __wb_services
  __wb_section_enabled tmux && __wb_tmux
  __wb_section_enabled commands && __wb_commands
  __wb_frame_bottom
  WB_FRAME_ON=0
}

__wb_section_enabled() {
  case " ${WB_SECTIONS:-machine tmux commands} " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---- user commands ---------------------------------------------------------
clamboard() { __wb_render; __wb_bottom_space; }
clamhelp() {
  __wb_load_config
  __wb_paint
  __wb_hdr "FULL REFERENCE"
  local -a sec=(
    "WELCOME BOARD" 'wb|render the board' 'welcomeboard|same as wb'
    'wb help|show helper commands' 'wb setup|write user config'
    'wb theme|list themes' 'wb theme amber-terminal|set a theme'
    'wb sections|show enabled sections' 'wb ports scan|read-only listening-port scan'
    'clamboard|reprint the board from a sourced shell'
    "TMUX  (it runs your shell in a named session that survives disconnect)"
    'tmux new -s work|start a session called work' 'tmux attach -t work|re-join it after reconnect'
    'tmux ls|list sessions' 'Ctrl-b then d|detach (leave it running in background)'
    'tmux new -s example|create a session named example' 'tmux attach -t example|join session named example'
    'tmux kill-session -t example|delete session named example'
    "VERIFY" 'bash -n welcome-board.sh|check shell syntax'
    'PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v|run tests'
  )
  local e c d
  for e in "${sec[@]}"; do
    if [[ "$e" != *"|"* ]]; then printf '\n  %s▌%s %s%s%s\n' "$WB_AC" "$WB_R" "$WB_HDR$WB_B" "$e" "$WB_R"
    else c="${e%%|*}"; d="${e##*|}"; printf '   %s%-20s%s%s%s%s\n' "$WB_CYN" "$c" "$WB_R" "$WB_D" "$d" "$WB_R"; fi
  done; echo
}

# ---- auto-render: interactive shells, or when executed directly ------------
if [[ $- == *i* ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then __wb_render; fi
