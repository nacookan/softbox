#!/usr/bin/env python3
"""Generate a simple warm-light radial gradient app icon for Softbox."""
import struct
import zlib
import math
import os

def make_chunk(chunk_type, data):
    crc = zlib.crc32(chunk_type + data) & 0xffffffff
    return struct.pack('>I', len(data)) + chunk_type + data + struct.pack('>I', crc)

def create_icon(size):
    cx = cy = (size - 1) / 2.0
    max_r = size / 2.0

    signature = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)
    ihdr = make_chunk(b'IHDR', ihdr_data)

    raw = bytearray()
    for y in range(size):
        raw.append(0)  # filter: None
        for x in range(size):
            dx = x - cx
            dy = y - cy
            d = math.sqrt(dx * dx + dy * dy) / max_r
            t = min(d, 1.0)

            # Center: bright white. Edge: warm amber (255, 150, 60)
            r = 255
            g = int(round(255 - t * 105))   # 255 -> 150
            b = int(round(255 - t * 195))   # 255 -> 60

            raw += bytes([r, g, b])

    compressed = zlib.compress(bytes(raw), 6)
    idat = make_chunk(b'IDAT', compressed)
    iend = make_chunk(b'IEND', b'')

    return signature + ihdr + idat + iend

out_dir = 'Softbox/Assets.xcassets/AppIcon.appiconset'
os.makedirs(out_dir, exist_ok=True)

sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes:
    path = os.path.join(out_dir, f'icon_{s}.png')
    with open(path, 'wb') as f:
        f.write(create_icon(s))
    print(f'Created {path}')
