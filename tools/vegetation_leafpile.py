"""OSTATOK 1.57: the leaf pile of the vegetation sheet, redrawn.

vegetation_v2.png cell 5 (leaf_pile) was a smooth orange oval - one of the
most common sprites outdoors, it read as an egg on the pavement. This draws
it as a ragged heap of single leaves in several autumn colours, darker and
browner underneath, a few blown clear of the heap, a twig through it.
Run after tools/blender/vegetation_v2.py (it patches that sheet in place).

    python3 tools/vegetation_leafpile.py <project_dir>
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

C = 64
OUT = (22, 18, 14, 255)
COLS = [(184, 104, 40), (204, 142, 52), (160, 80, 34), (214, 172, 72), (132, 96, 48), (176, 60, 36)]


def leaf_pile(seed=5):
    r = random.Random(seed)
    a = np.zeros((C, C, 4), np.uint8)

    def px(x, y, col, al=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < C and 0 <= y < C:
            a[y, x] = (col[0], col[1], col[2], al)

    cx, cy = 32, 46
    # a ragged mound outline: radius wobbles with angle
    wob = [r.uniform(0.75, 1.15) for _ in range(12)]

    def inside(x, y):
        ang = math.atan2((y - cy) / 0.5, x - cx) % math.tau
        i = ang / math.tau * 12
        k = wob[int(i) % 12] * (1 - i % 1) + wob[(int(i) + 1) % 12] * (i % 1)
        return ((x - cx) / (21 * k)) ** 2 + ((y - cy) / (9 * k)) ** 2 <= 1.0

    # the dark under-layer (old wet leaves), then the heap in leaves, lit from upper left
    for y in range(C):
        for x in range(C):
            if inside(x, y):
                px(x, y, (96, 64, 36))
    for i in range(800):
        x, y = cx + r.gauss(0, 11), cy + r.gauss(0, 4.6)
        if not inside(x, y):
            continue
        h = 1.0 - (((x - cx) / 21) ** 2 + ((y - cy) / 9) ** 2)       # height of the heap
        col = COLS[r.randrange(len(COLS))]
        k = 0.78 + 0.38 * h + (0.12 if (x - cx) + (y - cy) < -4 else 0.0)
        c = tuple(int(min(255, v * k)) for v in col)
        px(x, y - h * 3, c)
        px(x + 1, y - h * 3, tuple(int(v * 0.86) for v in c))
    for i in range(14):                                     # leaves blown clear of the heap
        ang = r.uniform(0, math.tau)
        d = r.uniform(1.15, 1.6)
        x, y = cx + math.cos(ang) * 21 * d, cy + math.sin(ang) * 9 * d
        col = COLS[r.randrange(len(COLS))]
        px(x, y, col); px(x + 1, y, tuple(int(v * 0.8) for v in col))
    for k in range(18):                                     # a twig through the heap
        px(14 + k * 1.4, 42 + k * 0.35, (70, 52, 36))
    A = a[..., 3] == 255
    g = np.zeros_like(A)
    g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
    a[g & ~A] = OUT
    S = a[..., 3] == 255
    sh = np.zeros_like(S)
    sh[1:, 1:] |= S[:-1, :-1]
    a[sh & ~S] = (8, 10, 10, 70)
    return Image.fromarray(a, 'RGBA')


def build(P):
    path = os.path.join(P, 'art', 'world_hd', 'vegetation_v2.png')
    sheet = Image.open(path).convert('RGBA')
    sheet.paste(Image.new('RGBA', (C, C)), (5 * C, 0))
    sheet.paste(leaf_pile(), (5 * C, 0))
    sheet.save(path)
    print('leaf pile patched')


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
