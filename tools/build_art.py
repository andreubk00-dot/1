"""OSTATOK 0.80.0 — rebuilds ALL art: items + survivor rig + infected rig.
Usage: python3 tools/build_art.py <project_dir>
"""
import sys, os, math, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from pxart import Canvas, trim
from items import ITEMS
import survivor3d
import infected3d
import environment_art
import exterior_art
import atmosphere_art

P = sys.argv[1]
src = open(os.path.join(P, 'main_script_mod.gd'), encoding='utf-8').read()

def table(name):
    body = re.search(r'var %s = \{(.*?)\n\}' % name, src, re.S).group(1)
    return body

def rects(name):
    return {k: tuple(map(int, v.split(','))) for k, v in re.findall(r'"(\w+)":Rect2i\(([\d,]+)\)', table(name))}

def cells(name):
    return {k: tuple(map(int, v.split(','))) for k, v in re.findall(r'"(\w+)":Vector2i\(([\d,]+)\)', table(name))}

def render_fit(i, w, h):
    box, fn = ITEMS[i]; c = Canvas(w, h, box, pad=1); fn(c); c.outline(); return c.image()

def render_native(i, w, h):
    box, fn = ITEMS[i]; c = Canvas(w, h, (0, 0, w, h), scale=1.0, origin=(0, 0, 0, 0)); fn(c); c.outline(); return c.image()

# 1. inventory icons (exact native regions, no scaling in UI)
inv = Image.new('RGBA', (256, 176))
for k, (x, y, w, h) in rects('inventory_icon_regions').items():
    inv.alpha_composite(render_fit(k, w, h), (x, y))
inv.save(os.path.join(P, 'inventory_icons_v25.png'))

mel = Image.new('RGBA', (80, 72))
for k, (x, y, w, h) in rects('melee_icon_regions').items():
    mel.alpha_composite(render_fit(k, w, h), (x, y))
mel.save(os.path.join(P, 'melee_inventory_v11.png'))

# 2. world loot at native world pixel size (sprite scale 1.0 in code)
LOOT = {'makarov': 13, 'shotgun': 26, 'akm': 26, 'combat_knife': 13, 'steel_pipe': 16, 'fire_axe': 18,
        'light_jacket': 15, 'police_vest': 15, 'field_backpack': 15, 'cap': 10, 'water': 15, 'dirty_water': 15,
        'herbal_tea': 14, 'antiseptic': 14, 'water_filter': 14, 'flashlight': 12, 'makarov_extmag': 11,
        'suppressor': 13, 'shotgun_exttube': 13, 'akm_extmag': 13, 'muzzle_brake': 9, 'repair_kit': 16,
        'firewood': 14, 'canned_meat': 11, 'hot_meal': 11, 'grain': 11, 'cloth': 11, 'scrap': 10, 'tape': 9,
        'bandage': 9, 'sterile_bandage': 10, 'painkillers': 9, 'antibiotics': 10, 'herbs': 10,
        'ammo_9x18': 9, 'ammo_12g': 9, 'ammo_762': 9}
LYING = {'flashlight', 'makarov_extmag', 'suppressor', 'shotgun_exttube', 'akm_extmag'}

def loot(i):
    box, fn = ITEMS[i]; dw, dh = box[2] - box[0], box[3] - box[1]; s = LOOT[i] / max(dw, dh)
    w, h = int(math.ceil(dw * s)) + 3, int(math.ceil(dh * s)) + 3
    ang = 0.0
    if i in LYING:
        w, h, ang = h, w, -math.pi / 2
    c = Canvas(w, h, box, scale=s, angle=ang, seed=11); fn(c); c.outline(); return trim(c.image())

lt = Image.new('RGBA', (240, 280))
for k, (cx, cy) in cells('loot_icon_cells').items():
    im = loot(k)
    lt.alpha_composite(im, (cx * 40 + (40 - im.width) // 2, cy * 40 + (40 - im.height) // 2))
lt.save(os.path.join(P, 'loot_sprites_v23.png'))

# 3. large models (HUD / quickbar / legacy held path) in the original row contracts
wm = Image.new('RGBA', (144, 144))
for r, i in enumerate(('makarov', 'shotgun', 'akm')):
    wm.alpha_composite(render_native(i, 144, 48), (0, r * 48))
wm.save(os.path.join(P, 'weapon_models_v19.png'))
mm = Image.new('RGBA', (96, 96))
for r, i in enumerate(('combat_knife', 'steel_pipe', 'fire_axe')):
    mm.alpha_composite(render_native(i, 96, 32), (0, r * 32))
mm.save(os.path.join(P, 'melee_models_v18.png'))

# 4. survivor: original 3D rig, 7 weapon variants x 21 clips x 8 dirs
survivor3d.build_all(P)

# 5. infected: four original variants, 8 directions, 12-frame gait + 8-frame attack
infected3d.build_all(P)

# 6. environment: native floor/wall/trim/detail atlases
environment_art.build_all(P)
exterior_art.build_all(P)
atmosphere_art.build_all(P)
print('ok')
