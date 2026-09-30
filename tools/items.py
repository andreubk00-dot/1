"""Design definitions for every OSTATOK item.

Each entry: design_box (x0,y0,x1,y1) in design units + draw(c).
Firearm and melee designs use the 144x48 / 96x32 model-row coordinates of the
game so grip / muzzle source points in _held_visual_config stay valid.
"""
from pxart import mul, mix

# ---- palette (muted post-Soviet, from reference) ------------------------
GUN_D = (46, 49, 52)
GUN = (70, 74, 77)
GUN_L = (118, 122, 124)
BLUED = (52, 56, 64)
WOOD = (132, 70, 36)
WOOD_D = (98, 50, 26)
WOOD_L = (166, 98, 54)
BAKE = (118, 58, 30)        # AK bakelite / plum magazine
OLIVE = (86, 94, 58)
OLIVE_D = (62, 68, 42)
OLIVE_L = (116, 124, 78)
KHAKI = (142, 128, 92)
KHAKI_D = (108, 96, 68)
CANVAS = (120, 112, 84)
NAVY = (48, 56, 66)
WHITE = (214, 210, 196)
WHITE_D = (170, 166, 152)
RED = (172, 40, 34)
RED_D = (120, 28, 26)
BRASS = (200, 156, 70)
BRASS_D = (150, 110, 44)
COPPER = (176, 98, 58)
STEEL = (150, 152, 150)
TIN = (170, 168, 156)
RUST = (126, 70, 40)
BLUE = (58, 116, 168)
BLUE_L = (120, 178, 214)
WATER = (104, 158, 196)
MURK = (104, 110, 70)
GREEN = (64, 112, 58)
GREEN_L = (104, 150, 78)
BROWN_G = (96, 58, 30)
AMBER = (150, 88, 36)
BLACK = (34, 34, 36)
TAPE = (132, 136, 138)
FIRE_RED = (170, 36, 32)

ITEMS = {}


def item(name, box):
    def deco(fn):
        ITEMS[name] = (box, fn)
        return fn
    return deco


# ======================================================================
# FIREARMS  (144 x 48 row space)
# ======================================================================
@item('makarov', (47, 15, 103, 44))
def makarov(c):
    # grip (brown bakelite panel on steel frame)
    c.part([(52, 25), (66, 25), (64, 42), (51, 42), (49, 32)], BLUED)
    c.part([(53, 27), (63, 27), (62, 40), (53, 40), (51, 33)], BAKE, noise=0.05)
    for y in (30, 33, 36, 39):
        c.line([(54, y), (61, y)], mul(BAKE, 0.75), width=0.8)
    # frame + trigger guard
    c.part([(58, 24), (97, 24), (97, 28), (74, 28), (70, 33), (63, 33), (60, 28)], BLUED)
    c.line([(63, 33), (72, 33), (75, 28)], BLUED, width=1.5)
    c.line([(68, 28), (67, 31)], GUN_L, width=0.8)
    # slide
    c.part([(50, 16), (99, 16), (101, 18), (101, 24), (50, 24), (48, 20)], GUN, grad=0.25)
    for x in range(53, 62, 2):
        c.line([(x, 17), (x, 23)], GUN_D, width=0.7)
    c.rect(64, 17.5, 97, 18.5, GUN_L, shade=False)
    c.rect(78, 19, 86, 22, GUN_D, shade=False)          # ejection port
    c.rect(97, 14.5, 99, 16, GUN_D)                     # front sight
    c.rect(52, 14.5, 55, 16, GUN_D)                     # rear sight
    c.part([(47, 17), (50, 17), (50, 21), (47, 20)], GUN_D)   # hammer
    c.rect(100, 20, 102, 23, (20, 20, 22), shade=False)  # muzzle
    c.dot(56, 26, GUN_L); c.dot(92, 26, GUN_L)


