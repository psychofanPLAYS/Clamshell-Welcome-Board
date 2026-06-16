#!/usr/bin/env bash
# ============================================================================
#  CLAMSHELL WELCOME BOARD  (v3 — compact, table-based, glanceable)
#  Prints on interactive shell start / SSH login. Sourced from ~/.bashrc.
#  FAST + failure-tolerant: local checks only, every field 2>/dev/null + fallback.
#  Only network touch: 0.8s-capped probes of mac + xtreme (never hangs).
#  Self-contained; also runs via `clamboard`. Defines clamboard / clamhelp.
#
#  Design rules (Dawid: dyslexia/ADHD, dark mode, 13" hi-dpi, glance-first):
#   - few rows, aligned columns, crisp box rules (NO fuzzy figlet headers)
#   - color legend:  cyan = copyable command · green ok · yellow check
#                    red problem · pink tip · grey label.  NO dark blue.
#   - show real status, not narration.
# ============================================================================

__wb_paint() {
  WB_R=$'\e[0m'; WB_B=$'\e[1m'; WB_D=$'\e[38;5;245m'   # "dim" = soft grey, not SGR-2 (readable on Dawid's screen)
  WB_GRN=$'\e[38;5;78m'; WB_RED=$'\e[38;5;203m'; WB_YEL=$'\e[38;5;221m'
  WB_CYN=$'\e[38;5;81m'; WB_PNK=$'\e[38;5;211m'; WB_GRY=$'\e[38;5;250m'
  WB_WHT=$'\e[38;5;253m'; WB_HDR=$'\e[38;5;117m'; WB_AC=$'\e[38;5;81m'
  WB_LBL=$'\e[1m\e[38;5;111m'   # bold cornflower — name column (CPU/GPU/…), pops, not yellow
  WB_DEV=$'\e[38;5;180m'        # warm tan — device-name column (i7-6700HQ / GTX 1060)
  WB_GOLD=$'\e[1m\e[38;5;220m'  # bold gold — major section dividers
  WB_FR=$'\e[22;24;39m'         # fg-only reset: clears bold/underline/colour but KEEPS the row's zebra bg
  WB_DM=$'\006'                 # sentinel for "adaptive dim grey" — __wb_zrow swaps it per stripe so it stays readable on both shades
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
    printf '  %s╞══ %s %s╡%s\n' \
      "$WB_GOLD" "$lbl" "$(__wb_repeat '═' "$rule")" "$WB_R"
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
__wb_greeting() {
  local h; h=$((10#$(date +%H))); local -a p
  if   [ "$h" -ge 5 ] && [ "$h" -lt 12 ]; then
    p=("Good morning, Dawid." "Morning, Dawid — CLAMSHELL held all night." "Good morning, Dawid. Standing by.")
  elif [ "$h" -ge 12 ] && [ "$h" -lt 17 ]; then
    p=("Good afternoon, Dawid." "Afternoon, Dawid. At your command." "Welcome back, Dawid.")
  elif [ "$h" -ge 17 ] && [ "$h" -lt 22 ]; then
    p=("Good evening, Dawid." "Evening, Dawid. Ready when you are." "Good evening, Dawid. Standing by.")
  else
    p=("Working late, Dawid." "Late night, Dawid — standing by." "Still here, Dawid.")
  fi
  printf '%s' "${p[RANDOM % ${#p[@]}]}"
}

# ---- BANNER (brand mark so SSH login ≠ macOS login) ------------------------
__wb_banner() {
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
  __wb_plainrow ""
  __wb_plainrow "${WB_HDR}$(__wb_greeting)${WB_R} ${WB_DM}· up $(uptime -p 2>/dev/null | sed 's/^up //;s/ hours\?/h/;s/ minutes\?/m/;s/ days\?/d/;s/,//g' || echo '?') · $(date '+%a %d %b · %H:%M')"
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
# one aligned, zebra-striped panel row:  $1 name  $2 pct  $3 device+detail (WB_FR resets)
__wb_mrow() {
  local c
  c="${WB_LBL}$(printf '%-5s' "$1")${WB_FR}$(__wb_bar "$2") ${WB_B}${WB_WHT}$(printf '%3s' "${2:-?}")%${WB_FR}   $3"
  __wb_zrow "$c"
}
__wb_center() {
  local w="$1" text="$2" pad right
  pad=$(( (w - ${#text}) / 2 )); ((pad < 0)) && pad=0
  right=$(( w - ${#text} - pad )); ((right < 0)) && right=0
  printf '%*s%s%*s' "$pad" '' "$text" "$right" ''
}
__wb_loadrow() {
  local pct="$1" l1="$2" l5="$3" l15="$4" up="$5" c labels
  c="${WB_LBL}$(printf '%-5s' 'LOAD')${WB_FR}$(__wb_bar "$pct") ${WB_B}${WB_WHT}$(printf '%3s' "${pct:-0}")%${WB_FR}   ${WB_WHT}$(printf '%5s %5s %5s' "${l1:-?}" "${l5:-?}" "${l15:-?}")${WB_DM} · up ${up:-?}"
  labels="${WB_D}$(printf '%21s' '')(${WB_WHT}1m${WB_D}) · (${WB_WHT}5m${WB_D}) · (${WB_WHT}15m${WB_D})${WB_R}"
  __wb_zrow "$c"
  __wb_plainrow "$labels"
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

# ---- MACHINE (full geek panel: aligned gauges + every pollable stat) --------
__wb_machine() {
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
  __wb_mrow "CPU"  "${cbusy:-0}" "${WB_DEV}${cbrand}  ${WB_DM}${cores}t · ${WB_WHT}${cfcur:-?}${WB_DM}/${cfmax:-?} GHz · ${WB_FR}$(__wb_tcol "$ctemp")${ctemp:-?}°C"
  __wb_mrow "GPU"  "${gutil:-0}" "${WB_DEV}${gname}  ${WB_DM}${gp:-?} · ${WB_WHT}${cgr:-?}${WB_DM}/${cgrmax:-?} MHz · ${WB_FR}$(__wb_tcol "$gtemp")${gtemp:-?}°C ${WB_DM}· ${WB_WHT}${gpw:-?}${WB_DM} W"
  __wb_mrow "VRAM" "${vpct}"     "$(__wb_grad "$vpct")${vu:-?}${WB_DM}/${vt:-?} MB · mem clk ${WB_WHT}${cm:-?}${WB_DM}/${cmmax:-?} MHz"
  __wb_mrow "RAM"  "${rpct}"     "$(__wb_grad "$rpct")${ruGB}${WB_DM}/${rtGB} GB"
  __wb_mrow "SWAP" "${spct}"     "$(__wb_grad "$spct")${suGB}${WB_DM}/${stGB} GB"
  __wb_mrow "DISK" "${dp:-0}"    "$(__wb_grad "${dp:-0}")${du:-?}${WB_DM}/${dt:-?} GB · root fs"
  __wb_loadrow "${lpct:-0}" "${l1:-?}" "${l5:-?}" "${l15:-?}" "${up:-?}"
}

# ---- NETWORK (tailscale topology + xtreme serving) -------------------------
__wb_network() {
  __wb_hdr "NETWORK"
  local ts self mac_ip mac_st xt_ip xt_st
  ts=$(timeout 1 tailscale status 2>/dev/null)
  self=$(echo "$ts" | awk '/clamshell/{print $1; exit}'); : "${self:=100.118.201.91}"
  mac_ip=$(echo "$ts" | awk '/m2-mac-air/{print $1; exit}'); : "${mac_ip:=100.117.254.106}"
  xt_ip=$(echo "$ts"  | awk '/xtreme/{print $1; exit}');     : "${xt_ip:=100.103.31.3}"
  echo "$ts" | grep -q 'm2-mac-air.*active' && mac_st="${WB_GRN}● online${WB_FR}" || mac_st="${WB_DM}○ offline"
  # xtreme: is the LM endpoint actually reachable+serving? (single 0.8s probe)
  if timeout 0.8 bash -c "exec 3<>/dev/tcp/${xt_ip}/6911" 2>/dev/null; then
    xt_st="${WB_GRN}● connected · ${WB_DM}serving ${WB_GRN}:6911${WB_FR}"
  elif echo "$ts" | grep -q 'xtreme.*active'; then
    xt_st="${WB_YEL}● up on tailscale · :6911 not serving${WB_FR}"
  else
    xt_st="${WB_RED}○ unreachable${WB_FR}"
  fi
  local nssh sc; nssh=$(who 2>/dev/null | grep -cE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)')
  sc=$WB_WHT; [ "${nssh:-0}" -ge 4 ] 2>/dev/null && sc=$WB_YEL
  __wb_zreset
  __wb_zrow "${WB_LBL}$(printf '%-10s' 'clamshell')${WB_FR}${WB_WHT}$(printf '%-16s' "$self")${WB_DM}(here)"
  __wb_zrow "${WB_LBL}$(printf '%-10s' 'm2 mac')${WB_FR}${WB_WHT}$(printf '%-16s' "$mac_ip")${WB_FR}${mac_st}"
  __wb_zrow "${WB_LBL}$(printf '%-10s' 'xtreme')${WB_FR}${WB_WHT}$(printf '%-16s' "$xt_ip")${WB_FR}${xt_st}"
  __wb_zrow "${WB_LBL}$(printf '%-10s' 'ssh now')${WB_FR}${sc}${nssh:-0} active${WB_FR} ${WB_DM}from m2 mac/tailscale · ghosts? → ${WB_CYN}ssh-reap"
}

# ---- LOCKS (security at a glance) ------------------------------------------
__wb_portname() {
  case "$1" in
    22) echo SSH;; 53) echo DNS;; 139|445) echo Samba;;
    631) echo printing;; 5432) echo Postgres;; 6333) echo "vector-DB";;
    6900) echo shim;; 6901) echo embedder;; 6902) echo reranker;;
    6903) echo memory;; 6904|6905|6907) echo "shim proxy";; 6911) echo "xtreme-proxy";;
    6912) echo "Hermes API";; 6915) echo "Hermes dash";; 6916) echo "Hermes aux";;
    37360) echo media;; *) echo "port $1";;
  esac
}
__wb_group() {  # $1 ports, $2 name-color
  local -A m=(); local -a order=(); local p n
  for p in $(echo "$1" | tr ' ' '\n' | sort -nu); do
    n=$(__wb_portname "$p")
    if [ -z "${m[$n]}" ]; then m[$n]="$p"; order+=("$n"); else m[$n]="${m[$n]}/$p"; fi
  done
  local out="" k; for k in "${order[@]}"; do out="$out${WB_DM}, ${2}${k}"; done
  printf '%s' "${out#${WB_DM}, }"
}
__wb_locks() {
  __wb_hdr "LOCKS"
  local expected=" 22 139 445 6900 6904 6905 6907 6915 37360 "
  local lan="" alert="" rygel_ports="" line port addr proc; declare -A seen
  while read -r line; do
    read -r _ _ _ addr _ proc <<<"$line"
    port="${addr##*:}"
    addr="${addr%:*}"
    addr="${addr%\%*}"
    addr="${addr//[\[\]]/}"
    case "$addr" in 127.*|::1|100.*|fd7a:*|fe80:*) continue;; esac   # private/vpn/link → not a LAN door
    [ -n "${seen[$port]}" ] && continue; seen[$port]=1
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
    __wb_zrow "${WB_RED}${WB_B}⚠ Unrecognized door:${WB_FR} ${WB_RED}$(__wb_group "$alert" "$WB_RED")${WB_DM} — investigate"
  else
    __wb_zrow "${WB_GRN}${WB_B}✓ Locked.${WB_FR} ${WB_DM}LAN doors ok: ${WB_WHT}$(__wb_group "$lan" "$WB_WHT")"
    __wb_zrow "${WB_DM}rest is loopback (this PC) or Tailscale VPN only — no strangers."
  fi
  if [ -n "$rygel_ports" ]; then
    __wb_zrow "${WB_DM}known dynamic service: ${WB_WHT}Rygel media server${WB_DM} on ${WB_WHT}${rygel_ports# }"
  fi
}

