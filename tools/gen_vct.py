"""Generates the classroom floor: vinyl composition tile, the speckled 12-inch squares on almost
every school classroom floor. Writes assets/textures/floor.jpg (colour), floor_n.jpg (normal) and
floor_orm.jpg (AO in red, roughness in green): a 4x4 block of tiles that repeats every 1.22 m.
"""
import os
import numpy as np
from PIL import Image, ImageFilter

SIZE = 2048
TILES = 4
TILE = SIZE // TILES
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'textures')
rng = np.random.default_rng(7)


def blur(a, r):
    image = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255


def noise(scale):
    """Smooth value noise that wraps around, so the texture tiles."""
    cells = max(SIZE // scale, 2)
    grid = rng.random((cells, cells)).astype(np.float32)
    image = Image.fromarray((grid * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.BICUBIC)
    return np.asarray(image).astype(np.float32) / 255


# Off-white tiles, each from a slightly different dye lot, with the odd one a shade greyer.
colour = np.zeros((SIZE, SIZE, 3), np.float32)
base = np.array([0.80, 0.78, 0.72], np.float32)
for ty in range(TILES):
    for tx in range(TILES):
        shift = rng.normal(0, 0.005, 3) + rng.normal(0, 0.022)
        if rng.random() < 0.15:
            shift -= 0.06
        colour[ty * TILE:(ty + 1) * TILE, tx * TILE:(tx + 1) * TILE] = base + shift

# Chips pressed into the vinyl: grey, beige and charcoal flecks, stretched a little one way
# the way the stock is rolled.
for tint, count, size in (((0.55, 0.53, 0.5), 16000, 3), ((0.68, 0.6, 0.48), 12000, 3),
                          ((0.3, 0.3, 0.3), 3500, 2), ((0.92, 0.91, 0.88), 6000, 3)):
    mask = np.zeros((SIZE, SIZE), np.float32)
    ys = rng.integers(0, SIZE, count)
    xs = rng.integers(0, SIZE, count)
    for dy in range(size):
        for dx in range(size * 2):
            mask[(ys + dy) % SIZE, (xs + dx) % SIZE] = 1.0
    mask = blur(mask, 0.8) * rng.uniform(0.7, 1.0)
    colour = colour * (1 - mask[..., None]) + np.array(tint, np.float32) * mask[..., None]

# Years of mopping: soft grime, darker towards the seams.
grime = noise(256) * 0.5 + noise(64) * 0.35 + noise(16) * 0.15
colour *= (0.9 + grime * 0.12)[..., None]
seam = np.zeros((SIZE, SIZE), np.float32)
for i in range(TILES):
    for w in range(3):
        seam[:, (i * TILE + w - 1) % SIZE] = 1.0
        seam[(i * TILE + w - 1) % SIZE, :] = 1.0
edge = blur(seam, 6)
colour *= (1 - edge * 0.35)[..., None]
colour *= (1 - seam * 0.45)[..., None]
Image.fromarray(np.clip(colour * 255, 0, 255).astype(np.uint8)).save(os.path.join(OUT, 'floor.jpg'), quality=92)

# Normal map: the seams are slight grooves, the chips a hint of texture.
height = 1 - blur(seam, 1.5) * 0.8 + (noise(4) - 0.5) * 0.04
gy, gx = np.gradient(height)
strength = 6.0
n = np.dstack((-gx * strength, gy * strength, np.ones_like(height)))
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(os.path.join(OUT, 'floor_n.jpg'), quality=95)

# Wax: shiny where it's been buffed, duller in patches and in the seams.
half = SIZE // 2
rough = 0.32 + noise(128) * 0.18 + noise(32) * 0.08 + blur(seam, 2) * 0.4
ao = 1 - blur(seam, 2) * 0.5
orm = np.dstack((ao, rough, np.zeros_like(rough)))
Image.fromarray(np.clip(orm * 255, 0, 255).astype(np.uint8)).resize((half, half), Image.LANCZOS) \
    .save(os.path.join(OUT, 'floor_orm.jpg'), quality=92)
print('floor written')
