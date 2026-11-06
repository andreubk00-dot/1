"""OSTATOK 1.46: the common 1x props of world_props_v19 remodelled in Blender.

Shelves, cabinets, desks, beds, fridges, litter ... were flat drawings - the
most visible low-quality things inside buildings. Each is modelled at real size,
rendered with the HD pipeline (front 3/4 camera, the game's light) and fitted
into the very same atlas cell, bottom-aligned on the old drawing's ground line
and inside its old bounding box. The layout of the atlas does not change, so the
placement, footprints and collision of every piece stay as they were.

    python3.13 tools/blender/props_v20.py <project_dir> [kind ...]

Reads world_props_v19.png, writes art/world_hd/world_props_v20.png.
"""
import math
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import numpy as np
from PIL import Image

import bk
from bk import box, cyl, mat, tube, sphere, mesh

RENDER = 80


def wood(c=(140, 102, 64)):
    return mat(c, rough=0.85, grime=0.35, dust=0.25, scale=0.2)


def steel(c=(110, 112, 108)):
    return mat(c, rough=0.5, metal=0.45, grime=0.35, dust=0.3)


def paint(c, grime=0.35):
    return mat(c, rough=0.6, metal=0.15, grime=grime, dust=0.3, scale=0.12)


def cloth(c):
    return mat(c, rough=0.95, grime=0.4, dust=0.2, scale=0.25)


PAPER = (214, 208, 190)
COLOURS = [(150, 50, 40), (60, 90, 130), (170, 140, 60), (70, 100, 70), (200, 196, 180), (120, 80, 50), (110, 60, 90)]


# ---------------------------------------------------------------- furniture
def metal_shelving():
    post = steel((96, 100, 98))
    shelf = steel((120, 124, 120))
    for x in (-22, 22):
        for y in (-3, 3):
            box((x, y, 15), (0.6, 0.6, 15), post, bevel=0)
    for z in (1.5, 9.5, 17.5, 25.5):
        box((0, 0, z), (22.4, 3.6, 0.35), shelf, bevel=0.1)
    k = 0
    for z in (1.85, 9.85, 17.85):
        x = -20.5
        while x < 19:
            k += 1
            w = 1.6 + (k * 7 % 5) * 0.8
            h = 3 + (k * 3 % 4) * 1.0
            if k % 7 == 3:
                x += 3.5                       # a gap: taken
                continue
            c = COLOURS[k % len(COLOURS)]
            if k % 3 == 0:
                cyl((x + w * 0.5, 1, z), 1.4, h * 0.8, paint(c), bevel=0.2, verts=12)   # tins
                w = 3.0
            else:
                box((x + w * 0.5, 0.5, z + h * 0.5), (w * 0.5, 3.2, h * 0.5), cloth(c) if k % 2 else mat((168, 132, 88), rough=0.95, grime=0.3), bevel=0.15)
            x += w + 0.6
    box((-10, 0.5, 26.9), (6, 3.5, 1.1), mat((168, 132, 88), rough=0.95, grime=0.3), bevel=0.2)   # boxes on top
    box((9, 0.5, 27.4), (4, 3.2, 1.6), mat((150, 118, 80), rough=0.95, grime=0.3), bevel=0.2)


def tool_case():
    body = paint((50, 54, 52))
    box((0, 0, 4), (12, 4.5, 4), body, bevel=0.8)
    box((0, 0, 8.05), (11.6, 4.1, 0.15), paint((62, 66, 64)), bevel=0)
    box((0, 4.55, 4.6), (11.8, 0.1, 0.25), mat((30, 30, 30), rough=0.8), bevel=0)   # lid seam
    for x in (-7, 7):
        box((x, 4.7, 5), (1.2, 0.3, 1.0), steel((170, 170, 160)), bevel=0.1)          # latches
    tube([(-3, 0, 8.2), (-3, 0, 10), (3, 0, 10), (3, 0, 8.2)], 0.6, mat((24, 24, 24), rough=0.6))
    box((5, 4.62, 2.2), (2.6, 0.05, 0.9), mat((200, 160, 40), rough=0.7), bevel=0)    # a label


def extinguisher():
    red = mat((176, 40, 32), rough=0.4, metal=0.2, grime=0.3, dust=0.3)
    cyl((0, 0, 0), 2.6, 14, red, bevel=0.8, verts=20)
    cyl((0, 0, 14), 1.0, 1.6, steel((60, 60, 60)), bevel=0.2)
    box((0.6, 0, 16.2), (2.4, 0.5, 0.4), mat((30, 30, 30), rough=0.6), bevel=0.1)    # handle
    tube([(1, 0, 15.5), (3.2, 0.8, 14), (3.4, 1.4, 8), (2.6, 1.8, 5)], 0.4, mat((26, 26, 26), rough=0.7))
    box((0, 2.55, 7.5), (1.6, 0.1, 2.4), mat((226, 222, 210), rough=0.8), bevel=0)    # instructions


