"""OSTATOK 1.50: roofs v2 - large seamless roof materials.

The roofs were a 64-unit tile repeated over the whole building: the same rust
blot, the same crack every 64 units read as wallpaper from the street. These
are 256-unit surfaces (512 px at 2 texels per unit), seamless, each with its
own runs of sheets, seams, repairs, rust, moss and water stains; every
building starts the material at its own offset.

    python3 tools/roofs_v2.py <project_dir>

Writes art/world_hd/roof_v2_s<style>.png for the six roof styles (same order
as roof_tile_s*_hd: bitumen, slabs, rusty corrugated, painted corrugated,
standing-seam tin, asbestos slate).
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from interior_floors_v2 import value_noise as _vn  # noqa: E402

N = 512


def vn(r, cells, octaves=3):
    # interior_floors_v2.value_noise works on its own N (256): scale up
    import interior_floors_v2 as f
    old = f.N
    f.N = N
    try:
        return _vn(r, cells, octaves)
    finally:
        f.N = old


def grain(r, k):
    return (r.random((N, N)) - 0.5) * k


def blot(img, r, n, col, size, strength, stretch=(1.0, 1.0)):
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(n):
        cx, cy = r.uniform(0, N, 2)
        rad = r.uniform(*size)
        dx = np.minimum(abs(xx - cx), N - abs(xx - cx)) / stretch[0]
        dy = np.minimum(abs(yy - cy), N - abs(yy - cy)) / stretch[1]
        d = np.sqrt(dx * dx + dy * dy) / rad
        m = np.clip(1.0 - d, 0, 1) ** 1.4 * strength
        img[:] = img * (1 - m[..., None]) + np.array(col, float)[None, None, :] * m[..., None]


def streaks(img, r, n, col, strength, length=(40, 160)):
    """water runs down the slope (toward the south edge = +y)"""
    for _ in range(n):
        x = int(r.integers(0, N))
        y = int(r.integers(0, N))
        L = int(r.integers(*length))
        w = int(r.integers(1, 3))
        for i in range(L):
            t = 1.0 - i / L
            yy = (y + i) % N
            for dx in range(w):
                xx = (x + dx + int(np.sin(i * 0.07) * 1.5)) % N
                img[yy, xx] = img[yy, xx] * (1 - strength * t) + np.array(col) * strength * t


def finish(img, colours=40):
    a = np.clip(img, 0, 255).astype(np.uint8)
    q = Image.fromarray(a, 'RGB').quantize(colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return q.convert('RGB')


def bitumen(r):
    img = np.zeros((N, N, 3)) + np.array([58, 58, 56], float)
    img *= (0.86 + 0.20 * vn(r, 4) + 0.06 * vn(r, 24, 2))[..., None]
    img += grain(r, 10)[..., None]
    # rolled sheets: overlapping seams every 32 units, staggered ends
    for y in range(0, N, 64):
        img[y:y + 2] *= 0.70
        img[y + 2] *= 1.10
    for y in range(0, N, 64):
        x = int(r.integers(0, N))
        img[y:y + 64, x % N] *= 0.72
    # torch-on repairs: darker, glossier rectangles with a fat seam
    for _ in range(4):
        x, y = r.integers(0, N, 2)
        w, h = r.integers(24, 70), r.integers(16, 40)
        ys = np.arange(y, y + h) % N
        xs = np.arange(x, x + w) % N
        img[np.ix_(ys, xs)] *= 0.80
        img[ys[0], xs] *= 0.6
        img[ys[-1], xs] *= 0.6
        img[np.ix_(ys, [xs[0], xs[-1]])] *= 0.6
    # ponding stains (pale rings) and moss on the low side
    blot(img, r, 7, (92, 92, 86), (16, 40), 0.35, (1.4, 1.0))
    blot(img, r, 6, (40, 40, 38), (10, 26), 0.45, (1.6, 1.0))
    blot(img, r, 10, (64, 78, 44), (6, 16), 0.55)
    # gravel speckle
    sp = r.random((N, N))
    img[sp > 0.985] *= 1.35
    img[sp < 0.010] *= 0.6
    return finish(img)


def slabs(r):
    img = np.zeros((N, N, 3)) + np.array([128, 128, 120], float)
    img *= (0.88 + 0.14 * vn(r, 4) + 0.06 * vn(r, 20, 2))[..., None]
    img += grain(r, 12)[..., None]
    s = 64   # 32-unit slabs
    for ty in range(N // s):
        for tx in range(N // s):
            img[ty * s:(ty + 1) * s, tx * s:(tx + 1) * s] *= 1 + r.normal(0, 0.04)
    img[::s] *= 0.62
    img[:, ::s] *= 0.62
    img[1::s] *= 1.08
    img[:, 1::s] *= 1.06
    # tar on the joints, here and there
    for _ in range(14):
        tx, ty = r.integers(0, N // s, 2)
        if r.random() < 0.5:
            img[ty * s:ty * s + 3, tx * s:(tx + 1) * s] = img[ty * s:ty * s + 3, tx * s:(tx + 1) * s] * 0.4 + 12
        else:
            img[ty * s:(ty + 1) * s, tx * s:tx * s + 3] = img[ty * s:(ty + 1) * s, tx * s:tx * s + 3] * 0.4 + 12
    blot(img, r, 8, (90, 92, 80), (14, 34), 0.35)
    blot(img, r, 9, (70, 84, 48), (6, 14), 0.5)
    streaks(img, r, 30, (80, 80, 76), 0.35)
    return finish(img)


def corrugated(r, base, rust_amount, rust_col=(124, 62, 34)):
    img = np.zeros((N, N, 3)) + np.array(base, float)
    # corrugation: vertical ribs every 4 texels, lit on the left
    x = np.arange(N)
    rib = np.sin(x * (2 * np.pi / 6.0))
    img *= (1.0 + 0.10 * rib)[None, :, None]
    img *= (0.88 + 0.14 * vn(r, 4) + 0.06 * vn(r, 16, 2))[..., None]
    img += grain(r, 8)[..., None]
    # sheets: 64 x 128 texel panels, overlaps darker, a few sheets off-tone
    for sy in range(0, N, 128):
        img[sy:sy + 3] *= 0.66
        for sx in range(0, N, 96):
            if r.random() < 0.25:
                img[sy:sy + 128, sx:sx + 96] *= 1 + r.normal(0, 0.08)
    # rust: blooms around the fixings and long runs down the slope
    rust = np.clip((vn(r, 6, 3) - (0.78 - rust_amount * 0.3)) * 4.0, 0, 1)
    img = img * (1 - rust[..., None] * 0.8) + np.array(rust_col, float) * rust[..., None] * 0.8
    for sy in range(0, N, 128):
        for fx in range(6, N, 24):
            if r.random() < rust_amount:
                img[(sy + 4) % N:(sy + 6) % N or N, fx:fx + 2] = rust_col
    streaks(img, r, int(40 * rust_amount) + 6, rust_col, 0.45)
    # a patched hole: a newer sheet laid over
    for _ in range(1):
        px, py = r.integers(0, N - 70, 2)
        # a newer sheet: same ribs, cleaner and a shade lighter
        img[py:py + 60, px:px + 66] = img[py:py + 60, px:px + 66] * 0.80 + np.array(base, float) * 0.30
        img[py, px:px + 66] *= 0.6
        img[py + 59, px:px + 66] *= 0.6
    blot(img, r, 4, (60, 72, 40), (6, 12), 0.5)
    return finish(img, 44)


def seam_tin(r):
    img = np.zeros((N, N, 3)) + np.array([150, 66, 50], float)
    img *= (0.88 + 0.14 * vn(r, 4) + 0.05 * vn(r, 20, 2))[..., None]
    img += grain(r, 8)[..., None]
    for x in range(0, N, 40):         # standing seams every 20 units
        img[:, x:x + 2] *= 0.62
        img[:, x + 2] *= 1.18
    fade = np.clip((vn(r, 3) - 0.45) * 2.0, 0, 1)
    img = img * (1 - fade[..., None] * 0.45) + np.array([170, 110, 92], float) * fade[..., None] * 0.45
    streaks(img, r, 24, (110, 60, 40), 0.4)
    blot(img, r, 6, (96, 50, 34), (8, 20), 0.5)
    return finish(img)


def slate(r):
    # asbestos-cement corrugated sheets (shifer): grey, lichen, chipped corners
    img = np.zeros((N, N, 3)) + np.array([140, 142, 132], float)
    x = np.arange(N)
    rib = np.sin(x * (2 * np.pi / 16.0))
    img *= (1.0 + 0.12 * rib)[None, :, None]
    img *= (0.88 + 0.14 * vn(r, 4) + 0.05 * vn(r, 18, 2))[..., None]
    img += grain(r, 10)[..., None]
    for sy in range(0, N, 80):
        off = 0 if (sy // 80) % 2 == 0 else 48
        img[sy:sy + 3] *= 0.6
        for sx in range(off, N + 96, 96):
            img[sy:sy + 80, sx % N:(sx % N) + 2] *= 0.7
    lich = np.clip((vn(r, 10, 3) - 0.62) * 5.0, 0, 1)
    img = img * (1 - lich[..., None] * 0.6) + np.array([160, 150, 96], float) * lich[..., None] * 0.6
    blot(img, r, 14, (82, 96, 52), (5, 14), 0.55)
    streaks(img, r, 20, (96, 98, 90), 0.35)
    return finish(img)


STYLES = [bitumen, slabs, lambda r: corrugated(r, (128, 96, 70), 0.8), lambda r: corrugated(r, (78, 98, 118), 0.45),
          seam_tin, slate]


def build(P):
    out = os.path.join(P, 'art', 'world_hd')
    for i, fn in enumerate(STYLES):
        im = fn(np.random.default_rng(1500 + i))
        im.save(os.path.join(out, 'roof_v2_s%d.png' % i))
        print('roof', i, flush=True)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
