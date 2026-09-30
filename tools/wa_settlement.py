"""OSTATOK 1.22-dev4 faction settlement set pieces.

settlement_props_v1.png  : 6 x 6 cells of 192x192, drawn at 2x density, shown at
                           0.5..0.75 in game (bottom-centre anchored, like poi_props_v1).
settlement_walls_v1.png  : per-faction perimeter tiles. Row f (faction order below):
                           horizontal tile 128x72 at x=0, vertical tile 40x128 at x=128,
                           gate post 64x112 at x=168. Shown at 0.5 in game.

Every faction keeps the shared 3/4 camera/light language of wa_core, but gets its own
material palette:
  perron    - salvaged wood, faded red/ochre cloth, whitewash, railway leftovers
  rubezh    - olive drab, sandbags, concrete, barbed wire, one red-star-free tricolour flag
  mechanics - galvanised/corrugated metal, rust, hazard yellow, cables and lamps
  lazaret   - whitewash, pale green-grey, red crosses, plastic sheeting
"""
import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw
from wa_core import Scene, V, grunge, fit_canvas, outline_img, LEAF_ORANGE

CELL = 192
FACTIONS = ['perron', 'rubezh', 'mechanics', 'lazaret']

KINDS = [
    # perron (civic / railway community)
    'market_stall', 'market_stall_b', 'water_tower', 'garden_beds', 'laundry_line', 'field_kitchen',
    'platform_canopy', 'radio_mast', 'water_point', 'chicken_coop', 'long_table', 'fire_barrel',
    # rubezh (garrison)
    'sandbag_nest', 'hesco_row', 'army_tent', 'flag_pole', 'searchlight_tower', 'ammo_bunker',
    'btr', 'jersey_blocks',
    # mechanics (artel)
    'jib_crane', 'scrap_heap', 'wind_turbine', 'fuel_station', 'car_on_blocks', 'furnace',
    'solar_rig', 'container_shop',
    # lazaret (medical)
    'medical_tent', 'decon_frame', 'triage_canopy', 'herb_beds', 'incinerator', 'oxygen_rack',
    'ambulance', 'wash_station',
    # survival clutter shared by all towns
    'shanty', 'tarp_shelter', 'scrap_barricade', 'tire_wall', 'burnt_car', 'graves',
    'warning_sign', 'rubble_pile', 'dead_tree', 'bonfire', 'rain_tank', 'junk_pile',
    # street life and utilities
    'pole_wood', 'pole_concrete', 'bus_stop', 'kiosk', 'swing_set', 'dog_kennel',
    'wheelbarrow', 'bicycle', 'poster_board', 'oil_drums', 'firewood_rack', 'cart',
]
# wire attach height (art px above the anchor, before the in-game scale) for the poles
POLE_TOP = {'pole_wood': 132, 'pole_concrete': 140}

WOOD = (132, 98, 64)
WOOD_D = (98, 72, 48)
PLANK = (150, 118, 78)
RED_CLOTH = (150, 64, 46)
OCHRE = (184, 146, 72)
CREAM = (206, 196, 168)
OLIVE = (92, 102, 64)
OLIVE_D = (66, 74, 46)
SAND = (156, 138, 98)
CONCRETE = (150, 148, 138)
STEEL = (120, 124, 124)
STEEL_D = (80, 84, 86)
HAZARD = (206, 164, 44)
WHITE = (200, 204, 196)
MINT = (150, 170, 158)
CROSS = (176, 48, 42)


def sc(oy=176):
    return Scene(CELL, CELL, (96, oy))


def _stripes(s, x0, x1, y, z0, z1, cols, n):
    """sloped striped awning surface from (y,z0) front edge to (y-?,z1)."""
    w = (x1 - x0) / n
    for i in range(n):
        xa, xb = x0 + i * w, x0 + (i + 1) * w
        s.poly([V(xa, y, z0), V(xb, y, z0), V(xb, y - 22, z1), V(xa, y - 22, z1)], cols[i % len(cols)], bias=6)