def cabinet():
    grey = paint((128, 132, 126))
    box((0, 0, 14), (11, 5, 14), grey, bevel=0.5)
    box((0, 5.05, 14), (0.15, 0.1, 13.2), mat((70, 72, 70), rough=0.6), bevel=0)
    for x in (-1.6, 1.6):
        box((x, 5.25, 15), (0.3, 0.3, 2.0), steel((40, 40, 40)), bevel=0.1)
    for x in (-6, 6):                                              # pressed vents
        for z in (23, 24.4, 25.8):
            box((x, 5.08, z), (2.5, 0.05, 0.25), mat((90, 94, 90), rough=0.6), bevel=0)
    box((0, 0, 28.4), (10.5, 4.5, 0.4), grey, bevel=0.2)
    box((-4, 0, 29.6), (4, 3, 1.0), mat((168, 132, 88), rough=0.95), bevel=0.2)        # a box on top
    box((6, 5.1, 9), (2.4, 0.05, 1.6), mat((214, 208, 190), rough=0.9), bevel=0)       # a note


def filing_cabinet():
    body = paint((104, 116, 100))
    box((0, 0, 16), (6.5, 6, 16), body, bevel=0.5)
    for i, z in enumerate((4, 12, 20, 28)):
        out = 3.0 if i == 1 else 0.0
        box((0, 6.0 + out, z), (6.1, 0.4 + out, 3.6), body if not out else paint((114, 126, 110)), bevel=0.3)
        box((0, 6.5 + out * 2, z + 1), (2.0, 0.3, 0.4), steel((180, 180, 170)), bevel=0.1)
        box((0, 6.45 + out * 2, z + 2.3), (1.4, 0.05, 0.6), mat(PAPER, rough=0.9), bevel=0)
    for j in range(5):                                             # files in the open drawer
        box((-4 + j * 1.9, 7.2, 13.6), (0.8, 2.6, 1.6), mat(COLOURS[j], rough=0.9), bevel=0.1)


def desk():
    top = wood((122, 84, 52))
    box((0, 0, 14), (17, 7, 0.8), top, bevel=0.3)
    box((10, 0, 7), (6.5, 6.5, 6.6), wood((108, 74, 46)), bevel=0.3)            # drawer pedestal
    for z in (3.5, 9.5):
        box((10, 6.55, z), (5.8, 0.1, 2.4), wood((96, 66, 42)), bevel=0)
        box((10, 6.8, z), (1.2, 0.25, 0.3), steel((170, 160, 120)), bevel=0)
    for y in (-6, 6):
        box((-15.5, y, 7), (0.8, 0.8, 6.6), wood((96, 66, 42)), bevel=0)
    box((-4, -5.5, 7), (11, 0.5, 5), wood((108, 74, 46)), bevel=0)              # modesty panel
    box((-6, -1, 18.4), (5, 3.5, 3.8), paint((180, 176, 160)), bevel=0.8)       # a CRT monitor
    box((-6, 2.55, 18.6), (3.8, 0.1, 2.8), mat((30, 40, 44), rough=0.25), bevel=0.2)
    box((-6, -1, 15), (2, 2, 0.4), paint((160, 156, 140)), bevel=0.2)
    box((6, 2, 15.0), (3.2, 2.2, 0.2), mat(PAPER, rough=0.9), bevel=0, rot=(0, 0, 0.2))
    box((7, 1.6, 15.3), (2.8, 2.0, 0.15), mat((200, 200, 190), rough=0.9), bevel=0, rot=(0, 0, -0.15))
    cyl((12, -3, 14.8), 0.9, 2.2, mat((200, 190, 170), rough=0.6), bevel=0.2, verts=12)   # a mug


def tipped_chair():
    w = wood((130, 80, 50))
    seat = cloth((130, 70, 50))
    # the chair on its back: seat stands upright, legs point at the camera
    box((0, 0, 6), (6, 0.8, 5.5), seat, bevel=0.5)
    box((0, -3, 1.0), (6, 6, 0.8), w, bevel=0.3)                                 # backrest on the floor
    for x in (-5, 5):
        for z in (2, 10):
            box((x, 5, z), (0.6, 5, 0.6), w, bevel=0.1)
    box((0, 9.5, 10), (5, 0.5, 0.5), w, bevel=0.1)


def old_mattress():
    m = cloth((176, 166, 136))
    box((0, 0, 2), (22, 10, 2), m, bevel=1.4, seg=3)
    for x in range(-18, 19, 6):                                    # quilting
        for y in (-5, 0, 5):
            sphere((x, y, 4.05), 0.5, mat((140, 130, 104), rough=1.0), scale=(1, 1, 0.3))
    sphere((8, 2, 4.0), 5.0, mat((128, 104, 70), rough=1.0), scale=(1.3, 1.0, 0.06))   # stain
    sphere((-12, -4, 4.0), 3.0, mat((140, 120, 84), rough=1.0), scale=(1.2, 1.0, 0.06))
    box((0, 10.05, 2), (21.5, 0.1, 0.4), mat((120, 110, 90), rough=1.0), bevel=0)      # piping


