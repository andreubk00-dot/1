"""OSTATOK vehicles: detailed wrecks and service vehicles for set-piece atlases.

Shared by wa_settlement (towns) and wa_hr_props (High Risk sites). Built with the
wa_core 3/4 block renderer, then weathered with coherent patches (rust along sills
and wheel arches, soot plumes above burnt openings, dust on the lower body)
instead of per-pixel noise, so vehicles read as painted metal, not speckle.
"""
import math
import random
import numpy as np
from PIL import Image, ImageDraw
from wa_core import Scene, V, fbm, clamp8, outline_img

CELL = 192
TYRE = (34, 34, 34)
HUB = (96, 98, 96)
GLASS = (52, 70, 80)
GLASS_HI = (110, 136, 146)
DARK = (26, 24, 22)


def sc(oy=166, ox=96):
    return Scene(CELL, CELL, (ox, oy))


def dk(c, k=0.72):
    return tuple(int(v * k) for v in c)


def wheel(s, x, y, r=7.0, w=3.0, flat=False, bias=-0.3):
    """tyre seen from the side: dark disc, tread rim, steel wheel and hub cap."""
    z = r * (0.8 if flat else 1.0)
    yy = y + w if y >= 0 else y - w * 0.2
    n = 18
    tyre = [V(x + math.cos(t) * r, yy, z + math.sin(t) * r) for t in np.linspace(0, 2 * math.pi, n, endpoint=False)]
    s.poly(tyre, TYRE, bias=bias)
    rim = [V(x + math.cos(t) * r * 0.58, yy + 0.2, z + math.sin(t) * r * 0.58) for t in np.linspace(0, 2 * math.pi, n, endpoint=False)]
    s.poly(rim, HUB, bias=bias + 0.05)
    hub = [V(x + math.cos(t) * r * 0.22, yy + 0.3, z + math.sin(t) * r * 0.22) for t in np.linspace(0, 2 * math.pi, 10, endpoint=False)]
    s.poly(hub, (140, 142, 138), bias=bias + 0.1)
    s.line([V(x - r * 0.8, yy + 0.25, z + r * 0.55), V(x + r * 0.8, yy + 0.25, z + r * 0.55)], (52, 52, 50), 1, bias=bias + 0.06)


def weather(img, seed, rust=0.25, soot=0.0, dust=0.35, burnt=False):
    """restrained weathering: faded paint, a thin rust line along sills and
    arches, dust on the lower body; burnt shells get an even scorched finish."""
    a = np.array(img).astype(float)
    h, w = a.shape[:2]
    A = a[..., 3] > 0
    if not A.any():
        return img
    ys = np.nonzero(A)[0]
    y0, y1 = ys.min(), ys.max()
    t = np.clip((np.arange(h)[:, None] - y0) / max(1, (y1 - y0)), 0, 1) * np.ones((1, w))
    n = fbm(w, h, 18, seed, 3, wrap=False)
    lum = a[..., :3].mean(axis=2)
    paint = A & (lum > 40)                     # leave outlines, tyres and glass alone
    a[..., :3] *= np.where(paint, 0.95 + 0.1 * n, 1.0)[..., None]
    if burnt:
        base = np.array((92, 72, 58), float)
        k = (0.78 + 0.3 * n)[..., None] * (1.0 - 0.35 * (1 - t[..., None]))   # darker towards the roof
        a[..., :3] = np.where(paint[..., None], base * k + a[..., :3] * 0.15, a[..., :3])
    if rust > 0:
        band = np.clip((t - (0.80 - rust * 0.25)) / 0.08, 0, 1) * (n > 0.45)
        m = band * paint
        a[..., :3] = a[..., :3] * (1 - 0.55 * m[..., None]) + np.array((116, 64, 36), float) * (0.55 * m[..., None])
    if dust > 0:
        g = (dust * 0.45 * t ** 3)[..., None] * paint[..., None]
        a[..., :3] = a[..., :3] * (1 - g) + np.array((104, 92, 72)) * g
    if soot > 0:
        g = (soot * 0.5 * (1 - t) ** 2 * (n > 0.5))[..., None] * paint[..., None]
        a[..., :3] *= (1 - g)
    a[..., 3] = np.where(A, a[..., 3], 0)
    return Image.fromarray(clamp8(a), 'RGBA')


