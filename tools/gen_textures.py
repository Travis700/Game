"""Generates Night Shift's tileable surface textures (albedo + normal map), all original.

Run from the project root:  python3 tools/gen_textures.py
Writes assets/textures/<name>.png and <name>_n.png. Every texture tiles seamlessly (all noise
is built in the frequency domain or with wrap-around rolls), so the game maps them triplanar
in world space.
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
N = 512


def rng(seed):
    return np.random.default_rng(seed)


def noise(size, beta, seed, aniso=(1.0, 1.0)):
    """Periodic fractal noise, roughly in [-1, 1]. beta: higher = smoother."""
    r = rng(seed)
    fy = np.fft.fftfreq(size)[:, None] * aniso[0]
    fx = np.fft.fftfreq(size)[None, :] * aniso[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spectrum = (r.normal(size=(size, size)) + 1j * r.normal(size=(size, size))) / f ** beta
    spectrum[0, 0] = 0
    n = np.real(np.fft.ifft2(spectrum))
    n -= n.mean()
    return n / (np.abs(n).max() + 1e-9)


def grain(size, seed, amount):
    return rng(seed).normal(0, amount, (size, size))


def save(name, rgb, height, strength=2.0):
    rgb = np.clip(rgb, 0, 1)
    Image.fromarray((rgb * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + ".png"))
    # Normal map (OpenGL convention, as Godot expects) from the height field, wrapping at edges.
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    nz = np.ones_like(height)
    length = np.sqrt(dx * dx + dy * dy + nz * nz)
    normal = np.stack([-dx / length, dy / length, nz / length], -1) * 0.5 + 0.5
    Image.fromarray((normal * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_n.png"))


def tint(value, color):
    return value[..., None] * np.array(color)[None, None, :]


def grid_mask(size, cells, line, axis=None):
    """1 on grout/joint lines of a cells x cells grid (line = width in pixels)."""
    idx = np.arange(size)
    period = size / cells
    on = (idx % period) < line
    if axis == "x":
        return np.broadcast_to(on[None, :], (size, size)).astype(float)
    if axis == "y":
        return np.broadcast_to(on[:, None], (size, size)).astype(float)
    return np.maximum(on[None, :], on[:, None]).astype(float)


def blur(img, passes=1):
    for _ in range(passes):
        img = (img + np.roll(img, 1, 0) + np.roll(img, -1, 0) + np.roll(img, 1, 1) + np.roll(img, -1, 1)) / 5.0
    return img


def floor_tiles():
    # Vinyl composition tile: 8 x 8 tiles per texture, alternating slightly, with flecks and scuffs.
    cells = 8
    r = rng(1)
    shade = r.uniform(0.9, 1.05, (cells, cells))
    shade[::2, ::2] *= 0.94
    per = np.kron(shade, np.ones((N // cells, N // cells)))
    fleck = (rng(2).random((N, N)) > 0.985) * rng(3).uniform(-0.25, 0.2, (N, N))
    scuff = noise(N, 1.6, 4) * 0.08
    joint = blur(grid_mask(N, cells, 2), 1)
    value = per * (1 + scuff) + fleck * 0.5 - joint * 0.35 + grain(N, 5, 0.015)
    rgb = tint(value, (0.62, 0.6, 0.53))
    save("floor", rgb, -joint * 0.6 + noise(N, 2.0, 6) * 0.05, 1.5)


def wall_blocks():
    # Painted cinder block: running bond, 4 courses x 2 blocks, thick painted mortar.
    rows, cols = 8, 4
    h = np.zeros((N, N))
    y = np.arange(N)[:, None]
    x = np.arange(N)[None, :]
    row = (y // (N // rows))
    offset = (row % 2) * (N // cols // 2)
    bed = (y % (N // rows)) < 5
    head = ((x + offset) % (N // cols)) < 5
    mortar = np.maximum(bed, head).astype(float)
    mortar = blur(mortar, 2)
    pits = np.clip(noise(N, 0.6, 7), 0.55, 1.0) - 0.55
    paint = noise(N, 2.2, 8) * 0.04
    value = 1.0 - mortar * 0.18 - pits * 0.5 + paint + grain(N, 9, 0.012)
    rgb = tint(value, (0.68, 0.66, 0.58))
    save("wall", rgb, -mortar * 0.8 - pits * 1.5 + noise(N, 1.0, 10) * 0.08, 2.5)


def ceiling_tiles():
    # Acoustic drop-ceiling tiles in a metal T-bar grid, 2 x 2 tiles per texture.
    cells = 2
    holes = (rng(11).random((N, N)) > 0.93).astype(float)
    holes = blur(holes, 1) * 1.5
    grid = grid_mask(N, cells, 6)
    stain = np.clip(noise(N, 2.4, 12), 0.4, 1) - 0.4
    value = 0.95 - holes * 0.25 - stain * 0.35 + grain(N, 13, 0.02)
    value = value * (1 - grid) + grid * 0.8
    rgb = tint(value, (0.62, 0.61, 0.56))
    rgb[grid > 0] = (0.55, 0.55, 0.55)
    save("ceiling", rgb, -holes * 0.6 + grid * 0.8, 2.0)


def brick():
    rows, cols = 16, 4
    y = np.arange(N)[:, None]
    x = np.arange(N)[None, :]
    row = y // (N // rows)
    offset = (row % 2) * (N // cols // 2)
    col = (x + offset) // (N // cols)
    bed = (y % (N // rows)) < 4
    head = ((x + offset) % (N // cols)) < 4
    mortar = np.maximum(bed, head).astype(float)
    r = rng(14)
    shades = r.uniform(0.8, 1.15, (rows + 1, cols + 2))
    per = shades[row % rows, col % cols]
    value = per * (1 + noise(N, 1.2, 15) * 0.12) + grain(N, 16, 0.02)
    rgb = tint(value, (0.5, 0.27, 0.2))
    mortar_rgb = tint(0.9 + noise(N, 1.5, 17) * 0.1, (0.42, 0.4, 0.37))
    m = blur(mortar, 1)[..., None]
    rgb = rgb * (1 - m) + mortar_rgb * m
    save("brick", rgb, -mortar * 0.9 + noise(N, 1.0, 18) * 0.1, 2.5)


def concrete():
    value = 0.95 + noise(N, 1.4, 19) * 0.08 + noise(N, 0.5, 20) * 0.05 + grain(N, 21, 0.02)
    cracks = np.abs(noise(N, 1.8, 22)) < 0.012
    value -= blur(cracks.astype(float), 1) * 0.4
    joint = blur(grid_mask(N, 1, 3), 1)
    value -= joint * 0.3
    rgb = tint(value, (0.36, 0.36, 0.35))
    save("concrete", rgb, noise(N, 0.6, 23) * 0.15 - joint * 0.5 - cracks * 0.6, 2.0)


def asphalt():
    stones = noise(N, 0.2, 24)
    value = 0.9 + stones * 0.15 + noise(N, 1.6, 25) * 0.1 + grain(N, 26, 0.03)
    rgb = tint(value, (0.12, 0.12, 0.13))
    save("asphalt", rgb, stones * 0.3, 2.0)


def grass():
    blades = noise(N, 0.4, 27, aniso=(0.3, 1.0))
    patches = noise(N, 2.0, 28)
    g = np.stack([0.11 + blades * 0.03 + patches * 0.03,
                  0.17 + blades * 0.05 + patches * 0.04,
                  0.09 + blades * 0.02 + patches * 0.01], -1)
    dirt = np.clip(patches - 0.4, 0, 1)[..., None]
    g = g * (1 - dirt) + np.array((0.17, 0.14, 0.1)) * dirt
    save("grass", g * 1.0, blades * 0.4, 2.0)


def wood_strips():
    # Gym floor: long maple strips, 8 per texture, varnished.
    strips = 8
    y = np.arange(N)[:, None]
    lane = y // (N // strips)
    r = rng(29)
    shade = r.uniform(0.85, 1.1, strips + 1)[lane]
    grain_lines = noise(N, 1.0, 30, aniso=(1.0, 0.08)) * 0.12
    joint = blur(grid_mask(N, strips, 2, axis="y"), 1)
    # Board ends, staggered per strip.
    x = np.arange(N)[None, :]
    ends = ((x + (lane * 97) % N) % N) < 2
    value = shade * (1 + grain_lines) - joint * 0.3 - ends * 0.3 + grain(N, 31, 0.01)
    rgb = tint(value, (0.66, 0.47, 0.27))
    save("gym_floor", rgb, -joint * 0.5 - ends * 0.5 + grain_lines * 0.3, 1.5)


def wood():
    grain_lines = noise(N, 1.1, 32, aniso=(1.0, 0.06))
    rings = np.sin(grain_lines * 18.0) * 0.06
    value = 0.95 + grain_lines * 0.1 + rings + grain(N, 33, 0.01)
    save("wood", tint(value, (0.36, 0.27, 0.18)), grain_lines * 0.2 + rings, 1.5)
    save("desk", tint(value * 0.98 + 0.04, (0.42, 0.35, 0.27)), grain_lines * 0.1, 1.0)


def metal():
    brushed = noise(N, 0.8, 34, aniso=(0.02, 1.0)) * 0.06
    smudge = noise(N, 2.0, 35) * 0.05
    value = 0.95 + brushed + smudge + grain(N, 36, 0.01)
    save("metal", tint(value, (0.45, 0.47, 0.49)), brushed * 0.5, 1.0)


def locker():
    # Painted steel locker fronts, one locker's height (1.9 m) top to bottom: a band of louvre
    # slots near the top and a handle recess partway down, with dents and chips. No door seams:
    # the school puts its own between lockers.
    y = np.arange(N)[:, None] * np.ones((1, N))
    slots = ((y > 24) & (y < 90) & ((y % 13) < 4)).astype(float)
    slots += ((y > N - 90) & (y < N - 24) & ((y % 13) < 4)).astype(float) * 0.0
    handle = ((y > 250) & (y < 262)).astype(float) * 0.5
    chips = (noise(N, 1.0, 37) > 0.75).astype(float) * 0.2
    value = 1.0 + noise(N, 2.2, 38) * 0.05 - slots * 0.6 - handle * 0.3 + chips * 0.3 + grain(N, 39, 0.01)
    rgb = tint(value, (0.22, 0.33, 0.46))
    rgb = rgb * (1 - chips[..., None]) + chips[..., None] * np.array((0.42, 0.42, 0.42))
    save("locker", rgb, -slots * 0.8 - handle * 0.4 + noise(N, 1.4, 40) * 0.08, 2.0)


def cork():
    value = 0.9 + noise(N, 0.3, 41) * 0.2 + grain(N, 42, 0.05)
    save("cork", tint(value, (0.58, 0.42, 0.26)), noise(N, 0.3, 43) * 0.4, 2.0)


def board():
    smear = noise(N, 1.6, 44, aniso=(0.4, 1.0))
    chalk = np.clip(smear, 0.3, 1) - 0.3
    value = 1.0 + chalk * 0.9 + grain(N, 45, 0.02)
    save("board", tint(value, (0.09, 0.17, 0.13)), smear * 0.05, 0.5)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for make in (floor_tiles, wall_blocks, ceiling_tiles, brick, concrete, asphalt, grass, wood_strips,
                 wood, metal, locker, cork, board):
        make()
    print("textures written to", os.path.abspath(OUT))
