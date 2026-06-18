#!/usr/bin/env bash
# Render the welcome board to a PNG screenshot for the README.
# Usage: tools/screenshot.sh [output.png]
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$HERE/docs/screenshots/welcome-board.png}"
TMPH="$(mktemp --suffix=.html)"
# render board with colour (board emits ANSI regardless of TTY), strip the dim sentinel
bash "$HERE/welcome-board.sh" 2>/dev/null | tr -d '\006' | python3 "$HERE/tools/ansi2html.py" > "$TMPH"
if command -v shot >/dev/null 2>&1; then
  shot "$TMPH" "$OUT" --width 1240 --full --wait 900
elif [ -x "$HOME/.AGENTS/bin/shot" ]; then
  "$HOME/.AGENTS/bin/shot" "$TMPH" "$OUT" --width 1240 --full --wait 900
else
  echo "no 'shot' tool; HTML is at $TMPH" >&2; exit 1
fi
rm -f "$TMPH"
echo "wrote $OUT"