# ------------------------------------------------------------------ vehicles --
def lada(colour=(96, 110, 120), burnt=False, seed=1):
    """VAZ-2105 style sedan, 3/4 view from the south."""
    s = sc(150)
    body = colour
    for x in (-26, 26):
        for y in (-13, 13):
            wheel(s, x, y, 6.5, 2.5, flat=burnt)
    s.box(V(0, 0, 11), (44, 15, 5), body, face_cols={'front': dk(body, 0.92)})            # lower body
    s.box(V(0, 0, 4.5), (45, 15.4, 1.6), (40, 40, 38), bias=0.2)                        # sill / rocker
    s.box(V(-4, 0, 20), (22, 13.5, 4.5), dk(body, 0.95))                                # cabin
    s.box(V(-4, 0, 24.8), (20, 12.5, 0.4), body, bias=0.3)                               # roof skin
    if burnt:
        s.box(V(-4, 13.6, 20), (20, 0.3, 3.6), DARK, edge=False, bias=1)
    else:
        s.box(V(-4, 13.6, 20), (20, 0.3, 3.6), GLASS, edge=False, bias=1)
        s.box(V(-14, 13.8, 21), (6, 0.2, 2.0), GLASS_HI, edge=False, bias=1.1)
    s.box(V(-4, 13.7, 20), (0.7, 0.3, 3.8), dk(body), edge=False, bias=1.2)              # B-pillar
    for x in (-18, 10):
        s.line([V(x, 15.3, 7), V(x, 15.3, 15)], dk(body, 0.6), 1, bias=1.3)              # door seams
    s.box(V(44.4, 0, 11), (0.6, 13, 3), (60, 60, 58), bias=1)                            # grille
    for y in (-10, 10):
        s.box(V(44.6, y, 12), (0.4, 2.5, 1.5), (200, 196, 170) if not burnt else DARK, bias=1.1)
    s.box(V(46, 0, 8), (1, 15, 1), (90, 92, 90), bias=1.2)                               # bumper
    s.box(V(-46, 0, 8), (1, 15, 1), (90, 92, 90), bias=1.2)
    s.box(V(10, 15.2, 18), (1.2, 1.2, 1), dk(body, 0.6), bias=1.4)                       # mirror
    img = s.render()
    return weather(img, seed, rust=0.45 if burnt else 0.28, dust=0.4, burnt=burnt)


def uaz_ambulance(burnt=False, seed=2):
    """UAZ-452 'bukhanka' ambulance."""
    s = sc(156)
    body = (206, 206, 196)
    for x in (-26, 24):
        for y in (-15, 15):
            wheel(s, x, y, 7, 3, flat=burnt)
    s.box(V(0, 0, 22), (40, 16, 14), body, face_cols={'front': (196, 196, 186)})
    s.box(V(0, 0, 36.6), (39, 15, 0.6), (190, 190, 182), bias=0.2)
    s.box(V(0, 0, 7), (40.6, 16.4, 1.6), (54, 56, 52), bias=0.1)
    # rounded nose: chamfer box at the front
    s.hexa([V(40, -16, 8), V(40, -16, 36), V(40, 16, 8), V(40, 16, 36),
            V(48, -15, 8), V(44, -14, 32), V(48, 15, 8), V(44, 14, 32)], body, face_cols={1: (186, 186, 176)})
    glass = DARK if burnt else GLASS
    s.box(V(44.3, 0, 26), (0.3, 12, 4), glass, edge=False, bias=1)                       # windscreen
    s.box(V(30, 16.3, 27), (6, 0.3, 4), glass, edge=False, bias=1)                       # cab door window
    s.box(V(-10, 16.3, 27), (12, 0.3, 4), glass, edge=False, bias=1)                     # saloon windows
    s.box(V(-10, 16.4, 27), (0.5, 0.2, 4), body, edge=False, bias=1.1)
    s.box(V(0, 16.4, 18), (40, 0.2, 1.6), (176, 48, 42), edge=False, bias=1.2)           # red stripe
    s.box(V(-28, 16.4, 26), (3.5, 0.2, 1.2), (176, 48, 42), edge=False, bias=1.3)        # cross
    s.box(V(-28, 16.4, 26), (1.2, 0.2, 3.5), (176, 48, 42), edge=False, bias=1.3)
    for x in (22, -2):
        s.line([V(x, 16.5, 9), V(x, 16.5, 34)], (150, 150, 144), 1, bias=1.4)              # door seams
    s.box(V(30, 0, 37.5), (3, 6, 1), (60, 110, 200) if not burnt else DARK, bias=1)      # beacon
    s.box(V(48.6, 0, 12), (0.4, 10, 3), (60, 62, 60), bias=1.2)                          # grille
    s.box(V(50, 0, 9), (1, 15, 1), (80, 82, 80), bias=1.3)
    img = s.render()
    return weather(img, seed, rust=0.4 if burnt else 0.18, dust=0.45, burnt=burnt)