def old_fridge():
    white = mat((214, 210, 196), rough=0.45, metal=0.1, grime=0.55, dust=0.35, scale=0.1)
    box((0, 0, 21), (10, 6, 21), white, bevel=2.0, seg=4)
    box((0, 6.05, 30), (9.0, 0.1, 0.15), mat((120, 118, 110), rough=0.6), bevel=0)   # freezer seam
    box((7.6, 6.4, 23), (0.5, 0.6, 4.0), steel((190, 190, 180)), bevel=0.2)            # chrome handle
    box((0, 6.1, 38), (3.2, 0.1, 0.5), steel((170, 170, 160)), bevel=0)                # badge
    for (x, z, r) in ((-6, 3, 1.4), (5, 2, 1.0), (-7.5, 14, 0.7), (8, 34, 0.8)):
        sphere((x, 6.0, z), r, mat((120, 70, 40), rough=1.0), scale=(1.2, 0.2, 1))     # rust
    box((-3, 6.12, 19), (1.6, 0.05, 2.0), mat((200, 80, 60), rough=0.9), bevel=0)      # a note on a magnet
    for x in (-8, 8):
        box((x, 4, 0.5), (1, 1, 0.5), mat((30, 30, 30), rough=0.9), bevel=0.1)


def cot():
    frame = steel((80, 90, 74))
    canvas = cloth((96, 108, 70))
    box((0, 0, 7), (15.5, 6, 0.6), canvas, bevel=0.4)
    for y in (-6, 6):
        box((0, y, 7), (16, 0.5, 0.5), frame, bevel=0)
    for x in (-14, 0, 14):
        tube([(x, -6, 0.2), (x, 6, 7)], 0.35, frame)
        tube([(x, 6, 0.2), (x, -6, 7)], 0.35, frame)
    box((-9, 0, 8.6), (4.5, 5, 1.0), cloth((150, 60, 50)), bevel=0.6)              # folded blanket
    sphere((11, 0, 8.4), 3.0, cloth((200, 196, 180)), scale=(1.2, 1.4, 0.4))       # pillow


def chair():
    w = wood((130, 82, 50))
    box((0, 0, 8), (5, 4.5, 0.6), cloth((140, 74, 52)), bevel=0.4)
    for x in (-4.3, 4.3):
        for y in (-3.8, 3.8):
            box((x, y, 4), (0.45, 0.45, 4), w, bevel=0)
        box((x, -4, 12.5), (0.5, 0.5, 4.5), w, bevel=0)
    box((0, -4, 15.5), (4.8, 0.6, 1.8), w, bevel=0.3)
    box((0, -4, 11.5), (4.5, 0.4, 0.5), w, bevel=0)


def electrical_box():
    grey = paint((126, 130, 124))
    box((0, 0, 16), (8, 3, 8), grey, bevel=0.5)
    box((0, 3.05, 16), (7.2, 0.1, 7.2), paint((136, 140, 134)), bevel=0)
    box((5, 3.3, 16), (0.5, 0.3, 1.2), steel((40, 40, 40)), bevel=0.1)
    mesh([(-3, 3.2, 21.5), (1, 3.2, 21.5), (-1, 3.2, 24.8)], [(0, 1, 2)], mat((220, 190, 40), rough=0.6))
    box((-1, 3.25, 22.6), (0.25, 0.05, 0.9), mat((30, 30, 30), rough=0.9), bevel=0)
    tube([(-5, 0, 8), (-5, 0.2, 6.5)], 0.6, mat((30, 30, 30), rough=0.8))   # conduit stubs
    tube([(4, 0, 24), (4, 0, 26)], 0.5, mat((40, 40, 40), rough=0.8))


def radiator():
    cream = mat((206, 196, 170), rough=0.55, metal=0.1, grime=0.5, dust=0.3, scale=0.1)
    for i in range(9):
        x = -11 + i * 2.75
        box((x, 0, 8), (1.1, 2.2, 6.5), cream, bevel=0.8, seg=3)
    box((0, 0, 14), (12.2, 1.0, 0.6), cream, bevel=0.3)
    box((0, 0, 2), (12.2, 1.0, 0.6), cream, bevel=0.3)
    for x in (-10, 10):
        cyl((x, 0, 0), 0.6, 1.6, steel((90, 90, 86)), bevel=0)
    tube([(12.5, 0, 4), (15, 0, 4), (15, 0, 0)], 0.6, steel((110, 110, 104)))
    for (x, z) in ((-6, 3.5), (4, 12), (8, 5)):
        sphere((x, 2.2, z), 0.6, mat((130, 76, 44), rough=1.0), scale=(1.2, 0.3, 1))


def locker():
    blue = paint((80, 100, 112))
    for i, x in enumerate((-7.4, 0, 7.4)):
        open_ = i == 2
        box((x, 0, 20), (3.6, 4, 20), blue, bevel=0.3)
        if open_:
            box((x + 3.4, 6.4, 20), (0.3, 2.6, 19), paint((90, 110, 122)), bevel=0.1, rot=(0, 0, -0.35))
            box((x, 3.0, 20), (3.2, 0.6, 19), mat((30, 34, 36), rough=0.9), bevel=0)    # inside
            box((x, 2.4, 30), (2.6, 0.5, 3.0), cloth((110, 90, 60)), bevel=0.3)          # a jacket
        else:
            box((x, 4.05, 20), (3.3, 0.1, 19), paint((88, 108, 120)), bevel=0.1)
            for z in (34, 35.4, 36.8):
                box((x, 4.2, z), (2.2, 0.05, 0.3), mat((40, 50, 56), rough=0.7), bevel=0)
            box((x + 2.2, 4.3, 20), (0.3, 0.3, 1.6), steel((180, 180, 170)), bevel=0.1)
            box((x, 4.2, 28), (1.2, 0.05, 0.7), mat(PAPER, rough=0.9), bevel=0)          # name tag
    box((-7.4, 4.25, 12), (1.4, 0.05, 1.8), mat((190, 70, 50), rough=0.9), bevel=0)     # sticker


