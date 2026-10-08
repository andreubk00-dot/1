"""OSTATOK HD interior trim (2 texels per world unit, drawn at 0.5).

interior_trim_v4 drew wall-foot shadows as smooth alpha gradients - the only
soft shading left inside buildings. Same layout at 2x (256 x 64):
  (0,0,32,16)   shadow under the back wall + skirting board
  (32,0,32,16)  front wall edge strip (skirting seen from above)
  (64,0,16,32)  shadow along the west wall
  (80,0,16,32)  shadow along the east wall
  (96,0,32,16)  door threshold: worn wooden sill with a steel nosing
Shadows are three flat alpha steps, the skirting a lit / dark board.

    python3 tools/wa_interior_trim_hd.py <project_dir>
"""
import os
import sys
import numpy as np
from PIL import Image

K = 2


def build(P):
    a = np.zeros((32 * K, 128 * K, 4), np.uint8)
    # back wall foot: skirting board then a stepped shadow on the floor
    x0, x1 = 0, 32 * K
    a[0:3, x0:x1] = (96, 72, 50, 255)
    a[0, x0:x1] = (130, 100, 70, 255)
    a[3, x0:x1] = (52, 38, 28, 255)
    for y, al in ((4, 110), (5, 110), (6, 80), (7, 80), (8, 80), (9, 50), (10, 50), (11, 50), (12, 50), (13, 26), (14, 26), (15, 26), (16, 26)):
        a[y, x0:x1] = (0, 0, 0, al)
    # front edge strip: low skirting seen from above
    x0, x1 = 32 * K, 64 * K
    a[20:27, x0:x1] = (96, 72, 50, 255)
    a[20, x0:x1] = (130, 100, 70, 255)
    a[27, x0:x1] = (40, 30, 22, 255)
    # side wall shadows: three flat steps (west wall lit side, east wall darker)
    for (x0, steps) in ((64 * K, ((0, 3, 96), (3, 7, 60), (7, 12, 30))), (80 * K, ((29, 32, 110), (25, 29, 70), (20, 25, 36)))):
        for (u0, u1, al) in steps:
            a[:, x0 + u0:x0 + u1] = (0, 0, 0, al)
    # threshold: worn plank sill with a steel nosing and nail heads
    x0 = 96 * K
    rng = np.random.default_rng(5)
    for y in range(4, 26):
        for x in range(x0 + 2, x0 + 62):
            c = np.array((112, 82, 56)) * (0.92 + 0.12 * rng.random())
            if (y - 4) % 7 == 0:
                c = np.array((70, 52, 36))
            a[y, x] = tuple(int(v) for v in c) + (255,)
    a[4:6, x0 + 2:x0 + 62] = (150, 150, 146, 255)
    a[6, x0 + 2:x0 + 62] = (90, 90, 86, 255)
    for x in range(x0 + 6, x0 + 60, 12):
        a[14, x] = (60, 58, 56, 255)
        a[21, x + 4] = (60, 58, 56, 255)
    a[26:29, x0 + 2:x0 + 62] = (0, 0, 0, 70)
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(a, 'RGBA').save(os.path.join(out, 'interior_trim_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
