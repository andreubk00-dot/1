"""OSTATOK 1.23-dev2 High Risk set pieces (hr_props_v1.png, 6 columns of 192x192 cells).

Large landmark pieces that give each High Risk site its own silhouette. Same
3/4 block renderer, light and outline as the settlement and POI set pieces.
Run: python3 tools/wa_hr_props.py <project_dir>
"""
import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw
from wa_core import Scene, V, grunge, fit_canvas, outline_img
import wa_vehicles as WV

CELL = 192
KINDS = ['heli_wreck', 'tank_wreck', 'vent_head', 'cooling_fans', 'light_mast', 'hazmat_drums',
         'body_bags', 'decon_tunnel', 'container_stack', 'generator_trailer', 'crater', 'sandbag_wall',
         'burnt_ambulance', 'fuel_bowser', 'lattice_mast', 'dragon_teeth', 'cable_spool_yard', 'rail_cart',
         'po2_fence', 'po2_fence_v', 'gate_pillar', 'hospital_sign', 'quarantine_sign', 'cryo_trailer']

OLIVE = (90, 102, 62)
OLIVE_D = (64, 72, 44)
STEEL = (120, 124, 124)
CONC = (150, 148, 138)


def sc(oy=176, ox=96):
    return Scene(CELL, CELL, (ox, oy))


def heli_wreck():
    """Mi-8 down on its side: broken tail boom, bent rotor blades, burnt cabin"""
    s = sc(160)
    body = (96, 104, 70)
    s.box(V(-10, 0, 14), (30, 13, 13), body, face_cols={'front': (88, 96, 64)})
    s.hexa([V(20, -12, 2), V(20, -12, 26), V(20, 12, 2), V(20, 12, 26), V(40, -8, 6), V(36, -8, 22), V(40, 8, 6), V(36, 8, 22)], body)
    s.box(V(28, 12.3, 16), (6, 0.3, 5), (50, 66, 76), edge=False, bias=2)            # cockpit glass
    s.box(V(-10, 13.3, 14), (10, 0.3, 7), (24, 22, 20), edge=False, bias=2)          # open door
    s.box(V(-60, 6, 10), (22, 3, 3), body, bias=1)                                   # tail boom (broken off)
    s.box(V(-84, 10, 6), (4, 2, 8), body, bias=1)
    s.box(V(-10, 0, 30), (8, 6, 3), (70, 76, 54), bias=2)                             # engine cowling
    for a, l in ((0.3, 60), (2.2, 44), (3.9, 52), (5.1, 30)):
        s.line([V(-10, 0, 33), V(-10 + math.cos(a) * l, math.sin(a) * l * 0.6, 33 - l * 0.25)], (40, 42, 40), 2, bias=4)
    img = s.render()
    a = np.array(img).astype(float)
    A = a[..., 3] > 0
    rng = np.random.default_rng(301)
    soot = rng.random(A.shape) < 0.3
    a[A & soot, :3] *= 0.5
    d = ImageDraw.Draw(img)
    img = Image.fromarray(a.astype(np.uint8))
    d = ImageDraw.Draw(img)
    d.text((70, 112), '22', fill=(200, 60, 40, 255))
    return grunge(img, 301, 0.18, rust=0.2, dirt_bottom=0.3, leaves=0.01)


def tank_wreck():
    s = sc(160)
    hull = (84, 90, 62)
    for x in range(-40, 44, 14):
        for y in (-18, 18):
            s.cyl(V(x, y, 0), 6, 4, (40, 40, 38), bias=-0.2)
    s.box(V(0, 0, 10), (50, 20, 6), hull)
    for y in (-20, 20):
        s.box(V(0, y, 6), (52, 3, 6), (44, 44, 40), bias=-0.1)
    s.hexa([V(-24, -14, 16), V(-20, -12, 28), V(-24, 14, 16), V(-20, 12, 28), V(24, -14, 16), V(20, -12, 28), V(24, 14, 16), V(20, 12, 28)], (78, 84, 58))
    s.hcyl(V(18, 6, 22), V(70, 18, 16), 2.4, (60, 62, 52), bias=3)                    # gun, drooping
    for i in range(6):
        s.box(V(-16 + i * 7, 14, 22), (3, 1.4, 2.5), (110, 96, 60), bias=3)          # reactive armour bricks
    img = s.render()
    a = np.array(img).astype(float)
    A = a[..., 3] > 0
    rng = np.random.default_rng(302)
    rust = rng.random(A.shape) < 0.16
    a[A & rust, :3] = a[A & rust, :3] * 0.4 + np.array((120, 64, 34)) * 0.6
    img = Image.fromarray(a.astype(np.uint8))
    return grunge(img, 302, 0.16, rust=0.25, dirt_bottom=0.35, leaves=0.01)