@item('shotgun', (8, 15, 134, 36))
def shotgun(c):
    # stock with pistol wrist
    c.part([(9, 21), (46, 19), (54, 20), (56, 26), (58, 31), (52, 33), (46, 28), (11, 33), (9, 32)],
           WOOD, grad=0.35, noise=0.06)
    c.line([(12, 25), (44, 22)], WOOD_L, width=0.8)
    c.rect(8.2, 21, 10.5, 33, BLACK)                        # recoil pad
    # receiver
    c.part([(52, 18), (78, 18), (78, 28), (60, 28), (55, 26)], GUN, grad=0.3)
    c.rect(60, 21, 72, 24, GUN_D, shade=False)
    c.line([(62, 28), (70, 32), (74, 28)], GUN_D, width=1.3)   # guard
    # barrel + magazine tube
    c.rect(76, 18, 133, 21.5, GUN, grad=0.4)
    c.rect(76, 22.5, 120, 25.5, GUN_D)
    c.rect(118, 22, 121, 26, GUN_L)                      # tube cap
    # pump forend (ribbed wood)
    c.part([(84, 21.5), (106, 21.5), (107, 27.5), (84, 27.5)], WOOD, grad=0.3, noise=0.05)
    for x in range(87, 105, 3):
        c.line([(x, 22.5), (x, 27)], WOOD_D, width=0.7)
    c.rect(130, 16.5, 132, 18, GUN_L)                    # bead
    c.rect(132, 18.5, 134, 21, (18, 18, 20), shade=False)


@item('akm', (6, 14, 134, 46))
def akm(c):
    # stock
    c.part([(7, 22), (51, 19), (52, 27), (42, 28), (8, 34), (6, 33)], WOOD, grad=0.35, noise=0.06)
    c.line([(10, 26), (46, 22)], WOOD_L, width=0.8)
    c.rect(6.3, 22, 8.5, 34, GUN_D)                        # butt plate
    # receiver
    c.part([(50, 19), (90, 19), (92, 21), (92, 28), (50, 28)], GUN, grad=0.3)
    c.part([(52, 17), (86, 17), (88, 19), (52, 19)], GUN_L, grad=0.2)   # dust cover
    c.line([(54, 18), (84, 18)], mul(GUN_L, 1.15), width=0.6)
    c.rect(71, 21, 84, 24, GUN_D, shade=False)           # ejection port
    c.part([(78, 23), (84, 22), (84, 24)], GUN_L)        # bolt handle
    c.part([(55, 22), (66, 21), (66, 23), (56, 24)], GUN_D)    # selector
    c.rect(87, 15, 91, 17.5, GUN_D)                      # rear sight
    # pistol grip
    c.part([(59, 27), (67, 27), (65, 38), (58, 37)], BAKE, noise=0.05)
    c.line([(66, 28), (71, 32), (74, 28)], GUN_D, width=1.3)
    # magazine (curved)
    c.part([(73, 27), (84, 27), (88, 35), (91.5, 44.5), (84, 45.6), (80, 37)], BAKE, grad=0.3, noise=0.04)
    c.line([(76, 29), (82, 30), (86, 38)], mul(BAKE, 1.25), width=0.7)
    # handguards
    c.part([(92, 21), (112, 21.5), (112, 27.5), (92, 28)], WOOD, grad=0.3, noise=0.05)
    c.rect(94, 17.5, 110, 20.5, WOOD_L, grad=0.3)
    c.line([(100, 22), (100, 27)], WOOD_D, width=0.6)
    c.rect(110, 18, 118, 20, GUN)                        # gas tube
    # barrel, front sight, muzzle
    c.rect(112, 21, 130, 23.2, GUN_D)
    c.part([(123, 14), (126, 14), (127, 21), (122, 21)], GUN_D)
    c.rect(128, 19.5, 132, 24, GUN)
    c.rect(131.5, 20.5, 133, 23, (16, 16, 18), shade=False)


