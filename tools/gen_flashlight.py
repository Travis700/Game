"""Paints the flashlight's beam pattern (a light cookie): python3 tools/gen_flashlight.py

assets/textures/flashlight_cookie.png: what a cheap reflector torch throws on a wall: a hot
centre, a darker ring round it, a soft bright ring, then the dim spill fading out, with a
little unevenness from the dented reflector.
"""
import math, os, random
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'textures', 'flashlight_cookie.png')
SIZE = 256
random.seed(3)
img = Image.new('L', (SIZE, SIZE))
px = img.load()
c = (SIZE - 1) / 2
# A few lumps round the rim, as if the reflector were dented.
dents = [(random.uniform(0, math.tau), random.uniform(0.02, 0.06)) for _ in range(5)]
for y in range(SIZE):
    for x in range(SIZE):
        dx, dy = (x - c) / c, (y - c) / c
        r = math.hypot(dx, dy)
        a = math.atan2(dy, dx)
        r *= 1.0 + sum(d * math.cos(3 * (a - phase)) for phase, d in dents) * 0.25
        hot = math.exp(-(r / 0.16) ** 2) * 0.35
        core = 0.62 * (1 - min(r / 0.42, 1) ** 2.2)
        ring = 0.28 * math.exp(-((r - 0.40) / 0.05) ** 2)
        dip = -0.1 * math.exp(-((r - 0.27) / 0.05) ** 2)
        spill = 0.22 * max(0.0, 1 - r) ** 1.6
        v = hot + core + ring + dip + spill
        # Nothing at all at the edge of the square, so the spot's cone never shows a hard edge.
        v *= max(0.0, min(1.0, (1.0 - r) / 0.12))
        px[x, y] = max(0, min(255, int(v * 255)))
img = img.filter(ImageFilter.GaussianBlur(1.2))
img.convert('RGB').save(OUT)
print(OUT)
