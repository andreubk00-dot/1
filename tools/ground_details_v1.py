"""OSTATOK 1.54: small ground details - what lies on open ground.

Open lots, fields and yards were bare between the big set pieces: a lawn with
nothing on it, a concrete yard of nothing but cracks. This sheet holds the
small things of the ground, drawn as HD pixel art (2 texels per world unit,
48 px cells = 24 units, light from the upper left, the 1 px dark outline of
the world's props): tufts, stones, flowers, mushrooms on soft ground; weeds
in cracks, rubble, a tyre, a pallet, bottles, moss on hard ground.

    python3 tools/ground_details_v1.py <project_dir>

Writes art/world_hd/ground_details_v1.png (8 x 3 cells): rows = grass, dirt /
forest, hard ground. Order mirrored in main_script_mod.gd GROUND_DETAIL_*.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

C = 48
OUT = (18, 16, 14, 255)


class Cell:
    def __init__(self, seed):
        self.a = np.zeros((C, C, 4), np.uint8)
        self.r = random.Random(seed)

    def px(self, x, y, col, alpha=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < C and 0 <= y < C:
            self.a[y, x] = (col[0], col[1], col[2], alpha)

    def blob(self, cx, cy, rx, ry, col, light=0.22, dark=0.30, rough=0.0):
        """a shaded lump: lit upper left, dark lower right"""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                d = dx * dx + dy * dy
                if d > 1.0 + self.r.uniform(-rough, rough):
                    continue
                k = 1.0 + light * max(0.0, -(dx + dy) * 0.7) - dark * max(0.0, (dx + dy) * 0.7)
                k += self.r.uniform(-0.04, 0.04)
                self.px(x, y, tuple(int(max(0, min(255, c * k))) for c in col))

    def blade(self, x, y, h, col, lean=0.0):
        for i in range(h):
            k = 0.8 + 0.35 * i / max(1, h - 1)
            self.px(x + lean * i / max(1, h - 1), y - i, tuple(int(min(255, c * k)) for c in col))

    def rect(self, x0, y0, w, h, col, light=1.12, dark=0.78):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                k = light if y == y0 or x == x0 else (dark if y == y0 + h - 1 or x == x0 + w - 1 else 1.0)
                self.px(x, y, tuple(int(max(0, min(255, c * k))) for c in col))

    def finish(self, shadow=True):
        A = self.a[..., 3] == 255
        g = np.zeros_like(A)
        g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
        e = g & ~A
        self.a[e] = OUT
        if shadow:
            # a soft contact shadow under and to the right of the solid part
            S = self.a[..., 3] == 255
            sh = np.zeros_like(S)
            sh[1:, 1:] |= S[:-1, :-1]
            sh[2:, 2:] |= S[:-2, :-2]
            self.a[sh & ~S] = (8, 10, 10, 70)
        return Image.fromarray(self.a, 'RGBA')


GRASS = [(58, 78, 38), (74, 96, 46), (92, 112, 54)]
DRY = [(120, 104, 60), (146, 128, 74), (168, 150, 92)]
STONE = [(118, 116, 108), (136, 134, 124), (98, 98, 92)]


def tuft(seed, cols=GRASS, n=14, h=(7, 13), spread=9):
    c = Cell(seed)
    for i in range(n):
        x = 24 + c.r.uniform(-spread, spread)
        c.blade(x, 40 - abs(x - 24) * 0.15, c.r.randint(*h), cols[c.r.randrange(len(cols))], c.r.uniform(-3, 3))
    return c.finish(False)


def stones(seed, n=3, big=False):
    c = Cell(seed)
    if big:
        c.blob(24, 32, 11, 7, STONE[0], rough=0.12)
        c.blob(20, 29, 4, 2.5, STONE[1])                         # a lighter facet
        for x in (15, 30):
            c.blade(x, 40, 5, GRASS[1], 1)
    else:
        for i in range(n):
            c.blob(14 + i * 9 + c.r.uniform(-2, 2), 34 + c.r.uniform(-3, 3), c.r.uniform(3, 5), c.r.uniform(2, 3.4), STONE[i % 3], rough=0.1)
    return c.finish()


def flowers(seed, petal, centre=None, n=7):
    c = Cell(seed)
    for i in range(10):
        c.blade(24 + c.r.uniform(-10, 10), 40, c.r.randint(3, 6), GRASS[c.r.randrange(3)], c.r.uniform(-1, 1))
    for i in range(n):
        x, y = 24 + c.r.uniform(-11, 11), 34 + c.r.uniform(-7, 3)
        c.blade(x, y + 4, 4, GRASS[0])
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1)):
            c.px(x + dx, y + dy, petal)
        if centre:
            c.px(x, y, centre)
    return c.finish(False)


def mushrooms(seed):
    c = Cell(seed)
    for (x, y, r) in ((20, 34, 4), (29, 37, 3)):
        c.rect(x - 1, y, 2, 5, (214, 204, 180))
        c.blob(x, y, r, r * 0.6, (150, 78, 46))
        c.px(x - 1, y - 1, (214, 190, 150))
    for i in range(6):
        c.px(14 + c.r.uniform(0, 20), 41, (150, 96, 40))            # fallen leaves
    return c.finish()


def fern(seed):
    c = Cell(seed)
    for a in (-1.2, -0.6, 0.0, 0.6, 1.2):
        for i in range(12):
            x, y = 24 + math.sin(a) * i * 1.2, 40 - math.cos(a) * i * 1.0 + (i * i) * 0.03
            col = GRASS[0] if i < 4 else (GRASS[1] if i < 9 else GRASS[2])
            c.px(x, y, col)
            w = max(0, 3 - abs(i - 6) // 2)
            for k in range(1, w + 1):
                c.px(x - k * math.cos(a), y - k * math.sin(a) * 0.6, col)
                c.px(x + k * math.cos(a), y + k * math.sin(a) * 0.6, col)
    return c.finish(False)


def cones(seed):
    c = Cell(seed)
    for i in range(4):
        x, y = 14 + i * 7 + c.r.uniform(-2, 2), 36 + c.r.uniform(-3, 3)
        c.blob(x, y, 2.6, 1.8, (104, 72, 44))
    for i in range(14):
        c.px(10 + c.r.uniform(0, 28), 30 + c.r.uniform(0, 12), (120, 84, 40))   # needles
    return c.finish()


def stump_small(seed):
    c = Cell(seed)
    c.blob(24, 35, 7, 4.5, (92, 68, 46))
    c.blob(24, 32, 6.5, 3.6, (168, 136, 92), light=0.1, dark=0.12)   # the cut face
    for r in (2, 4):
        for a in range(0, 360, 30):
            c.px(24 + math.cos(math.radians(a)) * r, 32 + math.sin(math.radians(a)) * r * 0.55, (132, 100, 64))
    for x in (15, 33):
        c.blade(x, 41, 4, GRASS[1])
    return c.finish()


def crack_weeds(seed):
    c = Cell(seed)
    x, y = 8.0, 34.0
    for i in range(32):
        c.px(x, y, (30, 30, 30), 200)
        x += 1
        y += c.r.choice((-1, 0, 0, 0, 1)) * 0.7
        if i % 4 == 1:
            c.blade(x, y, c.r.randint(3, 7), GRASS[c.r.randrange(3)], c.r.uniform(-2, 2))
    return c.finish(False)


def rubble_small(seed):
    c = Cell(seed)
    cols = [(150, 70, 52), (134, 62, 46), (150, 146, 136), (124, 120, 112)]
    for i in range(7):
        x, y = 12 + c.r.uniform(0, 22), 30 + c.r.uniform(0, 9)
        c.rect(int(x), int(y), c.r.randint(3, 6), c.r.randint(2, 4), cols[i % 4])
    return c.finish()


def tyre(seed):
    c = Cell(seed)
    c.blob(24, 33, 11, 6.5, (34, 34, 36), light=0.3)
    for y in range(28, 39):
        for x in range(17, 32):
            if ((x - 24) / 6.0) ** 2 + ((y - 33) / 3.2) ** 2 < 1:
                c.a[y, x] = (0, 0, 0, 0)
    for a in range(0, 360, 24):                                  # tread nicks
        c.px(24 + math.cos(math.radians(a)) * 10, 33 + math.sin(math.radians(a)) * 5.8, (60, 60, 62))
    return c.finish()


def pallet(seed):
    c = Cell(seed)
    for i, y in enumerate(range(26, 40, 3)):
        c.rect(10, y, 28, 2, (150, 116, 76) if i != 2 else (126, 96, 62))
    for x in (11, 23, 35):
        c.rect(x, 25, 2, 15, (112, 84, 54))
    return c.finish()


def bottles(seed):
    c = Cell(seed)
    c.rect(14, 34, 7, 3, (64, 106, 60))
    c.rect(21, 35, 2, 1, (64, 106, 60))
    c.rect(27, 30, 3, 6, (120, 80, 36))
    c.rect(28, 28, 1, 2, (120, 80, 36))
    c.blob(34, 37, 2.5, 2, (170, 172, 170))                       # a tin
    for i in range(5):
        c.px(18 + c.r.uniform(0, 14), 40, (120, 170, 120))         # shards
    return c.finish()


def moss(seed):
    c = Cell(seed)
    for i in range(5):
        c.blob(24 + c.r.uniform(-9, 9), 35 + c.r.uniform(-4, 4), c.r.uniform(3, 6), c.r.uniform(2, 3.5), (66, 86, 44), light=0.15, dark=0.15, rough=0.3)
    return c.finish(False)


def slab_chunk(seed):
    c = Cell(seed)
    c.blob(22, 34, 10, 5, (140, 138, 128), rough=0.25)
    c.blob(33, 38, 3.5, 2.2, (124, 122, 114), rough=0.2)
    for i in range(3):
        c.px(16 + i * 5, 32 + i, (96, 60, 40))                     # rebar
        c.px(17 + i * 5, 32 + i, (96, 60, 40))
    return c.finish()


def cardboard(seed):
    c = Cell(seed)
    c.rect(12, 30, 18, 9, (156, 122, 82))
    c.rect(26, 34, 10, 6, (140, 108, 72))
    for x in range(13, 29, 3):
        c.px(x, 34, (124, 96, 62))
    return c.finish()


ROWS = [
    # soft ground: grass
    [lambda: tuft(1), lambda: tuft(2, DRY, 12, (6, 11)), lambda: flowers(3, (226, 196, 60)), lambda: flowers(4, (232, 230, 220), (220, 180, 60)),
     lambda: stones(5), lambda: stones(6, big=True), lambda: tuft(7, GRASS, 22, (9, 16), 11), lambda: flowers(8, (150, 110, 190), None, 5)],
    # forest floor / bare earth
    [lambda: mushrooms(11), lambda: fern(12), lambda: cones(13), lambda: stump_small(14),
     lambda: stones(15, 2), lambda: tuft(16, DRY, 9, (5, 9), 7), lambda: moss(17), lambda: stones(18, big=True)],
    # hard ground: concrete, asphalt, paving
    [lambda: crack_weeds(21), lambda: rubble_small(22), lambda: tyre(23), lambda: pallet(24),
     lambda: bottles(25), lambda: moss(26), lambda: slab_chunk(27), lambda: cardboard(28)],
]


def build(P):
    sheet = Image.new('RGBA', (8 * C, len(ROWS) * C))
    for r, row in enumerate(ROWS):
        for i, fn in enumerate(row):
            sheet.paste(fn(), (i * C, r * C))
    sheet.save(os.path.join(P, 'art', 'world_hd', 'ground_details_v1.png'))
    print('ground details', sheet.size)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
