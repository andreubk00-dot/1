"""OSTATOK HD vehicles & High Risk set pieces modelled in Blender (bpy).

    python3 tools/blender/vehicles_hd.py <project_dir> [only_kind ...]

writes art/vehicles/vehicles_hd_v1.png (6 x N cells of 384 px = 192 world
units at 2 texels per unit) and world/vehicle_hd_atlas.gd (kind -> cell index).
Every model is built in game units (X right, Y toward the camera, Z up) and the
origin is the ground contact point placed at sprite pixel (96,166)*2.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk
from bk import box, cyl, prism, mat, glass, wheel, tube, sphere, mesh, rotate
from PIL import Image

CELL = 192

# ------------------------------------------------------------- materials ---
TYRE = None


def dk(c, k=0.75):
    return tuple(int(v * k) for v in c)


def chrome():
    return mat((150, 152, 150), rough=0.3, metal=0.7, grime=0.05)


def blackplastic():
    return mat((36, 36, 34), rough=0.7, grime=0.05)


def burnt_paint():
    return mat((70, 56, 46), rough=0.95, grime=0.35, scale=0.2)


def lamp(on=False):
    return mat((210, 206, 180), rough=0.2, grime=0.02, emit=(255, 230, 170) if on else None)


# ------------------------------------------------------------------ cars ---
def lada(colour=(98, 116, 128), burnt=False, seed=1, on_blocks=False):
    """VAZ-2105/2107 sedan: three-box body, chrome bumpers, square lamps."""
    rng = random.Random(seed)
    paint = burnt_paint() if burnt else mat(colour, rough=0.48, grime=0.10, dust=0.5)
    under = mat((40, 40, 38), rough=0.9)
    lift = 7.0 if on_blocks else 0.0
    # wheels (track 30, wheelbase 50)
    if not on_blocks:
        for x in (-25, 25):
            for y in (-14, 14):
                wheel(x, y, 0, 7.2, 4.4, side=1 if y > 0 else -1, flat=burnt and rng.random() < 0.7)
    else:
        for (x, y) in ((-25, -13), (25, -13), (-25, 13), (25, 13)):
            box((x, y, 3.5), (4, 4, 3.5), mat((112, 86, 56), rough=0.95, grime=0.3), bevel=0.3)
        wheel(66, 16, 0, 7.2, 4.4, side=1)
    z0 = 4.0 + lift
    # lower body side profile (x, z), extruded across the car width
    lower = [(-46, z0 + 2), (-47, z0 + 9), (-44, z0 + 15), (44, z0 + 15), (47, z0 + 11), (47, z0 + 3), (44, z0 + 1), (-43, z0 + 1)]
    prism(lower, -15, 15, paint, bevel=1.6, seg=3)
    # wheel arch shadows
    for x in ((-25, 25) if not on_blocks else ()):
        cyl((x, 15.05, z0 + 1), 8.3, 0.4, mat((20, 20, 20), rough=1), axis='y', bevel=0)
        cyl((x, -15.05, z0 + 1), 8.3, 0.4, mat((20, 20, 20), rough=1), axis='y', bevel=0)
    # greenhouse
    cabin = [(-27, z0 + 15), (-22, z0 + 27), (12, z0 + 27), (21, z0 + 15)]
    prism(cabin, -13.4, 13.4, paint, bevel=1.4, seg=3)
    g = mat((10, 10, 10), rough=1) if burnt else glass()
    # side windows (both sides), windscreen and rear window as thin inset panels
    for ys in (13.5, -13.5):
        prism([(-24.5, z0 + 16.5), (-21, z0 + 25.6), (-5.6, z0 + 25.6), (-5.6, z0 + 16.5)], ys - 0.25, ys + 0.25, g, bevel=0.2)
        prism([(-3.6, z0 + 16.5), (-3.6, z0 + 25.6), (11.0, z0 + 25.6), (18.6, z0 + 16.5)], ys - 0.25, ys + 0.25, g, bevel=0.2)
    mesh([(13, -12, z0 + 26.2), (13, 12, z0 + 26.2), (20.4, 12, z0 + 16.2), (20.4, -12, z0 + 16.2)], [(0, 1, 2, 3)], g)
    mesh([(-22.4, -12, z0 + 26.2), (-22.4, 12, z0 + 26.2), (-26.4, 12, z0 + 16.2), (-26.4, -12, z0 + 16.2)], [(0, 1, 2, 3)], g)
    # roof gutter / drip rails and a roof rack on some
    for ys in (13.2, -13.2):
        box((-5, ys, z0 + 27), (17, 0.5, 0.4), paint, bevel=0.2)
    if rng.random() < 0.5 and not burnt:
        rack = mat((44, 44, 42), rough=0.6, metal=0.4)
        for x in (-16, 2):
            box((x, 0, z0 + 28.6), (0.8, 13, 0.6), rack, bevel=0.2)
        for ys in (-11, 11):
            box((-7, ys, z0 + 29.2), (11, 0.5, 0.5), rack, bevel=0.2)
        box((-7, 2, z0 + 31), (8, 6, 2), mat((92, 84, 60), rough=0.9, grime=0.3), bevel=0.8)   # tarp bundle
    # door seams, handles
    seam = mat((34, 36, 38), rough=0.9)
    for ys in (15.1, -15.1):
        for x in (-4.6, 21):
            box((x, ys, z0 + 13), (0.25, 0.15, 11 if x < 0 else 2), seam, bevel=0)
        box((-4.6, ys, z0 + 21), (0.6, 0.2, 5), seam, bevel=0)                 # B pillar
        for x in (-8, 16):
            box((x, ys + 0.2 * (1 if ys > 0 else -1), z0 + 12.5), (1.6, 0.25, 0.4), chrome(), bevel=0.1)
        box((0, ys, z0 + 7), (40, 0.25, 0.5), mat((120, 122, 120), rough=0.35, metal=0.5), bevel=0.1)  # moulding
    # front: grille, square lamps, chrome bumper; rear: lamps, bumper
    box((47.2, 0, z0 + 10), (0.4, 8, 2.4), mat((30, 30, 30), rough=0.8), bevel=0.1)
    for i in range(-6, 7, 2):
        box((47.5, i, z0 + 10), (0.2, 0.3, 2.2), chrome(), bevel=0)
    for ys in (-11, 11):
        box((47.2, ys, z0 + 10), (0.5, 3.2, 2.4), lamp() if not burnt else seam, bevel=0.3)
    for ys in (-11.5, 11.5):
        box((-47.2, ys, z0 + 10), (0.5, 3.2, 2.0), mat((150, 40, 32), rough=0.3) if not burnt else seam, bevel=0.3)
    for xs in (48.2, -48.2):
        box((xs, 0, z0 + 4.2), (1.0, 15.4, 1.4), chrome() if not burnt else seam, bevel=0.5)
    box((-47.6, 0, z0 + 7.6), (0.3, 5, 1.6), mat((210, 210, 200), rough=0.6), bevel=0)   # number plate
    for ys in (-1, 1):
        box((14, ys * 15.5, z0 + 16), (1.0, 1.4, 1.0), blackplastic(), bevel=0.3)        # mirrors
    if on_blocks:
        # bonnet propped open, engine visible
        import math as _m
        hx, hz = 21, z0 + 15
        ex, ez = hx + 19 * _m.cos(_m.radians(58)), hz + 19 * _m.sin(_m.radians(58))
        mesh([(hx, -13, hz), (hx, 13, hz), (ex, 13, ez), (ex, -13, ez),
              (hx + 0.8, -13, hz - 0.6), (hx + 0.8, 13, hz - 0.6), (ex + 0.8, 13, ez - 0.6), (ex + 0.8, -13, ez - 0.6)],
             [(0, 1, 2, 3), (7, 6, 5, 4), (0, 3, 7, 4), (1, 5, 6, 2), (3, 2, 6, 7), (0, 4, 5, 1)], paint, bevel=0.3)
        tube([(hx + 14, 0, hz), (hx + 9, 0, hz + 13)], 0.3, mat((60, 60, 58)))      # prop rod
        box((34, 0, z0 + 14.8), (10, 12, 0.4), mat((30, 30, 28), rough=1), bevel=0)
        box((32, -3, z0 + 16.5), (5, 5, 2.4), mat((86, 84, 78), rough=0.5, metal=0.5), bevel=0.6)
        cyl((40, 6, z0 + 15), 2.6, 3, mat((40, 40, 40)), bevel=0.4)
        box((-58, 16, 3), (6, 3.5, 3), mat((176, 48, 42), rough=0.4), bevel=0.5)          # toolbox
        box((60, -8, 0.6), (5, 3, 0.6), mat((92, 70, 48), rough=0.9), bevel=0.2)          # plank
    if burnt:
        # scorched interior, sagging roof, bits on the ground
        box((-5, 0, z0 + 17), (17, 11, 1), mat((26, 22, 20), rough=1), bevel=0)
        for i in range(5):
            box((rng.uniform(-50, 50), rng.uniform(16, 24), 0.5), (rng.uniform(1, 3), rng.uniform(1, 2), 0.5),
                mat((40, 36, 32), rough=1), bevel=0.2, rot=(0, 0, rng.uniform(0, 3)))


def uaz_ambulance(burnt=False, seed=2):
    """UAZ-452 'bukhanka': rounded loaf body, split windscreen, red cross."""
    rng = random.Random(seed)
    body = burnt_paint() if burnt else mat((214, 214, 204), rough=0.5, grime=0.10, dust=0.6)
    for x in (-24, 24):
        for y in (-15, 15):
            wheel(x, y, 0, 7.8, 5, side=1 if y > 0 else -1, flat=burnt)
    z0 = 6.0
    prof = [(-42, z0 + 1), (-43, z0 + 30), (-40, z0 + 34), (32, z0 + 34), (40, z0 + 28), (45, z0 + 16), (45.5, z0 + 3), (42, z0 + 1)]
    prism(prof, -16, 16, body, bevel=3.0, seg=4)
    under = mat((34, 34, 32), rough=0.9)
    box((0, 0, z0 + 0.5), (40, 15, 1.5), under, bevel=0.3)
    for x in (-24, 24):
        for ys in (16.05, -16.05):
            cyl((x, ys, z0 + 1), 9.0, 0.4, mat((18, 18, 18), rough=1), axis='y', bevel=0)
    g = mat((10, 10, 10), rough=1) if burnt else glass()
    # split windscreen
    for ys in (-7, 7):
        mesh([(36.6, ys - 6, z0 + 32), (36.6, ys + 6, z0 + 32), (42.2, ys + 6, z0 + 24), (42.2, ys - 6, z0 + 24)], [(0, 1, 2, 3)], g)
    for ys in (16.3, -16.3):
        prism([(26, z0 + 22), (26, z0 + 31), (35, z0 + 31), (39.5, z0 + 22)], ys - 0.25, ys + 0.25, g, bevel=0.2)
        for x in (-12, 6):
            prism([(x, z0 + 22), (x, z0 + 30), (x + 12, z0 + 30), (x + 12, z0 + 22)], ys - 0.25, ys + 0.25, g, bevel=0.3)
    seam = mat((140, 140, 134), rough=0.8)
    red = mat((180, 40, 36), rough=0.45)
    if not burnt:
        for ys in (16.5, -16.5):
            box((0, ys, z0 + 18), (42, 0.2, 1.4), red, bevel=0)                         # stripe
            box((-28, ys, z0 + 26.5), (4.2, 0.2, 1.3), red, bevel=0)
            box((-28, ys, z0 + 26.5), (1.3, 0.2, 4.2), red, bevel=0)
    for ys in (16.4, -16.4):
        for x in (24, 0):
            box((x, ys, z0 + 16), (0.25, 0.2, 14), seam, bevel=0)
        box((22, ys, z0 + 14), (1.4, 0.4, 0.5), chrome(), bevel=0.1)
    # nose details
    box((45.6, 0, z0 + 10), (0.4, 9, 3.6), mat((44, 46, 44), rough=0.7), bevel=0.2)
    for i in range(-7, 8, 2):
        box((45.9, i, z0 + 10), (0.2, 0.4, 3.2), mat((70, 72, 70)), bevel=0)
    for ys in (-12, 12):
        cyl((45.8, ys, z0 + 13), 2.2, 0.8, lamp() if not burnt else seam, axis='x', bevel=0.3)
    box((47, 0, z0 + 2.4), (1, 15.4, 1.4), mat((60, 62, 60), rough=0.6, metal=0.3), bevel=0.4)
    box((-43.4, 0, z0 + 2.4), (1, 15.4, 1.4), mat((60, 62, 60), rough=0.6, metal=0.3), bevel=0.4)
    # roof: beacon + spare wheel ladder at the rear
    if not burnt:
        cyl((28, 0, z0 + 34), 2.6, 2.6, mat((60, 110, 210), rough=0.15, emit=(80, 140, 255)), bevel=0.4)
    else:
        box((-5, 0, z0 + 34.3), (30, 13, 0.6), mat((24, 20, 18), rough=1), bevel=0.2)
    for ys in (-1, 1):
        box((33, ys * 16.8, z0 + 24), (1.2, 1.4, 1.2), blackplastic(), bevel=0.3)


# --------------------------------------------------------------- military ---
OLIVE = (86, 98, 60)


def btr80(seed=3):
    rng = random.Random(seed)
    hull = mat(OLIVE, rough=0.75, grime=0.16, dust=0.7)
    for x in (-36, -12, 12, 36):
        for y in (-19, 19):
            wheel(x, y, 0, 9.0, 6, side=1 if y > 0 else -1, hub_bolts=8)
    z = 9.0
    # boat-shaped hull: lower plate, upper sloped plates
    prism([(-58, z + 2), (-60, z + 14), (-58, z + 22), (44, z + 24), (58, z + 14), (60, z + 6), (50, z), (-54, z)], -19, 19, hull, bevel=1.4)
    prism([(-58, z + 22), (-54, z + 26), (38, z + 27), (44, z + 24)], -21, 21, hull, bevel=1.2)
    # side sponsons slope
    for s in (-1, 1):
        mesh([(-56, s * 19, z + 22), (44, s * 19, z + 23.5), (40, s * 22, z + 16), (-56, s * 22, z + 16)], [(0, 1, 2, 3)], hull)
    dark = mat(dk(OLIVE, 0.6), rough=0.8)
    # hatches, vision blocks, firing ports, tow hooks
    for x in (-40, -18, 4, 24):
        box((x, 21.5, z + 18.5), (2.2, 0.6, 1.4), dark, bevel=0.3)
        cyl((x + 5, 21.6, z + 18.5), 1.0, 0.6, mat((30, 30, 30)), axis='y', bevel=0.1)
    box((-8, 22, z + 10), (6, 0.6, 5), dark, bevel=0.4)                                # side door
    for x in (-48, -30):
        box((x, 0, z + 27.4), (5, 6, 0.8), hull, bevel=0.5)
        cyl((x, 0, z + 28), 1.2, 1, dark, bevel=0.2)
    box((-50, 0, z + 27.6), (6, 12, 0.6), mat(dk(OLIVE, 0.85), rough=0.8), bevel=0.2)  # engine grille
    for i in range(-10, 11, 2):
        box((-50, i, z + 28.3), (5.6, 0.3, 0.2), dark, bevel=0)
    # turret + KPVT + PKT
    cyl((14, 0, z + 27), 10, 6, hull, bevel=1.4, verts=36)
    cyl((14, 0, z + 33), 7.5, 2, hull, bevel=1.0, verts=36)
    box((22, 0, z + 31), (4, 4, 2.4), hull, bevel=0.8)
    cyl((44, -1.5, z + 31), 1.3, 40, mat((46, 48, 42), rough=0.5, metal=0.5), axis='x', bevel=0.2)
    cyl((63, -1.5, z + 31), 1.9, 4, mat((40, 42, 38), rough=0.5, metal=0.5), axis='x', bevel=0.3)
    cyl((34, 3, z + 31), 0.8, 18, mat((40, 42, 38), rough=0.5, metal=0.5), axis='x', bevel=0.1)
    for i in range(3):
        cyl((16 + i * 3, -9, z + 33), 1.0, 2.4, dark, bevel=0.2)                        # smoke launchers
    # headlights with guards, front trim vane
    for ys in (-14, 14):
        cyl((58, ys, z + 16), 1.8, 1.2, lamp(), axis='x', bevel=0.3)
        box((59, ys, z + 16), (0.4, 2.6, 0.3), dark, bevel=0)
    box((60.6, 0, z + 8), (0.6, 14, 4), hull, bevel=0.4)
    # stowage: logs, jerrycans, ropes on the rear deck
    box((-56, 0, z + 31), (1.8, 16, 1.8), mat((104, 82, 56), rough=0.95, grime=0.3), bevel=0.8, rot=(0, 0, 0))
    for i in range(2):
        box((-38 + i * 5, -16, z + 29.5), (2, 1.2, 3), mat((70, 82, 50), rough=0.6), bevel=0.4)


def t72_wreck(seed=4):
    """T-72 hulk: turret torn off and lying against the hull, charred ring,
    engine deck grilles, fuel drums, rubber skirts hanging loose."""
    rng = random.Random(seed)
    hull = mat((80, 88, 58), rough=0.85, grime=0.2, dust=0.8, scale=0.12)
    soot = mat((40, 36, 30), rough=1, grime=0.3)
    steel = mat((54, 54, 50), rough=0.7, metal=0.4)
    era = mat((92, 96, 64), rough=0.8, grime=0.2)
    # tracks: belt + road wheels + idler/sprocket
    for s in (-1, 1):
        prism([(-52, 2), (-56, 8), (-50, 14), (50, 14), (58, 9), (54, 2), (46, 0), (-46, 0)], s * 15, s * 23, mat((38, 36, 34), rough=0.9), bevel=0.8)
        for x in range(-40, 44, 13):
            cyl((x, s * 23.3, 7), 5.6, 0.8, steel, axis='y', bevel=0.4)
            cyl((x, s * 23.8, 7), 1.8, 0.6, mat((40, 40, 38)), axis='y', bevel=0.1)
        for x in (-52, 53):
            cyl((x, s * 23.3, 8), 4.0, 0.8, steel, axis='y', bevel=0.3)
        for x in range(-50, 52, 3):
            box((x, s * 23.2, 13.9), (0.6, 0.3, 0.4), mat((28, 28, 26)), bevel=0)
    # hull with glacis and engine deck
    prism([(-56, 8), (-56, 20), (36, 21), (58, 13), (56, 8)], -17, 17, hull, bevel=1.2)
    for s in (-1, 1):
        box((0, s * 20.5, 19), (52, 4, 0.8), hull, bevel=0.3)                          # fenders
        for i in range(6):
            box((-40 + i * 16, s * 24.6, 16), (7, 0.4, 3), mat((58, 60, 46), rough=0.8), bevel=0.3,
                rot=(rng.uniform(-0.1, 0.35) * s, 0, 0))                                # loose skirt plates
        for x in (-12, 6, 22):
            box((x, s * 20.5, 21), (6, 3, 1.6), mat((74, 82, 54), rough=0.8), bevel=0.4)   # fender boxes
    for x in (-50, -40):
        cyl((x, 0, 23), 4.4, 30, mat((70, 78, 50), rough=0.7), axis='y', bevel=0.5)       # rear fuel drums
        for yy in (-8, 8):
            cyl((x, yy, 23), 4.6, 0.8, steel, axis='y', bevel=0.2)
    for i in range(7):
        box((-30 + i * 3.4, 0, 21.3), (1.2, 12, 0.4), mat((30, 30, 28)), bevel=0)          # engine grille slats
    tube([(-24, -14, 22), (-24, -14, 24), (20, -14, 24)], 1.4, steel)                      # snorkel tube
    # ERA bricks on the glacis
    for i in range(6):
        for j in range(2):
            box((42 + j * 6.5, -13 + i * 5.2, 18 - j * 2.6), (2.8, 2.3, 1.1), era, bevel=0.3, rot=(0, 0.35, 0))
    for s in (-1, 1):
        cyl((56, s * 13, 14), 1.4, 1, lamp(), axis='x', bevel=0.2)
    # open turret ring, charred
    cyl((4, 0, 20.5), 13, 1.4, soot, bevel=0.3, verts=40)
    cyl((4, 0, 21), 10.5, 0.8, mat((12, 10, 9), rough=1), bevel=0, verts=40)
    box((4, 0, 21.6), (20, 15, 0.2), mat((52, 48, 40), rough=1, grime=0.4), bevel=0)        # soot fan on the deck
    # torn-off turret lying on the ground in front, tilted, gun pointing away
    t = []
    t.append(prism([(-20, 0), (-18, 9), (-6, 13), (12, 12), (22, 6), (22, 0)], -17, 17, hull, bevel=3.0, seg=3))
    t.append(cyl((-2, 0, 13), 7, 2.6, hull, bevel=0.8))
    t.append(cyl((-10, -7, 13), 3.4, 2.4, hull, bevel=0.6))
    for i in range(6):
        t.append(box((18, -14 + i * 5.6, 7), (2.6, 2.4, 1.2), era, bevel=0.3, rot=(0, 0.8, 0)))
    t.append(cyl((54, 0, 7), 2.2, 64, steel, axis='x', bevel=0.3))
    t.append(cyl((70, 0, 7), 2.6, 6, mat((50, 50, 46), rough=0.6, metal=0.4), axis='x', bevel=0.3))
    for i in range(4):
        t.append(cyl((-6 + i * 3, 15, 10), 1.1, 3, steel, bevel=0.2))                        # smoke launchers
    t.append(cyl((-14, 6, 15), 0.6, 12, steel, bevel=0.1))                                  # antenna stub
    rotate(t, math.radians(-14), (0, 0, 0), 'x')
    rotate(t, math.radians(155), (0, 0, 0), 'z')
    for o in t:
        o.location.x += -2
        o.location.y -= 40          # blender -y = toward the camera
        o.location.z += 1.5
    # debris and scattered track links
    for i in range(9):
        box((rng.uniform(-50, 60), rng.uniform(26, 30), 0.6), (rng.uniform(1, 3.5), rng.uniform(1, 2.5), 0.6),
            soot if i % 2 else steel, bevel=0.2, rot=(0, 0, rng.uniform(0, 3)))


def mi8_wreck(seed=5):
    rng = random.Random(seed)
    body = mat((92, 102, 70), rough=0.75, grime=0.18, dust=0.5, scale=0.1)
    belly = mat((108, 124, 132), rough=0.7, grime=0.1)
    dark = mat((24, 22, 20), rough=1)
    # fuselage: side profile with rounded nose, extruded and bevelled hard
    prism([(-30, 2), (-32, 24), (-28, 30), (24, 30), (36, 24), (44, 14), (44, 7), (38, 2)], -12, 12, body, bevel=4.5, seg=4)
    prism([(-30, 1), (38, 1), (40, 6), (-30, 6)], -11, 11, belly, bevel=2)
    # cockpit glazing
    g = glass((44, 60, 66))
    for s in (-1, 1):
        mesh([(34, s * 2, 25), (34, s * 10, 23.5), (42.5, s * 9, 14), (43.5, s * 2, 15)], [(0, 1, 2, 3)], g)
        prism([(26, 16), (26, 25), (33, 25), (39, 16)], s * 12.2 - 0.3, s * 12.2 + 0.3, g, bevel=0.3)
    # round cabin windows, sliding door open (dark)
    for x in (-24, -14, 6, 14):
        cyl((x, 12.6, 19), 2.2, 0.6, g, axis='y', bevel=0.2)
    box((-4, 12.4, 13), (6, 0.4, 9), dark, bevel=0.2)
    # engine deck, exhausts, rotor head with bent blades
    box((-4, 0, 32), (18, 7, 3), body, bevel=1.6)
    for s in (-1, 1):
        cyl((-18, s * 7, 32), 2.4, 6, mat((40, 38, 36), rough=0.6, metal=0.4), axis='x', bevel=0.4)
    cyl((-2, 0, 35), 2.4, 4, mat((60, 62, 58), rough=0.5, metal=0.5), bevel=0.4)
    cyl((-2, 0, 39), 4, 1.4, mat((52, 54, 50), rough=0.5, metal=0.5), bevel=0.3)
    bl = mat((46, 48, 46), rough=0.6, metal=0.3)
    # rotor blades: flat drooping spars, two snapped short, one lying on the ground
    for a, l, droop in ((0.5, 58, 10), (2.0, 22, 4), (3.3, 50, 16), (4.6, 18, 3)):
        ca, sa = math.cos(a), math.sin(a)
        segs = 6
        for k in range(segs):
            t0, t1 = k / segs, (k + 1) / segs
            p0 = (-2 + ca * t0 * l, sa * t0 * l * 0.9, 40 - droop * t0 * t0)
            p1 = (-2 + ca * t1 * l, sa * t1 * l * 0.9, 40 - droop * t1 * t1)
            mx, my, mz = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
            ln = math.dist(p0, p1) / 2
            pitch = math.atan2(p0[2] - p1[2], math.hypot(p1[0] - p0[0], p1[1] - p0[1]))
            box((mx, my, mz), (ln, 2.0, 0.35), bl, bevel=0.15, rot=(0, -pitch, -a))
    for k in range(4):
        box((-40 + k * 15, 30, 0.5), (7.6, 2.0, 0.4), bl, bevel=0.15, rot=(0, 0, 0.12))     # blade on the ground
    # tail boom snapped, lying behind
    prism([(-30, 18), (-30, 28), (-58, 26), (-58, 22)], -4, 4, body, bevel=1.6)
    tb = prism([(-64, 2), (-64, 8), (-98, 6), (-98, 3)], -2.5, 2.5, body, bevel=1.0)
    fin = prism([(-94, 4), (-100, 22), (-96, 22), (-90, 6)], -1, 1, body, bevel=0.6)
    rotate([tb, fin], math.radians(18), (-64, 0, 0), 'z')
    # landing gear: front collapsed, main legs
    for s in (-1, 1):
        tube([(-6, s * 10, 6), (-6, s * 18, 2)], 0.8, mat((60, 60, 56), metal=0.5, rough=0.5))
        wheel(-6, s * 19, 0, 4.2, 3, side=s)
    # tactical number + red star outline
    num = mat((214, 200, 150), rough=0.7)
    for x in (-24, -19):
        box((x, 12.6, 11), (1.6, 0.1, 2.6), num, bevel=0)
        box((x, 12.7, 11), (0.7, 0.1, 1.6), body, bevel=0)
    # soot plume from the engine bay
    box((-4, 0, 30.5), (15, 7.6, 0.4), mat((30, 26, 22), rough=1), bevel=0)
    for i in range(6):
        box((rng.uniform(-40, 50), rng.uniform(16, 34), 0.5), (rng.uniform(1, 3), rng.uniform(1, 2), 0.5), dark, bevel=0.2,
            rot=(0, 0, rng.uniform(0, 3)))


def kamaz_bowser(seed=6):
    cab = mat(OLIVE, rough=0.6, grime=0.12, dust=0.6)
    tank = mat((116, 126, 88), rough=0.55, grime=0.12, dust=0.4)
    frame = mat((36, 36, 34), rough=0.8)
    for x in (-36, -22, 36):
        for y in (-15, 15):
            wheel(x, y, 0, 8.0, 5.4, side=1 if y > 0 else -1, hub_bolts=8)
    box((-4, 0, 13), (50, 9, 2), frame, bevel=0.4)
    # cab-over: KamAZ-4310
    prism([(26, 10), (26, 36), (44, 36), (50, 30), (52, 22), (52, 10)], -15, 15, cab, bevel=2.2)
    g = glass()
    mesh([(44.6, -13, 35), (44.6, 13, 35), (50.6, 13, 29.4), (50.6, -13, 29.4)], [(0, 1, 2, 3)], g)
    for s in (-1, 1):
        prism([(30, 24), (30, 33), (44, 33), (49, 26), (49, 24)], s * 15.2 - 0.3, s * 15.2 + 0.3, g, bevel=0.3)
        box((34, s * 15.3, 18), (0.2, 0.2, 6), frame, bevel=0)
        box((48, s * 17.5, 28), (0.6, 1.6, 3), blackplastic(), bevel=0.3)
        box((50, s * 12, 15), (2.4, 4, 3.2), cab, bevel=0.8)                             # fenders
    box((52.4, 0, 18), (0.4, 9, 4), mat((30, 32, 30)), bevel=0.2)
    for s in (-1, 1):
        cyl((52.4, s * 10, 18), 1.8, 0.8, lamp(), axis='x', bevel=0.2)
    box((54, 0, 10), (1.2, 15, 2), frame, bevel=0.4)
    box((40, 0, 36.6), (5, 12, 0.8), cab, bevel=0.3)                                     # sun visor
    # tank: elliptical section via scaled cylinder
    t = cyl((-12, 0, 27), 13, 74, tank, axis='x', bevel=1.4, verts=40)
    t.scale = (1, 1, 0.82)
    for x in (-44, -24, -4, 16):
        c = cyl((x, 0, 27), 13.4, 1.2, mat((96, 104, 72), rough=0.6), axis='x', bevel=0.3, verts=40)
        c.scale = (1, 1, 0.82)
    for x in (-34, -6, 12):
        cyl((x, 0, 37), 3.4, 2.2, mat((90, 96, 68), rough=0.5, metal=0.3), bevel=0.4)    # domes
    box((-12, 0, 38.4), (30, 2, 0.4), mat((60, 60, 56)), bevel=0)                        # walkway
    for s in (-1, 1):
        box((-12, s * 13, 14.2), (34, 1, 1.4), mat((60, 62, 58), metal=0.3), bevel=0.3)  # side boxes
    box((-50, 12, 16), (3, 3, 4), mat((70, 72, 68), metal=0.4), bevel=0.5)               # pump box
    tube([(-50, 15, 14), (-52, 22, 4), (-40, 26, 1), (-30, 24, 1)], 0.9, frame)          # hose
    # FLAMMABLE stencil band
    for s in (1,):
        box((-12, s * 13.2, 22), (16, 0.2, 1.8), mat((200, 170, 60), rough=0.5), bevel=0)


def gen_trailer(seed=7):
    body = mat(OLIVE, rough=0.6, grime=0.14, dust=0.5)
    frame = mat((40, 40, 38), rough=0.8)
    for y in (-13, 13):
        wheel(0, y, 0, 6.6, 4, side=1 if y > 0 else -1)
    box((0, 0, 9), (30, 11, 1.4), frame, bevel=0.3)
    tube([(30, 0, 9), (50, 0, 6), (54, 0, 6)], 0.9, frame)
    cyl((54, 0, 2), 1.2, 4, frame, bevel=0.2)
    prism([(-28, 11), (-28, 34), (26, 34), (28, 30), (28, 11)], -10, 10, body, bevel=1.4)
    lv = mat(dk(OLIVE, 0.6), rough=0.8)
    for x in range(-20, 22, 3):
        box((x, 10.3, 24), (0.6, 0.3, 6), lv, bevel=0.1)
    box((-20, 10.4, 17), (5, 0.3, 3.4), mat((50, 52, 50)), bevel=0.2)
    for i, c in enumerate(((220, 70, 50), (80, 190, 90), (230, 200, 70))):
        cyl((-23 + i * 3, 10.8, 17.5), 0.7, 0.5, mat(c, rough=0.3, emit=c if i == 1 else None), axis='y', bevel=0.1)
    cyl((18, -5, 34), 1.6, 10, mat((52, 50, 46), metal=0.5, rough=0.5), bevel=0.3)
    cyl((18, -5, 44), 2.0, 0.8, mat((40, 38, 36)), bevel=0.2)
    tube([(-28, 6, 14), (-36, 14, 3), (-44, 22, 0.5), (-60, 26, 0.5)], 0.7, mat((28, 28, 28)))  # cable


def cryo_semi(seed=8):
    tank = mat((176, 180, 180), rough=0.55, metal=0.1, grime=0.12, dust=0.5)
    frame = mat((44, 44, 42), rough=0.8)
    for x in (-38, -26, -14):
        for y in (-14, 14):
            wheel(x, y, 0, 7, 4.4, side=1 if y > 0 else -1)
    box((-6, 0, 11), (46, 9, 1.6), frame, bevel=0.3)
    cyl((-6, 0, 27), 14, 82, tank, axis='x', bevel=1.0, verts=48)
    for x in (-46, 34):
        sphere((x, 0, 27), 14, tank, scale=(0.35, 1, 1))
    for x in (-36, 22):
        cyl((x, 0, 27), 14.4, 1.4, mat((150, 154, 156), metal=0.5, rough=0.4), axis='x', bevel=0.3, verts=48)
    # valve cabinet at the rear with pipework
    box((-52, 0, 18), (3, 10, 6), mat((120, 124, 124), rough=0.5, metal=0.3), bevel=0.6)
    for i, ys in enumerate((-6, 0, 6)):
        tube([(-50, ys, 22), (-55, ys, 22), (-55, ys, 14)], 0.7, chrome())
        cyl((-55.6, ys, 16), 1.4, 0.6, mat((40, 110, 180), rough=0.4), axis='x', bevel=0.1)
    box((-6, 14.2, 33), (18, 0.3, 2.2), mat((60, 120, 176), rough=0.4), bevel=0)        # O2 band
    for s in (-1, 1):
        box((-6, s * 12, 13.8), (40, 1.2, 1.4), mat((70, 72, 70), metal=0.4), bevel=0.3)
    # landing legs and king pin
    for s in (-1, 1):
        box((30, s * 8, 6), (1, 1, 6), frame, bevel=0.2)
        box((30, s * 8, 0.6), (2.4, 2.4, 0.6), frame, bevel=0.2)


def burnt_bus_fragment(seed=10):
    pass



# ---------------------------------------------------- High Risk set pieces --
CONC = (150, 148, 138)
STEEL = (120, 124, 124)


def concrete(c=CONC, dust=0.4):
    return mat(c, rough=0.92, grime=0.18, dust=dust, scale=0.15)


def steel(c=STEEL):
    return mat(c, rough=0.5, metal=0.5, grime=0.12, dust=0.3)


def rusty(c=(118, 74, 46)):
    return mat(c, rough=0.85, metal=0.2, grime=0.3, scale=0.2)


def vent_head():
    """exhaust head of an underground ventilation shaft: louvred concrete box."""
    box((0, 0, 4), (26, 22, 4), concrete(), bevel=0.8)
    box((0, 0, 22), (18, 16, 14), concrete((140, 138, 128)), bevel=1.0)
    lv = steel((96, 100, 98))
    for z in range(12, 34, 4):
        for (cx, cy, sx, sy) in ((0, 16.6, 15, 0.5), (18.6, 0, 0.5, 13)):
            box((cx, cy, z), (sx, sy, 1.2), lv, bevel=0.2, rot=(0.5 if sy < 1 else 0, 0.5 if sx < 1 else 0, 0))
        box((0, 16.2, z - 1.6), (15.4, 0.4, 0.4), mat((30, 30, 30), rough=1), bevel=0)
    box((0, 0, 38), (22, 20, 2), concrete((118, 118, 112)), bevel=0.8)
    cyl((14, -10, 40), 3.6, 12, steel(), bevel=0.5)
    cyl((14, -10, 52), 4.6, 1.2, steel((90, 92, 90)), bevel=0.3)
    box((0, 16.8, 9), (6, 0.3, 3.6), mat((206, 164, 44), rough=0.5), bevel=0.1)
    for z in range(10, 38, 4):
        box((-20.5, 10, z), (0.6, 3.5, 0.35), steel((70, 72, 70)), bevel=0)
    for s_ in (-1, 1):
        box((-20.5, 10 + s_ * 3.5, 22), (0.6, 0.4, 16), steel((70, 72, 70)), bevel=0.1)


def cooling_fans():
    """dry-cooler array: three fan units on a concrete pad, pipes in front."""
    box((0, 0, 3), (56, 24, 3), concrete(), bevel=0.8)
    unit = mat((150, 154, 150), rough=0.55, metal=0.3, grime=0.12, dust=0.4)
    for x in (-32, 0, 32):
        box((x, 0, 18), (14, 19, 12), unit, bevel=0.8)
        for k in range(-11, 12, 3):
            box((x + k, 19.2, 18), (0.5, 0.3, 9), mat((96, 100, 98)), bevel=0)
        cyl((x, 0, 30), 11.5, 2.4, steel((90, 92, 90)), bevel=0.5, verts=40)
        cyl((x, 0, 30.6), 10.2, 1.6, mat((28, 28, 28), rough=1), bevel=0, verts=40)
        for a in range(5):
            ang = a / 5 * math.tau + x * 0.1
            box((x + math.cos(ang) * 5, math.sin(ang) * 5, 31.4), (4.6, 1.4, 0.2), steel((130, 132, 128)), bevel=0.1, rot=(0, 0, -ang))
        cyl((x, 0, 31.4), 1.6, 1.0, steel((60, 60, 58)), bevel=0.2)
        for k in (-8, -4, 0, 4, 8):
            box((x + k, 0, 33.2), (0.25, 10.6, 0.25), steel((70, 72, 70)), bevel=0)
            box((x, k, 33.2), (10.6, 0.25, 0.25), steel((70, 72, 70)), bevel=0)
    for y, z in ((22, 8), (22, 14)):
        cyl((0, y, z), 2.4, 118, rusty(), axis='x', bevel=0.3)
    for x in (-50, 50):
        box((x, 23, 4), (1.5, 1.5, 6), steel((60, 62, 60)), bevel=0.2)
    box((52, -16, 12), (4, 3, 7), mat((86, 98, 70), rough=0.6), bevel=0.5)


def light_mast():
    box((0, 0, 3), (8, 8, 3), concrete(), bevel=0.6)
    for x in (-6, 6):
        for y in (-6, 6):
            cyl((x, y, 6), 0.8, 1.2, steel((60, 60, 58)), bevel=0.1)
    cyl((0, 0, 6), 2.8, 40, steel((130, 132, 128)), bevel=0.3)
    cyl((0, 0, 46), 2.2, 60, steel((130, 132, 128)), bevel=0.3)
    cyl((0, 0, 106), 1.7, 50, steel((130, 132, 128)), bevel=0.3)
    for z in range(16, 150, 6):
        box((0, 2.6, z), (1.4, 0.35, 0.3), steel((80, 80, 78)), bevel=0)
    box((0, 0, 156), (19, 2.4, 1.2), steel((80, 82, 80)), bevel=0.3)
    for x in (-13, -4.5, 4.5, 13):
        box((x, 1.5, 160), (3.6, 2.2, 3.2), steel((70, 72, 70)), bevel=0.5, rot=(0.35, 0, 0))
        box((x, 3.7, 159.4), (3.0, 0.3, 2.6), lamp(True), bevel=0.2, rot=(0.35, 0, 0))
    box((3.4, 0, 20), (1.6, 2.6, 3.4), mat((90, 96, 92), rough=0.6), bevel=0.3)
    tube([(3, 2.5, 18), (8, 10, 2), (16, 14, 0.4)], 0.5, blackplastic())


def hazmat_drums():
    pal = mat((128, 100, 66), rough=0.95, grime=0.3)
    for i in range(5):
        box((-6 + 0, -12 + i * 6, 1), (24, 2.2, 1), pal, bevel=0.2)
    yellow = mat((200, 164, 44), rough=0.55, grime=0.18, dust=0.4)
    green = mat((60, 96, 70), rough=0.55, grime=0.18, dust=0.4)
    band = mat((70, 58, 24), rough=0.6)
    for i, (x, y) in enumerate([(-22, -6), (-8, -8), (6, -6), (-16, 8), (0, 8)]):
        m = green if i == 2 else yellow
        cyl((x, y, 2), 6.8, 16, m, bevel=0.6)
        for z in (7, 13):
            cyl((x, y, 2 + z - 0.4), 7.0, 0.8, band, bevel=0.2)
        cyl((x + 3, y - 2, 18), 1.2, 0.6, band, bevel=0.1)
    d = cyl((34, 16, 6.8), 6.8, 16, yellow, axis='x', bevel=0.6)
    for xx in (29, 39):
        cyl((xx, 16, 6.8), 7.0, 0.8, band, axis='x', bevel=0.2)
    mesh([(42, 12, 0.15), (58, 14, 0.15), (60, 24, 0.15), (44, 26, 0.15)], [(0, 1, 2, 3)], mat((40, 44, 30), rough=0.15))  # spill


def body_bags():
    """a row of zipped body bags laid out on plastic sheeting, tags at the feet."""
    blk = mat((36, 40, 36), rough=0.35, grime=0.1)
    wht = mat((188, 194, 188), rough=0.5, grime=0.15, dust=0.4)
    box((0, 0, 0.2), (40, 30, 0.2), mat((70, 96, 110), rough=0.4, grime=0.2), bevel=0.1)       # sheeting
    for i in range(5):
        y = -22 + i * 11
        x = (i % 2) * 3 - 2
        o = sphere((x, y, 3.0), 1, blk if i % 2 else wht)
        o.scale = (17, 4.6, 3.0)
        box((x - 2, y + 4.6, 3.2), (13, 0.2, 0.25), mat((120, 120, 116), metal=0.5), bevel=0)    # zipper
        box((x + 17, y, 2.2), (1.2, 2.4, 1.2), mat((210, 200, 150)), bevel=0.3)                  # toe tag
    box((52, 12, 2.2), (6, 4, 2.2), mat((210, 196, 120), rough=0.9), bevel=1.2)                 # lime sack
    box((52, -4, 0.3), (8, 6, 0.3), mat((226, 222, 210), rough=1), bevel=0.2)                   # lime spill


def decon_tunnel():
    L = 70
    skin = mat((206, 208, 198), rough=0.7, grime=0.12, dust=0.5)
    rib = mat((150, 156, 148), rough=0.6)
    t = cyl((0, 0, 0), 18, 2 * L, skin, axis='x', bevel=0.8, verts=40)
    t.scale = (22 / 18, 1, 1)               # local x is world up after the axis rotation
    for i in range(9):
        r = cyl((-L + i * 2 * L / 8, 0, 0), 18.6, 1.6, rib, axis='x', bevel=0.4, verts=40)
        r.scale = (22 / 18, 1, 1)
    # clear PVC windows and a side zip door
    win = mat((120, 140, 140), rough=0.15, grime=0.1)
    for x in (-45, -10, 25):
        bk.panel([(x - 8, 17.2, 10), (x + 8, 17.2, 10), (x + 8, 15.2, 16), (x - 8, 15.2, 16)], win)
    bk.panel([(48, 17.9, 0.5), (58, 17.9, 0.5), (58, 16.5, 13), (48, 16.5, 13)], mat((40, 70, 110), rough=0.4))
    tube([(53, 18.2, 0.5), (53, 16.8, 13)], 0.25, mat((200, 200, 190)))
    # entrance frame and flap
    for s_ in (-1, 1):
        box((L + 2, s_ * 14, 12), (1.2, 1.2, 12), mat((206, 164, 44), rough=0.5), bevel=0.3)
    box((L + 2, 0, 24.4), (1.2, 15, 1.2), mat((206, 164, 44), rough=0.5), bevel=0.3)
    box((L + 1.4, 0, 11), (0.2, 12, 11), mat((40, 70, 110), rough=0.4), bevel=0)
    # shower stand and hose
    cyl((L + 14, 12, 0), 1, 28, steel(), bevel=0.2)
    box((L + 14, 9, 28), (1.2, 4, 0.8), steel(), bevel=0.2)
    tube([(L + 14, 12, 2), (L + 22, 20, 0.5), (L + 40, 18, 0.5)], 0.7, mat((40, 60, 120)))
    # ground cleat pegs
    for x in range(-L, L + 1, 28):
        for s_ in (-1, 1):
            box((x, s_ * 22, 1), (0.6, 0.6, 1), steel((60, 60, 58)), bevel=0)


def _container(x, y, z, col, door_open=False):
    body = mat(col, rough=0.7, metal=0.2, grime=0.2, dust=0.3, scale=0.12)
    box((x, y, z + 13), (29, 12, 13), body, bevel=0.6)
    rib = mat(dk(col, 0.82), rough=0.7, metal=0.2)
    for k in range(-26, 27, 3):
        box((x + k, y + 12.2, z + 13), (0.6, 0.3, 11.4), rib, bevel=0)
        box((x + k, y, z + 26.15), (0.5, 11.4, 0.2), rib, bevel=0)
    for (cx, cy) in ((-28, -11), (28, -11), (-28, 11), (28, 11)):
        box((x + cx, y + cy, z + 1), (1.2, 1.2, 1), steel((60, 60, 58)), bevel=0.2)
        box((x + cx, y + cy, z + 25), (1.2, 1.2, 1), steel((60, 60, 58)), bevel=0.2)
    # door end (east): locking bars
    for yy in (-6, -2, 2, 6):
        box((x + 29.3, y + yy, z + 13), (0.3, 0.4, 11.6), steel((80, 80, 78)), bevel=0)
    if door_open:
        box((x + 29.6, y, z + 13), (0.2, 11.4, 11.6), mat((22, 20, 18), rough=1), bevel=0)
        box((x + 36, y + 14, z + 13), (6.4, 0.6, 11.6), body, bevel=0.3, rot=(0, 0, -0.5))


def container_stack():
    _container(-30, 0, 0, (128, 62, 44), door_open=True)
    _container(30, 0, 0, (60, 90, 112))
    _container(0, 0, 26.6, (78, 100, 70))
    box((-56, 16, 0.4), (4, 3, 0.4), mat((120, 96, 66), rough=1), bevel=0.2)


def crater():
    rng = random.Random(311)
    soil = mat((92, 80, 60), rough=1, grime=0.3, scale=0.2)
    dark = mat((44, 38, 30), rough=1, grime=0.2)
    n = 24
    rim, inner, pit = [], [], []
    for i in range(n):
        a = i / n * math.tau
        k = rng.uniform(0.86, 1.1)
        rim.append((math.cos(a) * 48 * k, math.sin(a) * 32 * k, 0.1))
        inner.append((math.cos(a) * 34 * k, math.sin(a) * 23 * k, 3.4 + rng.uniform(-0.6, 0.6)))
        pit.append((math.cos(a) * 22 * k, math.sin(a) * 15 * k, 0.6))
    verts = rim + inner + pit + [(0, 2, 0.3)]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
        faces.append((n + i, n + j, 2 * n + j, 2 * n + i))
        faces.append((2 * n + i, 2 * n + j, 3 * n))
    o = mesh(verts, faces, soil, smooth=True)
    mesh([(math.cos(a) * 12, math.sin(a) * 7 + 2, 0.7) for a in [i / 12 * math.tau for i in range(12)]],
         [tuple(range(12))], mat((52, 64, 72), rough=0.1))                               # rain water
    mesh([(math.cos(a) * 20, math.sin(a) * 13, 0.65) for a in [i / 16 * math.tau for i in range(16)]],
         [tuple(range(16))], dark)
    for _ in range(16):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(46, 62)
        box((math.cos(a) * r, math.sin(a) * r * 0.68, 1.2), (rng.uniform(1.5, 4), rng.uniform(1, 3), rng.uniform(0.8, 2)),
            rng.choice([soil, concrete(), dark]), bevel=0.5, rot=(0, 0, rng.uniform(0, 3)))


def sandbag_wall():
    rng = random.Random(312)
    for row in range(4):
        for i in range(12):
            x = -66 + i * 12 + (6 if row % 2 else 0)
            if x > 66:
                continue
            c = (150 - rng.randint(0, 18), 132 - rng.randint(0, 14), 92 - rng.randint(0, 10))
            box((x, rng.uniform(-0.6, 0.6), 2.6 + row * 5.0), (5.9, 6, 2.7), mat(c, rough=1, grime=0.25, dust=0.5, scale=0.3),
                bevel=2.2, seg=3, rot=(0, 0, rng.uniform(-0.06, 0.06)))
    # PKM on its bipod in the firing slot
    gun = mat((40, 40, 38), rough=0.5, metal=0.5)
    box((-38, 8, 21), (7, 1.2, 1.4), gun, bevel=0.3, rot=(0, 0, -1.1))
    cyl((-34, 18, 21), 0.6, 14, gun, axis='y', bevel=0.1)
    box((-38, 6, 21.2), (2.4, 2.4, 1.8), mat((60, 70, 44)), bevel=0.4)


def lattice_mast():
    h = 176
    red = mat((176, 64, 50), rough=0.6, metal=0.3)
    wht = mat((200, 200, 194), rough=0.6, metal=0.3)
    legs = [(-10, -10), (10, -10), (10, 10), (-10, 10)]
    for (x, y) in legs:
        for k in range(4):
            z0, z1 = k * h / 4, (k + 1) * h / 4
            s0, s1 = 1 - z0 / h * 0.8, 1 - z1 / h * 0.8
            tube([(x * s0, y * s0, z0), (x * s1, y * s1, z1)], 0.8, red if k % 2 == 0 else wht)
    for z in range(8, h - 8, 12):
        k0, k1 = 1 - z / h * 0.8, 1 - (z + 12) / h * 0.8
        for (a, b) in ((0, 1), (1, 2), (2, 3), (3, 0)):
            (xa, ya), (xb, yb) = legs[a], legs[b]
            tube([(xa * k0, ya * k0, z), (xb * k1, yb * k1, z + 12)], 0.35, mat((150, 150, 144), metal=0.4, rough=0.5))
    for z in (60, 110, 150):
        k = 1 - z / h * 0.8
        box((0, 10 * k + 1.5, z), (3, 1.2, 7), wht, bevel=0.6)
        box((10 * k + 1.5, 0, z + 6), (1.2, 3, 7), wht, bevel=0.6)
    d = cyl((-8, 6, 128), 5, 1.6, wht, axis='y', bevel=0.4)
    box((0, 0, 92), (9, 9, 0.6), steel((90, 92, 90)), bevel=0.2)
    sphere((0, 0, h + 3), 2.0, mat((230, 60, 40), rough=0.3, emit=(255, 60, 40)))
    box((0, 0, 3), (14, 14, 3), concrete(), bevel=0.6)
    box((18, 10, 6), (5, 4, 6), mat((150, 154, 150), rough=0.6, metal=0.2), bevel=0.6)   # equipment cabinet


def dragon_teeth():
    c = concrete((156, 154, 144), dust=0.6)
    for row in range(2):
        for i in range(5):
            x = -48 + i * 24 + row * 12
            y = -8 + row * 16
            o = prism([(-7, -7), (7, -7), (7, 7), (-7, 7)], 0, 1, c, plane='xy', bevel=0.8)
            o.data.vertices.foreach_get
            for v in o.data.vertices:
                if v.co.z > 0.5:
                    v.co.x *= 0.3
                    v.co.y *= 0.3
                    v.co.z = 18
            o.location = bk.G(x, y, 0)
            o.rotation_euler = (0, 0, (i * 0.37) % 0.6)


def cable_spool_yard():
    wood = mat((136, 100, 64), rough=0.95, grime=0.3, scale=0.2)
    cable = mat((34, 34, 36), rough=0.6)
    for i, (x, y, r) in enumerate([(-34, -4, 16), (-4, 6, 12), (26, -6, 18)]):
        for dy in (-7, 7):
            cyl((x, y + dy, r), r, 1.6, wood, axis='y', bevel=0.4, verts=40)
        cyl((x, y, r), r * 0.72, 12.4, cable, axis='y', bevel=0.3, verts=36)
        cyl((x, y + 8, r), r * 0.18, 0.6, mat((40, 36, 30)), axis='y', bevel=0.1)
    # one spool on its side
    cyl((54, 10, 0), 10, 1.4, wood, bevel=0.3, verts=36)
    cyl((54, 10, 1.4), 7, 6, cable, bevel=0.3, verts=36)
    cyl((54, 10, 7.4), 10, 1.4, wood, bevel=0.3, verts=36)
    tube([(-20, 2, 10), (-14, 16, 0.6), (8, 20, 0.6), (20, 14, 0.6)], 0.9, cable)


def rail_cart():
    rail = steel((96, 92, 86))
    for y in (-9, 9):
        box((0, y, 1.2), (34, 0.9, 1.2), rail, bevel=0.2)
    for x in range(-30, 31, 10):
        box((x, 0, 0.5), (2.4, 14, 0.5), mat((92, 72, 52), rough=1, grime=0.3), bevel=0.2)
    for x in (-16, 16):
        for y in (-9, 9):
            cyl((x, y, 5.4), 4, 1.6, steel((50, 50, 48)), axis='y', bevel=0.3)
    box((0, 0, 9), (24, 11, 2), steel((60, 60, 56)), bevel=0.4)
    # tipper bin
    prism([(-22, 11), (-24, 24), (24, 24), (22, 11)], -11, 11, rusty((110, 74, 48)), bevel=0.8)
    for x in (-12, 0, 12):
        box((x, 11.4, 17.5), (0.8, 0.4, 6), rusty((90, 60, 40)), bevel=0)
    for i in range(6):
        box((-14 + i * 5.6, (i % 2) * 4 - 2, 25), (2.6, 2.4, 1.8), concrete((120, 120, 112)), bevel=0.8, rot=(0, 0, i))


def _po2_panel(x0, x1, y, m):
    box(((x0 + x1) / 2, y, 24), ((x1 - x0) / 2, 3, 24), m, bevel=0.6)
    w = x1 - x0
    for i in range(4):
        cx = x0 + w * (i + 0.5) / 4
        for z in (12, 36):
            mesh([(cx, y + 3.0, z - 8), (cx + 6, y + 3.0, z), (cx, y + 3.0, z + 8), (cx - 6, y + 3.0, z), (cx, y + 4.6, z)],
                 [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)], m)


def po2_fence():
    pm = concrete((158, 156, 146), dust=0.7)
    _po2_panel(-30, 30, 0, pm)
    post = concrete((132, 130, 122))
    wire = mat((150, 152, 150), rough=0.4, metal=0.6)
    for x in (-30, 30):
        box((x, 0, 26), (2.4, 3.4, 26), post, bevel=0.5)
        tube([(x, 0, 52), (x, 7, 60)], 0.4, steel((80, 80, 76)))
    for (yy, z) in ((2.5, 55), (5, 58.5)):
        pts = [(-31 + i * 2, yy + (0.4 if i % 2 else -0.4), z + (0.5 if i % 2 else 0)) for i in range(32)]
        tube(pts, 0.25, wire)


def po2_fence_v():
    pm = concrete((158, 156, 146), dust=0.7)
    box((0, 0, 24), (3, 30, 24), pm, bevel=0.6)
    box((0, 30, 26), (3.4, 2.4, 26), concrete((132, 130, 122)), bevel=0.5)
    wire = mat((150, 152, 150), rough=0.4, metal=0.6)
    for (xx, z) in ((-2, 55), (2, 58)):
        tube([(xx, -31 + i * 2, z + (0.5 if i % 2 else 0)) for i in range(32)], 0.25, wire)


def gate_pillar():
    brick = mat((132, 76, 56), rough=0.95, grime=0.2, dust=0.5, scale=0.2)
    box((0, 0, 34), (8, 8, 34), brick, bevel=0.5)
    for z in range(4, 68, 4):
        box((0, 8.05, z), (8, 0.1, 0.3), mat((170, 160, 140), rough=1), bevel=0)
    box((0, 0, 69.5), (10, 10, 1.6), concrete((140, 138, 128)), bevel=0.5)
    cyl((0, 0, 71), 1.4, 3, steel((60, 60, 58)), bevel=0.2)
    sphere((0, 0, 77), 3.8, mat((250, 236, 190), rough=0.2, emit=(255, 230, 170)))
    box((0, 8.4, 42), (6, 0.3, 6), mat((206, 170, 44), rough=0.5), bevel=0.2)
    box((0, 8.6, 42), (3.6, 0.2, 0.8), mat((30, 30, 30)), bevel=0)
    for z in (20, 50):
        box((8.6, 0, z), (0.6, 2, 1.4), steel((60, 60, 58)), bevel=0.2)          # gate hinges


def _sign_board(w, h, bg, draw):
    from PIL import ImageDraw as _D
    im = Image.new('RGB', (int(w * 4), int(h * 4)), bg)
    draw(_D.Draw(im), im.size)
    return im


def hospital_sign():
    post = steel((90, 92, 90))
    for x in (-34, 34):
        cyl((x, 0, 0), 1.2, 52, post, bevel=0.2)
    def dr(d, sz):
        W, H = sz
        cx, cy = W // 2, H // 2
        d.rectangle([cx - 26, cy - 8, cx + 26, cy + 8], fill=(176, 48, 42))
        d.rectangle([cx - 8, cy - 26, cx + 8, cy + 26], fill=(176, 48, 42))
        for x0 in (10, W - 120):
            for k in range(3):
                d.rectangle([x0 + k * 36, cy - 4, x0 + k * 36 + 26, cy + 4], fill=(60, 60, 60))
        d.rectangle([0, 0, W - 1, H - 1], outline=(120, 120, 114), width=3)
    im = _sign_board(80, 18, (226, 226, 218), dr)
    bk.panel([(-40, 1.3, 35), (40, 1.3, 35), (40, 1.3, 53), (-40, 1.3, 53)], bk.img_mat(im, name='hsign'))
    box((0, 0, 44), (40.4, 1.2, 9.2), mat((150, 150, 144), metal=0.4), bevel=0.3)


def quarantine_sign():
    cyl((0, 0, 0), 1.2, 44, steel((90, 92, 90)), bevel=0.2)
    def dr(d, sz):
        W, H = sz
        cx, cy = W // 2, H // 2 - 6
        for a0 in (math.pi / 2, math.pi / 2 + 2 * math.pi / 3, math.pi / 2 + 4 * math.pi / 3):
            ox, oy = cx + math.cos(a0) * 14, cy - math.sin(a0) * 14
            d.ellipse([ox - 16, oy - 16, ox + 16, oy + 16], outline=(30, 30, 30), width=6)
        d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(30, 30, 30))
        for k in range(4):
            d.rectangle([20 + k * 40, H - 26, 20 + k * 40 + 30, H - 16], fill=(30, 30, 30))
        d.rectangle([0, 0, W - 1, H - 1], outline=(40, 40, 36), width=4)
    im = _sign_board(44, 28, (214, 176, 44), dr)
    bk.panel([(-22, 1.3, 32), (22, 1.3, 32), (22, 1.3, 60), (-22, 1.3, 60)], bk.img_mat(im, name='qsign'))
    box((0, 0, 46), (22.4, 1.2, 14.4), mat((150, 150, 144), metal=0.4), bevel=0.3)


# --------------------------------------------------------------- registry --
KINDS = [
    ('lada_blue', lambda: lada((70, 98, 132), seed=11)),
    ('lada_red', lambda: lada((138, 52, 40), seed=12)),
    ('lada_white', lambda: lada((196, 192, 178), seed=13)),
    ('lada_burnt', lambda: lada(burnt=True, seed=14)),
    ('car_on_blocks', lambda: lada((112, 128, 96), on_blocks=True, seed=15)),
    ('uaz_ambulance', lambda: uaz_ambulance(seed=21)),
    ('uaz_burnt', lambda: uaz_ambulance(burnt=True, seed=22)),
    ('btr80', lambda: btr80()),
    ('t72_wreck', lambda: t72_wreck()),
    ('mi8_wreck', lambda: mi8_wreck()),
    ('kamaz_bowser', lambda: kamaz_bowser()),
    ('gen_trailer', lambda: gen_trailer()),
    ('cryo_semi', lambda: cryo_semi()),
    ('vent_head', vent_head),
    ('cooling_fans', cooling_fans),
    ('light_mast', light_mast),
    ('hazmat_drums', hazmat_drums),
    ('body_bags', body_bags),
    ('decon_tunnel', decon_tunnel),
    ('container_stack', container_stack),
    ('crater', crater),
    ('sandbag_wall', sandbag_wall),
    ('lattice_mast', lattice_mast),
    ('dragon_teeth', dragon_teeth),
    ('cable_spool_yard', cable_spool_yard),
    ('rail_cart', rail_cart),
    ('po2_fence', po2_fence),
    ('po2_fence_v', po2_fence_v),
    ('gate_pillar', gate_pillar),
    ('hospital_sign', hospital_sign),
    ('quarantine_sign', quarantine_sign),
]


RENDER_CELL = 240          # render field (world units); fitted into CELL afterwards


def bake(kind, fn, tmpdir, scale_fit=True):
    bk.reset()
    bk.camera(RENDER_CELL, 200, 120)
    fn()
    raw = bk.render(os.path.join(tmpdir, kind + '_raw.png'))
    return bk.fit_cell(bk.to_sprite(raw, RENDER_CELL), CELL * bk.HD)


def build_all(P, only=None, tmpdir=None, cached=None):
    """cached: directory of already baked <kind>.png sprites to reuse."""
    import tempfile
    tmpdir = tmpdir or tempfile.mkdtemp(prefix='ostatok_hd_')
    os.makedirs(tmpdir, exist_ok=True)
    out_dir = os.path.join(P, 'art', 'vehicles')
    os.makedirs(out_dir, exist_ok=True)
    W = CELL * bk.HD
    cols = 6
    rows = (len(KINDS) + cols - 1) // cols
    sheet_path = os.path.join(out_dir, 'vehicles_hd_v1.png')
    sheet = Image.open(sheet_path).convert('RGBA') if (only and os.path.exists(sheet_path)) else Image.new('RGBA', (cols * W, rows * W))
    if sheet.size != (cols * W, rows * W):
        s2 = Image.new('RGBA', (cols * W, rows * W)); s2.paste(sheet, (0, 0)); sheet = s2
    for i, (kind, fn) in enumerate(KINDS):
        if only and kind not in only:
            continue
        cp = os.path.join(cached, kind + '.png') if cached else None
        spr = Image.open(cp).convert('RGBA') if cp and os.path.exists(cp) else bake(kind, fn, tmpdir)
        x, y = (i % cols) * W, (i // cols) * W
        sheet.paste(Image.new('RGBA', (W, W)), (x, y))
        sheet.alpha_composite(spr, (x, y))
        spr.save(os.path.join(tmpdir, kind + '.png'))
        print('baked', kind)
    sheet.save(sheet_path)
    gd = ['extends RefCounted', '', '# generated by tools/blender/vehicles_hd.py — HD vehicle atlas (384 px cells, draw at 0.5).',
          'const ATLAS = "res://art/vehicles/vehicles_hd_v1.png"', 'const CELL = %d' % W, 'const KINDS = {']
    for i, (kind, fn) in enumerate(KINDS):
        gd.append('    "%s":%d,' % (kind, i))
    gd.append('}')
    with open(os.path.join(P, 'world', 'vehicle_hd_atlas.gd'), 'w') as f:
        f.write('\n'.join(gd) + '\n')


# ----------------------------------------------------------- world cars --
def niva(colour=(170, 172, 168), seed=31):
    """VAZ-2121 Niva: short boxy 3-door, high stance, spare wheel under the bonnet."""
    paint = mat(colour, rough=0.5, grime=0.10, dust=0.6)
    for x in (-20, 22):
        for y in (-14, 14):
            wheel(x, y, 0, 8.4, 5.0, side=1 if y > 0 else -1)
    z0 = 6.0
    prism([(-38, z0 + 2), (-39, z0 + 16), (36, z0 + 16), (39, z0 + 12), (39, z0 + 3), (36, z0 + 1), (-36, z0 + 1)], -15, 15, paint, bevel=1.6)
    for x in (-20, 22):
        for ys in (15.05, -15.05):
            cyl((x, ys, z0 + 1), 9.4, 0.4, mat((20, 20, 20), rough=1), axis='y', bevel=0)
    prism([(-37, z0 + 16), (-36, z0 + 31), (8, z0 + 31), (17, z0 + 16)], -13.6, 13.6, paint, bevel=1.4)
    g = glass()
    for ys in (13.7, -13.7):
        prism([(-34, z0 + 17.5), (-34, z0 + 29.5), (-14, z0 + 29.5), (-14, z0 + 17.5)], ys - 0.25, ys + 0.25, g, bevel=0.2)
        prism([(-12, z0 + 17.5), (-12, z0 + 29.5), (7, z0 + 29.5), (15, z0 + 17.5)], ys - 0.25, ys + 0.25, g, bevel=0.2)
    mesh([(9, -12, z0 + 30.2), (9, 12, z0 + 30.2), (16.4, 12, z0 + 16.4), (16.4, -12, z0 + 16.4)], [(0, 1, 2, 3)], g)
    mesh([(-37.2, -11, z0 + 30), (-37.2, 11, z0 + 30), (-38.2, 11, z0 + 18), (-38.2, -11, z0 + 18)], [(0, 1, 2, 3)], g)
    seam = mat((34, 36, 38), rough=0.9)
    for ys in (15.1, -15.1):
        box((-12.5, ys, z0 + 15), (0.25, 0.15, 14), seam, bevel=0)
        box((-8, ys + 0.2 * (1 if ys > 0 else -1), z0 + 13), (1.6, 0.25, 0.4), chrome(), bevel=0.1)
        box((0, ys, z0 + 6), (36, 0.3, 1.0), blackplastic(), bevel=0.2)             # rubbing strip
    box((39.3, 0, z0 + 9), (0.4, 9, 2.6), mat((30, 30, 30), rough=0.8), bevel=0.1)
    for ys in (-11, 11):
        cyl((39.5, ys, z0 + 10), 2.6, 0.8, lamp(), axis='x', bevel=0.3)
    for xs in (40.2, -39.6):
        box((xs, 0, z0 + 3.5), (1.0, 15.2, 1.4), mat((60, 62, 60), rough=0.6, metal=0.3), bevel=0.5)
    for ys in (-11, 11):
        box((-39.4, ys, z0 + 11), (0.5, 2.4, 2.4), mat((150, 40, 32), rough=0.3), bevel=0.3)
    rack = mat((44, 44, 42), rough=0.6, metal=0.4)
    for ys in (-11, 11):
        box((-14, ys, z0 + 32), (20, 0.6, 0.6), rack, bevel=0.2)
    box((-16, 0, z0 + 34), (8, 7, 2.4), mat((80, 90, 60), rough=0.9, grime=0.3), bevel=1.0)   # jerrycans under a tarp
    for ys in (-1, 1):
        box((12, ys * 15.4, z0 + 17), (1.0, 1.4, 1.0), blackplastic(), bevel=0.3)


def moskvich(colour=(170, 172, 168), seed=32):
    """AZLK-2141 hatchback: wedge nose, long sloping tailgate."""
    paint = mat(colour, rough=0.48, grime=0.10, dust=0.5)
    for x in (-27, 26):
        for y in (-14, 14):
            wheel(x, y, 0, 7.2, 4.4, side=1 if y > 0 else -1)
    z0 = 4.0
    prism([(-44, z0 + 3), (-45, z0 + 15), (40, z0 + 14), (46, z0 + 9), (46, z0 + 2), (42, z0 + 1), (-42, z0 + 1)], -15, 15, paint, bevel=1.8)
    for x in (-27, 26):
        for ys in (15.05, -15.05):
            cyl((x, ys, z0 + 1), 8.3, 0.4, mat((20, 20, 20), rough=1), axis='y', bevel=0)
    prism([(-44, z0 + 15), (-24, z0 + 27), (6, z0 + 27), (20, z0 + 14.5)], -13.4, 13.4, paint, bevel=1.4)
    g = glass()
    for ys in (13.5, -13.5):
        prism([(-37, z0 + 16.5), (-24, z0 + 25.6), (-8, z0 + 25.6), (-8, z0 + 16.3)], ys - 0.25, ys + 0.25, g, bevel=0.2)
        prism([(-6, z0 + 16.3), (-6, z0 + 25.6), (5, z0 + 25.6), (17, z0 + 16)], ys - 0.25, ys + 0.25, g, bevel=0.2)
    mesh([(7, -12, z0 + 26.2), (7, 12, z0 + 26.2), (18.6, 12, z0 + 15.6), (18.6, -12, z0 + 15.6)], [(0, 1, 2, 3)], g)
    mesh([(-25, -12, z0 + 26.4), (-25, 12, z0 + 26.4), (-41, 12, z0 + 17), (-41, -12, z0 + 17)], [(0, 1, 2, 3)], g)
    seam = mat((34, 36, 38), rough=0.9)
    for ys in (15.1, -15.1):
        box((-7, ys, z0 + 13), (0.25, 0.15, 12), seam, bevel=0)
        box((-11, ys + 0.2 * (1 if ys > 0 else -1), z0 + 12.5), (1.6, 0.25, 0.4), blackplastic(), bevel=0.1)
        box((0, ys, z0 + 8), (40, 0.3, 0.8), blackplastic(), bevel=0.1)
    box((46.3, 0, z0 + 7), (0.4, 13, 2.0), mat((36, 36, 36), rough=0.7), bevel=0.1)
    for ys in (-10, 10):
        box((46.2, ys, z0 + 9.5), (0.5, 4, 1.4), lamp(), bevel=0.2)
    for xs in (47, -45.6):
        box((xs, 0, z0 + 3.4), (1.0, 15.2, 1.6), blackplastic(), bevel=0.5)
    for ys in (-10, 10):
        box((-45.2, ys, z0 + 11), (0.5, 4, 1.8), mat((150, 40, 32), rough=0.3), bevel=0.2)
    for ys in (-1, 1):
        box((14, ys * 15.4, z0 + 16), (1.0, 1.4, 1.0), blackplastic(), bevel=0.3)


WORLD_CAR_MODELS = [
    ('zhiguli', lambda: lada((170, 172, 168), seed=41), 0.74),
    ('niva', lambda: niva(), 0.82),
    ('moskvich', lambda: moskvich(), 0.76),
]
WORLD_CAR_VIEWS = [('side', 0.0), ('front', math.pi / 2), ('rear', -math.pi / 2)]
WORLD_CAR_CELL = 128          # world units per cell (256 px)


def build_world_cars(P, cached=None, tmpdir=None):
    """art/vehicles/world_cars_hd_v1.png: rows = Zhiguli / Niva / Moskvich,
    columns = side / front (toward camera) / rear. Neutral light paint, tinted
    in game. Ground centre of the car at cell pixel (128, 160)."""
    import tempfile
    tmpdir = tmpdir or tempfile.mkdtemp(prefix='ostatok_cars_')
    W = WORLD_CAR_CELL * bk.HD
    sheet = Image.new('RGBA', (W * 3, W * 3))
    for r, (name, fn, k) in enumerate(WORLD_CAR_MODELS):
        for c, (view, yaw) in enumerate(WORLD_CAR_VIEWS):
            key = 'car_%s_%s' % (name, view)
            cp = os.path.join(cached, key + '.png') if cached else None
            if cp and os.path.exists(cp):
                spr = Image.open(cp).convert('RGBA')
            else:
                bk.reset()
                bk.camera(WORLD_CAR_CELL, 80, 64)
                fn()
                bk.transform_all(k, yaw)
                raw = bk.render(os.path.join(tmpdir, key + '_raw.png'))
                spr = bk.to_sprite(raw, WORLD_CAR_CELL)
                spr.save(os.path.join(tmpdir, key + '.png'))
                if cached:
                    spr.save(cp)
            sheet.alpha_composite(spr, (c * W, r * W))
            print('car', key, flush=True)
    sheet.save(os.path.join(P, 'art', 'vehicles', 'world_cars_hd_v1.png'))


if __name__ == '__main__':
    P = sys.argv[1] if len(sys.argv) > 1 else '.'
    only = sys.argv[2:] or None
    build_all(P, only)
    if not only:
        build_world_cars(P)
