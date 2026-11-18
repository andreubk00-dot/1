"""OSTATOK 1.64: what the last day left on the roads - skid marks and glass.

Cars stood on the streets as if parked. A few now have a story behind them:
the black rubber of a hard stop or a skid behind them, crumbs of safety glass
round a smashed window. Flat HD decals (2 texels per world unit) with the
world's light; drawn on the asphalt under the car.

    python3 tools/road_marks_v1.py <project_dir>

Writes art/world_hd/road_marks_v1.png: row 0 - four skid mark pairs in
256 x 64 px cells (straight, swerving left, swerving right, broken);
row 1 - four glass scatters in 64 x 48 px cells.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

SW, SH = 256, 64
GW, GH = 64, 48


def skid(kind, seed):
    r = random.Random(seed)
    a = np.zeros((SH, SW, 4), np.uint8)
    track = 26                    # px between the two wheel tracks (13 units)
    for side in (-1, 1):
        last = None
        for x in range(8, SW - 4):
            t = x / SW
            if kind == 0:
                y = SH / 2
            elif kind == 1:
                y = SH / 2 + (t ** 2) * 18
            elif kind == 2:
                y = SH / 2 - (t ** 2) * 18 + math.sin(t * 9) * 1.5
            else:
                y = SH / 2 + math.sin(t * 3.2) * 4
            if kind == 3 and 0.35 < t < 0.48:
                continue                                      # the wheel bounced
            y += side * track / 2 * (1 - 0.15 * t)
            # heavier where the tyre bit first, fading toward the stop
            dark = 0.9 - 0.45 * t + r.uniform(-0.12, 0.12)
            w = 3 if t < 0.7 else 2
            for k in range(w):
                yy = int(round(y)) + k - w // 2
                if 0 <= yy < SH and r.random() < 0.93:
                    al = int(255 * max(0.15, min(0.85, dark)) * (0.75 if k != w // 2 else 1.0))
                    a[yy, x] = (18, 17, 16, al)
    return Image.fromarray(a, 'RGBA')


def glass(seed):
    r = random.Random(seed)
    a = np.zeros((GH, GW, 4), np.uint8)
    for i in range(110):
        x = GW / 2 + r.gauss(0, 10)
        y = GH / 2 + r.gauss(0, 6)
        if not (1 <= x < GW - 2 and 1 <= y < GH - 2):
            continue
        x, y = int(x), int(y)
        lit = r.random() < 0.3
        col = (214, 230, 232, 255) if lit else (120, 146, 150, 220)
        a[y, x] = col
        if r.random() < 0.4:
            a[y, x + 1] = (90, 110, 114, 200)
        if lit and r.random() < 0.3:
            a[y + 1, x] = (60, 70, 72, 160)                   # its little shadow
    return Image.fromarray(a, 'RGBA')


def build(P):
    sheet = Image.new('RGBA', (SW * 4, SH + GH))
    for i in range(4):
        sheet.paste(skid(i, 640 + i), (i * SW, 0))
    for i in range(4):
        sheet.paste(glass(650 + i), (i * GW, SH))
    sheet.save(os.path.join(P, 'art', 'world_hd', 'road_marks_v1.png'))
    print('road marks', sheet.size)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
