"""OSTATOK 1.56: ground cover - the larger flat things of forest and garden.

The forest floor between the trees was bare litter and the dacha plots were
lawn round a house. This sheet holds flat ground cover a step bigger than the
ground details (96 px cells = 48 world units, HD pixel art, light from the
upper left, the world's dark outline): undergrowth for the woods and the
beds and weeds of the dacha gardens. Everything is walk-over: drawn under
the characters, no collision.

    python3 tools/ground_cover_v1.py <project_dir>

Writes art/world_hd/ground_cover_v1.png (8 x 2 cells): row 0 forest,
row 1 garden. Order mirrored in main_script_mod.gd GROUND_COVER_*.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

C = 96
OUT = (18, 16, 14, 255)
GREEN = [(46, 66, 32), (58, 80, 38), (72, 96, 46), (90, 112, 54)]
DRY = [(112, 98, 58), (138, 120, 70), (162, 144, 88)]
SOIL = [(64, 50, 36), (78, 62, 44), (92, 74, 52)]


class Cell:
    def __init__(self, seed):
        self.a = np.zeros((C, C, 4), np.uint8)
        self.r = random.Random(seed)

    def px(self, x, y, col, alpha=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < C and 0 <= y < C:
            self.a[y, x] = (col[0], col[1], col[2], alpha)

    def shade(self, col, k):
        return tuple(int(max(0, min(255, c * k))) for c in col)

    def blob(self, cx, cy, rx, ry, col, light=0.22, dark=0.3, rough=0.0, jitter=0.04):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                if dx * dx + dy * dy > 1.0 + self.r.uniform(-rough, rough):
                    continue
                k = 1.0 + light * max(0.0, -(dx + dy) * 0.7) - dark * max(0.0, (dx + dy) * 0.7)
                self.px(x, y, self.shade(col, k + self.r.uniform(-jitter, jitter)))

    def leaf(self, x, y, a, length, col, width=1.6):
        """a fern frond / long leaf: a midrib with leaflets tapering off"""
        for i in range(int(length)):
            t = i / max(1.0, length - 1)
            px, py = x + math.cos(a) * i, y + math.sin(a) * i * 0.75
            k = 0.82 + 0.35 * t
            self.px(px, py, self.shade(col, k))
            w = int(round(width * 3 * math.sin(math.pi * min(1.0, t * 1.1 + 0.05))))
            if i % 2 == 0:
                for j in range(1, w + 1):
                    nx, ny = -math.sin(a), math.cos(a) * 0.75
                    self.px(px + nx * j + math.cos(a) * j * 0.5, py + ny * j, self.shade(col, k * (0.92 if j > 1 else 1.0)))
                    self.px(px - nx * j + math.cos(a) * j * 0.5, py - ny * j, self.shade(col, k * 1.08))

    def blade(self, x, y, h, col, lean=0.0):
        for i in range(h):
            k = 0.78 + 0.38 * i / max(1, h - 1)
            self.px(x + lean * i / max(1, h - 1), y - i, self.shade(col, k))

    def log(self, x0, y0, x1, y1, r, bark, cut, moss=None):
        L = math.hypot(x1 - x0, y1 - y0)
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        nx, ny = -uy, ux
        for i in range(int(L) + 1):
            for j in np.linspace(-r, r, int(r * 4)):
                px, py = x0 + ux * i + nx * j, y0 + uy * i + ny * j
                k = 1.18 - 0.5 * (j + r) / (2 * r)          # lit along the upper edge
                if (i * 7 + int(j * 3)) % 11 == 0:
                    k *= 0.8                                 # bark furrows
                col = bark
                if moss and j > r * 0.2 and self.r.random() < 0.5:
                    col = moss
                self.px(px, py, self.shade(col, k))
        # the sawn / broken end
        for j in np.linspace(-r, r, int(r * 4)):
            for d in range(2):
                self.px(x1 + nx * j + ux * d, y1 + ny * j + uy * d, self.shade(cut, 1.05 - 0.15 * abs(j) / r))

    def finish(self, shadow=True):
        A = self.a[..., 3] == 255
        g = np.zeros_like(A)
        g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
        self.a[g & ~A] = OUT
        if shadow:
            S = self.a[..., 3] == 255
            sh = np.zeros_like(S)
            sh[2:, 2:] |= S[:-2, :-2]
            sh[3:, 3:] |= S[:-3, :-3]
            self.a[sh & ~S] = (8, 10, 10, 72)
        return Image.fromarray(self.a, 'RGBA')


# ---------------------------------------------------------------- forest row
def fern_clump(seed):
    c = Cell(seed)
    for k, (cx, cy) in enumerate(((36, 50), (60, 56))):
        n = 7 if k == 0 else 6
        for i in range(n):
            # fronds spread mostly sideways and down: seen from above at a slant
            a = -math.pi * 0.1 + (i / (n - 1)) * math.pi * 1.2 + c.r.uniform(-0.15, 0.15)
            a = a if i % 2 else a + math.pi
            c.leaf(cx, cy, a, c.r.uniform(18, 26), GREEN[1 + (i % 3)], width=1.4)
    return c.finish()


def blueberry(seed):
    c = Cell(seed)
    for i in range(70):
        x, y = 48 + c.r.gauss(0, 15), 50 + c.r.gauss(0, 10)
        c.blob(x, y, 2.4, 1.8, GREEN[c.r.randrange(0, 3)], rough=0.3)
    for i in range(26):
        x, y = 48 + c.r.gauss(0, 13), 50 + c.r.gauss(0, 9)
        c.px(x, y, (52, 58, 112)); c.px(x + 1, y, (40, 44, 88)); c.px(x, y - 1, (110, 120, 180))
    return c.finish()


def birch_log(seed):
    c = Cell(seed)
    c.log(14, 62, 82, 40, 5.5, (206, 202, 190), (176, 140, 96))
    for i in range(10):                                  # black birch marks
        t = c.r.uniform(0.05, 0.95)
        x, y = 14 + 68 * t, 62 - 22 * t
        for j in range(c.r.randint(2, 4)):
            c.px(x + j, y - 4 + c.r.randint(0, 6), (34, 32, 30))
    for x in (20, 60, 76):
        c.blade(x, 72, 6, GREEN[2], 1)
    return c.finish()


def pine_log(seed):
    c = Cell(seed)
    c.log(10, 46, 86, 58, 6.5, (92, 66, 46), (182, 148, 98), moss=(78, 102, 50))
    for i in range(3):                                   # snapped branch stubs
        t = 0.25 + i * 0.22
        x, y = 10 + 76 * t, 46 + 12 * t
        for k in range(5):
            c.px(x + k * 0.4, y - 7 - k, (80, 58, 40))
    return c.finish()


def brushwood(seed):
    c = Cell(seed)
    for i in range(16):
        a = c.r.uniform(-0.5, 0.5) + (math.pi if i % 2 else 0)
        x, y = 48 + c.r.uniform(-12, 12), 50 + c.r.uniform(-8, 8)
        L = c.r.uniform(18, 30)
        col = (96, 72, 50) if i % 3 else (124, 96, 66)
        for k in range(int(L)):
            c.px(x + math.cos(a) * k, y + math.sin(a) * k * 0.6, c.shade(col, 1.1 if k % 5 else 0.85))
            c.px(x + math.cos(a) * k, y + math.sin(a) * k * 0.6 + 1, c.shade(col, 0.7))
    return c.finish()


def moss_stones(seed):
    c = Cell(seed)
    for i in range(9):
        c.blob(48 + c.r.uniform(-24, 24), 52 + c.r.uniform(-13, 13), c.r.uniform(8, 13), c.r.uniform(5, 8), (62, 84, 42), 0.15, 0.15, rough=0.35)
    for i in range(3):
        x, y = 40 + i * 9 + c.r.uniform(-3, 3), 50 + c.r.uniform(-5, 5)
        c.blob(x, y, c.r.uniform(4, 6), c.r.uniform(3, 4), (128, 126, 116), rough=0.1)
        c.blob(x - 1, y - 1, 2, 1.4, (152, 150, 140))
    return c.finish()


def leaf_pile(seed):
    c = Cell(seed)
    cols = [(176, 104, 40), (196, 140, 50), (150, 80, 34), (122, 92, 46), (204, 168, 70)]
    for i in range(180):
        x, y = 48 + c.r.gauss(0, 13), 52 + c.r.gauss(0, 8)
        col = cols[c.r.randrange(len(cols))]
        c.px(x, y, col); c.px(x + 1, y, c.shade(col, 0.85))
        if c.r.random() < 0.4:
            c.px(x, y + 1, c.shade(col, 0.7))
    return c.finish()


def mushroom_ring(seed):
    c = Cell(seed)
    for i in range(30):
        a = i / 30 * math.tau
        c.blade(48 + math.cos(a) * 26, 52 + math.sin(a) * 17, c.r.randint(2, 4), GREEN[c.r.randrange(1, 4)])
    for i in range(11):
        a = i / 11 * math.tau + c.r.uniform(-0.2, 0.2)
        x, y = 48 + math.cos(a) * 23, 50 + math.sin(a) * 15
        cap = (150, 78, 46) if i % 3 else (176, 58, 40)
        for k in range(3):
            c.px(x, y + k, (214, 204, 180))
        c.blob(x, y - 1, 3, 2, cap)
        if cap[1] == 58:
            c.px(x - 1, y - 2, (230, 226, 210)); c.px(x + 1, y - 1, (230, 226, 210))
    return c.finish()


# ---------------------------------------------------------------- garden row
def bed(seed, plant):
    c = Cell(seed)
    for y in range(20, 78):
        for x in range(10, 86):
            row = (y - 20) // 11
            ridge = (y - 20) % 11
            col = SOIL[2] if ridge < 3 else (SOIL[1] if ridge < 8 else SOIL[0])
            c.px(x, y, c.shade(col, 1.0 + c.r.uniform(-0.05, 0.05)))
    for x in range(8, 88):                               # board edging
        c.px(x, 18, (132, 104, 70)); c.px(x, 19, (104, 80, 54))
        c.px(x, 79, (104, 80, 54)); c.px(x, 80, (80, 60, 40))
    for y in range(18, 81):
        c.px(8, y, (132, 104, 70)); c.px(87, y, (90, 68, 46))
    for row in range(5):
        y = 23 + row * 11
        for x in range(16, 82, 9 if plant != 'onion' else 4):
            if c.r.random() < 0.15:
                continue                                  # gaps: neglected
            if plant == 'cabbage':
                c.blob(x, y, 3.6, 2.8, (104, 138, 80))
                c.blob(x - 1, y - 1, 1.6, 1.2, (150, 176, 120))
            elif plant == 'onion':
                for k in range(4):
                    c.px(x + (k % 2) * 0.5, y - k, (86, 124, 58))
            else:                                         # potato tops, half dry
                col = GREEN[c.r.randrange(1, 4)] if c.r.random() < 0.6 else DRY[c.r.randrange(3)]
                c.blob(x, y, 3.2, 2.4, col, rough=0.4)
    return c.finish()


def weeds(seed, cols, n, h, spread, flower=None):
    c = Cell(seed)
    for i in range(n):
        x = 48 + c.r.gauss(0, spread)
        y = 62 + c.r.gauss(0, spread * 0.4)
        hh = c.r.randint(*h)
        c.blade(x, y, hh, cols[c.r.randrange(len(cols))], c.r.uniform(-3, 3))
        if flower and c.r.random() < 0.25:
            c.px(x, y - hh, flower)
    return c.finish(False)


def nettle(seed):
    c = Cell(seed)
    for i in range(22):
        x, y = 48 + c.r.gauss(0, 12), 64 + c.r.gauss(0, 5)
        h = c.r.randint(10, 18)
        for k in range(h):
            c.px(x, y - k, GREEN[0])
            if k % 3 == 1 and k > 2:
                for s in (-1, 1):
                    c.px(x + s, y - k, GREEN[2]); c.px(x + 2 * s, y - k + 1, GREEN[1])
    return c.finish(False)


def compost(seed):
    c = Cell(seed)
    for x in range(22, 74):                              # three-sided plank box
        for y in (30, 31):
            c.px(x, y, (126, 98, 64))
    for y in range(30, 70):
        c.px(22, y, (126, 98, 64)); c.px(73, y, (96, 72, 48))
    for i in range(140):
        x, y = 48 + c.r.gauss(0, 11), 50 + c.r.gauss(0, 8)
        if 23 < x < 72 and 32 < y < 70:
            col = [SOIL[0], SOIL[1], (96, 110, 52), (140, 112, 60), (120, 84, 44)][c.r.randrange(5)]
            c.blob(x, y, 2, 1.5, col)
    return c.finish()


def flower_bed(seed):
    c = Cell(seed)
    c.blob(48, 50, 30, 18, SOIL[1], 0.1, 0.1)
    for i in range(16):                                   # a ring of whitewashed bricks
        a = i / 16 * math.tau
        x, y = 48 + math.cos(a) * 31, 50 + math.sin(a) * 19
        c.blob(x, y, 2.6, 1.6, (214, 210, 200))
    cols = [(214, 70, 60), (230, 190, 60), (232, 230, 220), (196, 110, 170)]
    for i in range(26):
        x, y = 48 + c.r.uniform(-22, 22), 50 + c.r.uniform(-12, 12)
        if ((x - 48) / 26) ** 2 + ((y - 50) / 15) ** 2 > 1:
            continue
        c.blade(x, y + 3, 4, GREEN[2])
        col = cols[c.r.randrange(len(cols))]
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1)):
            c.px(x + dx, y + dy, col)
    return c.finish()


ROWS = [
    [lambda: fern_clump(1), lambda: blueberry(2), lambda: birch_log(3), lambda: pine_log(4),
     lambda: brushwood(5), lambda: moss_stones(6), lambda: leaf_pile(7), lambda: mushroom_ring(8)],
    [lambda: bed(11, 'potato'), lambda: bed(12, 'cabbage'), lambda: bed(13, 'onion'), lambda: compost(14),
     lambda: weeds(15, GREEN[1:] + DRY[:1], 60, (10, 20), 13, (226, 196, 60)), lambda: nettle(16),
     lambda: weeds(17, DRY, 50, (8, 16), 12), lambda: flower_bed(18)],
]


def build(P):
    sheet = Image.new('RGBA', (8 * C, len(ROWS) * C))
    for r, row in enumerate(ROWS):
        for i, fn in enumerate(row):
            sheet.paste(fn(), (i * C, r * C))
    sheet.save(os.path.join(P, 'art', 'world_hd', 'ground_cover_v1.png'))
    print('ground cover', sheet.size)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
