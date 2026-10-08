"""OSTATOK district ground chunks (HD, 1536 x 1536 = 768 world units at 2x).

Every chunk keeps the logical footprint of ground_chunk_v12 (sidewalk band
274..299 / 469..494, carriageway 299..469 on both axes) so placement rules,
AI and saves are untouched - but outside the city the material changes:

  rural      dirt road with wheel ruts and a grass crown, grass verges with
             gravel edges, overgrown plots with garden soil
  woodland   forest track (packed earth, roots, needles), moss verges, forest
             floor with needles, moss, ferns and fallen branches
  military   precast concrete slab road (joints, cracks, tar seams), gravel
             verges, dry grass and gravel patches
  industrial patched concrete / asphalt with oil stains, crushed-stone verges,
             packed earth and gravel lots with weeds

Relief is a height field lit with the shared OSTATOK light, then crisp detail
(speckle, clusters, cracks) is painted at texel level. Tiles wrap seamlessly.

    python3 tools/wa_ground_districts.py <project_dir>
"""
import math
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wa_core import fbm, clamp8, LEAF_ORANGE, Tex
from pixel_finish import pixel_finish, blocky_noise
import wa_town

W = 768
K = 2
N = W * K
SW0, R0, R1, SW1 = 274, 299, 469, 494


def grid():
    v = (np.arange(N) + 0.5) / K
    return np.meshgrid(v, v)


X, Y = None, None
RAGGED = 0.0


def noise(seed, cell, oct=4):
    return fbm(N, N, cell * K, seed, oct, wrap=True)


def step(n, levels, seed, jit=0.6, cell=2):
    """continuous field -> a few flat tones; the boundaries between tones are
    broken by blocky jitter so they end in ragged pixel clusters, not contours."""
    j = (blocky_noise(N, N, cell, seed) - 0.5) * jit / levels
    return np.clip(np.floor((n + j) * levels), 0, levels - 1) / (levels - 1)


def tone(seed, cell, lo, hi, levels=3, oct=3):
    """stepped multiplicative tone variation (replaces lo + (hi-lo) * noise)."""
    return lo + (hi - lo) * step(noise(seed, cell, oct), levels, seed + 77, jit=0.3 if cell > 8 else 0.6, cell=3 if cell > 8 else 2)


def masks():
    # road edges are ragged by a texel or two: soft materials never meet in a ruler line
    jx = (blocky_noise(N, N, 3, 9001) - 0.5) * 5.0 * RAGGED
    jy = (blocky_noise(N, N, 3, 9002) - 0.5) * 5.0 * RAGGED
    xx, yy = X + jx, Y + jy
    road_v = (xx >= R0) & (xx < R1)
    road_h = (yy >= R0) & (yy < R1)
    road = road_v | road_h
    walk = (((xx >= SW0) & (xx < SW1)) | ((yy >= SW0) & (yy < SW1))) & ~road
    plot = ~(road | walk)
    # distance (world units) from the nearest road centreline, per axis
    dv = np.abs(xx - (R0 + R1) / 2)
    dh = np.abs(yy - (R0 + R1) / 2)
    return road, walk, plot, road_v, road_h, dv, dh


def shade(alb, hf, strength=1.0):
    gy, gx = np.gradient(hf * K)
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(hf)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    L = wa_town.LIGHT
    # screen y points south (toward the camera) = +y in the world
    d = (nx * L[0] + ny * L[1] + nz * L[2]) / ln
    k = 0.62 + 0.46 * step(np.clip(d, 0, 1), 6, 4242, jit=0.4)
    return alb * k[..., None]


def speckle(alb, m, density, cols, seed):
    """pebbles: a lit texel, its body and a shadow texel below-right - pixel
    stones instead of single-texel salt-and-pepper noise."""
    rng = np.random.default_rng(seed)
    r = m & (rng.random(m.shape) < density * 0.4)
    idx = rng.integers(0, len(cols), m.shape)
    big = rng.random(m.shape) < 0.35
    for i, c in enumerate(cols):
        c = np.asarray(c, float)
        sel = r & (idx == i)
        ys, xs = np.nonzero(sel)
        bx = big[ys, xs]
        alb[(ys + 1) % N, (xs + 1) % N] = alb[(ys + 1) % N, (xs + 1) % N] * 0.62
        alb[ys[bx], (xs[bx] + 1) % N] = c * 0.86
        alb[(ys[bx] + 1) % N, xs[bx]] = c * 0.74
        alb[(ys[bx] + 2) % N, (xs[bx] + 1) % N] = alb[(ys[bx] + 2) % N, (xs[bx] + 1) % N] * 0.62
        alb[ys, xs] = np.minimum(c * 1.12, 255)
    return alb