def ammo_crate():
    olive = mat((86, 98, 62), rough=0.6, metal=0.3, grime=0.4, dust=0.3, scale=0.12)
    box((-4, 0, 4), (9, 5, 4), wood((112, 104, 66)), bevel=0.4)
    for x in (-11, 3):
        box((x, 5.05, 4), (0.8, 0.1, 3.6), wood((90, 84, 52)), bevel=0)
    box((-4, 5.1, 4.5), (3.5, 0.05, 1.2), mat((214, 210, 186), rough=0.9), bevel=0)    # stencil
    box((9, 1, 3.5), (4, 3, 3.5), olive, bevel=0.4)                                    # a steel ammo can
    box((9, 1, 7.2), (4.2, 3.2, 0.3), olive, bevel=0.1)
    box((9, 1, 7.9), (2, 0.4, 0.4), mat((40, 40, 40), rough=0.6), bevel=0.1)
    box((-4, 0, 10.5), (6, 3.6, 2.5), olive, bevel=0.3)                                # another on top
    box((-4, 3.65, 10.8), (2, 0.05, 0.8), mat((220, 200, 60), rough=0.7), bevel=0)


def hospital_bed():
    frame = steel((180, 184, 180))
    box((0, 0, 9), (21, 8, 2), cloth((196, 200, 196)), bevel=1.2, seg=3)              # mattress
    box((3, 0, 11.2), (17, 8.2, 0.6), cloth((150, 176, 186)), bevel=0.4)               # blanket
    sphere((-16, 0, 11.6), 3.6, cloth((226, 226, 220)), scale=(1.0, 1.7, 0.5))         # pillow
    box((0, 0, 6.6), (21.5, 8.2, 0.5), frame, bevel=0.1)
    for x in (-21, 21):
        for y in (-7.5, 7.5):
            cyl((x, y, 0), 0.55, 6.6, frame, bevel=0, verts=10)
            sphere((x, y, 0.8), 0.9, mat((40, 40, 40), rough=0.8))
    for z in (12, 15, 18):                                                              # head rails
        box((-21.5, 0, z), (0.4, 8, 0.4), frame, bevel=0)
    for y in (-7.5, 7.5):
        cyl((-21.5, y, 6), 0.5, 13, frame, bevel=0, verts=10)
        cyl((21.5, y, 6), 0.5, 7, frame, bevel=0, verts=10)
    box((21.5, 0, 12), (0.3, 8, 1.4), frame, bevel=0)
    box((10, 8.3, 9.5), (6, 0.2, 1.4), frame, bevel=0)                                 # side rail


def broken_trolley():
    st = steel((176, 180, 176))
    box((0, 0, 10), (14, 6, 0.4), st, bevel=0.1, rot=(0, 0.25, 0))                    # top tray, tipped
    box((2, 0, 4), (13, 5.5, 0.4), st, bevel=0.1)
    for x in (-12, 12):
        for y in (-5, 5):
            cyl((x, y, 0), 0.5, 10 if x > 0 else 8, st, bevel=0, verts=10)
    for (x, y, c) in ((-4, 1, (200, 196, 186)), (2, -2, (150, 60, 50)), (6, 2, (220, 220, 214))):
        box((x, y, 4.8), (1.6, 1.2, 0.6), mat(c, rough=0.8), bevel=0.2)
    box((-17, 6, 0.4), (2.4, 1.6, 0.4), st, bevel=0.1, rot=(0, 0, 0.4))                 # a fallen tray
    sphere((-12, 8, 0.4), 0.9, mat((40, 40, 40), rough=0.8))


def wheelchair():
    fr = steel((150, 154, 150))
    seat = cloth((44, 46, 50))
    box((0, 0, 9), (6.5, 6, 0.6), seat, bevel=0.3)
    box((0, -6, 15), (6.5, 0.5, 5.5), seat, bevel=0.3)
    for x in (-7.5, 7.5):
        cyl((x, -1, 8.5), 8.5, 0.6, mat((30, 30, 30), rough=0.8), axis='x', bevel=0.2, verts=28)
        cyl((x, -1, 8.5), 7.0, 0.7, fr, axis='x', bevel=0.1, verts=24)
        cyl((x, -1, 8.5), 6.4, 0.9, mat((60, 62, 60), rough=0.8), axis='x', bevel=0, verts=24)
        box((x - (0.8 if x < 0 else -0.8), -6.4, 20.5), (0.4, 0.4, 1.2), fr, bevel=0)
        tube([(x * 0.8, 6, 9), (x * 0.8, 8, 3), (x * 0.8, 8.5, 1.5)], 0.35, fr)
        cyl((x * 0.8, 8.5, 0), 1.3, 0.5, mat((30, 30, 30), rough=0.8), axis='x', bevel=0.1)
        box((x * 0.95, 0, 12.4), (0.4, 5, 0.4), fr, bevel=0)


