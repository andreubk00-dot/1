"""OSTATOK HD interior back-wall bands (2 texels per world unit, scale 0.5).

Same layout as interior_wall_band_v4 at 2x: 8 tiles of 64 x 56 texels
(32 x 28 world units), each tiling horizontally:
  0 clinic tiles with green stripe, 1 clinic tiles cracked, 2 beige plaster,
  3 green oil paint over a dado, 4 plaster with notices, 5 brick,
  6 wallpaper with skirting, 7 lilac plaster cracked.
Pixel-art finish: flat tones, a lit top edge, a dark skirting / floor line.

    python3 tools/wa_interior_walls_hd.py <project_dir>
"""
import os
import sys
import numpy as np
from PIL import Image

W, H = 64, 56


def clamp8(a):
    return np.clip(a, 0, 255).astype(np.uint8)


def blot(a, rng, density, k):
    h, w = a.shape[:2]
    g = rng.random((h // 4 + 1, w // 4 + 1)) < density
    m = np.repeat(np.repeat(g, 4, 0), 4, 1)[:h, :w]
    a[m] *= k


def crack(a, rng, col, x0=None):
    x, y = (x0 if x0 is not None else rng.uniform(8, 56)), 4.0
    for _ in range(26):
        x += rng.choice([-1, 0, 0, 1]); y += 1
        if 0 <= int(x) < W and 0 <= int(y) < H - 8:
            a[int(y), int(x) % W] = col


def tiles(seed, cracked):
    rng = np.random.default_rng(seed)
    a = np.full((H, W, 3), (206, 210, 202), float)
    a[:20] = (196, 198, 190)                                  # plaster above
    blot(a[:20], rng, 0.1, 0.98)
    a[20:24] = (58, 112, 86)                                   # green stripe
    a[20] = (84, 140, 110)
    for y in range(24, H - 4):
        for x in range(W):
            if (y - 24) % 10 == 0 or x % 10 == 0:
                a[y, x] = (150, 156, 150)
    for ty in range(24, H - 4, 10):
        for tx in range(0, W, 10):
            a[ty + 1, tx + 1:tx + 9] *= 1.04
    if cracked:
        crack(a, rng, (110, 112, 106))
        a[30:40, 40:50] = (170, 166, 150)                     # missing tile
    a[H - 4:] = (80, 84, 80)
    a[H - 4] = (120, 124, 118)
    return a


def plaster(seed, col, cracked=False):
    rng = np.random.default_rng(seed)
    a = np.full((H, W, 3), col, float)
    blot(a, rng, 0.12, 0.97)
    blot(a, rng, 0.06, 1.03)
    a[:2] *= 1.08
    if cracked:
        crack(a, rng, np.array(col) * 0.6)
        a[6:14, 20:34] *= 0.88                                # damp stain
    a[H - 5:] = np.array(col) * 0.55
    a[H - 5] = np.array(col) * 0.75
    return a


def oil_paint(seed):
    rng = np.random.default_rng(seed)
    a = np.full((H, W, 3), (200, 196, 176), float)            # whitewash above
    blot(a, rng, 0.2, 0.96)
    a[22:H - 4] = (82, 120, 96)                               # green dado
    a[22] = (60, 90, 72)
    blot(a[23:H - 4], rng, 0.05, 1.08)                        # chipped paint
    a[H - 4:] = (60, 64, 56)
    return a


def notices(seed):
    a = plaster(seed, (176, 140, 116))
    a[8:24, 10:26] = (226, 220, 196)
    a[9, 11:25] = (150, 146, 130)
    for y in range(12, 22, 3):
        a[y, 12:24] = (140, 136, 120)
    a[10:22, 34:46] = (196, 70, 56)
    a[13:19, 37:43] = (230, 200, 180)
    return a


def brick(seed):
    rng = np.random.default_rng(seed)
    a = np.full((H, W, 3), (150, 140, 124), float)            # mortar
    BH, BW = 6, 16
    for row in range(H // BH + 1):
        off = (row % 2) * BW // 2
        for bx in range(-1, W // BW + 1):
            x0, y0 = bx * BW + off, row * BH
            c = np.array((150, 70, 50)) * rng.uniform(0.85, 1.1)
            for y in range(y0, min(H - 4, y0 + BH - 1)):
                for x in range(x0, x0 + BW - 1):
                    if 0 <= x < W:
                        a[y, x] = c * (1.1 if y == y0 else (0.85 if y == y0 + BH - 2 else 1.0))
    a[H - 4:] = (70, 52, 44)
    return a


def wallpaper(seed):
    rng = np.random.default_rng(seed)
    a = np.full((H, W, 3), (178, 160, 140), float)
    for y in range(0, H - 10, 8):
        for x in range(0, W, 8):
            a[y + 3, x + 3] = (150, 122, 104)
            a[y + 4, x + 4] = (150, 122, 104)
            a[y + 3, x + 5] = (196, 180, 160)
    blot(a[:H - 10], rng, 0.06, 0.96)
    a[24:40, 50:58] *= 0.9                                   # torn strip
    a[H - 10:H - 2] = (110, 74, 46)                           # skirting board
    a[H - 10] = (150, 104, 66)
    a[H - 2:] = (60, 40, 28)
    return a


def build(P):
    tiles_ = [tiles(1, False), tiles(2, True), plaster(3, (180, 160, 128)), oil_paint(4),
              notices(5), brick(6), wallpaper(7), plaster(8, (152, 148, 176), True)]
    sheet = np.zeros((H, W * 8, 4), np.uint8)
    for i, t in enumerate(tiles_):
        sheet[:, i * W:(i + 1) * W, :3] = clamp8(t * 0.9)   # interiors sit in shade
        sheet[:, i * W:(i + 1) * W, 3] = 255
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(sheet, 'RGBA').save(os.path.join(out, 'interior_wall_band_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