def clusters(alb, m, cols, seed, density):
    rng = np.random.default_rng(seed)
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return alb
    for i in rng.integers(0, len(xs), int(len(xs) * density)):
        x, y = xs[i], ys[i]
        c = np.array(cols[rng.integers(0, len(cols))], float)
        alb[y, x] = c
        if rng.random() < 0.6:
            alb[y, (x + 1) % N] = c * 0.8
        if rng.random() < 0.45:
            alb[(y + 1) % N, x] = c * 0.62
    return alb


def blades(alb, m, seed, count, cols=((62, 80, 42), (74, 92, 48), (86, 104, 54))):
    rng = np.random.default_rng(seed)
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return alb
    for i in rng.integers(0, len(xs), count):
        x, y = xs[i], ys[i]
        h = int(rng.integers(2, 6))
        for k in range(h):
            yk = (y - k) % N
            if m[yk, x]:
                alb[yk, x] = np.array(cols[min(k, len(cols) - 1)], float) * (1.0 + 0.04 * k)
    return alb


def leaves(alb, m, density, seed):
    rng = np.random.default_rng(seed)
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return alb
    for i in rng.integers(0, len(xs), int(len(xs) * density)):
        x, y = xs[i], ys[i]
        c = np.array(LEAF_ORANGE[rng.integers(0, len(LEAF_ORANGE))], float)
        alb[y, x] = c
        alb[y, (x + 1) % N] = c * 0.8
        if rng.random() < 0.4:
            alb[(y + 1) % N, x] = c * 0.6
    return alb


def cracks(alb, hf, m, seed, n, col, length=(30, 80)):
    t = Tex(N, N, seed=seed)
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return alb, hf
    for _ in range(n):
        i = t.rng.randrange(len(xs))
        for (px, py) in t.crack(float(xs[i]), float(ys[i]), t.rng.randint(*length), (0, 0, 0), None, 0.7):
            ix, iy = int(px) % N, int(py) % N
            if m[iy, ix]:
                alb[iy, ix] = col
                hf[iy, ix] -= 0.4
    return alb, hf


def grass_field(seed, base=(46, 58, 34), dry=(86, 82, 50), dirt=(74, 61, 44), dryness=0.5):
    n1, n2, n3 = noise(seed + 1, 96), noise(seed + 2, 20, 3), noise(seed + 3, 160, 2)
    g = np.array(base, float)[None, None, :] * np.ones((N, N, 1))
    dm = step(np.clip((n3 - (0.62 - dryness * 0.2)) * 3.2, 0, 1), 3, seed + 31, jit=1.2)
    g = g * (1 - dm[..., None]) + np.array(dry, float) * dm[..., None]
    soil = step(np.clip((n1 - 0.6) * 4.0, 0, 1), 3, seed + 32, jit=1.2)
    g = g * (1 - soil[..., None]) + np.array(dirt, float) * soil[..., None]
    g *= (0.84 + 0.3 * step(n2, 4, seed + 33))[..., None]
    hf = 0.6 * noise(seed + 4, 6, 2) - soil * 0.4
    return g, hf, soil


# ------------------------------------------------------------- families ---
_soft_seed = [500]


def soft(n, lo, hi):
    _soft_seed[0] += 1
    return step(np.clip((n - lo) / (hi - lo), 0, 1), 3, _soft_seed[0], jit=1.2)


def blend(alb, col, t):
    return alb * (1 - t[..., None]) + np.asarray(col, float)[None, None, :] * t[..., None]


def arm_masks(rv, rh):
    """road arms without the junction square (ruts / centre lines run along them)."""
    inter = rv & rh
    return rv & ~inter, rh & ~inter, inter


