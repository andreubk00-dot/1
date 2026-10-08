"""OSTATOK HD interior floors (2 texels per world unit, drawn at scale 0.5).

interior_floor_tiles_v5 was 1 texel per unit: inside a building the floor was
twice as coarse as the HD street outside. Same layout at 2x: 8 variants x 4
materials of 64 x 64 texels (= 32 x 32 world units):
  row 0 clinic ceramic tiles, row 1 retail linoleum, row 2 concrete,
  row 3 parquet.
Every pattern repeats on a divisor of 64 texels, so neighbouring cells join
without seams. Pixel-art finish: flat tones, lit top-left bevels, no gradients.

    python3 tools/wa_interior_floor_hd.py <project_dir>
"""
import os
import sys
import numpy as np
from PIL import Image

C = 64


def clamp8(a):
    return np.clip(a, 0, 255).astype(np.uint8)


def stains(a, rng, n, col, rx=(4, 10), ry=(2, 5), alpha=0.35):
    yy, xx = np.mgrid[0:C, 0:C]
    for _ in range(n):
        cx, cy = rng.uniform(8, 56), rng.uniform(8, 56)
        m = ((xx - cx) / rng.uniform(*rx)) ** 2 + ((yy - cy) / rng.uniform(*ry)) ** 2 < 1
        a[m] = a[m] * (1 - alpha) + np.array(col) * alpha


def speckle(a, rng, density, cols):
    m = rng.random((C, C)) < density
    idx = rng.integers(0, len(cols), (C, C))
    for i, c in enumerate(cols):
        a[m & (idx == i)] = c


def crack(a, rng, col):
    h, w = a.shape[:2]
    x, y = rng.uniform(2, w - 2), rng.uniform(2, h - 2)
    for _ in range(int(rng.integers(min(10, h), min(22, h + 6)))):
        x += rng.choice([-1, 0, 1]); y += 1 if rng.random() < 0.6 else 0
        if 1 <= int(x) < w - 1 and 1 <= int(y) < h - 1:
            a[int(y), int(x)] = col


def ceramic(v, rng):
    a = np.zeros((C, C, 3))
    T = 16
    base = [np.array((190, 190, 178)), np.array((150, 162, 160))]
    for ty in range(C // T):
        for tx in range(C // T):
            checker = (tx + ty) % 2
            tone = 0.94 + 0.1 * rng.random()
            c = base[checker] * tone
            y0, x0 = ty * T, tx * T
            a[y0:y0 + T, x0:x0 + T] = c
            a[y0 + 1, x0 + 1:x0 + T - 1] = c * 1.08          # lit bevel
            a[y0 + 1:y0 + T - 1, x0 + 1] = c * 1.06
            a[y0 + T - 2, x0 + 1:x0 + T - 1] = c * 0.86      # shade bevel
            a[y0 + 1:y0 + T - 1, x0 + T - 2] = c * 0.88
            if rng.random() < 0.08 + 0.04 * v:               # cracked tile
                crack(a[y0:y0 + T, x0:x0 + T], rng, c * 0.55)
    g = np.zeros((C, C), bool)
    g[::T, :] = True; g[:, ::T] = True
    a[g] = (92, 94, 88)
    speckle(a, rng, 0.012, [(80, 80, 74), (120, 118, 110)])
    if v in (3, 5):
        stains(a, rng, 1, (96, 82, 64), alpha=0.3)
    return a


def linoleum(v, rng):
    a = np.full((C, C, 3), (128, 112, 92), float)
    a *= (0.96 + 0.08 * (rng.random((C, C)) < 0.5))[..., None]
    speckle(a, rng, 0.06, [(150, 134, 112), (104, 92, 76), (118, 120, 120)])
    a[0, :] = (92, 80, 66)                                    # sheet seam
    a[:, 0] = (100, 88, 72)
    for _ in range(3 + v % 3):                                # scuffs
        x, y = rng.integers(4, 56), rng.integers(4, 60)
        L = rng.integers(4, 12)
        a[y, x:x + L] = a[y, x:x + L] * 0.8
    if v in (3, 4):
        stains(a, rng, 1, (80, 66, 52), alpha=0.35)
    return a


def concrete(v, rng):
    a = np.full((C, C, 3), (126, 126, 120), float)
    blot = rng.random((C // 4, C // 4))
    a *= np.repeat(np.repeat(0.94 + 0.08 * blot, 4, 0), 4, 1)[..., None]
    speckle(a, rng, 0.05, [(150, 150, 144), (92, 92, 88), (112, 110, 104)])
    a[0, :] = (82, 82, 78)                                    # slab joint
    a[:, 0] = (88, 88, 84)
    a[1, :] = a[1, :] * 1.06
    if v % 3 == 1:
        crack(a, rng, (70, 70, 66))
    if v in (1, 5):
        stains(a, rng, 1, (48, 48, 50), rx=(8, 14), ry=(4, 7), alpha=0.55)   # oil
    if v == 7:
        for x in range(8, 64, 16):                            # painted lane dots
            a[40:44, x:x + 4] = (200, 168, 50)
    return a


def parquet(v, rng):
    a = np.zeros((C, C, 3))
    PW = 8
    woods = [np.array(c) for c in ((126, 82, 52), (140, 94, 58), (114, 74, 46), (150, 102, 64))]
    for row in range(C // PW):
        off = (row * 24) % 64
        x = -off
        while x < C:
            L = 32
            c = woods[rng.integers(0, len(woods))] * (0.95 + 0.1 * rng.random())
            xs = np.arange(max(0, x), min(C, x + L))
            y0 = row * PW
            if len(xs):
                a[y0:y0 + PW, xs] = c
                a[y0 + 1, xs] = c * 1.1                       # lit edge
                a[y0 + PW - 1, xs] = c * 0.7                  # gap shadow
                for gy in (y0 + 3, y0 + 5):                   # grain
                    gx = xs[rng.random(len(xs)) < 0.35]
                    a[gy, gx] = c * 0.86
                end = x + L - 1
                if 0 <= end < C:
                    a[y0:y0 + PW, end] = c * 0.62             # board end
            x += L
    if v in (2, 6):
        stains(a, rng, 1, (90, 60, 40), alpha=0.3)
    if v == 5:
        a[30:34, 24:40] = (40, 30, 24)                        # missing board
    return a


def build(P):
    sheet = np.zeros((C * 4, C * 8, 3), np.uint8)
    for r, fn in enumerate((ceramic, linoleum, concrete, parquet)):
        for v in range(8):
            rng = np.random.default_rng(1000 * r + v)
            sheet[r * C:(r + 1) * C, v * C:(v + 1) * C] = clamp8(fn(v, rng))
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(sheet, 'RGB').save(os.path.join(out, 'interior_floor_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
