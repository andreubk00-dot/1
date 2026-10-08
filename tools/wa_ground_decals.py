"""OSTATOK ground decals (HD pixel art, 2 texels per world unit, drawn at 0.5).

Loose rubble, blood, papers, glass and oil on the street. Drawn as crisp pixel
art: hard edges, a lit top-left side and a shadow bottom-right, no
anti-aliasing. The game only flips them (never rotates by arbitrary angles,
which breaks pixel art into jaggies).

    python3 tools/wa_ground_decals.py <project_dir>

Writes art/world_hd/ground_decals_hd.png: one row of 96 x 64 texel cells,
kinds in DECAL_KINDS order (see main_script_mod.gd GROUND_DECAL_KINDS).
"""
import math
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

CW, CH = 96, 64
DECAL_KINDS = ['rubble_a', 'rubble_b', 'rubble_c', 'blood_a', 'blood_b', 'blood_dry',
               'papers_a', 'papers_b', 'glass', 'oil']

BRICK = [(122, 58, 44), (138, 70, 52), (104, 50, 40)]
CONCRETE = [(126, 124, 116), (110, 108, 100), (142, 138, 128)]
SHADOW = (18, 18, 16, 110)


def shade(c, k):
    return tuple(int(max(0, min(255, v * k))) for v in c[:3]) + (255,)


def chunk(draw, cx, cy, r, col, rng, sides=None):
    sides = sides or rng.integers(4, 7)
    a0 = rng.uniform(0, math.tau)
    pts = []
    for i in range(sides):
        a = a0 + math.tau * i / sides + rng.uniform(-0.3, 0.3)
        rr = r * rng.uniform(0.7, 1.15)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.7))
    # shadow, body, then lit top-left facets
    draw.polygon([(x + 2, y + 2) for x, y in pts], fill=SHADOW)
    draw.polygon(pts, fill=shade(col, 1.0))
    top = [p for p in pts if p[1] < cy]
    if len(top) >= 2:
        draw.line(top, fill=shade(col, 1.3), width=1)
    bot = [p for p in pts if p[1] >= cy]
    if len(bot) >= 2:
        draw.line(bot, fill=shade(col, 0.66), width=1)


def rubble(seed, brick_share):
    rng = np.random.default_rng(seed)
    im = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # dust under the pile
    for _ in range(140):
        x, y = rng.normal(CW / 2, 16), rng.normal(CH / 2 + 4, 8)
        d.point((x, y), fill=(84, 80, 72, 150))
    for _ in range(int(rng.integers(13, 19))):
        cx, cy = rng.normal(CW / 2, 12), rng.normal(CH / 2 + 2, 6)
        col = BRICK[rng.integers(0, 3)] if rng.random() < brick_share else CONCRETE[rng.integers(0, 3)]
        chunk(d, cx, cy, rng.uniform(3.5, 8.0), col, rng)
    for _ in range(24):                                  # grit
        x, y = rng.normal(CW / 2, 20), rng.normal(CH / 2 + 3, 10)
        d.point((x, y), fill=shade(CONCRETE[rng.integers(0, 3)], rng.uniform(0.7, 1.2)))
    return im


def blob_mask(rng, rx, ry, rough):
    yy, xx = np.mgrid[0:CH, 0:CW].astype(float)
    cx, cy = CW / 2 + rng.uniform(-6, 6), CH / 2 + rng.uniform(-4, 4)
    ang = np.arctan2(yy - cy, xx - cx)
    rad = np.ones_like(ang)
    for k in range(2, 7):
        rad += rough / k * np.sin(k * ang + rng.uniform(0, math.tau))
    dist = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    return dist < rad, cx, cy


