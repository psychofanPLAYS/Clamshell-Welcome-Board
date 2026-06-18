#!/usr/bin/env bash
# ============================================================================
#  WELCOME BOARD  (v4 — operator board: glanceable, symmetrical, cross-platform)
#  Prints on interactive shell start / SSH login. Sourced from ~/.bashrc.
#  Works on Linux + macOS. FAST + failure-tolerant: local checks only, every
#  field wrapped 2>/dev/null with a fallback. The board NEVER errors out and
#  NEVER blocks the prompt — a failed probe shows as "—", never a crash.
#  Self-contained; also runs via `clamboard` / `wb render`. Defines the
#  clamboard / clamhelp / hkeys user commands.
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
__wb_load_config() {
  [ "${_WB_CONFIG_LOADED:-0}" = 1 ] && return 0
  _WB_CONFIG_LOADED=1
  local cfg="${WELCOME_BOARD_CONFIG:-$HOME/.config/welcome-board/config}" key raw value
  if [ -r "$cfg" ]; then
    while IFS='=' read -r key raw || [ -n "$key" ]; do
      case "$key" in
        WB_DISPLAY_NAME|WB_BANNER_TEXT|WB_THEME|WB_SERVICE_PORTS|WB_EXPECTED_PORTS|\
WB_PEERS|WB_PORT_BASELINE_FILE|WB_HERMES_LABEL|WB_AUTOMATION_MATCH|WB_AUTOMATION_LABEL|WB_AUTOMATION_DAILY|WB_FRAME_INNER)
          value="$(__wb_config_value "$raw")"; printf -v "$key" '%s' "$value" ;;
      esac
    done < "$cfg"
  fi
  : "${WB_DISPLAY_NAME:=${USER:-friend}}"
  : "${WB_BANNER_TEXT:=CLAMSHELL}"
  : "${WB_THEME:=cyan-dark}"
  : "${WB_FRAME_INNER:=78}"
  : "${WB_SERVICE_PORTS:=ssh:22 webdash:6900 embedder:6901 reranker:6902 honcho:6903 kenny-gate:6913 hermes:6916 cockpit:36900 qdrant:6333}"
  : "${WB_PORT_BASELINE_FILE:=$HOME/.local/state/welcome-board/ports-baseline.txt}"
  : "${WB_AUTOMATION_MATCH:=oppy superbrain kenny darkfactory trading codex claude hermes lcm curator reindex secondbrain news update-safe xtreme resource-recycler}"
}

# ---- palette (256-colour, tuned for dark terminals) -------------------------
__wb_paint() {
  WB_R=$'\e[0m'; WB_B=$'\e[1m'; WB_D=$'\e[38;5;245m'
  WB_GRN=$'\e[38;5;78m'; WB_RED=$'\e[38;5;203m'; WB_YEL=$'\e[38;5;221m'
  WB_CYN=$'\e[38;5;81m'; WB_PNK=$'\e[38;5;211m'; WB_GRY=$'\e[38;5;250m'
  WB_WHT=$'\e[38;5;253m'; WB_HDR=$'\e[38;5;117m'; WB_AC=$'\e[38;5;81m'
  WB_LBL=$'\e[1m\e[38;5;111m'   # bold cornflower — name column
  WB_DEV=$'\e[38;5;180m'        # warm tan — device-name column
  WB_FR=$'\e[22;24;39m'         # fg-only reset: keeps the row's zebra bg
  WB_DM=$'\006'                 # sentinel for adaptive-dim grey (swapped per stripe)
}

# ---- platform ---------------------------------------------------------------
__wb_os() { case "$(uname -s 2>/dev/null)" in Darwin) echo macos;; *) echo linux;; esac; }

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
  printf '  %s│%s %b%*s%s│%s\n' "$WB_AC" "$WB_R" "$c" "$pad" '' "$WB_AC" "$WB_R"
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
  printf '  %s│%s %b%*s%s│%s\n' "$WB_AC" "$bg" "$c" "$pad" '' "$WB_AC" "$WB_R"
}

# ---- time-aware greeting (first name only, from config) ---------------------

