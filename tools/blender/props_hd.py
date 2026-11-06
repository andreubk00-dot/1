"""OSTATOK HD yard / interior props, rendered with the vehicle pipeline.

The most common world props (wooden crates, drums, workbenches, lamps ...) were
1x art drawn at scale 0.75-0.88, i.e. ~1.2 texels per world unit - visibly
coarser than the 2-texel HD world. These are modelled in Blender at their real
size and baked like the HD vehicles (same camera, light and pixel finish), into
64-unit cells (128 texels, drawn at 0.5), bottom-anchored on the ground line.

    python3 tools/blender/props_hd.py <project_dir>

Writes art/world_hd/props_hd.png (4 x 4 cells) - order in KINDS, mirrored in
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


def woodpile():
    """split logs stacked between two stakes, a tarred plank roof on top."""
    import math
    bark = wood((92, 66, 44))
    cut = mat((176, 140, 96), rough=0.9, grime=0.2, scale=0.2)
    for row in range(4):
        for i in range(7 - (row % 2)):
            x = -15 + i * 5.0 + (row % 2) * 2.5
            z = 2.4 + row * 4.4
            cyl((x, 0, z), 2.3, 10, bark, axis='y', bevel=0.3, verts=10)
            cyl((x, 5.05, z), 2.0, 0.2, cut, axis='y', bevel=0.05, verts=10)    # cut ends
    for x in (-19, 19):
        box((x, 0, 9), (0.8, 0.8, 9.5), bark, bevel=0.1)
    box((0, 0, 19.6), (21, 6.5, 0.5), mat((40, 40, 42), rough=0.7), bevel=0.2, rot=(0.12, 0, 0))


def stump():
    bark = wood((86, 62, 42))
    ring = mat((170, 134, 92), rough=0.9, grime=0.2)
    cyl((0, 0, 0), 5.0, 6.0, bark, bevel=0.5, verts=18)
    cyl((0, 0, 6.0), 4.4, 0.2, ring, bevel=0.05, verts=18)
    box((1.5, -0.5, 9.5), (0.5, 0.5, 4.0), wood((130, 96, 62)), bevel=0.1, rot=(0, 0.35, 0))   # axe handle
    box((0.4, -0.5, 6.6), (2.0, 0.4, 1.0), steel((120, 122, 120)), bevel=0.1)                  # axe head
    for (x, y, a) in ((-9, 3, 0.4), (8, 4, -0.6)):                                             # split chunks
        box((x, y, 1.2), (2.2, 1.2, 1.2), ring, bevel=0.3, rot=(0, 0, a))


def wheelbarrow():
    tub = mat((64, 96, 72), rough=0.5, metal=0.4, grime=0.5, dust=0.4)
    iron = steel((60, 60, 58))
    box((0, 0, 7), (8, 6, 3), tub, bevel=1.0)
    box((0, 0, 9.6), (7, 5, 0.3), mat((70, 56, 40), rough=1.0), bevel=0)      # soil inside
    cyl((11, 0, 4), 3.5, 1.4, mat((30, 30, 30), rough=0.9), axis='y', bevel=0.4)
    for y in (-4, 4):
        tube([(9, y, 5), (-8, y, 7), (-16, y, 9)], 0.5, iron)
        box((-6, y, 2.5), (0.4, 0.4, 2.5), iron, bevel=0)


def milk_can():
    al = mat((170, 174, 172), rough=0.35, metal=0.7, grime=0.4, dust=0.4)
    for (x, y) in ((-4, 0), (4, 1)):
        cyl((x, y, 0), 3.4, 9, al, bevel=0.5, verts=20)
        cyl((x, y, 9), 2.4, 2.4, al, bevel=0.4, verts=20)
        cyl((x, y, 11.4), 2.8, 0.8, steel((120, 124, 124)), bevel=0.3, verts=20)
    cyl((-4, 0, 3.5), 3.5, 1.0, mat((150, 120, 60), rough=0.6), bevel=0.1, verts=20)


def signpost():
    post = wood((110, 80, 52))
    box((0, 0, 14), (0.8, 0.8, 14), post, bevel=0.2)
    box((4, 0.9, 23), (5.5, 0.3, 1.6), mat((220, 214, 196), rough=0.8), bevel=0.2)          # arrow board
    box((-3, 0.9, 19), (4.0, 0.3, 1.4), mat((200, 190, 120), rough=0.8), bevel=0.2)
    box((4, 1.15, 23), (4, 0.05, 0.3), mat((60, 60, 60), rough=0.9), bevel=0)              # lettering
    box((-3, 1.15, 19), (3, 0.05, 0.3), mat((60, 60, 60), rough=0.9), bevel=0)


# ---------------------------------------------------------------- 1.46 ---
# The street: the furniture and the small things of the roads, at the same
# quality as the yard props (they were 1x drawings).
def bench():
    slat = wood((132, 96, 62))
    iron = steel((44, 46, 46))
    for x in (-13, 13):                                         # cast-iron ends
        box((x, 1.5, 2.6), (0.7, 3.4, 2.6), iron, bevel=0.2)
        box((x, -2.4, 7.5), (0.7, 0.7, 7.5), iron, bevel=0.2)
    for y in (-0.8, 1.6, 4.0):                                  # the seat
        box((0, y, 5.6), (14.5, 1.0, 0.45), slat, bevel=0.15)
    for z in (9.0, 12.2):                                       # the back
        box((0, -2.6, z), (14.5, 0.45, 1.1), slat, bevel=0.15)
    box((6, 1.6, 6.3), (2.2, 1.2, 0.5), mat((200, 196, 180), rough=0.9), bevel=0.1)   # a newspaper left on it
    box((-15, 4, 0.4), (1.6, 1.6, 0.4), mat((60, 70, 50), rough=1.0), bevel=0.2)       # a bottle by the leg


def dumpster():
    green = mat((54, 86, 62), rough=0.55, metal=0.35, grime=0.55, dust=0.45, scale=0.12)
    dark = mat((36, 54, 42), rough=0.6, metal=0.3)
    box((0, 0, 8.5), (13, 7, 7), green, bevel=0.6)
    for x in (-8, 0, 8):                                        # pressed ribs
        box((x, 7.05, 8.5), (0.8, 0.2, 6.5), dark, bevel=0.1)
    box((0, -1.5, 16.4), (13.4, 6.2, 0.6), dark, bevel=0.3, rot=(0.32, 0, 0))   # the lid propped up
    for x in (-10, 10):
        cyl((x, 5, 1.3), 1.3, 1.4, mat((30, 30, 30), rough=0.9), axis='y', bevel=0.2)
    sphere((3, 1, 15.5), 3.6, mat((34, 34, 36), rough=0.35), scale=(1.2, 1, 0.7))   # a bag on top
    box((-14.5, 4, 1.2), (2.2, 2.0, 1.2), mat((150, 120, 80), rough=0.95), bevel=0.3)  # a box on the ground
    box((-4, 7.2, 11), (3.5, 0.1, 1.4), mat((220, 220, 210), rough=0.9), bevel=0)      # a stencil number


def el_cabinets():
    grey = mat((136, 140, 136), rough=0.55, metal=0.3, grime=0.5, dust=0.4)
    for (x, h) in ((-6, 10), (6, 8)):
        box((x, 0, h), (5.5, 4, h), grey, bevel=0.4)
        box((x, 4.05, h), (0.2, 0.1, h - 1.0), mat((90, 94, 92), rough=0.6), bevel=0)   # door split
        box((x + 2, 4.15, h + 1), (0.4, 0.2, 1.4), steel((40, 40, 40)), bevel=0)        # lock
    box((-6, 4.12, 15), (2.4, 0.1, 2.0), mat((220, 190, 40), rough=0.6), bevel=0)         # danger sign
    box((-6, 4.16, 15.2), (0.4, 0.05, 1.2), mat((30, 30, 30), rough=0.9), bevel=0)
    box((6, 4.1, 6), (4.6, 0.05, 1.0), mat((40, 70, 120), rough=0.9), bevel=0)            # a spray tag
    tube([(-11, 0, 0.5), (-11, 0, 4), (-11.5, -2, 6)], 0.4, mat((30, 30, 30), rough=0.9))  # cable


def bus_stop():
    frame = steel((70, 80, 84))
    glass_m = mat((120, 150, 160), rough=0.25, metal=0.0, grime=0.4)
    for x in (-15, 15):
        box((x, -4, 12), (0.6, 0.6, 12), frame, bevel=0.1)
        box((x, 3, 12), (0.6, 0.6, 12), frame, bevel=0.1)
    box((0, -4, 13), (15, 0.25, 9), glass_m, bevel=0)            # back panel
    box((-15, -0.5, 13), (0.25, 3.5, 9), glass_m, bevel=0)       # side panel
    box((5, -4.3, 13), (4, 0.2, 7), mat((150, 60, 50), rough=0.8), bevel=0)   # a torn poster
    box((0, -0.5, 24.4), (16, 5.2, 0.6), steel((90, 96, 98)), bevel=0.3)     # roof
    box((0, -2.5, 4.6), (12, 1.4, 0.4), wood((120, 88, 58)), bevel=0.1)      # bench inside
    for x in (-10, 10):
        box((x, -2.5, 2.3), (0.4, 1.0, 2.3), frame, bevel=0)
    box((19, 3, 13), (0.5, 0.5, 13), frame, bevel=0.1)          # the sign pole
    box((19, 3.5, 25), (3, 0.3, 3), mat((40, 90, 160), rough=0.6), bevel=0.2)
    box((19, 3.85, 25), (1.2, 0.05, 1.6), mat((230, 230, 220), rough=0.6), bevel=0)


def bollards():
    con = mat((150, 148, 140), rough=0.9, grime=0.45, dust=0.4, scale=0.2)
    band = mat((190, 50, 40), rough=0.5)
    for i, x in enumerate((-12, -4, 4, 12)):
        tilt = 0.18 if i == 2 else 0.0                          # one knocked askew
        cyl((x, 0, 0), 1.8, 7.5, con, bevel=0.4, verts=16, rot=(tilt, 0, 0))
        cyl((x, 0.0 + tilt * 6, 6.0), 1.85, 0.8, band, bevel=0.1, verts=16, rot=(tilt, 0, 0))


def planter():
    con = mat((140, 136, 126), rough=0.9, grime=0.5, dust=0.4, scale=0.2)
    box((0, 0, 3.5), (13, 5, 3.5), con, bevel=0.5)
    box((0, 0, 6.9), (12, 4, 0.3), mat((64, 50, 36), rough=1.0), bevel=0)    # soil
    dry = mat((120, 96, 52), rough=0.9, grime=0.3)
    green = mat((70, 86, 46), rough=0.9, grime=0.3)
    for (x, y, r, m) in ((-7, 0, 2.6, dry), (-1, 1, 3.2, green), (6, -0.5, 2.4, dry), (9, 1, 1.8, green)):
        sphere((x, y, 7.2 + r * 0.6), r, m, scale=(1, 0.9, 0.8))
    box((-11, 5.05, 2), (3, 0.1, 1.0), mat((50, 90, 140), rough=0.9), bevel=0)   # a tag


def tires():
    rub = mat((32, 32, 32), rough=0.85, grime=0.3, dust=0.4)
    for i in range(3):
        cyl((-3, 0, i * 3.2), 5.0, 3.0, rub, bevel=0.8, verts=22)
        cyl((-3, 0, i * 3.2 + 3.05), 2.6, 0.1, mat((20, 20, 20), rough=1.0), bevel=0, verts=18)
    cyl((8, 2, 4.8), 5.0, 3.0, rub, axis='y', bevel=0.8, verts=22, rot=(1.25, 0, 0.3))   # one leaning


def notice_board():
    post = wood((104, 76, 50))
    box((-10, 0, 9), (0.8, 0.8, 9), post, bevel=0.2)
    box((10, 0, 9), (0.8, 0.8, 9), post, bevel=0.2)
    box((0, 0.6, 13), (10.5, 0.5, 5.5), wood((140, 104, 66)), bevel=0.3)
    box((0, 0.6, 18.8), (11.5, 1.6, 0.4), mat((60, 60, 58), rough=0.8), bevel=0.1)   # a little roof
    for (x, z, c) in ((-6, 14, (220, 216, 200)), (-1, 12, (200, 200, 180)), (5, 14.5, (230, 210, 150)), (2, 10, (190, 70, 60)), (7, 10.5, (210, 210, 205))):
        box((x, 1.15, z), (2.1, 0.05, 2.4), mat(c, rough=0.9), bevel=0, rot=(0, (x % 3) * 0.06, 0))


def traffic_cone():
    orange = mat((220, 96, 36), rough=0.6, grime=0.3, dust=0.4)
    white = mat((230, 230, 220), rough=0.5, grime=0.2)
    box((0, 0, 0.4), (4.4, 4.4, 0.4), mat((40, 40, 40), rough=0.8), bevel=0.2)
    import math as _m
    from bk import mesh
    # the cone body as a tapered cylinder stack
    for i, (r0, r1, z0, m) in enumerate(((3.2, 2.7, 0.8, orange), (2.7, 2.1, 4.0, white), (2.1, 1.6, 6.6, orange), (1.6, 1.1, 8.8, white), (1.1, 0.5, 10.6, orange))):
        h = (4.0, 6.6, 8.8, 10.6, 13.5)[i] - z0
        cyl((0, 0, z0), (r0 + r1) / 2, h, m, bevel=0.2, verts=18)


def road_barrier():
    con = mat((176, 172, 160), rough=0.9, grime=0.5, dust=0.5, scale=0.2)
    red = mat((180, 50, 40), rough=0.7, grime=0.3)
    box((0, 0, 1.6), (18, 4.5, 1.6), con, bevel=0.4)
    box((0, 0, 6.5), (18, 2.4, 3.4), con, bevel=0.6)
    for x in range(-15, 16, 6):                                 # red and white stripes
        box((x, 2.45, 6.8), (1.5, 0.1, 2.6), red, bevel=0, rot=(0, 0.6, 0))
    box((6, 2.5, 3), (3.0, 0.1, 1.0), mat((120, 116, 108), rough=1.0), bevel=0)   # a chipped corner


def sandbags():
    bag = mat((150, 134, 96), rough=0.95, grime=0.4, dust=0.3, scale=0.25)
    bag2 = mat((128, 114, 80), rough=0.95, grime=0.4, dust=0.3, scale=0.25)
    for row, (n, z) in enumerate(((4, 2.0), (3, 5.6), (2, 9.0))):
        for i in range(n):
            x = (i - (n - 1) / 2.0) * 7.6
            sphere((x, 0, z), 3.6, bag if (i + row) % 2 else bag2, scale=(1.05, 0.8, 0.5))


def trash_bag():
    blk = mat((30, 30, 32), rough=0.3, grime=0.15)
    blue = mat((40, 52, 70), rough=0.3, grime=0.15)
    sphere((-3, 0, 3.0), 4.2, blk, scale=(1, 0.85, 0.75))
    sphere((4, 1, 2.4), 3.4, blue, scale=(1, 0.9, 0.7))
    sphere((-3, 0, 6.6), 1.0, blk)                              # the knot
    box((2, 4, 0.3), (2, 1.2, 0.3), mat((200, 196, 180), rough=0.9), bevel=0)   # spilt paper


def road_sign():
    pole = steel((140, 144, 140))
    cyl((0, 0, 0), 0.6, 20, pole, bevel=0.1, verts=12)
    from bk import mesh
    red = mat((190, 40, 34), rough=0.5)
    white = mat((230, 228, 220), rough=0.5)
    # a warning triangle, its face to the camera
    mesh([(-5, 0.7, 17), (5, 0.7, 17), (0, 0.7, 26)], [(0, 1, 2)], red)
    mesh([(-3.6, 0.9, 18), (3.6, 0.9, 18), (0, 0.9, 24.4)], [(0, 1, 2)], white)
    box((0, 1.0, 20.6), (0.5, 0.05, 1.6), mat((30, 30, 30), rough=0.9), bevel=0)
    box((0, 1.0, 18.7), (0.5, 0.05, 0.4), mat((30, 30, 30), rough=0.9), bevel=0)


KINDS = [('crate', crate), ('barrel', barrel), ('workbench', workbench), ('lamp', lamp),
         ('supply_crate', supply_crate), ('gas_can', gas_can), ('cardboard_boxes', cardboard_boxes),
         ('trash_bin', trash_bin), ('woodpile', woodpile), ('stump', stump), ('wheelbarrow', wheelbarrow),
         ('milk_can', milk_can), ('signpost', signpost),
         ('bench', bench), ('dumpster', dumpster), ('el_cabinets', el_cabinets), ('bus_stop', bus_stop),
         ('bollards', bollards), ('planter', planter), ('tires', tires), ('notice_board', notice_board),
         ('traffic_cone', traffic_cone), ('road_barrier', road_barrier), ('sandbags', sandbags),
         ('trash_bag', trash_bag), ('road_sign', road_sign)]
COLS = 8


def build(P):
    tmp = tempfile.mkdtemp(prefix='ostatok_props_')
    W = CELL * bk.HD
    sheet = Image.new('RGBA', (COLS * W, ((len(KINDS) + COLS - 1) // COLS) * W))
    for i, (kind, fn) in enumerate(KINDS):
        bk.reset()
        bk.camera(RENDER, 60, 40)
        fn()
        raw = bk.render(os.path.join(tmp, kind + '_raw.png'))
        spr = bk.fit_cell(bk.to_sprite(raw, RENDER, colours=24), W)
        sheet.alpha_composite(spr, ((i % COLS) * W, (i // COLS) * W))
        print('prop', kind, flush=True)
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, 'props_hd.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