def retail_shelf():
    frame = paint((180, 184, 176))
    box((0, -4, 13), (15, 0.5, 13), frame, bevel=0.2)
    for x in (-15, 15):
        box((x, 0, 13), (0.5, 4, 13), frame, bevel=0.1)
    k = 0
    for z in (1.0, 8.5, 16.0):
        box((0, 0, z), (15, 4, 0.4), frame, bevel=0.1)
        x = -13.5
        while x < 13:
            k += 1
            if k % 5 == 2:
                x += 4
                continue
            c = COLOURS[(k * 3) % len(COLOURS)]
            if k % 2:
                cyl((x + 1, 1, z + 0.4), 1.1, 3.0, paint(c), bevel=0.2, verts=12)
                x += 2.6
            else:
                box((x + 1.4, 0.8, z + 2.6), (1.3, 2.4, 2.2), mat(c, rough=0.8), bevel=0.1)
                x += 3.2
    box((5, 3, 0.3), (2, 1.6, 0.3), mat(COLOURS[2], rough=0.8), bevel=0.1, rot=(0, 0, 0.5))   # dropped on the floor
    box((0, 4.1, 26), (14.5, 0.3, 1.4), mat((190, 60, 50), rough=0.7), bevel=0)               # shop strip


def iv_stand():
    st = steel((180, 184, 180))
    cyl((0, 0, 0), 0.4, 30, st, bevel=0, verts=10)
    for a in range(5):
        t = a * math.tau / 5
        tube([(0, 0, 1.2), (math.cos(t) * 5, math.sin(t) * 4, 0.4)], 0.35, st)
        sphere((math.cos(t) * 5, math.sin(t) * 4, 0.5), 0.6, mat((40, 40, 40), rough=0.8))
    tube([(-4, 0, 30), (4, 0, 30)], 0.3, st)
    box((-3, 0.5, 26.5), (1.6, 0.6, 2.6), mat((200, 220, 226), rough=0.2), bevel=0.6)        # the bag
    tube([(-3, 0.5, 23.8), (-2, 1.5, 18), (-1, 2.5, 10)], 0.15, mat((220, 230, 230), rough=0.3))


def oxygen_cylinder():
    blue = mat((52, 92, 150), rough=0.45, metal=0.3, grime=0.4, dust=0.3)
    cyl((0, 0, 0), 3.6, 22, blue, bevel=1.2, verts=22)
    cyl((0, 0, 22), 1.4, 2.0, steel((170, 160, 120)), bevel=0.2)
    box((0, 0, 24.6), (1.8, 0.7, 0.7), steel((150, 140, 100)), bevel=0.2)
    box((0, 3.6, 14), (2.0, 0.1, 1.0), mat((236, 236, 230), rough=0.8), bevel=0)    # "КИСЛОРОД"


def reception_desk():
    # a tall front with a raised ledge: from the camera it is mostly front
    front = wood((124, 92, 60))
    trim = wood((92, 66, 42))
    box((0, 0, 11), (23, 3, 11), front, bevel=0.5)
    for x in range(-18, 19, 9):                                    # panels
        box((x, 3.05, 10), (3.8, 0.1, 8), wood((136, 102, 68)), bevel=0.2)
        box((x, 3.12, 10), (3.2, 0.05, 7.2), front, bevel=0)
    box((0, 3.1, 1.0), (23, 0.2, 1.0), trim, bevel=0)              # kick plate
    box((0, 0.5, 22.4), (24, 4.0, 0.6), wood((158, 122, 84)), bevel=0.3)   # the ledge
    box((0, 3.3, 22.4), (24, 0.3, 0.7), trim, bevel=0)
    box((12, -2, 25), (3.6, 2.4, 2.6), paint((180, 176, 160)), bevel=0.6)  # a monitor behind
    box((-10, 1, 23.2), (3.0, 2.0, 0.2), mat(PAPER, rough=0.9), bevel=0, rot=(0, 0, 0.25))
    box((-4, 1.5, 23.4), (1.6, 1.0, 0.5), mat((30, 30, 30), rough=0.6), bevel=0.2)   # a phone
    box((4, 3.25, 15), (3.0, 0.05, 1.4), mat((40, 80, 130), rough=0.8), bevel=0)     # a sign
    box((4, 3.3, 15), (2.0, 0.05, 0.3), mat((220, 220, 210), rough=0.8), bevel=0)