# ======================================================================
# MELEE (96 x 32 row space)
# ======================================================================
@item('combat_knife', (15, 11, 84, 21))
def combat_knife(c):
    c.part([(17, 13.5), (37, 13), (38, 19.5), (17, 19)], BLACK, grad=0.3)
    for x in (21, 26, 31):
        c.line([(x, 14), (x, 18.5)], (60, 60, 62), width=0.8)
    c.rect(15.5, 14, 17.5, 18.5, GUN_L)                  # pommel
    c.rect(37, 11.2, 40.5, 20.8, GUN)                    # guard
    c.part([(40.5, 12.8), (70, 12.8), (83.5, 16), (74, 20), (40.5, 20)], STEEL, grad=0.5)
    c.line([(42, 14.5), (70, 14.5)], mul(STEEL, 1.3), width=0.8)
    c.line([(44, 18.2), (72, 18.2)], mul(STEEL, 0.76), width=0.7)


@item('steel_pipe', (10, 11, 84, 22))
def steel_pipe(c):
    c.rect(10.5, 13.5, 81, 20, (104, 108, 106), grad=0.6, noise=0.07)
    c.rect(80, 12, 83.8, 21.5, GUN)                      # fitting
    c.rect(10, 13, 34, 20.5, (58, 60, 60), grad=0.3)     # tape grip
    for x in range(12, 34, 3):
        c.line([(x, 13.5), (x + 1.5, 20)], (40, 42, 42), width=0.6)
    for x, y in ((50, 16), (62, 18), (70, 15), (77, 17)):
        c.dot(x, y, RUST)


@item('fire_axe', (10, 4, 92, 29))
def fire_axe(c):
    c.part([(10.5, 15.5), (84, 14), (84, 18.5), (10.5, 19.5)], WOOD_L, grad=0.4, noise=0.05)
    c.rect(10.5, 15, 22, 20, BLACK)                      # grip wrap
    # head: curved pick on top, flared blade below
    c.part([(73, 11), (82, 11), (82, 20), (73, 20)], FIRE_RED, grad=0.3)
    c.part([(74, 11.5), (81, 11.5), (80, 7), (77, 4.2), (76, 7)], FIRE_RED, grad=0.3)
    c.part([(73, 19.5), (82, 19.5), (89, 24), (91.8, 28.8), (64, 28.8), (66, 24)], FIRE_RED, grad=0.25)
    c.part([(65.5, 26.8), (90.8, 26.8), (91.8, 28.8), (64.2, 28.8)], STEEL, shade=False)   # honed edge
    c.dot(79, 17, mul(FIRE_RED, 0.6))


# ======================================================================
# AMMO
# ======================================================================
def cartridge(c, x, y0, y1, w, case, tip, neck=None):
    c.rect(x, y0 + (y1 - y0) * 0.38, x + w, y1, case, grad=0.3)
    c.part([(x, y0 + (y1 - y0) * 0.4), (x + w / 2, y0), (x + w, y0 + (y1 - y0) * 0.4)], tip)
    c.rect(x - 0.2, y1 - 1.2, x + w + 0.2, y1, mul(case, 0.7), shade=False)


@item('ammo_9x18', (0, 0, 18, 18))
def ammo_9x18(c):
    c.rect(1, 9, 17, 17, (112, 92, 58), noise=0.05)      # carton
    c.rect(1, 9, 17, 11, (140, 118, 76), shade=False)
    for i, x in enumerate((2.5, 7.3, 12.1)):
        cartridge(c, x, 1.5 + i % 2, 12, 3.4, BRASS, COPPER)


@item('ammo_12g', (0, 0, 16, 20))
def ammo_12g(c):
    for x, y in ((1.5, 3), (8.5, 1)):
        c.rect(x, y, x + 6, y + 13, RED, grad=0.3)
        c.rect(x, y + 13, x + 6, y + 18, BRASS, grad=0.4)
        c.line([(x + 1, y + 1), (x + 1, y + 12)], mul(RED, 1.35), width=0.7)
        c.line([(x, y + 13), (x + 6, y + 13)], BRASS_D, width=0.6)


