"""OSTATOK 0.87 ground chunk (768x768, tiles seamlessly chunk-to-chunk).

Keeps the logical footprint of every previous version:
  sidewalks 274..299 and 469..494, asphalt 299..469 (both axes).
"""
import math
import random
import numpy as np
from wa_core import Tex, fbm, value_noise, LEAF_ORANGE, MOSS

S = 768
SW0, R0, R1, SW1 = 274, 299, 469, 494


def build(path, seed=87):
    rng = random.Random(seed)
    t = Tex(S, S, (0, 0, 0), seed=seed)
    yy, xx = np.mgrid[0:S, 0:S]
    road_v = (xx >= R0) & (xx < R1)
    road_h = (yy >= R0) & (yy < R1)
    road = road_v | road_h
    walk = (((xx >= SW0) & (xx < SW1)) | ((yy >= SW0) & (yy < SW1))) & ~road
    grass = ~(road | walk)
    inter = road_v & road_h

    # ------------------------------------------------------------ grass / soil
    n1 = fbm(S, S, 96, seed + 1, 4)
    n2 = fbm(S, S, 24, seed + 2, 3)
    n3 = fbm(S, S, 160, seed + 3, 2)
    grass_col = np.array((46, 58, 34.0)); dry = np.array((86, 82, 50.0)); dirt = np.array((74, 61, 44.0))
    g = grass_col[None, None, :] * np.ones((S, S, 1))
    dmix = np.clip((n3 - 0.52) * 3.2, 0, 1)
    g = g * (1 - dmix[..., None]) + dry * dmix[..., None]
    soil = np.clip((n1 - 0.58) * 4.0, 0, 1)
    g = g * (1 - soil[..., None]) + dirt * soil[..., None]
    g *= (0.80 + 0.36 * n2)[..., None]
    g *= (0.78 + 0.4 * fbm(S, S, 48, seed + 8, 3))[..., None]
    t.rgb[grass] = g[grass]
    # grass blades / tufts
    t.speckle(grass & (soil < 0.5), 0.06, [(88, 104, 54), (98, 112, 60), (70, 86, 44)], seed=3)
    t.speckle(grass, 0.03, [(34, 42, 26), (40, 48, 30)], seed=4)
    t.speckle(grass & (soil > 0.4), 0.05, [(96, 84, 64), (58, 48, 36), (112, 104, 90)], seed=5)  # pebbles
    # tall tufts: vertical 2-3px blades with light tip
    r2 = np.random.default_rng(seed + 6)
    ys, xs = np.nonzero(grass & (soil < 0.35))
    for i in r2.integers(0, len(xs), 2600):
        x, y = xs[i], ys[i]
        h = r2.integers(2, 4)
        for k in range(h):
            yk = (y - k) % S
            if grass[yk, x]:
                t.rgb[yk, x] = (62 + 12 * k, 80 + 12 * k, 42 + 6 * k)
    # fallen leaves: dense under (imaginary) canopies, sparse elsewhere
    lf = fbm(S, S, 64, seed + 7, 3)
    t.leaves(grass & (lf > 0.66), 0.07, seed=1)
    t.leaves(grass & (lf <= 0.66) & (lf > 0.5), 0.008, seed=2)
    # mud puddles on soil
    for _ in range(5):
        cx, cy = rng.randrange(S), rng.randrange(S)
        if grass[cy % S, cx % S] and soil[cy % S, cx % S] > 0.3:
            m = t.mask_ellipse(cx, cy, rng.uniform(6, 14), rng.uniform(3, 6)) & grass
            t.blend(m, (40, 38, 34), 0.8)
            t.speckle(m, 0.05, [(96, 104, 112)], seed=cx)

    # ------------------------------------------------------------ asphalt
    a1 = fbm(S, S, 128, seed + 11, 4)
    a2 = fbm(S, S, 16, seed + 12, 2)
    base = np.array((60, 61, 62.0))
    asp = base * (0.80 + 0.34 * a1)[..., None] * (0.94 + 0.12 * a2)[..., None]
    # faint brown/blue temperature variation
    tint = fbm(S, S, 200, seed + 13, 2)
    asp[..., 0] += (tint - 0.5) * 8
    asp[..., 2] -= (tint - 0.5) * 6
    t.rgb[road] = asp[road]
    # tyre wear lanes (darker, polished)
    for c in (341, 427):
        for off in (-12, 12):
            band_v = road_v & ~inter & (np.abs(xx - (c + off)) <= 5)
            band_h = road_h & ~inter & (np.abs(yy - (c + off)) <= 5)
            k = 0.90 + 0.06 * a2
            t.mul(band_v | band_h, k)
    # aggregate speckle
    t.speckle(road, 0.04, [(68, 68, 67), (65, 65, 65)], seed=13)
    t.speckle(road, 0.06, [(47, 47, 49), (44, 45, 47)], seed=14)
    blot = fbm(S, S, 30, seed + 17, 3)
    t.mul(road, 0.9 + 0.2 * blot)
    # wet sheen (low spots)
    wet = road & (a1 < 0.36)
    t.blend(wet, (44, 50, 58), 0.35)
    t.speckle(wet, 0.004, [(96, 108, 120)], seed=15)

    # repair patches (darker, smoother, sealed edges)
    patches = [(310, 60, 36, 22), (420, 150, 26, 40), (80, 318, 44, 26), (600, 430, 38, 24),
               (350, 610, 30, 44), (160, 400, 28, 30), (690, 340, 34, 20), (440, 700, 24, 30)]
    for (x, y, w, h) in patches:
        m = road & t.mask_rect(x, y, x + w, y + h)
        t.mul(m, 0.88)
        t.speckle(m, 0.05, [(46, 46, 48)], seed=x)
        edge = m & ~t.mask_rect(x + 1, y + 1, x + w - 1, y + h - 1)
        t.blend(edge, (30, 30, 32), 0.6)

    # cracks: longitudinal + alligator networks
    for _ in range(34):
        if rng.random() < 0.5:
            x, y = rng.uniform(R0 + 6, R1 - 6), rng.uniform(0, S)
            ang = math.pi / 2 + rng.uniform(-0.3, 0.3)
        else:
            x, y = rng.uniform(0, S), rng.uniform(R0 + 6, R1 - 6)
            ang = rng.uniform(-0.3, 0.3)
        t.crack(x, y, rng.randint(20, 60), (28, 28, 30), (74, 74, 72), 0.7, ang)
    for (cx, cy) in [(330, 120), (440, 560), (120, 440), (640, 330), (380, 380)]:
        for _ in range(14):
            t.crack(cx + rng.uniform(-14, 14), cy + rng.uniform(-10, 10), rng.randint(4, 9), (32, 32, 34), None, 0.2)
    # restore non-road pixels possibly touched by cracks (they are drawn only for flavour on road)

    # potholes
    for (cx, cy, rx, ry) in [(356, 200, 7, 4.5), (452, 640, 6, 4), (190, 350, 8, 5), (580, 452, 5, 3.5), (402, 438, 6, 4)]:
        rim = t.mask_ellipse(cx, cy, rx + 1.5, ry + 1.2)
        hole = t.mask_ellipse(cx, cy, rx, ry)
        water = t.mask_ellipse(cx + 0.5, cy + 0.6, rx * 0.7, ry * 0.6)
        t.mul(rim & ~hole, 1.18)
        t.fill(hole, (34, 33, 32))
        t.speckle(hole, 0.2, [(52, 48, 42), (44, 42, 38)], seed=cx)
        t.fill(water, (48, 56, 64))
        t.px(cx - rx * 0.3, cy - ry * 0.2, (132, 146, 158))
        t.px(cx - rx * 0.3 + 1, cy - ry * 0.2, (96, 108, 120))

    # oil stains
    for _ in range(9):
        cx, cy = rng.choice([341, 427]) + rng.uniform(-8, 8), rng.uniform(0, S)
        if rng.random() < 0.5:
            cx, cy = cy, cx
        m = road & t.mask_ellipse(cx, cy, rng.uniform(4, 9), rng.uniform(3, 6))
        t.blend(m, (26, 26, 30), 0.45)
        t.speckle(m, 0.03, [(70, 58, 90), (60, 84, 92)], seed=int(cx))

    # ------------------------------------------------------------ markings
    WHITE = (176, 172, 156)
    wear = fbm(S, S, 5, seed + 21, 2) * 0.7 + fbm(S, S, 40, seed + 22, 2) * 0.3
    def paint(m, col=WHITE, keep=0.63):
        m = m & (wear < keep)
        t.blend(m, col, 0.82)
    CX = 384
    dash_v = road_v & ~road_h & (np.abs(xx - CX + 0.5) <= 1.5) & ((yy % 48) < 26)
    dash_h = road_h & ~road_v & (np.abs(yy - CX + 0.5) <= 1.5) & ((xx % 48) < 26)
    paint(dash_v | dash_h)
    # edge lines (thin, very worn)
    for e in (R0 + 5, R1 - 6):
        paint(road_v & ~road_h & (xx == e), (150, 146, 132), 0.45)
        paint(road_h & ~road_v & (yy == e), (150, 146, 132), 0.45)
    # zebra crossings on each arm + stop lines
    Z0, Z1 = 20, 44          # distance from intersection
    zs = []
    for (ax, ay, horiz) in [(None, R0 - Z1, True), (None, R1 + Z1 - 24, True), (R0 - Z1, None, False), (R1 + Z1 - 24, None, False)]:
        if horiz:   # crossing a vertical road arm: stripes vertical
            y0 = ay
            m = road_v & ~road_h & (yy >= y0) & (yy < y0 + 24) & (((xx - R0 - 8) % 14) < 8) & (xx > R0 + 6) & (xx < R1 - 6)
        else:
            x0 = ax
            m = road_h & ~road_v & (xx >= x0) & (xx < x0 + 24) & (((yy - R0 - 8) % 14) < 8) & (yy > R0 + 6) & (yy < R1 - 6)
        paint(m, (184, 180, 164), 0.66)
    # stop lines
    paint(road_v & ~road_h & ((yy == R0 - 12) | (yy == R0 - 13)) & (xx < CX) & (xx > R0 + 4), WHITE, 0.6)
    paint(road_v & ~road_h & ((yy == R1 + 11) | (yy == R1 + 12)) & (xx > CX) & (xx < R1 - 4), WHITE, 0.6)
    paint(road_h & ~road_v & ((xx == R0 - 12) | (xx == R0 - 13)) & (yy > CX) & (yy < R1 - 4), WHITE, 0.6)
    paint(road_h & ~road_v & ((xx == R1 + 11) | (xx == R1 + 12)) & (yy < CX) & (yy > R0 + 4), WHITE, 0.6)
    # yellow box grid in the junction (faded)
    box = inter & (np.abs(xx - CX) < 40) & (np.abs(yy - CX) < 40)
    boxl = box & ((np.abs((xx - CX) - (yy - CX)) <= 1) | (np.abs((xx - CX) + (yy - CX)) <= 1) |
                  (np.abs(np.abs(xx - CX) - 39) <= 0.5) | (np.abs(np.abs(yy - CX) - 39) <= 0.5))

    # ------------------------------------------------------------ gutters + leaves in gutters
    dist_edge = np.minimum(
        np.where(road_v & ~road_h, np.minimum(xx - R0, R1 - 1 - xx), 999),
        np.where(road_h & ~road_v, np.minimum(yy - R0, R1 - 1 - yy), 999))
    gut = road & (dist_edge <= 4)
    t.mul(gut, 0.84)
    t.mul(road & (dist_edge <= 1), 0.72)
    t.leaves(gut, 0.14, seed=9)
    t.speckle(gut, 0.05, [(64, 58, 44), (76, 70, 50)], seed=19)

    # ------------------------------------------------------------ sidewalks
    walk_col = np.array((104, 101, 92.0))
    tn = np.random.default_rng(seed + 31)
    # tile coordinates: along-road 12px period, across 11px (2 tiles + 3px curb = 25px)
    along_v = yy // 12; along_h = xx // 12
    t.rgb[walk] = walk_col
    # per-tile shade
    tile_rand = tn.random((S // 12 + 2, 64))
    kv = np.ones((S, S))
    in_v = walk & ((xx >= SW0) & (xx < SW1))
    in_h = walk & ((yy >= SW0) & (yy < SW1)) & ~in_v
    across_v = np.where(xx < R0, (xx - SW0) // 11, (xx - R1 - 3) // 11)
    across_h = np.where(yy < R0, (yy - SW0) // 11, (yy - R1 - 3) // 11)
    kv[in_v] = 0.86 + 0.24 * tile_rand[(along_v[in_v]) % 64, (across_v[in_v] * 7 + 3) % 64]
    kv[in_h] = 0.86 + 0.24 * tile_rand[(along_h[in_h]) % 64, (across_h[in_h] * 11 + 5) % 64]
    t.mul(walk, kv)
    wn = fbm(S, S, 20, seed + 32, 3)
    t.mul(walk, 0.88 + 0.22 * wn)
    t.speckle(walk, 0.06, [(122, 118, 108), (84, 82, 74)], seed=33)
    # seams
    seam_along_v = in_v & ((yy % 12) == 0)
    seam_along_h = in_h & ((xx % 12) == 0)
    seam_x = in_v & ((xx == SW0 + 11) | (xx == R1 + 3 + 11))
    seam_y = in_h & ((yy == SW0 + 11) | (yy == R1 + 3 + 11))
    seams = seam_along_v | seam_along_h | seam_x | seam_y
    t.fill(seams, (66, 64, 58))
    # moss / weeds in seams
    t.speckle(seams, 0.30, MOSS, seed=34)
    t.leaves(walk & (lf > 0.55), 0.03, seed=35)
    # broken / missing / cracked tiles
    for _ in range(60):
        if rng.random() < 0.5:
            tx = rng.choice([SW0, SW0 + 11, R1 + 3, R1 + 14]); ty = rng.randrange(0, S // 12) * 12
            w_, h_ = 11, 12
        else:
            ty = rng.choice([SW0, SW0 + 11, R1 + 3, R1 + 14]); tx = rng.randrange(0, S // 12) * 12
            w_, h_ = 12, 11
        m = walk & t.mask_rect(tx + 1, ty + 1, tx + w_, ty + h_) & ~seams
        kind = rng.random()
        if kind < 0.35:
            t.crack(tx + 2, ty + rng.uniform(2, 9), 8, (58, 56, 50), None, 0.3, rng.uniform(-0.6, 0.6))
        elif kind < 0.6:      # sunken / stained
            t.mul(m, 0.78)
        elif kind < 0.8:      # missing tile -> dirt + weeds
            t.fill(m, (70, 60, 44))
            t.speckle(m, 0.35, MOSS + [(90, 104, 50)], seed=tx + ty)
            t.leaves(m, 0.15, seed=tx)
        else:                 # lifted tile edge
            e = m & (t.mask_rect(tx + 1, ty + 1, tx + w_, ty + 2))
            t.mul(e, 1.25)
    # outer edge stone (grass side) + overhanging grass
    outer = walk & (
        (in_v & ((xx == SW0) | (xx == SW1 - 1))) |
        (in_h & ((yy == SW0) | (yy == SW1 - 1))))
    t.fill(outer, (80, 78, 70))
    near = grass & (((xx >= SW0 - 3) & (xx < SW0)) | ((xx >= SW1) & (xx < SW1 + 3)) |
                    ((yy >= SW0 - 3) & (yy < SW0)) | ((yy >= SW1) & (yy < SW1 + 3)))
    t.mul(near, 0.78)
    over = walk & (((xx - SW0 < 2) & (xx >= SW0)) | ((SW1 - 1 - xx < 2) & (xx < SW1)) |
                   ((yy - SW0 < 2) & (yy >= SW0)) | ((SW1 - 1 - yy < 2) & (yy < SW1)))
    t.speckle(over, 0.28, [(66, 82, 42), (80, 96, 50)], seed=36)

    # ------------------------------------------------------------ curbs (3px stone on the sidewalk side)
    curb = walk & (
        (((xx >= R0 - 3) & (xx < R0)) | ((xx >= R1) & (xx < R1 + 3)) & ~road_h) & (~road_h) |
        ((((yy >= R0 - 3) & (yy < R0)) | ((yy >= R1) & (yy < R1 + 3))) & ~road_v))
    curb &= walk
    t.fill(curb, (132, 130, 120))
    t.mul(curb, 0.9 + 0.2 * wn)
    cseam = curb & ((((xx % 16) == 0) & ~(((xx >= R0 - 3) & (xx < R0)) | ((xx >= R1) & (xx < R1 + 3)))) |
                    (((yy % 16) == 0) & (((xx >= R0 - 3) & (xx < R0)) | ((xx >= R1) & (xx < R1 + 3)))))
    t.fill(cseam, (84, 82, 76))
    # top highlight / face shadow
    t.mul(curb & ((xx == R0 - 1) | (xx == R1) | (yy == R0 - 1) | (yy == R1)), 0.72)
    t.mul(curb & ((xx == R0 - 3) | (xx == R1 + 2) | (yy == R0 - 3) | (yy == R1 + 2)), 1.12)
    # chipped curb
    for _ in range(30):
        x0 = rng.randrange(S); m = curb & t.mask_rect(x0, 0, x0 + rng.randint(2, 5), S)
        m &= t.mask_rect(0, rng.randrange(S), S, 0) | True
    t.speckle(curb, 0.05, [(78, 76, 70)], seed=37)

    # ------------------------------------------------------------ drains + manholes
    def grate(x, y, w, h):
        m = t.mask_rect(x, y, x + w, y + h)
        t.fill(m, (46, 44, 42))
        for i in range(x + 1, x + w - 1, 2):
            t.fill(t.mask_rect(i, y + 1, i + 1, y + h - 1), (22, 22, 24))
        t.fill(m & ~t.mask_rect(x + 1, y + 1, x + w - 1, y + h - 1), (84, 80, 72))
    for yv in (96, 672):
        grate(R0 + 1, yv, 6, 10); grate(R1 - 7, yv + 40, 6, 10)
    for xv in (96, 672):
        grate(xv, R0 + 1, 10, 6); grate(xv + 40, R1 - 7, 10, 6)

    def manhole(cx, cy, r=6.5):
        rim = t.mask_ellipse(cx, cy, r + 1, r + 1)
        lid = t.mask_ellipse(cx, cy, r, r)
        t.fill(rim, (40, 40, 40))
        t.fill(lid, (74, 70, 64))
        t.mul(lid & t.mask_rect(0, 0, S, cy - r * 0.2), 1.1)
        for rr in (r * 0.7, r * 0.35):
            ring = t.mask_ellipse(cx, cy, rr, rr) & ~t.mask_ellipse(cx, cy, rr - 1, rr - 1)
            t.fill(ring, (52, 50, 46))
        t.fill(t.mask_rect(cx - r + 2, cy - 0.5, cx + r - 2, cy + 0.5), (52, 50, 46))
        t.speckle(lid, 0.12, [(110, 70, 40), (92, 60, 36)], seed=int(cx))
    manhole(355, 520); manhole(560, 402); manhole(196, 364); manhole(412, 150)

    # debris flecks on road + dirt along sidewalk edge
    t.speckle(road & ~gut & (lf > 0.6), 0.004, LEAF_ORANGE, seed=41)
    t.speckle(road, 0.0015, [(92, 84, 70)], seed=42)

    img = t.image()
    img.save(path)
    return img


if __name__ == '__main__':
    import sys
    build(sys.argv[1] if len(sys.argv) > 1 else '/tmp/ground.png')
