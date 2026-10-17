"""Draws the wear the school has picked up over the years, as decal textures in
assets/textures/wear/: black heel scuffs, spill stains and mop marks on the floors, brown
water rings on the ceiling tiles, grime along the bottom of the walls, and a loose sheet of
notebook paper.
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'textures', 'wear')
os.makedirs(OUT, exist_ok=True)
rnd = random.Random(11)


def alpha_noise(size, scale, seed):
    r = random.Random(seed)
    small = Image.new('L', (max(size[0] // scale, 2), max(size[1] // scale, 2)))
    small.putdata([r.randint(0, 255) for _ in range(small.size[0] * small.size[1])])
    return small.resize(size, Image.BICUBIC)


def save(name, colour, alpha):
    image = Image.new('RGBA', alpha.size, colour)
    image.putalpha(alpha)
    image.save(os.path.join(OUT, name + '.png'))


# Heel scuffs: short dark curved strokes, smeared, in a loose cluster.
for n in range(3):
    size = 512
    alpha = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(alpha)
    for _ in range(rnd.randint(7, 14)):
        cx, cy = rnd.uniform(90, 420), rnd.uniform(90, 420)
        length, angle = rnd.uniform(20, 90), rnd.uniform(0, math.pi)
        bend = rnd.uniform(-0.6, 0.6)
        points = []
        for i in range(12):
            t = i / 11 - 0.5
            a = angle + bend * t
            points.append((cx + math.cos(a) * length * t, cy + math.sin(a) * length * t + bend * 30 * t * t))
        d.line(points, fill=rnd.randint(120, 230), width=rnd.randint(2, 6))
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.6))
    # Fade out towards the edges of the square so nothing is cut off.
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).ellipse((40, 40, size - 40, size - 40), fill=255)
    alpha = ImageChops.multiply(alpha, mask.filter(ImageFilter.GaussianBlur(40)))
    save('scuff%d' % n, (18, 16, 15), alpha)

# Spill and mop stains: soft irregular blotches with a slightly darker dried edge.
for n in range(3):
    size = 512
    blob = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(blob)
    for _ in range(rnd.randint(4, 8)):
        r = rnd.uniform(40, 120)
        cx, cy = 256 + rnd.uniform(-90, 90), 256 + rnd.uniform(-90, 90)
        d.ellipse((cx - r, cy - r * rnd.uniform(0.6, 1.0), cx + r, cy + r * rnd.uniform(0.6, 1.0)), fill=255)
    blob = blob.filter(ImageFilter.GaussianBlur(14))
    blob = ImageChops.multiply(blob, alpha_noise((size, size), 24, n).point(lambda v: 120 + v // 2))
    shape = blob.point(lambda v: 255 if v > 110 else 0).filter(ImageFilter.GaussianBlur(3))
    edge = ImageChops.subtract(shape, shape.filter(ImageFilter.MinFilter(9))).filter(ImageFilter.GaussianBlur(2))
    patchy = alpha_noise((size, size), 10, 20 + n).point(lambda v: 60 + v * 0.75)
    body = ImageChops.multiply(shape, patchy).point(lambda v: v * 0.4)
    alpha = ImageChops.add(body, edge.point(lambda v: v * 0.35)).filter(ImageFilter.GaussianBlur(5))
    save('stain%d' % n, (58, 46, 30), alpha)

# Water damage on a ceiling tile: a ring of rust-brown with a paler middle.
for n in range(2):
    size = 512
    shape = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(shape)
    for _ in range(5):
        r = rnd.uniform(90, 170)
        cx, cy = 256 + rnd.uniform(-50, 50), 256 + rnd.uniform(-50, 50)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    shape = shape.filter(ImageFilter.GaussianBlur(10))
    shape = ImageChops.multiply(shape, alpha_noise((size, size), 32, 40 + n).point(lambda v: 150 + v // 3))
    shape = shape.point(lambda v: 255 if v > 120 else 0).filter(ImageFilter.GaussianBlur(4))
    rings = Image.new('L', (size, size), 0)
    inner = shape
    for i in range(3):
        smaller = inner.filter(ImageFilter.MinFilter(15 + i * 6))
        ring = ImageChops.subtract(inner, smaller).filter(ImageFilter.GaussianBlur(3))
        rings = ImageChops.lighter(rings, ring.point(lambda v, k=i: v * (0.85 - k * 0.2)))
        inner = smaller.filter(ImageFilter.MinFilter(25))
    alpha = ImageChops.add(shape.point(lambda v: v * 0.3), rings)
    save('ceiling_stain%d' % n, (96, 64, 30), alpha)

# Grime along the bottom of a wall: dark at the floor, fading up in uneven streaks.
w, h = 1024, 256
alpha = Image.new('L', (w, h), 0)
px = alpha.load()
streaks = alpha_noise((w, 1), 12, 77).load()
for x in range(w):
    top = 0.35 + streaks[x, 0] / 255 * 0.5
    for y in range(h):
        up = 1 - y / (h - 1)          # 1 at the top of the image, 0 at the floor
        v = max(0.0, 1 - up / top) ** 1.6
        px[x, y] = int(v * 150)
fine = alpha_noise((w, h), 6, 78).point(lambda v: 150 + v // 2.5)
alpha = ImageChops.multiply(alpha, fine)
# Fade the ends so lengths of it don't show a hard edge.
ends = Image.linear_gradient('L').rotate(90, expand=True).resize((w, h))
ramp = ends.point(lambda v: min(255, int(min(v, 255 - v) * 6)))
alpha = ImageChops.multiply(alpha, ramp)
save('wall_grime', (34, 30, 26), alpha)

# A dropped sheet of lined notebook paper.
w, h = 340, 440
paper = Image.new('RGB', (w, h), (232, 230, 220))
d = ImageDraw.Draw(paper)
for y in range(60, h, 18):
    d.line((0, y, w, y), fill=(150, 175, 205), width=2)
d.line((52, 0, 52, h), fill=(210, 120, 120), width=2)
for i in range(rnd.randint(5, 9)):
    y = 66 + i * 18 - 8
    x = 62
    while x < w - 30 and rnd.random() > 0.08:
        word = rnd.randint(12, 40)
        d.line((x, y + rnd.randint(-1, 1), x + word, y + rnd.randint(-1, 1)), fill=(40, 45, 80), width=2)
        x += word + 8
shade = alpha_noise((w, h), 30, 90).point(lambda v: 236 + v // 14)
paper = ImageChops.multiply(paper, Image.merge('RGB', (shade, shade, shade)))
paper.putalpha(255)
paper.save(os.path.join(OUT, 'paper.png'))
print('wear decals written')
