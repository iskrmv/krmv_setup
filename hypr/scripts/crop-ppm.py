#!/usr/bin/env python3
"""crop-ppm.py <in.ppm> <out.png> <x> <y> <w> <h>
Cuts a rectangle out of a binary PPM (what `grim -t ppm` writes) and saves it as PNG, with the standard library only.
screenshot.sh uses it when ImageMagick is not installed."""
import sys
import zlib
import struct


def read_ppm(path):
    with open(path, "rb") as f:
        data = f.read()
    pos = 0
    tokens = []
    while len(tokens) < 4:
        while data[pos:pos + 1].isspace():
            pos += 1
        if data[pos:pos + 1] == b"#":
            while data[pos:pos + 1] != b"\n":
                pos += 1
            continue
        start = pos
        while not data[pos:pos + 1].isspace():
            pos += 1
        tokens.append(data[start:pos])
    pos += 1  # the single whitespace after maxval
    if tokens[0] != b"P6" or int(tokens[3]) != 255:
        raise SystemExit("not an 8-bit binary PPM")
    return int(tokens[1]), int(tokens[2]), data[pos:]


def png_chunk(kind, body):
    chunk = kind + body
    return struct.pack(">I", len(body)) + chunk + struct.pack(">I", zlib.crc32(chunk) & 0xFFFFFFFF)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    x, y, w, h = (int(v) for v in sys.argv[3:7])
    width, height, pixels = read_ppm(src)
    x = max(0, min(x, width - 1))
    y = max(0, min(y, height - 1))
    w = max(1, min(w, width - x))
    h = max(1, min(h, height - y))
    stride = width * 3
    rows = []
    for row in range(y, y + h):
        start = row * stride + x * 3
        rows.append(b"\x00" + pixels[start:start + w * 3])
    raw = b"".join(rows)
    out = b"\x89PNG\r\n\x1a\n"
    out += png_chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    out += png_chunk(b"IDAT", zlib.compress(raw, 6))
    out += png_chunk(b"IEND", b"")
    with open(dst, "wb") as f:
        f.write(out)


main()