def stretcher():
    st = steel((170, 174, 170))
    box((0, 0, 8.5), (21, 6, 0.9), cloth((80, 110, 100)), bevel=0.5)
    box((-17, 0, 9.8), (3.5, 5, 0.8), cloth((210, 210, 204)), bevel=0.5)
    for x in (-22, 22):
        box((x, 0, 8.0), (1.5, 6.2, 0.3), st, bevel=0)
    for y in (-6, 6):
        box((0, y, 8.0), (23.5, 0.4, 0.4), st, bevel=0)
    for x in (-16, 16):
        tube([(x, -5, 7.8), (x - 3, -5, 1.2)], 0.35, st)
        tube([(x, 5, 7.8), (x - 3, 5, 1.2)], 0.35, st)
        sphere((x - 3, 5, 0.9), 0.9, mat((40, 40, 40), rough=0.8))
    box((6, 4, 9.6), (5, 2.5, 0.4), mat((120, 34, 30), rough=0.9), bevel=0.2, rot=(0, 0, 0.3))   # a stain


def shopping_cart():
    st = steel((160, 166, 166))
    for z in (6, 10):
        box((0, 0, z), (8, 5, 0.25), st, bevel=0)
    for x in range(-7, 8, 2):
        box((x, 5, 8), (0.15, 0.15, 3), st, bevel=0)
        box((x, -5, 8), (0.15, 0.15, 3), st, bevel=0)
    for y in range(-4, 5, 2):
        box((8, y, 8), (0.15, 0.15, 3), st, bevel=0)
        box((-8, y, 8), (0.15, 0.15, 3), st, bevel=0)
    box((0, 0, 4), (7, 4, 0.2), st, bevel=0)
    tube([(-8, -5, 11), (-10, -5, 13), (-10, 5, 13), (-8, 5, 11)], 0.35, mat((40, 80, 150), rough=0.6))
    for x in (-6, 6):
        for y in (-4, 4):
            tube([(x, y, 4), (x, y, 1.2)], 0.3, st)
            sphere((x, y, 0.8), 0.8, mat((30, 30, 30), rough=0.8))
    box((2, 0, 7), (3, 2, 1), mat((168, 132, 88), rough=0.95), bevel=0.2)            # a box left in it


def counter():
    box((0, 0, 9), (19, 5, 9), paint((150, 140, 120)), bevel=0.5)
    box((0, 0, 18.4), (19.6, 5.6, 0.5), mat((90, 92, 88), rough=0.4, metal=0.3, grime=0.3), bevel=0.2)
    box((0, 5.05, 9), (18, 0.1, 0.3), mat((110, 100, 84), rough=0.8), bevel=0)
    for x in (-12, 0, 12):
        box((x, 5.1, 5), (5, 0.1, 3.4), paint((140, 130, 112)), bevel=0)
    box((-10, 0, 20.6), (4, 3, 1.8), paint((60, 64, 60)), bevel=0.4)                  # a cash register
    box((-10, 2.8, 22.2), (2.6, 0.2, 0.8), mat((60, 100, 60), rough=0.3), bevel=0)
    box((8, 1, 19.1), (2.4, 1.8, 0.2), mat(PAPER, rough=0.9), bevel=0)


def medical_shelf():
    white = mat((214, 216, 210), rough=0.5, metal=0.1, grime=0.45, dust=0.3)
    box((0, 0, 14), (15, 5, 14), white, bevel=0.5)
    box((0, 5.05, 14), (14, 0.1, 13), mat((60, 76, 82), rough=0.2), bevel=0)        # glass doors (dark inside)
    box((0, 5.15, 14), (0.2, 0.1, 13), white, bevel=0)
    for z in (6, 13, 20):
        box((0, 4.9, z), (14, 0.2, 0.25), white, bevel=0)
        for i in range(8):
            x = -12 + i * 3.3
            if (i + int(z)) % 4 == 1:
                continue
            c = [(220, 220, 214), (150, 90, 40), (60, 120, 150), (200, 80, 60)][(i + int(z)) % 4]
            cyl((x, 4.4, z + 0.25), 0.9, 2.2 + (i % 3) * 0.7, mat(c, rough=0.3), bevel=0.2, verts=10)
    box((9, 5.2, 24), (2.2, 0.05, 2.2), mat((190, 40, 40), rough=0.7), bevel=0)      # red cross plate
    box((9, 5.25, 24), (0.5, 0.05, 1.6), mat((240, 240, 236), rough=0.7), bevel=0)
    box((9, 5.25, 24), (1.6, 0.05, 0.5), mat((240, 240, 236), rough=0.7), bevel=0)


def large_med_cabinet():
    medical_shelf()


def pharmacy_cabinet():
    medical_shelf()


def drawer_cabinet():
    body = wood((120, 86, 56))
    box((0, 0, 13), (10, 6, 13), body, bevel=0.5)
    for i, z in enumerate((3.5, 10, 16.5, 23)):
        out = 2.5 if i == 1 else 0
        box((0, 6 + out, z), (9.4, 0.3 + out, 2.8), wood((132, 96, 62)), bevel=0.3)
        for x in (-4, 4):
            sphere((x, 6.6 + out * 2, z), 0.6, steel((170, 160, 120)))
    box((0, 7.5, 10.8), (6, 2, 1.2), cloth((180, 170, 150)), bevel=0.4)              # clothes in it
    cyl((-5, 0, 26), 2.0, 0.3, mat((200, 196, 180), rough=0.4), bevel=0.1)           # a plate on top


