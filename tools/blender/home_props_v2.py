"""OSTATOK 1.50: the home furniture remodelled in Blender.

props_home_v1.png (tools/home_props_v1.py) was drawn flat, straight from the
front - next to the Blender props it read as cut-out cardboard. Each piece is
modelled at real size, rendered with the HD pipeline (the game's 3/4 camera and
light: the top of a sofa, a bed, a table is seen) and fitted into the same
atlas cell, on the old ground line and within the old width - so placement,
footprints and collision stay as they were.

    python3.13 tools/blender/home_props_v2.py <project_dir> [kind ...]

Reads art/world_hd/props_home_v1.png, writes art/world_hd/props_home_v2.png.
"""
import math
import os
import random
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import numpy as np
from PIL import Image

import bk
from bk import box, cyl, mat, tube, sphere
from props_v20 import harden, wood, steel, paint, cloth, PAPER

RENDER = 80
CW, CH = 72, 56
ORDER = ["sofa", "armchair", "wardrobe", "bookshelf", "kitchen_stove", "kitchen_counter", "dining_table", "bed",
         "tv_stand", "dresser", "rug", "bathtub", "washing_machine", "computer_desk", "water_cooler", "freezer_chest"]


def sofa():
    fab = cloth((86, 104, 70))
    dark = cloth((66, 82, 54))
    box((0, 0, 4.5), (20, 7, 3.0), dark, bevel=1.0, seg=3)                 # base
    for x in (-10, 0, 10):                                               # seat cushions
        box((x, 1, 8.6), (4.7, 5.4, 1.4), fab, bevel=1.0, seg=3)
    box((0, -6, 12.5), (17.5, 2.2, 6.0), fab, bevel=1.4, seg=3)           # back
    for x in (-19, 19):                                                  # arms
        box((x, 0, 9.5), (2.4, 7.2, 3.6), dark, bevel=1.2, seg=3)
    box((7, 2, 10.6), (3.2, 2.4, 0.9), cloth((150, 60, 50)), bevel=0.6, rot=(0, 0, 0.3))   # a cushion thrown on it
    for x in (-17, 17):
        cyl((x, 5, 0), 0.6, 1.6, wood((60, 40, 26)), bevel=0)
    sphere((-6, 3, 9.9), 2.0, cloth((70, 84, 58)), scale=(1.3, 1, 0.25))   # a worn patch


def armchair():
    fab = cloth((128, 84, 60))
    dark = cloth((100, 64, 46))
    box((0, 0, 4.5), (8, 7, 3.0), dark, bevel=1.0, seg=3)
    box((0, 1, 8.6), (5.6, 5.4, 1.4), fab, bevel=1.0, seg=3)
    box((0, -6, 13), (6.5, 2.2, 6.5), fab, bevel=1.4, seg=3)
    for x in (-7.5, 7.5):
        box((x, 0, 9.5), (2.0, 7.2, 3.8), dark, bevel=1.0, seg=3)
    for x in (-6, 6):
        cyl((x, 5, 0), 0.6, 1.6, wood((60, 40, 26)), bevel=0)


def wardrobe():
    w = wood((122, 82, 50))
    box((0, 0, 21), (11, 5.5, 21), w, bevel=0.5)
    box((0, 0, 42.4), (11.6, 6, 0.6), wood((100, 66, 40)), bevel=0.2)       # cornice
    box((-5.4, 5.6, 21), (5.2, 0.2, 19.5), wood((134, 92, 58)), bevel=0.2)   # left door
    box((7.0, 7.5, 21), (0.2, 3.6, 19.5), wood((134, 92, 58)), bevel=0.1, rot=(0, 0, 0.9))   # right door ajar
    box((5.4, 5.0, 21), (5.0, 0.4, 19.0), mat((40, 30, 24), rough=0.9), bevel=0)   # the dark inside
    for z in (24, 30):
        box((5.4, 3.5, z), (3.5, 1.6, 2.5), cloth([(90, 100, 130), (130, 70, 60)][int(z) % 2]), bevel=0.5)   # clothes
    box((-1.2, 6.0, 22), (0.3, 0.4, 2.0), steel((180, 170, 130)), bevel=0.1)   # handle
    for x in (-9, 9):
        box((x, 4, 0.6), (1, 1, 0.6), wood((80, 54, 34)), bevel=0)
    box((-4, 0, 43.8), (4, 3.5, 1.4), mat((168, 132, 88), rough=0.95), bevel=0.3)   # a box on top


