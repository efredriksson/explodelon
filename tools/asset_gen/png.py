"""Minimal zero-dependency PNG writer.

Only what the generators in this folder need: 8-bit RGBA, one filter-none
scanline per row, no interlacing. Kept dependency-free on purpose so the
scripts run against a bare python3.
"""

import struct
import zlib


def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_rgba(path, width: int, height: int, pixel_at) -> None:
    """Write an RGBA PNG; pixel_at(x, y) returns an (r, g, b, a) tuple, 0-255."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # per-scanline filter: none
        for x in range(width):
            raw.extend(pixel_at(x, y))

    png = bytearray(b"\x89PNG\r\n\x1a\n")
    png += _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += _chunk(b"IEND", b"")

    with open(path, "wb") as handle:
        handle.write(png)