def generator_prop():
    red = mat((150, 60, 36), rough=0.5, metal=0.3, grime=0.5, dust=0.4)
    frame = steel((40, 40, 40))
    box((0, 0, 7), (12, 7, 6), red, bevel=0.8)
    box((-4, 0, 14.5), (7, 5.5, 1.6), mat((190, 160, 40), rough=0.5, metal=0.2, grime=0.4), bevel=0.8)   # tank
    cyl((-4, 0, 16), 1.2, 1.0, frame, bevel=0.2)
    box((7, 7.1, 8), (3.4, 0.2, 3.4), mat((60, 60, 60), rough=0.6), bevel=0.2)        # panel
    for x in (-12.5, 12.5):
        tube([(x, -7, 0.5), (x, -7, 14), (x, 7, 14), (x, 7, 0.5)], 0.6, frame)
    cyl((9, -4, 13), 1.4, 3.0, frame, bevel=0.2)                                      # exhaust
    tube([(12, 0, 4), (16, 3, 0.5), (20, 6, 0.4)], 0.4, mat((30, 30, 30), rough=0.8))


# ------------------------------------------------------------- floor litter
def street_debris():
    pl = wood((128, 96, 64))
    box((-6, 0, 0.6), (9, 1.4, 0.6), pl, bevel=0.2, rot=(0, 0, 0.25))
    box((5, 3, 0.9), (6, 1.2, 0.5), wood((110, 84, 56)), bevel=0.2, rot=(0, 0.2, -0.5))
    for (x, y, c) in ((10, -2, (150, 70, 52)), (12, 1, (140, 64, 48)), (-12, 4, (160, 156, 146))):
        box((x, y, 1.0), (2.0, 1.0, 1.0), mat(c, rough=0.95, grime=0.3), bevel=0.2, rot=(0, 0, x * 0.1))
    tube([(-14, -3, 0.6), (-2, -5, 0.6)], 0.7, steel((100, 90, 80)))
    box((2, -3, 0.2), (3, 2, 0.15), mat(PAPER, rough=0.9), bevel=0, rot=(0, 0, 0.4))
    for (x, y) in ((0, 5), (-9, 6), (14, 5)):
        sphere((x, y, 0.6), 1.0, mat((150, 146, 138), rough=1.0), scale=(1.3, 1, 0.7))


def scattered_bottles():
    for i, (x, y, rot, c) in enumerate(((-12, 2, 0.3, (60, 100, 50)), (-3, -2, -0.8, (110, 70, 30)),
                                        (7, 3, 1.2, (60, 100, 50)), (13, -2, 0.0, (180, 196, 190)))):
        g = mat(c, rough=0.15, grime=0.2)
        cyl((x, y, 1.6), 1.5, 7, g, axis='x', bevel=0.5, verts=14, rot=(0, math.pi / 2, rot))
    cyl((0, 5, 0), 1.6, 6.5, mat((60, 100, 50), rough=0.15), bevel=0.4, verts=14)     # one still standing
    cyl((0, 5, 6.5), 0.6, 2.2, mat((60, 100, 50), rough=0.15), bevel=0.1, verts=10)
    cyl((-7, 6, 0), 1.4, 3.2, steel((170, 160, 150)), bevel=0.2, verts=14)            # a tin
    for (x, y) in ((3, 0), (5, -4), (-1, 3)):
        box((x, y, 0.15), (0.8, 0.5, 0.15), mat((90, 140, 90), rough=0.1), bevel=0, rot=(0, 0, x))   # shards


def rubble():
    con = [(150, 146, 136), (128, 124, 116), (166, 160, 150)]
    import random
    rnd = random.Random(7)
    for i in range(14):
        x = rnd.uniform(-12, 12)
        y = rnd.uniform(-3, 4)
        s = rnd.uniform(1.2, 3.2) * (1.0 - abs(x) / 20)
        box((x, y, s * 0.6), (s, s * 0.8, s * 0.6), mat(con[i % 3], rough=1.0, grime=0.4, dust=0.4), bevel=0.3, rot=(rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), rnd.uniform(0, 3)))
    for (x, y) in ((-6, 3), (7, -1)):
        box((x, y, 1.0), (2.2, 1.1, 1.0), mat((150, 70, 52), rough=0.95), bevel=0.2, rot=(0, 0, x * 0.2))
    tube([(-4, -2, 2.4), (2, 0, 4.5), (6, 2, 6)], 0.25, steel((110, 70, 40)))          # rebar


def medicine_boxes():
    for i, (x, y, z, s) in enumerate(((-9, 0, 0, (4, 3, 2.2)), (-1, 1, 0, (4, 3, 2.6)), (8, 0, 0, (5, 3.5, 2.4)),
                                      (-5, 0.5, 4.6, (3.6, 2.8, 2)), (4, 1, 5.0, (3.4, 2.6, 1.8)))):
        c = [(226, 226, 220), (210, 216, 222), (230, 226, 210)][i % 3]
        box((x, y, z + s[2]), s, mat(c, rough=0.8, grime=0.3), bevel=0.2)
        box((x, y + s[1] + 0.02, z + s[2]), (1.0, 0.02, 0.35), mat((190, 40, 40), rough=0.7), bevel=0)
        box((x, y + s[1] + 0.02, z + s[2]), (0.35, 0.02, 1.0), mat((190, 40, 40), rough=0.7), bevel=0)