def bookshelf():
    w = wood((112, 76, 46))
    box((0, 0, 19), (12, 4, 19), w, bevel=0.4)
    box((0, 3.2, 19), (11, 1.0, 18), mat((40, 30, 22), rough=0.9), bevel=0)   # the back (dark)
    rnd = random.Random(5)
    cols = [(150, 50, 40), (60, 90, 130), (170, 140, 60), (70, 100, 70), (200, 196, 180), (120, 80, 50), (110, 60, 90)]
    for z in (1.5, 10.5, 19.5, 28.5):
        box((0, 4.1, z), (11, 0.25, 0.35), w, bevel=0)
        x = -10.4
        while x < 10:
            bw = rnd.uniform(0.7, 1.6)
            if rnd.random() < 0.15:
                x += 2.5
                continue
            h = rnd.uniform(4.5, 7.2)
            lean = rnd.uniform(-0.2, 0.2) if rnd.random() < 0.2 else 0
            box((x + bw * 0.5, 3.6, z + 0.4 + h * 0.5), (bw * 0.5, 2.6, h * 0.5), mat(cols[rnd.randrange(len(cols))], rough=0.8), bevel=0.05, rot=(0, lean, 0))
            x += bw + 0.15
    box((3, 4.6, 38.6), (3, 2, 0.6), mat(PAPER, rough=0.9), bevel=0.1)


def kitchen_stove():
    white = mat((214, 210, 196), rough=0.45, metal=0.1, grime=0.22, dust=0.12, scale=0.1)
    box((0, 0, 12), (9, 7, 12), white, bevel=0.8)
    box((0, 0, 24.2), (9.2, 7.2, 0.3), mat((40, 40, 40), rough=0.6, metal=0.4), bevel=0.1)   # hob
    for x, y in ((-4, -3), (4, -3), (-4, 3), (4, 3)):
        cyl((x, y, 24.3), 2.0, 0.4, mat((30, 30, 30), rough=0.5, metal=0.5), bevel=0.1, verts=16)
    box((0, 7.1, 9), (7.4, 0.2, 6.0), mat((40, 46, 48), rough=0.2), bevel=0.3)     # oven door glass
    box((0, 7.5, 16.4), (6, 0.4, 0.4), steel((180, 180, 170)), bevel=0.1)          # handle
    for x in range(-6, 8, 3):
        cyl((x, 7.3, 21), 0.7, 0.6, mat((30, 30, 30), rough=0.6), axis='y', bevel=0.1, verts=10)   # knobs
    cyl((-4, -3, 24.6), 2.6, 2.4, steel((150, 150, 146)), bevel=0.3, verts=18)      # a pot
    box((0, -7, 27), (9, 0.6, 3), white, bevel=0.3)                                # splashback


def kitchen_counter():
    base = mat((196, 184, 156), rough=0.6, grime=0.25, dust=0.12, scale=0.1)
    top = mat((150, 140, 120), rough=0.4, grime=0.4)
    box((0, 0, 11), (20, 6.5, 11), base, bevel=0.5)
    box((0, 0.4, 22.4), (20.6, 7.2, 0.6), top, bevel=0.2)
    for x in (-13, 0, 13):
        box((x, 6.55, 9), (6, 0.15, 7.5), mat((206, 196, 168), rough=0.6), bevel=0.1)
        box((x + 4, 6.8, 13), (0.3, 0.3, 1.4), steel((170, 170, 160)), bevel=0)
    box((8, 0, 22.6), (5, 4, 0.5), steel((170, 174, 172)), bevel=0.2)              # sink
    box((8, 0, 22.7), (4.2, 3.2, 0.5), mat((60, 64, 66), rough=0.3), bevel=0)
    tube([(8, -5, 23), (8, -5, 27), (8, -2.5, 27)], 0.35, steel((190, 190, 186)))   # tap
    box((-12, 1, 24.4), (3, 2.4, 1.4), mat((180, 70, 50), rough=0.5), bevel=0.4)   # a breadbin
    cyl((-4, 2, 22.9), 1.4, 2.4, mat((220, 220, 214), rough=0.4), bevel=0.2, verts=14)   # a jar


