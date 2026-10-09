"""OSTATOK HD puddles (2 texels per world unit, drawn at 0.5).

Row 0: four puddle shapes, 112 x 56 texels each (56 x 28 world units).
Row 1 (y 56): four large ones, 160 x 80 texels (80 x 40 units), laid under
street lamps where the light pours onto the wet pavement. All flattened by
the 3/4 view. Still water mirroring the overcast sky (grey-blue, deeper in the middle,
darker under the near bank), a wet darker rim where the ground is soaked,
and a pale sky sheen along the far (upper) edge. The alpha is the water mask: a shader clips light reflections
to it (clip_children does not work in Compatibility), so they stay on water.

    python3 tools/wa_puddles_hd.py <project_dir>
"""
import math
import os
import sys
import numpy as np
from PIL import Image

CW, CH = 112, 56


BW, BH = 160, 80


def shape(seed, w=CW, h=CH):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    m = np.zeros((h, w), bool)
    sx, sy = w / CW, h / CH
    # a puddle is a union of a few flat ellipses (ruts, dips)
    for _ in range(int(rng.integers(2, 5))):
        cx, cy = rng.uniform(44, 68) * sx, rng.uniform(24, 32) * sy
        rx, ry = rng.uniform(16, 30) * sx, rng.uniform(10, 15) * sy
        m |= ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 < 1.0
    # ragged 2-texel edge
    g = rng.random((h // 2 + 1, w // 2 + 1)) < 0.35
    g = np.repeat(np.repeat(g, 2, 0), 2, 1)[:h, :w]
    edge = m & ~(np.roll(m, 2, 0) & np.roll(m, -2, 0) & np.roll(m, 2, 1) & np.roll(m, -2, 1))
    m &= ~(edge & g)
    return m


def cell(m):
    h, w = m.shape
    if True:
        a = np.zeros((h, w, 4), np.uint8)
        # soaked rim one texel outside the water
        rim = (np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1) |
               np.roll(m, 2, 0) | np.roll(m, -2, 0)) & ~m
        a[rim] = (22, 20, 18, 96)
        # water mirrors the overcast sky: a grey-blue, not a black hole
        a[m] = (78, 86, 94, 205)
        # depth: the middle a little darker
        core = m & np.roll(m, 3, 0) & np.roll(m, -3, 0) & np.roll(m, 4, 1) & np.roll(m, -4, 1)
        a[core] = (64, 72, 82, 215)
        # a darker band under the near (lower) bank: the bank's reflection
        near = m & ~np.roll(m, -3, 0)
        a[near] = (52, 58, 64, 220)
        # sky sheen along the upper (far) edge, broken into pixel dashes
        top = m & ~np.roll(m, 2, 0)
        xs = np.arange(w)[None, :].repeat(h, 0)
        sheen = top & ((xs // 3) % 3 != 0)
        a[sheen] = (176, 188, 198, 230)
    return a


def build(P):
    sheet = np.zeros((CH + BH, BW * 4, 4), np.uint8)
    for i in range(4):
        sheet[:CH, i * CW:(i + 1) * CW] = cell(shape(31 + i))
        sheet[CH:, i * BW:(i + 1) * BW] = cell(shape(51 + i, BW, BH))
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(sheet, 'RGBA').save(os.path.join(out, 'puddles_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