# ---- BANNER (brand mark; figlet-style block art + binary subtitle) ----------
__wb_banner_baked() {   # pre-baked ANSI-Shadow "CLAMSHELL" brand art (default / fallback)
  cat <<'ART'
  ██████╗██╗      █████╗ ███╗   ███╗███████╗██╗  ██╗███████╗██╗     ██╗
 ██╔════╝██║     ██╔══██╗████╗ ████║██╔════╝██║  ██║██╔════╝██║     ██║
 ██║     ██║     ███████║██╔████╔██║███████╗███████║█████╗  ██║     ██║
 ██║     ██║     ██╔══██║██║╚██╔╝██║╚════██║██╔══██║██╔══╝  ██║     ██║
 ╚██████╗███████╗██║  ██║██║ ╚═╝ ██║███████║██║  ██║███████╗███████╗███████╗
  ╚═════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝
ART
}
__wb_banner_art() {   # echoes the banner art lines (no colour). Reused by the animation.
  local txt="${WB_BANNER_TEXT:-CLAMSHELL}"
  if [ -z "$txt" ] || [ "$txt" = "CLAMSHELL" ]; then __wb_banner_baked; return; fi
  if command -v figlet >/dev/null 2>&1; then
    figlet -w 120 -- "$txt" 2>/dev/null | grep -v '^[[:space:]]*$'
  elif command -v toilet >/dev/null 2>&1; then
    toilet -w 120 -f standard -- "$txt" 2>/dev/null | grep -v '^[[:space:]]*$'
  else
    printf '  >>>  %s  <<<\n' "$txt"
  fi
}
# binary subtitle = the banner word as 8-bit ASCII (pure bash, bash-3.2 safe)
__wb_banner_binary() {
  local txt b="" i j ch code byte
  txt=$(printf '%s' "${WB_BANNER_TEXT:-clamshell}" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'); : "${txt:=clamshell}"
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
  local -a g=($'\e[38;5;45m' $'\e[38;5;81m' $'\e[38;5;75m' $'\e[38;5;39m' $'\e[38;5;33m' $'\e[38;5;69m')
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
__wb_cpubusy() {
  local t1 i1 t2 i2 dt di
  read -r t1 i1 < <(awk '/^cpu /{idle=$5+$6;tot=0;for(i=2;i<=NF;i++)tot+=$i;print tot,idle}' /proc/stat 2>/dev/null)
  sleep 0.1 2>/dev/null
  read -r t2 i2 < <(awk '/^cpu /{idle=$5+$6;tot=0;for(i=2;i<=NF;i++)tot+=$i;print tot,idle}' /proc/stat 2>/dev/null)
  dt=$(( ${t2:-0}-${t1:-0} )); di=$(( ${i2:-0}-${i1:-0} ))
  if ((dt>0)); then echo $(( (100*(dt-di))/dt ))
  else awk -v n="$(nproc 2>/dev/null||echo 1)" '{p=$1/n*100;p=(p>100)?100:p;printf "%d",p}' /proc/loadavg 2>/dev/null; fi
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
    n="${e%:*}"; p="${e##*:}"; ntot=$((ntot+1))
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
  command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1 && have_timer=1
  local ntimers=0 ncron=0 nextlist=""
  if [ "$have_timer" = 1 ]; then
    local tl; tl=$(systemctl --user list-timers --no-pager 2>/dev/null | grep -E '\.timer' | grep -vEi 'launchpadlib|man-db|fwupd|fstrim|logrotate')
    ntimers=$(printf '%s\n' "$tl" | grep -cE '\.timer')
    local u names=() pretty="" x
    while read -r u; do [ -n "$u" ] && names+=("${u%.timer}"); done \
      < <(printf '%s\n' "$tl" | awk '{for(i=1;i<=NF;i++) if($i ~ /\.timer$/){print $i; break}}' | head -3)
    for x in "${names[@]}"; do pretty="$pretty${WB_DM}, ${WB_WHT}${x}"; done
    nextlist="${pretty#${WB_DM}, }"
  fi
  ncron=$(crontab -l 2>/dev/null | grep -vcE '^\s*#|^\s*$')
  if [ "$have_timer" = 1 ] || [ "${ncron:-0}" -gt 0 ]; then
    local label=""; [ -n "${WB_AUTOMATION_LABEL:-}" ] && label=" ${WB_DM}— ${WB_AUTOMATION_LABEL}"
    __wb_zrow "${WB_LBL}$(printf '%-9s' 'jobs')${WB_FR}${WB_WHT}${ntimers}${WB_DM} loops · ${WB_WHT}${ncron}${WB_DM} cron${label}"
    [ -n "$nextlist" ] && __wb_zrow "${WB_LBL}$(printf '%-9s' 'next up')${WB_FR}${nextlist}"
    [ -n "${WB_AUTOMATION_DAILY:-}" ] && __wb_zrow "${WB_LBL}$(printf '%-9s' 'daily')${WB_FR}${WB_DM}${WB_AUTOMATION_DAILY}"
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

# ---- ANIMATION (showpiece; opt-in. Login stays static + instant.) -----------
#  Banner SLAMS in from behind the right edge to its resting left position, then
#  the binary subtitle DECODES left-to-right. Synchronous + fast (~0.4s),
#  finishes before the prompt. Never used at login unless WB_ANIMATE=1.
__wb_anim_supported() { [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; }
__wb_animate_banner() {
  __wb_anim_supported || { __wb_banner; return; }
  # always restore the cursor, even if the animation is interrupted (Ctrl-C)
  trap 'printf "\033[?25h"; trap - RETURN INT' RETURN INT
  local -a art=(); local __l; while IFS= read -r __l; do art+=("$__l"); done < <(__wb_banner_art)
  local -a g=($'\e[38;5;45m' $'\e[38;5;81m' $'\e[38;5;75m' $'\e[38;5;39m' $'\e[38;5;33m' $'\e[38;5;69m')
  local h=${#art[@]} cols max_art=0 line i
  cols=$(tput cols 2>/dev/null || echo 100)
  for line in "${art[@]}"; do ((${#line} > max_art)) && max_art=${#line}; done
  local binary; binary=$(__wb_banner_binary)
  local home_pad=$(( (2 + ${#binary} - max_art) / 2 )); ((home_pad<0)) && home_pad=0
  for ((i=0;i<h;i++)); do printf '\n'; done
  printf '\e[?25l'
  local start=$(( cols - max_art - 2 )); ((start<home_pad)) && start=home_pad
  local off
  for ((off=start; off>home_pad; off-=6)); do
    printf '\e[%dA' "$h"
    for ((i=0;i<h;i++)); do printf '\e[2K%*s%s%s%s\n' "$off" '' "${g[i]}" "${art[i]}" "$WB_R"; done
    sleep 0.018 2>/dev/null
  done
  printf '\e[%dA' "$h"
  for ((i=0;i<h;i++)); do printf '\e[2K%*s%s%s%s\n' "$home_pad" '' "${g[i]}" "${art[i]}" "$WB_R"; done
  printf '\e[?25h'
  local ch
  printf '  %s' "$WB_HDR"
  for ((i=0;i<${#binary};i++)); do ch="${binary:i:1}"; printf '%s' "$ch"; case "$ch" in [01]) sleep 0.004 2>/dev/null;; esac; done
  printf '%s\n' "$WB_R"
}

# ============================ render =========================================
__wb_probe_listeners() {
  if [ "$(__wb_os)" = linux ] && command -v ss >/dev/null 2>&1; then
    WB_LISTEN=$(ss -tlnH 2>/dev/null); WB_LISTENP=$(ss -tlnHp 2>/dev/null)
  else WB_LISTEN=""; WB_LISTENP=""; fi
}
__wb_render() {
  local animate="${1:-0}"
  __wb_load_config; __wb_paint
  WB_FRAME_ON=1; WB_W=$WB_FRAME_INNER; WB_ZW=$WB_FRAME_INNER
  __wb_probe_listeners
  printf '\n'
  if [ "$animate" = 1 ] || [ "${WB_ANIMATE:-0}" = 1 ]; then __wb_animate_banner; else __wb_banner; fi
  __wb_frame_top
  __wb_greeting_row
  __wb_machine
  __wb_network
  __wb_security
  __wb_services
  __wb_automation
  __wb_hermes
  __wb_commands
  __wb_frame_bottom
  __wb_footer
  WB_FRAME_ON=0
}

# ---- user commands ----------------------------------------------------------
clamboard() {
  case "$1" in --animate|-a|animate) __wb_render 1;; *) __wb_render 0;; esac
  printf '\n'
}
hkeys() { __wb_load_config; __wb_paint; WB_FRAME_ON=1; WB_W=$WB_FRAME_INNER; WB_ZW=$WB_FRAME_INNER
  __wb_frame_top; __wb_hermes_full; __wb_frame_bottom; WB_FRAME_ON=0; }
keys() { hkeys; }
clamhelp() {
  __wb_load_config; __wb_paint
  printf '\n  %s▌%s %sWELCOME BOARD — FULL REFERENCE%s\n' "$WB_AC" "$WB_R" "$WB_HDR$WB_B" "$WB_R"
  local -a sec=(
    "BOARD" 'clamboard|reprint the welcome board' 'clamboard --animate|play the slam-in animation'
    'wb render|same board via the wb CLI' 'hkeys / keys|reprint the Hermes shortcuts'
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

# --- palette additions (set globally; __wb_paint never clears these) --------
WB_GOLD=$'\e[1m\e[38;5;220m'          # bold gold — group sub-headers
WB_NEON_ORANGE=$'\e[1m\e[38;5;208m'   # bold neon orange — the name, pops

# --- section header: TWO blank rows above, title divider, ONE blank below ---
__wb_hdr() {
  local lbl="$1" rule
  rule=$(( WB_FRAME_INNER - ${#lbl} - 3 )); ((rule < 4)) && rule=4
  __wb_plainrow ""
  __wb_plainrow ""
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
    msg=("sleep is a config flag — leave it set." "the machines don't blink; you should." "low light, high focus." "the LAN never sleeps; you can." "make it count, then rack out.")
  fi
  printf '%s\t%s' "${hi[RANDOM % ${#hi[@]}]}" "${msg[RANDOM % ${#msg[@]}]}"
}
__wb_greeting_row() {
  local name="${WB_DISPLAY_NAME:-friend}" hi msg up
  IFS=$'\t' read -r hi msg < <(__wb_greeting)
  up=$(uptime -p 2>/dev/null | sed 's/^up //;s/ hours\?/h/;s/ minutes\?/m/;s/ days\?/d/;s/ weeks\?/w/;s/,//g' || echo '?')
  __wb_plainrow ""
  __wb_plainrow "${WB_HDR}${hi}, ${WB_NEON_ORANGE}${name}${WB_FR}${WB_HDR}.${WB_R} ${WB_WHT}${msg}${WB_R}"
  __wb_plainrow "${WB_DM}up ${up} · $(date '+%a %d %b · %H:%M' 2>/dev/null)"
}

# --- machine helpers (history sparkline engine, ported intact) ---------------
__wb_pct() { local p="${1:-0}"; [[ "$p" =~ ^-?[0-9]+$ ]] || p=0; ((p<0))&&p=0; ((p>100))&&p=100; printf '%s' "$p"; }
__wb_clock_pct() { local c="${1:-0}" m="${2:-0}"; [[ "$c" =~ ^[0-9]+$ ]]||c=0; [[ "$m" =~ ^[0-9]+$ ]]||m=0; ((m>0)) && __wb_pct $((c*100/m)) || printf '0'; }
__wb_hist_path() { printf '%s' "${WELCOME_BOARD_MACHINE_HISTORY:-$HOME/.local/state/welcome-board/machine-series.tsv}"; }
__wb_hist_trim() { local p="$1" t; [ -f "$p" ] || return 0; t="${p}.tmp.$$"; tail -n 1024 "$p" >"$t" 2>/dev/null && mv "$t" "$p"; rm -f "$t" 2>/dev/null||true; }
__wb_hist_add()  { local k="$1" v; v="$(__wb_pct "$2")"; local p d; p="$(__wb_hist_path)"; d=$(dirname "$p"); mkdir -p "$d" 2>/dev/null||return 0; printf '%s\t%s\t%s\n' "$(date +%s 2>/dev/null||echo 0)" "$k" "$v" >>"$p" 2>/dev/null||return 0; }
# history sparkline (width + glyphs come from WB_SPARK_N / WB_SPARK globals)
: "${WB_SPARK:=▁▂▃▄▅▆▇█}"; : "${WB_SPARK_N:=8}"
__wb_hist_graph() {
  local key="$1" value path vals count pad v idx out="" levels="${WB_SPARK}" n="${WB_SPARK_N}" fb=""
  value="$(__wb_pct "$2")"; path="$(__wb_hist_path)"
  __wb_hist_add "$key" "$value"; __wb_hist_trim "$path"
  vals=$(awk -F '\t' -v k="$key" '$2==k {print $3}' "$path" 2>/dev/null | tail -n "$n")
  count=$(printf '%s\n' "$vals" | sed '/^$/d' | wc -l | awk '{print $1}')
  pad=$((n - count)); while ((pad>0)); do vals=$(printf '0\n%s' "$vals"); pad=$((pad-1)); done
  while read -r v; do [ -z "$v" ] && continue; v=$(__wb_pct "$v"); idx=$((v*7/100)); out+="${levels:idx:1}"; done <<< "$vals"
  for ((v=0;v<n;v++)); do fb+="${levels:0:1}"; done
  printf '%s' "${out:-$fb}"
}
# (__wb_mrow + __wb_msub are VARIANT-specific; defined below)

# --- network throughput (real /proc/net/dev delta; no mocks) -----------------
__wb_netrate() {   # echoes: iface rxKBs txKBs  (sum non-loopback over a 0.1s delta)
  local r1 t1 r2 t2 nif
  read -r r1 t1 < <(awk 'NR>2{gsub(":"," "); if($1!="lo"){rx+=$2;tx+=$10}} END{print rx+0,tx+0}' /proc/net/dev 2>/dev/null)
  sleep 0.1 2>/dev/null
  read -r r2 t2 < <(awk 'NR>2{gsub(":"," "); if($1!="lo"){rx+=$2;tx+=$10}} END{print rx+0,tx+0}' /proc/net/dev 2>/dev/null)
  nif=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}'); : "${nif:=net}"
  awk -v a="${r1:-0}" -v b="${r2:-0}" -v c="${t1:-0}" -v d="${t2:-0}" -v i="$nif" \
    'BEGIN{printf "%s %.0f %.0f", i, (b-a)/0.1/1024, (d-c)/0.1/1024}'
}

# --- load row routes through __wb_mrow so it matches each variant's style ----
__wb_loadrow() {
  local pct="$1" l1="$2" l5="$3" l15="$4" up="$5" graph="$6"
  __wb_mrow "LOAD" "$pct" "$graph" "${WB_WHT}${l1} ${WB_DM}· ${WB_WHT}${l5} ${WB_DM}· ${WB_WHT}${l15}${WB_DM}  (1m·5m·15m) · up ${up}"
}

# --- MACHINE: five segregated groups, real probes, history graphs -----------
__wb_machine() {
  [ "$(__wb_os)" = macos ] && { __wb_machine_macos; return; }
  __wb_hdr "MACHINE"; __wb_zreset
  # CPU
  local cbrand cores ctemp cfcur cfmax cbusy
  cbrand=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | sed -E 's/.*: //; s/\(R\)//g; s/\(TM\)//g; s/Intel //; s/Core //; s/ CPU.*//; s/  */ /g; s/^ //'); : "${cbrand:=CPU}"
  cores=$(nproc 2>/dev/null || echo '?')
  ctemp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1); [ -n "$ctemp" ] && ctemp=$((ctemp/1000))
  cfcur=$(awk '{s+=$1;n++} END{if(n)printf "%.2f",s/n/1e6}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)
  cfmax=$(awk '{printf "%.2f",$1/1e6}' /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
  cbusy=$(__wb_cpubusy)
  # RAM / SWAP
  local mu mtot rpct su stot spct ruGB rtGB suGB stGB
  read -r mu mtot < <(free -m 2>/dev/null | awk '/^Mem:/{print $3,$2}')
  [ -n "$mtot" ] && [ "$mtot" -gt 0 ] 2>/dev/null && rpct=$(( ${mu:-0}*100/mtot )) || rpct=0
  read -r su stot < <(free -m 2>/dev/null | awk '/^Swap:/{print $3,$2}')
  [ -n "$stot" ] && [ "$stot" -gt 0 ] 2>/dev/null && spct=$(( ${su:-0}*100/stot )) || spct=0
  ruGB=$(awk -v u="${mu:-0}" 'BEGIN{printf "%.1f",u/1024}'); rtGB=$(awk -v t="${mtot:-0}" 'BEGIN{printf "%.0f",t/1024}')
  suGB=$(awk -v u="${su:-0}" 'BEGIN{printf "%.1f",u/1024}'); stGB=$(awk -v t="${stot:-0}" 'BEGIN{printf "%.0f",t/1024}')
  # GPU
  local gpu gname gp gutil gtemp vu vt cgr cgrmax cm cmmax gpw vpct gclk_pct mclk_pct v
  gpu=$(nvidia-smi --query-gpu=name,pstate,utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.gr,clocks.max.gr,clocks.mem,clocks.max.mem,power.draw --format=csv,noheader,nounits 2>/dev/null | head -1)
  IFS=',' read -r gname gp gutil gtemp vu vt cgr cgrmax cm cmmax gpw <<<"$gpu"
  gname=$(printf '%s' "$gname" | sed -E 's/^ *//; s/NVIDIA //; s/GeForce //'); : "${gname:=no GPU}"
  for v in gp gutil gtemp vu vt cgr cgrmax cm cmmax gpw; do printf -v "$v" '%s' "${!v// /}"; done
  [ -n "$vt" ] && [ "$vt" -gt 0 ] 2>/dev/null && vpct=$(( ${vu:-0}*100/vt )) || vpct=0
  gpw=${gpw%.*}; gclk_pct=$(__wb_clock_pct "$cgr" "$cgrmax"); mclk_pct=$(__wb_clock_pct "$cm" "$cmmax")
  # DISK
  local du dt dp
  read -r du dt dp < <(df -BG --output=used,size,pcent / 2>/dev/null | tail -1 | tr -d 'G%')
  # LOAD
  local l1 l5 l15 lpct up
  read -r l1 l5 l15 _ < /proc/loadavg 2>/dev/null
  lpct=$(awk -v n="${cores:-1}" -v x="${l1:-0}" 'BEGIN{p=x/n*100;p=(p>100)?100:p;printf "%d",p}')
  up=$(uptime -p 2>/dev/null | sed 's/^up //;s/ hours\?/h/;s/ minutes\?/m/;s/ days\?/d/;s/ weeks\?/w/;s/,//g')

  __wb_msub "CPU"
  __wb_mrow  "USAGE" "${cbusy:-0}"             "$(__wb_hist_graph cpu "${cbusy:-0}")"   "${WB_DEV}${cbrand}  ${WB_DM}${cores}t · ${WB_WHT}${cfcur:-?}${WB_DM}/${cfmax:-?} GHz"
  __wb_mrow  "TEMP"  "$(__wb_pct "${ctemp:-0}")" "$(__wb_hist_graph ctemp "${ctemp:-0}")" "${WB_DEV}package${WB_DM} · ${WB_FR}$(__wb_tcol "$ctemp")${ctemp:-?}°C"
  __wb_loadrow "${lpct:-0}" "${l1:-?}" "${l5:-?}" "${l15:-?}" "${up:-?}" "$(__wb_hist_graph load "${lpct:-0}")"
  __wb_plainrow ""
  __wb_msub "RAM"
  __wb_mrow  "USED"  "${rpct}" "$(__wb_hist_graph ram "${rpct:-0}")"  "$(__wb_grad "$rpct")${ruGB}${WB_DM}/${rtGB} GB"
  __wb_mrow  "SWAP"  "${spct}" "$(__wb_hist_graph swap "${spct:-0}")" "$(__wb_grad "$spct")${suGB}${WB_DM}/${stGB} GB"
  __wb_plainrow ""
  __wb_msub "GPU"
  __wb_mrow  "USAGE" "${gutil:-0}"             "$(__wb_hist_graph gpu "${gutil:-0}")"   "${WB_DEV}${gname}  ${WB_DM}${gp:-?} · ${WB_WHT}${gpw:-?}${WB_DM} W"
  __wb_mrow  "TEMP"  "$(__wb_pct "${gtemp:-0}")" "$(__wb_hist_graph gtemp "${gtemp:-0}")" "${WB_DEV}core${WB_DM} · ${WB_FR}$(__wb_tcol "$gtemp")${gtemp:-?}°C"
  __wb_mrow  "VRAM"  "${vpct}" "$(__wb_hist_graph vram "${vpct:-0}")"  "$(__wb_grad "$vpct")${vu:-?}${WB_DM}/${vt:-?} MB"
  __wb_mrow  "CLOCK" "$gclk_pct" "$(__wb_hist_graph gclk "$gclk_pct")" "${WB_DEV}graphics${WB_DM} · ${WB_WHT}${cgr:-?}${WB_DM}/${cgrmax:-?} MHz"
  __wb_plainrow ""
  __wb_msub "DISK"
  __wb_mrow  "ROOT"  "${dp:-0}" "$(__wb_hist_graph disk "${dp:-0}")"  "$(__wb_grad "${dp:-0}")${du:-?}${WB_DM}/${dt:-?} GB · /"
}

__wb_machine_macos() {
  __wb_hdr "MACHINE"; __wb_zreset
  local cbrand cores mtot_b ctot psize mu_pages mu rpct btot bused dt du dp l1 l5 l15 lpct up
  cbrand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | sed -E 's/ +\(.*\)$//; s/  */ /g'); : "${cbrand:=Apple Silicon}"
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
__wb_network() {
  __wb_hdr "NETWORK"; __wb_zreset
  local nif nrx ntx npct
  read -r nif nrx ntx < <(__wb_netrate)
  npct=$(awk -v r="${nrx:-0}" -v t="${ntx:-0}" 'BEGIN{m=(r>t)?r:t;p=m/12500*100;p=(p>100)?100:p;printf "%d",p}')
  __wb_mrow "RATE" "${npct}" "$(__wb_hist_graph net "${npct}")" "${WB_DEV}${nif:-—}  ${WB_DM}down ${WB_WHT}${nrx:-0}${WB_DM} · up ${WB_WHT}${ntx:-0}${WB_DM} KB/s"
  local ts self peer nm match probe ip st
  ts=$(timeout 1 tailscale status 2>/dev/null)
  self=$(hostname 2>/dev/null | cut -d. -f1)
  if [ -n "$self" ]; then
    ip=$(echo "$ts" | awk -v h="$self" '$0 ~ h {print $1; exit}'); : "${ip:=$(hostname -I 2>/dev/null | awk '{print $1}')}"
    __wb_zrow "${WB_LBL}$(printf '%-6s' "${self:0:6}")${WB_FR} ${WB_WHT}$(printf '%-16s' "${ip:-?}")${WB_DM}· this machine"
  fi
  local IFS_SAVE="$IFS"
  for peer in ${WB_PEERS:-}; do
    IFS='|' read -r nm match probe <<<"$peer"; IFS="$IFS_SAVE"
    ip=$(echo "$ts" | awk -v m="$match" '$0 ~ m {print $1; exit}')
    local phost="${probe%:*}" pport="${probe##*:}"
    if [ -n "$probe" ] && [[ "$phost" =~ ^[A-Za-z0-9._-]+$ ]] && [[ "$pport" =~ ^[0-9]+$ ]] \
       && timeout 0.8 bash -c "exec 3<>/dev/tcp/${phost}/${pport}" 2>/dev/null; then
      st="${WB_GRN}● serving ${WB_DM}:${pport}"
    elif echo "$ts" | grep -qi "$match.*active"; then st="${WB_GRN}● online"
    else st="${WB_DM}○ offline"; fi
    __wb_zrow "${WB_LBL}$(printf '%-6s' "${nm:0:6}")${WB_FR} ${WB_WHT}$(printf '%-16s' "${ip:-—}")${WB_FR}${st}"
  done
  IFS="$IFS_SAVE"
  local nssh sc ntmux tnames
  nssh=$(who 2>/dev/null | grep -cE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)'); : "${nssh:=0}"
  sc=$WB_WHT; [ "${nssh:-0}" -ge 4 ] 2>/dev/null && sc=$WB_YEL
  ntmux=$(tmux ls 2>/dev/null | wc -l | tr -d ' '); : "${ntmux:=0}"
  tnames=$(tmux ls 2>/dev/null | sed 's/:.*//' | paste -sd, - | sed 's/,/, /g')
  __wb_zrow "${WB_LBL}$(printf '%-6s' 'ssh')${WB_FR} ${sc}${nssh}${WB_FR} ${WB_DM}remote login(s) · clear ghosts → ${WB_CYN}ssh-reap"
  if [ "${ntmux:-0}" -gt 0 ]; then
    __wb_zrow "${WB_LBL}$(printf '%-6s' 'tmux')${WB_FR} ${WB_WHT}${ntmux}${WB_FR} ${WB_DM}session(s): ${tnames}"
  else
    __wb_zrow "${WB_LBL}$(printf '%-6s' 'tmux')${WB_FR} ${WB_DM}no sessions · start: ${WB_CYN}tmux new -s work"
  fi
}

# --- HERMES: consolidated to 4 tight rows (full sheet still behind `hkeys`) --
__wb_hermes() {
  __wb_hdr "HERMES"; __wb_zreset
  __wb_zrow "${WB_DM}two brothers — ${WB_B}${WB_YEL}1${WB_FR}${WB_DM}=codex, ${WB_B}${WB_YEL}2${WB_FR}${WB_DM}=local. ${WB_DM}type ${WB_CYN}m1c${WB_FR}${WB_DM}/${WB_CYN}m2s${WB_FR}${WB_DM} (the ${WB_B}${WB_YEL}#${WB_FR}${WB_DM} is the brother)"
  __wb_zrow "${WB_CYN}m#c${WB_FR} ${WB_WHT}chat${WB_DM}   ${WB_CYN}m#s${WB_FR} ${WB_WHT}status${WB_DM}   ${WB_CYN}m#g${WB_FR} ${WB_WHT}gateway${WB_DM}   ${WB_CYN}m#d${WB_FR} ${WB_WHT}dashboard${WB_DM}   ${WB_CYN}m#k${WB_FR} ${WB_WHT}kanban"
  __wb_zrow "${WB_CYN}m#up${WB_FR}${WB_DM}/${WB_CYN}down${WB_FR}${WB_DM}/${WB_CYN}re${WB_FR} ${WB_WHT}gateway on·off·restart${WB_DM}   ${WB_CYN}m#doctor${WB_FR} ${WB_WHT}diagnose${WB_DM}   ${WB_CYN}m#setup${WB_FR} ${WB_WHT}wizard"
  __wb_zrow "${WB_DM}full cheat-sheet any time: ${WB_CYN}hkeys"
}

# --- COMMANDS: deduped + curated to what you actually reach for -------------
__wb_cmdrow() { __wb_zrow "${WB_PNK}${WB_B}$(printf '%-9s' "$1")${WB_FR} ${2}"; }
__wb_commands() {
  __wb_hdr "COMMANDS"; __wb_zreset
  __wb_cmdrow "update"  "${WB_CYN}update-all${WB_FR} ${WB_D}apt·snap·node·npm·uv·gh + claude + codex${WB_FR}   ${WB_CYN}restart${WB_FR} ${WB_D}reload shell"
  __wb_cmdrow "board"   "${WB_CYN}clamboard${WB_FR} ${WB_D}reprint this${WB_FR}   ${WB_CYN}clamhelp${WB_FR} ${WB_D}every command${WB_FR}   ${WB_CYN}hkeys${WB_FR} ${WB_D}hermes keys"
  __wb_cmdrow "tmux"    "${WB_CYN}tmux${WB_FR} ${WB_D}list${WB_FR}  ${WB_CYN}tmux 2${WB_FR} ${WB_D}join${WB_FR}  ${WB_CYN}tmux new -s work${WB_FR}  ${WB_CYN}kill 1 2${WB_FR}  ${WB_D}detach ${WB_CYN}C-b d"
  __wb_cmdrow "remote"  "${WB_CYN}ssh mac${WB_FR}  ${WB_CYN}ssh xtreme${WB_FR}  ${WB_CYN}ssh-reap${WB_FR} ${WB_D}kill ghosts${WB_FR}  ${WB_CYN}lid-on${WB_FR}${WB_D}/${WB_CYN}lid-off-clamshell"
  __wb_cmdrow "secrets" "${WB_CYN}vault${WB_FR} ${WB_D}edit${WB_FR}  ${WB_CYN}secret get NAME${WB_FR}  ${WB_CYN}secret list${WB_FR}   ${WB_D}values never printed"
}

# --- FOOTER: killed (it only duplicated COMMANDS) ---------------------------
__wb_footer() { :; }

# --- VARIANT A: classic gauge + 8-cell history spark, inline gold sub-headers
WB_SPARK="▁▂▃▄▅▆▇█"; WB_SPARK_N=8
__wb_mrow() {
  local g="${3:-▁▁▁▁▁▁▁▁}"
  __wb_zrow "${WB_LBL}$(printf '%-6s' "$1")${WB_FR} $(__wb_bar "$2") ${WB_B}${WB_WHT}$(printf '%3s' "${2:-0}")%${WB_FR} ${WB_CYN}${g}${WB_FR}  $4"
}
__wb_msub() { __wb_plainrow "${WB_GOLD}$(printf '%-5s' "$1")${WB_FR}"; }

if [[ $- == *i* ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then __wb_render 0; fi
