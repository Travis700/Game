"""Draws a clipped boxwood hedge as a tiling texture: assets/textures/hedge.jpg (colour) and
hedge_n.jpg (normal map from the same leaf heights). Layers of small leaves, darker the deeper
they sit, so the box it's put on reads as a trimmed hedge.
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'textures')
rnd = random.Random(5)
colour = Image.new('RGB', (SIZE, SIZE), (10, 22, 10))
height = Image.new('L', (SIZE, SIZE), 0)
cd = ImageDraw.Draw(colour)
hd = ImageDraw.Draw(height)
for layer in range(6):
    depth = layer / 5.0                       # 0 deep inside, 1 the outer leaves
    for _ in range(int(2600 + layer * 900)):
        x, y = rnd.uniform(0, SIZE), rnd.uniform(0, SIZE)
        length = rnd.uniform(10, 18)
        width = length * rnd.uniform(0.45, 0.6)
        angle = rnd.uniform(0, math.pi)
        g = int(45 + depth * 80 + rnd.uniform(-15, 15))
        fill = (int(g * rnd.uniform(0.35, 0.5)), g, int(g * rnd.uniform(0.2, 0.35)))
        h = int(40 + depth * 200)
        points = []
        for i in range(10):
            t = i / 10 * math.tau
            px, py = math.cos(t) * length * 0.5, math.sin(t) * width * 0.5
            points.append((px * math.cos(angle) - py * math.sin(angle), px * math.sin(angle) + py * math.cos(angle)))
        # Drawn at every wrapped copy, so the texture tiles.
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                if -30 < x + ox < SIZE + 30 and -30 < y + oy < SIZE + 30:
                    shape = [(x + ox + px, y + oy + py) for px, py in points]
                    cd.polygon(shape, fill=fill)
                    hd.polygon(shape, fill=h)
# Duller and patchier than fresh paint: a little grey, darker in clumps.
rgb = np.asarray(colour).astype(np.float32) / 255
grey = rgb.mean(axis=2, keepdims=True)
rgb = rgb * 0.7 + grey * 0.3
small = Image.new('L', (8, 8))
small.putdata([rnd.randint(150, 255) for _ in range(64)])
patches = np.asarray(small.resize((SIZE, SIZE), Image.BICUBIC)).astype(np.float32)[..., None] / 255
rgb = rgb * patches * 0.8
Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8)).save(os.path.join(OUT, 'hedge.jpg'), quality=92)
heights = np.asarray(height.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
gy, gx = np.gradient(heights)
n = np.dstack((-gx * 8, gy * 8, np.ones_like(heights)))
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(os.path.join(OUT, 'hedge_n.jpg'), quality=95)
print('hedge written')