def vent_head():
    s = sc(166)
    s.box(V(0, 0, 4), (26, 22, 4), CONC)
    s.box(V(0, 0, 22), (18, 16, 14), (138, 136, 126))
    for z in range(12, 34, 4):
        s.line([V(-16, 16.3, z), V(16, 16.3, z)], (60, 62, 60), 1, bias=2)
    s.box(V(0, 0, 38), (22, 20, 2), (110, 110, 104))
    s.cyl(V(14, -10, 40), 4, 12, (120, 124, 124), bias=3)
    s.box(V(0, 16.5, 10), (6, 0.3, 4), (206, 164, 44), bias=3)
    return grunge(s.render(), 303, 0.14, rust=0.2, dirt_bottom=0.2, leaves=0.012)


def cooling_fans():
    s = sc(160)
    s.box(V(0, 0, 3), (54, 24, 3), CONC)
    for x in (-30, 0, 30):
        s.box(V(x, 0, 18), (13, 18, 12), (150, 152, 148))
        s.cyl(V(x, 0, 30), 11, 2, (70, 72, 70), bias=1)
        s.line([V(x - 9, 0, 32.5), V(x + 9, 0, 32.5)], (40, 40, 40), 1, bias=2)
        s.line([V(x, -9, 32.5), V(x, 9, 32.5)], (40, 40, 40), 1, bias=2)
    s.hcyl(V(-60, 20, 8), V(60, 20, 8), 3, (120, 80, 50), bias=3)
    return grunge(s.render(), 304, 0.14, rust=0.25, dirt_bottom=0.2)


def light_mast():
    s = Scene(CELL, CELL, (96, 188))
    s.box(V(0, 0, 3), (8, 8, 3), CONC)
    s.cyl(V(0, 0, 6), 2.4, 150, (130, 132, 128))
    s.box(V(0, 0, 158), (18, 3, 4), (80, 82, 80), bias=2)
    for x in (-12, -4, 4, 12):
        s.box(V(x, 3.5, 158), (3, 0.5, 3), (230, 226, 190), bias=3)
    s.line([V(0, 0, 60), V(0, 18, 0)], (90, 90, 90), 1, bias=1)
    return grunge(s.render(), 305, 0.1, rust=0.2, dirt_bottom=0.05)


def hazmat_drums():
    s = sc(150)
    pos = [(-24, -6), (-8, -8), (8, -6), (-16, 8), (0, 8), (22, 6)]
    for i, (x, y) in enumerate(pos):
        col = (206, 170, 44) if i % 3 else (60, 96, 70)
        s.cyl(V(x, y, 0), 7, 16, col, bands=((5, (60, 50, 20)), (11, (60, 50, 20))), bias=(y + 10) * 0.1)
    s.hcyl(V(30, 16, 6.5), V(48, 20, 6.5), 6.5, (206, 170, 44), bias=2)
    img = s.render()
    d = ImageDraw.Draw(img)
    for (x, y) in [(88, 136), (104, 140)]:
        d.ellipse([x - 2, y - 2, x + 2, y + 2], outline=(30, 30, 30, 255))
    a = np.array(img).astype(float)                                                 # leak puddle
    return grunge(Image.fromarray(a.astype(np.uint8)), 306, 0.14, rust=0.35, dirt_bottom=0.2)


