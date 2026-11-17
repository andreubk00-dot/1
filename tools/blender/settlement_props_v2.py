"""OSTATOK 1.57: the scrap heap and the rubble pile of the faction bases, in Blender.

settlement_props_v1 (HD twin art/world_hd/x2/settlement_props_v1.png, 6
columns of 384 x 384 px cells) drew the scrap heap as a flat rusty triangle
on four wheels and the rubble pile as a beige cone. Both are modelled here and
fitted over the old sprites (same footprint and ground line).

    python3.13 tools/blender/settlement_props_v2.py <project_dir>

Writes art/world_hd/settlement_props_v2.png (same layout as the x2 twin).
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

from PIL import Image

from bk import box, cyl, mat, tube, sphere
from poi_props_v2 import refit

KINDS = [
    "market_stall", "market_stall_b", "water_tower", "garden_beds", "laundry_line", "field_kitchen",
    "platform_canopy", "radio_mast", "water_point", "chicken_coop", "long_table", "fire_barrel",
    "sandbag_nest", "hesco_row", "army_tent", "flag_pole", "searchlight_tower", "ammo_bunker",
    "btr", "jersey_blocks",
    "jib_crane", "scrap_heap", "wind_turbine", "fuel_station", "car_on_blocks", "furnace",
    "solar_rig", "container_shop",
    "medical_tent", "decon_frame", "triage_canopy", "herb_beds", "incinerator", "oxygen_rack",
    "ambulance", "wash_station",
    "shanty", "tarp_shelter", "scrap_barricade", "tire_wall", "burnt_car", "graves",
    "warning_sign", "rubble_pile", "dead_tree", "bonfire", "rain_tank", "junk_pile",
]


def scrap_heap():
    rnd = random.Random(21)
    rust = [mat(c, rough=0.8, metal=0.4, grime=0.5, dust=0.2) for c in ((132, 70, 40), (110, 58, 36), (150, 92, 54))]
    paint = [mat(c, rough=0.6, metal=0.3, grime=0.5) for c in ((70, 96, 120), (150, 40, 34), (196, 192, 180), (86, 104, 70))]
    tyre = mat((28, 28, 30), rough=0.85)
    # a low mound of sheets, doors and panels leaning on each other
    for i in range(16):
        x, y = rnd.uniform(-22, 22), rnd.uniform(-9, 9)
        h = 6 + 9 * (1 - abs(x) / 26)
        m = (paint if rnd.random() < 0.4 else rust)[rnd.randrange(3)]
        box((x, y, rnd.uniform(1.5, h)), (rnd.uniform(3, 7), rnd.uniform(0.3, 3), rnd.uniform(2, 5)), m, bevel=0.2,
            rot=(rnd.uniform(-35, 35), rnd.uniform(-40, 40), rnd.uniform(0, 180)))
    box((-6, 2, 9), (3.4, 3, 6), mat((214, 210, 196), rough=0.5, grime=0.4), bevel=0.6, rot=(0, 24, 10))   # an old fridge
    for (x, y) in ((16, 6), (19, 3), (-18, 7)):
        cyl((x, y, 1.6), 3.6, 2.4, tyre, axis='z', bevel=0.6, verts=20)
        cyl((x, y, 2.9), 1.7, 0.3, mat((60, 60, 60), rough=0.6, metal=0.5), axis='z', bevel=0.1, verts=14)
    pipe = mat((96, 92, 86), rough=0.5, metal=0.6, grime=0.5)
    for i in range(4):
        x = rnd.uniform(-16, 12)
        tube([(x, -6, 1), (x + 16, 5, rnd.uniform(5, 11))], 0.7, pipe)


def rubble_pile():
    rnd = random.Random(43)
    brick = [mat(c, rough=0.9, grime=0.3, dust=0.4) for c in ((150, 70, 52), (130, 60, 44), (166, 88, 64))]
    conc = [mat(c, rough=0.95, dust=0.5) for c in ((150, 148, 138), (128, 126, 118), (170, 166, 154))]
    rebar = mat((96, 60, 40), rough=0.6, metal=0.5)
    for i in range(70):
        a = rnd.uniform(0, math.tau)
        d = rnd.random() ** 0.7
        x, y = math.cos(a) * d * 24, math.sin(a) * d * 11
        z = (1 - d) * 11 + rnd.uniform(0.5, 2)
        if rnd.random() < 0.6:
            box((x, y, z), (1.9, 0.9, 0.9), brick[rnd.randrange(3)], bevel=0.15, rot=(0, rnd.uniform(-30, 30), rnd.uniform(0, 180)))
        else:
            box((x, y, z), (rnd.uniform(1.5, 4), rnd.uniform(1.5, 3), rnd.uniform(0.8, 2)), conc[rnd.randrange(3)], bevel=0.3,
                rot=(rnd.uniform(-25, 25), rnd.uniform(-25, 25), rnd.uniform(0, 180)))
    box((4, -1, 6), (8, 4, 1.4), conc[0], bevel=0.3, rot=(18, -12, 20))               # a slab with rebar
    for k in range(3):
        tube([(1 + k * 3, -2, 7), (3 + k * 3.5, -5, 14 + k)], 0.3, rebar, verts=6)
    for i in range(40):                                                                 # dust and grit round the foot
        a = rnd.uniform(0, math.tau)
        sphere((math.cos(a) * rnd.uniform(18, 27), math.sin(a) * rnd.uniform(8, 12), 0.4), rnd.uniform(0.5, 1.1), conc[rnd.randrange(3)])


def build(P):
    src = Image.open(os.path.join(P, 'art', 'world_hd', 'x2', 'settlement_props_v1.png')).convert('RGBA')
    sheet = src.copy()
    refit(src, sheet, (("scrap_heap", scrap_heap), ("rubble_pile", rubble_pile)), KINDS, 384, 384)
    sheet.save(os.path.join(P, 'art', 'world_hd', 'settlement_props_v2.png'))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