def dining_table():
    w = wood((130, 88, 54))
    box((-2, 0, 13), (13, 7.5, 0.7), w, bevel=0.3)
    for x in (-13, 9):
        for y in (-6, 6):
            box((x, y, 6.2), (0.7, 0.7, 6.2), wood((104, 70, 42)), bevel=0)
    box((-6, 0, 13.8), (4.5, 3.5, 0.12), mat((220, 214, 196), rough=0.9), bevel=0)   # a cloth
    cyl((2, 2, 13.8), 1.6, 0.4, mat((210, 206, 196), rough=0.4), bevel=0.1, verts=14)   # a plate
    cyl((-9, -3, 13.8), 0.8, 2.2, mat((60, 100, 70), rough=0.2), bevel=0.1, verts=10)   # a bottle
    # a chair pushed out, at the end
    c = wood((116, 78, 46))
    box((15, 2, 7.5), (3.4, 3.4, 0.5), c, bevel=0.2)
    for x in (12.2, 17.8):
        for y in (-0.8, 4.8):
            box((x, y, 3.7), (0.35, 0.35, 3.7), c, bevel=0)
    box((17.8, 2, 12), (0.4, 3.4, 4), c, bevel=0.2)


def bed():
    frame = wood((112, 76, 46))
    box((0, 0, 4), (11, 21, 4), frame, bevel=0.5)
    box((0, 0, 9.0), (10, 20, 1.6), cloth((214, 210, 196)), bevel=1.0, seg=3)     # mattress
    box((0, 4, 11.2), (10.4, 15, 0.9), cloth((80, 100, 140)), bevel=0.8, seg=3)    # blanket
    box((-3, -6, 11.6), (8, 5, 0.8), cloth((70, 90, 128)), bevel=0.8, rot=(0.4, 0, 0.2))   # turned back
    sphere((0, -16, 11.5), 4.2, cloth((226, 224, 214)), scale=(1.6, 0.8, 0.45))    # pillow
    box((0, -21.5, 10), (11.2, 0.8, 10), frame, bevel=0.4)                        # headboard
    box((0, 21.2, 6.5), (11.2, 0.7, 6.5), frame, bevel=0.4)


def tv_stand():
    w = wood((104, 70, 42))
    box((0, 0, 6), (12, 6, 6), w, bevel=0.4)
    for x in (-6, 6):
        box((x, 6.05, 6), (5.4, 0.15, 5.0), wood((120, 82, 50)), bevel=0.1)
        cyl((x + (3 if x < 0 else -3), 6.4, 6), 0.5, 0.4, steel((170, 160, 120)), axis='y', bevel=0)
    box((0, -1, 17.5), (8.5, 6, 5.5), paint((60, 58, 54)), bevel=1.2)            # the CRT
    box((-1.5, 5.05, 17.8), (6.2, 0.2, 4.3), mat((32, 42, 46), rough=0.15), bevel=0.6)   # screen
    for z in (14.5, 16.5):
        cyl((6.4, 5.2, z), 0.6, 0.4, mat((180, 176, 160), rough=0.5), axis='y', bevel=0)
    tube([(0, -4, 23), (-3, -4, 28)], 0.15, steel((180, 180, 180)))               # antenna
    tube([(0, -4, 23), (3, -4, 28.5)], 0.15, steel((180, 180, 180)))


def dresser():
    w = wood((126, 86, 52))
    box((0, 0, 10), (11, 6, 10), w, bevel=0.5)
    box((0, 0, 20.3), (11.5, 6.4, 0.4), wood((104, 70, 42)), bevel=0.2)
    for i, z in enumerate((3.5, 9.5, 15.5)):
        out = 2.0 if i == 1 else 0
        box((0, 6.0 + out, z), (10.3, 0.3 + out, 2.6), wood((138, 96, 60)), bevel=0.3)
        for x in (-5, 5):
            sphere((x, 6.6 + out * 2, z), 0.6, steel((170, 160, 120)))
    box((0, 7.2, 10), (6, 1.6, 0.9), cloth((150, 140, 120)), bevel=0.4)           # something hanging out
    cyl((-6, 0, 20.6), 1.4, 3.6, mat((170, 190, 200), rough=0.2), bevel=0.3, verts=14)   # a vase
    box((5, -2, 21.2), (2.4, 1.6, 0.6), mat(PAPER, rough=0.9), bevel=0.1)


