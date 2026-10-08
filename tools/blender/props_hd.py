"""OSTATOK HD yard / interior props, rendered with the vehicle pipeline.

The most common world props (wooden crates, drums, workbenches, lamps ...) were
1x art drawn at scale 0.75-0.88, i.e. ~1.2 texels per world unit - visibly
coarser than the 2-texel HD world. These are modelled in Blender at their real
size and baked like the HD vehicles (same camera, light and pixel finish), into
64-unit cells (128 texels, drawn at 0.5), bottom-anchored on the ground line.

    python3 tools/blender/props_hd.py <project_dir>

Writes art/world_hd/props_hd.png (4 x 2 cells) - order in KINDS, mirrored in
main_script_mod.gd PROP_HD_KINDS.
"""
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import numpy as np
from PIL import Image

import bk
from bk import box, cyl, mat, tube, sphere

CELL = 64
RENDER = 80


def wood(c=(140, 102, 64)):
    return mat(c, rough=0.9, grime=0.35, dust=0.3, scale=0.2)


def steel(c=(110, 112, 108)):
    return mat(c, rough=0.5, metal=0.5, grime=0.3, dust=0.3)


def crate():
    w = wood()
    dark = wood((96, 70, 46))
    box((0, 0, 8), (10, 8, 8), dark, bevel=0.2)
    for z in (2.2, 7.6, 13.0):                                # slats on every face
        box((0, 8.05, z), (10, 0.3, 2.2), w, bevel=0.15)
        box((10.05, 0, z), (0.3, 8, 2.2), w, bevel=0.15)
    box((0, 0, 16.1), (10.2, 8.2, 0.3), w, bevel=0.1)
    for x in (-9.4, 9.4):                                      # corner posts
        box((x, 7.6, 8), (0.9, 0.7, 8.1), dark, bevel=0.1)
    box((0, 8.4, 8), (8.6, 0.3, 0.6), dark, bevel=0, rot=(0, 0.75, 0))   # diagonal brace
    box((0, 8.5, 8), (1.6, 0.1, 1.0), mat((210, 200, 170), rough=0.9), bevel=0)   # stencil label


def barrel():
    body = mat((132, 74, 44), rough=0.7, metal=0.3, grime=0.5, dust=0.4, scale=0.12)
    band = mat((96, 52, 34), rough=0.6, metal=0.4)
    cyl((0, 0, 0), 6.2, 18, body, bevel=0.5, verts=28)
    for z in (5.5, 12.5):
        cyl((0, 0, z), 6.35, 0.8, band, bevel=0.2, verts=28)
    cyl((0, 0, 18), 5.6, 0.3, mat((70, 46, 32), rough=0.8), bevel=0.1, verts=28)
    cyl((2.6, -1.4, 18.2), 0.9, 0.4, band, bevel=0.1)
    box((0, 6.0, 9), (2.4, 0.2, 2.0), mat((200, 170, 40), rough=0.6), bevel=0)   # hazard label


def workbench():
    top = wood((126, 92, 60))
    iron = steel((70, 72, 70))
    box((0, 0, 10.5), (20, 8, 1.0), top, bevel=0.3)
    for x in (-18, 18):
        for y in (-6, 6):
            box((x, y, 5), (0.9, 0.9, 5), iron, bevel=0)
    box((0, 0, 3.0), (18.5, 6.5, 0.4), wood((100, 74, 50)), bevel=0.1)   # lower shelf
    box((14, 6.2, 12.8), (3, 2, 1.4), steel((60, 90, 120)), bevel=0.2)  # vise
    cyl((14, 9.5, 12.8), 0.4, 3, iron, axis='y', bevel=0)
    box((-8, -1, 11.9), (4, 2.4, 0.4), steel((150, 40, 30)), bevel=0.1)  # toolbox lid
    box((-8, -1, 11.6), (4, 2.4, 0.2), steel((120, 34, 26)), bevel=0)
    box((2, 2, 11.7), (3.5, 0.4, 0.2), steel((160, 160, 156)), bevel=0)  # spanner
    box((0, 0, 4.2), (6, 4, 1.2), mat((70, 60, 50), rough=0.9), bevel=0.2)   # crate on shelf