def btr80(seed=3):
    s = sc(166)
    olive = (88, 100, 62)
    for x in (-36, -12, 12, 36):
        wheel(s, x, -19, 8.5, 3.5, bias=-0.5)
        wheel(s, x, 19, 8.5, 3.5, bias=-0.5)
    s.hexa([V(-56, -18, 9), V(-58, -18, 24), V(-56, 18, 9), V(-58, 18, 24),
            V(56, -16, 9), V(48, -16, 26), V(56, 16, 9), V(48, 16, 26)], olive, face_cols={3: dk(olive, 0.92)})
    s.hexa([V(-58, -21, 24), V(-56, -21, 31), V(-58, 21, 24), V(-56, 21, 31),
            V(48, -21, 26), V(42, -19, 31), V(48, 21, 26), V(42, 19, 31)], (96, 108, 68), face_cols={5: (100, 112, 72)})
    for x in (-40, -20, 0, 20):
        s.box(V(x, 21.2, 27), (5, 0.4, 2.2), (70, 80, 50), bias=1)                       # firing ports / hatches
    s.cyl(V(10, 0, 31), 10, 7, (82, 94, 58), bias=1)                                     # turret
    s.hcyl(V(16, 2, 35), V(54, 2, 36), 1.6, (50, 54, 40), bias=2)                        # KPVT barrel
    s.hcyl(V(16, -3, 35), V(32, -3, 35.5), 1, (40, 42, 34), bias=2)
    for x in (-50, 30):
        s.box(V(x, 0, 31.6), (4, 6, 0.6), (70, 80, 50), bias=2)                          # top hatches
    s.box(V(46, 14, 22), (1, 3, 2), (200, 196, 170), bias=2)
    s.box(V(46, -14, 22), (1, 3, 2), (200, 196, 170), bias=2)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.text((70, 128), '217', fill=(214, 208, 180, 255))
    return weather(img, seed, rust=0.22, dust=0.5)


def t72_wreck(seed=4):
    s = sc(160)
    hull = (84, 92, 62)
    for x in range(-42, 46, 12):
        wheel(s, x, 20, 5.5, 2.0, bias=0.15)
    for y in (-20, 20):
        s.box(V(0, y, 3), (50, 3.5, 2), (38, 38, 36), bias=-0.1)                         # track run
        s.box(V(0, y, 13), (50, 4, 1), (40, 40, 38), bias=0.1)
    s.box(V(0, 0, 12), (52, 17, 6), hull)
    s.hexa([V(52, -17, 6), V(52, -17, 18), V(52, 17, 6), V(52, 17, 18), V(60, -15, 10), V(56, -15, 18), V(60, 15, 10), V(56, 15, 18)], hull)
    for y in (-22, 22):
        s.box(V(0, y, 16), (48, 2, 1), dk(hull, 0.85), bias=0.2)                         # side skirts
    # turret blown sideways
    s.hexa([V(-26, -12, 18), V(-20, -10, 30), V(-26, 14, 18), V(-20, 12, 30),
            V(14, -14, 18), V(8, -10, 30), V(14, 16, 18), V(8, 12, 30)], (80, 88, 58))
    for i in range(7):
        s.box(V(-20 + i * 6, 13, 26), (2.6, 1.4, 2.4), (104, 98, 64), bias=2)           # ERA bricks
    s.hcyl(V(10, 4, 24), V(64, 26, 12), 2.2, (60, 62, 52), bias=3)                       # barrel drooped
    s.cyl(V(-14, -4, 30), 4, 3, (70, 76, 52), bias=2)
    img = s.render()
    return weather(img, seed, rust=0.4, soot=0.45, dust=0.5)