def ruts(alb, hf, rv, rh, offsets, half=4.0, depth=1.2, dark=0.82):
    av, ah, inter = arm_masks(rv, rh)
    c = (R0 + R1) / 2
    for off in offsets:
        tv = av & (np.abs(X - (c + off)) < half)
        th = ah & (np.abs(Y - (c + off)) < half)
        for t, coord in ((tv, X), (th, Y)):
            prof = np.clip(1 - np.abs(coord - (c + off)) / half, 0, 1)
            k = step(prof, 3, int(off) + 600, jit=0.9) * t
            alb *= (1 - (1 - dark) * k)[..., None]
            hf -= depth * k
    return alb, hf


def rural():
    road, walk, plot, rv, rh, dv, dh = masks()
    alb, hf, soil = grass_field(1101, dryness=0.6)
    earth = np.array((100, 86, 64), float)[None, None, :] * tone(1110, 30, 0.86, 1.08, 4, 3)[..., None]
    earth *= tone(1111, 5, 0.94, 1.06, 4, 2)[..., None]
    alb[road] = earth[road]
    hf[road] = 0.3 * noise(1112, 4, 2)[road]
    alb, hf = ruts(alb, hf, rv, rh, (-52, -26, 26, 52), half=4.5, depth=1.4, dark=0.8)
    # muted puddles in the ruts after rain
    pud = road & (noise(1114, 30, 3) > 0.72) & (hf < -0.8)
    alb = blend(alb, (70, 76, 74), pud * 0.8)
    # sparse grass crown along the centre of each arm, grass creeping in at the edges
    av, ah, inter = arm_masks(rv, rh)
    c = (R0 + R1) / 2
    crown = (av & (np.abs(X - c) < 6)) | (ah & (np.abs(Y - c) < 6))
    alb = blades(alb, crown, 1113, 6000)
    edge_d = np.minimum(np.minimum(np.abs(X - R0), np.abs(X - R1)), np.minimum(np.abs(Y - R0), np.abs(Y - R1)))
    creep = road & (edge_d < 10) & (noise(1115, 8, 2) > 0.45)
    alb = blades(alb, creep, 1116, 9000)
    alb = speckle(alb, road, 0.05, [(132, 122, 104), (78, 66, 50), (116, 104, 86)], 1117)
    # verges: rough grass, a few stones
    alb = blades(alb, walk, 1118, 26000)
    alb = speckle(alb, walk, 0.01, [(140, 132, 116), (96, 90, 80)], 1119)
    # plots: meadow with soft dry and bare patches
    bare = plot & (noise(1120, 60, 3) > 0.62)
    alb = blend(alb, (86, 72, 52), soft(noise(1120, 60, 3), 0.62, 0.72) * plot * 0.8)
    alb = blades(alb, plot & ~bare, 1121, 110000)
    alb = clusters(alb, plot & ~bare, [(186, 170, 80), (206, 204, 190), (150, 104, 170)], 1122, 0.0006)
    alb = leaves(alb, plot | walk, 0.003, 1123)
    return alb, hf


