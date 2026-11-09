"""OSTATOK 1.51: rooftop equipment remodelled in Blender.

roof_props_hd.png (AC unit, vent stacks, air handler, antenna mast) and
roof_details_hd.png (water tank, satellite dish, stair housing, pipe run,
puddle, debris, small vents, skylights) were washed-out flat drawings. Each is
modelled at real size, rendered with the HD pipeline and fitted into the same
128 px cell, on the old ground line and within the old width, so placement is
unchanged. The puddle and the empty debris cell are copied as they are.

    python3.13 tools/blender/roof_props_v2.py <project_dir>

Writes art/world_hd/roof_props_v2.png and art/world_hd/roof_details_v2.png.
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
from PIL import Image

import bk
from bk import box, cyl, mat, tube, sphere, mesh
from props_v20 import harden, steel, paint

RENDER = 80


def galv(c=(150, 154, 150)):
    return mat(c, rough=0.45, metal=0.55, grime=0.45, dust=0.35, scale=0.12)


def rust_col():
    return mat((120, 64, 36), rough=0.9, grime=0.3)


# ------------------------------------------------------------- roof_props
def ac_unit():
    body = paint((196, 194, 182), grime=0.5)
    box((0, 0, 7), (12, 7, 7), body, bevel=0.6)
    box((0, 0, 14.2), (12.2, 7.2, 0.3), paint((176, 174, 162)), bevel=0.2)
    cyl((4, 0, 14.3), 5.0, 0.5, mat((50, 52, 52), rough=0.5, metal=0.4), bevel=0.2, verts=24)   # fan grille
    for a in range(4):
        t = a * math.pi / 2
        box((4 + math.cos(t) * 2.2, math.sin(t) * 2.2, 14.9), (2.0, 0.6, 0.1), steel((90, 92, 90)), bevel=0, rot=(0, 0, t))
    for x in range(-10, -2, 2):                       # louvres on the front
        box((x, 7.1, 7), (0.4, 0.15, 5.5), mat((150, 148, 138), rough=0.6), bevel=0)
    box((-6, 7.2, 1.5), (5, 0.3, 0.6), mat((200, 160, 40), rough=0.6), bevel=0)     # label
    tube([(12, 3, 3), (15, 3, 3), (15, -5, 1)], 0.6, galv((120, 120, 116)))          # pipes
    tube([(12, 1, 2), (16, 1, 2), (16, -6, 0.6)], 0.5, mat((30, 30, 30), rough=0.8))
    for x in (-10, 10):
        box((x, 0, 0.4), (1.2, 7.5, 0.4), galv((100, 100, 96)), bevel=0)            # rails
    sphere((-8, 5, 0.3), 3, rust_col(), scale=(1.5, 0.8, 0.1))                        # rust stain


def vent_stacks():
    base = paint((150, 150, 142), grime=0.6)
    box((0, 0, 3), (10, 7, 3), base, bevel=0.6)
    for (x, y, r, h) in ((-4, -1, 2.4, 20), (3, 2, 2.0, 14), (6, -3, 1.6, 10)):
        cyl((x, y, 6), r, h, galv(), bevel=0.3, verts=18)
        cyl((x, y, 6 + h), r + 1.2, 1.4, galv((130, 134, 130)), bevel=0.4, verts=18)   # rain cap
        cyl((x, y, 6 + h + 1.4), r * 0.5, 1.8, galv((120, 124, 120)), bevel=0.2, verts=12)
        sphere((x, y, 6 + h * 0.4), r * 1.02, mat((60, 60, 58), rough=0.9), scale=(1, 1, 0.2))   # soot band
    sphere((-4, -1, 27.6), 2.2, mat((40, 40, 38), rough=1.0), scale=(1.4, 1.4, 0.6))   # soot on the cap


def air_handler():
    blue = mat((70, 104, 132), rough=0.5, metal=0.3, grime=0.5, dust=0.3)
    box((-4, 0, 8), (9, 8, 8), blue, bevel=0.6)
    for x in range(-12, 5, 2):
        box((x, 8.1, 8), (0.5, 0.15, 6.5), mat((56, 84, 108), rough=0.6), bevel=0)     # louvres
    box((10, 0, 5), (5, 6, 5), paint((190, 188, 176)), bevel=0.5)                      # control box
    box((10, 6.1, 6), (2.5, 0.2, 2.2), mat((60, 60, 60), rough=0.5), bevel=0.1)
    tube([(5, -4, 12), (8, -4, 12), (8, -4, 15), (14, -4, 15)], 1.6, galv())          # duct
    for x in (-12, 4):
        box((x, 0, 0.4), (1, 8.5, 0.4), galv((100, 100, 96)), bevel=0)


def antenna_mast():
    st = galv((150, 154, 150))
    for (x, y) in ((-5, -3), (5, -3), (0, 4)):
        tube([(x, y, 0), (0, 0, 30)], 0.45, st)                                         # tripod
    cyl((0, 0, 0), 0.7, 52, st, bevel=0, verts=10)
    for z, w in ((36, 7), (42, 5.5), (48, 4)):
        box((0, 0, z), (w, 0.3, 0.3), st, bevel=0)                                     # TV antenna arms
        for x in (-w, w):
            box((x, 1.2, z), (0.25, 1.2, 0.25), st, bevel=0)
    # a dish on the mast
    cyl((4, 2.5, 26), 5.5, 0.8, mat((220, 220, 214), rough=0.4), axis='y', bevel=0.6, verts=26, rot=(math.pi / 2 - 0.4, 0, 0.3))
    tube([(4, 2.5, 26), (4, 7, 25)], 0.3, st)
    box((0, 0, 1.5), (5, 4, 1.5), paint((140, 140, 132)), bevel=0.4)                 # ballast block


# ----------------------------------------------------------- roof_details
def water_tank():
    tank = mat((92, 118, 150), rough=0.5, metal=0.35, grime=0.5, dust=0.3)
    cyl((0, 0, 6), 9, 18, tank, bevel=1.2, verts=32)
    for z in (11, 19):
        cyl((0, 0, z), 9.2, 0.8, mat((70, 92, 120), rough=0.5, metal=0.4), bevel=0.2, verts=32)   # hoops
    sphere((0, 0, 24), 9, tank, scale=(1, 1, 0.3))
    cyl((0, 0, 26.2), 1.8, 1.2, galv(), bevel=0.2)
    for (x, y) in ((-6, -6), (6, -6), (-6, 6), (6, 6)):
        box((x, y, 3), (0.6, 0.6, 3), galv((100, 100, 96)), bevel=0)               # legs
    tube([(0, 9, 4), (0, 13, 4), (0, 13, 0.4)], 0.7, galv())
    for (z, r) in ((8, 1.6), (15, 1.2)):
        sphere((-5, 7.8, z), r, rust_col(), scale=(1.2, 0.2, 2.0))                  # rust runs


def sat_dish():
    cyl((0, 0, 0), 1.0, 10, galv(), bevel=0.2, verts=12)
    box((0, 0, 0.8), (3, 3, 0.8), paint((140, 140, 132)), bevel=0.3)
    cyl((0, 3, 13), 7.5, 1.0, mat((226, 224, 218), rough=0.35, grime=0.3), axis='y', bevel=0.8, verts=30, rot=(math.pi / 2 - 0.5, 0, 0.2))
    tube([(0, 3, 10), (0, 9, 12), (0, 8, 15)], 0.3, galv())
    box((0, 8.6, 15.4), (1, 1, 0.8), mat((40, 40, 40), rough=0.6), bevel=0.2)     # LNB
    tube([(0, 0, 1), (-6, 2, 0.4), (-12, 3, 0.4)], 0.3, mat((30, 30, 30), rough=0.8))


def stair_housing():
    wall = paint((150, 148, 138), grime=0.6)
    box((0, 0, 11), (15, 13, 11), wall, bevel=0.4)
    box((0, 0, 22.4), (15.6, 13.6, 0.5), mat((52, 52, 50), rough=0.85), bevel=0.2)   # tar roof
    box((-4, 13.1, 8), (4.5, 0.3, 8), mat((92, 80, 64), rough=0.7, metal=0.3, grime=0.5), bevel=0.2)   # steel door
    box((-1, 13.5, 8), (0.3, 0.3, 0.8), steel((170, 170, 160)), bevel=0)
    box((8, 13.1, 15), (3, 0.2, 2.4), mat((40, 50, 56), rough=0.2), bevel=0.2)      # small window
    cyl((10, -6, 22.9), 1.6, 5, galv(), bevel=0.2, verts=14)                          # vent pipe
    sphere((5, 13.0, 3), 3, mat((96, 94, 86), rough=1.0), scale=(1.5, 0.15, 1))     # water stain
    box((0, 13.2, 21), (15, 0.3, 0.6), mat((120, 118, 108), rough=0.8), bevel=0)    # drip edge


def pipe_run():
    p = galv((140, 144, 140))
    tube([(-22, 0, 3), (14, 0, 3)], 1.4, p)
    tube([(-22, 3.5, 2.5), (8, 3.5, 2.5)], 1.0, mat((40, 40, 40), rough=0.8))
    tube([(14, 0, 3), (16, 0, 3), (16, 0, 14)], 1.4, p)
    cyl((16, 0, 14), 2.2, 1.2, galv((120, 124, 120)), bevel=0.3, verts=16)
    for x in (-16, -4, 8):
        box((x, 1.5, 1), (1.2, 4, 1), paint((130, 128, 120)), bevel=0.2)            # sleepers
    box((-8, 0, 3), (1.6, 1.8, 1.8), mat((150, 70, 40), rough=0.6), bevel=0.3)       # a valve
    cyl((-8, 0, 5), 1.6, 0.4, mat((170, 40, 30), rough=0.5), bevel=0.1, verts=12)
    sphere((2, 0, 3.2), 1.5, rust_col(), scale=(2, 1, 0.8))


def vent_small():
    for (x, y, h) in ((-5, -2, 8), (4, 1, 11), (0, 5, 6)):
        cyl((x, y, 0), 1.6, h, galv(), bevel=0.2, verts=14)
        cyl((x, y, h), 2.6, 1.0, galv((128, 132, 128)), bevel=0.3, verts=14)
        sphere((x, y, h + 1.6), 1.6, galv((120, 124, 120)), scale=(1, 1, 0.6))


def skylight_row():
    frame = galv((120, 124, 120))
    for i, x in enumerate((-16, 0, 16)):
        box((x, 0, 2), (6.5, 6.5, 2), paint((140, 140, 132)), bevel=0.4)            # kerb
        glass = mat((86, 120, 140), rough=0.12) if i != 1 else mat((30, 34, 36), rough=0.4)   # one broken
        box((x, 0, 4.4), (6, 6, 0.3), glass, bevel=0.1, rot=(0.25, 0, 0))
        box((x, 0, 4.6), (0.3, 6, 0.4), frame, bevel=0, rot=(0.25, 0, 0))
        box((x, 0, 4.6), (6, 0.3, 0.4), frame, bevel=0, rot=(0.25, 0, 0))
    for (x, y) in ((-1, -2), (2, 3), (-3, 2)):
        box((x, y, 4.8), (1.2, 0.8, 0.2), mat((100, 140, 160), rough=0.1), bevel=0, rot=(0, 0, x))   # shards


PROPS = [ac_unit, vent_stacks, air_handler, antenna_mast]
DETAILS = [water_tank, sat_dish, stair_housing, pipe_run, None, None, vent_small, skylight_row]


def fit_sheet(P, src_name, dst_name, models):
    src = Image.open(os.path.join(P, 'art', 'world_hd', src_name)).convert('RGBA')
    sheet = src.copy()
    tmp = tempfile.mkdtemp(prefix='ostatok_roof2_')
    C = src.height
    for i, fn in enumerate(models):
        if fn is None:
            continue
        x0 = i * C
        old = np.array(src.crop((x0, 0, x0 + C, C)))
        ys, xs = np.nonzero(old[..., 3] > 200)
        if len(xs) == 0:
            continue
        bx0, bx1, by0, by1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        bk.reset()
        bk.camera(RENDER, 64, 40)
        fn()
        raw = bk.render(os.path.join(tmp, fn.__name__ + '.png'))
        spr = bk.to_sprite(raw, RENDER, colours=0, outline=False, shadow=True)
        a = np.array(spr)
        sy, sx = np.nonzero(a[..., 3] > 0)
        spr = spr.crop((sx.min(), sy.min(), sx.max() + 1, sy.max() + 1))
        # keep the old size: the larger of the old width / height decides
        k = min((bx1 - bx0 + 6) / spr.width, (by1 - by0 + 10) / spr.height)
        nw, nh = max(1, int(round(spr.width * k))), max(1, int(round(spr.height * k)))
        arr = np.array(spr).astype(float)
        arr[..., :3] *= arr[..., 3:4] / 255.0
        pm = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA').resize((nw, nh), Image.LANCZOS)
        arr = np.array(pm).astype(float)
        al = np.maximum(arr[..., 3:4], 1)
        arr[..., :3] = np.clip(arr[..., :3] * 255.0 / al, 0, 255)
        # the cast shadow (dark, half alpha) is kept soft; the body is hardened
        body = Image.fromarray(arr.astype(np.uint8), 'RGBA')
        b = np.array(body)
        lum = b[..., :3].mean(axis=2)
        shadow = (b[..., 3] > 20) & (b[..., 3] < 200) & (lum < 40)
        fitted = Image.new('RGBA', (nw + 2, nh + 2))
        fitted.paste(body, (1, 1))
        fitted = harden(fitted, 28)
        f = np.array(fitted)
        sh = np.zeros_like(f)
        sh[1:-1, 1:-1][shadow] = (8, 10, 10, 90)
        out = Image.fromarray(sh, 'RGBA')
        out.alpha_composite(fitted)
        cell = Image.new('RGBA', (C, C))
        cx = (bx0 + bx1) // 2
        cell.alpha_composite(out, (max(0, int(cx - out.width // 2)), max(0, min(C - out.height, int(by1 + 2 - out.height)))))
        sheet.paste(cell, (x0, 0))
        print(dst_name, fn.__name__, (bx1 - bx0, by1 - by0), '->', fitted.size, flush=True)
    sheet.save(os.path.join(P, 'art', 'world_hd', dst_name))


def build(P):
    fit_sheet(P, 'roof_props_hd.png', 'roof_props_v2.png', PROPS)
    fit_sheet(P, 'roof_details_hd.png', 'roof_details_v2.png', DETAILS)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