def bathtub():
    enamel = mat((226, 224, 214), rough=0.3, grime=0.2, dust=0.1, scale=0.1)
    box((0, 0, 6.5), (21, 9, 6.5), enamel, bevel=2.0, seg=4)
    box((0, 0, 12.6), (19, 7, 0.8), mat((150, 150, 140), rough=0.3), bevel=1.6, seg=3)   # the hollow
    box((0, 0, 12.0), (18, 6.4, 0.3), mat((110, 120, 116), rough=0.2), bevel=1.0)        # grey water
    tube([(-21, -5, 13), (-21, -5, 18), (-18, -5, 18)], 0.5, steel((190, 190, 186)))
    for (x, z, r) in ((-12, 3, 1.2), (14, 4, 1.0), (8, 9.5, 0.7)):
        sphere((x, 9.0, z), r, mat((150, 110, 70), rough=1.0), scale=(1.2, 0.2, 1))   # rust stains
    for x in (-17, 17):
        sphere((x, 6, 0.8), 1.0, steel((150, 150, 146)))


def washing_machine():
    white = mat((222, 220, 210), rough=0.45, metal=0.1, grime=0.22, dust=0.12, scale=0.1)
    box((0, 0, 12), (8.5, 7.5, 12), white, bevel=1.0)
    cyl((0, 7.5, 11), 5.0, 0.6, mat((150, 150, 146), rough=0.4, metal=0.3), axis='y', bevel=0.3, verts=24)
    cyl((0, 7.9, 11), 3.8, 0.4, mat((50, 64, 70), rough=0.15), axis='y', bevel=0.2, verts=24)   # porthole
    box((0, 7.6, 21.5), (7.6, 0.2, 1.6), mat((190, 190, 184), rough=0.5), bevel=0.2)   # panel
    for x in (-4, 3, 5.5):
        cyl((x, 7.9, 21.5), 0.8, 0.5, mat((80, 80, 80), rough=0.5), axis='y', bevel=0.1, verts=10)
    box((-5.5, 7.7, 21.5), (1.8, 0.1, 0.9), mat((60, 60, 60), rough=0.4), bevel=0)


def computer_desk():
    top = wood((116, 84, 56))
    box((0, 0, 14), (17, 7, 0.7), top, bevel=0.3)
    box((11, 0, 7), (5.5, 6.5, 6.6), wood((100, 72, 46)), bevel=0.3)
    for z in (3.5, 9.5):
        box((11, 6.55, z), (4.8, 0.1, 2.4), wood((90, 64, 40)), bevel=0)
    for y in (-6, 6):
        box((-15.5, y, 7), (0.7, 0.7, 6.6), steel((60, 60, 58)), bevel=0)
    box((-4, -2, 18.5), (5.5, 4, 4.0), paint((190, 186, 170)), bevel=0.9)          # CRT monitor
    box((-4, 2.05, 18.7), (4.4, 0.1, 3.0), mat((30, 46, 50), rough=0.15), bevel=0.4)
    box((-4, -2, 15), (2.2, 2.0, 0.4), paint((180, 176, 160)), bevel=0.2)
    box((-4, 4.5, 14.9), (5, 1.6, 0.3), paint((200, 196, 184)), bevel=0.2)          # keyboard
    box((12, -2, 18.8), (2.8, 5, 4.2), paint((186, 182, 168)), bevel=0.4)          # the tower
    box((-14, 3, 2.5), (3, 3, 2.5), mat((168, 132, 88), rough=0.95), bevel=0.3)    # a box under it