def woodland():
    road, walk, plot, rv, rh, dv, dh = masks()
    litter = np.array((70, 58, 42), float)[None, None, :] * tone(2101, 50, 0.84, 1.1, 4, 3)[..., None]
    alb = litter.copy()
    hf = 0.7 * noise(2102, 8, 3)
    mossy = soft(noise(2103, 36, 3), 0.44, 0.62)
    alb = blend(alb, (64, 82, 46), mossy * 0.8)
    alb = clusters(alb, np.ones((N, N), bool), [(132, 94, 54), (112, 80, 46), (150, 112, 64), (86, 64, 42)], 2105, 0.10)   # needles
    alb = clusters(alb, mossy > 0.5, [(78, 100, 50), (94, 116, 58)], 2106, 0.06)
    # forest track: packed earth, soft edges with litter creeping in
    d = np.minimum(np.where(rv, dv, 999), np.where(rh, dh, 999))
    tw = 46 + 8 * noise(2107, 40, 2)
    track = road & (d < tw)
    t_soft = step(np.clip((tw - d) / 8.0, 0, 1), 3, 2120, jit=1.2) * road
    earth = np.array((96, 82, 62), float)[None, None, :] * tone(2108, 20, 0.86, 1.08, 4, 3)[..., None]
    alb = alb * (1 - t_soft[..., None]) + earth * t_soft[..., None]
    hf = hf * (1 - t_soft) + 0.25 * noise(2109, 3, 2) * t_soft
    alb, hf = ruts(alb, hf, rv, rh, (-20, 20), half=5.0, depth=1.2, dark=0.84)
    alb = speckle(alb, track, 0.04, [(124, 112, 94), (72, 60, 44)], 2110)
    # roots across the track edges
    t = Tex(N, N, seed=2111)
    for _ in range(70):
        x, y = t.rng.uniform(0, N), t.rng.uniform(0, N)
        if not road[int(y) % N, int(x) % N]:
            continue
        for (px, py) in t.crack(x, y, t.rng.randint(20, 46), (0, 0, 0), None, 0.4):
            ix, iy = int(px) % N, int(py) % N
            alb[iy, ix] = (82, 62, 44)
            hf[iy, ix] += 0.7
    rng = np.random.default_rng(2112)
    for _ in range(700):                    # ferns
        cx, cy = rng.integers(0, N, 2)
        if t_soft[cy, cx] > 0.2:
            continue
        for a in np.linspace(0, math.tau, 7, endpoint=False):
            for r in range(1, 9):
                px, py = int(cx + math.cos(a) * r) % N, int(cy + math.sin(a) * r * 0.7) % N
                alb[py, px] = (66 + r * 3, 92 + r * 2, 44)
                hf[py, px] += 0.3
    for _ in range(120):                    # fallen branches
        x, y = rng.uniform(0, N), rng.uniform(0, N)
        a = rng.uniform(0, math.pi)
        L = rng.uniform(10, 36)
        for sstep in np.linspace(0, L, int(L * 2)):
            px, py = int(x + math.cos(a) * sstep) % N, int(y + math.sin(a) * sstep) % N
            alb[py, px] = (88, 70, 50)
            alb[(py + 1) % N, px] = (50, 40, 30)
            hf[py, px] += 0.6
    alb = clusters(alb, t_soft < 0.3, [(96, 70, 44)], 2113, 0.002)       # cones
    alb = leaves(alb, t_soft < 0.5, 0.008, 2114)
    return alb, hf


def military():
    road, walk, plot, rv, rh, dv, dh = masks()
    alb, hf, soil = grass_field(3101, base=(66, 70, 40), dry=(104, 98, 62), dirt=(88, 78, 56), dryness=0.9)
    slab = np.array((128, 126, 116), float)[None, None, :] * tone(3102, 30, 0.88, 1.04, 4, 3)[..., None]
    alb[road] = slab[road]
    hf[road] = 0.0
    c = (R0 + R1) / 2
    sx, sy = 60.0, 28.0
    lx, ly = np.abs(X - c), np.abs(Y - c)
    jv = rv & ((((Y + 7) % sx) < 0.8) | ((lx % sy) < 0.8))
    jh = rh & ((((X + 7) % sx) < 0.8) | ((ly % sy) < 0.8))
    joint = jv | jh
    alb[joint] = (84, 82, 76)
    hf[joint] -= 0.5
    cell = np.floor((Y + 7) / sx) * 7 + np.floor(lx / sy) * 13 + np.floor((X + 7) / sx) * 3
    alb[road] *= (1.0 + 0.035 * np.sin(cell * 1.7))[road][..., None]
    hf[road] += (np.sin(cell) * 0.25)[road]
    alb, hf = cracks(alb, hf, road, 3103, 70, (88, 86, 80))
    alb = clusters(alb, joint, [(84, 100, 50), (98, 112, 58)], 3104, 0.15)
    alb = speckle(alb, road, 0.012, [(146, 142, 132), (100, 98, 90)], 3105)
    gv = soft(noise(3106, 60, 3), 0.55, 0.65)
    gravel_t = np.maximum(walk.astype(float), gv * plot)
    gcol = np.array((116, 110, 98), float)[None, None, :] * tone(3107, 3, 0.82, 1.08, 4, 2)[..., None]
    alb = alb * (1 - gravel_t[..., None]) + gcol * gravel_t[..., None]
    hf += 0.4 * noise(3108, 2, 2) * gravel_t
    alb = speckle(alb, gravel_t > 0.5, 0.2, [(150, 146, 134), (84, 80, 72), (124, 116, 100)], 3109)
    alb = blades(alb, plot & (gravel_t < 0.5), 3110, 60000, cols=((96, 92, 56), (110, 104, 62), (124, 116, 70)))
    alb = leaves(alb, plot, 0.002, 3111)
    return alb, hf