def blood(seed, dry=False):
    rng = np.random.default_rng(seed)
    base = np.array((92, 14, 16)) if not dry else np.array((70, 30, 22))
    m, cx, cy = blob_mask(rng, rng.uniform(14, 20), rng.uniform(8, 12), 0.35)
    a = np.zeros((CH, CW, 4), np.uint8)
    core, _, _ = blob_mask(np.random.default_rng(seed), 9, 5, 0.25)
    a[m] = np.r_[base * 1.15, 255]
    a[m & core] = np.r_[base * 0.8, 255]
    # rim: one texel lighter along the top-left edge (wet sheen)
    lit = m & ~np.roll(m, 1, 0) | m & ~np.roll(m, 1, 1)
    a[lit] = np.r_[np.minimum(base * 1.6, 255), 255]
    im = Image.fromarray(a, 'RGBA')
    d = ImageDraw.Draw(im)
    for _ in range(int(rng.integers(8, 16))):             # droplets thrown outwards
        ang = rng.uniform(0, math.tau)
        r = rng.uniform(18, 34)
        x, y = cx + math.cos(ang) * r, cy + math.sin(ang) * r * 0.6
        s = rng.integers(1, 3)
        d.rectangle([x, y, x + s - 1, y + s - 1], fill=tuple(int(v) for v in base) + (255,))
    if not dry:
        d.point((cx - 4, cy - 3), fill=(190, 80, 80, 255))
    return im


def papers(seed):
    rng = np.random.default_rng(seed)
    im = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(int(rng.integers(3, 6))):
        cx, cy = rng.normal(CW / 2, 14), rng.normal(CH / 2, 7)
        w, h = rng.uniform(9, 14), rng.uniform(6, 9)
        a = rng.choice([-0.35, 0.0, 0.3, 0.5])
        ca, sa = math.cos(a), math.sin(a)
        pts = [(cx + ca * x - sa * y, cy + (sa * x + ca * y) * 0.75) for x, y in ((-w, -h), (w, -h), (w, h), (-w, h))]
        pts = [(round(x), round(y)) for x, y in pts]
        tone = rng.uniform(0.78, 1.0)
        d.polygon([(x + 1, y + 2) for x, y in pts], fill=(20, 20, 18, 90))
        d.polygon(pts, fill=(int(200 * tone), int(196 * tone), int(178 * tone), 255))
        for k in range(1, 4):                              # print lines
            t = k / 4.0
            p0 = (pts[0][0] + (pts[3][0] - pts[0][0]) * t + 2, pts[0][1] + (pts[3][1] - pts[0][1]) * t)
            p1 = (pts[1][0] + (pts[2][0] - pts[1][0]) * t - 2, pts[1][1] + (pts[2][1] - pts[1][1]) * t)
            d.line([p0, p1], fill=(int(120 * tone), int(118 * tone), int(108 * tone), 255))
    return im


def glass(seed):
    rng = np.random.default_rng(seed)
    im = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(26):
        x, y = rng.normal(CW / 2, 14), rng.normal(CH / 2, 7)
        s = rng.integers(1, 4)
        d.polygon([(x, y), (x + s, y + rng.integers(0, 2)), (x + rng.integers(0, 2), y + s)], fill=(150, 176, 178, 220))
        d.point((x, y), fill=(226, 240, 240, 255))
    return im


def oil(seed):
    rng = np.random.default_rng(seed)
    m, cx, cy = blob_mask(rng, rng.uniform(18, 24), rng.uniform(9, 12), 0.3)
    a = np.zeros((CH, CW, 4), np.uint8)
    a[m] = (26, 26, 30, 200)
    inner, _, _ = blob_mask(np.random.default_rng(seed + 1), 10, 5, 0.3)
    a[m & inner] = (36, 34, 46, 210)
    sheen = m & (np.random.default_rng(seed + 2).random((CH, CW)) < 0.03)
    a[sheen] = (70, 62, 96, 220)
    return Image.fromarray(a, 'RGBA')


def build(P):
    makers = {'rubble_a': lambda: rubble(11, 0.6), 'rubble_b': lambda: rubble(12, 0.15),
              'rubble_c': lambda: rubble(13, 0.9), 'blood_a': lambda: blood(21),
              'blood_b': lambda: blood(22), 'blood_dry': lambda: blood(23, True),
              'papers_a': lambda: papers(31), 'papers_b': lambda: papers(32),
              'glass': lambda: glass(41), 'oil': lambda: oil(51)}
    sheet = Image.new('RGBA', (CW * len(DECAL_KINDS), CH), (0, 0, 0, 0))
    for i, k in enumerate(DECAL_KINDS):
        sheet.alpha_composite(makers[k](), (i * CW, 0))
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, 'ground_decals_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
