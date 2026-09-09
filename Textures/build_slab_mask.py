"""Build the inset alpha mask for the 142 x 54 UI-unit stat slabs."""
from pathlib import Path
import struct

width, height = 512, 256
pixels = bytearray()
for y in range(height):
    py = (y + 0.5) * 54 / height
    corner = max(0, 3 - min(py, 54 - py))
    for x in range(width):
        px = (x + 0.5) * 142 / width
        inside = 2 <= py <= 52 and 2 + corner <= px <= 140 - corner
        pixels.extend((255, 255, 255, 255 if inside else 0))
header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x28)
Path(__file__).with_name('StatSlabMask.tga').write_bytes(header + pixels)
