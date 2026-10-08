"""OSTATOK HD railway track strip (2 texels per world unit, drawn at 0.5).

Tileable along x: 72 world units (six sleepers 12 apart) by 88 units across.
Ballast bed with a lit crown and darker shoulders, creosoted wooden sleepers
with end checks, two rails (lit head, dark web shadow), spikes and tie plates,
weeds between the sleepers. Gauge 30 units. The track centre is at y = 44 units.

    python3 tools/wa_rail_hd.py <project_dir>
"""
import os
import sys
import numpy as np
from PIL import Image

K = 2
W, H = 72 * K, 88 * K
CY = 44 * K
SLEEPERS = (3, 15, 27, 39, 51, 63)        # 12 units apart, real proportions
HALF = 27                                 # sleeper half length (units)


def build(P):
    rng = np.random.default_rng(17)
    a = np.zeros((H, W, 4), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.abs(yy - CY) / K                              # units from the centre line
    ragged = (rng.random((H // 4 + 1, W // 4 + 1)) * 3.0)
    ragged = np.repeat(np.repeat(ragged, 4, 0), 4, 1)[:H, :W]
    bed = d < 36 + ragged
    stones = rng.random((H, W))
    base = np.array((112, 106, 96), float)
    col = base * (0.78 + 0.34 * stones[..., None])
    col *= np.where(d < 30, 1.0, 0.84)[..., None]         # shoulders a bit darker
    rust = rng.random((H, W)) < 0.08
    col[rust] = (118, 84, 58)
    a[bed, :3] = np.clip(col[bed], 0, 255)
    a[bed, 3] = 255
    edge = bed & ~np.roll(bed, 2, 0)
    a[edge, 3] = 200
    # sleepers: 34 units apart, 26 units long across, 5 units wide
    for sx in SLEEPERS:
        x0, x1 = sx * K, (sx + 5) * K
        tone = np.array((78, 60, 44), float) * rng.uniform(0.9, 1.08)
        for y in range(CY - HALF * K, CY + HALF * K + 1):
            for x in range(x0, x1):
                c = tone * (1.18 if x == x0 else (0.62 if x >= x1 - 2 else 1.0))
                if (y - CY) % 7 == 0 and x0 + 2 < x < x1 - 2:
                    c = tone * 0.78                      # grain / checks
                a[y, x, :3] = np.clip(c, 0, 255)
                a[y, x, 3] = 255
        a[CY + HALF * K + 1:CY + HALF * K + 3, x0 + 2:x1 + 2] = (30, 28, 24, 160)   # sleeper shadow
    # weeds between sleepers
    for _ in range(60):
        x, y = int(rng.integers(0, W)), int(rng.integers(CY - 30 * K, CY + 30 * K))
        h = int(rng.integers(2, 6))
        for k in range(h):
            if 0 <= y - k < H:
                a[y - k, x] = (74 + 6 * k, 92 + 4 * k, 46, 255)
    # rails: gauge ~15 units; head lit, web shadow below
    for ry in (CY - 15 * K, CY + 15 * K):
        a[ry - 2, :] = (60, 58, 56, 255)
        a[ry - 1, :] = (186, 184, 178, 255)              # polished head
        a[ry, :] = (150, 146, 140, 255)
        a[ry + 1, :] = (92, 74, 60, 255)                 # rusty web
        a[ry + 2, :] = (48, 40, 34, 255)
        a[ry + 3:ry + 5, :] = (20, 20, 18, 120)          # shadow on the ballast
        for sx in SLEEPERS:                              # tie plates + spikes
            x0 = sx * K
            a[ry - 3:ry + 4, x0 - 1:x0 + 5 * K + 1] = np.where(a[ry - 3:ry + 4, x0 - 1:x0 + 5 * K + 1, 3:4] > 0,
                                                             a[ry - 3:ry + 4, x0 - 1:x0 + 5 * K + 1], 0)
            a[ry - 3, x0 + 1:x0 + 5 * K - 1] = (70, 64, 58, 255)
            a[ry + 3, x0 + 1:x0 + 5 * K - 1] = (70, 64, 58, 255)
            a[ry - 3, x0 + 2] = (140, 136, 128, 255)
            a[ry + 3, x0 + 5 * K - 3] = (140, 136, 128, 255)
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(a, 'RGBA').save(os.path.join(out, 'rail_track_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
