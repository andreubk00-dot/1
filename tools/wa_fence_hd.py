"""OSTATOK HD chain-link fence (2 texels per world unit, drawn at scale 0.5).

fence_segment_v3 was drawn at 1.33 texels per unit and its segments overlapped,
doubling the posts. The HD segment is exactly one 31-unit bay wide and tiles
seamlessly: diamond mesh with a slight sag, top rail, rust, weeds at the foot
and a soft ground shadow; the post is a separate cell placed at every bay joint.

    python3 tools/wa_fence_hd.py <project_dir>

Writes art/world_hd/fence_hd.png: [bay 62 x 80][post 8 x 80].
"""
import math
import os
import sys
import numpy as np
from PIL import Image

BW, H, PW = 62, 80, 8
BASE = 76                 # texel row of the ground line


def bay(seed=3):
    rng = np.random.default_rng(seed)
    a = np.zeros((H, BW, 4), np.uint8)
    # ground shadow (light from the upper left falls south-east)
    a[BASE:BASE + 3, :] = (8, 10, 10, 70)
    lit, mid, dark = (176, 182, 176), (132, 138, 134), (92, 98, 96)
    rust = (132, 82, 52)
    for x in range(BW):
        sag = 2.0 * math.sin(math.pi * x / BW)
        for y in range(8, BASE - 1):
            yy = y - sag
            u = (x + yy) % 6
            v = (x - yy) % 6
            if u < 1 or v < 1:
                c = lit if (u < 1) else mid
                if y > BASE - 18:
                    c = dark if u < 1 else mid
                if rng.random() < 0.05:
                    c = rust
                a[y, x] = c + (225,)
    for x in range(BW):                                   # top rail pipe
        a[5, x] = (196, 200, 194, 255)
        a[6, x] = (150, 156, 150, 255)
        a[7, x] = (80, 86, 84, 255)
        a[BASE - 2, x] = (110, 116, 112, 255)            # tension wire
    for _ in range(26):                                   # weeds at the foot
        x = int(rng.integers(0, BW))
        hgt = int(rng.integers(3, 11))
        col = [(70, 92, 46), (88, 108, 52), (120, 116, 60), (104, 80, 44)][rng.integers(0, 4)]
        lean = rng.choice([-1, 0, 1])
        for k in range(hgt):
            xx = x + (lean if k > hgt // 2 else 0)
            if 0 <= xx < BW:
                a[BASE - k, xx] = tuple(int(c * (0.8 + 0.25 * k / hgt)) for c in col) + (255,)
    for _ in range(4):                                    # snagged litter / leaves
        x, y = int(rng.integers(2, BW - 3)), int(rng.integers(BASE - 20, BASE - 4))
        a[y, x] = (200, 120, 40, 255)
        a[y, x + 1] = (160, 90, 34, 255)
    return a


def post():
    a = np.zeros((H, PW, 4), np.uint8)
    a[BASE:BASE + 3, 2:8] = (8, 10, 10, 90)
    for y in range(3, BASE + 1):
        a[y, 2] = (190, 196, 190, 255)
        a[y, 3] = (150, 156, 152, 255)
        a[y, 4] = (112, 118, 114, 255)
        a[y, 5] = (70, 76, 74, 255)
        a[y, 1] = (24, 26, 24, 255)
        a[y, 6] = (24, 26, 24, 255)
    a[1:3, 1:7] = (206, 210, 204, 255)                    # cap
    a[0, 2:6] = (24, 26, 24, 255)
    a[BASE - 1:BASE + 1, 1:7] = (96, 92, 84, 255)         # footing
    return a


def build(P):
    sheet = np.zeros((H, BW + PW, 4), np.uint8)
    sheet[:, :BW] = bay()
    sheet[:, BW:] = post()
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(sheet, 'RGBA').save(os.path.join(out, 'fence_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
