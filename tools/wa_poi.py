"""OSTATOK 0.91 major-POI set pieces (poi_props_v1.png, 6 x 3 cells of 192x128).
Drawn at 2x density; the game shows them at scale 0.5 (bottom-centre anchored)."""
import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw
from wa_core import Scene, V, grunge, fit_canvas, LEAF_ORANGE, MOSS

KINDS = ['boxcar', 'tank_wagon', 'h_tank', 'silo', 'pipe_rack', 'watchtower',
         'guard_booth', 'boom_barrier', 'army_truck', 'forklift', 'pallets_tarp', 'pipe_stack',
         'cable_drum', 'transformer', 'hedgehogs', 'greenhouse', 'woodpile', 'rail_signal']


def boxcar():
    s = Scene(192, 128, (96, 100))
    for x in (-60, -44, 44, 60):
        s.cyl(V(x, 18, 0), 6, 3, (30, 30, 30))
    s.box(V(0, 0, 10), (80, 20, 3), (40, 40, 38))
    s.box(V(0, 0, 36), (78, 22, 23), (128, 58, 40))
    s.box(V(0, 0, 60), (79, 23, 1.6), (100, 50, 36))
    for x in range(-72, 76, 10):
        s.line([V(x, 22.2, 14), V(x, 22.2, 58)], (100, 44, 30), 1, bias=2)
    s.box(V(-8, 22.4, 34), (18, 0.3, 20), (116, 52, 36), bias=2)
    s.line([V(-8, 22.8, 16), V(-8, 22.8, 54)], (60, 30, 20), 1, bias=3)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.text((118, 50), '4721', fill=(210, 200, 180, 255))
    return grunge(img, 1, 0.16, rust=0.25, dirt_bottom=0.3, leaves=0.004)


def tank_wagon():
    s = Scene(192, 128, (96, 100))
    for x in (-60, -44, 44, 60):
        s.cyl(V(x, 18, 0), 6, 3, (30, 30, 30))
    s.box(V(0, 0, 10), (80, 18, 3), (40, 40, 38))
    s.hcyl(V(-74, 0, 32), V(74, 0, 32), 20, (46, 48, 50))
    s.cyl(V(0, 0, 50), 7, 6, (56, 58, 60))
    s.line([V(-70, 21, 14), V(70, 21, 14)], (70, 70, 70), 1, bias=3)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.rectangle([66, 64, 126, 70], fill=(170, 150, 60, 255))
    return grunge(img, 2, 0.12, rust=0.2, dirt_bottom=0.3)


def h_tank():
    s = Scene(192, 128, (96, 104))
    for x in (-40, 0, 40):
        s.box(V(x, 0, 6), (4, 16, 6), (130, 126, 116))
    s.hcyl(V(-62, 0, 28), V(62, 0, 28), 18, (176, 176, 168))
    s.box(V(20, 0, 48), (6, 6, 2), (120, 120, 116))
    s.line([V(-66, 14, 10), V(-66, 14, 44)], (80, 80, 76), 1, bias=3)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.rectangle([70, 58, 118, 63], fill=(190, 60, 40, 255))
    return grunge(img, 3, 0.14, rust=0.25, dirt_bottom=0.25)


def silo():
    s = Scene(192, 128, (96, 122))
    s.box(V(0, 0, 2), (22, 22, 2), (110, 108, 100))
    s.cyl(V(0, 0, 4), 18, 70, (150, 152, 148), bands=((20, (110, 112, 110)), (40, (110, 112, 110)), (60, (110, 112, 110))))
    s.cyl(V(0, 0, 74), 12, 6, (130, 132, 128))
    for z in range(8, 74, 5):
        s.line([V(15, 12, z), V(19, 10, z)], (70, 72, 72), 1, bias=4)
    s.line([V(15, 12, 4), V(15, 12, 76)], (70, 72, 72), 1, bias=4)
    s.line([V(19, 10, 4), V(19, 10, 76)], (70, 72, 72), 1, bias=4)
    return grunge(s.render(), 4, 0.14, rust=0.25, dirt_bottom=0.2)


