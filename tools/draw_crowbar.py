"""dev72: the crowbar - a dark steel bar with a gooseneck claw at one end and a
flat bent chisel at the other - drawn into the three atlases a melee weapon
uses: the held model (melee_models_v18.png, a new 96x32 row 3), the inventory
icon (melee_inventory_v11.png, 52x20 at 0,72) and the ground loot cell (3,4 ->
loot_sprites_v30.png cell 4,9). House style: chunky pixels, a light top edge,
a dark drop shadow down-right."""
import sys
from PIL import Image

HI = (176, 186, 198, 255)
HI2 = (132, 142, 156, 255)
MID = (94, 102, 116, 255)
LO = (54, 58, 66, 255)
EDGE = (18, 19, 23, 255)
WORN = (196, 176, 140, 255)
SHADOW = (21, 21, 21, 220)


def crowbar(length, thick=5):
    """thick: 5 for the held model, 4 for icons."""
    w, h = length + 3, thick + 13
    body = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    bp = body.load()

    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            bp[x, y] = c

    shade = [HI, HI2, MID, LO, LO][:thick] if thick >= 4 else [HI, MID, LO]
    top = 2
    x0, x1 = 3, length - 8
    for x in range(x0, x1 + 1):
        put(x, top - 1, EDGE)
        for i, c in enumerate(shade):
            put(x, top + i, c)
        put(x, top + len(shade), EDGE)
    # worn grip, where the hands go
    g0 = x0 + length // 4
    for x in range(g0, g0 + 8):
        if x % 2 == 0:
            put(x, top + 1, WORN)
    # the chisel end: flattened, bent a pixel up, tapering
    for i, c in enumerate(shade[:-1]):
        put(x0 - 1, top - 1 + i, c)
        put(x0 - 2, top - 1 + i, c if i < len(shade) - 2 else EDGE)
    put(x0 - 1, top - 2, EDGE)
    put(x0 - 2, top - 2, EDGE)
    put(x0 - 3, top - 1, EDGE)
    put(x0 - 3, top, HI)
    # gooseneck: a full curl down and back, ending in a split claw
    cx, cy, r = x1 + 1, top + len(shade) // 2 + 3, 3
    import math
    for a in range(-90, 121, 3):
        t = math.radians(a)
        for k in range(len(shade)):
            rr = r + len(shade) / 2.0 - k
            x = int(round(cx + rr * math.cos(t)))
            y = int(round(cy + rr * math.sin(t)))
            put(x, y, shade[k])
        xo = int(round(cx + (r + len(shade) / 2.0 + 1) * math.cos(t)))
        yo = int(round(cy + (r + len(shade) / 2.0 + 1) * math.sin(t)))
        if bp[xo, yo][3] == 0 if 0 <= xo < w and 0 <= yo < h else False:
            put(xo, yo, EDGE)
    # the claw: the curl's end runs back a little, split by a notch
    end_t = math.radians(120)
    ex = int(round(cx + (r + len(shade) / 2.0) * math.cos(end_t)))
    ey = int(round(cy + (r + len(shade) / 2.0) * math.sin(end_t)))
    for d in range(1, 3):
        for k in range(len(shade) - 1):
            put(ex - d, ey - k + 1, shade[min(k + 1, len(shade) - 1)])
        put(ex - d, ey + 2, EDGE)
    put(ex - 3, ey, EDGE)
    put(ex - 3, ey + 1, EDGE)
    put(ex - 1, ey - 1, EDGE)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    sp = im.load()
    for y in range(h):
        for x in range(w):
            if bp[x, y][3] > 0 and x + 1 < w and y + 1 < h:
                sp[x + 1, y + 1] = SHADOW
    im.alpha_composite(body)
    return im.crop(im.getbbox())


def main(root):
    # held model: a fourth 32-px row
    models = Image.open(root + '/melee_models_v18.png').convert('RGBA')
    assert models.size == (96, 96), 'melee model atlas already extended'
    grown = Image.new('RGBA', (96, 128), (0, 0, 0, 0))
    grown.alpha_composite(models)
    bar = crowbar(70, 5)
    grown.alpha_composite(bar, (12, 96 + (32 - bar.size[1]) // 2))
    grown.save(root + '/melee_models_v18.png')
    # inventory icon
    inv = Image.open(root + '/melee_inventory_v11.png').convert('RGBA')
    assert inv.size == (80, 72), 'melee inventory atlas already extended'
    inv2 = Image.new('RGBA', (80, 96), (0, 0, 0, 0))
    inv2.alpha_composite(inv)
    icon = crowbar(46, 4)
    inv2.alpha_composite(icon, (1, 72 + (20 - icon.size[1]) // 2))
    inv2.save(root + '/melee_inventory_v11.png')
    # ground loot
    loot = Image.open(root + '/loot_sprites_v30.png').convert('RGBA')
    cell = (4 * 40, 9 * 40)
    assert loot.crop((cell[0], cell[1], cell[0] + 40, cell[1] + 40)).getbbox() is None, 'loot cell is taken'
    small = crowbar(32, 3)
    loot.alpha_composite(small, (cell[0] + (40 - small.size[0]) // 2, cell[1] + (40 - small.size[1]) // 2))
    loot.save(root + '/loot_sprites_v30.png')
    print('crowbar drawn')


main(sys.argv[1] if len(sys.argv) > 1 else '.')