@item('ammo_762', (0, 0, 18, 18))
def ammo_762(c):
    for i, x in enumerate((1.5, 6.5, 11.5)):
        c.rect(x, 7, x + 4, 17, (104, 108, 82), grad=0.3)             # lacquered steel case
        c.part([(x + 0.8, 7), (x + 2, 0.5 + i % 2), (x + 3.2, 7)], COPPER)
        c.line([(x + 0.8, 8), (x + 0.8, 16)], (140, 144, 110), width=0.6)


# ======================================================================
# MEDICAL
# ======================================================================
@item('bandage', (0, 0, 18, 18))
def bandage(c):
    c.rect(5, 3, 16, 15, WHITE, grad=0.35)
    for x in (8, 11, 14):
        c.line([(x, 3.5), (x, 14.5)], WHITE_D, width=0.6)
    c.ell(5, 9, 3.6, 6, mul(WHITE, 1.02))
    c.ell(5, 9, 1.6, 2.8, WHITE_D, shade=False)
    c.ell(5, 9, 0.7, 1.1, (120, 116, 106), shade=False)
    c.part([(13, 13), (17, 16), (15, 17.5), (11, 15)], WHITE)          # loose tail


@item('sterile_bandage', (0, 0, 18, 18))
def sterile_bandage(c):
    c.part([(1, 3), (17, 2), (17, 16), (1, 16)], (196, 196, 180), grad=0.3)
    c.rect(1, 2, 17, 4, (160, 160, 148), shade=False)
    c.rect(7.5, 6, 10.5, 14, RED, shade=False)
    c.rect(5, 8.5, 13, 11.5, RED, shade=False)


@item('antiseptic', (0, 0, 14, 44))
def antiseptic(c):
    c.rect(4.5, 3, 9.5, 8, WHITE)                        # cap
    c.rect(5, 8, 9, 12, AMBER)
    c.part([(5, 12), (9, 12), (12, 17), (12, 42), (2, 42), (2, 17)], AMBER, grad=0.35)
    c.line([(3.5, 18), (3.5, 40)], mul(AMBER, 1.5), width=0.7)
    c.rect(2, 22, 12, 34, WHITE, grad=0.2)
    c.rect(6, 24, 8, 32, RED, shade=False)
    c.rect(3.5, 27, 10.5, 29, RED, shade=False)


@item('painkillers', (0, 0, 18, 18))
def painkillers(c):
    c.rect(4, 1, 14, 5, WHITE, grad=0.3)
    c.rect(3, 5, 15, 17, (206, 206, 196), grad=0.3)
    c.rect(3, 8, 15, 14, BLUE, grad=0.2)
    c.line([(5, 11), (13, 11)], (200, 220, 236), width=0.8)
    c.line([(4.5, 6), (4.5, 16)], (240, 240, 232), width=0.6)


@item('antibiotics', (0, 0, 18, 18))
def antibiotics(c):
    c.part([(2, 4), (14, 2), (17, 5), (17, 16), (5, 17), (2, 15)], (208, 206, 190), grad=0.3)
    c.part([(2, 4), (14, 2), (17, 5), (5, 7)], (228, 226, 212))
    c.rect(6, 9, 16, 13, GREEN, shade=False)
    c.line([(8, 11), (14, 11)], (190, 220, 170), width=0.7)


# ======================================================================
# FOOD / WATER
# ======================================================================
def bottle(c, liquid, cap=BLUE, label=(190, 70, 50), fill_top=12):
    c.rect(5, 1, 9, 5, cap, grad=0.3)
    c.rect(5.5, 5, 8.5, 7, (180, 196, 204))
    c.part([(5, 7), (9, 7), (12, 12), (12, 42), (2, 42), (2, 12)], (170, 196, 206), grad=0.2, alpha=255)
    c.part([(2.6, fill_top), (11.4, fill_top), (11.4, 41.4), (2.6, 41.4)], liquid, grad=0.35)
    c.rect(2, 20, 12, 28, label, grad=0.2)
    c.line([(3.5, 10), (3.5, 40)], (228, 238, 242), width=0.7)
    for y in (32, 37):
        c.line([(2.5, y), (11.5, y)], mul(liquid, 0.8), width=0.5)


