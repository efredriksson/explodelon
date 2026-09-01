#!/usr/bin/env python3
"""Generate assets/arrow_shade.png: the fade behind the map-selection arrows.

A black strip that spans the screen vertically, opaque along its LEFT edge
and easing to clear toward the right. src/map_selection.tl draws it against
the left screen edge as-is and mirrors a second copy for the right edge.

Re-run after tweaking the constants below:

    python3 tools/asset_gen/arrow_shade.py
"""

from pathlib import Path

from png import write_rgba

WIDTH = 35  # how far the fade reaches in from the screen edge
HEIGHT = 224  # screen.HEIGHT; the strip covers the whole screen
EDGE_ALPHA = 200  # opacity (0-255) hard against the screen edge
FADE_EXPONENT = 0.8  # below 1 stays dark across the arrow, thins near the map

OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "arrow_shade.png"


def column_alpha(x: int) -> int:
    falloff = (1 - x / WIDTH) ** FADE_EXPONENT
    return max(0, min(255, round(EDGE_ALPHA * falloff)))


def shade_pixel(x: int, _y: int) -> tuple:
    return (0, 0, 0, column_alpha(x))


def main() -> None:
    write_rgba(OUTPUT, WIDTH, HEIGHT, shade_pixel)
    print(f"wrote {OUTPUT} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