def mi8_wreck(seed=5):
    s = sc(160)
    body = (96, 104, 70)
    s.box(V(-8, 0, 15), (32, 13, 14), body, face_cols={'front': dk(body, 0.95)})
    s.hexa([V(24, -13, 2), V(24, -13, 28), V(24, 13, 2), V(24, 13, 28),
            V(44, -9, 6), V(40, -9, 22), V(44, 9, 6), V(40, 9, 22)], body)
    s.box(V(36, 11.5, 18), (5, 0.3, 4), GLASS, edge=False, bias=2)
    s.box(V(40, 8.5, 12), (3, 0.3, 3), GLASS, edge=False, bias=2)
    for x in (-28, -16, -4, 8):
        s.box(V(x, 13.2, 20), (3, 0.3, 3), DARK if x != -4 else GLASS, edge=False, bias=2)  # round-ish windows
    s.box(V(-20, 13.3, 12), (8, 0.3, 9), DARK, edge=False, bias=2)                       # sliding door open
    s.box(V(-8, 0, 32), (12, 7, 3), (78, 84, 58), bias=2)                                # engine cowlings
    s.cyl(V(-4, 0, 35), 3, 3, (60, 62, 52), bias=2.5)
    s.box(V(-58, 4, 12), (20, 3, 3), body, bias=1)                                       # tail boom, cracked off
    s.box(V(-82, 8, 8), (5, 2, 9), body, bias=1)
    s.box(V(-82, 10.5, 14), (1, 0.4, 4), (60, 62, 52), bias=1.5)
    for a, l in ((0.35, 64), (2.2, 46), (3.8, 54), (5.0, 34), (1.2, 20)):
        s.line([V(-4, 0, 38), V(-4 + math.cos(a) * l, math.sin(a) * l * 0.6, 38 - l * 0.28)], (40, 42, 40), 2, bias=4)
    s.box(V(40, 0, 1), (6, 10, 1), (40, 40, 38), bias=-0.5)                              # crushed gear
    img = s.render()
    d = ImageDraw.Draw(img)
    d.text((86, 112), '22', fill=(206, 196, 150, 255))
    return weather(img, seed, rust=0.25, soot=0.5, dust=0.4)


def kamaz_bowser(seed=6):
    s = sc(156)
    cab = (88, 100, 62)
    for x in (-34, -18, 34):
        for y in (-15, 15):
            wheel(s, x, y, 7, 3)
    s.box(V(-6, 0, 12), (46, 12, 2.5), (48, 50, 46))
    s.box(V(38, 0, 22), (11, 15, 11), cab, face_cols={'side': (80, 92, 58)})
    s.box(V(49.3, 0, 26), (0.3, 12, 4), GLASS, edge=False, bias=1)
    s.box(V(38, 15.3, 27), (6, 0.3, 4), GLASS, edge=False, bias=1)
    s.box(V(50, 0, 14), (1, 13, 3), (70, 72, 70), bias=1)
    s.hcyl(V(-48, 0, 26), V(24, 0, 26), 12, (112, 122, 82))
    for x in (-36, -12, 12):
        s.line([V(x, 12.4, 16), V(x, 12.4, 36)], (84, 92, 62), 2, bias=1)                # tank bands
    s.box(V(-12, 0, 38.6), (5, 3, 1.2), (80, 88, 60), bias=2)                           # filler hatch
    s.box(V(-46, 12, 14), (3, 2, 4), (60, 62, 60), bias=2)                               # hose box
    img = s.render()
    return weather(img, seed, rust=0.28, dust=0.45)