def industrial():
    road, walk, plot, rv, rh, dv, dh = masks()
    alb, hf, soil = grass_field(4101, base=(58, 62, 40), dry=(92, 86, 58), dirt=(82, 72, 56), dryness=0.8)
    con = np.array((116, 114, 106), float)[None, None, :] * tone(4102, 28, 0.86, 1.06, 4, 3)[..., None]
    alb[road] = con[road]
    hf[road] = 0.0
    pt = soft(noise(4103, 40, 3), 0.68, 0.71) * road
    alb = blend(alb, (88, 88, 84), pt * 0.7)                  # asphalt patches with crisp-ish edges
    hf += pt * 0.25
    alb, hf = cracks(alb, hf, road, 4105, 120, (64, 62, 58))
    oil = soft(noise(4106, 14, 3), 0.78, 0.84) * road
    alb *= (1 - 0.22 * oil)[..., None]
    alb = speckle(alb, road, 0.012, [(140, 136, 126), (88, 86, 80)], 4107)
    lt = np.maximum(walk.astype(float), soft(noise(4108, 80, 3), 0.42, 0.52) * plot)
    lcol = np.array((100, 94, 84), float)[None, None, :] * tone(4109, 3, 0.82, 1.08, 4, 2)[..., None]
    alb = alb * (1 - lt[..., None]) + lcol * lt[..., None]
    hf += 0.5 * noise(4110, 2, 2) * lt
    alb = speckle(alb, lt > 0.5, 0.2, [(132, 126, 114), (72, 66, 58), (118, 80, 52)], 4111)
    pud = soft(noise(4112, 40, 3), 0.76, 0.8) * (lt > 0.5)
    alb = blend(alb, (60, 66, 68), pud * 0.8)
    alb = blades(alb, (plot & (lt < 0.5)) | ((lt > 0.5) & (noise(4113, 20, 2) > 0.68)), 4114, 50000)
    alb = leaves(alb, plot | walk, 0.003, 4115)
    return alb, hf