@item('water', (0, 0, 14, 44))
def water(c):
    bottle(c, WATER, BLUE, (60, 96, 150))


@item('dirty_water', (0, 0, 14, 44))
def dirty_water(c):
    bottle(c, MURK, (110, 110, 100), (130, 120, 90), fill_top=16)
    for x, y in ((5, 30), (8, 35), (6, 39), (9, 25)):
        c.dot(x, y, (70, 66, 40))


@item('herbal_tea', (0, 0, 14, 44))
def herbal_tea(c):
    c.rect(3, 1, 11, 6, GUN, grad=0.3)                   # cup-lid
    c.rect(4, 6, 10, 8, GUN_D)
    c.rect(2, 8, 12, 42, OLIVE, grad=0.35, noise=0.04)   # army thermos
    c.rect(2, 12, 12, 14, OLIVE_D, shade=False)
    c.rect(2, 36, 12, 38, OLIVE_D, shade=False)
    c.line([(3.5, 15), (3.5, 35)], OLIVE_L, width=0.8)
    c.part([(1, 3), (4, 0), (5, 1), (2, 4)], (220, 220, 214), shade=False, alpha=150)   # steam


@item('water_filter', (0, 0, 16, 44))
def water_filter(c):
    c.rect(4, 1, 12, 7, (200, 200, 192), grad=0.3)
    c.rect(6, 0, 10, 2, GUN)
    c.rect(2, 7, 14, 38, BLUE, grad=0.4)
    for y in range(11, 36, 4):
        c.line([(2.5, y), (13.5, y)], mul(BLUE, 0.75), width=0.6)
    c.rect(2, 18, 14, 26, WHITE, grad=0.2)
    c.rect(5, 20, 11, 22, BLUE, shade=False)
    c.rect(5, 38, 11, 43, (200, 200, 192), grad=0.3)


@item('canned_meat', (0, 0, 22, 16))
def canned_meat(c):
    c.ell(11, 3.5, 9.5, 2.6, TIN)
    c.rect(1.5, 3.5, 20.5, 13, TIN, grad=0.4)
    c.ell(11, 13, 9.5, 2.4, mul(TIN, 0.75))
    c.rect(1.5, 5.5, 20.5, 11.5, (182, 164, 120), grad=0.2)       # cream label
    c.rect(1.5, 7, 20.5, 10, RED_D, shade=False)
    c.rect(8, 7.5, 14, 9.5, (230, 214, 170), shade=False)
    c.ell(11, 3.2, 7, 1.4, mul(TIN, 1.2), shade=False)


@item('hot_meal', (0, 0, 22, 18))
def hot_meal(c):
    c.part([(1, 9), (21, 9), (18, 17), (4, 17)], (120, 126, 118), grad=0.4)   # mess tin
    c.ell(11, 9, 10, 2.8, (150, 104, 56), shade=False)                          # stew
    for x, y in ((7, 9), (12, 8), (15, 10)):
        c.dot(x, y, (196, 150, 90))
    c.rect(19, 10, 22, 11.5, GUN_L)                                             # handle
    for x in (7, 11, 15):
        c.line([(x, 6), (x + 1, 3), (x, 1)], (226, 226, 220), width=0.7, alpha=170)


