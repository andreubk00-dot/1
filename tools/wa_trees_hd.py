"""OSTATOK HD trees: hand-style pixel art at 2 texels per world unit.

tree_v3 was drawn at ~1.3 texels per world unit, coarser than everything else
in the HD world. These are drawn the way pixel artists build trees: the crown
is a stack of leaf clusters, each shaded as a lumpy sphere in 4-5 flat tones lit
from the shared OSTATOK light (top-left), with a dark outline on the outside of
the silhouette only, a few sky-lit highlight texels and the trunk showing
between clusters. No gradients, no anti-aliasing.

    python3 tools/wa_trees_hd.py <project_dir>

Writes art/world_hd/trees_hd.png: cells of 132 x 204 texels, birch, maple, pine
and a second individual of each (cell = tree_v3 variant + 3 * alt). The game draws a cell at scale 0.5 in place of the 88 x 136
tree_v3 region at scale 0.75 (same world size, same anchor).
"""
import math
import os
import sys
import numpy as np
from PIL import Image

CW, CH = 132, 204
GROUND = 186            # texel row of the trunk base (matches tree_v3 anchor)
L = np.array([-0.55, -0.62, 0.56])
L /= np.linalg.norm(L)
OUTLINE = (22, 24, 20)


def ramp(c0, n=5, lo=0.5, hi=1.3, hue_shift=(-8, 4, 14)):
    """light -> dark tones; shadows drift cool, lights drift warm (pixel-art ramp)."""
    out = []
    for i in range(n):
        t = i / (n - 1)
        k = hi + (lo - hi) * t
        shift = np.array(hue_shift) * (t - 0.4)
        out.append(np.clip(np.array(c0) * k + shift, 0, 255))
    return out


class Canvas:
    def __init__(self):
        self.rgb = np.zeros((CH, CW, 3))
        self.a = np.zeros((CH, CW), bool)
        self.part = np.zeros((CH, CW), np.int8)      # 1 trunk, 2 leaves

    def put(self, m, col, part):
        self.rgb[m] = col
        self.a[m] = True
        self.part[m] = part


def noise2(rng, h, w, cell):
    g = rng.random((h // cell + 2, w // cell + 2))
    yy, xx = np.mgrid[0:h, 0:w] / cell
    i, j = yy.astype(int), xx.astype(int)
    fy, fx = yy - i, xx - j
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = g[i, j] * (1 - fx) + g[i, j + 1] * fx
    b = g[i + 1, j] * (1 - fx) + g[i + 1, j + 1] * fx
    return a * (1 - fy) + b * fy


def trunk(cv, x0, top, w0, w1, col, rng, birch=False):
    ys = np.arange(top, GROUND + 1)
    tones = ramp(col, 4, 0.55, 1.2)
    for y in ys:
        t = (y - top) / max(1, GROUND - top)
        w = w1 + (w0 - w1) * t
        lean = 1.5 * math.sin(y * 0.09)
        xl, xr = int(round(x0 - w / 2 + lean)), int(round(x0 + w / 2 + lean))
        for x in range(xl, xr + 1):
            u = (x - xl) / max(1, xr - xl)
            k = 0 if u < 0.3 else (1 if u < 0.6 else 2)
            if x in (xl, xr):
                k = 3
            c = tones[k]
            if birch and rng.random() < 0.09:
                c = (40, 38, 34)
            cv.rgb[y, x] = c
            cv.a[y, x] = True
            cv.part[y, x] = 1
    # root flare
    for dx in (-1, 1):
        for k in range(3):
            x = int(x0 + dx * (w0 / 2 + 1 + k))
            cv.rgb[GROUND - k, x] = tones[2]
            cv.a[GROUND - k, x] = True
            cv.part[GROUND - k, x] = 1


def branch(cv, p0, p1, w, col):
    n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]))) + 1
    tones = ramp(col, 4, 0.55, 1.15)
    for i in range(n):
        t = i / max(1, n - 1)
        x, y = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
        ww = max(1, int(round(w * (1 - 0.6 * t))))
        for k in range(ww):
            xi, yi = int(round(x + k - ww / 2)), int(round(y))
            if 0 <= xi < CW and 0 <= yi < CH:
                cv.rgb[yi, xi] = tones[1 if k < ww - 1 else 2]
                cv.a[yi, xi] = True
                cv.part[yi, xi] = 1


