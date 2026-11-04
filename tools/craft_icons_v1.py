"""OSTATOK 1.40 crafting II icons.

Draws the new materials, the tool kit and the five schematics as pixel art in
the inventory atlas's style (dark outline, a lit top-left, a shaded bottom
right) and appends them to the atlases:

  inventory_icons_v32.png -> inventory_icons_v33.png  (a band from y 528)
  loot_sprites_v30.png    -> loot_sprites_v31.png     (two rows of 40 px cells)

python3 tools/craft_icons_v1.py <project>
Prints the regions / cells to put in main_script_mod.gd.
"""
import os
import sys
from PIL import Image

OUTLINE = (24, 22, 20, 255)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


class Canvas:
    def __init__(self, w, h):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.im.load()
        self.w, self.h = w, h

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def box(self, x0, y0, x1, y1, base, light=1.25, dark=0.62):
        """a filled box with an outline, lit top/left and shaded bottom/right"""
        self.rect(x0, y0, x1, y1, OUTLINE)
        self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, base)
        self.rect(x0 + 1, y0 + 1, x1 - 1, y0 + 1, shade(base, light))
        self.rect(x0 + 1, y0 + 1, x0 + 1, y1 - 1, shade(base, light * 0.95))
        self.rect(x0 + 1, y1 - 1, x1 - 1, y1 - 1, shade(base, dark))
        self.rect(x1 - 1, y0 + 1, x1 - 1, y1 - 1, shade(base, dark * 1.05))

    def disc(self, cx, cy, r, c):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.put(x, y, c)

    def outline(self):
        """a dark rim round every opaque pixel that touches the transparent"""
        src = self.im.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and src[nx, ny][3] > 0 and src[nx, ny][:3] != OUTLINE[:3]:
                            self.px[x, y] = OUTLINE
                            break


def nails():
    c = Canvas(18, 18)
    c.box(1, 6, 16, 16, (150, 118, 72))           # a cardboard box
    c.rect(2, 7, 15, 8, (186, 150, 96))
    for x in (4, 8, 12):                            # nail heads and shanks sticking out
        c.rect(x, 2, x + 1, 6, (150, 152, 150))
        c.rect(x - 1, 1, x + 2, 2, (196, 198, 194))
        c.put(x - 1, 1, OUTLINE)
    c.rect(5, 11, 12, 13, (110, 86, 52))             # the label
    c.rect(6, 12, 11, 12, (214, 206, 180))
    c.outline()
    return c.im


def wire():
    c = Canvas(18, 18)
    copper = (190, 108, 56)
    for r, k in ((7.5, 0.7), (6.2, 1.0), (4.9, 1.2), (3.6, 0.85)):
        c.disc(9, 9.5, r, shade(copper, k))
    c.disc(9, 9.5, 2.2, (0, 0, 0, 0))
    for y in range(18):
        for x in range(18):
            if c.px[x, y][3] and (x + y) % 3 == 0:
                c.px[x, y] = shade(c.px[x, y], 0.82)
    c.rect(14, 2, 16, 3, shade(copper, 1.15))       # a loose end
    c.rect(16, 3, 16, 5, shade(copper, 1.0))
    c.outline()
    return c.im


def alcohol():
    c = Canvas(14, 44)
    glass = (186, 206, 200)
    c.box(5, 2, 8, 8, (70, 74, 72))                  # the cap
    c.rect(4, 8, 9, 10, shade(glass, 0.9))
    c.box(1, 10, 12, 42, glass, 1.15, 0.7)           # the body
    c.rect(2, 26, 11, 41, (210, 228, 222))           # the spirit inside
    c.rect(3, 14, 3, 38, (240, 248, 246))            # a highlight
    c.box(2, 18, 11, 30, (232, 230, 220))            # the label
    c.rect(5, 21, 8, 27, (178, 46, 40))              # a red cross
    c.rect(4, 23, 9, 25, (178, 46, 40))
    c.outline()
    return c.im


def gunpowder():
    c = Canvas(18, 18)
    tin = (72, 84, 64)
    c.box(2, 4, 15, 16, tin)
    c.rect(2, 3, 15, 5, OUTLINE)
    c.rect(3, 3, 14, 4, (150, 154, 146))             # the lid
    c.rect(4, 8, 13, 13, (196, 168, 92))             # the label
    c.rect(5, 9, 12, 9, (120, 48, 36))
    c.rect(7, 11, 10, 12, (40, 38, 34))              # a grain heap mark
    c.outline()
    return c.im


