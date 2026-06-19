#!/usr/bin/env python3
"""Redact IP-shaped values inside the Welcome Board NETWORK section.

The README screenshot is public-facing, but the board render can be captured
from a real workstation. Keep the frame width stable by replacing each visible
IP character with "x" instead of changing line length.
"""
from __future__ import annotations

import re
import sys


ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
IPV4 = re.compile(r"(?<![\d])(?:\d{1,3}\.){3}\d{1,3}(?![\d])")
IPV6 = re.compile(r"(?<![0-9A-Fa-f:])(?:[0-9A-Fa-f]{1,4}:){2,}[0-9A-Fa-f:]*")


def plain(line: str) -> str:
    return ANSI.sub("", line).replace("\006", "")


def same_width_redaction(match: re.Match[str]) -> str:
    return "x" * len(match.group(0))


def redact_network_ips(text: str) -> str:
    out: list[str] = []
    in_network = False

    for line in text.splitlines(keepends=True):
        visible = plain(line)
        if "├─ " in visible and "NETWORK" in visible:
            in_network = True
        elif in_network and "├─ " in visible:
            in_network = False

        if in_network:
            line = IPV4.sub(same_width_redaction, line)
            line = IPV6.sub(same_width_redaction, line)
        out.append(line)

    return "".join(out)


def main() -> int:
    sys.stdout.write(redact_network_ips(sys.stdin.read()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