def blocky(rng, h, w, cell=2):
    g = rng.random((h // cell + 1, w // cell + 1))
    return np.repeat(np.repeat(g, cell, 0), cell, 1)[:h, :w]


def cluster(cv, cx, cy, r, tones, rng, density=1.0, ry=None, k_off=0, mass=False):
    """one leaf clump: a lumpy sphere shaded in flat tones, with 2x2 leaf
    texture breaking the tone bands and a ragged leafy rim."""
    ry = ry or r * 0.86
    y0, y1 = int(cy - ry - 4), int(cy + ry + 4)
    x0, x1 = int(cx - r - 4), int(cx + r + 4)
    h, w = y1 - y0 + 1, x1 - x0 + 1
    lump = noise2(rng, h, w, 4)
    leaf = blocky(rng, h, w, 2)
    for y in range(max(0, y0), min(CH, y1 + 1)):
        for x in range(max(0, x0), min(CW, x1 + 1)):
            dx, dy = (x - cx) / r, (y - cy) / ry
            d = dx * dx + dy * dy
            lv = leaf[y - y0, x - x0]
            edge = 0.72 + 0.34 * lump[y - y0, x - x0] + 0.22 * (lv - 0.5)
            if d > edge:
                continue
            if density < 1.0 and d > 0.4 and lv > density:
                continue
            if mass:
                cv.rgb[y, x] = tones[-1]
                cv.a[y, x] = True
                cv.part[y, x] = 2
                continue
            nz = math.sqrt(max(0.0, 1 - min(d, 1.0)))
            n = np.array([dx, dy, nz + 0.3])
            n /= np.linalg.norm(n)
            lit = float(n @ L) + 0.34 * (lv - 0.5) + 0.12 * (lump[y - y0, x - x0] - 0.5)
            k = 0 if lit > 0.8 else 1 if lit > 0.5 else 2 if lit > 0.18 else 3
            k = min(len(tones) - 1, k + k_off)
            cv.rgb[y, x] = tones[k]
            cv.a[y, x] = True
            cv.part[y, x] = 2


def crown_spots(rng, cx, cy, rx, ry, n_big, n_small, rbig=(10, 16), rsmall=(5, 8)):
    """irregular crown: big clumps scattered inside an ellipse (no grid),
    small tufts along the rim so the silhouette is ragged, not round."""
    spots = []
    tries = 0
    while len(spots) < n_big and tries < 4000:
        tries += 1
        a, rr = rng.uniform(0, math.tau), math.sqrt(rng.uniform(0, 1))
        x, y = cx + math.cos(a) * rr * rx * 0.78, cy + math.sin(a) * rr * ry * 0.78
        r = rng.uniform(*rbig)
        if all((x - u) ** 2 + (y - v) ** 2 > (0.42 * (r + w)) ** 2 for u, v, w in spots):
            spots.append((x, y, r))
    for _ in range(n_small):
        a = rng.uniform(0, math.tau)
        x, y = cx + math.cos(a) * rx * rng.uniform(0.82, 1.0), cy + math.sin(a) * ry * rng.uniform(0.8, 1.0)
        spots.append((x, y, rng.uniform(*rsmall)))
    return spots


def holes(cv, rng, spots, tones, n, branch_col):
    """sky / shadow gaps inside the crown with a limb showing through."""
    for _ in range(n):
        x, y, r = spots[rng.integers(0, len(spots))]
        hx, hy = int(x + rng.uniform(-r, r) * 0.5), int(y + rng.uniform(0, r) * 0.6)
        for yy in range(hy - 2, hy + 3):
            for xx in range(hx - 3, hx + 4):
                if 0 <= yy < CH and 0 <= xx < CW and cv.part[yy, xx] == 2 and (xx - hx) ** 2 / 9 + (yy - hy) ** 2 / 4 < 1:
                    cv.rgb[yy, xx] = tones[-1] * 0.8
        for k in range(-3, 4):
            yy, xx = hy + k // 2, hx + k
            if 0 <= yy < CH and 0 <= xx < CW and cv.part[yy, xx] == 2:
                cv.rgb[yy, xx] = branch_col


def crown(cv, spots, tones, rng, density=1.0):
    """dark crown mass first, then clumps from back (top) to front (bottom),
    lit clumps last on the upper-left - the classic pixel-art tree build."""
    for (x, y, r) in spots:
        cluster(cv, x, y, r * 1.08, tones, rng, density, mass=True)
    for (x, y, r) in sorted(spots, key=lambda s: s[1]):
        cluster(cv, x, y, r * 0.86, tones, rng, density, k_off=1)
    for (x, y, r) in spots:
        if x < CW / 2 + 6 and y < 120:
            cluster(cv, x - r * 0.22, y - r * 0.24, r * 0.5, tones, rng, density)


def finish(cv, rng, speck_cols=(), speck=0.0):
    img = np.zeros((CH, CW, 4), np.uint8)
    a = cv.a
    # outline on the outside of the silhouette (selective: lighter on the lit side)
    out = np.zeros_like(a)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        out |= np.roll(np.roll(a, dy, 0), dx, 1)
    out &= ~a
    rgb = cv.rgb.copy()
    # ground shadow (drawn first, under everything)
    yy, xx = np.mgrid[0:CH, 0:CW]
    sh = (((xx - CW / 2 - 8) / 42.0) ** 2 + ((yy - GROUND - 2) / 9.0) ** 2) < 1.0
    img[sh] = (10, 14, 10, 96)
    img[out] = OUTLINE + (255,)
    # the lit (top-left) outline is softened into the darkest leaf tone
    lit_out = out & ~np.roll(np.roll(a, -1, 0), -1, 1) & (np.roll(a, 1, 0) | np.roll(a, 1, 1))
    img[lit_out] = (44, 46, 36, 255)
    img[a, :3] = np.clip(rgb[a], 0, 255).astype(np.uint8)
    img[a, 3] = 255
    # falling / lying leaves
    for _ in range(int(speck * 100)):
        x, y = int(rng.normal(CW / 2, 26)), int(rng.normal(GROUND - 2, 4) if rng.random() < 0.6 else rng.uniform(40, GROUND))
        if 0 <= x < CW - 1 and 0 <= y < CH and img[y, x, 3] < 200 and speck_cols:
            img[y, x] = tuple(int(v) for v in speck_cols[rng.integers(0, len(speck_cols))]) + (255,)
    return Image.fromarray(img, 'RGBA')


def birch(seed=3):
    rng = np.random.default_rng(seed)
    cv = Canvas()
    tones = ramp((222, 182, 62), 5, 0.46, 1.16, (-12, 0, 22))
    trunk(cv, CW / 2 - 2, 64, 9, 4, (216, 212, 198), rng, birch=True)
    for (a, b) in (((63, 112), (40, 96)), ((63, 100), (88, 84)), ((62, 88), (50, 70)), ((63, 80), (78, 62))):
        branch(cv, a, b, 2, (206, 202, 188))
    # a birch crown is loose and drooping: narrow, tall, see-through
    spots = crown_spots(rng, 62, 74, 36, 54, 18, 14, (8, 12), (4, 6))
    crown(cv, spots, tones, rng, density=0.8)
    holes(cv, rng, spots, tones, 6, (214, 208, 192))
    return finish(cv, rng, [tones[0], tones[2], (196, 120, 40)], 0.5)


def maple(seed=5):
    rng = np.random.default_rng(seed)
    cv = Canvas()
    trunk(cv, CW / 2, 100, 13, 8, (92, 66, 46), rng)
    for (a, b) in (((66, 116), (38, 90)), ((66, 110), (98, 84)), ((66, 104), (62, 70))):
        branch(cv, a, b, 4, (86, 62, 44))
    tones = ramp((210, 108, 36), 5, 0.44, 1.14, (-14, -2, 16))
    spots = crown_spots(rng, 66, 80, 54, 46, 20, 16, (11, 17), (5, 8))
    crown(cv, spots, tones, rng, density=0.97)
    holes(cv, rng, spots, tones, 5, (70, 50, 36))
    return finish(cv, rng, [tones[0], tones[1], tones[3]], 0.8)


def pine(seed=7):
    rng = np.random.default_rng(seed)
    cv = Canvas()
    trunk(cv, CW / 2, 150, 7, 5, (82, 58, 42), rng)
    tones = ramp((40, 74, 48), 5, 0.5, 1.3, (-6, 4, 12))
    tiers = 9
    top, bottom = 14, 170
    pine_tex = blocky(rng, CH, CW, 2)
    for i in range(tiers):
        t = i / (tiers - 1)
        cy = top + (bottom - top) * t
        half = 7 + 46 * t + 4 * math.sin(i * 2.3)
        hgt = 22 + 6 * t
        # one tier: a drooping skirt of needles, lit on the upper-left
        for y in range(int(cy - hgt), int(cy + 5)):
            if not 0 <= y < CH:
                continue
            v = (y - (cy - hgt)) / (hgt + 5)
            w = half * min(1.0, v * 1.25)
            for x in range(int(CW / 2 - w - 2), int(CW / 2 + w + 3)):
                if not 0 <= x < CW:
                    continue
                u = (x - CW / 2) / max(1.0, w)
                # ragged needle fringe along the lower edge
                fringe = cy + 3 - 4 * abs(u) ** 1.6 + (2.5 * math.sin(x * 1.3 + i * 2.1) + 2.0 * math.sin(x * 0.53 + i)) * (abs(u) > 0.15)
                if abs(u) > 1.0 or y > fringe:
                    continue
                lit = -0.6 * u - 0.45 * (1 - v) + 0.3 * (pine_tex[y, x] - 0.5)
                k = 0 if lit > 0.35 else 1 if lit > 0.0 else 2 if lit > -0.35 else 3
                if y > fringe - 2.5:
                    k = 4
                cv.rgb[y, x] = tones[k]
                cv.a[y, x] = True
                cv.part[y, x] = 2
    return finish(cv, rng, [(150, 104, 54), (120, 84, 46)], 0.25)


def build(P):
    # row of 6: birch, maple, pine, then a second individual of each
    sheet = Image.new('RGBA', (CW * 6, CH), (0, 0, 0, 0))
    for i, (fn, seed) in enumerate(((birch, 3), (maple, 5), (pine, 7), (birch, 13), (maple, 15), (pine, 17))):
        sheet.alpha_composite(fn(seed), (i * CW, 0))
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, 'trees_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