def tool_kit():
    c = Canvas(40, 20)
    metal = (62, 92, 128)
    c.rect(14, 1, 25, 2, OUTLINE)                     # the handle
    c.rect(14, 2, 15, 6, OUTLINE)
    c.rect(24, 2, 25, 6, OUTLINE)
    c.rect(16, 3, 23, 3, (160, 162, 160))
    c.box(1, 6, 38, 18, metal)
    c.rect(2, 10, 37, 10, shade(metal, 0.55))         # the lid seam
    c.rect(17, 9, 22, 12, (196, 176, 96))             # the latch
    c.put(17, 9, OUTLINE)
    c.rect(4, 13, 9, 15, shade(metal, 1.25))          # a worn corner
    c.outline()
    return c.im


SCHEMATIC_TINTS = {
    "sch_gunsmith": (126, 58, 44),
    "sch_tailor": (58, 86, 126),
    "sch_medic": (214, 214, 206),
    "sch_tech": (186, 150, 54),
    "sch_reload": (150, 118, 62),
}


def schematic(item_id):
    c = Canvas(18, 18)
    paper = (210, 202, 176)
    c.box(2, 1, 15, 16, (92, 84, 66))                 # a notebook cover
    c.box(3, 2, 14, 15, paper, 1.05, 0.78)            # its open page
    for y in (5, 7, 9, 11):                           # ruled lines / a drawing
        c.rect(5, y, 12, y, (140, 130, 108))
    c.rect(2, 1, 4, 16, OUTLINE)                       # the spine
    tint = SCHEMATIC_TINTS[item_id]
    c.rect(2, 2, 3, 15, tint)
    c.rect(11, 1, 13, 6, tint)                         # a bookmark ribbon in the topic's colour
    c.put(12, 6, OUTLINE)
    if item_id == "sch_medic":
        c.rect(7, 9, 10, 13, (178, 46, 40))
        c.rect(6, 10, 11, 12, (178, 46, 40))
    c.outline()
    return c.im


ICONS = [
    ("nails", nails), ("wire", wire), ("gunpowder", gunpowder),
    ("sch_gunsmith", lambda: schematic("sch_gunsmith")), ("sch_tailor", lambda: schematic("sch_tailor")),
    ("sch_medic", lambda: schematic("sch_medic")), ("sch_tech", lambda: schematic("sch_tech")),
    ("sch_reload", lambda: schematic("sch_reload")),
    ("alcohol", alcohol), ("tool_kit", tool_kit),
]


def main(project):
    inv_src = Image.open(os.path.join(project, "inventory_icons_v32.png")).convert("RGBA")
    loot_src = Image.open(os.path.join(project, "loot_sprites_v30.png")).convert("RGBA")
    band_y = inv_src.height
    inv = Image.new("RGBA", (inv_src.width, band_y + 56), (0, 0, 0, 0))
    inv.paste(inv_src, (0, 0))
    rows = loot_src.height // 40
    loot = Image.new("RGBA", (loot_src.width, loot_src.height + 80), (0, 0, 0, 0))
    loot.paste(loot_src, (0, 0))
    x = 0
    regions = {}
    cells = {}
    for i, (item_id, fn) in enumerate(ICONS):
        im = fn()
        if x + im.width > inv.width:
            raise SystemExit("band overflow")
        inv.paste(im, (x, band_y), im)
        regions[item_id] = (x, band_y, im.width, im.height)
        x += im.width + 4
        # world sprite: the same art, a little smaller, centred in its cell
        k = 0.62 if im.height > 24 or im.width > 24 else 0.8
        small = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.NEAREST)
        cx, cy = i % 6, rows + i // 6
        loot.paste(small, (cx * 40 + (40 - small.width) // 2, cy * 40 + (40 - small.height) // 2), small)
        cells[item_id] = (cx, cy)
    inv.save(os.path.join(project, "inventory_icons_v33.png"))
    loot.save(os.path.join(project, "loot_sprites_v31.png"))
    for k, r in regions.items():
        print('    "%s":Rect2i(%d,%d,%d,%d),' % ((k,) + r))
    for k, c in cells.items():
        print('    "%s":Vector2i(%d,%d),' % (k, c[0], c[1]))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