def pipe_rack():
    s = Scene(192, 128, (96, 104))
    for x in (-66, -22, 22, 66):
        s.box(V(x, 0, 16), (2, 2, 16), (80, 82, 82))
        s.box(V(x, 0, 32), (3, 14, 1.2), (80, 82, 82))
    for (y, r, col) in [(-8, 4, (130, 132, 128)), (0, 5, (120, 70, 50)), (9, 3.5, (80, 110, 90))]:
        s.hcyl(V(-86, y, 38 + r), V(86, y, 38 + r), r, col)
    return grunge(s.render(), 5, 0.12, rust=0.35)


def watchtower():
    s = Scene(192, 128, (96, 124))
    for (x, y) in [(-12, -12), (12, -12), (-12, 12), (12, 12)]:
        s.line([V(x * 1.4, y * 1.4, 0), V(x, y, 60)], (90, 70, 50), 2)
    for z in (18, 38):
        s.line([V(-14, 13, z), V(14, 13, z)], (80, 62, 44), 1, bias=3)
        s.line([V(-14, 13, z), V(14, 13, z + 18)], (80, 62, 44), 1, bias=3)
    s.box(V(0, 0, 62), (16, 16, 2), (110, 86, 58))
    s.box(V(0, 0, 70), (15, 15, 6), (96, 76, 52), face_cols={'front': (30, 34, 34)})
    s.box(V(0, 0, 80), (18, 18, 1.6), (84, 90, 70))
    s.box(V(6, 16, 72), (3, 1, 1.5), (240, 210, 140), edge=False, bias=3)
    return grunge(s.render(), 6, 0.16, rust=0.1, leaves=0.005)


def guard_booth():
    s = Scene(192, 128, (96, 108))
    s.box(V(0, 0, 18), (18, 14, 18), (104, 112, 92))
    s.box(V(0, 14.2, 24), (12, 0.3, 7), (70, 92, 104), edge=False, bias=1)
    s.box(V(0, 14.4, 24), (12, 0.2, 0.4), (104, 112, 92), edge=False, bias=2)
    s.box(V(-10, 14.2, 12), (4, 0.3, 11), (70, 80, 62), edge=False, bias=1)
    s.box(V(0, 0, 37.5), (21, 17, 1.6), (84, 90, 70))
    s.box(V(10, 15, 34), (2, 1.5, 1), (240, 210, 140), edge=False, bias=2)
    for i, z in enumerate((2, 6)):
        s.box(V(-28, 8, z), (7, 5, 2), (134, 122, 88))
        s.box(V(28, 8, z), (7, 5, 2), (134, 122, 88))
    return grunge(s.render(), 7, 0.14, rust=0.08)


def boom_barrier():
    s = Scene(192, 128, (60, 100))
    s.box(V(0, 0, 10), (4, 4, 10), (130, 128, 120))
    s.box(V(0, 0, 21), (5, 5, 1.2), (60, 60, 58))
    ang = math.radians(62)          # raised arm (passable)
    for i in range(8):
        a0, a1 = i * 9, (i + 1) * 9
        col = (190, 40, 34) if i % 2 == 0 else (230, 224, 210)
        p0 = V(4 + math.cos(ang) * a0, 0, 20 + math.sin(ang) * a0)
        p1 = V(4 + math.cos(ang) * a1, 0, 20 + math.sin(ang) * a1)
        s.line([p0, p1], col, 3, bias=2)
    s.box(V(0, 5, 26), (2, 1, 2), (220, 60, 40), edge=False, bias=3)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.ellipse([100, 76, 116, 92], fill=(190, 40, 34, 255), outline=(30, 20, 20, 255))
    d.rectangle([103, 82, 113, 86], fill=(230, 224, 210, 255))
    d.line([(108, 92), (108, 104)], fill=(120, 120, 116, 255), width=2)
    return grunge(img, 8, 0.1, rust=0.1)