def city():
    """urban crossroads in the layout and palette of ground_chunk_v12: worn
    asphalt with repairs, faded zebra crossings, stop lines and a dashed centre
    line, granite kerbs with leaf litter in the gutter, concrete tile pavements
    with broken tiles and weeds, autumn lawns."""
    road, walk, plot, rv, rh, dv, dh = masks()
    av, ah, inter = arm_masks(rv, rh)
    # lawns
    alb, hf, soil = grass_field(9201, base=(46, 60, 32), dry=(70, 72, 40), dirt=(64, 56, 42), dryness=0.15)
    alb = blades(alb, plot & (soil < 0.5), 9202, 90000, cols=((52, 68, 34), (62, 80, 40), (74, 92, 46)))
    # asphalt
    asp = np.array((58, 59, 60), float)[None, None, :] * tone(9203, 30, 0.9, 1.08, 4, 3)[..., None]
    alb[road] = asp[road]
    hf[road] = 0.0
    # wheel-polished lanes: slightly darker bands along each arm
    c = (R0 + R1) / 2
    for off in (-52, -26, 26, 52):
        lane = (av & (np.abs(X - (c + off)) < 7)) | (ah & (np.abs(Y - (c + off)) < 7))
        alb[lane] *= 0.94
    # rectangular repairs with crisp edges
    rng = np.random.default_rng(9204)
    for _ in range(14):
        x0, y0 = rng.uniform(R0, R1 - 30), rng.uniform(0, W - 30)
        if rng.random() < 0.5:
            x0, y0 = y0, x0
        w, h = rng.uniform(10, 30), rng.uniform(8, 22)
        m = road & (X >= x0) & (X < x0 + w) & (Y >= y0) & (Y < y0 + h)
        alb[m] = np.array((48, 49, 51), float) * rng.uniform(0.96, 1.04)
        edge = m & ~((X >= x0 + 0.6) & (X < x0 + w - 0.6) & (Y >= y0 + 0.6) & (Y < y0 + h - 0.6))
        alb[edge] = (40, 40, 42)
    alb, hf = cracks(alb, hf, road, 9205, 150, (36, 36, 38))
    oil = soft(noise(9206, 12, 3), 0.8, 0.85) * road
    alb *= (1 - 0.18 * oil)[..., None]
    alb = speckle(alb, road, 0.012, [(92, 92, 90), (40, 40, 42)], 9207)
    # markings (worn: paint missing in clusters)
    paint = np.array((178, 176, 164), float)
    wear = (noise(9208, 7, 2) > 0.3) & (noise(9217, 2, 1) > 0.12)
    marks = np.zeros((N, N), bool)
    # zebra crossings on every arm just outside the junction
    for a, b in ((253, 279), (489, 515)):
        zv = av & (Y >= a) & (Y < b) & (((X - R0 - 4) % 14) < 8) & (X > R0 + 3) & (X < R1 - 3)
        zh = ah & (X >= a) & (X < b) & (((Y - R0 - 4) % 14) < 8) & (Y > R0 + 3) & (Y < R1 - 3)
        marks |= zv | zh
    # stop lines on the inbound half, dashed centre line
    marks |= av & (np.abs(Y - 247) < 1.0) & (X > R0 + 3) & (X < c)
    marks |= av & (np.abs(Y - 521) < 1.0) & (X > c) & (X < R1 - 3)
    marks |= ah & (np.abs(X - 247) < 1.0) & (Y > c) & (Y < R1 - 3)
    marks |= ah & (np.abs(X - 521) < 1.0) & (Y > R0 + 3) & (Y < c)
    dash_v = av & (np.abs(X - c) < 1.0) & ((Y % 24) < 10) & ((Y < 240) | (Y > 528))
    dash_h = ah & (np.abs(Y - c) < 1.0) & ((X % 24) < 10) & ((X < 240) | (X > 528))
    marks |= dash_v | dash_h
    marks &= wear
    alb[marks] = paint * tone(9209, 6, 0.9, 1.0, 3, 2)[marks][..., None]
    # kerbs: granite edge stones along the carriageway, shadow on the road side
    edge_d = np.minimum(np.minimum(np.abs(X - R0), np.abs(X - R1)), np.minimum(np.abs(Y - R0), np.abs(Y - R1)))
    kerb = walk & (edge_d < 2.0)
    alb[kerb] = (128, 126, 118)
    kerb_lit = walk & (edge_d < 0.6)
    alb[kerb_lit] = (150, 148, 140)
    gutter = road & ~inter & (edge_d < 4.0)
    alb[gutter] *= 0.82
    alb = leaves(alb, gutter, 0.08, 9210)
    # pavements: concrete tiles with grout, per-tile tone, broken / missing tiles
    tile = 12.0
    tx, ty = np.floor(X / tile), np.floor(Y / tile)
    tid = (tx * 92821 + ty * 68917) % 997
    ttone = 0.9 + 0.12 * ((tid * 7919) % 13) / 12.0
    pav = np.array((98, 94, 82), float)[None, None, :] * ttone[..., None]
    sw = walk & ~kerb
    alb[sw] = pav[sw]
    grout = sw & (((X % tile) < 0.6) | ((Y % tile) < 0.6))
    alb[grout] = (70, 68, 60)
    broken = sw & (((tid * 31) % 97) < 4)
    alb[broken] = (74, 64, 50)
    alb = speckle(alb, broken, 0.25, [(110, 104, 90), (60, 52, 42)], 9211)
    alb = blades(alb, grout & (noise(9212, 18, 2) > 0.62), 9213, 9000, cols=((62, 80, 40), (76, 94, 46)))
    alb = speckle(alb, sw, 0.01, [(120, 116, 104), (70, 66, 58)], 9214)
    # lawn kerb: low dark edge where the lawn meets the pavement
    lawn_edge = plot & ((np.abs(X - SW0) < 1.0) | (np.abs(X - SW1) < 1.0) | (np.abs(Y - SW0) < 1.0) | (np.abs(Y - SW1) < 1.0))
    alb[lawn_edge] = (52, 52, 46)
    alb = leaves(alb, plot, 0.02, 9215)
    alb = leaves(alb, sw, 0.004, 9216)
    return alb, hf