def body_bags():
    s = sc(140)
    for i in range(5):
        x = -40 + i * 20
        s.box(V(x, 0, 3), (7, 18, 3), (40, 46, 40) if i % 2 else (190, 196, 190), bias=i * 0.01)
        s.line([V(x, -16, 6.2), V(x, 16, 6.2)], (90, 90, 90), 1, bias=1 + i * 0.01)
    s.box(V(56, 10, 2), (6, 4, 2), (200, 180, 60), bias=2)                       # lime sack
    return grunge(s.render(), 307, 0.1, dirt_bottom=0.1, leaves=0.01)


def decon_tunnel():
    s = sc(166)
    L = 70
    for i in range(8):
        x0 = -L + i * 2 * L / 8
        x1 = x0 + 2 * L / 8
        for k in range(10):
            a0, a1 = math.pi * k / 10, math.pi * (k + 1) / 10
            p0 = (math.cos(a0) * 18, math.sin(a0) * 22)
            p1 = (math.cos(a1) * 18, math.sin(a1) * 22)
            col = (200, 204, 196) if k < 5 else (180, 186, 178)
            s.poly([V(x0, p0[0], p0[1]), V(x1, p0[0], p0[1]), V(x1, p1[0], p1[1]), V(x0, p1[0], p1[1])], col, bias=0.01 * k)
        s.line([V(x0, -18, 0), V(x0, 0, 22), V(x0, 18, 0)], (120, 126, 120), 1, bias=1)
    s.box(V(L + 2, 0, 12), (2, 18, 12), (206, 164, 44), bias=2)
    img = s.render()
    a = np.array(img).astype(float)
    A = a[..., 3] > 0
    a[A, 3] = np.where(a[A, 0] > 170, 225, 255)
    return grunge(Image.fromarray(a.astype(np.uint8)), 308, 0.1, dirt_bottom=0.3)


def container_stack():
    s = sc(170)
    cols = [(128, 62, 44), (60, 90, 112), (78, 100, 70), (140, 120, 60)]
    for i, (x, z, c) in enumerate([(-30, 0, cols[0]), (30, 0, cols[1]), (0, 26, cols[2])]):
        s.box(V(x, 0, z + 13), (29, 12, 13), c)
        for k in range(-27, 28, 4):
            s.line([V(x + k, 12.2, z + 1), V(x + k, 12.2, z + 25)], tuple(int(v * 0.78) for v in c), 1, bias=1 + i)
    s.box(V(-30, 12.4, 12), (8, 0.3, 11), (30, 26, 22), edge=False, bias=4)          # one door open
    return grunge(s.render(), 309, 0.16, rust=0.35, dirt_bottom=0.25)


def generator_trailer():
    s = sc(150)
    for x in (-18, 18):
        s.cyl(V(x, 14, 0), 6, 3, (30, 30, 30), bias=-0.2)
    s.box(V(0, 0, 10), (34, 13, 4), (60, 62, 60))
    s.box(V(0, 0, 24), (30, 12, 10), OLIVE)
    for x in range(-26, 28, 4):
        s.line([V(x, 12.3, 16), V(x, 12.3, 32)], OLIVE_D, 1, bias=2)
    s.line([V(34, 0, 10), V(52, 0, 6)], (60, 60, 58), 2, bias=1)
    s.cyl(V(20, -6, 34), 2, 8, (60, 60, 58), bias=3)
    return grunge(s.render(), 310, 0.14, rust=0.2, dirt_bottom=0.25)


def crater():
    s = sc(120)
    rng = random.Random(311)
    rim = [V(math.cos(a) * 44 * rng.uniform(0.85, 1.1), math.sin(a) * 30 * rng.uniform(0.85, 1.1), 2) for a in np.linspace(0, 2 * math.pi, 18, endpoint=False)]
    s.poly(rim, (88, 76, 58))
    pit = [V(math.cos(a) * 30 * rng.uniform(0.85, 1.05), math.sin(a) * 20 * rng.uniform(0.85, 1.05), 1) for a in np.linspace(0, 2 * math.pi, 16, endpoint=False)]
    s.poly(pit, (40, 34, 28), bias=1)
    water = [V(math.cos(a) * 14, math.sin(a) * 8 + 3, 1) for a in np.linspace(0, 2 * math.pi, 12, endpoint=False)]
    s.poly(water, (52, 64, 72), bias=2)
    for _ in range(14):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(44, 60)
        s.box(V(math.cos(a) * r, math.sin(a) * r * 0.68, 2), (rng.uniform(1.5, 4), rng.uniform(1, 3), 2), (rng.choice([(110, 96, 74), (140, 138, 128), (70, 62, 50)])), bias=3)
    return grunge(outline_img(s.render(outline=False)), 311, 0.16, dirt_bottom=0.0, leaves=0.012)