@item('grain', (0, 0, 20, 18))
def grain(c):
    c.part([(4, 5), (16, 5), (19, 12), (17, 17), (3, 17), (1, 12)], (160, 136, 92), grad=0.4, noise=0.08)
    c.part([(5, 1), (15, 1), (16, 5), (4, 5)], (140, 118, 80))
    c.line([(4.5, 5.5), (15.5, 5.5)], (90, 66, 40), width=0.9)
    c.ell(10, 2.2, 4, 1.2, (220, 196, 130), shade=False)
    c.rect(7, 10, 13, 13, (120, 96, 60), shade=False)


@item('herbs', (0, 0, 18, 18))
def herbs(c):
    for a, b in (((9, 17), (3, 3)), ((9, 17), (9, 1)), ((9, 17), (15, 3)), ((9, 17), (5, 8)), ((9, 17), (13, 7))):
        c.line([a, b], (70, 100, 50), width=0.8)
    for (x, y) in ((3, 3), (9, 1.8), (15, 3.2), (5, 8), (13, 7), (7, 5), (11, 4), (6, 11), (12, 11)):
        c.ell(x, y, 1.9, 1.3, GREEN_L if (x + y) % 3 else GREEN)
    c.rect(7.5, 12, 10.5, 14, (150, 112, 70))                      # twine


# ======================================================================
# MATERIALS / TOOLS
# ======================================================================
@item('scrap', (0, 0, 18, 18))
def scrap(c):
    c.part([(1, 12), (8, 6), (12, 9), (6, 16), (1, 16)], (118, 122, 118), noise=0.08)
    c.part([(7, 3), (16, 1), (17, 5), (9, 8)], RUST, noise=0.1)
    c.part([(9, 11), (17, 9), (17, 17), (10, 17)], (92, 96, 94), noise=0.08)
    c.line([(3, 14), (9, 8)], (160, 164, 158), width=0.6)
    for x, y in ((12, 12), (14, 15), (11, 3)):
        c.dot(x, y, (60, 58, 52))


@item('cloth', (0, 0, 20, 18))
def cloth(c):
    c.part([(1, 11), (19, 10), (19, 17), (1, 17)], KHAKI_D, noise=0.06)
    c.part([(2, 6), (18, 5), (18, 11), (2, 11.5)], (156, 140, 104), noise=0.06)
    c.part([(3, 1), (17, 1.5), (17, 6), (3, 6)], (126, 134, 98), noise=0.06)
    for y in (3.5, 8, 14):
        c.line([(4, y), (16, y - 0.3)], (90, 84, 60), width=0.5)


@item('tape', (0, 0, 18, 18))
def tape(c):
    c.ell(9, 9, 8, 8, TAPE)
    c.ell(9, 9, 4.2, 4.2, (178, 150, 104), shade=False)            # cardboard core
    c.ell(9, 9, 3, 3, (0, 0, 0), shade=False, alpha=0)
    c.part([(15, 12), (18, 16), (16, 17.5), (13, 14)], TAPE)


@item('repair_kit', (0, 0, 44, 18))
def repair_kit(c):
    c.rect(1, 5, 43, 17, (122, 46, 36), grad=0.35, noise=0.04)     # red steel box
    c.rect(1, 5, 43, 8, (150, 60, 46), shade=False)
    c.line([(1, 8.5), (43, 8.5)], (70, 26, 22), width=0.7)
    c.part([(16, 5), (17, 1.5), (27, 1.5), (28, 5), (26, 5), (25.5, 3), (18.5, 3), (18, 5)], GUN)
    c.rect(20, 9.5, 24, 12, GUN_L)                                  # latch
    c.rect(4, 11, 10, 13, (96, 36, 28), shade=False)
    c.rect(34, 11, 40, 13, (96, 36, 28), shade=False)


@item('firewood', (0, 0, 30, 18))
def firewood(c):
    for (x0, y0, y1) in ((2, 9, 17), (11, 9, 17), (6, 1, 9)):
        c.rect(x0 + 3, y0, x0 + 18, y1, (112, 76, 44), grad=0.3, noise=0.08)
        c.ell(x0 + 3, (y0 + y1) / 2, 3, (y1 - y0) / 2, (196, 156, 102))
        c.ell(x0 + 3, (y0 + y1) / 2, 1.3, 1.6, (150, 110, 64), shade=False)
    c.line([(12, 12), (19, 11)], (80, 52, 30), width=0.5)


