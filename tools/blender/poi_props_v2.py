"""OSTATOK 1.57: three weak pieces of the industrial set-piece sheet, in Blender.

poi_props_v1 (HD twin art/world_hd/x2/poi_props_v1.png) drew the cable drum
as a dark shield-like blot, the greenhouse as a flat pale slab and the
woodpile as a heap of boards. They are modelled here, rendered with the HD
pipeline and fitted into their cells on the same ground line and footprint,
so placement and collision are unchanged.

    python3.13 tools/blender/poi_props_v2.py <project_dir>

Writes art/world_hd/poi_props_v2.png (same layout as the x2 twin: 6 x 3
cells of 384 x 256 px).
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
from bk import box, cyl, mat, tube, sphere
from props_v20 import harden

CW, CH = 384, 256
KINDS = ["boxcar", "tank_wagon", "h_tank", "silo", "pipe_rack", "watchtower",
         "guard_booth", "boom_barrier", "army_truck", "forklift", "pallets_tarp", "pipe_stack",
         "cable_drum", "transformer", "hedgehogs", "greenhouse", "woodpile", "rail_signal"]


def cable_drum():
    """a wooden cable reel lying on its side, a flange turned to the viewer,
    black cable wound on the drum"""
    wood = mat((150, 112, 70), rough=0.9, grime=0.35, dust=0.2)
    dark = mat((112, 82, 52), rough=0.9, grime=0.4)
    cable = mat((30, 30, 32), rough=0.55, metal=0.1)
    for y in (-8.0, 8.0):                                        # two flanges
        cyl((0, y, 14), 14, 2.4, wood, axis='y', bevel=0.4, verts=36)
        f = 1.3 if y > 0 else -1.3
        for a in range(0, 360, 45):                              # bolts
            r = math.radians(a)
            box((math.cos(r) * 9, y + f, 14 + math.sin(r) * 9), (0.7, 0.2, 0.7), dark, bevel=0.1)
        for k in (-6, 0, 6):                                     # plank seams
            box((k, y + f, 14), (0.15, 0.1, 12.5), dark, bevel=0.0)
        cyl((0, y + f, 14), 3.2, 0.4, mat((90, 90, 88), rough=0.5, metal=0.6), axis='y', bevel=0.1)
    cyl((0, 0, 14), 9.6, 14, cable, axis='y', bevel=0.3, verts=36)
    for i in range(8):                                           # winding ridges
        cyl((0, -6.3 + i * 1.8, 14), 9.9, 0.9, cable, axis='y', bevel=0.3, verts=36)
    tube([(8, 2, 20), (14, 6, 8), (18, 10, 0.4), (26, 12, 0.4)], 0.9, cable)   # loose end
    box((0, 0, 0.3), (16, 12, 0.3), mat((60, 58, 52), rough=1.0), bevel=0.2)            # trodden ground


def greenhouse():
    """a polycarbonate tunnel greenhouse: white ribs, milky panels, plants inside"""
    rib = mat((220, 222, 218), rough=0.5, metal=0.3, grime=0.25)
    pane = mat((182, 200, 196), rough=0.25, grime=0.3, dust=0.25)
    L, R = 34.0, 13.0
    for i in range(9):
        x = -L + i * (2 * L / 8)
        pts = [(x, math.cos(a) * R, math.sin(a) * R * 1.05) for a in np.linspace(0, math.pi, 14)]
        tube(pts, 0.55, rib, verts=6)
    tube([(-L, 0, R * 1.05), (L, 0, R * 1.05)], 0.5, rib, verts=6)
    rnd = random.Random(4)
    for i in range(8):
        x = -L + (i + 0.5) * (2 * L / 8)
        for k in range(6):
            if rnd.random() < 0.1:
                continue                                         # a panel torn off
            a = k / 6 * math.pi + math.pi / 12
            box((x, math.cos(a) * R, math.sin(a) * R * 1.05), (L / 8 - 0.3, 0.25, R * 0.27),
                pane, bevel=0.05, rot=((math.pi / 2 - a) * 57.29578, 0, 0))
    for x in (-L, L):                                            # end walls, a door
        box((x, 0, 6.5), (0.3, R - 0.5, 6.5), pane, bevel=0.05)
    box((L + 0.4, 0, 6), (0.3, 4, 6), mat((120, 150, 150), rough=0.3), bevel=0.1)
    green = [mat(c, rough=0.9) for c in ((70, 104, 50), (88, 120, 58), (110, 132, 64))]
    for i in range(18):
        sphere((rnd.uniform(-L + 4, L - 4), rnd.uniform(-7, 7), 2.5), rnd.uniform(2.2, 3.4), green[i % 3], scale=(1, 1, 0.8))
    box((0, 0, 0.3), (L + 2, R + 2, 0.3), mat((72, 60, 44), rough=1.0), bevel=0.2)


def woodpile():
    """split logs stacked between posts, a sheet of roofing on top"""
    rnd = random.Random(9)
    bark = [mat(c, rough=0.95, grime=0.3) for c in ((86, 62, 42), (100, 74, 48), (74, 54, 38))]
    cut = [mat(c, rough=0.9) for c in ((196, 158, 104), (178, 140, 92), (210, 176, 124))]
    W, D = 26.0, 7.0
    for row in range(5):
        z = 2.2 + row * 4.0
        for k in range(7):
            x = -W + 3.9 + k * 7.4 + (1.8 if row % 2 else 0)
            if x > W - 3:
                continue
            r = rnd.uniform(1.7, 2.1)
            cyl((x, 0, z), r, D * 2, bark[rnd.randrange(3)], axis='y', bevel=0.2, verts=10)
            cyl((x, D + 0.05, z), r - 0.3, 0.2, cut[rnd.randrange(3)], axis='y', bevel=0.05, verts=10)
    post = mat((70, 52, 38), rough=0.9)
    for x in (-W, W):
        box((x, 0, 11), (0.9, 0.9, 11), post, bevel=0.2)
    box((0, 0, 22.6), (W + 3, D + 3, 0.4), mat((120, 116, 108), rough=0.7, metal=0.3, grime=0.5), bevel=0.2, rot=(6, 0, 0))
    box((0, 0, 0.3), (W + 3, D + 4, 0.3), mat((84, 70, 52), rough=1.0), bevel=0.2)


def refit(src, sheet, jobs, kinds, cw, ch):
    """render each (name, fn) and fit it over the old sprite of its cell: the
    same footprint width and ground line, so placement and collision hold"""
    tmp = tempfile.mkdtemp(prefix='ostatok_refit_')
    for name, fn in jobs:
        idx = kinds.index(name)
        CW, CH = cw, ch
        x0, y0 = (idx % 6) * CW, (idx // 6) * CH
        old = np.array(src.crop((x0, y0, x0 + CW, y0 + CH)))
        ys, xs = np.nonzero(old[..., 3] > 200)
        bx0, bx1, by0, by1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        render = 110 if name != "greenhouse" else 96
        bk.reset()
        bk.camera(render, int(render * 0.7), render // 2)
        fn()
        raw = bk.render(os.path.join(tmp, name + '.png'))
        spr = bk.to_sprite(raw, render, colours=0, outline=False, shadow=False)
        a = np.array(spr)
        sy, sx = np.nonzero(a[..., 3] > 0)
        spr = spr.crop((sx.min(), sy.min(), sx.max() + 1, sy.max() + 1))
        # the same footprint width; the height follows the model
        k = (bx1 - bx0 + 4) / spr.width
        if name == "cable_drum":
            k *= 1.15
        nw, nh = max(1, int(round(spr.width * k))), max(1, int(round(spr.height * k)))
        arr = np.array(spr).astype(float)
        arr[..., :3] *= arr[..., 3:4] / 255.0
        pm = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA').resize((nw, nh), Image.LANCZOS)
        arr = np.array(pm).astype(float)
        al = np.maximum(arr[..., 3:4], 1)
        arr[..., :3] = np.clip(arr[..., :3] * 255.0 / al, 0, 255)
        fitted = Image.new('RGBA', (nw + 2, nh + 2))
        fitted.paste(Image.fromarray(arr.astype(np.uint8), 'RGBA'), (1, 1))
        fitted = harden(fitted, 30)
        cell = Image.new('RGBA', (CW, CH))
        cx = (bx0 + bx1) // 2
        cell.alpha_composite(fitted, (max(0, min(CW - fitted.width, int(cx - fitted.width // 2))), max(0, int(by1 - fitted.height))))
        sheet.paste(cell, (x0, y0))
        print('refit', name, (bx1 - bx0, by1 - by0), '->', fitted.size, flush=True)


def build(P):
    src = Image.open(os.path.join(P, 'art', 'world_hd', 'x2', 'poi_props_v1.png')).convert('RGBA')
    sheet = src.copy()
    refit(src, sheet, (("cable_drum", cable_drum), ("greenhouse", greenhouse), ("woodpile", woodpile)), KINDS, CW, CH)
    sheet.save(os.path.join(P, 'art', 'world_hd', 'poi_props_v2.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
