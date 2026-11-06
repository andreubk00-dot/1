"""OSTATOK 1.48: interior floors v2 - seamless HD materials.

The 1.38 floors were 32-unit tiles cut from a 4-row atlas: the ceramic was a
loud checker, the concrete and linoleum showed every 32-unit tile border as a
grid. These are whole seamless surfaces (128 x 128 units at 2 texels per unit,
256 px), drawn once per building with texture repeat, low in contrast, with
their own joints, wear and stains.

    python3 tools/interior_floors_v2.py <project_dir>

Writes art/world_hd/floor_<name>_hd.png for every name in FLOORS.
"""
import os
import sys

import numpy as np
from PIL import Image

N = 256            # texels (128 world units)


def rng(seed):
    return np.random.default_rng(seed)


def value_noise(r, cells, octaves=3):
    """seamless smooth noise in 0..1 (periodic on N)."""
    out = np.zeros((N, N))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = cells * (2 ** o)
        g = r.random((c, c))
        y = np.linspace(0, c, N, endpoint=False)
        y0 = np.floor(y).astype(int)
        f = y - y0
        f = f * f * (3 - 2 * f)
        y1 = (y0 + 1) % c
        a = g[y0][:, y0] * (1 - f)[None, :] + g[y0][:, y1] * f[None, :]
        b = g[y1][:, y0] * (1 - f)[None, :] + g[y1][:, y1] * f[None, :]
        out += amp * (a * (1 - f)[:, None] + b * f[:, None])
        tot += amp
        amp *= 0.5
    return out / tot


def grain(r, k=1.0):
    return (r.random((N, N)) - 0.5) * k


def stains(img, r, n, colour, size=(8, 22), strength=0.35):
    """soft irregular stains, wrapping round the edges."""
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(n):
        cx, cy = r.uniform(0, N, 2)
        rad = r.uniform(*size)
        dx = np.minimum(abs(xx - cx), N - abs(xx - cx))
        dy = np.minimum(abs(yy - cy), N - abs(yy - cy))
        d = np.sqrt(dx * dx + (dy * r.uniform(0.6, 1.4)) ** 2) / rad
        wob = value_noise(r, 8, 2) * 0.6
        m = np.clip(1.0 - (d + wob - 0.3), 0, 1) ** 1.5 * strength
        img[:] = img * (1 - m[..., None]) + np.array(colour)[None, None, :] * m[..., None]