# ======================================================================
# GEAR
# ======================================================================
@item('cap', (0, 0, 20, 16))
def cap(c):
    c.part([(3, 11), (4, 5), (8, 2), (13, 2), (17, 6), (17, 11)], OLIVE, grad=0.35, noise=0.05)
    c.part([(1, 11), (19, 10.5), (19.5, 13.5), (0.5, 14)], OLIVE_D)
    c.line([(10, 2.5), (10, 10.5)], OLIVE_D, width=0.6)
    c.rect(8.5, 6, 11.5, 8, RED, shade=False)


@item('light_jacket', (0, 0, 44, 44))
def light_jacket(c):
    # sleeves
    c.part([(9, 8), (3, 16), (1, 38), (7, 39), (10, 20)], OLIVE_D, noise=0.05)
    c.part([(35, 8), (41, 16), (43, 38), (37, 39), (34, 20)], OLIVE_D, noise=0.05)
    # body
    c.part([(9, 6), (17, 3), (27, 3), (35, 6), (35, 41), (9, 41)], OLIVE, grad=0.3, noise=0.05)
    # collar
    c.part([(15, 3), (22, 8), (29, 3), (27, 1), (17, 1)], OLIVE_L)
    c.line([(22, 8), (22, 40)], (60, 58, 50), width=0.9)            # zip
    for y in (12, 18, 24, 30, 36):
        c.dot(22, y, (170, 170, 160))
    for x0 in (11, 25):                                             # chest + hip pockets
        c.rect(x0, 12, x0 + 8, 19, OLIVE_L, grad=0.2)
        c.line([(x0, 12.5), (x0 + 8, 12.5)], OLIVE_D, width=0.6)
        c.rect(x0, 28, x0 + 8, 36, OLIVE_L, grad=0.2)
    c.rect(9, 38, 35, 41, OLIVE_D, shade=False)                     # hem
    c.rect(1, 36, 7, 39, OLIVE_D, shade=False)
    c.rect(37, 36, 43, 39, OLIVE_D, shade=False)


@item('police_vest', (0, 0, 44, 44))
def police_vest(c):
    c.part([(8, 4), (16, 2), (18, 9), (26, 9), (28, 2), (36, 4), (38, 12), (38, 40), (6, 40), (6, 12)],
           NAVY, grad=0.3, noise=0.05)
    c.part([(17, 9), (27, 9), (26, 14), (18, 14)], (32, 36, 42))    # neck cut
    for x0 in (8, 16, 24, 32):                                      # mag pouches
        c.rect(x0 - 1, 22, x0 + 5, 32, (60, 70, 80), grad=0.2)
        c.rect(x0 - 1, 22, x0 + 5, 24.5, (72, 82, 92), shade=False)
    c.rect(10, 16, 34, 20, (212, 206, 176), shade=False)            # ПОЛИЦИЯ panel
    for x in range(12, 33, 3):
        c.line([(x, 17), (x + 1.5, 17)], NAVY, width=0.7)
        c.line([(x, 19), (x + 1.5, 19)], NAVY, width=0.7)
    c.rect(6, 34, 38, 36, (38, 44, 52), shade=False)
    for x in range(9, 38, 4):
        c.line([(x, 36), (x, 39)], (64, 72, 82), width=0.6)