# ---- SERVICES (is anything broken?) ----------------------------------------
__wb_services() {
  __wb_hdr "SERVICES"
  local -a svc=("dash:6915" "API:6912" "memory:6903" "embedder:6901" "reranker:6902" "vector-DB:6333" "shim:6900")
  local up="" down="" e n p
  for e in "${svc[@]}"; do n="${e%:*}"; p="${e##*:}"
    if echo "$WB_LISTEN" | grep -q ":$p "; then up="$up, $n"; else down="$down, $n"; fi; done
  __wb_zreset
  if [ -z "$down" ]; then __wb_zrow "${WB_GRN}${WB_B}✓ All up.${WB_FR} ${WB_DM}${up#,}"
  else __wb_zrow "${WB_RED}${WB_B}⚠ Down:${WB_FR}${WB_RED}${down#,}${WB_FR}   ${WB_DM}up:${up#,}"; fi
}

# ---- COMMANDS (cyan = copyable). tmux reminders kept. ----------------------
__wb_cmdrow() {
  local label="$1" body="$2"
  __wb_zrow "${WB_PNK}${WB_B}$(printf '%-8s' "$label")${WB_FR} ${body}"
}
__wb_commands() {
  __wb_hdr "COMMANDS"
  __wb_zreset
  __wb_cmdrow "UPDATE" "${WB_CYN}update-all${WB_FR} ${WB_DM}apt/brew/snap/node/npm/uv/pipx/gh + claude/codex"
  __wb_cmdrow ""       "${WB_DM}skips hermes/openclaw"
  __wb_cmdrow "HELP"   "${WB_CYN}clamhelp${WB_FR} ${WB_D}full reference${WB_FR}   ${WB_CYN}restart${WB_FR} ${WB_D}reload shell${WB_FR}   ${WB_CYN}ssh mac${WB_FR}"
  __wb_cmdrow "INSTALL" "${WB_D}codex:${WB_FR} ${WB_CYN}npm install -g @openai/codex@latest${WB_FR}"
  __wb_cmdrow ""       "${WB_D}claude:${WB_FR} ${WB_CYN}npm install -g @anthropic-ai/claude-code@latest${WB_FR}"
  __wb_cmdrow "TMUX"   "${WB_D}new:${WB_FR} ${WB_CYN}tmux new -s work${WB_FR}   ${WB_D}join:${WB_FR} ${WB_CYN}tmux attach -t work${WB_FR}"
  __wb_cmdrow ""       "${WB_D}detach:${WB_FR} ${WB_CYN}Ctrl-b d${WB_FR}   ${WB_D}list:${WB_FR} ${WB_CYN}tmux ls${WB_FR}"
  __wb_cmdrow ""       "${WB_D}example:${WB_FR} ${WB_CYN}tmux new -s example${WB_FR}   ${WB_D}delete:${WB_FR} ${WB_CYN}tmux kill-session -t example${WB_FR}"
  __wb_cmdrow "LID"    "${WB_CYN}lid-status${WB_FR}   ${WB_CYN}lid-on-clamshell${WB_FR} ${WB_D}(stay awake)${WB_FR}   ${WB_CYN}lid-off-clamshell${WB_FR}"
  __wb_cmdrow "SSH"    "${WB_CYN}ssh-sessions${WB_FR} ${WB_D}(who's on)${WB_FR}   ${WB_CYN}ssh-reap${WB_FR} ${WB_D}(kill ghost sessions)"
  __wb_cmdrow ""       "${WB_DM}keeps this one + tmux"
  __wb_cmdrow "SECRET" "${WB_CYN}vault${WB_FR} ${WB_D}edit+re-encrypt${WB_FR}   ${WB_CYN}secret get NAME${WB_FR}   ${WB_CYN}secret list${WB_FR}"
  [ "${WB_FRAME_ON:-0}" = 1 ] || echo
}

