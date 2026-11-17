"""OSTATOK 1.61: ponds for the woods and the dachas.

There was no open water anywhere in the world. Three pond shapes, HD pixel
art (2 texels per world unit) in 320 x 224 px cells (160 x 112 units): a
ragged outline, a muddy shore with stones, water darkening toward the deep
middle, reeds and sedge in the shallows, lily pads, a few lit ripples. Water
texels carry alpha 250 so the shader can make only the water shimmer.

    python3 tools/ponds_v1.py <project_dir>

Writes art/world_hd/ponds_v1.png and art/world_hd/ponds_v1.json (per shape:
the water outline in world units around the cell centre, for collision).
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image

CW, CH = 320, 224
SHAPES = [
    # rx, ry (px), harmonics [(k, amp, phase)]
    (128, 74, [(2, 0.10, 0.4), (3, 0.07, 1.9), (5, 0.04, 0.7)]),
    (112, 82, [(2, 0.14, 2.2), (3, 0.05, 0.3), (4, 0.05, 1.1)]),
    (136, 66, [(1, 0.06, 0.0), (3, 0.11, 2.8), (5, 0.03, 1.5)]),
]
OUT = (16, 18, 16, 255)


def radius(shape, a):
    rx, ry, harm = shape
    k = 1.0 + sum(amp * math.cos(n * a + ph) for n, amp, ph in harm)
    return rx * k, ry * k


def inside(shape, x, y, grow=0.0):
    a = math.atan2(y / shape[1], x / shape[0])
    rx, ry = radius(shape, a)
    return (x / (rx + grow)) ** 2 + (y / (ry + grow * ry / rx)) ** 2 <= 1.0


def depth(shape, x, y):
    a = math.atan2(y / shape[1], x / shape[0])
    rx, ry = radius(shape, a)
    return 1.0 - math.sqrt((x / rx) ** 2 + (y / ry) ** 2)   # 0 at the edge, 1 at the middle


def pond(idx, seed):
    shape = SHAPES[idx]
    r = random.Random(seed)
    a = np.zeros((CH, CW, 4), np.uint8)
    cx, cy = CW / 2, CH / 2
    noise = np.random.default_rng(seed).random((CH, CW))
    from PIL import ImageFilter
    water = np.zeros((CH, CW), bool)
    shore = np.zeros((CH, CW), bool)
    for y in range(CH):
        for x in range(CW):
            lx, ly = x - cx, y - cy
            if inside(shape, lx, ly):
                water[y, x] = True
            elif inside(shape, lx, ly, grow=7.0):
                shore[y, x] = True
    # depth: the water mask blurred - 0 at the bank, 1 well inside; smooth,
    # whatever the outline does
    m = Image.fromarray((water * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14))
    dep = np.clip((np.array(m).astype(float) / 255.0 - 0.5) * 2.4, 0, 1)
    # the far (north) bank shades the water under it
    north = np.zeros_like(water)
    north[8:] = ~water[:-8]
    for y in range(CH):
        for x in range(CW):
            if water[y, x]:
                t = dep[y, x]
                # shallow: brown-olive over the mud; deep: the grey sky mirrored
                col = np.array((92, 100, 74)) * (1 - t) + np.array((70, 92, 102)) * t
                col = col * 0.8 + np.array((120, 138, 146)) * 0.2 * t
                col *= 0.97 + noise[y, x] * 0.06
                if north[y, x]:
                    col *= 0.78
                a[y, x] = (*np.clip(col, 0, 255).astype(np.uint8), 250)
            elif shore[y, x]:
                col = np.array((76, 62, 44)) if noise[y, x] > 0.35 else np.array((88, 74, 52))
                if noise[y, x] > 0.86:
                    col = np.array((70, 88, 46))
                a[y, x] = (*col.astype(np.uint8), 255)
    def px(x, y, col, al=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < CW and 0 <= y < CH:
            a[y, x] = (*col, al)
    # ripples: short lit strokes on the open water
    for i in range(26):
        ang = r.uniform(0, math.tau)
        d = r.uniform(0.2, 0.75)
        rx, ry = radius(shape, ang)
        x, y = cx + math.cos(ang) * rx * d, cy + math.sin(ang) * ry * d
        for k in range(r.randint(3, 7)):
            px(x + k, y, (150, 170, 176), 250)
    # lily pads in one or two sheltered patches
    for patch in range(2):
        ang = r.uniform(0, math.tau)
        rx, ry = radius(shape, ang)
        bx, by = cx + math.cos(ang) * rx * 0.62, cy + math.sin(ang) * ry * 0.62
        for i in range(9):
            x, y = bx + r.gauss(0, 9), by + r.gauss(0, 5)
            if not inside(shape, x - cx, y - cy, grow=-4):
                continue
            rr = r.uniform(2.2, 3.6)
            notch = r.uniform(0, math.tau)
            for yy in range(int(y - rr), int(y + rr) + 1):
                for xx in range(int(x - rr * 1.3), int(x + rr * 1.3) + 1):
                    dx, dy = (xx - x) / (rr * 1.3), (yy - y) / rr
                    if dx * dx + dy * dy <= 1 and abs(math.atan2(dy, dx) - notch) > 0.5:
                        px(xx, yy, (70, 112, 52) if dx + dy < 0 else (52, 88, 42))
            if r.random() < 0.25:
                px(x, y - 1, (232, 226, 214)); px(x + 1, y - 1, (240, 214, 120)); px(x, y - 2, (232, 226, 214))
    # reeds and sedge in clumps round the shallows
    for c in range(14):
        ang = r.uniform(0, math.tau)
        rx, ry = radius(shape, ang)
        bx, by = cx + math.cos(ang) * (rx - 3), cy + math.sin(ang) * (ry - 2)
        for i in range(r.randint(16, 30)):
            x, y = bx + r.gauss(0, 6), by + r.gauss(0, 3)
            h = r.randint(6, 15)
            lean = r.uniform(-2.5, 2.5)
            col = [(66, 92, 44), (82, 108, 52), (118, 112, 62), (98, 120, 58)][r.randrange(4)]
            for k in range(h):
                t = k / max(1, h - 1)
                px(x + lean * t, y - k, tuple(int(v * (0.8 + 0.35 * t)) for v in col))
            if r.random() < 0.18:                        # a bulrush head
                for k in range(3):
                    px(x + lean, y - h - k, (92, 58, 34))
    # stones on the shore
    for i in range(7):
        ang = r.uniform(0, math.tau)
        rx, ry = radius(shape, ang)
        x, y = cx + math.cos(ang) * (rx + 4), cy + math.sin(ang) * (ry + 3)
        for yy in range(-2, 3):
            for xx in range(-3, 4):
                if (xx / 3.4) ** 2 + (yy / 2.4) ** 2 <= 1:
                    px(x + xx, y + yy, (150, 148, 138) if xx + yy < 0 else (112, 110, 104))
    A = a[..., 3] > 0
    g = np.zeros_like(A)
    g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
    a[g & ~A] = OUT
    # the water outline for collision: world units around the cell centre,
    # pulled in by two units so the survivor can stand at the very edge
    poly = []
    for i in range(20):
        ang = i / 20 * math.tau
        rx, ry = radius(shape, ang)
        poly.append([round(math.cos(ang) * (rx - 4) / 2, 1), round(math.sin(ang) * (ry - 4) / 2, 1)])
    return Image.fromarray(a, 'RGBA'), poly


def build(P):
    sheet = Image.new('RGBA', (CW * len(SHAPES), CH))
    polys = []
    for i in range(len(SHAPES)):
        im, poly = pond(i, 610 + i)
        sheet.paste(im, (i * CW, 0))
        polys.append(poly)
    out = os.path.join(P, 'art', 'world_hd')
    sheet.save(os.path.join(out, 'ponds_v1.png'))
    with open(os.path.join(out, 'ponds_v1.json'), 'w') as f:
        json.dump({"cell": [CW, CH], "outlines": polys}, f)
    print('ponds', sheet.size)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
