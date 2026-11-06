"""OSTATOK 1.48: the small vegetation of the world remodelled in Blender.

vegetation_v1.png (8 cells of 64 px: orange shrub, yellow shrub, green shrub,
grass tuft, reeds, leaf pile, fallen branch, dry weeds) is the most common
sprite outdoors - about a hundred per chunk - and was a flat 1x drawing. Each
cell is modelled (clumps of leaf masses, blades, stalks), rendered with the HD
pipeline and fitted into the same cell on the old ground line, so placement and
sway stay as they were.

    python3.13 tools/blender/vegetation_v2.py <project_dir>

Writes art/world_hd/vegetation_v2.png (512 x 64, same layout).
"""
import math
import os
import random
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import numpy as np
from PIL import Image, ImageDraw

import bk
from bk import box, cyl, mat, tube, sphere
from props_v20 import harden

RENDER = 60


def leafmass(cx, cy, cz, rx, ry, rz, cols, n, seed, size=(1.2, 2.4)):
    rnd = random.Random(seed)
    ms = [mat(c, rough=0.85, grime=0.25, scale=0.3) for c in cols]
    for i in range(n):
        u, v, w = rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)
        if u * u + v * v + w * w > 1:
            continue
        # upper side lighter: pick the colour by height
        k = min(len(ms) - 1, int((w + 1) * 0.5 * len(ms) + rnd.uniform(-0.6, 0.6)))
        sphere((cx + u * rx, cy + v * ry, cz + w * rz), rnd.uniform(*size), ms[max(0, k)], scale=(1, 1, 0.8))


def twigs(cx, cy, n, h, seed, col=(70, 52, 36)):
    rnd = random.Random(seed)
    m = mat(col, rough=0.9)
    for i in range(n):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(1, 4)
        tube([(cx, cy, 0), (cx + math.cos(a) * r, cy + math.sin(a) * r * 0.5, h * rnd.uniform(0.5, 1.0))], 0.25, m)


AUTUMN = [(120, 56, 22), (160, 74, 26), (192, 96, 34), (214, 124, 44)]
YELLOW = [(140, 110, 30), (178, 146, 44), (206, 176, 62), (226, 202, 96)]
GREEN = [(42, 58, 30), (56, 76, 36), (72, 94, 44), (92, 112, 54)]


def shrub(masses, cols, seed, twig_h=10):
    """many small leaves over a dark core: depth inside, a broken outline"""
    twigs(0, 0, 8, twig_h, seed)
    core = [tuple(int(v * 0.55) for v in cols[0])]
    for j, (cx, cy, cz, rx, ry, rz) in enumerate(masses):
        leafmass(cx, cy, cz, rx * 0.75, ry * 0.75, rz * 0.75, core, 40, seed + 50 + j, (1.6, 2.4))
        leafmass(cx, cy, cz, rx, ry, rz, cols, int(rx * ry * rz * 2.2), seed + j, (0.7, 1.3))


def orange_shrub():
    shrub([(-6, 0, 7, 9, 5, 6), (7, 1, 6, 8, 5, 5)], AUTUMN, 11)


def yellow_shrub():
    shrub([(0, 0, 8, 10, 6, 7), (-9, 2, 4, 5, 4, 4)], YELLOW, 21)


def green_shrub():
    shrub([(0, 0, 15, 8, 6, 10), (2, 1, 6, 7, 5, 5)], GREEN, 31, 16)


def blades(n, h, spread, cols, seed, lean=1.5, r=0.32):
    rnd = random.Random(seed)
    ms = [mat(c, rough=0.8, grime=0.2) for c in cols]
    for i in range(n):
        x, y = rnd.uniform(-spread, spread), rnd.uniform(-spread * 0.4, spread * 0.4)
        hh = h * rnd.uniform(0.55, 1.0)
        lx, ly = rnd.uniform(-lean, lean), rnd.uniform(-lean * 0.5, lean * 0.5)
        tube([(x, y, 0), (x + lx * 0.4, y + ly * 0.4, hh * 0.6), (x + lx, y + ly, hh)], r, ms[i % len(ms)])


def grass_tuft():
    blades(46, 7, 7, [(60, 80, 38), (78, 98, 46), (96, 114, 56), (120, 124, 64)], 41, 2.0)


def reeds():
    blades(34, 15, 6, [(96, 100, 54), (120, 116, 64), (140, 130, 76)], 51, 1.6, 0.3)
    rnd = random.Random(52)
    m = mat((110, 80, 48), rough=0.9)
    for i in range(6):
        x = rnd.uniform(-5, 5)
        cyl((x, 0, 13 + rnd.uniform(-1, 2)), 0.6, 2.6, m, bevel=0.2, verts=8)