def water_cooler():
    body = mat((220, 220, 212), rough=0.4, grime=0.4, dust=0.2)
    box((0, 0, 11), (4.5, 4.5, 11), body, bevel=0.6)
    box((0, 4.6, 14), (2.8, 0.3, 2.4), mat((60, 60, 60), rough=0.5), bevel=0.2)
    box((-1.2, 5.0, 14.5), (0.5, 0.5, 0.6), mat((40, 80, 180), rough=0.4), bevel=0.1)
    box((1.2, 5.0, 14.5), (0.5, 0.5, 0.6), mat((200, 50, 40), rough=0.4), bevel=0.1)
    cyl((0, 0, 22), 3.8, 9.5, mat((120, 170, 210), rough=0.1, grime=0.1), bevel=1.4, verts=22)   # the bottle
    cyl((0, 0, 31.5), 1.6, 1.2, mat((60, 120, 190), rough=0.3), bevel=0.3)


def freezer_chest():
    white = mat((220, 218, 206), rough=0.45, metal=0.1, grime=0.22, dust=0.12, scale=0.1)
    box((0, 0, 8), (20, 8, 8), white, bevel=1.0)
    box((0, 0, 16.3), (19.6, 7.6, 0.5), mat((170, 190, 200), rough=0.15), bevel=0.4)   # glass lid
    box((0, 0, 15.6), (18.8, 6.8, 0.2), mat((60, 70, 76), rough=0.3), bevel=0)
    box((0, 8.05, 10), (19, 0.15, 1.2), mat((180, 50, 40), rough=0.6), bevel=0)        # red stripe
    for x in (-10, -4, 2, 8):
        box((x, 8.1, 5), (2, 0.1, 1.4), mat([(60, 100, 160), (220, 180, 60), (80, 140, 80), (200, 80, 60)][(x + 10) // 6], rough=0.6), bevel=0)
    box((15, 8.2, 13), (2.4, 0.1, 1.4), mat((40, 40, 40), rough=0.5), bevel=0)


MODELS = {k: globals()[k] for k in ORDER if k != "rug"}


def build(P, only=None):
    src = Image.open(os.path.join(P, 'art', 'world_hd', 'props_home_v1.png')).convert('RGBA')
    dst = os.path.join(P, 'art', 'world_hd', 'props_home_v2.png')
    sheet = Image.open(dst).convert('RGBA') if (only and os.path.exists(dst)) else src.copy()
    tmp = tempfile.mkdtemp(prefix='ostatok_home2_')
    for i, kind in enumerate(ORDER):
        if kind not in MODELS or (only and kind not in only):
            continue
        x0 = i * CW
        old = np.array(src.crop((x0, 0, x0 + CW, CH)))
        ys, xs = np.nonzero(old[..., 3] > 200)
        bx0, bx1, by1 = xs.min(), xs.max() + 1, ys.max() + 1
        bk.reset()
        bk.camera(RENDER, 64, 40)
        MODELS[kind]()
        raw = bk.render(os.path.join(tmp, kind + '.png'))
        spr = bk.to_sprite(raw, RENDER, colours=0, outline=False, shadow=False)
        a = np.array(spr)
        sy, sx = np.nonzero(a[..., 3] > 0)
        spr = spr.crop((sx.min(), sy.min(), sx.max() + 1, sy.max() + 1))
        tw, th = bx1 - bx0, by1 - 2
        k = min(tw / spr.width, th / spr.height)
        nw, nh = max(1, int(round(spr.width * k))), max(1, int(round(spr.height * k)))
        arr = np.array(spr).astype(float)
        arr[..., :3] *= arr[..., 3:4] / 255.0
        pm = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA').resize((nw, nh), Image.LANCZOS)
        arr = np.array(pm).astype(float)
        al = np.maximum(arr[..., 3:4], 1)
        arr[..., :3] = np.clip(arr[..., :3] * 255.0 / al, 0, 255)
        fitted = Image.new('RGBA', (nw + 2, nh + 2))
        fitted.paste(Image.fromarray(arr.astype(np.uint8), 'RGBA'), (1, 1))
        fitted = harden(fitted, 28)
        cell = Image.new('RGBA', (CW, CH))
        cx = (bx0 + bx1) // 2
        cell.alpha_composite(fitted, (max(0, int(cx - fitted.width // 2)), max(0, int(by1 + 1 - fitted.height))))
        sheet.paste(cell, (x0, 0))
        print('home', kind, (bx1 - bx0, by1), '->', fitted.size, flush=True)
    sheet.save(dst)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.', set(sys.argv[2:]) or None)
