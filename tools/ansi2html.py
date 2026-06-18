#!/usr/bin/env python3
"""Faithful ANSI (256-colour + bold) -> standalone dark HTML, for screenshots.
Reads ANSI on stdin (or a file arg), writes HTML on stdout.
Supports: \\e[38;5;Nm / \\e[48;5;Nm (256 fg/bg), \\e[1m bold, \\e[0m reset,
and partial resets like \\e[22;24;39m. Designed for the Welcome Board showpiece."""
import sys, re, html

BG = "#0c0c10"          # near-black, low-glare (matches Dawid's dark theme)
FG = "#cfd2d6"          # soft off-white default text


def xterm256(n: int) -> str:
    if n < 16:
        base = [(0, 0, 0), (205, 0, 0), (0, 205, 0), (205, 205, 0), (0, 0, 238),
                (205, 0, 205), (0, 205, 205), (229, 229, 229), (127, 127, 127),
                (255, 0, 0), (0, 255, 0), (255, 255, 0), (92, 92, 255),
                (255, 0, 255), (0, 255, 255), (255, 255, 255)]
        r, g, b = base[n]
    elif n < 232:
        n -= 16
        steps = [0, 95, 135, 175, 215, 255]
        r, g, b = steps[n // 36 % 6], steps[n // 6 % 6], steps[n % 6]
    else:
        v = 8 + (n - 232) * 10
        r = g = b = v
    return f"#{r:02x}{g:02x}{b:02x}"


TOK = re.compile(r"\x1b\[([0-9;]*)m")


def convert(text: str) -> str:
    out, fg, bg, bold = [], None, None, False
    pos = 0
    open_span = False

    def close():
        nonlocal open_span
        if open_span:
            out.append("</span>")
            open_span = False

    def opn():
        nonlocal open_span
        styles = []
        styles.append(f"color:{fg or FG}")
        if bg:
            styles.append(f"background:{bg}")
        if bold:
            styles.append("font-weight:700")
        out.append(f'<span style="{";".join(styles)}">')
        open_span = True

    for m in TOK.finditer(text):
        seg = text[pos:m.start()]
        if seg:
            if not open_span:
                opn()
            out.append(html.escape(seg))
        pos = m.end()
        codes = [c for c in m.group(1).split(";") if c != ""] or ["0"]
        i = 0
        while i < len(codes):
            c = int(codes[i])
            if c == 0:
                fg = bg = None; bold = False
            elif c == 1:
                bold = True
            elif c in (22, 24):
                bold = False
            elif c == 39:
                fg = None
            elif c == 49:
                bg = None
            elif c == 38 and i + 2 < len(codes) and codes[i + 1] == "5":
                fg = xterm256(int(codes[i + 2])); i += 2
            elif c == 48 and i + 2 < len(codes) and codes[i + 1] == "5":
                bg = xterm256(int(codes[i + 2])); i += 2
            i += 1
        close()
    tail = text[pos:]
    if tail:
        if not open_span:
            opn()
        out.append(html.escape(tail))
    close()
    body = "".join(out)
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{{margin:0;background:{BG};}}
  pre{{margin:0;padding:26px 30px;background:{BG};color:{FG};
    font-family:'DejaVu Sans Mono','JetBrains Mono','Cascadia Code',monospace;
    font-size:15px;line-height:1.32;letter-spacing:0;
    -webkit-font-smoothing:antialiased;font-variant-ligatures:none;}}
</style></head><body><pre>{body}</pre></body></html>"""


if __name__ == "__main__":
    src = open(sys.argv[1], encoding="utf-8", errors="replace") if len(sys.argv) > 1 else sys.stdin
    sys.stdout.write(convert(src.read()))