def med_supply_stack():
    medicine_boxes()
    box((13, 2, 0.6), (2, 1.4, 0.6), mat((200, 220, 226), rough=0.2), bevel=0.4)


KINDS = {
    'metal_shelving': metal_shelving, 'tool_case': tool_case, 'extinguisher': extinguisher,
    'cabinet': cabinet, 'filing_cabinet': filing_cabinet, 'desk': desk, 'tipped_chair': tipped_chair,
    'old_mattress': old_mattress, 'old_fridge': old_fridge, 'cot': cot, 'chair': chair,
    'electrical_box': electrical_box, 'radiator': radiator, 'locker': locker, 'ammo_crate': ammo_crate,
    'hospital_bed': hospital_bed, 'broken_trolley': broken_trolley, 'wheelchair': wheelchair,
    'retail_shelf': retail_shelf, 'iv_stand': iv_stand, 'oxygen_cylinder': oxygen_cylinder,
    'reception_desk': reception_desk, 'stretcher': stretcher, 'shopping_cart': shopping_cart,
    'counter': counter, 'medical_shelf': medical_shelf, 'large_med_cabinet': large_med_cabinet,
    'pharmacy_cabinet': pharmacy_cabinet, 'drawer_cabinet': drawer_cabinet, 'generator_prop': generator_prop,
    'street_debris': street_debris, 'scattered_bottles': scattered_bottles, 'rubble': rubble,
    'medicine_boxes': medicine_boxes, 'med_supply_stack': med_supply_stack,
}


def regions(P):
    s = open(os.path.join(P, 'main_script_mod.gd'), encoding='utf-8').read()
    out = {}
    for k in KINDS:
        m = re.search(r'"%s":Rect2\((\d+),(\d+),(\d+),(\d+)\)' % k, s)
        if m:
            out[k] = tuple(int(v) for v in m.groups())
    return out


def harden(im, colours=24):
    a = np.array(im).astype(np.uint8)
    al = a[..., 3]
    solid = al >= 120
    res = np.zeros_like(a)
    res[solid, :3] = a[solid, :3]
    res[solid, 3] = 255
    pim = Image.fromarray(res, 'RGBA')
    q = Image.fromarray(res[..., :3], 'RGB').quantize(colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    r2 = np.array(pim)
    r2[solid, :3] = np.array(q)[solid]
    A = r2[..., 3] == 255
    g = np.zeros_like(A)
    g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
    e = g & ~A
    r2[e] = bk.OUTLINE + (255,)
    return Image.fromarray(r2, 'RGBA')


def build(P, only=None):
    src = Image.open(os.path.join(P, 'world_props_v19.png')).convert('RGBA')
    dst_path = os.path.join(P, 'art', 'world_hd', 'world_props_v20.png')
    sheet = Image.open(dst_path).convert('RGBA') if (only and os.path.exists(dst_path)) else src.copy()
    tmp = tempfile.mkdtemp(prefix='ostatok_v20_')
    for kind, (x, y, w, h) in regions(P).items():
        if only and kind not in only:
            continue
        old = np.array(src.crop((x, y, x + w, y + h)))
        ys, xs = np.nonzero(old[..., 3] > 0)
        if len(xs) == 0:
            continue
        bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        bk.reset()
        bk.camera(RENDER, 64, 40)
        KINDS[kind]()
        raw = bk.render(os.path.join(tmp, kind + '.png'))
        spr = bk.to_sprite(raw, RENDER, colours=0, outline=False, shadow=False)
        a = np.array(spr)
        sy, sx = np.nonzero(a[..., 3] > 0)
        spr = spr.crop((sx.min(), sy.min(), sx.max() + 1, sy.max() + 1))
        # fit inside the old drawing's box (1 px kept for the outline)
        # the width of the old drawing; the height may use the cell up to its
        # top (the old pieces were drawn flat, the models show their top too)
        tw, th = bx1 - bx0 - 2, by1 - 3
        k = min(tw / spr.width, th / spr.height)
        nw, nh = max(1, int(round(spr.width * k))), max(1, int(round(spr.height * k)))
        # premultiplied resize keeps edge colours clean
        arr = np.array(spr).astype(float)
        arr[..., :3] *= arr[..., 3:4] / 255.0
        pm = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA').resize((nw, nh), Image.LANCZOS)
        arr = np.array(pm).astype(float)
        al = np.maximum(arr[..., 3:4], 1)
        arr[..., :3] = np.clip(arr[..., :3] * 255.0 / al, 0, 255)
        fitted = Image.new('RGBA', (nw + 2, nh + 2))
        fitted.paste(Image.fromarray(arr.astype(np.uint8), 'RGBA'), (1, 1))
        fitted = harden(fitted)
        cell = Image.new('RGBA', (w, h))
        cx = (bx0 + bx1) // 2
        cell.alpha_composite(fitted, (max(0, int(cx - fitted.width // 2)), max(0, int(by1 - fitted.height))))
        sheet.paste(cell, (x, y))
        print('v20', kind, (w, h), '->', fitted.size, flush=True)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    sheet.save(dst_path)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.', set(sys.argv[2:]) or None)