# ---------------------------------------------------------------- perron --
def market_stall():
    s = sc()
    # counter with produce crates
    s.box(V(0, 8, 10), (40, 10, 10), WOOD, face_cols={'front': PLANK})
    for x in range(-36, 40, 12):
        s.line([V(x, 18.2, 1), V(x, 18.2, 19)], WOOD_D, 1, bias=2)
    for i, (x, col) in enumerate([(-26, (170, 70, 40)), (-4, (120, 140, 56)), (18, (196, 150, 60))]):
        s.box(V(x, 6, 22), (9, 7, 2.5), (140, 108, 70))
        for k in range(7):
            s.ball(V(x - 6 + (k % 4) * 4, 3 + (k // 4) * 5, 26), 2.2, col, bias=3)
    # posts + striped awning (faded red / cream)
    for x in (-42, 42):
        s.line([V(x, 20, 0), V(x, 20, 46)], WOOD_D, 2, bias=4)
        s.line([V(x, -16, 0), V(x, -16, 56)], WOOD_D, 2)
    _stripes(s, -46, 46, 24, 46, 58, [RED_CLOTH, CREAM], 8)
    # scale + hanging lamp
    s.box(V(32, 10, 23), (4, 3, 3), STEEL)
    s.line([V(0, 12, 50), V(0, 12, 42)], (40, 40, 40), 1, bias=7)
    s.ball(V(0, 12, 40), 2.2, (250, 214, 130), bias=8)
    img = grunge(s.render(), 101, 0.14, rust=0.04, dirt_bottom=0.22, leaves=0.004)
    return img


def market_stall_b():
    s = sc()
    s.box(V(0, 4, 8), (36, 12, 8), (110, 92, 66))
    # hanging goods rail
    for x in (-38, 38):
        s.line([V(x, 16, 0), V(x, 16, 48)], WOOD_D, 2, bias=4)
        s.line([V(x, -12, 0), V(x, -12, 54)], WOOD_D, 2)
    s.line([V(-38, 16, 44), V(38, 16, 44)], WOOD_D, 1, bias=5)
    for i, x in enumerate(range(-30, 34, 10)):
        col = [(70, 90, 110), (150, 120, 70), (110, 60, 50), (180, 170, 150)][i % 4]
        s.box(V(x, 16.5, 38), (3, 0.5, 5), col, bias=6)
    _stripes(s, -42, 42, 20, 48, 58, [(70, 104, 84), CREAM], 7)
    # goods on the counter: jars, canisters, bundles
    for x in (-26, -18, -10):
        s.cyl(V(x, 6, 16), 3, 7, (160, 170, 150))
    s.box(V(10, 4, 20), (8, 6, 4), (86, 104, 70))
    s.cyl(V(26, 4, 16), 4, 10, (120, 60, 40))
    # sacks in front
    s.ball(V(-20, 24, 6), 7, (170, 150, 110), bias=2)
    s.ball(V(-8, 26, 5), 6, (160, 140, 100), bias=2)
    return grunge(s.render(), 102, 0.14, dirt_bottom=0.22, leaves=0.004)


def water_tower():
    s = Scene(CELL, CELL, (96, 184))
    # brick octagonal base (as a box with brick lines) + steel tank on top
    brick = (142, 78, 58)
    s.box(V(0, 0, 36), (18, 16, 36), brick, face_cols={'front': (150, 84, 62)})
    for z in range(6, 72, 6):
        s.line([V(-18, 16.3, z), V(18, 16.3, z)], (110, 60, 44), 1, bias=2)
    s.box(V(0, 16.4, 12), (5, 0.4, 10), (60, 50, 40), edge=False, bias=3)
    s.box(V(0, 16.4, 50), (3, 0.4, 5), (70, 90, 100), edge=False, bias=3)
    s.box(V(0, 0, 74), (21, 19, 2), (120, 118, 110))
    s.cyl(V(0, 0, 76), 24, 30, (132, 138, 134), bands=((8, (100, 104, 102)), (20, (100, 104, 102))))
    s.cyl(V(0, 0, 106), 14, 8, (112, 116, 112))
    s.cyl(V(0, 0, 114), 3, 6, (90, 92, 90))
    # ladder
    for z in range(4, 104, 5):
        s.line([V(20, 16, z), V(25, 14, z)], (60, 62, 60), 1, bias=5)
    s.line([V(20, 16, 2), V(20, 16, 106)], (60, 62, 60), 1, bias=5)
    s.line([V(25, 14, 2), V(25, 14, 106)], (60, 62, 60), 1, bias=5)
    img = s.render()
    d = ImageDraw.Draw(img)
    # faded painted number on the tank
    d.text((84, 88), '1954', fill=(190, 186, 170, 255))
    return grunge(img, 103, 0.14, rust=0.28, dirt_bottom=0.16, leaves=0.004)


def garden_beds():
    s = sc(150)
    for row, y in enumerate((-18, 4, 26)):
        s.box(V(0, y, 3), (52, 8, 3), (104, 78, 52), face_cols={'top': (74, 58, 40)})
        rng = random.Random(row + 7)
        for x in range(-46, 48, 8):
            kind = (row + x // 8) % 3
            if kind == 0:     # cabbages
                s.ball(V(x, y, 8), 3.4, (116, 148, 84), bias=2)
            elif kind == 1:   # potato tops
                s.ball(V(x, y - 2, 8), 2.4, (84, 118, 58), bias=2)
                s.ball(V(x + 2, y + 2, 7), 2.0, (96, 128, 62), bias=2)
            else:             # dill / onion
                s.line([V(x, y, 6), V(x + rng.uniform(-1, 1), y, 13)], (110, 150, 70), 1, bias=2)
                s.line([V(x + 2, y, 6), V(x + 2, y, 11)], (96, 140, 64), 1, bias=2)
    # stick fence + watering can
    for x in range(-58, 60, 10):
        s.line([V(x, 38, 0), V(x, 38, 12)], WOOD_D, 1, bias=4)
    s.line([V(-58, 38, 9), V(58, 38, 9)], WOOD, 1, bias=4)
    s.cyl(V(48, -30, 0), 4, 7, (96, 120, 110))
    return grunge(s.render(), 104, 0.12, dirt_bottom=0.15, leaves=0.006)


def laundry_line():
    s = sc(160)
    for x in (-60, 60):
        s.line([V(x, 0, 0), V(x, 0, 44)], WOOD_D, 2)
        s.line([V(x - 4, 0, 44), V(x + 4, 0, 44)], WOOD_D, 1)
    for i in range(25):
        x0 = -60 + i * 5
        sag = 4.0 * math.sin(math.pi * i / 24)
        s.line([V(x0, 0, 42 - sag), V(x0 + 5, 0, 42 - 4.0 * math.sin(math.pi * (i + 1) / 24))], (170, 170, 160), 1, bias=3)
    clothes = [(-48, 10, 14, (170, 168, 150)), (-30, 8, 20, (90, 110, 130)), (-12, 9, 12, (160, 80, 60)),
               (6, 10, 18, (190, 186, 170)), (24, 7, 14, (110, 120, 80)), (42, 9, 16, (150, 130, 96))]
    for x, w, h, col in clothes:
        top = 42 - 4.0 * math.sin(math.pi * (x + 60) / 120) - 1
        s.box(V(x, 0.5, top - h / 2), (w / 2, 0.6, h / 2), col, bias=4)
    s.box(V(-4, 16, 4), (10, 6, 4), (140, 120, 90))       # washing basket
    return grunge(s.render(), 105, 0.12, dirt_bottom=0.1)


def field_kitchen():
    s = sc()
    brick = (136, 80, 60)
    s.box(V(-14, 0, 12), (24, 18, 12), brick)
    s.box(V(-14, 18.3, 8), (6, 0.4, 5), (40, 26, 18), edge=False, bias=2)
    s.box(V(-14, 18.5, 8), (4, 0.2, 3), (230, 130, 50), edge=False, bias=3)
    s.cyl(V(-14, 0, 24), 15, 12, (70, 72, 70))
    s.cyl(V(-14, 0, 36), 16, 1.5, (86, 88, 86))
    s.cyl(V(6, -12, 24), 3, 44, (60, 60, 58))            # chimney pipe
    s.cyl(V(6, -12, 68), 5, 3, (70, 70, 68))
    # side table with pots, bread, firewood
    s.box(V(34, 6, 14), (14, 10, 1.5), WOOD)
    for x in (22, 46):
        s.line([V(x, 14, 0), V(x, 14, 13)], WOOD_D, 1, bias=2)
    s.cyl(V(28, 4, 15.5), 5, 6, (120, 124, 120))
    s.box(V(42, 6, 17.5), (4, 3, 2), (180, 140, 80))
    for row in range(2):
        for i in range(4 - row):
            s.hcyl(V(-48, -10 + i * 5 + row * 2.5, 3 + row * 4.5), V(-32, -10 + i * 5 + row * 2.5, 3 + row * 4.5), 2.2, (120, 84, 54))
    return grunge(s.render(), 106, 0.14, rust=0.12, dirt_bottom=0.2, leaves=0.004)


def platform_canopy():
    s = sc(170)
    s.box(V(0, 4, 5), (78, 22, 5), (140, 138, 128), face_cols={'front': (120, 118, 110)})
    s.line([V(-78, 26.2, 9.4), V(78, 26.2, 9.4)], (200, 180, 70), 2, bias=3)      # yellow edge
    for x in (-60, 0, 60):
        s.box(V(x, 0, 30), (2, 2, 20), (90, 96, 92))
    s.box(V(0, 2, 52), (74, 18, 2), (96, 108, 100), face_cols={'top': (110, 118, 110)})
    s.box(V(0, 20.4, 50), (74, 0.4, 3), (130, 60, 46), edge=False, bias=2)
    # bench + station board
    s.box(V(-30, -4, 16), (16, 4, 1.2), WOOD)
    for x in (-42, -18):
        s.line([V(x, -2, 10), V(x, -2, 15)], (60, 60, 58), 1, bias=2)
    s.box(V(30, -8, 34), (18, 1, 6), (40, 70, 64), bias=3)
    img = s.render()
    d = ImageDraw.Draw(img)
    return grunge(img, 107, 0.14, rust=0.14, dirt_bottom=0.18, leaves=0.006)


def radio_mast():
    s = Scene(CELL, CELL, (96, 186))
    s.box(V(0, 0, 2), (16, 16, 2), (120, 118, 110))
    h = 150
    corners = [(-9, -9), (9, -9), (9, 9), (-9, 9)]
    for (x, y) in corners:
        s.line([V(x, y, 2), V(x * 0.25, y * 0.25, h)], (150, 60, 50) if False else (140, 142, 138), 1)
    for z in range(10, h - 10, 12):
        k = 1 - z / h * 0.75
        s.line([V(-9 * k, 9 * k, z), V(9 * k, 9 * k, z + 12)], (120, 122, 118), 1, bias=2)
        s.line([V(9 * k, 9 * k, z), V(-9 * k, 9 * k, z + 12)], (120, 122, 118), 1, bias=2)
    # red/white warning bands near top, antennae, dish
    for z in (h - 30, h - 18):
        s.line([V(-4, 4, z), V(4, 4, z)], (190, 50, 40), 2, bias=3)
    s.line([V(0, 0, h), V(0, 0, h + 20)], (80, 80, 80), 1, bias=4)
    s.line([V(-14, 0, h - 8), V(14, 0, h - 8)], (80, 80, 80), 1, bias=4)
    s.ball(V(0, 0, h + 20), 1.6, (230, 60, 40), bias=5)
    s.box(V(20, 18, 12), (10, 8, 10), (110, 116, 104))     # radio hut
    s.box(V(20, 18, 23), (11.5, 9.5, 1.2), (80, 86, 76))
    s.box(V(20, 26.3, 12), (3, 0.3, 7), (60, 56, 50), edge=False, bias=2)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.ellipse([104, 60, 116, 68], fill=(170, 172, 166, 255), outline=(40, 40, 40, 255))
    return grunge(img, 108, 0.12, rust=0.18, dirt_bottom=0.12)


def water_point():
    s = sc()
    # hand pump on concrete pad + barrels + trough
    s.box(V(-10, 4, 2), (20, 16, 2), (128, 126, 118))
    s.cyl(V(-14, 2, 4), 3, 22, (60, 90, 80))
    s.line([V(-14, 2, 26), V(-2, 2, 30)], (50, 60, 56), 2, bias=3)
    s.line([V(-17, 2, 18), V(-22, 4, 16)], (50, 60, 56), 2, bias=3)
    s.box(V(0, 14, 6), (14, 5, 4), (110, 112, 108), face_cols={'top': (70, 100, 116)})
    for (x, y, col) in [(26, -6, (70, 92, 110)), (40, 2, (130, 60, 40)), (30, 12, (70, 92, 110))]:
        s.cyl(V(x, y, 0), 7, 16, col, bands=((4, (50, 60, 70)), (12, (50, 60, 70))))
    s.box(V(-40, 6, 10), (8, 8, 10), (90, 104, 120))      # plastic cube tank
    s.line([V(-48, 14, 10), V(-32, 14, 10)], (150, 150, 150), 1, bias=2)
    img = grunge(s.render(), 109, 0.12, rust=0.14, dirt_bottom=0.22)
    a = np.array(img).astype(float)
    return Image.fromarray(a.astype(np.uint8))


def chicken_coop():
    s = sc()
    s.box(V(-16, 0, 16), (22, 16, 16), (118, 92, 62), face_cols={'front': (130, 102, 68)})
    for x in range(-36, 6, 7):
        s.line([V(x, 16.3, 1), V(x, 16.3, 31)], WOOD_D, 1, bias=2)
    s.poly([V(-40, 18, 32), V(8, 18, 32), V(8, -2, 42), V(-40, -2, 42)], (100, 88, 80))
    s.poly([V(-40, -2, 42), V(8, -2, 42), V(8, -18, 32), V(-40, -18, 32)], (86, 76, 70))
    s.box(V(-8, 16.4, 6), (4, 0.3, 5), (40, 30, 24), edge=False, bias=3)
    # mesh run
    for x in range(8, 52, 6):
        s.line([V(x, 16, 0), V(x, 16, 16)], (150, 150, 140), 1, bias=3)
    s.line([V(8, 16, 16), V(50, 16, 16)], (150, 150, 140), 1, bias=3)
    s.line([V(50, -14, 0), V(50, 16, 0), V(50, 16, 16)], (150, 150, 140), 1, bias=3)
    for (x, y, col) in [(20, 6, (220, 214, 200)), (32, 10, (170, 110, 60)), (42, 2, (220, 214, 200))]:
        s.ball(V(x, y, 4), 3, col, bias=2)
        s.px(V(x + 3, y, 6), (200, 60, 40), bias=3)
    return grunge(s.render(), 110, 0.14, dirt_bottom=0.2, leaves=0.006)


def long_table():
    s = sc(150)
    s.box(V(0, 0, 14), (56, 12, 1.6), WOOD, face_cols={'top': PLANK})
    for x in (-50, 50):
        s.line([V(x, 8, 0), V(x, 8, 13)], WOOD_D, 2, bias=2)
    for y in (-22, 22):
        s.box(V(0, y, 8), (54, 3, 1.2), WOOD_D)
        for x in (-46, 46):
            s.line([V(x, y + 2, 0), V(x, y + 2, 7)], WOOD_D, 1, bias=2)
    for (x, col) in [(-36, (180, 180, 170)), (-12, (160, 90, 60)), (14, (180, 180, 170)), (38, (110, 130, 110))]:
        s.cyl(V(x, 0, 16), 3.5, 2, col)
    s.cyl(V(0, 2, 16), 2, 6, (60, 90, 70))
    s.box(V(26, -2, 17), (5, 3, 1.5), (180, 140, 80))
    return grunge(s.render(), 111, 0.12, dirt_bottom=0.12, leaves=0.004)


def fire_barrel():
    s = sc(150)
    s.cyl(V(0, 0, 0), 9, 22, (86, 70, 56), bands=((6, (60, 46, 36)), (16, (60, 46, 36))))
    for k, (dx, dz, r, col) in enumerate([(-3, 24, 4, (240, 150, 50)), (2, 27, 4.5, (250, 190, 70)),
                                           (0, 31, 3, (255, 230, 150)), (-1, 36, 2, (250, 190, 70))]):
        s.ball(V(dx, 0, dz), r, col, bias=5 + k)
    s.box(V(18, 4, 3), (6, 4, 3), (110, 84, 54))
    return grunge(s.render(), 112, 0.1, rust=0.4, dirt_bottom=0.1)


# ---------------------------------------------------------------- rubezh --
def _sandbag_row(s, x0, x1, y, z, col=SAND, bias=0.0):
    n = max(1, int((x1 - x0) / 11))
    w = (x1 - x0) / n
    for i in range(n):
        x = x0 + w * (i + 0.5) + (w * 0.5 if int(z / 5) % 2 else 0)
        if x > x1:
            continue
        c = tuple(int(v * (0.92 + 0.08 * ((i * 7 + int(z)) % 3))) for v in col)
        s.box(V(x, y, z), (w * 0.47, 5, 2.4), c, bias=bias)


def sandbag_nest():
    s = sc()
    for z in (2.4, 7.2, 12.0, 16.8):
        _sandbag_row(s, -44, 44, 16, z, bias=2)
        for y in range(-14, 14, 10):
            s.box(V(-44, y, z), (5, 5, 2.4), SAND, bias=1)
            s.box(V(44, y, z), (5, 5, 2.4), SAND, bias=1)
    s.box(V(0, -2, 26), (40, 18, 1.4), OLIVE_D)           # camo net roof
    for x in (-38, 38):
        s.line([V(x, -16, 0), V(x, -16, 25)], WOOD_D, 1)
        s.line([V(x, 14, 20), V(x, 14, 25)], WOOD_D, 1, bias=3)
    # MG barrel poking out
    s.line([V(6, 10, 22), V(12, 34, 22)], (40, 40, 40), 2, bias=4)
    img = s.render()
    a = np.array(img)
    rng = random.Random(113)
    for _ in range(200):
        x, y = rng.randint(40, 150), rng.randint(40, 150)
        if a[y, x, 3] and abs(int(a[y, x, 0]) - OLIVE_D[0] * 0.9) < 30 and a[y, x, 1] > a[y, x, 0]:
            a[y, x, :3] = rng.choice([(78, 88, 50), (58, 64, 38), (96, 96, 60)])
    return grunge(Image.fromarray(a), 113, 0.14, dirt_bottom=0.25, leaves=0.004)


def hesco_row():
    s = sc(160)
    for i, x in enumerate(range(-60, 61, 24)):
        s.box(V(x, 0, 14), (11.5, 11, 14), (150, 136, 100), face_cols={'top': (130, 116, 80), 'front': (158, 144, 108)})
        for gx in range(-10, 12, 5):
            s.line([V(x + gx, 11.2, 0), V(x + gx, 11.2, 28)], (100, 102, 96), 1, bias=2)
        for gz in range(4, 28, 6):
            s.line([V(x - 11, 11.2, gz), V(x + 11, 11.2, gz)], (100, 102, 96), 1, bias=2)
    # razor wire coil on top
    for i in range(60):
        t = i / 59
        x = -70 + t * 140
        a = t * math.pi * 26
        s.px(V(x + math.cos(a) * 1.5, math.sin(a) * 4, 32 + math.sin(a) * 3), (150, 152, 150), bias=4)
    return grunge(s.render(), 114, 0.14, rust=0.05, dirt_bottom=0.25)


def _gable_tent(s, W, L, H, E, cols, door, seams):
    """ridge runs toward the camera (y); both roof slopes and the front gable are visible."""
    left, right, front, wall = cols
    s.box(V(0, 0, 1), (W + 6, L + 6, 1), (74, 70, 58), edge=False)
    # low side walls
    s.poly([V(-W, -L, 0), V(-W, L, 0), V(-W, L, E), V(-W, -L, E)], wall)
    s.poly([V(W, -L, 0), V(W, L, 0), V(W, L, E), V(W, -L, E)], wall)
    # roof slopes
    s.poly([V(-W, -L, E), V(-W, L, E), V(0, L, H), V(0, -L, H)], left, bias=1)
    s.poly([V(W, -L, E), V(W, L, E), V(0, L, H), V(0, -L, H)], right, bias=1)
    for y in range(-L + seams, L, seams):
        s.line([V(-W, y, E), V(0, y, H), V(W, y, E)], tuple(int(c * 0.86) for c in left), 1, bias=2)
    s.line([V(0, -L, H), V(0, L, H)], tuple(min(255, int(c * 1.12)) for c in right), 1, bias=3)
    # front gable
    s.poly([V(-W, L, 0), V(W, L, 0), V(W, L, E), V(0, L, H), V(-W, L, E)], front, bias=4)
    s.poly([V(-door, L + 0.2, 0), V(door, L + 0.2, 0), V(0, L + 0.2, H * 0.62)], (38, 40, 32), bias=12)
    for x in (-W, W):
        s.line([V(x, L, E), V(x + (8 if x > 0 else -8), L + 8, 0)], (160, 150, 120), 1, bias=12)


def army_tent():
    s = sc(170)
    _gable_tent(s, 36, 40, 38, 12, ((106, 116, 76), (86, 96, 62), (70, 80, 50), (78, 88, 56)), 11, 13)
    s.cyl(V(-16, -24, 30), 2, 20, (60, 60, 58), bias=6)
    s.box(V(22, 36, 8), (6, 5, 8), OLIVE_D, bias=6)
    img = s.render()
    return grunge(img, 115, 0.12, dirt_bottom=0.18, leaves=0.004)


def flag_pole():
    s = Scene(CELL, CELL, (80, 186))
    s.box(V(0, 0, 3), (10, 10, 3), CONCRETE)
    s.cyl(V(0, 0, 6), 1.6, 140, (170, 172, 168))
    s.ball(V(0, 0, 147), 2.2, (200, 180, 90), bias=2)
    img = s.render()
    d = ImageDraw.Draw(img)
    # waving cloth: olive field with a pale bar - Rubezh colours
    fx, fy = 82, 44
    for i in range(60):
        wave = int(round(3 * math.sin(i / 9.0)))
        d.line([(fx + i, fy + wave), (fx + i, fy + 36 + wave)], fill=(84, 98, 62, 255))
        d.line([(fx + i, fy + 14 + wave), (fx + i, fy + 21 + wave)], fill=(200, 190, 150, 255))
        if i % 9 < 2:
            d.line([(fx + i, fy + wave), (fx + i, fy + 36 + wave)], fill=(70, 82, 52, 255))
    return grunge(outline_img(img), 116, 0.1, dirt_bottom=0.1)


def searchlight_tower():
    s = Scene(CELL, CELL, (96, 186))
    for (x, y) in [(-14, -14), (14, -14), (-14, 14), (14, 14)]:
        s.line([V(x * 1.3, y * 1.3, 0), V(x, y, 84)], (84, 86, 84), 2)
    for z in (20, 44, 66):
        s.line([V(-15, 15, z), V(15, 15, z)], (90, 92, 90), 1, bias=3)
        s.line([V(-15, 15, z), V(15, 15, z + 20)], (90, 92, 90), 1, bias=3)
    s.box(V(0, 0, 86), (18, 18, 2), (100, 100, 96))
    for z in (90, 96):
        _sandbag_row(s, -18, 18, 17, z, bias=3)
    s.box(V(0, 0, 112), (20, 20, 1.4), OLIVE_D)
    for (x, y) in [(-18, 18), (18, 18), (-18, -18), (18, -18)]:
        s.line([V(x, y, 88), V(x, y, 111)], (70, 72, 70), 1, bias=2)
    s.cyl(V(8, 8, 98), 5, 6, (60, 62, 60), bias=5)
    s.ball(V(8, 13, 101), 3.5, (250, 240, 200), bias=6)
    return grunge(s.render(), 117, 0.12, rust=0.16, dirt_bottom=0.1)


def ammo_bunker():
    s = sc(164)
    # earth-covered arch with a concrete portal
    for i in range(12):
        a0 = math.pi * i / 12
        a1 = math.pi * (i + 1) / 12
        col = (92, 104, 62) if i % 3 else (86, 96, 58)
        s.poly([V(-50, 24, 0), V(50, 24, 0), V(50, 24 - 0, 0)], col)
    s.box(V(0, 0, 14), (54, 26, 14), (96, 104, 64), face_cols={'top': (88, 100, 58), 'front': (106, 94, 66)})
    s.box(V(0, 0, 32), (46, 20, 4), (90, 102, 60))
    s.box(V(0, 0, 38), (34, 14, 2), (84, 98, 56))
    s.box(V(0, 26.5, 16), (22, 1.5, 16), CONCRETE)
    s.box(V(0, 28.2, 12), (14, 0.3, 12), (70, 84, 60), edge=False, bias=2)
    s.line([V(0, 28.6, 0), V(0, 28.6, 24)], (40, 44, 36), 1, bias=3)
    s.box(V(0, 28.4, 30), (10, 0.3, 2.5), (200, 180, 60), edge=False, bias=3)
    s.box(V(-34, 30, 6), (6, 4, 6), OLIVE, bias=2)
    s.box(V(-20, 32, 4), (5, 3.5, 4), OLIVE_D, bias=2)
    img = s.render()
    a = np.array(img)
    rng = random.Random(118)
    for _ in range(260):
        x, y = rng.randint(30, 160), rng.randint(60, 150)
        if a[y, x, 3] and a[y, x, 1] > a[y, x, 0] + 6:
            a[y, x, :3] = rng.choice([(70, 90, 46), (110, 120, 70), (84, 70, 50)])
    return grunge(Image.fromarray(a), 118, 0.12, dirt_bottom=0.2, leaves=0.01)


def btr():
    s = sc(162)
    olive = (86, 98, 60)
    for x in (-40, -14, 14, 40):
        for y in (-20, 20):
            s.cyl(V(x, y, 0), 8, 4, (30, 30, 30), bias=-0.2)
            s.box(V(x, y, 8), (7.5, 3, 7.5), (32, 32, 32), bias=-0.4)
    s.hexa([V(-60, -18, 8), V(-60, -18, 26), V(-60, 18, 8), V(-60, 18, 26),
            V(62, -16, 12), V(54, -16, 28), V(62, 16, 12), V(54, 16, 28)], olive)
    s.hexa([V(-58, -20, 26), V(-58, -20, 32), V(-58, 20, 26), V(-58, 20, 32),
            V(50, -20, 28), V(44, -18, 32), V(50, 20, 28), V(44, 18, 32)], (96, 108, 66),
           face_cols={5: (100, 112, 70)})
    s.cyl(V(6, 0, 32), 11, 8, (80, 92, 56))
    s.hcyl(V(12, 2, 37), V(58, 2, 39), 1.6, (50, 54, 40), bias=3)
    s.box(V(-30, 20.4, 22), (6, 0.3, 3), (60, 70, 44), edge=False, bias=2)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.text((58, 108), '217', fill=(210, 206, 180, 255))
    return grunge(img, 119, 0.12, rust=0.12, dirt_bottom=0.35, leaves=0.004)


def jersey_blocks():
    s = sc(160)
    for i, x in enumerate(range(-54, 60, 36)):
        s.hexa([V(x - 17, -6, 0), V(x - 17, -3, 20), V(x - 17, 6, 0), V(x - 17, 3, 20),
                V(x + 17, -6, 0), V(x + 17, -3, 20), V(x + 17, 6, 0), V(x + 17, 3, 20)],
               (160, 158, 148))
        if i % 2 == 0:
            s.poly([V(x - 10, 5.2, 4), V(x - 2, 5.2, 4), V(x + 4, 3.6, 14), V(x - 4, 3.6, 14)], (190, 60, 44), bias=2)
            s.poly([V(x + 2, 5.2, 4), V(x + 10, 5.2, 4), V(x + 16, 3.6, 14), V(x + 8, 3.6, 14)], (190, 60, 44), bias=2)
    return grunge(s.render(), 120, 0.16, rust=0.04, dirt_bottom=0.3, leaves=0.004)


# ---------------------------------------------------------------- mechanics --
def jib_crane():
    s = Scene(CELL, CELL, (72, 184))
    s.box(V(0, 0, 3), (16, 16, 3), CONCRETE)
    s.box(V(0, 0, 60), (4, 4, 54), HAZARD)
    for z in range(10, 110, 14):
        s.line([V(-4, 4.2, z), V(4, 4.2, z + 7)], (40, 40, 38), 2, bias=2)
    s.box(V(44, 0, 112), (52, 3, 3), HAZARD)
    s.line([V(0, 0, 114), V(90, 0, 114)], (40, 40, 38), 1, bias=2)
    s.line([V(4, 0, 100), V(40, 0, 109)], (150, 120, 40), 2, bias=1)
    s.box(V(-12, 0, 112), (8, 5, 5), (80, 80, 76))                 # counterweight
    s.line([V(70, 0, 109), V(70, 0, 52)], (40, 40, 40), 1, bias=3)
    s.box(V(70, 0, 50), (3, 2, 2), (60, 60, 58), bias=3)
    s.box(V(70, 0, 38), (12, 8, 10), (110, 90, 70), bias=3)          # hanging engine block
    s.line([V(70, 0, 48), V(62, 0, 48), V(70, 0, 52), V(78, 0, 48)], (40, 40, 40), 1, bias=4)
    return grunge(s.render(), 121, 0.12, rust=0.22, dirt_bottom=0.12)


def scrap_heap():
    s = sc(160)
    rng = random.Random(122)
    s.poly([V(-60, 20, 0), V(60, 20, 0), V(30, -10, 30), V(-24, -12, 34)], (90, 80, 70))
    pieces = [((-30, 4, 14), (14, 8, 6), (110, 60, 40)), ((10, 8, 10), (18, 6, 5), (120, 124, 120)),
              ((-6, -2, 26), (10, 7, 5), (70, 90, 110)), ((26, 0, 20), (9, 8, 7), (130, 70, 40)),
              ((-42, 12, 6), (8, 6, 5), (90, 90, 86)), ((40, 14, 6), (10, 5, 5), (100, 110, 80))]
    for (c, h, col) in pieces:
        s.box(V(*c), h, col, bias=2)
    for i in range(3):
        s.cyl(V(-20 + i * 26, 22 + (i % 2) * 4, 0), 8, 4, (30, 30, 30), bias=3)
        s.cyl(V(-20 + i * 26, 22 + (i % 2) * 4, 4), 4, 0.5, (100, 100, 96), bias=4)
    s.hcyl(V(-50, 0, 20), V(10, -10, 32), 2, (140, 110, 90), bias=3)
    s.hcyl(V(4, -6, 34), V(46, 6, 14), 2.5, (80, 80, 76), bias=3)
    img = s.render()
    return grunge(img, 122, 0.18, rust=0.45, dirt_bottom=0.2, leaves=0.004)


def wind_turbine():
    s = Scene(CELL, CELL, (96, 186))
    s.box(V(0, 0, 3), (12, 12, 3), CONCRETE)
    s.cyl(V(0, 0, 6), 2.4, 118, (150, 152, 150))
    for (x, y) in [(-26, 20), (26, 20), (0, -30)]:
        s.line([V(0, 0, 70), V(x, y, 0)], (120, 120, 116), 1, bias=-1)
    s.box(V(0, 0, 126), (10, 4, 4), (110, 120, 128))
    s.box(V(-12, 0, 126), (2, 8, 5), (140, 60, 40))                # tail fin
    img = s.render()
    d = ImageDraw.Draw(img)
    hx, hy = 108, 186 - 126
    for a in (0.3, 0.3 + 2 * math.pi / 3, 0.3 + 4 * math.pi / 3):
        ex, ey = hx + math.cos(a) * 30, hy + math.sin(a) * 30
        d.polygon([(hx, hy), (ex, ey), (ex + math.cos(a + 1.5) * 5, ey + math.sin(a + 1.5) * 5)],
                  fill=(186, 188, 182, 255))
    d.ellipse([hx - 3, hy - 3, hx + 3, hy + 3], fill=(80, 80, 80, 255))
    s2 = Scene(CELL, CELL, (96, 186))
    s2.box(V(24, 18, 10), (10, 7, 10), (100, 108, 100))            # battery box
    s2.box(V(24, 25.3, 12), (5, 0.3, 3), (206, 164, 44), edge=False, bias=2)
    img.alpha_composite(s2.render())
    return grunge(outline_img(img), 123, 0.1, rust=0.14, dirt_bottom=0.1)


def fuel_station():
    s = sc(166)
    s.box(V(0, 0, 3), (56, 26, 3), (118, 116, 108))
    s.hcyl(V(-50, -8, 24), V(22, -8, 24), 18, (150, 60, 40))
    for x in (-40, 10):
        s.box(V(x, -8, 6), (4, 14, 4), (90, 90, 86))
    s.cyl(V(-14, -8, 42), 4, 4, (110, 110, 106))
    s.box(V(40, 10, 18), (8, 6, 16), (206, 164, 44))
    s.box(V(40, 16.3, 24), (5, 0.3, 4), (40, 50, 50), edge=False, bias=2)
    s.line([V(46, 16, 16), V(54, 22, 4), V(58, 22, 2)], (30, 30, 30), 1, bias=3)
    for (x, y) in [(-20, 22), (-6, 24)]:
        s.cyl(V(x, y, 6), 6, 14, (66, 90, 70), bands=((4, (50, 60, 50)), (10, (50, 60, 50))), bias=2)
    img = s.render()
    d = ImageDraw.Draw(img)
    return grunge(img, 124, 0.14, rust=0.3, dirt_bottom=0.3)


def car_on_blocks():
    s = sc(162)
    body = (110, 120, 128)
    for (x, y) in [(-34, -16), (34, -16), (-34, 16), (34, 16)]:
        s.box(V(x, y, 5), (6, 5, 5), (110, 84, 54), bias=-0.4)
    s.box(V(0, 0, 18), (50, 18, 8), body)
    s.box(V(-6, 0, 32), (24, 16, 6), (100, 110, 118), face_cols={'front': (60, 76, 88)})
    # open hood propped up
    s.poly([V(26, -16, 26), V(26, 16, 26), V(40, 16, 46), V(40, -16, 46)], (96, 106, 114), bias=3)
    s.box(V(38, 0, 26), (10, 12, 2), (60, 58, 54), bias=1)          # engine bay
    s.cyl(V(62, 10, 0), 8, 5, (30, 30, 30), bias=2)                 # wheel on floor
    s.box(V(-58, 16, 4), (6, 4, 4), (180, 40, 34), bias=2)          # toolbox
    return grunge(s.render(), 125, 0.12, rust=0.35, dirt_bottom=0.35)


def furnace():
    s = sc(172)
    brick = (126, 76, 58)
    s.box(V(-10, 0, 20), (26, 20, 20), brick)
    for z in range(6, 40, 6):
        s.line([V(-36, 20.3, z), V(16, 20.3, z)], (96, 56, 42), 1, bias=2)
    s.box(V(-10, 20.4, 14), (8, 0.3, 7), (40, 22, 14), edge=False, bias=2)
    s.box(V(-10, 20.6, 12), (6, 0.2, 4), (255, 140, 40), edge=False, bias=3)
    s.box(V(-10, 20.8, 11), (3, 0.2, 2), (255, 220, 120), edge=False, bias=4)
    s.cyl(V(-20, -8, 40), 6, 60, (100, 62, 48), bands=((20, (80, 50, 40)), (40, (80, 50, 40))))
    # anvil + quench barrel
    s.box(V(34, 10, 8), (6, 4, 8), (60, 60, 58))
    s.box(V(34, 10, 18), (11, 5, 3), (74, 74, 72))
    s.cyl(V(56, -4, 0), 8, 16, (80, 70, 60), bands=((6, (50, 44, 38)),))
    return grunge(s.render(), 126, 0.14, rust=0.2, dirt_bottom=0.25)


def solar_rig():
    s = sc(160)
    for i, x in enumerate((-40, 0, 40)):
        s.line([V(x - 14, 8, 0), V(x - 14, 8, 14)], (90, 92, 90), 1)
        s.line([V(x + 14, 8, 0), V(x + 14, 8, 14)], (90, 92, 90), 1)
        s.line([V(x - 14, -10, 0), V(x - 14, -10, 26)], (90, 92, 90), 1)
        s.line([V(x + 14, -10, 0), V(x + 14, -10, 26)], (90, 92, 90), 1)
        s.poly([V(x - 17, 12, 14), V(x + 17, 12, 14), V(x + 17, -12, 28), V(x - 17, -12, 28)], (46, 58, 84), bias=3)
        for g in range(1, 4):
            s.line([V(x - 17 + g * 8.5, 12, 14), V(x - 17 + g * 8.5, -12, 28)], (120, 130, 150), 1, bias=4)
        s.line([V(x - 17, 0, 21), V(x + 17, 0, 21)], (120, 130, 150), 1, bias=4)
    s.box(V(0, 28, 8), (12, 6, 8), (110, 116, 110), bias=2)
    s.line([V(-40, 12, 12), V(-8, 26, 4)], (30, 30, 30), 1, bias=3)
    s.line([V(40, 12, 12), V(8, 26, 4)], (30, 30, 30), 1, bias=3)
    return grunge(s.render(), 127, 0.1, rust=0.08, dirt_bottom=0.1)


def container_shop():
    s = sc(166)
    blue = (60, 92, 110)
    s.box(V(0, 0, 22), (58, 22, 22), blue)
    for x in range(-56, 58, 6):
        s.line([V(x, 22.2, 1), V(x, 22.2, 43)], (46, 72, 88), 1, bias=2)
    s.box(V(10, 22.4, 20), (24, 0.3, 18), (30, 28, 24), edge=False, bias=3)     # open side
    s.box(V(10, 22.6, 36), (22, 0.2, 1.5), (250, 214, 130), edge=False, bias=4)  # lamp strip
    for x in (-6, 4, 14, 24):
        s.box(V(x, 22.6, 12), (3, 0.2, 5), (120, 110, 90), edge=False, bias=4)
    s.poly([V(-58, 34, 38), V(58, 34, 38), V(58, 22, 46), V(-58, 22, 46)], (150, 150, 140), bias=5)   # awning sheet
    for x in (-54, 54):
        s.line([V(x, 34, 0), V(x, 34, 38)], (80, 80, 76), 1, bias=5)
    s.box(V(-38, 22.4, 26), (10, 0.3, 4), (206, 164, 44), edge=False, bias=3)
    return grunge(s.render(), 128, 0.14, rust=0.3, dirt_bottom=0.28)


# ---------------------------------------------------------------- lazaret --
def medical_tent():
    s = sc(170)
    _gable_tent(s, 36, 40, 38, 12, ((206, 208, 198), (178, 182, 174), (150, 156, 148), (166, 170, 162)), 11, 13)
    img = s.render()
    d = ImageDraw.Draw(img)
    # red crosses on both roof slopes, readable from the 3/4 camera
    for cx in (96 - 18, 96 + 18):
        cy = 170 - 40
        d.rectangle([cx - 5, cy - 2, cx + 5, cy + 2], fill=CROSS + (255,))
        d.rectangle([cx - 2, cy - 5, cx + 2, cy + 5], fill=CROSS + (255,))
    return grunge(img, 129, 0.1, dirt_bottom=0.22, leaves=0.004)


def decon_frame():
    s = sc(166)
    for (x, y) in [(-30, -14), (30, -14), (-30, 14), (30, 14)]:
        s.line([V(x, y, 0), V(x, y, 44)], (170, 172, 168), 2)
    s.line([V(-30, 14, 44), V(30, 14, 44)], (170, 172, 168), 2, bias=2)
    s.line([V(-30, -14, 44), V(30, -14, 44)], (170, 172, 168), 2)
    s.box(V(0, 0, 1), (32, 16, 1), (90, 110, 120), edge=False)
    # translucent strip curtains
    for x in range(-28, 30, 5):
        s.box(V(x, 14.2, 22), (2.2, 0.2, 21), (170, 200, 196), edge=False, bias=3)
    # shower heads + pipe
    for x in (-12, 12):
        s.line([V(x, 0, 44), V(x, 0, 38)], (120, 120, 116), 1, bias=4)
        s.cyl(V(x, 0, 36), 3, 2, (150, 150, 146), bias=4)
    s.line([V(-30, 0, 44), V(30, 0, 44)], (120, 120, 116), 1, bias=4)
    s.cyl(V(46, -4, 0), 9, 26, (220, 220, 210), bands=((20, (60, 120, 160)),))
    s.box(V(46, 5, 12), (3, 0.3, 3), (206, 164, 44), edge=False, bias=3)
    img = s.render()
    a = np.array(img).astype(float)
    cur = (a[..., 1] > 175) & (a[..., 2] > 170) & (a[..., 0] < 190) & (a[..., 3] > 0)
    a[cur, 3] = 175
    return grunge(Image.fromarray(a.astype(np.uint8)), 130, 0.1, dirt_bottom=0.12)


def triage_canopy():
    s = sc(166)
    for (x, y) in [(-54, -20), (54, -20), (-54, 22), (54, 22)]:
        s.line([V(x, y, 0), V(x, y, 40)], (150, 150, 146), 2)
    s.poly([V(-58, 26, 38), V(58, 26, 38), V(58, -22, 46), V(-58, -22, 46)], (130, 150, 140), bias=6)
    s.line([V(-58, 26, 38), V(58, 26, 38)], (100, 120, 110), 1, bias=7)
    for x in (-34, 0, 34):
        s.box(V(x, 2, 9), (9, 18, 1.2), (170, 176, 170))
        s.box(V(x, 2, 11), (8, 16, 1.2), (140, 160, 170), bias=1)
        s.box(V(x, -12, 12), (7, 3, 1.5), (220, 220, 214), bias=2)
        for (lx, ly) in [(-8, -16), (8, -16), (-8, 20), (8, 20)]:
            s.line([V(x + lx, ly, 0), V(x + lx, ly, 8)], (90, 90, 88), 1, bias=0.5)
    s.line([V(48, 16, 0), V(48, 16, 30)], (170, 170, 166), 1, bias=3)
    s.box(V(48, 16, 30), (3, 1, 4), (190, 210, 214), bias=3)
    return grunge(s.render(), 131, 0.1, dirt_bottom=0.14)


def herb_beds():
    s = sc(150)
    for row, y in enumerate((-16, 6, 28)):
        s.box(V(0, y, 3), (50, 7, 3), (150, 150, 140), face_cols={'top': (70, 58, 42)})
        for x in range(-44, 46, 7):
            k = (row * 3 + x // 7) % 3
            if k == 0:   # chamomile
                s.ball(V(x, y, 8), 2.5, (100, 134, 76), bias=2)
                s.px(V(x, y - 1, 11), (236, 232, 200), bias=3)
            elif k == 1:  # lavender / thyme
                s.line([V(x, y, 6), V(x, y, 12)], (104, 120, 90), 1, bias=2)
                s.px(V(x, y, 13), (150, 120, 180), bias=3)
                s.px(V(x + 1, y, 12), (150, 120, 180), bias=3)
            else:         # calendula
                s.ball(V(x, y, 8), 2.8, (92, 124, 70), bias=2)
                s.px(V(x, y, 11), (230, 150, 40), bias=3)
    for x in (-54, 54):
        s.line([V(x, 38, 0), V(x, 38, 14)], (150, 150, 146), 1, bias=4)
    s.box(V(0, 38.2, 14), (8, 0.4, 3), (230, 230, 220), bias=5)
    s.px(V(0, 38.8, 14), CROSS, bias=6)
    return grunge(s.render(), 132, 0.1, dirt_bottom=0.12, leaves=0.004)


def incinerator():
    s = sc(176)
    s.box(V(0, 0, 18), (22, 18, 18), (130, 128, 120))
    s.box(V(0, 18.3, 14), (9, 0.3, 8), (60, 58, 54), edge=False, bias=2)
    s.box(V(0, 18.5, 12), (6, 0.2, 3), (240, 120, 40), edge=False, bias=3)
    s.cyl(V(10, -8, 36), 5, 70, (150, 150, 146), bands=((10, (170, 60, 50)), (60, (170, 60, 50))))
    # yellow bio-waste bins
    for (x, y) in [(-36, 10), (-36, -6)]:
        s.box(V(x, y, 8), (8, 6, 8), (200, 170, 50), bias=1)
        s.box(V(x, y, 17), (8.5, 6.5, 1), (170, 140, 40), bias=1)
    img = s.render()
    d = ImageDraw.Draw(img)
    return grunge(img, 133, 0.12, rust=0.2, dirt_bottom=0.2)


def oxygen_rack():
    s = sc(160)
    s.box(V(0, -8, 20), (40, 3, 20), (120, 124, 124))
    for i, x in enumerate(range(-34, 38, 10)):
        col = (70, 110, 150) if i % 3 else (210, 212, 206)
        s.cyl(V(x, 0, 0), 4.5, 36, col, bands=((30, (60, 60, 60)),), bias=2)
        s.cyl(V(x, 0, 36), 2, 4, (150, 150, 140), bias=3)
    s.line([V(-40, 5, 26), V(40, 5, 26)], (200, 180, 60), 1, bias=4)
    s.box(V(0, 5.3, 36), (10, 0.3, 3), (230, 230, 220), bias=5)
    return grunge(s.render(), 134, 0.1, rust=0.08, dirt_bottom=0.14)


def ambulance():
    s = sc(162)
    body = (196, 198, 188)
    for x in (-34, 30):
        for y in (-17, 17):
            s.box(V(x, y, 6), (7, 3, 6), (28, 28, 28), bias=-0.4)
    s.box(V(-6, 0, 26), (46, 18, 16), body, face_cols={'top': (206, 206, 196)})
    s.hexa([V(40, -18, 10), V(40, -18, 38), V(40, 18, 10), V(40, 18, 38),
            V(56, -17, 10), V(50, -16, 30), V(56, 17, 10), V(50, 16, 30)], body,
           face_cols={1: (60, 80, 90)})
    s.box(V(-6, 18.3, 20), (46, 0.3, 2), CROSS, edge=False, bias=2)
    s.box(V(-20, 18.3, 30), (8, 0.3, 5), (70, 88, 96), edge=False, bias=2)
    s.box(V(10, 0, 43), (4, 4, 1.5), (60, 110, 200), bias=2)
    img = s.render()
    d = ImageDraw.Draw(img)
    cx, cy = 104, 162 - int(18 * 0.55) - 30
    d.rectangle([cx - 5, cy - 2, cx + 5, cy + 2], fill=CROSS + (255,))
    d.rectangle([cx - 2, cy - 5, cx + 2, cy + 5], fill=CROSS + (255,))
    return grunge(img, 135, 0.1, rust=0.14, dirt_bottom=0.32)


def wash_station():
    s = sc(160)
    s.box(V(0, 0, 14), (30, 8, 1.6), (150, 154, 150))
    for x in (-26, 26):
        s.line([V(x, 6, 0), V(x, 6, 13)], (100, 100, 98), 1, bias=2)
    for x in (-14, 14):
        s.cyl(V(x, 0, 15.5), 7, 2, (170, 176, 176), bias=1)
    s.box(V(0, -10, 38), (22, 6, 8), (70, 110, 150))               # header tank
    s.line([V(-14, -6, 30), V(-14, -2, 22), V(-14, 0, 22)], (120, 120, 116), 1, bias=3)
    s.line([V(14, -6, 30), V(14, -2, 22), V(14, 0, 22)], (120, 120, 116), 1, bias=3)
    for x in (-20, 20):
        s.line([V(x, -10, 0), V(x, -10, 30)], (110, 110, 106), 1)
    s.box(V(0, -3.6, 38), (6, 0.3, 4), (230, 230, 220), bias=3)
    s.box(V(40, 6, 10), (6, 5, 10), (200, 170, 50), bias=1)
    s.box(V(-40, 6, 8), (5, 5, 8), (150, 160, 150), bias=1)
    return grunge(s.render(), 136, 0.1, rust=0.06, dirt_bottom=0.16)


# ------------------------------------------------------------- survival clutter --
def shanty():
    s = sc(166)
    # walls: mismatched corrugated sheets and planks
    cols = [(124, 128, 128), (128, 84, 54), (76, 102, 118), (110, 92, 64)]
    x = -40
    i = 0
    while x < 40:
        w = 10 + (i * 7) % 8
        s.box(V(x + w / 2, 0, 18), (w / 2, 20, 18), cols[i % 4], bias=0.1 * i)
        for k in range(int(x), int(x + w), 2):
            s.line([V(k, 20.2, 1), V(k, 20.2, 35)], tuple(int(c * 0.8) for c in cols[i % 4]), 1, bias=1)
        x += w
        i += 1
    s.box(V(-10, 20.4, 12), (7, 0.3, 12), (60, 44, 30), edge=False, bias=2)          # plank door
    for z in (5, 12, 19):
        s.line([V(-17, 20.8, z), V(-3, 20.8, z)], (90, 66, 44), 1, bias=3)
    s.box(V(20, 20.4, 22), (6, 0.3, 4), (60, 74, 80), edge=False, bias=2)             # window
    # tarp roof weighed with tyres, stove pipe with smoke
    s.poly([V(-46, 26, 36), V(46, 26, 36), V(46, -24, 44), V(-46, -24, 44)], (58, 88, 124))
    for (x, y) in ((-24, 0), (18, -6)):
        s.cyl(V(x, y, 39), 5, 3, (32, 32, 32), bias=4)
    s.cyl(V(30, -10, 40), 2, 16, (70, 70, 68), bias=5)
    return grunge(s.render(), 137, 0.16, rust=0.25, dirt_bottom=0.3, leaves=0.006)


def tarp_shelter():
    s = sc(160)
    for (x, y, h) in ((-44, 22, 26), (44, 22, 26), (-44, -18, 40), (44, -18, 40)):
        s.line([V(x, y, 0), V(x, y, h)], (96, 72, 48), 2)
    s.poly([V(-50, 28, 24), V(50, 28, 24), V(50, -20, 42), V(-50, -20, 42)], (72, 92, 60))
    for x in range(-44, 46, 14):
        s.line([V(x, 28, 24), V(x + 4, -20, 42)], (56, 72, 46), 1, bias=2)
    s.line([V(-50, 28, 24), V(-58, 38, 0)], (170, 160, 130), 1, bias=3)
    s.line([V(50, 28, 24), V(58, 38, 0)], (170, 160, 130), 1, bias=3)
    s.box(V(-20, 4, 7), (10, 8, 7), (140, 108, 70), bias=1)
    s.box(V(4, 8, 5), (8, 6, 5), (110, 116, 104), bias=1)
    s.box(V(-4, 0, 1.5), (26, 12, 1.5), (120, 110, 90), bias=0.5)                    # mattress
    s.cyl(V(28, 10, 0), 6, 12, (70, 92, 110), bias=1)
    return grunge(s.render(), 138, 0.14, dirt_bottom=0.2, leaves=0.006)


def scrap_barricade():
    s = sc(160)
    rng = random.Random(139)
    pieces = [((-40, 0, 10), (14, 6, 10), (120, 124, 124)), ((-16, 4, 8), (12, 4, 8), (128, 84, 54)),
              ((10, 0, 12), (10, 5, 12), (110, 92, 64)), ((34, 4, 9), (12, 5, 9), (76, 102, 118)),
              ((-28, 2, 22), (18, 4, 4), (96, 72, 48)), ((22, 2, 25), (16, 4, 3), (140, 110, 70))]
    for c, h, col in pieces:
        s.box(V(*c), h, col, bias=rng.uniform(0, 1))
    for x in (-48, 48):
        s.cyl(V(x, 10, 0), 7, 4, (32, 32, 32), bias=2)
        s.cyl(V(x, 10, 4), 7, 4, (36, 36, 36), bias=2.1)
    for x in range(-44, 46, 11):
        s.line([V(x, 8, 18), V(x + 6, 14, 30)], (70, 60, 50), 1, bias=3)         # spikes / rebar
    for i in range(40):
        t = i / 39
        a = t * math.pi * 16
        s.px(V(-48 + t * 96 + math.cos(a) * 1.5, 6 + math.sin(a) * 3, 32 + math.sin(a) * 2), (150, 152, 150), bias=4)
    return grunge(s.render(), 139, 0.18, rust=0.4, dirt_bottom=0.25)


def tire_wall():
    s = sc(150)
    for row in range(3):
        n = 6 - row
        for i in range(n):
            x = (i - (n - 1) / 2) * 15
            s.cyl(V(x, 0, row * 6), 7.5, 5.5, (34, 34, 34), bias=row)
            s.cyl(V(x, 0, row * 6 + 5.5), 3.5, 0.2, (18, 18, 18), bias=row + 0.5, edge=False)
    return grunge(s.render(), 140, 0.12, dirt_bottom=0.1, leaves=0.01)


def burnt_car():
    s = sc(156)
    body = (62, 44, 34)
    s.box(V(0, 0, 14), (46, 18, 8), body)
    s.box(V(-4, 0, 27), (24, 16, 5), (48, 36, 30), face_cols={'front': (20, 18, 16)})
    for (x, y) in ((-30, -18), (30, -18), (-30, 18), (30, 18)):
        s.box(V(x, y, 3), (6, 2, 3), (40, 30, 24), bias=-0.3)                       # rims
    s.box(V(38, 0, 16), (8, 14, 4), (30, 26, 22), bias=1)                            # gaping bonnet
    img = s.render()
    a = np.array(img).astype(float)
    A = a[..., 3] > 0
    rng = np.random.default_rng(141)
    rust = rng.random(A.shape) < 0.18
    a[A & rust, :3] = a[A & rust, :3] * 0.4 + np.array((126, 64, 32)) * 0.6
    soot = rng.random(A.shape) < 0.25
    a[A & soot, :3] *= 0.55
    return grunge(Image.fromarray(a.astype(np.uint8)), 141, 0.2, rust=0.3, dirt_bottom=0.3, leaves=0.01)


def graves():
    s = sc(150)
    for i, x in enumerate((-40, 0, 40)):
        s.box(V(x, 8, 2), (12, 16, 2), (78, 64, 48), face_cols={'top': (70, 58, 42)})
        s.box(V(x, -8, 14), (1.5, 1.5, 14), (104, 80, 54), bias=1)
        s.box(V(x, -8, 22), (7, 1.5, 1.4), (104, 80, 54), bias=1.1)
        if i != 1:
            for k in range(4):
                s.px(V(x - 4 + k * 3, 14, 4.5), [(200, 60, 50), (220, 200, 90), (230, 230, 220)][k % 3], bias=2)
    s.cyl(V(52, 18, 0), 2.5, 6, (160, 120, 60), bias=3)                            # candle jar
    return grunge(s.render(), 142, 0.12, dirt_bottom=0.1, leaves=0.02)


def warning_sign():
    s = sc(160)
    s.line([V(-14, 0, 0), V(-14, 0, 40)], (96, 72, 48), 2)
    s.line([V(14, 0, 0), V(14, 0, 40)], (96, 72, 48), 2)
    s.box(V(0, 1, 40), (22, 1, 10), (150, 124, 86), bias=1)
    img = s.render()
    d = ImageDraw.Draw(img)
    # red painted skull-ish mark and slashes: readable danger sign without text
    cx, cy = 96, 160 - 40 - 8
    d.ellipse([cx - 6, cy - 8, cx + 6, cy + 2], fill=(170, 40, 34, 255))
    d.rectangle([cx - 3, cy + 1, cx + 3, cy + 5], fill=(170, 40, 34, 255))
    d.point([(cx - 3, cy - 4), (cx + 2, cy - 4)], fill=(150, 124, 86, 255))
    d.line([(cx - 18, cy - 8), (cx - 12, cy + 6)], fill=(170, 40, 34, 255), width=2)
    d.line([(cx + 12, cy - 8), (cx + 18, cy + 6)], fill=(170, 40, 34, 255), width=2)
    return grunge(outline_img(img), 143, 0.14, dirt_bottom=0.1)


def rubble_pile():
    s = sc(150)
    rng = random.Random(144)
    s.poly([V(-50, 18, 0), V(50, 18, 0), V(30, -10, 18), V(-26, -12, 22)], (104, 98, 88))
    for _ in range(26):
        x, y = rng.uniform(-44, 44), rng.uniform(-8, 16)
        z = 16 * (1 - abs(x) / 50) * (1 - (y + 8) / 30) + rng.uniform(0, 4)
        col = rng.choice([(138, 80, 58), (150, 148, 138), (120, 116, 108), (112, 66, 50)])
        s.box(V(x, y, z + 2), (rng.uniform(2, 5), rng.uniform(1.5, 3), rng.uniform(1.5, 3)), col, bias=rng.uniform(0, 2))
    for _ in range(4):
        x = rng.uniform(-30, 30)
        s.line([V(x, 0, 10), V(x + rng.uniform(-8, 8), rng.uniform(-6, 6), 26)], (110, 70, 44), 1, bias=5)   # rebar
    return grunge(s.render(), 144, 0.18, rust=0.1, dirt_bottom=0.2, leaves=0.012)


def dead_tree():
    s = Scene(CELL, CELL, (96, 186))
    rng = random.Random(145)
    trunk = (70, 60, 50)

    def branch(p, d, length, width, depth):
        q = p + d * length
        s.line([p, q], trunk, max(1, int(width)), bias=depth)
        if depth > 4 or length < 6:
            return
        for k in range(rng.randint(2, 3)):
            nd = d + V(rng.uniform(-0.7, 0.7), rng.uniform(-0.4, 0.4), rng.uniform(-0.1, 0.35))
            nd = nd / np.linalg.norm(nd)
            branch(q, nd, length * rng.uniform(0.55, 0.75), width * 0.65, depth + 1)
    branch(V(0, 0, 0), V(0, 0, 1), 60, 5, 0)
    s.poly([V(-10, 6, 0), V(10, 6, 0), V(6, -4, 0), V(-6, -4, 0)], (60, 52, 40))
    return grunge(s.render(), 145, 0.12, dirt_bottom=0.05)


def bonfire():
    s = sc(150)
    for i in range(10):
        a = 2 * math.pi * i / 10
        s.ball(V(math.cos(a) * 16, math.sin(a) * 10, 3), 4, (110, 106, 98), bias=1 if math.sin(a) > 0 else 0)
    for a in (0.3, 1.4, 2.6):
        s.hcyl(V(math.cos(a) * 12, math.sin(a) * 7, 4), V(-math.cos(a) * 10, -math.sin(a) * 6, 8), 2.2, (96, 66, 40), bias=2)
    for k, (dx, dz, r, col) in enumerate([(-2, 9, 5, (240, 140, 44)), (3, 12, 4.5, (250, 190, 70)), (0, 16, 3, (255, 232, 150))]):
        s.ball(V(dx, 0, dz), r, col, bias=5 + k)
    s.line([V(-24, 0, 0), V(-24, 0, 26)], (70, 60, 50), 1, bias=3)
    s.line([V(24, 0, 0), V(24, 0, 26)], (70, 60, 50), 1, bias=3)
    s.line([V(-24, 0, 26), V(24, 0, 26)], (70, 60, 50), 1, bias=3)
    s.cyl(V(0, 0, 18), 5, 5, (60, 62, 60), bias=6)                                   # hanging pot
    s.box(V(-36, 12, 4), (7, 4, 4), (104, 80, 54), bias=1)                          # log seats
    s.box(V(36, 12, 4), (7, 4, 4), (104, 80, 54), bias=1)
    return grunge(s.render(), 146, 0.12, dirt_bottom=0.1)


def rain_tank():
    s = sc(160)
    s.box(V(0, 0, 3), (18, 16, 3), (104, 80, 54))                                  # pallet
    s.box(V(0, 0, 24), (16, 14, 18), (190, 196, 190), face_cols={'front': (176, 182, 176)})
    for x in (-16, 0, 16):
        s.line([V(x, 14.2, 6), V(x, 14.2, 42)], (120, 124, 124), 1, bias=2)
    for z in (6, 24, 42):
        s.line([V(-16, 14.2, z), V(16, 14.2, z)], (120, 124, 124), 1, bias=2)
    s.box(V(0, 0, 43), (6, 6, 1), (70, 70, 68), bias=3)
    s.line([V(0, 0, 44), V(0, -10, 54), V(-30, -10, 54)], (110, 112, 110), 2, bias=4)   # gutter from a roof
    s.box(V(10, 15, 10), (2, 1, 2), (180, 50, 40), bias=3)
    s.cyl(V(24, 18, 0), 5, 10, (70, 92, 110), bias=2)                                # bucket
    img = s.render()
    a = np.array(img).astype(float)
    water = (a[..., 3] > 0) & (a[..., 0] > 160) & (a[..., 1] > 160)
    rng = np.random.default_rng(147)
    lvl = rng.random(water.shape) < 0.08
    a[water & lvl, :3] = (110, 140, 150)
    return grunge(Image.fromarray(a.astype(np.uint8)), 147, 0.12, dirt_bottom=0.25)


def junk_pile():
    s = sc(150)
    s.box(V(-26, 0, 16), (8, 7, 16), (196, 196, 186))                              # fridge
    s.box(V(-26, 7.3, 18), (6, 0.3, 1), (120, 120, 116), edge=False, bias=1)
    s.box(V(6, 6, 3), (22, 10, 3), (150, 130, 110), bias=0.5)                      # mattress
    for i in range(5):
        s.box(V(i * 8 - 4, 4, 7 + i % 2), (3, 2, 2), (110, 90, 70), bias=1)
    for (x, y, c) in ((30, 8, (50, 56, 60)), (38, -2, (30, 32, 34)), (20, 16, (60, 70, 50))):
        s.ball(V(x, y, 5), 6, c, bias=2)                                               # trash bags
    s.cyl(V(-44, 10, 0), 6, 4, (32, 32, 32), bias=1)
    s.line([V(-10, 0, 10), V(10, -8, 26)], (120, 110, 90), 1, bias=3)
    return grunge(s.render(), 148, 0.16, rust=0.2, dirt_bottom=0.2, leaves=0.012)


# ------------------------------------------------------------- street life --
def pole_wood():
    s = Scene(CELL, CELL, (96, 186))
    s.cyl(V(0, 0, 0), 3.2, 140, (98, 76, 54))
    for z in range(10, 140, 16):
        s.line([V(-3, 3, z), V(3, 3, z + 1)], (80, 62, 44), 1, bias=1)
    s.box(V(0, 0, 128), (22, 2, 2), (92, 72, 50), bias=2)                       # crossarm
    for x in (-18, -6, 6, 18):
        s.cyl(V(x, 0, 130), 1.4, 4, (210, 210, 200), bias=3)                    # insulators
    s.line([V(0, 0, 118), V(14, 0, 128)], (80, 62, 44), 1, bias=2)               # brace
    s.box(V(0, 3.4, 46), (4, 0.6, 6), (180, 176, 160), bias=3)                   # notice nailed on
    s.box(V(0, 3.4, 60), (3, 0.6, 3), (200, 180, 80), bias=3)
    return grunge(s.render(), 149, 0.14, dirt_bottom=0.1, leaves=0.004)


def pole_concrete():
    s = Scene(CELL, CELL, (96, 186))
    s.box(V(0, 0, 70), (3, 3, 70), (140, 138, 128))
    for z in range(8, 140, 10):
        s.px(V(0, 3.2, z), (100, 100, 94), bias=1)
    s.box(V(0, 0, 136), (22, 2, 1.6), (120, 120, 112), bias=2)
    for x in (-18, -6, 6, 18):
        s.cyl(V(x, 0, 137), 1.4, 4, (210, 210, 200), bias=3)
    s.line([V(0, 0, 112), V(0, 16, 118), V(0, 22, 116)], (70, 70, 70), 1, bias=3)  # lamp arm
    s.box(V(0, 22, 114), (4, 3, 1.5), (60, 62, 60), bias=4)
    s.box(V(0, 3.4, 30), (4, 0.6, 5), (150, 60, 44), bias=3)                     # warning plate
    return grunge(s.render(), 150, 0.12, rust=0.12, dirt_bottom=0.1)


def bus_stop():
    s = sc(160)
    s.box(V(0, -14, 2), (44, 16, 2), (120, 118, 110))
    s.box(V(0, -26, 22), (40, 1.5, 20), (80, 110, 120), bias=1)                  # back wall (glass)
    s.box(V(-40, -12, 22), (1.5, 14, 20), (70, 72, 72), bias=1)
    s.box(V(40, -12, 22), (1.5, 14, 20), (70, 72, 72), bias=1)
    s.poly([V(-44, 4, 44), V(44, 4, 44), V(44, -28, 46), V(-44, -28, 46)], (126, 60, 44), bias=3)
    s.box(V(0, -18, 10), (30, 5, 1.2), (110, 84, 56), bias=2)                    # bench
    s.box(V(-20, -24.2, 24), (10, 0.3, 8), (206, 196, 160), bias=2)              # timetable / posters
    s.box(V(10, -24.2, 26), (8, 0.3, 6), (170, 70, 50), bias=2)
    s.line([V(48, 6, 0), V(48, 6, 40)], (70, 70, 70), 1, bias=2)
    s.box(V(48, 6, 42), (6, 1, 6), (220, 200, 90), bias=3)
    img = s.render()
    a = np.array(img).astype(float)
    glass = (a[..., 2] > a[..., 0] + 20) & (a[..., 3] > 0)
    rng = np.random.default_rng(151)
    broken = glass & (rng.random(glass.shape) < 0.35)
    a[broken, 3] = 0
    return grunge(Image.fromarray(a.astype(np.uint8)), 151, 0.14, rust=0.2, dirt_bottom=0.2, leaves=0.01)


def kiosk():
    s = sc(166)
    s.box(V(0, 0, 22), (26, 18, 22), (150, 140, 110), face_cols={'front': (160, 150, 118)})
    s.box(V(0, 18.3, 26), (18, 0.3, 10), (40, 50, 56), edge=False, bias=1)       # shutter window
    for z in range(17, 36, 2):
        s.line([V(-18, 18.6, z), V(18, 18.6, z)], (110, 104, 90), 1, bias=2)
    s.poly([V(-30, 24, 44), V(30, 24, 44), V(30, -20, 50), V(-30, -20, 50)], (70, 104, 84), bias=3)
    s.box(V(0, 18.6, 46), (22, 0.3, 3), (190, 60, 44), bias=4)                  # sign band
    s.box(V(-20, 22, 6), (5, 4, 6), (104, 80, 54), bias=2)
    s.cyl(V(22, 24, 0), 5, 10, (70, 92, 110), bias=2)
    return grunge(s.render(), 152, 0.16, rust=0.25, dirt_bottom=0.25, leaves=0.008)


def swing_set():
    s = sc(160)
    col = (170, 60, 44)
    for x in (-36, 36):
        s.line([V(x - 8, 10, 0), V(x, 0, 40)], col, 2)
        s.line([V(x + 8, -10, 0), V(x, 0, 40)], col, 2)
    s.line([V(-36, 0, 40), V(36, 0, 40)], col, 2, bias=1)
    for x, tilt in ((-14, 0), (14, 6)):
        s.line([V(x - 4, 0, 40), V(x - 4, tilt, 14)], (70, 70, 70), 1, bias=2)
        s.line([V(x + 4, 0, 40), V(x + 4, tilt, 14)], (70, 70, 70), 1, bias=2)
        s.box(V(x, tilt, 13), (6, 3, 1), (110, 84, 56), bias=3)
    return grunge(s.render(), 153, 0.1, rust=0.45, dirt_bottom=0.05, leaves=0.01)


def dog_kennel():
    s = sc(150)
    s.box(V(0, 0, 10), (14, 12, 10), (110, 84, 56))
    s.poly([V(-17, 14, 18), V(17, 14, 18), V(17, 0, 28), V(-17, 0, 28)], (90, 96, 88), bias=1)
    s.poly([V(-17, -14, 18), V(17, -14, 18), V(17, 0, 28), V(-17, 0, 28)], (80, 84, 78), bias=0.5)
    s.box(V(0, 12.3, 7), (5, 0.3, 6), (26, 22, 18), edge=False, bias=2)
    s.cyl(V(24, 14, 0), 4, 2, (130, 130, 126), bias=2)                         # bowl
    s.line([V(14, 0, 4), V(30, 6, 0), V(40, 14, 0)], (90, 90, 88), 1, bias=2)   # chain
    return grunge(s.render(), 154, 0.14, dirt_bottom=0.2, leaves=0.01)


def wheelbarrow():
    s = sc(150)
    s.hexa([V(-14, -8, 8), V(-12, -6, 18), V(-14, 8, 8), V(-12, 6, 18), V(10, -6, 8), V(16, -8, 18), V(10, 6, 8), V(16, 8, 18)], (90, 110, 96))
    s.cyl(V(20, 0, 0), 5, 2, (32, 32, 32), bias=1)
    for y in (-6, 6):
        s.line([V(-14, y, 10), V(-30, y, 12)], (104, 80, 54), 1, bias=1)
        s.line([V(-10, y, 8), V(-10, y, 0)], (70, 70, 70), 1, bias=1)
    for i in range(5):
        s.ball(V(-4 + i * 4, (i % 2) * 3 - 1, 19), 2.5, (110, 96, 70), bias=2)   # potatoes / coal
    return grunge(s.render(), 155, 0.14, rust=0.3, dirt_bottom=0.1)


def bicycle():
    s = sc(150)
    for x in (-16, 16):
        pts = [V(x + math.cos(a) * 9, 0, 9 + math.sin(a) * 9) for a in np.linspace(0, 2 * math.pi, 17)]
        s.line(pts, (30, 30, 30), 1)
    s.line([V(-16, 0, 9), V(-2, 0, 20), V(10, 0, 20), V(16, 0, 9)], (110, 50, 40), 2, bias=1)
    s.line([V(-2, 0, 20), V(0, 0, 9), V(-16, 0, 9)], (110, 50, 40), 2, bias=1)
    s.line([V(10, 0, 20), V(12, 0, 26), V(8, 0, 27)], (60, 60, 60), 1, bias=2)
    s.box(V(-4, 0, 22), (4, 1.5, 1), (30, 30, 30), bias=2)
    s.box(V(-16, 0, 14), (6, 3, 3), (104, 84, 60), bias=2)                       # rack crate
    return grunge(s.render(), 156, 0.1, rust=0.3, dirt_bottom=0.05)


def poster_board():
    s = sc(160)
    for x in (-24, 24):
        s.line([V(x, 0, 0), V(x, 0, 36)], (96, 72, 48), 2)
    s.box(V(0, 0.5, 30), (28, 1, 12), (110, 84, 56), bias=1)
    rng = random.Random(157)
    for i in range(7):
        x, z = rng.uniform(-22, 20), rng.uniform(22, 38)
        c = rng.choice([(214, 206, 180), (200, 196, 170), (190, 180, 120), (180, 80, 60)])
        s.box(V(x, 1.8, z), (rng.uniform(3, 6), 0.2, rng.uniform(2.5, 4)), c, edge=False, bias=2 + i * 0.01)
    s.poly([V(-30, 4, 43), V(30, 4, 43), V(30, -2, 46), V(-30, -2, 46)], (90, 96, 88), bias=3)
    return grunge(s.render(), 157, 0.12, dirt_bottom=0.1, leaves=0.006)


def oil_drums():
    s = sc(150)
    cols = [(60, 90, 70), (130, 60, 40), (70, 92, 110), (140, 110, 50), (60, 90, 70)]
    pos = [(-30, -6), (-12, -8), (6, -6), (-22, 8), (-4, 8)]
    for (x, y), c in zip(pos, cols):
        s.cyl(V(x, y, 0), 7, 17, c, bands=((5, dark_(c)), (12, dark_(c))), bias=(y + 10) * 0.1)
    s.hcyl(V(18, 10, 6.5), V(40, 12, 6.5), 6.5, (110, 70, 44), bias=2)          # one on its side
    return grunge(s.render(), 158, 0.14, rust=0.4, dirt_bottom=0.15)


def dark_(c):
    return tuple(int(v * 0.72) for v in c)


def firewood_rack():
    s = sc(150)
    for x in (-34, 34):
        s.line([V(x, 0, 0), V(x, 0, 30)], (96, 72, 48), 2)
    s.poly([V(-38, 10, 30), V(38, 10, 30), V(38, -8, 36), V(-38, -8, 36)], (104, 96, 86), bias=2)
    for row in range(5):
        for i in range(11):
            s.hcyl(V(-32 + i * 6.2, -8, 3 + row * 5), V(-32 + i * 6.2, 6, 3 + row * 5), 2.4,
                   (120 - (i * 7 % 20), 86 - (i * 5 % 14), 54), bias=row * 0.1)
    s.box(V(44, 8, 4), (5, 5, 4), (110, 84, 56), bias=1)                         # chopping block
    s.line([V(44, 8, 8), V(48, 10, 16)], (80, 80, 80), 1, bias=2)
    return grunge(s.render(), 159, 0.14, dirt_bottom=0.1, leaves=0.01)


def cart():
    s = sc(150)
    s.box(V(0, 0, 12), (22, 12, 5), (110, 84, 56))
    for x in range(-20, 22, 6):
        s.line([V(x, 12.2, 8), V(x, 12.2, 16)], (80, 60, 40), 1, bias=1)
    for y in (-12, 12):
        s.cyl(V(-6, y, 0), 9, 1.5, (60, 50, 40), bias=0.5 if y > 0 else -0.5)
    s.line([V(22, -6, 12), V(46, -6, 4)], (96, 72, 48), 2, bias=2)
    s.line([V(22, 6, 12), V(46, 6, 4)], (96, 72, 48), 2, bias=2)
    for i in range(4):
        s.ball(V(-12 + i * 7, (i % 2) * 4 - 2, 19), 4, [(170, 150, 110), (150, 130, 96)][i % 2], bias=2)   # sacks
    return grunge(s.render(), 160, 0.14, dirt_bottom=0.1, leaves=0.008)


FNS = [market_stall, market_stall_b, water_tower, garden_beds, laundry_line, field_kitchen,
       platform_canopy, radio_mast, water_point, chicken_coop, long_table, fire_barrel,
       sandbag_nest, hesco_row, army_tent, flag_pole, searchlight_tower, ammo_bunker,
       btr, jersey_blocks,
       jib_crane, scrap_heap, wind_turbine, fuel_station, car_on_blocks, furnace,
       solar_rig, container_shop,
       medical_tent, decon_frame, triage_canopy, herb_beds, incinerator, oxygen_rack,
       ambulance, wash_station,
       shanty, tarp_shelter, scrap_barricade, tire_wall, burnt_car, graves,
       warning_sign, rubble_pile, dead_tree, bonfire, rain_tank, junk_pile,
       pole_wood, pole_concrete, bus_stop, kiosk, swing_set, dog_kennel,
       wheelbarrow, bicycle, poster_board, oil_drums, firewood_rack, cart]
assert len(FNS) == len(KINDS)


# ---------------------------------------------------------------- walls --
WALL_W, WALL_H = 128, 72
VW, VH = 40, 128
GATE_W, GATE_H = 64, 112


def _crop_h(s, oy):
    img = s.render()
    return img


def wall_h(f):
    """seamless horizontal perimeter tile (content spans the full 128 px width)."""
    s = Scene(WALL_W + 64, WALL_H, (32 + WALL_W // 2, WALL_H - 8))
    L = WALL_W // 2 + 32
    if f == 'perron':
        # salvaged plank palisade with a painted strip and patched corrugated sheet
        for i, x in enumerate(range(-L, L, 8)):
            h = 40 + (i * 7 % 5)
            col = [(126, 94, 62), (116, 86, 58), (138, 104, 68), (104, 80, 56)][i % 4]
            s.box(V(x + 4, 0, h / 2), (3.7, 3, h / 2), col, bias=0)
        s.line([V(-L, 3.2, 14), V(L, 3.2, 14)], WOOD_D, 2, bias=2)
        s.line([V(-L, 3.2, 32), V(L, 3.2, 32)], WOOD_D, 2, bias=2)
        s.box(V(-8, 3.6, 24), (18, 0.3, 9), (120, 120, 112), edge=False, bias=3)
        s.box(V(-8, 3.8, 24), (16, 0.2, 1), RED_CLOTH, edge=False, bias=4)
    elif f == 'rubezh':
        # stacked FBS concrete blocks, olive band, barbed wire on posts
        for row in range(3):
            off = 16 if row % 2 else 0
            for x in range(-L - 16, L + 16, 32):
                s.box(V(x + off, 0, 6 + row * 12), (15.6, 6, 5.8), (150 - row * 4, 148 - row * 4, 138 - row * 4))
        s.box(V(0, 6.3, 20), (L, 0.3, 2), OLIVE, edge=False, bias=2)
        for x in range(-L, L + 1, 32):
            s.line([V(x, 0, 36), V(x, 0, 50)], (70, 70, 66), 1, bias=3)
        for z in (41, 47):
            s.line([V(-L, 0, z), V(L, 0, z)], (150, 150, 146), 1, bias=3)
            for x in range(-L, L, 6):
                s.px(V(x + 3, 0, z + 1), (170, 170, 166), bias=4)
    elif f == 'mechanics':
        # corrugated sheet on steel posts, hazard band, rust
        for x in range(-L, L, 4):
            col = (132, 136, 136) if (x // 4) % 2 else (112, 116, 118)
            s.box(V(x + 2, 0, 22), (2, 2, 22), col, edge=False)
        s.line([V(-L, 2.2, 1), V(L, 2.2, 1)], (60, 60, 58), 1, bias=2)
        s.line([V(-L, 2.2, 44), V(L, 2.2, 44)], (70, 72, 72), 2, bias=2)
        for x in range(-L, L + 1, 32):
            s.box(V(x, 2.6, 23), (1.8, 1, 23), (70, 72, 74), bias=3)
        for x in range(-L, L, 16):
            s.poly([V(x, 2.4, 4), V(x + 8, 2.4, 4), V(x + 12, 2.4, 9), V(x + 4, 2.4, 9)], HAZARD, bias=3)
    else:
        # low whitewashed plinth + mesh panels, green-grey posts
        s.box(V(0, 0, 5), (L, 4, 5), (186, 188, 180))
        for x in range(-L, L + 1, 32):
            s.box(V(x, 0, 24), (2, 2, 16), (104, 124, 114), bias=2)
        for x in range(-L, L, 4):
            s.line([V(x, 0, 10), V(x + 4, 0, 38)], (150, 156, 150), 1, bias=1)
            s.line([V(x + 4, 0, 10), V(x, 0, 38)], (150, 156, 150), 1, bias=1)
        s.line([V(-L, 0, 38), V(L, 0, 38)], (104, 124, 114), 2, bias=2)
        s.line([V(-L, 0.2, 10), V(L, 0.2, 10)], (104, 124, 114), 1, bias=2)
        s.box(V(0, 4.3, 5), (L, 0.2, 1), (110, 150, 130), edge=False, bias=2)
    img = s.render()
    img = img.crop((32, 0, 32 + WALL_W, WALL_H))
    seed = FACTIONS.index(f) + 201
    return grunge(img, seed, 0.12, rust=0.22 if f in ('mechanics', 'rubezh') else 0.04,
                  dirt_bottom=0.22, leaves=0.004)


def wall_v(f):
    """vertical perimeter tile, seen from above: wall cap + posts, seamless in y."""
    ext = 200
    s = Scene(VW, VH + 160, (VW // 2, (VH + 160) // 2))
    if f == 'perron':
        for i, y in enumerate(range(-ext, ext, 8)):
            col = [(126, 94, 62), (116, 86, 58), (138, 104, 68), (104, 80, 56)][i % 4]
            s.box(V(0, y + 4, 38), (7, 3.8, 2), col, edge=False)
        s.line([V(-5, -ext, 36), V(-5, ext, 36)], WOOD_D, 1, bias=2)
    elif f == 'rubezh':
        for y in range(-ext, ext, 32):
            s.box(V(0, y + 16, 34), (9, 15.6, 2), (150, 148, 138))
        for y in range(-ext, ext, 58):
            s.cyl(V(0, y, 36), 1.2, 10, (70, 70, 66), bias=2)
        s.line([V(-3, -ext, 44), V(-3, ext, 44)], (150, 150, 146), 1, bias=3)
        s.line([V(3, -ext, 42), V(3, ext, 42)], (150, 150, 146), 1, bias=3)
    elif f == 'mechanics':
        for y in range(-ext, ext, 4):
            s.box(V(0, y + 2, 44), (5, 2, 1), (132, 136, 136) if (y // 4) % 2 else (112, 116, 118), edge=False)
        for y in range(-ext, ext, 58):
            s.box(V(2, y, 42), (2, 2, 4), (70, 72, 74), bias=2)
    else:
        for y in range(-ext, ext, 4):
            s.box(V(0, y + 2, 10), (7, 2, 1), (186, 188, 180), edge=False)
        s.line([V(0, -ext, 38), V(0, ext, 38)], (104, 124, 114), 2, bias=2)
        for y in range(-ext, ext, 58):
            s.cyl(V(0, y, 10), 2, 30, (104, 124, 114), bias=2)
    img = s.render(outline=False)
    top = 80
    img = img.crop((0, top, VW, top + VH))
    # side outline only (keeps the tile seamless vertically)
    a = np.array(img)
    A = a[..., 3] > 0
    e = np.zeros_like(A)
    e[:, 1:] |= A[:, :-1] & ~A[:, 1:]
    e[:, :-1] |= A[:, 1:] & ~A[:, :-1]
    a[e] = (18, 16, 14, 255)
    img = Image.fromarray(a)
    return grunge(img, FACTIONS.index(f) + 211, 0.12, rust=0.2 if f in ('mechanics', 'rubezh') else 0.03,
                  dirt_bottom=0.0)


def gate_post(f):
    s = Scene(GATE_W, GATE_H + 40, (GATE_W // 2, GATE_H + 30))
    if f == 'perron':
        s.box(V(0, 0, 36), (7, 6, 36), (118, 88, 58))
        s.box(V(0, 0, 76), (10, 8, 4), (98, 72, 48))
        s.ball(V(0, 7, 60), 3, (250, 210, 130), bias=3)
        s.box(V(0, 6.3, 30), (5, 0.3, 12), RED_CLOTH, edge=False, bias=2)
    elif f == 'rubezh':
        for z in range(0, 50, 5):
            s.box(V(0, 0, z + 2.4), (12, 10, 2.4), SAND if (z // 5) % 2 else (146, 128, 90))
        s.box(V(0, 0, 60), (4, 4, 10), (84, 86, 84))
        s.ball(V(0, 5, 72), 3, (250, 240, 200), bias=3)
    elif f == 'mechanics':
        s.box(V(0, 0, 40), (8, 8, 40), HAZARD)
        for z in range(4, 80, 10):
            s.poly([V(-8, 8.2, z), V(8, 8.2, z + 5), V(8, 8.2, z + 9), V(-8, 8.2, z + 4)], (40, 40, 38), bias=2)
        s.ball(V(0, 0, 84), 3, (250, 170, 60), bias=3)
    else:
        s.box(V(0, 0, 34), (7, 7, 34), (190, 192, 184))
        s.box(V(0, 7.3, 50), (5, 0.3, 5), (230, 230, 222), edge=False, bias=2)
        s.box(V(0, 7.5, 50), (4, 0.2, 1.2), CROSS, edge=False, bias=3)
        s.box(V(0, 7.5, 50), (1.2, 0.2, 4), CROSS, edge=False, bias=3)
        s.ball(V(0, 0, 72), 3, (220, 240, 230), bias=3)
    img = s.render()
    return fit_canvas(grunge(img, FACTIONS.index(f) + 221, 0.1, rust=0.1, dirt_bottom=0.2), GATE_W, GATE_H, 'bottom')


def build_all(P):
    cols = 6
    rows = (len(FNS) + cols - 1) // cols
    out = Image.new('RGBA', (CELL * cols, CELL * rows))
    for i, fn in enumerate(FNS):
        out.alpha_composite(fit_canvas(fn(), CELL, CELL, 'bottom'), ((i % cols) * CELL, (i // cols) * CELL))
    out.save(os.path.join(P, 'settlement_props_v1.png'))
    walls = Image.new('RGBA', (WALL_W + VW + GATE_W, max(WALL_H, VH, GATE_H) * len(FACTIONS)))
    row_h = max(WALL_H, VH, GATE_H)
    for r, f in enumerate(FACTIONS):
        walls.alpha_composite(wall_h(f), (0, r * row_h))
        walls.alpha_composite(wall_v(f), (WALL_W, r * row_h))
        walls.alpha_composite(gate_post(f), (WALL_W + VW, r * row_h))
    walls.save(os.path.join(P, 'settlement_walls_v1.png'))
    return out, walls


if __name__ == '__main__':
    import sys
    build_all(sys.argv[1] if len(sys.argv) > 1 else '.')
    print('settlement art ok')