def army_truck():
    s = Scene(192, 128, (100, 104))
    olive, dark = (90, 102, 62), (60, 68, 42)
    for x in (-50, -32, 44):
        for y in (-16, 16):
            s.box(V(x, y, 6), (7, 3, 6), (26, 26, 26), bias=-0.4)
    s.box(V(-8, 0, 12), (62, 17, 3), (44, 46, 40))
    s.box(V(44, 0, 26), (14, 16, 12), olive, face_cols={'side': (46, 58, 66)})
    s.box(V(58, 0, 18), (4, 15, 5), dark)
    s.box(V(-22, 0, 34), (38, 18, 18), (104, 112, 76))
    s.box(V(-22, 0, 52.4), (38.6, 18.6, 0.6), (96, 104, 70), edge=False)
    for x in range(-56, 14, 12):
        s.line([V(x, 18.2, 17), V(x, 18.2, 51)], (80, 88, 58), 1, bias=2)
    s.box(V(61.5, -10, 22), (0.5, 3, 1.5), (220, 214, 170), edge=False, bias=2)
    s.box(V(61.5, 10, 22), (0.5, 3, 1.5), (220, 214, 170), edge=False, bias=2)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.polygon([(150, 70), (153, 76), (147, 76)], fill=(200, 60, 40, 255))
    return grunge(img, 9, 0.14, rust=0.12, dirt_bottom=0.35, leaves=0.004)


def forklift():
    s = Scene(192, 128, (96, 100))
    s.box(V(0, 0, 10), (16, 11, 6), (200, 160, 40))
    s.box(V(-10, 0, 14), (6, 10, 8), (60, 60, 58))
    for x in (-12, 12):
        for y in (-11, 11):
            s.box(V(x, y, 4), (4, 2, 4), (26, 26, 26), bias=-0.4)
    for (x, y) in [(-6, -9), (6, -9), (-6, 9), (6, 9)]:
        s.line([V(x, y, 16), V(x, y, 34)], (50, 50, 50), 1)
    s.box(V(0, 0, 35), (8, 10, 0.8), (70, 70, 68))
    s.box(V(20, 0, 20), (1.2, 9, 16), (60, 62, 60))
    s.box(V(30, -5, 3), (10, 1.5, 0.8), (70, 72, 70))
    s.box(V(30, 5, 3), (10, 1.5, 0.8), (70, 72, 70))
    return grunge(s.render(), 10, 0.14, rust=0.25, dirt_bottom=0.3)


def pallets_tarp():
    s = Scene(192, 128, (96, 104))
    for i, z in enumerate(range(0, 16, 3)):
        s.box(V(-26, 0, z + 1.5), (16, 14, 1.2), (150, 116, 72))
    s.box(V(14, 0, 14), (22, 16, 14), (78, 92, 60))
    s.box(V(14, 0, 28.6), (22.6, 16.6, 0.8), (70, 84, 54), edge=False)
    for x in (4, 24):
        s.line([V(x, 16.4, 1), V(x, 16.4, 28)], (50, 50, 44), 1, bias=2)
    return grunge(s.render(), 11, 0.16, dirt_bottom=0.2, leaves=0.006)


def pipe_stack():
    s = Scene(192, 128, (96, 100))
    rows = [(0, 5), (1, 4), (2, 3)]
    for row, n in rows:
        for i in range(n):
            y = (i - (n - 1) / 2) * 9
            z = 4.5 + row * 8
            s.hcyl(V(-50, y, z), V(50, y, z), 4.4, (126, 110, 96))
    s.box(V(-30, 0, 1), (2, 26, 1), (100, 72, 46)); s.box(V(30, 0, 1), (2, 26, 1), (100, 72, 46))
    return grunge(s.render(), 12, 0.14, rust=0.4)


def cable_drum():
    s = Scene(192, 128, (96, 104))
    s.hcyl(V(0, -12, 18), V(0, 12, 18), 18, (130, 96, 60))
    s.hcyl(V(0, -8, 18), V(0, 8, 18), 13, (40, 40, 42))
    return grunge(s.render(), 13, 0.16, rust=0.05)


