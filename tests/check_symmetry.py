#!/usr/bin/env python3
"""Frame-symmetry test: every framed board line must have identical DISPLAY width.
Usage: bash welcome-board.sh | python3 tests/check_symmetry.py   (or pass a file arg)"""
import sys, re, unicodedata
ANSI = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]')
def dispw(s):
    w = 0
    for ch in s:
        if ch == '\x06':            # dim sentinel = zero width
            continue
        w += 2 if unicodedata.east_asian_width(ch) in ('W', 'F') else 1
    return w
src = open(sys.argv[1], encoding='utf-8', errors='replace') if len(sys.argv) > 1 else sys.stdin
widths = {}
for raw in src.read().splitlines():
    clean = ANSI.sub('', raw)
    st = clean.lstrip(' ')
    if st[:1] and st[0] in '┌│├└':
        widths.setdefault(dispw(clean), []).append(clean)
keys = sorted(widths)
print("distinct framed-line display widths:", keys)
if len(keys) == 1:
    n = sum(len(v) for v in widths.values())
    print(f"\033[32m🟢 PERFECT SYMMETRY — all {n} framed lines are {keys[0]} cols wide\033[0m")
    sys.exit(0)
print("\033[31m🔴 MISALIGNED:\033[0m")
base = max(widths, key=lambda k: len(widths[k]))
print("   majority width =", base)
for w in keys:
    if w != base:
        for ln in widths[w]:
            print(f"   [{w}] {ln[:88]}")
sys.exit(1)
