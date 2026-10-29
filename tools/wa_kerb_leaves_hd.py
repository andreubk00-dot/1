"""dev78: fallen leaves drifted against the kerb - four strips, HD texels
(2 per world px), the dense edge on top (the kerb side; the game turns the
strip to each kerb). python3 tools/wa_kerb_leaves_hd.py <project>"""
import os
import random
import sys

from PIL import Image

W, H, N = 192, 24, 4
LEAVES = [(196, 108, 38), (214, 138, 46), (176, 84, 34), (150, 92, 44), (206, 164, 62), (120, 74, 40), (98, 62, 36)]
GRIT = [(70, 66, 58), (84, 78, 66), (58, 54, 48)]


def strip(seed):
    rnd = random.Random(seed)
    im = Image.new('RGBA', (W, H))
    px = im.load()
    # the drift's thickness along its length: piles and gaps
    hump = []
    a, b = rnd.uniform(0, 6.28), rnd.uniform(0, 6.28)
    import math
    for x in range(W):
        t = x / W
        env = math.sin(t * math.pi) ** 0.6                      # tapers at both ends
        wave = 0.55 + 0.30 * math.sin(t * 9.0 + a) + 0.15 * math.sin(t * 23.0 + b)
        hump.append(max(0.0, env * wave) * (H - 4))
    for x in range(W):
        depth = hump[x]
        for y in range(H):
            if y > depth + 2:
                continue
            # dense against the kerb, thinning out into the road
            k = 1.0 - y / max(1.0, depth + 2)
            if rnd.random() < 0.10 + 0.78 * k * k:
                c = rnd.choice(LEAVES)
                f = rnd.uniform(0.78, 1.05)
                c = tuple(min(255, int(v * f)) for v in c)
                px[x, y] = c + (255,)
                # a leaf is two or three texels, not one
                if rnd.random() < 0.55 and x + 1 < W:
                    px[x + 1, y] = c + (255,)
                if rnd.random() < 0.35 and y + 1 < H:
                    px[x, y + 1] = tuple(int(v * 0.82) for v in c) + (255,)
            elif rnd.random() < 0.05 * k:
                px[x, y] = rnd.choice(GRIT) + (200,)
    # a soft damp shadow under the pile
    sh = Image.new('RGBA', (W, H))
    sp = sh.load()
    for x in range(W):
        for y in range(H):
            if y <= hump[x] + 3 and px[x, y][3] == 0:
                sp[x, y] = (20, 18, 16, int(46 * (1.0 - y / (hump[x] + 4))))
    sh.alpha_composite(im)
    return sh


def build(project):
    out = Image.new('RGBA', (W, H * N))
    for i in range(N):
        out.alpha_composite(strip(7100 + i * 31), (0, i * H))
    path = os.path.join(project, 'art', 'world_hd', 'kerb_leaves_hd.png')
    out.save(path)
    print('wrote', path)


if __name__ == '__main__':
    build(sys.argv[1])
