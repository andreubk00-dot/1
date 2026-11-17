"""OSTATOK 1.60: crows - the first life in the empty world.

Small flocks sit on open ground, peck and hop, and lift off flapping when the
survivor comes close. HD pixel art (2 texels per world unit) in 24 px cells,
light from the upper left, the world's dark outline.

    python3 tools/crows_v1.py <project_dir>

Writes art/world_hd/crows_v1.png: 6 cells - stand, peck, hop (seen from the
side, facing right), then three wing beats seen from above at a slant
(wings up, level, down). Mirrored in code for the other way.
"""
import os
import sys

import numpy as np
from PIL import Image

C = 24
BLACK = (24, 24, 30)
BODY = (38, 38, 46)
SHEEN = (70, 74, 96)
BEAK = (52, 50, 48)
EYE = (150, 140, 120)
OUT = (8, 8, 10, 255)


def cell():
    return np.zeros((C, C, 4), np.uint8)


def put(a, x, y, col):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < C and 0 <= y < C:
        a[y, x] = (col[0], col[1], col[2], 255)


def ellipse(a, cx, cy, rx, ry, col, sheen=True):
    for y in range(C):
        for x in range(C):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                c = col
                if sheen and dy < -0.35 and dx < 0.3:
                    c = SHEEN
                put(a, x, y, c)


def standing(peck=False, hop=False):
    a = cell()
    lift = 2 if hop else 0
    # tail, body, head, beak, legs
    for i in range(5):
        put(a, 5 + i * 0.6, 13 - lift + i * 0.2, BLACK)
        put(a, 5 + i * 0.6, 14 - lift + i * 0.2, BLACK)
    ellipse(a, 11, 13 - lift, 5.5, 3.4, BODY)
    hx, hy = (16, 15 - lift) if peck else (16, 10 - lift)
    ellipse(a, hx, hy, 2.4, 2.2, BODY)
    put(a, hx + 0.5, hy - 0.8, EYE)
    for k in range(3):
        put(a, hx + 2 + k, hy + (0.6 if peck else 0.2) + (k * 0.6 if peck else 0), BEAK)
    if not hop:
        for x in (10, 12):
            put(a, x, 17, BEAK); put(a, x, 18, BEAK)
            put(a, x + 1, 18, BEAK)
    else:
        put(a, 10, 15, BEAK); put(a, 13, 15, BEAK)
    return a


def flying(phase):
    """seen from above at a slant: body along x (head right), swept wings with
    fingered primaries; the wing beat shortens the wings as they rise or fall"""
    from PIL import ImageDraw
    im = Image.new('RGBA', (C, C))
    d = ImageDraw.Draw(im)
    L = {0: 6.0, 1: 9.5, 2: 8.0}[phase]               # half span seen from above
    back = {0: 1.0, 1: 2.5, 2: 3.5}[phase]             # tips swept back on the down stroke
    for side in (-1, 1):
        tip = (11.0 - back, 12.0 + side * L)
        poly = [(14.0, 12.0 + side * 1.0), (12.5, 12.0 + side * L * 0.6), tip,
                (9.5 - back, 12.0 + side * (L - 1.5)), (8.0, 12.0 + side * 1.5)]
        d.polygon(poly, fill=BLACK + (255,))
        for f in range(3):                                # fingered primaries
            fx = tip[0] - 0.5 - f * 1.1
            d.point((fx, tip[1] + side * 0.8), fill=BLACK + (255,))
        # the near (lower) wing shows its lit leading edge
        if side > 0:
            d.line([(14.0, 13.0), (12.5, 12.0 + L * 0.6)], fill=SHEEN + (255,))
    a = np.array(im)
    ellipse(a, 11.5, 12, 4.6, 2.0, BODY)
    ellipse(a, 16.5, 12, 1.8, 1.6, BODY)
    put(a, 18.5, 12, BEAK); put(a, 19.5, 12, BEAK)
    for i in range(4):                                    # fan tail
        put(a, 6.5 - i * 0.6, 11.4 + i * 0.1, BLACK); put(a, 6.5 - i * 0.6, 12.6 - i * 0.1, BLACK)
    return a


def outline(a):
    A = a[..., 3] == 255
    g = np.zeros_like(A)
    g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
    a[g & ~A] = OUT
    return a


def build(P):
    cells = [standing(), standing(peck=True), standing(hop=True), flying(0), flying(1), flying(2)]
    sheet = Image.new('RGBA', (C * len(cells), C))
    for i, c in enumerate(cells):
        sheet.paste(Image.fromarray(outline(c), 'RGBA'), (i * C, 0))
    sheet.save(os.path.join(P, 'art', 'world_hd', 'crows_v1.png'))
    print('crows', sheet.size)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
