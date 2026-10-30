"""dev79: ground surfaces for the city's blocks (squares, playgrounds, car parks,
building sites, ruins) - seamless 256 x 256 HD tiles (2 texels per world px,
so a tile covers 128 x 128), in the ground's own palette; art/world_hd/lot_<kind>_hd.png:
  0 asphalt   old car-park asphalt, patched and cracked
  1 paving    square concrete slabs, weeds and leaves in the joints
  2 sand      a playground's sand, footprints and a few leaves
  3 gravel    a building site's crushed stone and clay
  4 slab      a ruin's bare floor slab, stained, cracked
  5 path      trodden earth, the way people cut across a lot
  6 weeds     grass and weeds taking an empty street back
python3 tools/wa_lot_surfaces_hd.py <project>"""
import math
import os
import random
import sys

from PIL import Image

T = 256
KINDS = ['asphalt', 'paving', 'sand', 'gravel', 'slab', 'path', 'weeds']
LEAF = [(176, 92, 30), (196, 118, 40), (150, 84, 36), (206, 160, 60)]


def tnoise(seed, cells):
    """tileable value noise on a cells x cells lattice, sampled per texel"""
    rnd = random.Random(seed)
    g = [[rnd.random() for _ in range(cells)] for _ in range(cells)]
    out = [[0.0] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            fx, fy = x * cells / T, y * cells / T
            ix, iy = int(fx), int(fy)
            tx, ty = fx - ix, fy - iy
            tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
            a = g[iy % cells][ix % cells]
            b = g[iy % cells][(ix + 1) % cells]
            c = g[(iy + 1) % cells][ix % cells]
            d = g[(iy + 1) % cells][(ix + 1) % cells]
            out[y][x] = (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
    return out


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def base(px, col, n1, n2, amp1, amp2, rnd, speck):
    for y in range(T):
        for x in range(T):
            k = 1.0 + (n1[y][x] - 0.5) * amp1 + (n2[y][x] - 0.5) * amp2
            c = shade(col, k)
            if rnd.random() < speck[0]:
                c = shade(c, speck[1] if rnd.random() < 0.5 else speck[2])
            px[x, y] = c + (255,)


def leaves(px, rnd, n):
    for _ in range(n):
        x, y = rnd.randrange(T), rnd.randrange(T)
        c = rnd.choice(LEAF)
        px[x, y] = c + (255,)
        px[(x + 1) % T, y] = c + (255,)


def crack(px, rnd, col, length):
    x, y = rnd.uniform(0, T), rnd.uniform(0, T)
    a = rnd.uniform(0, 6.28)
    for _ in range(length):
        px[int(x) % T, int(y) % T] = col + (255,)
        a += rnd.uniform(-0.6, 0.6)
        x += math.cos(a)
        y += math.sin(a)


def tile(kind, seed):
    rnd = random.Random(seed)
    im = Image.new('RGBA', (T, T))
    px = im.load()
    n1, n2 = tnoise(seed, 6), tnoise(seed + 1, 32)
    if kind == 'asphalt':
        base(px, (60, 60, 61), n1, n2, 0.16, 0.10, rnd, (0.10, 0.82, 1.14))
        # a darker patch of newer tar
        for y in range(T):
            for x in range(T):
                if n1[y][x] > 0.7:
                    px[x, y] = shade(px[x, y][:3], 0.91) + (255,)
        for _ in range(7):
            crack(px, rnd, (44, 44, 45), 22)
        leaves(px, rnd, 30)
    elif kind == 'paving':
        base(px, (98, 94, 84), n1, n2, 0.12, 0.10, rnd, (0.08, 0.86, 1.12))
        s = 32                               # 16 px slabs (a whole number per tile)
        for y in range(T):
            for x in range(T):
                if x % s in (0, 1) or y % s in (0, 1):
                    weed = n2[y][x] > 0.6
                    px[x, y] = ((70, 84, 42) if weed else (66, 64, 58)) + (255,)
                elif x % s == 2 or y % s == 2:
                    px[x, y] = shade(px[x, y][:3], 1.08) + (255,)
        # one slab in a few sits a shade off
        for sy in range(0, T, s):
            for sx in range(0, T, s):
                if rnd.random() < 0.35:
                    k = rnd.choice((0.9, 1.07))
                    for y in range(sy + 3, min(T, sy + s)):
                        for x in range(sx + 3, min(T, sx + s)):
                            px[x, y] = shade(px[x, y][:3], k) + (255,)
        for _ in range(3):
            crack(px, rnd, (70, 66, 58), 14)
        leaves(px, rnd, 50)
    elif kind == 'sand':
        base(px, (150, 128, 92), n1, n2, 0.14, 0.16, rnd, (0.22, 0.86, 1.12))
        for _ in range(24):                  # footprints and scuffs
            x, y = rnd.randrange(T), rnd.randrange(T)
            for dx in range(3):
                for dy in range(2):
                    px[(x + dx) % T, (y + dy) % T] = shade(px[(x + dx) % T, (y + dy) % T][:3], 0.82) + (255,)
        leaves(px, rnd, 26)
    elif kind == 'gravel':
        base(px, (104, 96, 84), n1, n2, 0.20, 0.10, rnd, (0.0, 1, 1))
        for _ in range(3600):
            x, y = rnd.randrange(T), rnd.randrange(T)
            c = rnd.choice(((132, 126, 116), (84, 78, 70), (118, 104, 86), (70, 64, 58)))
            px[x, y] = c + (255,)
        for y in range(T):                   # wet clay where the ground dips
            for x in range(T):
                if n1[y][x] < 0.24 and n2[y][x] > 0.35:
                    px[x, y] = shade((106, 88, 68), 0.92 + n2[y][x] * 0.16) + (255,)
    elif kind == 'slab':
        base(px, (108, 106, 100), n1, n2, 0.14, 0.08, rnd, (0.06, 0.84, 1.1))
        for y in range(T):
            for x in range(T):
                if x % 128 == 0 or y % 128 == 0:
                    px[x, y] = (76, 74, 70, 255)
                if n1[y][x] < 0.22:          # soot and damp
                    px[x, y] = shade(px[x, y][:3], 0.84) + (255,)
        for _ in range(9):
            crack(px, rnd, (70, 68, 64), 26)
    elif kind == 'weeds':
        base(px, (50, 64, 34), n1, n2, 0.22, 0.20, rnd, (0.0, 1, 1))
        for _ in range(5200):                # blades, two texels tall
            x, y = rnd.randrange(T), rnd.randrange(T)
            c = rnd.choice(((82, 103, 51), (66, 86, 40), (42, 54, 29), (96, 112, 58)))
            px[x, y] = c + (255,)
            px[x, (y + 1) % T] = shade(c, 0.85) + (255,)
        leaves(px, rnd, 60)
    elif kind == 'path':
        base(px, (92, 76, 58), n1, n2, 0.18, 0.14, rnd, (0.14, 0.8, 1.15))
        leaves(px, rnd, 40)
    return im


def build(project):
    # one file per surface: the game repeats it across a patch
    for i, k in enumerate(KINDS):
        path = os.path.join(project, 'art', 'world_hd', 'lot_%s_hd.png' % k)
        tile(k, 9100 + i * 17).save(path)
        print('wrote', path)


if __name__ == '__main__':
    build(sys.argv[1])
