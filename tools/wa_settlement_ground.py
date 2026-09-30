"""OSTATOK 1.22-dev4 settlement ground materials.

Seamless 256x256 textures at world density (1 px = 1 world px), one PNG per
material because Godot cannot repeat an AtlasTexture region. Built with the same
tileable noise / crack / leaf helpers as the city ground (wa_ground) so the
settlements share the worn, leaf-littered look of the rest of the world.
"""
import math
import os
import random
import numpy as np
from wa_core import Tex, fbm, LEAF_ORANGE

S = 512
K = (S // 256) ** 2        # feature counts scale with the texture area


def _base(col, seed, big=64, fine=12, k_big=0.30, k_fine=0.14):
    t = Tex(S, S, col, seed=seed)
    n1 = fbm(S, S, big, seed + 1, 4)
    n2 = fbm(S, S, fine, seed + 2, 3)
    t.rgb *= (1 - k_big / 2 + k_big * n1)[..., None]
    t.rgb *= (1 - k_fine / 2 + k_fine * n2)[..., None]
    return t


def _all(t):
    return np.ones((S, S), bool)


def _leaves(t, seed, dense=0.05, sparse=0.006):
    lf = fbm(S, S, 48, seed + 70, 3)
    t.leaves(lf > 0.64, dense, seed=seed + 71)
    t.leaves((lf <= 0.64) & (lf > 0.45), sparse, seed=seed + 72)


def _cracks(t, rng, n, col=(26, 26, 28), hi=(78, 78, 76), branch=0.6):
    for _ in range(n * K):
        t.crack(rng.uniform(0, S), rng.uniform(0, S), rng.randint(14, 46), col, hi, branch, rng.uniform(0, math.pi))


def _weeds(t, rng, mask, n):
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return
    for _ in range(n * K):
        i = rng.randrange(len(xs))
        x, y = xs[i], ys[i]
        for k in range(rng.randint(2, 4)):
            t.px((x + rng.randint(-1, 1)) % S, (y - k) % S, (70 + 14 * k, 88 + 12 * k, 44 + 6 * k))


def asphalt(seed=301):
    rng = random.Random(seed)
    t = _base((58, 59, 60), seed, 96, 10)
    A = _all(t)
    t.speckle(A, 0.05, [(70, 70, 69), (46, 46, 48)], seed=seed + 3)
    # repair patches with sealed edges
    for _ in range(4 * K):
        x, y, w, h = rng.randrange(S), rng.randrange(S), rng.randint(20, 46), rng.randint(14, 34)
        m = np.zeros((S, S), bool)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                m[yy % S, xx % S] = True
        t.mul(m, 0.86)
        t.speckle(m, 0.05, [(44, 44, 46)], seed=x)
    _cracks(t, rng, 7, (38, 38, 40), (72, 72, 70), 0.35)
    # alligator patches (potholes / puddles are separate decals placed per street)
    for _ in range(2 * K):
        cx, cy = rng.uniform(0, S), rng.uniform(0, S)
        for _ in range(12):
            t.crack(cx + rng.uniform(-12, 12), cy + rng.uniform(-9, 9), rng.randint(4, 9), (30, 30, 32), None, 0.2)
    wet = fbm(S, S, 80, seed + 9, 3) < 0.34
    t.blend(wet, (44, 50, 58), 0.3)
    _weeds(t, rng, A, 40)
    _leaves(t, seed, 0.02, 0.004)
    return t.image()


def concrete_slabs(seed=302):
    rng = random.Random(seed)
    t = _base((104, 104, 98), seed, 80, 10, 0.24, 0.12)
    A = _all(t)
    t.speckle(A, 0.05, [(118, 118, 112), (86, 86, 82)], seed=seed + 3)
    # 64 x 32 road slabs, some sunk / darker, joints with weeds
    joint = np.zeros((S, S), bool)
    joint[:, ::64] = True
    joint[::32, :] = True
    for sy in range(0, S, 32):
        for sx in range(0, S, 64):
            m = t.mask_rect(sx + 1, sy + 1, sx + 64, sy + 32)
            k = rng.choice([1.0, 1.0, 0.92, 1.06, 0.86])
            t.mul(m, k)
            if rng.random() < 0.3:
                t.crack(sx + rng.uniform(4, 60), sy + rng.uniform(4, 28), rng.randint(10, 30), (58, 58, 56), (130, 130, 124), 0.4, rng.uniform(0, math.pi))
    t.blend(joint, (48, 50, 46), 0.9)
    _weeds(t, rng, joint, 160)
    t.speckle(A, 0.01, [(72, 64, 50)], seed=seed + 5)          # rust / oil spots
    for _ in range(4 * K):
        cx, cy = rng.randrange(S), rng.randrange(S)
        t.blend(t.mask_ellipse(cx, cy, rng.uniform(6, 16), rng.uniform(3, 7)), (58, 56, 52), 0.55)
    _leaves(t, seed, 0.02, 0.004)
    return t.image()


def cobble(seed=303):
    rng = random.Random(seed)
    t = _base((74, 68, 58), seed, 90, 16, 0.26, 0.1)
    # small worn setts (6 x 5 px), low contrast against muddy joints
    t.rgb[:] = (58, 53, 44)
    for row, y in enumerate(range(0, S, 5)):
        off = (row % 2) * 3
        for x in range(-off, S, 6):
            if rng.random() < 0.03:
                continue                                          # missing stone
            c = np.array(rng.choice([(80, 75, 64), (74, 70, 60), (86, 80, 68), (70, 66, 58), (82, 76, 62)]), float)
            c *= rng.uniform(0.9, 1.08)
            for yy in range(y + 1, y + 5):
                for xx in range(x + 1, x + 6):
                    t.rgb[yy % S, xx % S] = c * (1.06 if yy == y + 1 else (0.9 if yy == y + 4 else 1.0))
    n = fbm(S, S, 60, seed + 9, 3)
    t.rgb *= (0.82 + 0.3 * n)[..., None]
    mud = fbm(S, S, 40, seed + 12, 3) > 0.62
    t.blend(mud, (62, 52, 40), 0.55)                              # silted over in places
    gaps = (t.rgb.sum(axis=2) < 170)
    _weeds(t, rng, gaps, 160)
    t.speckle(gaps, 0.03, [(58, 74, 40), (66, 84, 44)], seed=seed + 4)
    for _ in range(3 * K):
        cx, cy = rng.randrange(S), rng.randrange(S)
        t.blend(t.mask_ellipse(cx, cy, rng.uniform(8, 16), rng.uniform(4, 7)), (54, 48, 38), 0.5)
    _leaves(t, seed, 0.04, 0.008)
    return t.image()


def dirt_road(seed=304):
    rng = random.Random(seed)
    t = _base((86, 72, 54), seed, 70, 12, 0.34, 0.2)
    A = _all(t)
    t.speckle(A, 0.07, [(104, 94, 78), (66, 56, 42), (120, 112, 98)], seed=seed + 3)   # gravel
    for _ in range(6 * K):
        cx, cy = rng.randrange(S), rng.randrange(S)
        t.blend(t.mask_ellipse(cx, cy, rng.uniform(6, 16), rng.uniform(3, 7)), (70, 58, 44), 0.35)   # soft damp spots
    grass = fbm(S, S, 50, seed + 20, 3) > 0.62
    t.blend(grass, (60, 70, 40), 0.55)
    _weeds(t, rng, grass, 300)
    _leaves(t, seed, 0.05, 0.01)
    return t.image()


def grass_leaves(seed=305, dry=0.0):
    rng = random.Random(seed)
    t = Tex(S, S, (46, 58, 34), seed=seed)
    n1 = fbm(S, S, 80, seed + 1, 4)
    n2 = fbm(S, S, 20, seed + 2, 3)
    n3 = fbm(S, S, 120, seed + 3, 2)
    dryc = np.array((86, 82, 50.0)); dirt = np.array((74, 61, 44.0))
    g = t.rgb.copy()
    dm = np.clip((n3 - 0.5 + dry) * 3.0, 0, 1)
    g = g * (1 - dm[..., None]) + dryc * dm[..., None]
    soil = np.clip((n1 - 0.6) * 4, 0, 1)
    g = g * (1 - soil[..., None]) + dirt * soil[..., None]
    g *= (0.80 + 0.36 * n2)[..., None]
    t.rgb = g
    A = _all(t)
    t.speckle(A, 0.06, [(88, 104, 54), (98, 112, 60), (70, 86, 44)], seed=seed + 4)
    t.speckle(A, 0.03, [(34, 42, 26), (40, 48, 30)], seed=seed + 5)
    _weeds(t, rng, soil < 0.4, 900)
    _leaves(t, seed, 0.08, 0.012)
    return t.image()


def dirt_yard(seed=306):
    rng = random.Random(seed)
    t = _base((78, 66, 50), seed, 60, 10, 0.34, 0.2)
    A = _all(t)
    t.speckle(A, 0.08, [(98, 88, 72), (62, 52, 40), (112, 104, 90)], seed=seed + 3)
    patches = fbm(S, S, 40, seed + 9, 3) > 0.58
    t.blend(patches, (58, 70, 38), 0.6)
    _weeds(t, rng, patches, 500)
    t.speckle(A, 0.004, [(150, 140, 120), (60, 70, 80)], seed=seed + 11)            # shards / litter
    _leaves(t, seed, 0.06, 0.012)
    return t.image()


def gravel(seed=307):
    rng = random.Random(seed)
    t = _base((92, 90, 80), seed, 60, 8, 0.26, 0.2)
    A = _all(t)
    t.speckle(A, 0.25, [(112, 110, 100), (74, 72, 64), (126, 122, 110), (84, 80, 70)], seed=seed + 3)
    tracks = fbm(S, S, 70, seed + 8, 3) < 0.36
    t.mul(tracks, 0.86)
    weeds = fbm(S, S, 30, seed + 9, 3) > 0.68
    t.blend(weeds, (62, 72, 42), 0.5)
    _weeds(t, rng, weeds, 260)
    _leaves(t, seed, 0.02, 0.004)
    return t.image()


def oil_concrete(seed=308):
    rng = random.Random(seed)
    t = _base((92, 92, 88), seed, 70, 10, 0.3, 0.14)
    A = _all(t)
    joint = np.zeros((S, S), bool)
    joint[:, ::64] = True
    joint[::64, :] = True
    t.blend(joint, (54, 54, 52), 0.8)
    t.speckle(A, 0.05, [(104, 104, 100), (70, 70, 68)], seed=seed + 3)
    for _ in range(9 * K):
        cx, cy = rng.randrange(S), rng.randrange(S)
        rx, ry = rng.uniform(6, 22), rng.uniform(3, 10)
        t.blend(t.mask_ellipse(cx, cy, rx, ry), (30, 30, 32), 0.6)
        t.speckle(t.mask_ellipse(cx, cy, rx * 0.7, ry * 0.7), 0.03, [(70, 60, 90), (60, 80, 70)], seed=cx)   # oil sheen
    rust = fbm(S, S, 30, seed + 12, 3) > 0.7
    t.blend(rust, (104, 66, 40), 0.35)
    _cracks(t, rng, 14, (40, 40, 40), (120, 120, 116))
    _weeds(t, rng, joint, 120)
    _leaves(t, seed, 0.015, 0.003)
    return t.image()


def pavers(seed=309):
    rng = random.Random(seed)
    t = _base((128, 128, 120), seed, 70, 12, 0.22, 0.1)
    for y in range(0, S, 16):
        for x in range(0, S, 16):
            k = rng.uniform(0.88, 1.08)
            m = t.mask_rect(x + 1, y + 1, x + 16, y + 16)
            t.mul(m, k)
            if rng.random() < 0.05:
                t.blend(m, (84, 82, 74), 0.6)                     # broken / missing paver
    grid = np.zeros((S, S), bool)
    grid[:, ::16] = True
    grid[::16, :] = True
    t.blend(grid, (80, 82, 76), 0.8)
    _weeds(t, rng, grid, 260)
    t.speckle(grid, 0.06, [(58, 74, 40)], seed=seed + 5)
    _cracks(t, rng, 8, (70, 70, 66), (150, 150, 144), 0.3)
    _leaves(t, seed, 0.03, 0.006)
    return t.image()


def pavement(seed=310):
    """kerb / pavement slabs (30 px) with fallen leaves and moss in the joints."""
    rng = random.Random(seed)
    t = _base((112, 112, 106), seed, 60, 10, 0.24, 0.12)
    for y in range(0, S, 32):
        for x in range(0, S, 32):
            t.mul(t.mask_rect(x + 1, y + 1, x + 32, y + 32), rng.uniform(0.86, 1.08))
    grid = np.zeros((S, S), bool)
    grid[:, ::32] = True
    grid[::32, :] = True
    t.blend(grid, (70, 72, 66), 0.9)
    _weeds(t, rng, grid, 160)
    _cracks(t, rng, 10, (60, 60, 58), (140, 140, 134), 0.3)
    _leaves(t, seed, 0.07, 0.012)
    return t.image()


def lawn_overgrown(seed=311):
    return grass_leaves(seed, dry=-0.1)


def grass_dry(seed=312):
    return grass_leaves(seed, dry=0.25)


# ---------------------------------------------------------------- ground decals --
# 8 cells of 96 x 64 at 1x. Placed individually in game so nothing repeats in rows.
DECALS = ['puddle_a', 'puddle_b', 'pothole', 'mud', 'oil', 'patch', 'ruts', 'drain']
DW, DH = 96, 64


def _decal(kind, seed):
    rng = random.Random(seed)
    t = Tex(DW, DH, (0, 0, 0), alpha=0, seed=seed)
    cx, cy = DW / 2, DH / 2

    def blob(rx, ry, jag=0.25, n=14):
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n
            r = 1 + rng.uniform(-jag, jag)
            pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
        return t.mask_poly(pts)

    def put(m, col, alpha=255):
        t.rgb[m] = col
        t.a[m] = alpha

    if kind in ('puddle_a', 'puddle_b'):
        rx, ry = (40, 22) if kind == 'puddle_a' else (30, 18)
        rim = blob(rx, ry, 0.3)
        put(rim, (40, 36, 30), 200)
        water = blob(rx - 4, ry - 3, 0.3)
        put(water, (46, 56, 66), 235)
        sky = water & (np.mgrid[0:DH, 0:DW][0] < cy - 2)
        t.blend(sky, (78, 92, 104), 0.5)
        t.speckle(water, 0.02, [(120, 134, 146), (96, 110, 122)], seed=seed)
        for _ in range(8):
            x, y = rng.uniform(cx - rx * 0.6, cx + rx * 0.6), rng.uniform(cy - ry * 0.5, cy + ry * 0.5)
            t.px(int(x) % DW, int(y) % DH, rng.choice(LEAF_ORANGE))
    elif kind == 'pothole':
        rim = blob(24, 14, 0.35)
        put(rim, (34, 32, 30), 240)
        t.speckle(rim, 0.2, [(70, 68, 64), (52, 50, 48)], seed=seed)
        hole = blob(17, 9, 0.35)
        put(hole, (38, 46, 56), 245)
        t.speckle(hole, 0.05, [(110, 124, 136)], seed=seed + 1)
    elif kind == 'mud':
        m = blob(42, 24, 0.4, 18)
        put(m, (62, 50, 36), 170)
        t.speckle(m, 0.08, [(80, 66, 48), (48, 40, 30)], seed=seed)
        for i in range(4):
            y = int(cy - 10 + i * 6)
            for x in range(8, DW - 8, 3):
                if m[y % DH, x]:
                    t.px(x, y % DH, (44, 36, 26), 210)
    elif kind == 'oil':
        m = blob(34, 18, 0.35)
        put(m, (20, 20, 24), 150)
        t.speckle(m, 0.04, [(70, 50, 90), (40, 80, 70), (90, 80, 40)], seed=seed)
    elif kind == 'patch':
        m = t.mask_rect(14, 16, DW - 14, DH - 16)
        put(m, (40, 40, 42), 230)
        t.speckle(m, 0.06, [(52, 52, 54), (32, 32, 34)], seed=seed)
        edge = m & ~t.mask_rect(16, 18, DW - 16, DH - 18)
        put(edge, (26, 26, 28), 240)
    elif kind == 'ruts':
        for y0 in (22, 42):
            for x in range(DW):
                y = y0 + int(2 * math.sin(x / 18.0 + seed))
                for d in range(-2, 3):
                    t.px(x, (y + d) % DH, (46, 38, 28), 120 - abs(d) * 30)
    elif kind == 'drain':
        m = t.mask_rect(34, 24, 62, 40)
        put(m, (60, 62, 60), 255)
        for x in range(36, 62, 3):
            t.line([(x, 26), (x, 38)], (22, 22, 22), wrap=False)
        rim = t.mask_rect(32, 22, 64, 42) & ~m
        put(rim, (96, 96, 90), 255)
        leaves = blob(20, 10, 0.5) & ~t.mask_rect(32, 22, 64, 42)
        t.leaves(leaves, 0.25, seed=seed)
        t.a[leaves & (t.a == 0) & (np.random.default_rng(seed).random((DH, DW)) < 0.25)] = 0
    return t.image()


def build_decals(P):
    from PIL import Image
    out = Image.new('RGBA', (DW * len(DECALS), DH), (0, 0, 0, 0))
    for i, k in enumerate(DECALS):
        out.alpha_composite(_decal(k, 400 + i), (i * DW, 0))
    out.save(os.path.join(P, 'settlement_ground_decals_v1.png'))


MATERIALS = {
    'asphalt': asphalt, 'concrete_slabs': concrete_slabs, 'cobble': cobble, 'dirt_road': dirt_road,
    'grass': grass_leaves, 'grass_dry': grass_dry, 'lawn': lawn_overgrown, 'dirt_yard': dirt_yard,
    'gravel': gravel, 'oil_concrete': oil_concrete, 'pavers': pavers, 'pavement': pavement,
}


def build_all(P):
    for name, fn in MATERIALS.items():
        fn().save(os.path.join(P, 'settlement_ground_%s_v1.png' % name))
    build_decals(P)


if __name__ == '__main__':
    import sys
    build_all(sys.argv[1] if len(sys.argv) > 1 else '.')
    print('settlement ground ok')
