"""OSTATOK 1.58: front door leaves without the black slit.

door_leaf_hd.png has 48 px cells (24 world units) but the door itself filled
only 36 px (40 for the industrial / military doors); the rest of the cell was
opaque black. The doorway of every entrance is 20 units wide (entrance_hd:
x -10..+10), so a leaf hung at door_x - 9 left that black strip standing on
the wall to the right of the door. Here each door is stretched to exactly
40 px = 20 units and the rest of the cell is cleared.

    python3 tools/door_leaf_v2.py <project_dir>

Writes art/world_hd/door_leaf_v2.png (same layout as door_leaf_hd.png).
"""
import os
import sys

import numpy as np
from PIL import Image

CELL, DOOR = 48, 40


def build(P):
    src = Image.open(os.path.join(P, 'art', 'world_hd', 'door_leaf_hd.png')).convert('RGBA')
    a = np.array(src)
    out = Image.new('RGBA', src.size)
    for st in range(src.width // CELL):
        c = a[:, st * CELL:(st + 1) * CELL]
        black = [x for x in range(CELL) if (c[:, x, 3] > 200).all() and (c[:, x, :3].max(axis=1) < 20).all()]
        w = min(black) if black else CELL
        door = Image.fromarray(c[:, :w].copy(), 'RGBA')
        if w != DOOR:
            door = door.resize((DOOR, door.height), Image.NEAREST)
        out.paste(door, (st * CELL, 0))
        print('leaf', st, w, '->', DOOR)
    out.save(os.path.join(P, 'art', 'world_hd', 'door_leaf_v2.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