# ---- HERMES shortcut cheat-sheet (aphasia aid) -----------------------------
#  ONE template per command:   m # c   ← the # is the brother number (1 or 2).
#  Swap # for 1 or 2 and type it with NO spaces:  m # c -> m1c / m2c.
#  The # shows in bold-yellow with thin "half" spaces so the token reads clean.
#  `hkeys` is just the command that PRINTS this box. It also auto-shows at
#  every login. Reprint any time with:  hkeys   (or the alias: keys).
#  The box is closed on both sides and zebra-striped for fast scanning.
__hk_padline() {
  local content="$1" vis pad bg dim
  if ((_HK_ZEB%2==0)); then bg=$'\e[48;5;236m'; dim=$'\e[38;5;109m'
  else                       bg=$'\e[48;5;233m'; dim=$'\e[38;5;116m'; fi
  _HK_ZEB=$(( _HK_ZEB+1 ))
  content=${content//$WB_DM/$dim}
  content=${content//$WB_R/$WB_FR}
  vis=$(__wb_vis "$content")
  pad=$(( HK_W - vis )); ((pad<0)) && pad=0
  printf ' %b│%b%s%b%*s%b│%b\n' "$WB_AC" "$bg" "$content" "$WB_FR" "$pad" '' "$WB_AC" "$WB_R"
}
__hk_say() { __hk_padline "  $1"; }
__hk_gap() { __hk_padline ""; }
__hk_head(){ __hk_padline "  ${WB_HDR}${WB_B}$1${WB_FR}"; }
__hk_cmd() {   # $1 suffix (letter or word)   $2 description
  local suf="$1" desc="$2" tok vis pad HS
  local hl="${WB_B}${WB_YEL}"
  printf -v HS '\u2009'                     # thin "half" space (U+2009), guaranteed
  tok="${WB_CYN}m${WB_R}${HS}${hl}#${WB_R}${HS}${WB_CYN}${suf}${WB_R}"
  vis=$(( 4 + ${#suf} ))                          # m + ‹half› + # + ‹half› + suffix
  pad=$(( 15 - vis )); (( pad<1 )) && pad=1
  __hk_padline "   ${tok}$(printf '%*s' "$pad" '')${WB_D}${desc}${WB_R}"
}
__hkeys_frame_cmd() {
  local suf="$1" desc="$2" tok vis pad
  tok="${WB_CYN}m${WB_B}${WB_YEL}#${WB_FR}${WB_CYN}${suf}${WB_FR}"
  vis=$(( 2 + ${#suf} ))
  pad=$(( 13 - vis )); ((pad < 1)) && pad=1
  __wb_zrow "   ${tok}$(printf '%*s' "$pad" '')${WB_WHT}${desc}"
}
__hkeys_frame_head() {
  __wb_zrow " ${WB_HDR}${WB_B}$1${WB_FR}"
}
__hkeys_frame_gap() {
  __wb_plainrow ""
}
__hkeys_frame() {
  __wb_hdr "HERMES SHORTCUTS"
  __wb_zreset
  __wb_zrow " ${WB_B}${WB_YEL}#${WB_FR} ${WB_WHT}= brother number${WB_DM}; use ${WB_B}${WB_YEL}1${WB_FR}${WB_DM}=master-1-codex, ${WB_B}${WB_YEL}2${WB_FR}${WB_DM}=master-2-local"
  __wb_zrow " ${WB_DM}typed for real: ${WB_CYN}m1c${WB_FR}${WB_DM} or ${WB_CYN}m2c${WB_FR}${WB_DM}; base works too: ${WB_CYN}m1 status${WB_FR}"
  __hkeys_frame_gap
  __hkeys_frame_head "EVERYDAY"
  __hkeys_frame_cmd c "chat with the brother"
  __hkeys_frame_cmd s "status"
  __hkeys_frame_cmd g "gateway  (add: start / stop / restart / status)"
  __hkeys_frame_cmd d "dashboard"
  __hkeys_frame_cmd l "logs"
  __hkeys_frame_cmd k "kanban  (shared task board)"
  __hkeys_frame_gap
  __hkeys_frame_head "TURN ON / OFF"
  __hkeys_frame_cmd up   "gateway start  (turn this brother on)"
  __hkeys_frame_cmd down "gateway stop"
  __hkeys_frame_cmd re   "gateway restart"
  __hkeys_frame_gap
  __hkeys_frame_head "SET-UP & FIX-IT"
  __hkeys_frame_cmd setup  "interactive setup wizard"
  __hkeys_frame_cmd doctor "check config + dependencies  (try this first)"
  __hkeys_frame_cmd login  "sign in to a model provider"
  __hkeys_frame_cmd model  "pick default model / provider"
  __hkeys_frame_cmd mem    "open the memory store"
  __hkeys_frame_gap
  __wb_zrow " ${WB_DM}this section is called ${WB_CYN}hkeys${WB_FR}${WB_DM}; type ${WB_CYN}hkeys${WB_FR}${WB_DM} or ${WB_CYN}keys${WB_FR}${WB_DM} to show it again"
}
hkeys() {
  __wb_paint
  if [ "${WB_FRAME_ON:-0}" = 1 ]; then
    __hkeys_frame
    return
  fi
  local HK_W=70 hl="${WB_B}${WB_YEL}" title=" HERMES PROFILE SHORTCUTS " title_len=26 _HK_ZEB=0
  printf '\n %b┌─%b%s%b' "$WB_AC" "${WB_HDR}${WB_B}" "$title" "$WB_AC"
  printf '%s' "$(__wb_repeat '─' $(( HK_W - title_len - 1 )))"; printf '┐%b\n' "$WB_R"
  __hk_say "${WB_GRY}${WB_D}# = which brother you talk to — swap it for a number:${WB_R}"
  __hk_say "  ${hl}1${WB_R} ${WB_GRY}→ master-1-codex  ${WB_D}(CODDY · architect)${WB_R}"
  __hk_say "  ${hl}2${WB_R} ${WB_GRY}→ master-2-local  ${WB_D}(local 4090 worker)${WB_R}"
  __hk_say "${WB_D}so  ${WB_CYN}m${WB_R}${hl}#${WB_R}${WB_CYN}c${WB_R}${WB_D}  typed for real is  ${WB_CYN}m1c${WB_R}${WB_D}  or  ${WB_CYN}m2c${WB_R}"
  __hk_gap
  __hk_head "EVERYDAY"
  __hk_cmd c "chat with the brother"
  __hk_cmd s "status"
  __hk_cmd g "gateway   (add: start / stop / restart / status)"
  __hk_cmd d "dashboard"
  __hk_cmd l "logs"
  __hk_cmd k "kanban  (shared task board)"
  __hk_gap
  __hk_head "TURN ON / OFF"
  __hk_cmd up   "gateway start    (turn this brother on)"
  __hk_cmd down "gateway stop"
  __hk_cmd re   "gateway restart  (kick it if stuck)"
  __hk_gap
  __hk_head "SET-UP & FIX-IT  ${WB_GRY}${WB_D}— first wiring, or when broken${WB_R}"
  __hk_cmd setup  "interactive setup wizard"
  __hk_cmd doctor "check config + dependencies  (try this first)"
  __hk_cmd login  "sign in to a model provider"
  __hk_cmd model  "pick the default model / provider"
  __hk_cmd mem    "open the memory store"
  __hk_gap
  __hk_say "${WB_GRY}${WB_D}m1 / m2 alone work too — add ANY word:  ${WB_CYN}m1 status${WB_R}"
  __hk_say "${WB_GRY}${WB_D}this box is called  ${WB_CYN}hkeys${WB_R}${WB_GRY}${WB_D} — type it to show it again (or ${WB_CYN}keys${WB_R}${WB_GRY}${WB_D})${WB_R}"
  printf ' %b└' "$WB_AC"; printf '%s' "$(__wb_repeat '─' "$HK_W")"; printf '┘%b\n' "$WB_R"
}

# ============================ render =========================================
__wb_top_space() {
  printf '\n\n'
}

__wb_bottom_space() {
  printf '\n\n'
}

__wb_render() {
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
  __wb_machine
  __wb_network
  __wb_locks
  __wb_services
  __wb_commands
  hkeys
  __wb_frame_bottom
  WB_FRAME_ON=0
}

# ---- user commands ---------------------------------------------------------
clamboard() { __wb_render; __wb_bottom_space; }
clamhelp() {
  __wb_paint
  __wb_hdr "FULL REFERENCE"
  local -a sec=(
    "UPDATE / INSTALL" 'update-all|apt·brew·snap·node·npm·uv·pipx·gh + claude + codex (skips hermes/openclaw)'
    'claude update|update Claude Code' 'clamboard|reprint the welcome board'
    'npm install -g @openai/codex@latest|install / upgrade Codex CLI'
    'npm install -g @anthropic-ai/claude-code@latest|install / upgrade Claude Code CLI'
    "TMUX  (it runs your shell in a named session that survives disconnect)"
    'tmux new -s work|start a session called work' 'tmux attach -t work|re-join it after reconnect'
    'tmux ls|list sessions' 'Ctrl-b then d|detach (leave it running in background)'
    'tmux new -s example|create a session named example' 'tmux attach -t example|join session named example'
    'tmux kill-session -t example|delete session named example'
    "HERMES PROFILES  (# = brother: 1=master-1-codex, 2=master-2-local — swap # for 1 or 2)"
    'm1 / m2|base — add ANY word, e.g.  m1 status   m2 setup'
    'm#c|chat' 'm#s|status' 'm#g|gateway  (add: start / stop / restart / status)'
    'm#d|dashboard' 'm#l|logs' 'm#k|kanban (shared task board)'
    'm#up / m#down / m#re|gateway start / stop / restart'
    "HERMES SET-UP & FIX-IT  (first wiring a brother up, or when it's broken)"
    'm#setup|interactive setup wizard' 'm#doctor|check config + dependencies (try first)'
    'm#login|sign in to a model provider' 'm#model|pick the default model'
    'm#mem|open the memory store'
    'qwenmodel|pin local Qwen id (default qwen3.6-35b); qwenmodel <id> to retarget'
    'hkeys|reprint the Hermes shortcut cheat-sheet box (keys / mkeys too)'
    "LAPTOP LID" 'lid-status|show current lid behavior' 'lid-on-clamshell|KEEP awake when lid closes'
    'lid-off-clamshell|restore default (sleep on lid close)'
    "REMOTE" 'ssh mac|open the M2 Mac' 'ssh xtreme|open the 4090 box'
  )
  local e c d
  for e in "${sec[@]}"; do
    if [[ "$e" != *"|"* ]]; then printf '\n  %s▌%s %s%s%s\n' "$WB_AC" "$WB_R" "$WB_HDR$WB_B" "$e" "$WB_R"
    else c="${e%%|*}"; d="${e##*|}"; printf '   %s%-20s%s%s%s%s\n' "$WB_CYN" "$c" "$WB_R" "$WB_D" "$d" "$WB_R"; fi
  done; echo
}

# ---- auto-render: interactive shells, or when executed directly ------------
if [[ $- == *i* ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then __wb_render; fi