def sandbag_wall():
    s = sc(150)
    for row in range(4):
        n = 11
        for i in range(n):
            x = -66 + i * 12 + (6 if row % 2 else 0)
            if x > 66:
                continue
            c = (150 - (i * 7 % 18), 132 - (i * 5 % 14), 92)
            s.box(V(x, 0, 2.6 + row * 5.2), (5.8, 6, 2.6), c, bias=row * 0.1)
    s.line([V(-40, 6, 22), V(-30, 30, 24)], (40, 40, 40), 2, bias=3)                 # MG barrel
    return grunge(s.render(), 312, 0.12, dirt_bottom=0.2, leaves=0.008)


def burnt_ambulance():
    s = sc(156)
    body = (130, 124, 110)
    for x in (-30, 26):
        for y in (-16, 16):
            s.box(V(x, y, 4), (6, 2, 4), (40, 34, 30), bias=-0.4)
    s.box(V(-6, 0, 24), (40, 17, 16), body)
    s.hexa([V(34, -17, 8), V(34, -17, 34), V(34, 17, 8), V(34, 17, 34), V(50, -16, 8), V(44, -15, 28), V(50, 16, 8), V(44, 15, 28)], body, face_cols={1: (30, 28, 26)})
    s.box(V(-6, 17.3, 20), (40, 0.3, 2), (150, 60, 50), edge=False, bias=2)
    s.box(V(-46.5, 0, 22), (0.4, 12, 12), (22, 20, 18), edge=False, bias=2)       # rear doors torn off
    img = s.render()
    a = np.array(img).astype(float)
    A = a[..., 3] > 0
    rng = np.random.default_rng(313)
    soot = rng.random(A.shape) < 0.45
    a[A & soot, :3] *= 0.45
    return grunge(Image.fromarray(a.astype(np.uint8)), 313, 0.2, rust=0.35, dirt_bottom=0.3, leaves=0.01)


def fuel_bowser():
    s = sc(156)
    for x in (-34, -18, 30):
        for y in (-15, 15):
            s.box(V(x, y, 5), (6, 2.5, 5), (30, 30, 30), bias=-0.4)
    s.box(V(-8, 0, 10), (44, 14, 3), (50, 52, 48))
    s.box(V(36, 0, 22), (12, 14, 11), OLIVE, face_cols={'side': (46, 58, 66)})
    s.hcyl(V(-46, 0, 24), V(20, 0, 24), 12, (110, 120, 80))
    s.box(V(-12, 0, 37), (6, 4, 2), (90, 96, 66), bias=2)
    return grunge(s.render(), 314, 0.14, rust=0.25, dirt_bottom=0.35)


def lattice_mast():
    s = Scene(CELL, CELL, (96, 190))
    h = 176
    for (x, y) in [(-10, -10), (10, -10), (10, 10), (-10, 10)]:
        s.line([V(x, y, 0), V(x * 0.2, y * 0.2, h)], (150, 60, 50), 1)
    for z in range(8, h - 8, 10):
        k = 1 - z / h * 0.8
        s.line([V(-10 * k, 10 * k, z), V(10 * k, 10 * k, z + 10)], (170, 170, 164), 1, bias=2)
        s.line([V(10 * k, 10 * k, z), V(-10 * k, 10 * k, z + 10)], (170, 170, 164), 1, bias=2)
    for z in (60, 110, 150):
        s.box(V(0, 4, z), (3, 1.5, 6), (210, 212, 206), bias=3)                      # panel antennas
    s.ball(V(0, 0, h + 4), 2, (230, 60, 40), bias=4)
    return grunge(s.render(), 315, 0.1, rust=0.2, dirt_bottom=0.05)


