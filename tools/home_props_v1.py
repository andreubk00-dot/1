"""OSTATOK 1.44 furniture: the rooms people lived and worked in.

Pixel art in the world-props style (3/4 view from the front and above: a lit
top, a front face, a dark outline, muted worn colours, a few pixels of wear),
one piece per 72 x 56 cell, centred, the way world_props_v19 lays them out.

  python3 tools/home_props_v1.py <project>  ->  art/world_hd/props_home_v1.png
Prints HOME_PROP_REGIONS for main_script_mod.gd.
"""
import os
import random
import sys
from PIL import Image

OUT = (22, 20, 18, 255)


def sh(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


class C:
    def __init__(self, w, h, seed=1):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.im.load()
        self.r = random.Random(seed)

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c if len(c) == 4 else c + (255,)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def block(self, x0, y0, x1, y1, top_h, col, top=None):
        """a solid seen from the front and above: a top band, then the face"""
        top = top or sh(col, 1.18)
        self.rect(x0, y0, x1, y0 + top_h - 1, top)
        self.rect(x0, y0 + top_h, x1, y1, col)
        self.rect(x0, y0 + top_h, x1, y0 + top_h, sh(col, 0.78))       # the front edge under the top
        self.rect(x0, y0, x1, y0, sh(top, 1.08))                       # lit back rim
        self.rect(x1, y0 + top_h, x1, y1, sh(col, 0.82))               # shade on the right
        self.rect(x0, y1, x1, y1, sh(col, 0.70))                       # the foot

    def wear(self, x0, y0, x1, y1, n, k=0.86):
        for _ in range(n):
            x, y = self.r.randint(x0, x1), self.r.randint(y0, y1)
            if self.px[x, y][3]:
                self.px[x, y] = sh(self.px[x, y], k)

    def outline(self):
        src = self.im.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[nx, ny][3] and src[nx, ny][:3] != OUT[:3]:
                        self.px[x, y] = OUT
                        break

    def legs(self, xs, y0, y1, col):
        for x in xs:
            self.rect(x, y0, x, y1, col)


WOOD = (120, 84, 54)
WOOD_D = (92, 62, 40)
FABRIC_G = (86, 96, 66)
FABRIC_B = (104, 78, 60)
METAL = (138, 142, 140)
WHITE = (196, 194, 184)
CREAM = (184, 176, 150)


def sofa():
    c = C(52, 28, 11)
    c.block(1, 4, 50, 15, 5, sh(FABRIC_G, 0.9))                # the back
    c.block(1, 12, 50, 24, 4, FABRIC_G)                        # the seat
    c.block(0, 9, 6, 24, 3, sh(FABRIC_G, 0.95))                # arms
    c.block(45, 9, 51, 24, 3, sh(FABRIC_G, 0.95))
    for x in (17, 33):                                         # cushion seams
        c.rect(x, 13, x, 18, sh(FABRIC_G, 0.72))
    c.rect(28, 14, 37, 16, sh(FABRIC_B, 1.0))                  # a thrown blanket
    c.rect(30, 17, 36, 18, sh(FABRIC_B, 0.85))
    c.legs((3, 48), 25, 26, WOOD_D)
    c.wear(2, 5, 49, 23, 60)
    c.outline()
    return c.im


def armchair():
    c = C(26, 28, 12)
    col = (118, 86, 62)
    c.block(3, 3, 22, 14, 4, sh(col, 0.9))
    c.block(3, 12, 22, 23, 4, col)
    c.block(0, 9, 5, 23, 3, sh(col, 0.95))
    c.block(20, 9, 25, 23, 3, sh(col, 0.95))
    c.rect(10, 15, 15, 16, sh(col, 0.7))                       # a torn seat
    c.put(12, 17, (210, 196, 150))
    c.legs((2, 23), 24, 25, WOOD_D)
    c.wear(3, 4, 22, 22, 30)
    c.outline()
    return c.im


def wardrobe():
    c = C(30, 46, 13)
    c.block(0, 0, 29, 43, 4, WOOD)
    c.rect(14, 6, 15, 41, WOOD_D)                              # between the doors
    for x in (12, 17):                                         # handles
        c.rect(x, 20, x, 24, (190, 168, 110))
    c.rect(2, 6, 12, 41, sh(WOOD, 1.04))
    c.rect(17, 6, 27, 41, sh(WOOD, 0.98))
    c.rect(18, 7, 26, 40, sh(WOOD, 0.94))                      # the right door ajar, darker
    c.rect(27, 7, 28, 40, (30, 24, 20))
    c.legs((1, 28), 44, 45, WOOD_D)
    c.wear(1, 5, 28, 42, 70)
    c.outline()
    return c.im


def bookshelf():
    c = C(34, 42, 14)
    c.block(0, 0, 33, 40, 3, WOOD_D)
    inner = (44, 34, 26)
    colours = [(140, 60, 50), (60, 80, 110), (150, 130, 80), (70, 100, 70), (120, 110, 100), (170, 150, 120)]
    for row in range(4):
        y0 = 5 + row * 9
        c.rect(2, y0, 31, y0 + 6, inner)
        x = 3
        while x < 30:
            w = c.r.randint(1, 3)
            if c.r.random() < 0.22:                             # gaps where books were taken
                x += w + 1
                continue
            col = c.r.choice(colours)
            h = c.r.randint(4, 6)
            c.rect(x, y0 + 6 - h + 1, min(30, x + w - 1), y0 + 6, col)
            c.rect(x, y0 + 6 - h + 1, x, y0 + 6, sh(col, 1.2))
            x += w
        c.rect(2, y0 + 7, 31, y0 + 7, sh(WOOD_D, 1.15))        # the shelf board
    c.outline()
    return c.im


def stove():
    c = C(26, 30, 15)
    c.block(0, 0, 25, 27, 9, WHITE, top=(170, 170, 164))
    for (x, y) in ((5, 2), (16, 2), (5, 5), (16, 5)):          # burners
        c.rect(x, y, x + 4, y + 2, (52, 52, 54))
        c.rect(x + 1, y + 1, x + 3, y + 1, (86, 86, 88))
    c.rect(3, 13, 22, 24, sh(WHITE, 0.86))                     # the oven door
    c.rect(5, 15, 20, 21, (46, 48, 50))
    c.rect(6, 16, 12, 17, (90, 96, 100))                       # a glint on the glass
    c.rect(6, 11, 19, 11, (80, 80, 82))                        # knobs
    for x in (7, 11, 15, 19):
        c.put(x, 11, (30, 30, 30))
    c.wear(1, 10, 24, 26, 40, 0.8)
    c.outline()
    return c.im


def kitchen_counter():
    c = C(50, 28, 16)
    c.block(0, 0, 49, 25, 7, (150, 136, 112), top=(186, 178, 160))
    c.rect(28, 1, 41, 5, (130, 134, 136))                      # the sink
    c.rect(29, 2, 40, 4, (92, 96, 98))
    c.rect(34, 0, 35, 1, (170, 172, 170))                      # the tap
    for x0 in (2, 17, 33):                                     # cupboard doors
        c.rect(x0, 9, x0 + 13, 23, sh((150, 136, 112), 1.04))
        c.rect(x0 + 11, 14, x0 + 11, 16, (90, 80, 64))
    c.rect(5, 2, 9, 4, (200, 196, 186))                        # a plate left on it
    c.rect(13, 1, 15, 4, (110, 70, 50))                        # a bottle
    c.wear(1, 1, 48, 24, 60)
    c.outline()
    return c.im


def dining_table():
    c = C(46, 30, 17)
    c.block(2, 6, 43, 13, 5, WOOD, top=sh(WOOD, 1.22))
    c.legs((4, 41), 14, 22, WOOD_D)
    c.legs((7, 38), 13, 18, sh(WOOD_D, 0.85))
    # two chairs: one pushed in behind, one knocked aside in front
    c.block(17, 0, 28, 7, 2, sh(WOOD, 0.9))
    c.block(30, 18, 40, 27, 3, sh(WOOD, 0.95))
    c.legs((31, 39), 28, 29, WOOD_D)
    c.rect(10, 7, 14, 9, (200, 196, 186))                      # a cup and papers
    c.rect(22, 8, 30, 9, (210, 206, 190))
    c.outline()
    return c.im


def bed():
    c = C(34, 50, 18)
    frame = (96, 70, 50)
    c.block(0, 0, 33, 7, 3, frame)                             # headboard
    c.rect(2, 8, 31, 45, frame)                                # frame sides
    c.rect(3, 8, 30, 44, (170, 164, 150))                      # the mattress
    c.rect(5, 9, 15, 14, (206, 204, 196))                      # pillows
    c.rect(18, 9, 28, 14, (196, 194, 186))
    blanket = (92, 104, 122)
    c.rect(3, 19, 30, 43, blanket)                             # the blanket, thrown back
    c.rect(3, 19, 30, 20, sh(blanket, 1.2))
    c.rect(20, 17, 30, 19, sh(blanket, 0.9))
    for y in range(22, 43, 4):                                 # folds
        c.rect(4 + (y % 3), y, 29, y, sh(blanket, 0.82))
    c.block(0, 43, 33, 48, 2, frame)                           # footboard
    c.wear(3, 9, 30, 43, 50, 0.9)
    c.outline()
    return c.im


def tv_stand():
    c = C(30, 34, 19)
    c.block(0, 18, 29, 31, 4, WOOD_D)
    c.rect(2, 24, 13, 30, sh(WOOD_D, 1.1))
    c.rect(16, 24, 27, 30, sh(WOOD_D, 1.1))
    c.block(5, 2, 24, 18, 3, (70, 70, 72))                     # an old CRT
    c.rect(7, 6, 22, 15, (40, 44, 46))
    c.rect(8, 7, 14, 9, (80, 92, 96))                          # its dead screen's sheen
    c.rect(18, 6, 22, 13, (36, 38, 40))
    c.put(14, 0, (90, 90, 90))                                 # an aerial
    c.put(13, 1, (90, 90, 90))
    c.put(17, 1, (90, 90, 90))
    c.outline()
    return c.im


def dresser():
    c = C(30, 28, 20)
    c.block(0, 2, 29, 25, 4, sh(WOOD, 0.95))
    for i, y in enumerate((8, 14, 20)):
        out = 2 if i == 1 else 0                               # one drawer pulled out
        c.rect(2, y - out, 27, y + 4 - out, sh(WOOD, 1.06 if i != 1 else 1.14))
        c.rect(13, y + 2 - out, 16, y + 2 - out, (186, 164, 108))
    c.rect(4, 0, 8, 3, (150, 160, 170))                        # a photo frame
    c.rect(22, 0, 24, 3, (120, 90, 60))
    c.legs((1, 28), 26, 27, WOOD_D)
    c.outline()
    return c.im


def rug():
    c = C(50, 30, 21)
    base = (124, 56, 48)
    c.rect(1, 2, 48, 27, base)
    c.rect(4, 5, 45, 24, (150, 112, 70))
    c.rect(7, 8, 42, 21, base)
    for x in range(10, 40, 6):                                 # a pattern
        c.rect(x, 13, x + 2, 15, (180, 150, 96))
    for x in range(1, 49, 2):                                  # fringe
        c.put(x, 1, (190, 176, 140))
        c.put(x, 28, (190, 176, 140))
    c.wear(1, 2, 48, 27, 160, 0.82)
    return c.im                                                 # flat: no outline


def bathtub():
    c = C(50, 30, 22)
    c.block(0, 4, 49, 25, 9, WHITE, top=(214, 212, 204))
    c.rect(4, 6, 45, 11, (150, 156, 158))                      # the inside
    c.rect(5, 7, 44, 11, (118, 126, 128))
    c.rect(20, 9, 30, 11, (96, 84, 62))                        # a rust ring of old water
    c.rect(43, 2, 44, 6, METAL)                                # taps
    c.legs((3, 46), 26, 27, METAL)
    c.wear(1, 13, 48, 24, 40, 0.84)
    c.outline()
    return c.im


def washing_machine():
    c = C(26, 30, 23)
    c.block(0, 0, 25, 27, 5, WHITE)
    c.rect(2, 6, 23, 8, (176, 176, 170))                       # the control strip
    c.put(19, 7, (60, 60, 60))
    c.put(16, 7, (60, 60, 60))
    for y in range(11, 25):                                    # the round door
        for x in range(4, 22):
            if (x - 12.5) ** 2 + (y - 17.5) ** 2 <= 49:
                c.put(x, y, (150, 156, 160) if (x - 12.5) ** 2 + (y - 17.5) ** 2 > 25 else (70, 80, 86))
    c.rect(9, 14, 11, 15, (120, 134, 140))
    c.outline()
    return c.im


def computer_desk():
    c = C(46, 34, 24)
    c.block(0, 12, 45, 20, 5, (130, 120, 104), top=(156, 148, 132))
    c.legs((2, 43), 21, 30, (70, 70, 70))
    c.block(30, 14, 43, 30, 2, (120, 112, 98))                 # the drawer pedestal
    c.block(8, 0, 25, 13, 2, (64, 64, 66))                     # a monitor
    c.rect(10, 3, 23, 11, (34, 38, 42))
    c.rect(11, 4, 15, 6, (70, 84, 90))
    c.rect(15, 12, 18, 13, (64, 64, 66))
    c.rect(8, 15, 22, 16, (60, 60, 62))                        # a keyboard
    c.rect(26, 14, 28, 16, (200, 196, 186))                    # a mug
    c.outline()
    return c.im


def water_cooler():
    c = C(16, 38, 25)
    c.rect(4, 0, 11, 11, (120, 170, 200))                      # the bottle, half empty
    c.rect(4, 0, 11, 5, (170, 200, 214))
    c.rect(5, 1, 5, 10, (200, 226, 236))
    c.block(1, 11, 14, 35, 3, (190, 190, 184))
    c.rect(4, 17, 11, 19, (60, 62, 64))                        # taps
    c.put(5, 18, (190, 60, 50))
    c.put(10, 18, (60, 110, 190))
    c.outline()
    return c.im


def freezer():
    c = C(48, 30, 26)
    c.block(0, 2, 47, 27, 10, WHITE, top=(170, 196, 206))       # glass lid
    c.rect(3, 3, 44, 10, (120, 150, 162))
    c.rect(5, 4, 13, 5, (200, 222, 230))
    for x in range(16, 42, 6):                                 # what is left inside
        c.rect(x, 7, x + 3, 9, c.r.choice([(170, 70, 50), (210, 180, 90), (90, 120, 80)]))
    c.rect(3, 16, 44, 18, (150, 40, 36))                       # the brand stripe
    c.wear(1, 13, 46, 26, 40, 0.84)
    c.outline()
    return c.im


PIECES = [
    ("sofa", sofa), ("armchair", armchair), ("wardrobe", wardrobe), ("bookshelf", bookshelf),
    ("kitchen_stove", stove), ("kitchen_counter", kitchen_counter), ("dining_table", dining_table),
    ("bed", bed), ("tv_stand", tv_stand), ("dresser", dresser), ("rug", rug), ("bathtub", bathtub),
    ("washing_machine", washing_machine), ("computer_desk", computer_desk), ("water_cooler", water_cooler),
    ("freezer_chest", freezer),
]
CELL_W, CELL_H = 72, 56


def main(project):
    atlas = Image.new("RGBA", (CELL_W * len(PIECES), CELL_H), (0, 0, 0, 0))
    regions = {}
    for i, (name, fn) in enumerate(PIECES):
        im = fn()
        x = i * CELL_W + (CELL_W - im.width) // 2
        y = (CELL_H - im.height) // 2
        atlas.paste(im, (x, y), im)
        regions[name] = (i * CELL_W, 0, CELL_W, CELL_H)
    out = os.path.join(project, "art", "world_hd", "props_home_v1.png")
    atlas.save(out)
    print("const HOME_PROP_REGIONS = {")
    print(",\n".join('    "%s":Rect2(%d,%d,%d,%d)' % ((k,) + v) for k, v in regions.items()))
    print("}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