def transformer():
    s = Scene(192, 128, (96, 104))
    s.box(V(0, 0, 2), (34, 22, 2), (120, 118, 110))
    s.box(V(0, 0, 18), (18, 12, 14), (96, 104, 92))
    for x in range(-16, 18, 4):
        s.line([V(x, 12.2, 6), V(x, 12.2, 30)], (74, 80, 70), 1, bias=2)
    for x in (-10, 0, 10):
        s.cyl(V(x, -4, 32), 2, 8, (190, 150, 110))
    for (x, y) in [(-34, 22), (34, 22), (-34, -22), (34, -22)]:
        s.line([V(x, y, 0), V(x, y, 22)], (80, 82, 80), 1)
    s.line([V(-34, 22, 22), V(34, 22, 22)], (80, 82, 80), 1, bias=3)
    for x in range(-34, 35, 3):
        s.line([V(x, 22, 0), V(x + 3, 22, 22)], (100, 102, 100), 1, bias=3)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.polygon([(96, 78), (100, 85), (92, 85)], fill=(220, 190, 40, 255))
    return grunge(img, 14, 0.12, rust=0.2)


def hedgehogs():
    s = Scene(192, 128, (96, 100))
    for (cx, cy) in [(-40, 0), (0, 6)]:
        for a in (0.0, 2.1, 4.2):
            dx, dy = math.cos(a) * 12, math.sin(a) * 12
            s.line([V(cx - dx, cy - dy, 0), V(cx + dx, cy + dy, 22)], (60, 60, 58), 3)
    s.box(V(44, 0, 8), (16, 8, 8), (150, 146, 136))
    s.box(V(44, 0, 16.6), (12, 5, 0.6), (130, 126, 116))
    img = s.render()
    return grunge(img, 15, 0.12, rust=0.35, dirt_bottom=0.2)


def greenhouse():
    s = Scene(192, 128, (96, 108))
    s.box(V(0, 0, 2), (40, 20, 2), (110, 84, 58))
    for x in range(-40, 41, 10):
        s.line([V(x, 20, 4), V(x, 20, 22), V(x, 0, 34), V(x, -20, 22)], (190, 190, 180), 1)
    s.poly([V(-40, 20, 22), V(40, 20, 22), V(40, 0, 34), V(-40, 0, 34)], (168, 190, 196))
    s.poly([V(-40, 20, 4), V(40, 20, 4), V(40, 20, 22), V(-40, 20, 22)], (150, 176, 180))
    img = s.render()
    a = np.array(img).astype(float)
    glass = (a[..., 2] > 170) & (a[..., 3] > 0)
    a[glass, 3] = 170
    rng = random.Random(16)
    for _ in range(40):
        x, y = rng.randint(58, 134), rng.randint(70, 96)
        if a[y, x, 3] > 0:
            a[y, x, :3] = rng.choice([(90, 120, 60), (120, 140, 60), (180, 80, 50)]); a[y, x, 3] = 255
    return grunge(Image.fromarray(a.astype(np.uint8)), 16, 0.1, leaves=0.01)


def woodpile():
    s = Scene(192, 128, (96, 104))
    for row in range(4):
        n = 7 - row
        for i in range(n):
            y = (i - (n - 1) / 2) * 5
            s.hcyl(V(-24, y, 3 + row * 5), V(24, y, 3 + row * 5), 2.6, (120, 84, 54))
    img = s.render()
    return grunge(img, 17, 0.14, leaves=0.01)


def rail_signal():
    s = Scene(192, 128, (96, 124))
    s.box(V(0, 0, 2), (5, 5, 2), (120, 118, 110))
    s.cyl(V(0, 0, 4), 1.6, 60, (80, 82, 82))
    s.box(V(0, 3, 64), (5, 2, 10), (30, 30, 32))
    img = s.render()
    d = ImageDraw.Draw(img)
    d.ellipse([93, 30, 99, 36], fill=(220, 50, 40, 255))
    d.ellipse([93, 40, 99, 46], fill=(60, 80, 60, 255))
    return grunge(img, 18, 0.1, rust=0.2)


def build_all(P):
    fns = [boxcar, tank_wagon, h_tank, silo, pipe_rack, watchtower, guard_booth, boom_barrier, army_truck,
           forklift, pallets_tarp, pipe_stack, cable_drum, transformer, hedgehogs, greenhouse, woodpile, rail_signal]
    out = Image.new('RGBA', (192 * 6, 128 * 3))
    for i, fn in enumerate(fns):
        out.alpha_composite(fit_canvas(fn(), 192, 128, 'bottom'), ((i % 6) * 192, (i // 6) * 128))
    out.save(os.path.join(P, 'poi_props_v1.png'))
    return out