def dragon_teeth():
    s = sc(140)
    for row in range(2):
        for i in range(5):
            x = -48 + i * 24 + row * 12
            y = -8 + row * 16
            s.hexa([V(x - 7, y - 7, 0), V(x - 2, y - 2, 18), V(x - 7, y + 7, 0), V(x - 2, y + 2, 18),
                    V(x + 7, y - 7, 0), V(x + 2, y - 2, 18), V(x + 7, y + 7, 0), V(x + 2, y + 2, 18)], CONC, bias=row)
    return grunge(s.render(), 316, 0.16, dirt_bottom=0.25, leaves=0.01)


def cable_spool_yard():
    s = sc(150)
    for i, (x, y, r) in enumerate([(-34, -4, 16), (-4, 6, 12), (26, -6, 18), (50, 10, 10)]):
        s.hcyl(V(x, y - 8, r), V(x, y + 8, r), r, (130, 96, 60), bias=i * 0.1)
        s.hcyl(V(x, y - 6, r), V(x, y + 6, r), r * 0.7, (40, 40, 42), bias=i * 0.1 + 0.05)
    return grunge(s.render(), 317, 0.16, rust=0.1, dirt_bottom=0.2)


def rail_cart():
    s = sc(150)
    for x in (-16, 16):
        for y in (-10, 10):
            s.cyl(V(x, y, 0), 4, 2, (40, 40, 40), bias=-0.2)
    s.box(V(0, 0, 10), (24, 12, 6), (110, 80, 50))
    s.box(V(0, 0, 18), (22, 11, 3), (90, 92, 90))
    for i in range(3):
        s.box(V(-12 + i * 12, 0, 24), (5, 8, 3), (120, 120, 112), bias=1)
    return grunge(s.render(), 318, 0.16, rust=0.4, dirt_bottom=0.2)


def po2_fence():
    """Soviet PO-2 concrete fence panel with diamond relief and barbed wire (1x tile 3 m)"""
    s = sc(150)
    W = 60
    s.box(V(0, 0, 24), (W / 2, 3, 24), (156, 154, 144))
    for i in range(4):
        x = -W / 2 + 7.5 + i * 15
        for z in (12, 36):
            s.poly([V(x, 3.2, z - 8), V(x + 6, 3.2, z), V(x, 3.2, z + 8), V(x - 6, 3.2, z)], (140, 138, 128), bias=1)
    for x in (-W / 2, W / 2):
        s.box(V(x, 0, 26), (2.4, 3.4, 26), (130, 128, 120), bias=1)
        s.line([V(x, 0, 52), V(x, 6, 60)], (80, 80, 76), 1, bias=2)
    for z in (55, 59):
        for i in range(30):
            x = -W / 2 + i * 2
            s.px(V(x, 4 + (z - 52) * 0.6, z + (i % 2)), (150, 152, 150), bias=3)
    img = s.render()
    return grunge(img, 319, 0.16, rust=0.06, dirt_bottom=0.3, leaves=0.006)


def po2_fence_v():
    s = sc(150)
    for i in range(3):
        y = -30 + i * 20
        s.box(V(0, y + 10, 50), (3, 10, 2), (156, 154, 144), bias=i)
    s.box(V(0, 0, 26), (3.4, 2.4, 26), (130, 128, 120), bias=5)
    s.line([V(-2, -30, 58), V(-2, 30, 58)], (150, 152, 150), 1, bias=6)
    s.line([V(2, -30, 56), V(2, 30, 56)], (150, 152, 150), 1, bias=6)
    return grunge(s.render(), 320, 0.16, dirt_bottom=0.0)


def gate_pillar():
    s = sc(170)
    s.box(V(0, 0, 34), (8, 8, 34), (150, 148, 138))
    s.box(V(0, 0, 70), (10, 10, 3), (120, 118, 110))
    s.ball(V(0, 0, 76), 4, (250, 230, 170), bias=2)
    s.box(V(0, 8.3, 40), (6, 0.3, 6), (206, 170, 44), edge=False, bias=2)
    return grunge(s.render(), 321, 0.14, rust=0.1, dirt_bottom=0.25)


