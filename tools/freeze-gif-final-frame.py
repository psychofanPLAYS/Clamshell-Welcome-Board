#!/usr/bin/env python3
"""Post-process the README GIF so the animation is readable.

VHS can optimize away a static final sleep in some exports. This tool keeps the
motion at a calmer 75% speed and pins the final frame for seven seconds.
"""

from __future__ import annotations

from pathlib import Path
import sys

from PIL import Image, ImageSequence


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots/welcome-board.gif")
    image = Image.open(path)
    frames = [frame.copy() for frame in ImageSequence.Iterator(image)]
    if not frames:
        raise SystemExit(f"no frames found in {path}")

    source_durations = []
    image.seek(0)
    for index in range(image.n_frames):
        image.seek(index)
        source_durations.append(max(20, int(image.info.get("duration", 40))))

    durations = [max(20, round(duration / 0.75)) for duration in source_durations]
    durations[-1] = 7000

    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"wrote {path}: frames={len(frames)} duration_ms={sum(durations)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