def leaf_pile():
    rnd = random.Random(61)
    for i in range(80):
        x, y = rnd.gauss(0, 5), rnd.gauss(0, 2.4)
        d = math.hypot(x / 9, y / 4.5)
        if d > 1.1:
            continue
        z = (1.1 - d) * 3.0
        c = AUTUMN[rnd.randrange(len(AUTUMN))]
        sphere((x, y, z), rnd.uniform(1.0, 1.9), mat(c, rough=0.9, grime=0.3), scale=(1.3, 1.0, 0.35))


def fallen_branch():
    bark = mat((74, 56, 40), rough=0.95, grime=0.3, scale=0.2)
    tube([(-11, 1, 0.9), (-3, 0, 1.0), (4, -1, 1.1), (11, 0.5, 0.9)], 0.9, bark)
    tube([(-3, 0, 1.0), (0, 3, 1.4), (2, 5, 1.2)], 0.45, bark)
    tube([(4, -1, 1.1), (7, -3, 2.0), (9, -4, 2.4)], 0.4, bark)
    tube([(-7, 0.5, 1.0), (-9, -2.5, 1.6)], 0.35, bark)
    leafmass(9, -4, 2.4, 1.8, 1.2, 1.0, AUTUMN[1:], 12, 71, (0.6, 1.0))


def dry_weeds():
    blades(22, 10, 5, [(110, 86, 52), (132, 104, 62), (92, 70, 44)], 81, 2.4, 0.22)
    rnd = random.Random(82)
    m = mat((150, 120, 74), rough=0.9)
    for i in range(10):
        sphere((rnd.uniform(-5, 5), rnd.uniform(-1, 1), rnd.uniform(6, 10)), 0.6, m)


CELLS = [orange_shrub, yellow_shrub, green_shrub, None, None, None, None, None]   # the small ones stay drawn


def build(P):
    src = Image.open(os.path.join(P, 'vegetation_v1.png')).convert('RGBA')
    sheet = Image.new('RGBA', src.size)
    tmp = tempfile.mkdtemp(prefix='ostatok_veg2_')
    for i, fn in enumerate(CELLS):
        x0 = i * 64
        if fn is None:
            sheet.paste(src.crop((x0, 0, x0 + 64, 64)), (x0, 0))
            continue
        old = np.array(src.crop((x0, 0, x0 + 64, 64)))
        solid = old[..., 3] > 200          # the drawing without its soft shadow
        ys, xs = np.nonzero(solid)
        bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        bk.reset()
        bk.camera(RENDER, 46, 30)
        fn()
        raw = bk.render(os.path.join(tmp, '%d.png' % i))
        spr = bk.to_sprite(raw, RENDER, colours=0, outline=False, shadow=False)
        a = np.array(spr)
        sy, sx = np.nonzero(a[..., 3] > 0)
        spr = spr.crop((sx.min(), sy.min(), sx.max() + 1, sy.max() + 1))
        tw, th = bx1 - bx0 + 4, by1 - 2
        k = min(tw / spr.width, th / spr.height)
        nw, nh = max(1, int(round(spr.width * k))), max(1, int(round(spr.height * k)))
        arr = np.array(spr).astype(float)
        arr[..., :3] *= arr[..., 3:4] / 255.0
        pm = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA').resize((nw, nh), Image.LANCZOS)
        arr = np.array(pm).astype(float)
        al = np.maximum(arr[..., 3:4], 1)
        arr[..., :3] = np.clip(arr[..., :3] * 255.0 / al, 0, 255)
        fitted = Image.new('RGBA', (nw + 2, nh + 2))
        fitted.paste(Image.fromarray(arr.astype(np.uint8), 'RGBA'), (1, 1))
        fitted = harden(fitted, 20)
        cell = Image.new('RGBA', (64, 64))
        # a soft contact shadow under the plant, as the old cells had
        sh = Image.new('RGBA', (64, 64))
        d = ImageDraw.Draw(sh)
        cx = (bx0 + bx1) // 2
        hw = max(6, int(nw * 0.42))
        d.ellipse((cx - hw + 3, by1 - 4, cx + hw + 3, by1 + 1), fill=(8, 10, 10, 80))
        cell.alpha_composite(sh)
        cell.alpha_composite(fitted, (max(0, int(cx - fitted.width // 2)), max(0, int(by1 - fitted.height))))
        sheet.paste(cell, (x0, 0))
        print('veg', i, fn.__name__, fitted.size, flush=True)
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, 'vegetation_v2.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