# ---------------------------------------------------------------- yards ---
# Compound yards (POI / settlement / High Risk cells): the same materials with
# no public road cross. Multi-chunk compounds tile them seamlessly, and their
# outer edges blend into the district with the runtime edge shader.
def rural_yard():
    alb, hf, soil = grass_field(5101, dryness=0.5)
    # worn footpaths between the plots
    n = noise(5102, 90, 3)
    path = (np.abs(n - 0.5) < 0.018) | (np.abs(noise(5103, 120, 2) - 0.5) < 0.014)
    alb = blend(alb, (98, 84, 62), path * 1.0)
    hf -= path * 0.3
    garden = soft(noise(5104, 70, 3), 0.7, 0.76)
    alb = blend(alb, (82, 66, 48), garden * 0.9)
    alb = blades(alb, ~path & (garden < 0.5), 5105, 120000)
    alb = speckle(alb, path, 0.05, [(132, 122, 104), (78, 66, 50)], 5106)
    alb = clusters(alb, ~path & (garden < 0.5), [(186, 170, 80), (206, 204, 190)], 5107, 0.0005)
    alb = leaves(alb, np.ones((N, N), bool), 0.003, 5108)
    return alb, hf


def woodland_yard():
    litter = np.array((72, 60, 44), float)[None, None, :] * tone(6101, 50, 0.84, 1.1, 4, 3)[..., None]
    alb = litter.copy()
    hf = 0.6 * noise(6102, 8, 3)
    mossy = soft(noise(6103, 40, 3), 0.42, 0.6)
    alb = blend(alb, (64, 82, 46), mossy * 0.8)
    # trampled clearing: packed earth in the middle of the yard
    trodden = soft(noise(6104, 110, 2), 0.5, 0.58)
    alb = blend(alb, (94, 80, 60), trodden * 0.85)
    alb = clusters(alb, trodden < 0.5, [(132, 94, 54), (112, 80, 46), (150, 112, 64), (86, 64, 42)], 6105, 0.08)
    alb = clusters(alb, mossy > 0.5, [(78, 100, 50), (94, 116, 58)], 6106, 0.05)
    alb = speckle(alb, trodden > 0.5, 0.04, [(124, 112, 94), (72, 60, 44)], 6107)
    alb = blades(alb, (mossy > 0.5) & (trodden < 0.5), 6108, 40000)
    alb = leaves(alb, np.ones((N, N), bool), 0.007, 6109)
    return alb, hf


def _slabs(alb, hf, m, sx, sy, joint_col, seed):
    jx = ((X % sx) < 0.8) | ((Y % sy) < 0.8)
    joint = m & jx
    alb[joint] = joint_col
    hf[joint] -= 0.5
    cell = np.floor(X / sx) * 7 + np.floor(Y / sy) * 13
    alb[m] *= (1.0 + 0.035 * np.sin(cell * 1.7 + seed))[m][..., None]
    return alb, hf, joint


def military_yard():
    slab = np.array((124, 122, 112), float)[None, None, :] * tone(7101, 30, 0.88, 1.04, 4, 3)[..., None]
    alb = slab.copy()
    hf = np.zeros((N, N))
    allm = np.ones((N, N), bool)
    alb, hf, joint = _slabs(alb, hf, allm, 48.0, 48.0, (84, 82, 76), 0.3)
    alb, hf = cracks(alb, hf, allm, 7102, 90, (88, 86, 80))
    alb = clusters(alb, joint, [(84, 100, 50), (98, 112, 58)], 7103, 0.15)
    gv = soft(noise(7104, 70, 3), 0.6, 0.68)
    gcol = np.array((116, 110, 98), float)[None, None, :] * tone(7105, 3, 0.82, 1.08, 4, 2)[..., None]
    alb = alb * (1 - gv[..., None]) + gcol * gv[..., None]
    alb = speckle(alb, gv > 0.5, 0.2, [(150, 146, 134), (84, 80, 72), (124, 116, 100)], 7106)
    alb = speckle(alb, gv < 0.5, 0.012, [(146, 142, 132), (100, 98, 90)], 7107)
    alb = leaves(alb, gv > 0.5, 0.002, 7108)
    return alb, hf