def finish(img, colours=28):
    a = np.clip(img, 0, 255).astype(np.uint8)
    im = Image.fromarray(a, 'RGB')
    q = im.quantize(colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return q.convert('RGB')


def clinic(r):
    # 8-unit (16 px) ceramic, pale grey-green, tile to tile a shade apart
    base = np.array([168, 176, 170], float)
    img = np.zeros((N, N, 3)) + base
    t = 16
    for ty in range(N // t):
        for tx in range(N // t):
            k = 1.0 + r.normal(0, 0.035)
            tint = np.array([0, r.normal(0, 2), r.normal(0, 2)])
            img[ty * t:(ty + 1) * t, tx * t:(tx + 1) * t] = img[ty * t:(ty + 1) * t, tx * t:(tx + 1) * t] * k + tint
    n = value_noise(r, 4)
    img *= (0.94 + 0.10 * n)[..., None]
    img += grain(r, 6)[..., None]
    # grout: one texel, darker
    img[::t, :] = img[::t, :] * 0.78
    img[:, ::t] = img[:, ::t] * 0.78
    # chipped / cracked tiles
    for _ in range(7):
        tx, ty = r.integers(0, N // t, 2)
        x0, y0 = tx * t + 2, ty * t + 2
        for i in range(10):
            img[(y0 + i) % N, (x0 + i + r.integers(0, 2)) % N] *= 0.72
    stains(img, r, 5, (140, 132, 112), (10, 26), 0.28)
    return finish(img)


def linoleum(r):
    base = np.array([150, 138, 112], float)
    img = np.zeros((N, N, 3)) + base
    n = value_noise(r, 3)
    img *= (0.92 + 0.12 * n)[..., None]
    sp = r.random((N, N))
    img[sp > 0.985] *= 0.82
    img[sp < 0.012] *= 1.10
    img += grain(r, 4)[..., None]
    # sheet seams every 64 units, and the odd scuff
    img[:, ::128] *= 0.80
    for _ in range(26):
        x, y = r.integers(0, N, 2)
        L = r.integers(6, 18)
        for i in range(L):
            img[(y + i // 4) % N, (x + i) % N] *= 0.86
    stains(img, r, 6, (118, 104, 80), (8, 24), 0.30)
    return finish(img)


def concrete(r):
    base = np.array([132, 132, 126], float)
    img = np.zeros((N, N, 3)) + base
    n1 = value_noise(r, 3)
    n2 = value_noise(r, 12, 2)
    img *= (0.88 + 0.14 * n1 + 0.06 * n2)[..., None]
    img += grain(r, 10)[..., None]
    # trowel arcs: faint lighter swirls
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(10):
        cx, cy = r.uniform(0, N, 2)
        rad = r.uniform(18, 40)
        d = np.sqrt(np.minimum(abs(xx - cx), N - abs(xx - cx)) ** 2 + np.minimum(abs(yy - cy), N - abs(yy - cy)) ** 2)
        ring = np.exp(-((d - rad) ** 2) / 10.0) * 0.012
        img *= (1 + ring)[..., None]
    # one sawn joint across the 128-unit slab
    img[0, :] *= 0.70
    img[:, 0] *= 0.70
    img[1, :] *= 1.06
    # hairline cracks
    for _ in range(4):
        x, y = r.uniform(0, N, 2)
        a = r.uniform(0, np.pi)
        for i in range(int(r.integers(20, 50))):
            a += r.normal(0, 0.25)
            x, y = x + np.cos(a), y + np.sin(a)
            img[int(y) % N, int(x) % N] *= 0.72
    stains(img, r, 4, (70, 68, 62), (10, 22), 0.40)      # oil
    stains(img, r, 4, (150, 146, 136), (12, 30), 0.20)   # dust
    return finish(img)


def parquet(r):
    # herringbone oak: 4 x 16 units (8 x 32 px) blocks
    img = np.zeros((N, N, 3))
    yy, xx = np.mgrid[0:N, 0:N]
    bw, bl = 8, 32
    u = (xx + yy)
    v = (xx - yy)
    # two diagonal families alternate in rows
    band = (u // bl) % 2
    idx_a = (u // bl) * 1000 + (v // bw)
    idx_b = (v // bl) * 1000 + (u // bw)
    idx = np.where(band == 0, idx_a, idx_b + 500000)
    ids, inv = np.unique(idx, return_inverse=True)
    tones = r.normal(0, 1, len(ids))
    t = tones[inv].reshape(N, N)
    base = np.array([138, 96, 60], float)
    img[:] = base
    img *= (1 + 0.07 * t)[..., None]
    # wood grain along each block
    gr = np.sin((np.where(band == 0, v, u)) * 1.7 + t * 3.0) * 0.04
    img *= (1 + gr)[..., None]
    img += grain(r, 6)[..., None]
    # joints
    edge = (u % bl == 0) | (np.where(band == 0, v % bw == 0, u % bw == 0))
    img[edge] *= 0.72
    n = value_noise(r, 3)
    img *= (0.90 + 0.14 * n)[..., None]
    stains(img, r, 4, (90, 64, 42), (10, 26), 0.30)
    return finish(img, 32)


def planks(r):
    # Soviet painted floorboards: 8-unit (16 px) boards, rust-brown paint worn
    # to bare wood down the walking lanes
    img = np.zeros((N, N, 3))
    paint = np.array([108, 66, 50], float)
    wood = np.array([150, 116, 80], float)
    bw = 16
    for b in range(N // bw):
        y0 = b * bw
        x = int(r.integers(0, N))
        lengths = []
        while sum(lengths) < N:
            lengths.append(int(r.integers(96, 192)))
        lengths[-1] = N - sum(lengths[:-1])
        for L in lengths:
            tone = 1 + r.normal(0, 0.05)
            for i in range(L):
                img[y0:y0 + bw, (x + i) % N] = paint * tone
            img[y0:y0 + bw, x % N] *= 0.6        # board end
            x += L
        img[y0, :] *= 0.62                       # gap between boards
        img[y0 + 1, :] *= 1.05
    wear = value_noise(r, 3)
    wm = np.clip((wear - 0.55) * 3.0, 0, 1)
    img = img * (1 - wm[..., None] * 0.7) + wood[None, None, :] * wm[..., None] * 0.7
    gr = np.sin(np.arange(N)[None, :] * 0.9 + value_noise(r, 6) * 8) * 0.03
    img *= (1 + gr)[..., None]
    img += grain(r, 6)[..., None]
    # nail heads
    for b in range(N // bw):
        for x in range(0, N, 48):
            img[b * bw + 8, (x + b * 13) % N] *= 0.6
    stains(img, r, 3, (80, 50, 36), (10, 24), 0.30)
    return finish(img, 30)


def home_lino(r):
    # patterned linoleum: muted diamonds, worn grey in the lanes
    img = np.zeros((N, N, 3))
    yy, xx = np.mgrid[0:N, 0:N]
    d = (np.abs(((xx % 32) - 16)) + np.abs(((yy % 32) - 16)))
    a = np.array([152, 120, 92], float)
    b = np.array([128, 98, 76], float)
    c = np.array([170, 146, 112], float)
    img[:] = a
    img[d < 12] = b
    img[(d >= 12) & (d < 14)] = c
    img[d < 4] = c
    n = value_noise(r, 3)
    wear = np.clip((n - 0.5) * 2.5, 0, 1)
    grey = np.array([140, 130, 116], float)
    img = img * (1 - wear[..., None] * 0.55) + grey * wear[..., None] * 0.55
    img += grain(r, 5)[..., None]
    img[:, ::128] *= 0.82
    stains(img, r, 4, (100, 80, 60), (10, 22), 0.28)
    return finish(img, 30)


def bath_tile(r):
    base = np.array([196, 184, 160], float)
    img = np.zeros((N, N, 3)) + base
    t = 20
    for ty in range(N // t + 1):
        for tx in range(N // t + 1):
            k = 1 + r.normal(0, 0.03)
            img[ty * t:(ty + 1) * t, tx * t:(tx + 1) * t] *= k
    img += grain(r, 5)[..., None]
    # 256 is not a multiple of 20: use a 16-texel tile so it tiles
    img = np.zeros((N, N, 3)) + base
    t = 16
    for ty in range(N // t):
        for tx in range(N // t):
            k = 1 + r.normal(0, 0.03)
            img[ty * t:(ty + 1) * t, tx * t:(tx + 1) * t] *= k
    img *= (0.95 + 0.08 * value_noise(r, 4))[..., None]
    img += grain(r, 5)[..., None]
    img[::t, :] *= 0.80
    img[:, ::t] *= 0.80
    stains(img, r, 5, (150, 136, 110), (8, 20), 0.30)
    return finish(img)


def garage(r):
    img = np.array(concrete(r)).astype(float)
    paint = np.array([92, 104, 88], float)
    n = value_noise(r, 4)
    keep = np.clip((0.62 - n) * 4.0, 0, 1)        # paint left where nobody walks
    img = img * (1 - keep[..., None] * 0.65) + paint * keep[..., None] * 0.65
    # a faded yellow line
    img[100:104, :] = img[100:104, :] * 0.5 + np.array([170, 150, 70]) * 0.5 * (r.random((4, N, 1)) > 0.25)
    return finish(img)


FLOORS = {'clinic': clinic, 'linoleum': linoleum, 'concrete': concrete, 'parquet': parquet,
          'planks': planks, 'home_lino': home_lino, 'bath_tile': bath_tile, 'garage': garage}


def build(P):
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    for i, (name, fn) in enumerate(FLOORS.items()):
        im = fn(rng(1480 + i))
        im.save(os.path.join(out, 'floor_%s_hd.png' % name))
        print('floor', name, flush=True)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')


def wall_cap(r):
    """neutral plaster for the tops of walls (tinted by the wall colour in game)."""
    img = np.zeros((N, N, 3)) + 200.0
    img *= (0.90 + 0.12 * value_noise(r, 4) + 0.05 * value_noise(r, 16, 2))[..., None]
    img += grain(r, 10)[..., None]
    for _ in range(6):                         # hairline cracks
        x, y = r.uniform(0, N, 2)
        a = r.uniform(0, np.pi)
        for i in range(int(r.integers(12, 40))):
            a += r.normal(0, 0.3)
            x, y = x + np.cos(a), y + np.sin(a)
            img[int(y) % N, int(x) % N] *= 0.78
    for _ in range(14):                        # chipped plaster
        x, y = r.integers(0, N, 2)
        img[y:y + 2, x:x + 3] *= 0.84
    return finish(img, 16)


if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[2] == 'walls':
    wall_cap(rng(1490)).save(os.path.join(sys.argv[1], 'art', 'world_hd', 'wall_cap_hd.png'))
    print('wall cap')
