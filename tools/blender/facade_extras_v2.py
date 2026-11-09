"""OSTATOK 1.52: the brick chimney and the factory stack of the roofs, in Blender.

facade_extras_hd.png holds a fire ladder (kept), a brick chimney and a tall
guyed stack. The two roof pieces were flat grey drawings; they are modelled
here, rendered with the HD pipeline and fitted into their cells on the same
ground line, so placement is unchanged.

    python3.13 tools/blender/facade_extras_v2.py <project_dir>

Writes art/world_hd/facade_extras_v2.png (same layout as facade_extras_hd).
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

# (x, y, w, h) of each cell in the HD sheet
CELLS = {"chimney": (96, 0, 128, 128), "stack": (224, 0, 128, 240)}


def brick_chimney():
    rnd = random.Random(2)
    cols = [(132, 62, 46), (118, 54, 40), (146, 72, 52), (104, 50, 38)]
    mortar = mat((150, 140, 124), rough=1.0)
    box((0, 0, 14), (6.0, 6.0, 14), mortar, bevel=0.2)
    for row in range(14):
        z = 1 + row * 2.0
        off = 1.5 if row % 2 else 0
        for face in (0, 1):                       # front (+y) and side (+x) faces
            for i in range(4):
                c = mat(cols[rnd.randrange(len(cols))], rough=0.9, grime=0.3)
                if face == 0:
                    box((-4.5 + i * 3.0 + off, 6.05, z), (1.35, 0.25, 0.85), c, bevel=0.05)
                else:
                    box((6.05, -4.5 + i * 3.0 + off, z), (0.25, 1.35, 0.85), c, bevel=0.05)
    box((0, 0, 28.6), (7.0, 7.0, 0.8), mat((120, 116, 108), rough=0.9, grime=0.4), bevel=0.3)   # cap
    cyl((0, 0, 29.4), 2.2, 2.6, mat((90, 90, 86), rough=0.6, metal=0.4), bevel=0.3, verts=14)  # flue
    sphere((0, 0, 32.4), 2.4, mat((30, 30, 28), rough=1.0), scale=(1, 1, 0.4))                 # soot
    sphere((0, 6.2, 26), 3.0, mat((40, 36, 32), rough=1.0), scale=(1.2, 0.1, 1.6))             # soot run
    box((0, 0, 0.3), (8, 8, 0.3), mat((60, 60, 58), rough=0.9), bevel=0.2)                     # flashing


def factory_stack():
    white = mat((206, 202, 192), rough=0.7, grime=0.55, dust=0.3, scale=0.15)
    red = mat((160, 52, 40), rough=0.7, grime=0.5, dust=0.3, scale=0.15)
    H = 104
    seg = 8
    for i in range(int(H / seg)):
        r = 4.6 - i * 0.12
        cyl((0, 0, i * seg), r, seg, red if (i // 2) % 2 == 0 else white, bevel=0.1, verts=24)
    cyl((0, 0, H), 4.0, 1.6, mat((60, 60, 58), rough=0.6, metal=0.4), bevel=0.3, verts=24)   # top ring
    sphere((0, 0, H + 1.8), 3.6, mat((26, 26, 24), rough=1.0), scale=(1, 1, 0.35))           # soot
    for z in range(4, H, 6):                                                                 # ladder
        box((0, 4.9 - z * 0.006, z), (1.2, 0.2, 0.15), mat((70, 70, 68), rough=0.5, metal=0.5), bevel=0)
    for x in (-1.2, 1.2):
        cyl((x, 4.9, 2), 0.15, H - 6, mat((70, 70, 68), rough=0.5, metal=0.5), bevel=0, verts=6)
    for z in (40, 80):                                                                       # platforms
        cyl((0, 0, z), 6.2, 0.4, mat((80, 80, 78), rough=0.5, metal=0.5), bevel=0, verts=24)
    wire = mat((40, 40, 40), rough=0.6, metal=0.5)
    for a in (0.6, 2.6, 4.4):                                                                # guy wires
        tube([(0, 0, 70), (math.cos(a) * 15, math.sin(a) * 7, 0)], 0.32, wire)
    box((0, 0, 3), (6, 6, 3), mat((140, 136, 126), rough=0.9, grime=0.5), bevel=0.4)        # plinth


def build(P):
    src = Image.open(os.path.join(P, 'art', 'world_hd', 'facade_extras_hd.png')).convert('RGBA')
    sheet = src.copy()
    tmp = tempfile.mkdtemp(prefix='ostatok_fx2_')
    for name, fn in (("chimney", brick_chimney), ("stack", factory_stack)):
        x0, y0, w, h = CELLS[name]
        old = np.array(src.crop((x0, y0, x0 + w, y0 + h)))
        ys, xs = np.nonzero(old[..., 3] > 200)
        bx0, bx1, by0, by1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        render = 140 if name == "stack" else 80
        bk.reset()
        bk.camera(render, int(render * 0.85), render // 2)
        fn()
        raw = bk.render(os.path.join(tmp, name + '.png'))
        spr = bk.to_sprite(raw, render, colours=0, outline=False, shadow=False)
        a = np.array(spr)
        sy, sx = np.nonzero(a[..., 3] > 0)
        spr = spr.crop((sx.min(), sy.min(), sx.max() + 1, sy.max() + 1))
        k = min((bx1 - bx0 + 4) / spr.width, (by1 - by0) / spr.height)
        nw, nh = max(1, int(round(spr.width * k))), max(1, int(round(spr.height * k)))
        arr = np.array(spr).astype(float)
        arr[..., :3] *= arr[..., 3:4] / 255.0
        pm = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA').resize((nw, nh), Image.LANCZOS)
        arr = np.array(pm).astype(float)
        al = np.maximum(arr[..., 3:4], 1)
        arr[..., :3] = np.clip(arr[..., :3] * 255.0 / al, 0, 255)
        fitted = Image.new('RGBA', (nw + 2, nh + 2))
        fitted.paste(Image.fromarray(arr.astype(np.uint8), 'RGBA'), (1, 1))
        fitted = harden(fitted, 28)
        cell = Image.new('RGBA', (w, h))
        cx = (bx0 + bx1) // 2
        cell.alpha_composite(fitted, (max(0, int(cx - fitted.width // 2)), max(0, int(by1 - fitted.height))))
        sheet.paste(cell, (x0, y0))
        print('fx', name, (bx1 - bx0, by1 - by0), '->', fitted.size, flush=True)
    sheet.save(os.path.join(P, 'art', 'world_hd', 'facade_extras_v2.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