def hospital_sign():
    s = sc(170)
    for x in (-34, 34):
        s.line([V(x, 0, 0), V(x, 0, 40)], (90, 92, 90), 2)
    s.box(V(0, 0.5, 44), (40, 1, 8), (230, 230, 222), bias=1)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.rectangle([90, 118, 102, 122], fill=(176, 48, 42, 255))
    d.rectangle([94, 114, 98, 126], fill=(176, 48, 42, 255))
    for x in range(62, 86, 4):
        d.line([(x, 120), (x + 2, 120)], fill=(60, 60, 60, 255))
    for x in range(108, 132, 4):
        d.line([(x, 120), (x + 2, 120)], fill=(60, 60, 60, 255))
    return grunge(img, 322, 0.18, rust=0.2, dirt_bottom=0.1)


def quarantine_sign():
    s = sc(170)
    s.line([V(0, 0, 0), V(0, 0, 44)], (90, 92, 90), 2)
    s.box(V(0, 0.5, 46), (22, 1, 14), (214, 176, 44), bias=1)
    img = s.render()
    d = ImageDraw.Draw(img)
    cx, cy = 96, 170 - 46 - 1
    for a0 in (math.pi / 2, math.pi / 2 + 2 * math.pi / 3, math.pi / 2 + 4 * math.pi / 3):
        ox, oy = cx + math.cos(a0) * 4, cy - math.sin(a0) * 4
        d.ellipse([ox - 5, oy - 5, ox + 5, oy + 5], outline=(30, 30, 30, 255), width=2)
    return grunge(img, 323, 0.14, rust=0.15, dirt_bottom=0.1)


def cryo_trailer():
    s = sc(156)
    for x in (-30, -14, 30):
        for y in (-14, 14):
            s.box(V(x, y, 5), (6, 2.5, 5), (30, 30, 30), bias=-0.4)
    s.box(V(-4, 0, 10), (44, 13, 3), (50, 52, 48))
    s.hcyl(V(-44, 0, 26), V(36, 0, 26), 13, (210, 214, 216))
    s.box(V(40, 0, 20), (6, 12, 8), (120, 124, 124), bias=1)
    for x in range(-40, 36, 10):
        s.line([V(x, 13, 18), V(x, 13, 34)], (170, 174, 176), 1, bias=2)
    return grunge(s.render(), 324, 0.12, rust=0.12, dirt_bottom=0.3)


heli_wreck = lambda: WV.mi8_wreck(301)
tank_wreck = lambda: WV.t72_wreck(302)
burnt_ambulance = lambda: WV.uaz_ambulance(True, 313)
fuel_bowser = lambda: WV.kamaz_bowser(314)
generator_trailer = lambda: WV.gen_trailer(310)
cryo_trailer = lambda: WV.cryo_semi(324)

FNS = [heli_wreck, tank_wreck, vent_head, cooling_fans, light_mast, hazmat_drums,
       body_bags, decon_tunnel, container_stack, generator_trailer, crater, sandbag_wall,
       burnt_ambulance, fuel_bowser, lattice_mast, dragon_teeth, cable_spool_yard, rail_cart,
       po2_fence, po2_fence_v, gate_pillar, hospital_sign, quarantine_sign, cryo_trailer]
assert len(FNS) == len(KINDS)


def build_all(P):
    cols = 6
    rows = (len(FNS) + cols - 1) // cols
    out = Image.new('RGBA', (CELL * cols, CELL * rows))
    for i, fn in enumerate(FNS):
        out.alpha_composite(fit_canvas(fn(), CELL, CELL, 'bottom'), ((i % cols) * CELL, (i // cols) * CELL))
    os.makedirs(os.path.join(P, 'art', 'high_risk'), exist_ok=True)
    out.save(os.path.join(P, 'art', 'high_risk', 'hr_props_v1.png'))
    return out


if __name__ == '__main__':
    import sys
    build_all(sys.argv[1] if len(sys.argv) > 1 else '.')
    print('high risk props ok')