def industrial_yard():
    con = np.array((112, 110, 102), float)[None, None, :] * tone(8101, 28, 0.86, 1.06, 4, 3)[..., None]
    alb = con.copy()
    hf = np.zeros((N, N))
    allm = np.ones((N, N), bool)
    alb, hf, joint = _slabs(alb, hf, allm, 64.0, 64.0, (78, 76, 70), 1.1)
    pt = soft(noise(8102, 40, 3), 0.66, 0.7)
    alb = blend(alb, (86, 86, 82), pt * 0.7)
    alb, hf = cracks(alb, hf, allm, 8103, 140, (64, 62, 58))
    oil = soft(noise(8104, 14, 3), 0.78, 0.84)
    alb *= (1 - 0.22 * oil)[..., None]
    lt = soft(noise(8105, 90, 3), 0.6, 0.68)
    lcol = np.array((100, 94, 84), float)[None, None, :] * tone(8106, 3, 0.82, 1.08, 4, 2)[..., None]
    alb = alb * (1 - lt[..., None]) + lcol * lt[..., None]
    alb = speckle(alb, lt > 0.5, 0.2, [(132, 126, 114), (72, 66, 58), (118, 80, 52)], 8107)
    alb = speckle(alb, lt < 0.5, 0.012, [(140, 136, 126), (88, 86, 80)], 8108)
    alb = blades(alb, (lt > 0.5) & (noise(8109, 20, 2) > 0.7), 8110, 20000)
    alb = clusters(alb, joint, [(84, 100, 50)], 8111, 0.08)
    return alb, hf


def city_yard():
    # worn courtyard asphalt in the palette of ground_chunk_v12's carriageway
    asp = np.array((60, 61, 62), float)[None, None, :] * tone(9101, 26, 0.9, 1.08, 4, 3)[..., None]
    alb = asp.copy()
    hf = np.zeros((N, N))
    allm = np.ones((N, N), bool)
    patch = soft(noise(9102, 34, 3), 0.66, 0.7)
    alb = blend(alb, (48, 49, 50), patch * 0.8)
    alb, hf = cracks(alb, hf, allm, 9103, 160, (38, 38, 40))
    worn = soft(noise(9104, 60, 3), 0.7, 0.76)
    alb = blend(alb, (84, 80, 70), worn * 0.7)
    alb = speckle(alb, allm, 0.01, [(92, 92, 90), (44, 44, 46)], 9105)
    seams = (np.abs(noise(9106, 50, 2) - 0.5) < 0.01)
    alb = blades(alb, seams, 9107, 9000)
    alb = leaves(alb, allm, 0.002, 9108)
    return alb, hf


YARDS = {'rural': rural_yard, 'woodland': woodland_yard, 'military': military_yard,
         'industrial': industrial_yard, 'city': city_yard}


PALETTE = {'rural': 30, 'woodland': 30, 'military': 26, 'industrial': 28, 'city': 22}
FAMILIES = {'city': city, 'rural': rural, 'woodland': woodland, 'military': military, 'industrial': industrial}


def build_all(P):
    global X, Y
    X, Y = grid()
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    global RAGGED
    for name, fn in FAMILIES.items():
        RAGGED = 1.0 if name in ('rural', 'woodland') else (0.0 if name == 'city' else 0.4)
        alb, hf = fn()
        img = Image.fromarray(clamp8(shade(alb, hf, 0.9)), 'RGB')
        img = pixel_finish(img, colours=PALETTE.get(name, 32), jitter=0.0, wrap=True)
        img.convert('RGB').save(os.path.join(out, 'ground_%s_hd.png' % name))
        print('ground', name, flush=True)
    for name, fn in YARDS.items():
        alb, hf = fn()
        img = Image.fromarray(clamp8(shade(alb, hf, 0.9)), 'RGB')
        img = pixel_finish(img, colours=PALETTE.get(name, 28), jitter=0.0, wrap=True)
        img.convert('RGB').save(os.path.join(out, 'yard_%s_hd.png' % name))
        print('yard', name, flush=True)


if __name__ == '__main__':
    build_all(sys.argv[1] if len(sys.argv) > 1 else '.')