@item('field_backpack', (0, 0, 44, 44))
def field_backpack(c):
    c.part([(3, 14), (7, 10), (7, 40), (3, 38)], OLIVE_D)           # side pocket l
    c.part([(41, 14), (37, 10), (37, 40), (41, 38)], OLIVE_D)
    c.part([(8, 8), (14, 4), (30, 4), (36, 8), (37, 41), (7, 41)], OLIVE, grad=0.35, noise=0.06)
    c.part([(9, 6), (15, 2), (29, 2), (35, 6), (34, 18), (10, 18)], OLIVE_L, grad=0.2, noise=0.05)   # top flap
    c.rect(14, 12, 17, 26, (58, 50, 36))                            # straps + buckles
    c.rect(27, 12, 30, 26, (58, 50, 36))
    c.rect(13.5, 24, 17.5, 27, BRASS_D)
    c.rect(26.5, 24, 30.5, 27, BRASS_D)
    c.rect(11, 28, 33, 39, OLIVE_D, grad=0.2)                       # front pocket
    c.line([(11, 29), (33, 29)], OLIVE_L, width=0.6)
    c.rect(19, 0.5, 25, 3, (58, 50, 36))                            # grab handle
    c.part([(4, 20), (8, 18), (8, 24), (4, 25)], (58, 50, 36))      # compression strap


# ======================================================================
# MODULES / ACCESSORIES
# ======================================================================
@item('flashlight', (0, 0, 14, 44))
def flashlight(c):
    c.part([(2, 1), (12, 1), (12, 8), (10, 12), (4, 12), (2, 8)], GUN, grad=0.3)
    c.rect(3, 1.5, 11, 3.5, (236, 226, 170), shade=False)           # lens
    c.rect(4, 12, 10, 42, BLACK, grad=0.3)
    for y in range(16, 34, 2):
        c.line([(4.5, y), (9.5, y)], (52, 52, 54), width=0.5)
    c.rect(5.5, 20, 8.5, 23, RED_D)                                 # switch
    c.rect(4, 40, 10, 43, GUN)


@item('makarov_extmag', (0, 0, 14, 44))
def makarov_extmag(c):
    c.rect(3, 2, 11, 38, BLUED, grad=0.4)
    c.rect(3, 2, 11, 5, BRASS)                                      # top round
    c.rect(1.5, 38, 12.5, 42, BAKE)                                  # base pad
    for y in range(9, 36, 5):
        c.dot(9, y, GUN_L)
    c.line([(4.3, 6), (4.3, 37)], GUN_L, width=0.6)


@item('muzzle_brake', (0, 0, 20, 12))
def muzzle_brake(c):
    c.rect(1, 2, 19, 10, GUN, grad=0.5)
    for x in (5, 9, 13):
        c.rect(x, 4, x + 2, 8, (22, 22, 24), shade=False)
    c.rect(17, 3, 19, 9, GUN_D)


@item('suppressor', (0, 0, 14, 44))
def suppressor(c):
    c.rect(2, 3, 12, 42, BLACK, grad=0.45, noise=0.04)
    c.rect(4, 0.5, 10, 3, GUN)
    c.line([(3.5, 5), (3.5, 40)], (82, 84, 86), width=0.7)
    for y in (8, 38):
        c.line([(2.5, y), (11.5, y)], (20, 20, 22), width=0.6)


@item('shotgun_exttube', (0, 0, 14, 44))
def shotgun_exttube(c):
    c.rect(4, 2, 10, 42, GUN, grad=0.45)
    c.rect(3, 38, 11, 43, GUN_L)
    c.rect(3.5, 18, 10.5, 21, GUN_D)
    c.line([(5, 3), (5, 37)], GUN_L, width=0.6)


@item('akm_extmag', (0, 0, 18, 44))
def akm_extmag(c):
    c.part([(3, 2), (10, 2), (12, 14), (16, 30), (16, 38), (10, 40), (7, 26), (3, 12)], BAKE, grad=0.3, noise=0.04)
    c.rect(3, 1, 10, 3.5, GUN_D)
    c.part([(9, 38), (17, 36), (17, 41), (10, 43)], GUN_D)
    c.line([(4.5, 5), (8.5, 25), (11.5, 36)], mul(BAKE, 1.3), width=0.7)
