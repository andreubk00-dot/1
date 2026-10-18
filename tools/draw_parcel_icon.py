"""dev70: the sealed parcel of a retrieve contract - a cardboard case bound
with grey tape, a paper tag and a red seal - drawn into the inventory atlas
(36x20 at 152,483) and the world loot atlas (cell 3,9), in the house style:
chunky pixels, a light top edge, a dark drop shadow down-right."""
import sys
from PIL import Image

CARD = (150, 118, 76, 255)
CARD_HI = (184, 150, 100, 255)
CARD_LO = (104, 80, 50, 255)
TAPE = (88, 96, 102, 255)
TAPE_HI = (124, 134, 140, 255)
TAG = (222, 214, 190, 255)
TAG_LO = (176, 168, 146, 255)
SEAL = (170, 46, 40, 255)
SEAL_HI = (214, 84, 70, 255)
SHADOW = (21, 21, 21, 230)


def parcel(w, h):
    W, H = w + 1, h + 1
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    body = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    bp = body.load()
    for y in range(h):
        for x in range(w):
            c = CARD
            if y == 0 or x == 0:
                c = CARD_HI
            elif y == h - 1 or x == w - 1:
                c = CARD_LO
            # a lid seam a third of the way down
            if y == h // 3:
                c = CARD_LO
            bp[x, y] = c
    # tape: one band across, one along
    ty = h // 2 - 1
    for x in range(w):
        for y in (ty, ty + 1, ty + 2):
            bp[x, y] = TAPE_HI if y == ty else TAPE
    tx = w // 3
    for y in range(h):
        for x in (tx, tx + 1, tx + 2):
            bp[x, y] = TAPE_HI if x == tx else TAPE
    # paper tag on the right with a red wax seal
    gx, gy, gw, gh = w - 11, 2, 8, max(5, h - 9)
    for y in range(gy, gy + gh):
        for x in range(gx, gx + gw):
            bp[x, y] = TAG_LO if (x == gx + gw - 1 or y == gy + gh - 1) else TAG
    for (x, y) in [(gx + 2, gy + 1), (gx + 3, gy + 1), (gx + 2, gy + 3), (gx + 3, gy + 3), (gx + 4, gy + 3)]:
        bp[x, y] = TAG_LO
    sx, sy = tx + 1, ty + 1
    for (dx, dy) in [(-1, -1), (0, -1), (1, -1), (-1, 0), (0, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]:
        bp[sx + dx, sy + dy] = SEAL_HI if (dx, dy) == (-1, -1) else SEAL
    px = im.load()
    for y in range(H):
        for x in range(W):
            if bp[x, y][3] > 0 and x + 1 < W and y + 1 < H:
                px[x + 1, y + 1] = SHADOW
    im.alpha_composite(body)
    return im


def main(root):
    inv = Image.open(root + '/inventory_icons_v32.png').convert('RGBA')
    icon = parcel(35, 19)
    region = (152, 483, 152 + 36, 483 + 20)
    assert inv.crop(region).getbbox() is None, 'inventory atlas slot is taken'
    inv.alpha_composite(icon, (152, 483))
    inv.save(root + '/inventory_icons_v32.png')
    loot = Image.open(root + '/loot_sprites_v30.png').convert('RGBA')
    cell = (3 * 40, 9 * 40)
    assert loot.crop((cell[0], cell[1], cell[0] + 40, cell[1] + 40)).getbbox() is None, 'loot cell is taken'
    small = parcel(28, 16)
    loot.alpha_composite(small, (cell[0] + 5, cell[1] + 12))
    loot.save(root + '/loot_sprites_v30.png')
    print('parcel icon drawn', icon.size, small.size)


main(sys.argv[1] if len(sys.argv) > 1 else '.')
