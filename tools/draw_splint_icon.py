"""dev67: the splint icon - two wooden slats bound with bandage and a strip of
tape - drawn into the inventory atlas (46x16 at 100,482) and the world loot
atlas (cell 2,9; a shorter pack for the ground), in the house style: chunky
pixels, a light top edge, a dark drop shadow down-right."""
import sys
from PIL import Image

WOOD = (160, 122, 74, 255)
WOOD_HI = (196, 154, 98, 255)
WOOD_LO = (110, 80, 48, 255)
CLOTH = (217, 210, 189, 255)
CLOTH_LO = (181, 173, 151, 255)
TAPE = (79, 92, 104, 255)
TAPE_HI = (112, 128, 142, 255)
SHADOW = (21, 21, 21, 230)


def splint(length):
    w, h = length + 1, 14
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()

    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = c

    body = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    bp = body.load()
    # two slats, 4 px each with a 2 px gap; rounded ends
    for top in (1, 7):
        for x in range(1, length - 1):
            for dy in range(4):
                c = WOOD_HI if dy == 0 else (WOOD_LO if dy == 3 else WOOD)
                if (x in (1, length - 2)) and dy in (0, 3):
                    continue
                # a little grain
                if dy in (1, 2) and (x * 7 + top) % 11 == 0:
                    c = WOOD_LO
                bp[x, top + dy] = c
    # three bandage wraps crossing both slats
    for cx in (length * 0.22, length * 0.5, length * 0.78):
        x0 = int(cx) - 2
        for x in range(x0, x0 + 5):
            for y in range(0, 12):
                bp[x, y] = CLOTH_LO if (x == x0 + 4 or y in (0, 11)) else CLOTH
            # the turns of the bandage
            bp[x, 4] = CLOTH_LO
            bp[x, 8] = CLOTH_LO
    # a strip of tape near one end
    tx = length - 7
    for x in range(tx, tx + 3):
        for y in range(1, 11):
            bp[x, y] = TAPE_HI if x == tx else TAPE
    # drop shadow: one pixel down-right under everything
    for y in range(h):
        for x in range(w):
            if bp[x, y][3] > 0 and x + 1 < w and y + 1 < h:
                put(x + 1, y + 1, SHADOW)
    im.alpha_composite(body)
    return im


def main(root):
    inv = Image.open(root + '/inventory_icons_v32.png').convert('RGBA')
    icon = splint(45)
    region = (100, 482, 146, 498)
    assert inv.crop(region).getbbox() is None, 'inventory atlas slot is taken'
    inv.alpha_composite(icon, (100, 483))
    inv.save(root + '/inventory_icons_v32.png')
    loot = Image.open(root + '/loot_sprites_v30.png').convert('RGBA')
    cell = (2 * 40, 9 * 40)
    assert loot.crop((cell[0], cell[1], cell[0] + 40, cell[1] + 40)).getbbox() is None, 'loot cell is taken'
    small = splint(34)
    loot.alpha_composite(small, (cell[0] + 3, cell[1] + 13))
    loot.save(root + '/loot_sprites_v30.png')
    print('splint icon drawn', icon.size, small.size)


main(sys.argv[1] if len(sys.argv) > 1 else '.')
