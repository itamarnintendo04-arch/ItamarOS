#!/usr/bin/env python3
"""Generate 36 transparent Plymouth ring-segment PNGs using only stdlib.

A Plymouth callback lights up the ring based on actual (estimated) boot progress.
These are image assets only; no filesystem changes outside the destination directory.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

CANVAS = 320
COUNT = 36

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(
        ">I", zlib.crc32(tag + data) & 0xffffffff)

def write_segment(path, index):
    angle = -math.pi / 2 + 2 * math.pi * index / COUNT
    cx = CANVAS / 2 + 116 * math.cos(angle)
    cy = CANVAS / 2 + 116 * math.sin(angle)
    blend = index / (COUNT - 1)
    rgb = (int(68 + 96 * blend), int(168 + 36 * blend), 255)
    pixels = bytearray(CANVAS * CANVAS * 4)
    for y in range(max(0, int(cy) - 10), min(CANVAS, int(cy) + 12)):
        for x in range(max(0, int(cx) - 10), min(CANVAS, int(cx) + 12)):
            d = math.hypot(x + .5 - cx, y + .5 - cy)
            alpha = int(max(0, min(1, 9.2 - d)) * 255)
            if alpha:
                offset = (y * CANVAS + x) * 4
                pixels[offset:offset + 4] = bytes((*rgb, alpha))
    rows = b"".join(b"\x00" + pixels[y * CANVAS * 4:(y + 1) * CANVAS * 4]
                    for y in range(CANVAS))
    ihdr = struct.pack(">IIBBBBB", CANVAS, CANVAS, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" +
                     chunk(b"IHDR", ihdr) +
                     chunk(b"IDAT", zlib.compress(rows, 9)) +
                     chunk(b"IEND", b""))

def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: generate_boot_ring.py <theme-directory>")
    destination = Path(sys.argv[1])
    destination.mkdir(parents=True, exist_ok=True)
    for i in range(COUNT):
        write_segment(destination / f"segment-{i}.png", i)
    print(f"Generated {COUNT} original ring progress assets in {destination}")

if __name__ == "__main__":
    main()
