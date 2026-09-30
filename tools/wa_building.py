"""OSTATOK 0.87 building exterior art.

Styles (row order used by the game):
  0 panel (residential / admin)   1 clinic (municipal tile)   2 shop (plaster)
  3 garage (brick)                4 industrial (corrugated)   5 military (painted block)
  6 rural (wooden siding / tin)
Roof tiles (64x64, seamless):
  0 bitumen  1 concrete slab  2 rusty corrugated  3 blue-grey corrugated
  4 red standing-seam tin  5 asbestos-cement wave (shifer)
"""
import math
import random
import numpy as np
from PIL import Image
from wa_core import Tex, fbm, value_noise, Scene, V, grunge, outline_img, fit_canvas, LEAF_ORANGE, MOSS, clamp8

T = 64


# ============================================================== ROOF TILES ==
def roof_tile(style, seed):
    rng = random.Random(seed)
    t = Tex(T, T, (0, 0, 0), seed=seed)
    yy, xx = np.mgrid[0:T, 0:T]
    n = fbm(T, T, 32, seed, 3)
    n2 = fbm(T, T, 8, seed + 1, 2)
    allm = np.ones((T, T), bool)
    if style == 0:          # bitumen roll roofing
        t.rgb[:] = np.array((64, 62, 60.0)) * (0.84 + 0.3 * n)[..., None]
        for y0 in range(0, T, 16):
            t.fill((yy == y0), (40, 39, 38))
            t.mul((yy == y0 + 1), 1.2)
            t.mul((yy >= y0 + 12) & (yy < y0 + 16), 0.93)
        t.speckle(allm, 0.10, [(74, 72, 68), (52, 50, 48)], seed=2)
        for _ in range(3):                                     # blisters / patches
            cx, cy = rng.randrange(T), rng.randrange(T)
            m = t.mask_ellipse(cx, cy, rng.uniform(3, 6), rng.uniform(2, 4))
            t.mul(m, 1.14)
        pud = n < 0.34
        t.blend(pud, (48, 54, 60), 0.5)
        t.speckle(pud, 0.03, [(120, 132, 140)], seed=3)
        t.speckle(n2 > 0.72, 0.35, MOSS, seed=4)
    elif style == 1:        # concrete slabs
        t.rgb[:] = np.array((96, 94, 88.0)) * (0.84 + 0.28 * n)[..., None]
        slab = ((xx // 32) * 3 + (yy // 32) * 5) % 4
        t.mul(allm, (0.93 + 0.05 * slab))
        seam = (xx % 32 == 0) | (yy % 32 == 0)
        t.fill(seam, (58, 56, 52))
        t.mul((xx % 32 == 1) | (yy % 32 == 1), 1.1)
        t.speckle(allm, 0.08, [(110, 108, 102), (78, 76, 72)], seed=2)
        stain = n < 0.38
        t.blend(stain, (70, 72, 70), 0.5)
        t.speckle(seam & (n2 > 0.4), 0.6, MOSS, seed=4)
        for _ in range(2):
            t.crack(rng.uniform(0, T), rng.uniform(0, T), 10, (64, 62, 58), None, 0.4)
    elif style in (2, 3):   # corrugated sheet
        base = (112, 80, 58) if style == 2 else (86, 96, 104)
        t.rgb[:] = np.array(base, float)
        rib = [1.22, 1.04, 0.78, 0.92]
        t.mul(allm, np.array(rib)[xx % 4])
        t.mul(allm, 0.86 + 0.26 * n)
        # sheet overlap every 32 rows + rivets
        t.fill(yy % 32 == 31, tuple(int(c * 0.5) for c in base))
        t.mul(yy % 32 == 0, 1.2)
        for x in range(2, T, 8):
            t.px(x, 29, (190, 180, 160)); t.px(x, 28, (60, 50, 44))
        rust = fbm(T, T, 12, seed + 5, 3)
        rm = rust > (0.58 if style == 2 else 0.66)
        t.blend(rm, (128, 62, 28), 0.7)
        t.mul(rm & (xx % 4 == 2), 0.8)
        streak = (value_noise(T, T, 4, seed + 7) > 0.8) & (rust > 0.5)
        t.blend(streak, (98, 46, 24), 0.6)
        t.leaves(n2 > 0.7, 0.10, seed=6)
    elif style == 4:        # red standing-seam tin
        t.rgb[:] = np.array((134, 62, 46.0)) * (0.84 + 0.3 * n)[..., None]
        seam = xx % 8
        t.mul(seam == 0, 1.35)
        t.mul(seam == 1, 0.62)
        t.mul(seam == 7, 0.86)
        rust = fbm(T, T, 10, seed + 5, 3)
        t.blend(rust > 0.62, (98, 50, 30), 0.65)
        t.speckle(allm, 0.04, [(160, 88, 66)], seed=3)
        t.leaves(n2 > 0.66, 0.12, seed=6)
        t.speckle((n2 > 0.75) & (seam == 1), 0.6, MOSS, seed=7)
    elif style == 5:        # shifer (asbestos-cement wave sheets)
        t.rgb[:] = np.array((120, 120, 112.0)) * (0.82 + 0.3 * n)[..., None]
        wave = np.array([1.18, 1.1, 0.98, 0.84, 0.76, 0.84, 0.98, 1.1])
        t.mul(allm, wave[xx % 8])
        t.fill(yy % 21 == 20, (70, 70, 66))
        t.mul(yy % 21 == 0, 1.12)
        lich = fbm(T, T, 10, seed + 5, 3)
        t.blend(lich > 0.6, (96, 104, 60), 0.55)
        t.speckle(lich > 0.66, 0.3, [(150, 146, 96), (70, 84, 44)], seed=8)
        t.leaves(n2 > 0.7, 0.08, seed=6)
    return t.image()


EDGE = {  # coping / eave colour per roof style
    0: ((138, 134, 124), (92, 90, 84)), 1: ((146, 142, 132), (98, 96, 90)),
    2: ((96, 70, 52), (58, 44, 34)), 3: ((110, 118, 124), (60, 66, 72)),
    4: ((150, 74, 54), (84, 40, 30)), 5: ((140, 140, 132), (84, 84, 78)),
}


def roof_edges():
    """64x48 horizontal strips (rows of 8) + 48x64 vertical strips at x=64+style*8."""
    out = Image.new('RGBA', (64 + 48, 64))
    for st in range(6):
        top, face = EDGE[st]
        h = Tex(64, 8, top, seed=st + 90)
        n = fbm(64, 8, 16, st + 91, 2)
        h.mul(np.ones((8, 64), bool), 0.86 + 0.28 * n)
        if st in (0, 1, 5):         # concrete parapet: top, face, shadow on roof
            h.fill(h.mask_rect(0, 0, 64, 1), tuple(int(c * 1.12) for c in top))
            h.fill(h.mask_rect(0, 3, 64, 6), face)
            h.a[6:, :] = 110; h.rgb[6:, :] = (10, 10, 10)
            for x in range(0, 64, 16):
                h.fill(h.mask_rect(x, 0, x + 1, 6), tuple(int(c * 0.7) for c in face))
            h.speckle(h.mask_rect(0, 0, 64, 3), 0.15, MOSS, seed=st)
        else:                       # metal eave + gutter
            h.fill(h.mask_rect(0, 0, 64, 2), top)
            h.fill(h.mask_rect(0, 2, 64, 5), (72, 74, 74))
            h.fill(h.mask_rect(0, 3, 64, 4), (100, 104, 104))
            h.a[5:, :] = 100; h.rgb[5:, :] = (10, 10, 10)
            h.speckle(h.mask_rect(0, 2, 64, 5), 0.2, [(122, 62, 30)], seed=st)
        out.alpha_composite(h.image(), (0, st * 8))
        v = h.image().rotate(90, expand=True)          # 8x64, same material
        out.alpha_composite(v, (64 + st * 8, 0))
    return out


# ============================================================== ROOF PROPS ==
def roof_props():
    out = Image.new('RGBA', (256, 64))
    # 0: AC / ventilation block with fan grille
    s = Scene(64, 64, (32, 44))
    s.box(V(0, 0, 6), (14, 9, 6), (150, 150, 144))
    s.box(V(0, 0, 12.5), (14.5, 9.5, 0.6), (120, 120, 116), edge=False)
    for x in range(-10, 11, 3):
        s.line([V(x, 9.2, 2), V(x, 9.2, 10)], (96, 96, 92))
    s.ball(V(6, 0, 13.5), 5.0, (70, 72, 72))
    s.ball(V(6, 0, 14.0), 2.0, (40, 40, 42))
    s.box(V(-7, 0, 14), (4, 4, 1.5), (130, 130, 124))
    out.alpha_composite(grunge(s.render(), 1, 0.12, rust=0.12), (0, 0))
    # 1: vent pipes / exhaust stacks with caps
    s = Scene(64, 64, (32, 52))
    for (x, y, h, r) in [(-12, -4, 18, 3.2), (0, 2, 26, 3.8), (12, -2, 14, 2.8)]:
        s.cyl(V(x, y, 0), r, h, (120, 122, 120), bands=((h * 0.3, (84, 84, 82)), (h * 0.7, (84, 84, 82))))
        s.box(V(x, y, h + 1.2), (r + 1.4, r + 1.4, 1.0), (90, 92, 92))
    s.box(V(0, 0, 0.6), (18, 8, 0.6), (80, 80, 76), edge=False)
    out.alpha_composite(grunge(s.render(), 2, 0.12, rust=0.2), (64, 0))
    # 2: roof hatch + skylight
    s = Scene(64, 64, (32, 44))
    s.box(V(-8, 0, 3), (10, 12, 3), (110, 108, 100))
    s.box(V(-8, 0, 6.4), (8.5, 10.5, 0.4), (70, 92, 104), edge=False)
    for k in (-4, 0, 4):
        s.line([V(-16.5, k * 2, 6.9), V(0.5, k * 2, 6.9)], (60, 62, 60))
    s.px(V(-12, -4, 7), (170, 196, 206)); s.px(V(-11, -4, 7), (140, 170, 184))
    s.box(V(12, 2, 3.5), (6, 6, 3.5), (96, 96, 90))
    s.box(V(12, 2, 7.4), (6.6, 6.6, 0.6), (82, 84, 82))
    s.line([V(9, 8.6, 7), V(15, 8.6, 7)], (140, 140, 132))
    out.alpha_composite(grunge(s.render(), 3, 0.1, rust=0.08), (128, 0))
    # 3: antenna mast + dish + guy wires
    s = Scene(64, 64, (30, 58))
    s.box(V(0, 0, 1), (4, 4, 1), (90, 90, 86))
    s.line([V(0, 0, 2), V(0, 0, 40)], (70, 72, 72), 1)
    for z in (22, 30, 38):
        s.line([V(-9, 0, z), V(9, 0, z)], (86, 88, 88))
    for (x, y) in [(-16, 8), (16, 8), (0, -12)]:
        s.line([V(0, 0, 34), V(x, y, 0)], (54, 56, 56))
    s.ball(V(10, 4, 14), 5.5, (170, 170, 164))
    s.ball(V(10, 4, 14), 2.0, (120, 120, 116))
    s.box(V(10, 4, 6), (0.6, 0.6, 6), (80, 80, 80))
    out.alpha_composite(grunge(s.render(), 4, 0.08, rust=0.1), (192, 0))
    return out


# ============================================================== FACADES ==
FACADE_STYLES = 7


def facade_tile(style, var, seed):
    """32x28 front-wall tile, opaque."""
    rng = random.Random(seed)
    W, H = 32, 28
    t = Tex(W, H, (0, 0, 0), seed=seed)
    yy, xx = np.mgrid[0:H, 0:W]
    allm = np.ones((H, W), bool)
    n = fbm(W, H, 16, seed, 3)
    if style == 0:      # panel concrete
        t.rgb[:] = np.array((150, 142, 126.0)) * (0.84 + 0.28 * n)[..., None]
        t.fill((xx == 0), (92, 88, 78)); t.mul(xx == 1, 1.1)
        t.fill((yy == 13), (96, 92, 82)); t.mul(yy == 14, 1.08)
        t.speckle(allm, 0.08, [(120, 114, 102), (170, 162, 146)], seed=1)
    elif style == 1:    # clinic: small beige tiles + green stripe
        t.rgb[:] = np.array((168, 160, 140.0))
        t.mul(allm, 0.88 + 0.2 * value_noise(W, H, 4, seed))
        t.fill((xx % 4 == 0) | (yy % 4 == 0), (126, 120, 106))
        t.fill((yy >= 6) & (yy < 9), (58, 98, 80))
        t.mul(yy == 6, 1.2)
        t.mul(allm, 0.9 + 0.16 * n)
    elif style == 2:    # shop plaster (ochre)
        t.rgb[:] = np.array((150, 128, 96.0)) * (0.82 + 0.3 * n)[..., None]
        t.speckle(allm, 0.1, [(126, 108, 82), (168, 146, 112)], seed=1)
        # fallen plaster reveals brick
        m = t.mask_ellipse(rng.uniform(6, 26), rng.uniform(6, 20), rng.uniform(4, 8), rng.uniform(3, 5))
        if var in (1, 3):
            t.fill(m, (122, 64, 46))
            t.fill(m & ((yy % 4 == 0) | (((xx + (yy // 4) * 3) % 8) == 0)), (90, 80, 70))
    elif style == 3:    # brick garage wall
        t.rgb[:] = np.array((120, 62, 44.0))
        bn = value_noise(W, H, 4, seed + 3)
        t.mul(allm, 0.8 + 0.35 * bn)
        mortar = (yy % 4 == 3) | (((xx + (yy // 4 % 2) * 4) % 8) == 7)
        t.fill(mortar, (86, 78, 68))
        t.mul(allm, 0.86 + 0.24 * n)
        # whitewash band at the bottom
        t.blend(yy >= 22, (150, 146, 132), 0.55)
    elif style == 4:    # corrugated industrial wall (vertical ribs)
        t.rgb[:] = np.array((96, 104, 108.0))
        t.mul(allm, np.array([1.2, 1.04, 0.78, 0.92])[xx % 4])
        t.mul(allm, 0.86 + 0.26 * n)
        rust = fbm(W, H, 8, seed + 5, 3)
        t.blend(rust > 0.6, (124, 62, 30), 0.6)
        t.blend((rust > 0.52) & (yy > 18), (110, 56, 30), 0.4)
    elif style == 5:    # military painted block
        t.rgb[:] = np.array((96, 104, 84.0)) * (0.84 + 0.26 * n)[..., None]
        mortar = (yy % 7 == 6) | (((xx + (yy // 7 % 2) * 8) % 16) == 15)
        t.fill(mortar, (70, 76, 62))
        t.speckle(allm, 0.06, [(112, 120, 98), (80, 86, 70)], seed=1)
    elif style == 6:    # wooden siding (faded paint)
        paint = [(88, 116, 124), (98, 118, 80), (140, 118, 76), (110, 96, 80)][var % 4]
        t.rgb[:] = np.array(paint, float)
        t.mul(allm, 0.84 + 0.3 * n)
        board = yy % 5
        t.mul(board == 0, 1.2); t.mul(board == 4, 0.62)
        grain = value_noise(W, H, 3, seed + 4)
        peel = fbm(W, H, 6, seed + 6, 2) > 0.62
        t.blend(peel, (104, 84, 62), 0.8)                 # bare wood
        t.mul(allm, 0.94 + 0.1 * grain)
    # --- variant dressing
    if var == 1 and style in (0, 1, 2, 5):      # drainpipe
        t.fill((xx >= 26) & (xx < 29), (96, 100, 100))
        t.mul((xx == 26), 1.25); t.mul(xx == 28, 0.7)
        t.fill((xx >= 25) & (xx < 30) & ((yy == 6) | (yy == 20)), (70, 72, 72))
        t.blend((xx >= 25) & (xx < 31) & (yy > 20), (60, 50, 40), 0.25)
    if var == 2 and style in (0, 2, 3, 5):      # AC unit / vent box
        m = t.mask_rect(8, 4, 22, 14)
        t.fill(m, (168, 168, 160)); t.mul(t.mask_rect(8, 12, 22, 14), 0.72)
        e = t.mask_ellipse(17.5, 9, 3.4, 3.4); t.fill(e, (70, 72, 72))
        t.fill(t.mask_ellipse(17.5, 9, 1.2, 1.2), (40, 40, 42))
        for y in range(6, 12, 2):
            t.fill(t.mask_rect(9, y, 13, y + 1), (120, 120, 114))
        t.blend(t.mask_rect(10, 14, 21, 28), (70, 60, 50), 0.3)   # drip stain
        t.fill(t.mask_rect(8, 3, 22, 4), (40, 40, 40))
    if var == 3:                                 # graffiti tag / crack / stains
        if style in (0, 2, 5):
            col = random.Random(seed).choice([(170, 60, 50), (60, 110, 150), (190, 180, 170)])
            x = 4
            for i in range(9):
                t.px(x + i * 2.4, 16 + math.sin(i * 1.3) * 3, col)
                t.px(x + i * 2.4 + 1, 16 + math.sin(i * 1.3 + 0.5) * 3, col)
        for _ in range(2):
            t.crack(rng.uniform(4, 28), 1, 14, tuple(int(c * 0.55) for c in t.rgb[4, 4]), None, 0.5, math.pi / 2)
    # common: vertical rain streaks + grime at base + moss line
    streak = (value_noise(W, H, 3, seed + 11) > 0.72) & (yy > 6)
    t.mul(streak, 0.9)
    t.mul(allm, (1 - 0.35 * np.clip((yy - 18) / 10, 0, 1)))
    t.speckle(yy >= 25, 0.35, MOSS + [(60, 52, 40)], seed=12)
    t.mul(yy <= 1, 0.7)                         # eave shadow at top
    return t.image()


def facade_atlas():
    out = Image.new('RGBA', (128, 28 * FACADE_STYLES))
    for st in range(FACADE_STYLES):
        for v in range(4):
            out.alpha_composite(facade_tile(st, v, 500 + st * 10 + v), (v * 32, st * 28))
    return out


# ============================================================== WINDOWS ==
def window(state, seed, lit=False):
    W, H = 44, 32
    t = Tex(W, H, (0, 0, 0), alpha=0, seed=seed)
    frame = (178, 172, 156)
    outer = t.mask_rect(4, 2, 40, 27)
    t.fill(outer, (46, 44, 40))                     # reveal / shadowed opening
    inner = t.mask_rect(6, 4, 38, 25)
    glass = np.array((46, 60, 70.0)) if not lit else np.array((210, 150, 70.0))
    yy, xx = np.mgrid[0:H, 0:W]
    grad = np.clip((yy - 4) / 21.0, 0, 1)
    t.rgb[inner] = (glass * (1.15 - 0.35 * grad[..., None]))[inner]
    t.a[inner] = 255
    if not lit:
        refl = inner & (np.abs((xx - 8) - (yy - 4) * 0.8) < 2.2)
        t.blend(refl, (120, 140, 150), 0.45)
        refl2 = inner & (np.abs((xx - 26) - (yy - 4) * 0.8) < 1.0)
        t.blend(refl2, (110, 130, 140), 0.3)
        # curtain hint
        cur = inner & (xx < 12) & (yy > 6)
        t.blend(cur, (110, 84, 70), 0.5)
    # frame bars
    for m in (t.mask_rect(6, 4, 38, 5), t.mask_rect(6, 24, 38, 25), t.mask_rect(6, 4, 7, 25),
              t.mask_rect(37, 4, 38, 25), t.mask_rect(21, 4, 23, 25), t.mask_rect(6, 12, 38, 13)):
        t.fill(m, frame)
    t.mul(t.mask_rect(6, 4, 38, 5), 1.08)
    t.mul(t.mask_rect(37, 4, 38, 25), 0.78)
    # sill
    t.fill(t.mask_rect(3, 27, 41, 29), (150, 146, 134))
    t.fill(t.mask_rect(3, 29, 41, 30), (70, 68, 62))
    t.a[27:30, 3:41] = 255
    t.blend(t.mask_rect(8, 30, 36, 32), (40, 34, 30), 0.35); t.a[30:32, 8:36] = 110
    if state == 1:                                  # broken
        rng = random.Random(seed)
        hole = t.mask_poly([(10, 6), (20, 5), (18, 12), (14, 22), (8, 18)])
        t.fill(hole & inner, (18, 18, 20))
        for _ in range(4):
            x0, y0 = rng.uniform(8, 20), rng.uniform(6, 22)
            t.line([(x0, y0), (x0 + rng.uniform(-6, 6), y0 + rng.uniform(-6, 6))], (190, 200, 204))
        t.fill(t.mask_rect(26, 16, 34, 24) & inner, (22, 22, 24))
    if state == 2:                                  # boarded up
        for (y0, sk) in [(7, 0.12), (15, -0.08), (21, 0.05)]:
            pts = [(3, y0 + 3 * sk * -4), (41, y0 - 3 * sk * 4), (41, y0 + 4 - 3 * sk * 4), (3, y0 + 4 + 3 * sk * 4)]
            m = t.mask_poly(pts)
            t.fill(m, (116, 84, 54)); t.a[m] = 255
            t.mul(m & (yy == int(y0)), 1.2)
            t.speckle(m, 0.12, [(90, 64, 42), (136, 102, 66)], seed=y0)
            t.px(6, y0 + 2, (60, 60, 60)); t.px(38, y0 + 2, (60, 60, 60))
    return t.image()


def windows():
    out = Image.new('RGBA', (44 * 4, 32))
    for i, (st, lit) in enumerate([(0, False), (1, False), (2, False), (0, True)]):
        out.alpha_composite(window(st, 700 + i, lit), (i * 44, 0))
    return out


# ============================================================== CANOPIES ==
def canopies():
    out = Image.new('RGBA', (256, 48))
    # 0 clinic: concrete canopy, green fascia, lamp
    s = Scene(64, 48, (32, 40))
    s.box(V(-20, 4, 7), (1.2, 1.2, 7), (120, 118, 110))
    s.box(V(20, 4, 7), (1.2, 1.2, 7), (120, 118, 110))
    s.box(V(0, 0, 15), (26, 9, 1.5), (140, 136, 126), face_cols={'front': (60, 100, 82)})
    s.box(V(0, 8, 13.2), (3, 1, 0.8), (230, 200, 130), edge=False)
    out.alpha_composite(grunge(s.render(), 11, 0.1, leaves=0.02), (0, 0))
    # 1 shop: faded striped awning
    s = Scene(64, 48, (32, 40))
    for i in range(-5, 5):
        col = (150, 60, 50) if i % 2 == 0 else (190, 180, 160)
        x = i * 5 + 2.5
        s.poly([V(x - 2.5, -4, 22), V(x + 2.5, -4, 22), V(x + 2.5, 10, 13), V(x - 2.5, 10, 13)], col)
    s.box(V(0, 10, 12), (26, 0.6, 1.5), (100, 50, 40))
    out.alpha_composite(grunge(s.render(), 12, 0.2, rust=0.05), (64, 0))
    # 2 industrial: corrugated canopy + hazard fascia + brackets
    s = Scene(64, 48, (32, 40))
    s.poly([V(-26, -4, 22), V(26, -4, 22), V(26, 10, 16), V(-26, 10, 16)], (90, 98, 104))
    for x in range(-26, 27, 3):
        s.line([V(x, -4, 22), V(x, 10, 16)], (70, 76, 82))
    for i in range(-13, 13):
        col = (190, 150, 40) if i % 2 == 0 else (30, 30, 30)
        s.poly([V(i * 2, 10, 16), V(i * 2 + 2, 10, 16), V(i * 2 + 2, 10, 14), V(i * 2, 10, 14)], col)
    for x in (-20, 20):
        s.line([V(x, -4, 12), V(x, 8, 16)], (60, 62, 64), 2)
    s.box(V(0, 9, 13), (2.5, 1, 0.8), (240, 190, 110), edge=False)
    out.alpha_composite(grunge(s.render(), 13, 0.14, rust=0.25), (128, 0))
    # 3 residential: slab over the entrance, bare bulb, small sign plate
    s = Scene(64, 48, (32, 40))
    s.box(V(0, 2, 14), (16, 8, 1.3), (132, 128, 118))
    s.box(V(0, 9, 12.4), (1.2, 1.0, 0.8), (240, 200, 120), edge=False)
    s.box(V(-10, 9.4, 11), (3, 0.3, 1.8), (60, 90, 130), edge=False)
    out.alpha_composite(grunge(s.render(), 14, 0.1, leaves=0.03), (192, 0))
    return out


# ============================================================== DOORS / CORNERS ==
def door_topdown():
    t = Tex(44, 14, (0, 0, 0), alpha=0, seed=5)
    t.fill(t.mask_rect(0, 3, 44, 12), (40, 38, 34))
    leaf = t.mask_rect(2, 4, 42, 11)
    t.fill(leaf, (96, 70, 46))
    t.mul(leaf & t.mask_rect(0, 4, 44, 6), 1.2)
    t.mul(leaf & t.mask_rect(0, 9, 44, 11), 0.78)
    for x in (12, 22, 32):
        t.fill(t.mask_rect(x, 4, x + 1, 11), (70, 50, 34))
    t.fill(t.mask_rect(35, 6, 38, 9), (180, 170, 130))
    t.speckle(leaf, 0.1, [(80, 58, 38), (112, 84, 56)], seed=3)
    t.a[12:14, 2:42] = 90; t.rgb[12:14, 2:42] = (10, 10, 10)
    return t.image()


def wall_corners():
    out = Image.new('RGBA', (64, 16))
    for i in range(4):
        t = Tex(16, 16, (126, 122, 110), seed=40 + i)
        n = fbm(16, 16, 8, 40 + i, 2)
        t.mul(np.ones((16, 16), bool), 0.84 + 0.3 * n)
        t.fill(t.mask_rect(0, 0, 16, 1), (150, 146, 134))
        t.fill(t.mask_rect(0, 15, 16, 16), (70, 68, 60))
        t.fill(t.mask_rect(0, 0, 1, 16), (150, 146, 134))
        t.fill(t.mask_rect(15, 0, 16, 16), (74, 72, 64))
        if i >= 2:
            t.mul(t.mask_rect(0, 10, 16, 16), 0.7)
            t.speckle(t.mask_rect(0, 12, 16, 16), 0.4, MOSS, seed=i)
        out.alpha_composite(t.image(), (i * 16, 0))
    return out


def build_all(P):
    import os
    rt = Image.new('RGBA', (64 * 6, 64))
    for st in range(6):
        rt.alpha_composite(roof_tile(st, 300 + st), (st * 64, 0))
    rt.save(os.path.join(P, 'roof_tiles_v3.png'))
    roof_edges().save(os.path.join(P, 'roof_edges_v1.png'))
    roof_props().save(os.path.join(P, 'roof_props_v4.png'))
    facade_atlas().save(os.path.join(P, 'facade_wall_tiles_v4.png'))
    windows().save(os.path.join(P, 'window_v3.png'))
    canopies().save(os.path.join(P, 'facade_detail_v2.png'))
    door_topdown().save(os.path.join(P, 'door_topdown_v2.png'))
    wall_corners().save(os.path.join(P, 'wall_corner_v2.png'))
