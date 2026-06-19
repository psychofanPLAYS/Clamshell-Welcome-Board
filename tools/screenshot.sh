#!/usr/bin/env bash
# Render the welcome board to a PNG screenshot for the README.
# Usage: tools/screenshot.sh [output.png]
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$HERE/docs/screenshots/welcome-board.png}"
TMPH="$(mktemp "$HERE/docs/screenshots/board-shot.XXXXXX.html")"
cleanup() { rm -f "$TMPH"; }
trap cleanup EXIT
# render board with colour (board emits ANSI regardless of TTY), strip the dim sentinel
bash "$HERE/welcome-board.sh" 2>/dev/null \
  | python3 "$HERE/tools/redact-network-ips.py" \
  | tr -d '\006' \
  | python3 "$HERE/tools/ansi2html.py" > "$TMPH"
if command -v wkhtmltoimage >/dev/null 2>&1; then
  wkhtmltoimage --width 1240 --height 1780 --log-level none "$TMPH" "$OUT"
elif command -v shot >/dev/null 2>&1; then
  shot "$TMPH" "$OUT" --width 1240 --height 1780 --wait 900
elif [ -x "$HOME/.AGENTS/bin/shot" ]; then
  "$HOME/.AGENTS/bin/shot" "$TMPH" "$OUT" --width 1240 --height 1780 --wait 900
else
  echo "no 'shot' or 'wkhtmltoimage' tool; HTML is at $TMPH" >&2
  trap - EXIT
  exit 1
fi
if python3 -c 'import PIL.Image' >/dev/null 2>&1; then
  python3 - "$OUT" <<'PY'
from pathlib import Path
import sys
from PIL import Image

path = Path(sys.argv[1])
image = Image.open(path)
image = image.convert("P", palette=Image.Palette.ADAPTIVE, colors=256)
image.save(path, optimize=True)
PY
fi
echo "wrote $OUT"