def lamp():
    pole = steel((96, 100, 102))
    cyl((0, 0, 0), 1.4, 44, pole, bevel=0.3, verts=16)
    cyl((0, 0, 0), 2.4, 3.0, pole, bevel=0.4, verts=18)
    box((0, 1.5, 6), (1.2, 0.3, 2.0), mat((180, 170, 140), rough=0.9), bevel=0)   # notice on the pole
    tube([(0, 0, 43), (3, 0, 46), (10, 0, 46.5)], 0.8, pole)          # arm to the side
    box((12.5, 0, 46.2), (4.0, 2.6, 1.6), steel((60, 64, 66)), bevel=0.6)     # lamp head
    box((12.5, 0, 44.5), (3.2, 2.0, 0.2), mat((255, 236, 180), rough=0.3, emit=(255, 226, 160)), bevel=0)


def supply_crate():
    olive = mat((86, 98, 62), rough=0.7, grime=0.35, dust=0.4, scale=0.15)
    edge = mat((60, 68, 44), rough=0.7)
    box((0, 0, 6), (11, 7, 6), olive, bevel=0.5)
    box((0, 0, 12.2), (11.3, 7.3, 0.4), edge, bevel=0.2)
    for x in (-7, 7):
        box((x, 7.1, 6), (1.2, 0.2, 6), edge, bevel=0)
        box((x, 7.3, 9.5), (1.6, 0.2, 0.8), steel((40, 40, 40)), bevel=0)   # latch
    box((0, 7.15, 6), (3.2, 0.1, 1.4), mat((210, 206, 180), rough=0.9), bevel=0)   # stencil


def gas_can():
    red = mat((160, 46, 34), rough=0.45, metal=0.2, grime=0.3, dust=0.4)
    box((0, 0, 7), (5.5, 2.8, 7), red, bevel=0.6)
    box((0, 2.85, 7), (4.2, 0.12, 5.2), mat((178, 58, 44), rough=0.45, metal=0.2), bevel=0.2)   # embossed panel
    for x in (-2.4, 0, 2.4):
        box((x, 0, 14.6), (0.6, 2.2, 0.8), red, bevel=0.2)     # triple handle
    cyl((4, 0, 14), 0.9, 2, steel((60, 60, 58)), bevel=0.1)


def cardboard_boxes():
    card = mat((168, 132, 88), rough=0.95, grime=0.25, dust=0.3, scale=0.2)
    tape = mat((196, 170, 120), rough=0.6)
    for (x, y, z, s) in ((-5, 0, 0, (6, 5, 4.5)), (6, 1, 0, (5, 4.5, 4)), (-2, -1, 9, (5, 4, 3.5))):
        box((x, y, z + s[2]), s, card, bevel=0.3)
        box((x, y, z + 2 * s[2] + 0.05), (0.8, s[1] + 0.05, 0.05), tape, bevel=0)
    box((6, 1, 8.2), (5.2, 0.4, 0.3), card, bevel=0.1, rot=(0.6, 0, 0))   # open flap


def trash_bin():
    green = mat((58, 92, 70), rough=0.55, metal=0.3, grime=0.5, dust=0.4)
    cyl((0, 0, 0), 5.6, 13, green, bevel=0.4, verts=24)
    cyl((0, 0, 13), 6.0, 0.8, steel((70, 74, 72)), bevel=0.3, verts=24)
    sphere((1, -1, 14.2), 3.2, mat((40, 40, 42), rough=0.4), scale=(1, 1, 0.6))   # bag overflowing
    box((-3, 5.2, 4), (2, 0.3, 1.5), mat((200, 196, 180), rough=0.9), bevel=0)  # sticker


KINDS = [('crate', crate), ('barrel', barrel), ('workbench', workbench), ('lamp', lamp),
         ('supply_crate', supply_crate), ('gas_can', gas_can), ('cardboard_boxes', cardboard_boxes),
         ('trash_bin', trash_bin)]


def build(P):
    tmp = tempfile.mkdtemp(prefix='ostatok_props_')
    W = CELL * bk.HD
    sheet = Image.new('RGBA', (4 * W, 2 * W))
    for i, (kind, fn) in enumerate(KINDS):
        bk.reset()
        bk.camera(RENDER, 60, 40)
        fn()
        raw = bk.render(os.path.join(tmp, kind + '_raw.png'))
        spr = bk.fit_cell(bk.to_sprite(raw, RENDER, colours=24), W)
        sheet.alpha_composite(spr, ((i % 4) * W, (i // 4) * W))
        print('prop', kind, flush=True)
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, 'props_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
