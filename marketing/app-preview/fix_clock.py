"""Remove the patch box around the 9:41 clock on framed 1290x2796 shots.

Each row of the clock area is refilled with the background colour sampled just to
its right (between the clock and the Dynamic Island), then the clock's dark glyph
pixels are laid back on top with anti-aliasing preserved.
Usage: python3 fix_clock.py in.png out.png
"""
import sys
from PIL import Image

X0, X1, Y0, Y1 = 150, 375, 100, 240   # clock area (framed 1290x2796)
SAMPLE_X = 410                          # clear background, left of the island

src = Image.open(sys.argv[1]).convert("RGB")
out = src.copy()
px, po = src.load(), out.load()

def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]

for y in range(Y0, Y1):
    bg = px[SAMPLE_X, y]
    bl = lum(bg)
    for x in range(X0, X1):
        c = px[x, y]
        # Glyph coverage: how far this pixel is from the background toward black.
        # The patch's own edge differs from the background by only a few levels,
        # so it falls under the threshold and is painted over.
        a = (bl - lum(c)) / bl if bl else 0
        a = 0 if a < 0.12 else min(1.0, a)
        po[x, y] = tuple(round(b * (1 - a) + t * a) for b, t in zip(bg, c))

out.save(sys.argv[2])
