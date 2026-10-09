"""OSTATOK HD puddles (2 texels per world unit, drawn at 0.5).

Four puddle shapes, 112 x 56 texels each (56 x 28 world units), flattened by
the 3/4 view. Dark still water that lets the ground show through faintly, a
wet darker rim where the ground is soaked, and a pale sky sheen along the far
(upper) edge. The alpha is the water mask: a shader clips light reflections
to it (clip_children does not work in Compatibility), so they stay on water.

    python3 tools/wa_puddles_hd.py <project_dir>
"""
import math
import os
import sys
import numpy as np
from PIL import Image

CW, CH = 112, 56


def shape(seed):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:CH, 0:CW].astype(float)
    m = np.zeros((CH, CW), bool)
    # a puddle is a union of a few flat ellipses (ruts, dips)
    for _ in range(int(rng.integers(2, 5))):
        cx, cy = rng.uniform(44, 68), rng.uniform(24, 32)
        rx, ry = rng.uniform(16, 30), rng.uniform(10, 15)
        m |= ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 < 1.0
    # ragged 2-texel edge
    g = rng.random((CH // 2 + 1, CW // 2 + 1)) < 0.35
    g = np.repeat(np.repeat(g, 2, 0), 2, 1)[:CH, :CW]
    edge = m & ~(np.roll(m, 2, 0) & np.roll(m, -2, 0) & np.roll(m, 2, 1) & np.roll(m, -2, 1))
    m &= ~(edge & g)
    return m


def build(P):
    sheet = np.zeros((CH, CW * 4, 4), np.uint8)
    for i in range(4):
        m = shape(31 + i)
        a = np.zeros((CH, CW, 4), np.uint8)
        # soaked rim one texel outside the water
        rim = (np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1) |
               np.roll(m, 2, 0) | np.roll(m, -2, 0)) & ~m
        a[rim] = (14, 16, 18, 70)
        a[m] = (34, 40, 46, 150)
        # depth: the middle a little darker
        core = m & np.roll(m, 3, 0) & np.roll(m, -3, 0) & np.roll(m, 4, 1) & np.roll(m, -4, 1)
        a[core] = (26, 32, 38, 170)
        # sky sheen along the upper (far) edge, broken into pixel dashes
        top = m & ~np.roll(m, 2, 0)
        xs = np.arange(CW)[None, :].repeat(CH, 0)
        sheen = top & ((xs // 3) % 3 != 0)
        a[sheen] = (140, 154, 166, 190)
        sheet[:, i * CW:(i + 1) * CW] = a
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(sheet, 'RGBA').save(os.path.join(out, 'puddles_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
