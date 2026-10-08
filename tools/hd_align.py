"""Keeps an HD twin atlas in register with the 1x atlas it replaces.

The game places 1x atlas regions by hand-tuned offsets (a drainpipe 9 px in
from the wall corner, graffiti in rows 44..68, ...). An HD cell whose artwork
sits elsewhere in the cell shows up displaced - a drainpipe hanging in the air
beside the building, graffiti cut in half. align_cells() moves the artwork of
every HD cell so its bounding box is centred where the 1x artwork is, then
pulls it inside the bounds the game crops (`keep`, in 1x pixels).

    python3 tools/hd_align.py <project_dir>
"""
import os
import sys
import numpy as np
from PIL import Image


def _bbox(a):
    ys, xs = np.nonzero(a[..., 3] > 0)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def align_cells(hd, ref, cw, ch, k=2, keep=None, x_only=()):
    """hd, ref: RGBA images; cw, ch: 1x cell size; keep: {cell: (y0, y1)} rows (1x)
    the game crops from that cell; x_only: cells cropped from the bottom up by a
    varying height (they stay anchored to the ground, only move sideways)."""
    keep = keep or {}
    h = np.array(hd.convert('RGBA'))
    r = np.array(ref.convert('RGBA'))
    out = np.zeros_like(h)
    for cy in range(r.shape[0] // ch):
        for cx in range(r.shape[1] // cw):
            hc = h[cy * ch * k:(cy + 1) * ch * k, cx * cw * k:(cx + 1) * cw * k]
            b2 = _bbox(hc)
            b1 = _bbox(r[cy * ch:(cy + 1) * ch, cx * cw:(cx + 1) * cw])
            if b2 is None:
                continue
            dx = dy = 0
            if b1 is not None:
                dx = int(round((b1[0] + b1[2]) * k / 2 - (b2[0] + b2[2]) / 2))
                dy = int(round((b1[1] + b1[3]) * k / 2 - (b2[1] + b2[3]) / 2))
            if cx in x_only:
                dy = 0
            y0, y1 = keep.get(cx, (0, ch))
            dx = max(-b2[0], min(cw * k - b2[2], dx))
            if cx not in x_only:
                dy = max(y0 * k - b2[1], min(y1 * k - b2[3], dy)) if b2[3] - b2[1] <= (y1 - y0) * k else y0 * k - b2[1]
            moved = np.zeros_like(hc)
            sy0, sy1 = max(0, -dy), min(hc.shape[0], hc.shape[0] - dy)
            sx0, sx1 = max(0, -dx), min(hc.shape[1], hc.shape[1] - dx)
            moved[sy0 + dy:sy1 + dy, sx0 + dx:sx1 + dx] = hc[sy0:sy1, sx0:sx1]
            out[cy * ch * k:(cy + 1) * ch * k, cx * cw * k:(cx + 1) * cw * k] = moved
    return Image.fromarray(out, 'RGBA')


# facade_details_v1 regions used by main_script_mod.gd::_dress_tall_facade
# (drainpipe, ivy and grime are cut from the bottom of the cell by facade height)
DETAIL_KEEP = {3: (20, 60), 4: (0, 64), 5: (44, 68), 6: (44, 68)}
DETAIL_X_ONLY = (0, 1, 2)


def align_details(P):
    hd_path = os.path.join(P, 'art', 'world_hd', 'facade_details_hd.png')
    ref = Image.open(os.path.join(P, 'facade_details_v1.png'))
    align_cells(Image.open(hd_path), ref, 48, 80, keep=DETAIL_KEEP, x_only=DETAIL_X_ONLY).save(hd_path)


if __name__ == '__main__':
    align_details(sys.argv[1] if len(sys.argv) > 1 else '.')