def gen_trailer(seed=7):
    s = sc(150)
    for x in (-16, 16):
        wheel(s, x, 13, 6, 2.5)
    s.box(V(0, 0, 10), (34, 12, 3), (56, 58, 56))
    s.box(V(0, 0, 23), (30, 11, 10), (90, 102, 64))
    for x in range(-26, 28, 4):
        s.line([V(x, 11.3, 16), V(x, 11.3, 31)], (70, 80, 50), 1, bias=1)                # louvres
    s.box(V(0, 0, 33.6), (30.4, 11.4, 0.6), (80, 92, 58), bias=1)
    s.box(V(-18, 11.4, 22), (5, 0.3, 4), (60, 62, 60), edge=False, bias=2)               # control panel
    s.box(V(-18, 11.6, 23), (1.2, 0.2, 1.2), (220, 70, 50), edge=False, bias=2.2)
    s.line([V(34, 0, 10), V(52, 0, 5)], (60, 60, 58), 2, bias=1)
    s.cyl(V(20, -5, 34), 2, 8, (60, 60, 58), bias=3)                                     # exhaust
    img = s.render()
    return weather(img, seed, rust=0.22, dust=0.4)


def cryo_semi(seed=8):
    s = sc(156)
    for x in (-34, -20, 30):
        for y in (-14, 14):
            wheel(s, x, y, 6.5, 2.5)
    s.box(V(-4, 0, 11), (44, 12, 2.5), (50, 52, 48))
    s.hcyl(V(-46, 0, 26), V(34, 0, 26), 13, (214, 218, 220))
    for x in (-40, 28):
        s.line([V(x, 13.4, 15), V(x, 13.4, 37)], (170, 174, 176), 2, bias=1)
    s.box(V(40, 0, 21), (6, 12, 9), (120, 124, 124), bias=1)                             # valve cabinet
    for x in (36, 40, 44):
        s.line([V(x, 12.4, 14), V(x, 12.4, 28)], (90, 94, 94), 1, bias=1.5)
    s.box(V(-4, 13.6, 30), (16, 0.2, 2), (60, 120, 170), edge=False, bias=2)            # O2 band
    img = s.render()
    return weather(img, seed, rust=0.14, dust=0.4)


def car_on_blocks(seed=9):
    """stripped Zhiguli on wooden blocks, bonnet up, one wheel on the ground."""
    s = sc(156)
    body = (110, 120, 128)
    for (x, y) in [(-30, -13), (30, -13), (-30, 13), (30, 13)]:
        s.box(V(x, y, 4), (5, 4, 4), (112, 86, 56), bias=-0.4)
        s.box(V(x, y, 8.6), (3, 3, 0.6), (96, 72, 48), bias=-0.3)
    s.box(V(0, 0, 15), (44, 15, 5), body, face_cols={'front': dk(body, 0.92)})
    s.box(V(0, 0, 9), (45, 15.4, 1.4), (40, 40, 38), bias=0.2)
    s.box(V(-4, 0, 24), (22, 13.5, 4.5), dk(body, 0.95))
    s.box(V(-4, 13.6, 24), (20, 0.3, 3.6), GLASS, edge=False, bias=1)
    s.box(V(-4, 13.7, 24), (0.7, 0.3, 3.8), dk(body), edge=False, bias=1.2)
    for x in (-30, 30):
        s.box(V(x, 15.3, 12), (6, 0.3, 4), DARK, edge=False, bias=1.3)                   # empty wheel arches
    s.poly([V(26, -14, 20), V(26, 14, 20), V(38, 14, 40), V(38, -14, 40)], dk(body, 0.9), bias=3)   # bonnet up
    s.box(V(36, 0, 19), (8, 11, 2), (56, 54, 50), bias=1.5)                              # engine bay
    s.box(V(34, 0, 22), (4, 6, 3), (90, 86, 80), bias=1.6)
    wheel(s, 62, 14, 7, 2.5, bias=2)
    s.box(V(-58, 14, 4), (6, 4, 4), (176, 48, 42), bias=2)                               # red toolbox
    img = s.render()
    return weather(img, seed, rust=0.35, dust=0.4)


def outline(img):
    return outline_img(img)
