"""OSTATOK 0.88 full-height facade art.

facade_bands_v1.png     32x126: style s -> cornice 32x8 at y=s*18, plinth 32x10 at y=s*18+8
facade_windows_v1.png   192x280: row = style, col = state (0 intact, 1 broken, 2 boarded, 3 lit), cell 48x40
facade_features_v1.png  512x48: balcony, shop_display, roller_closed, roller_open, ribbon_window,
                        gate, hazard_plinth, flower_box  (64x48 cells, bottom aligned)
entrance_v1.png         448x80: style entrances 64x80, bottom = ground line
Styles: 0 panel 1 clinic 2 shop 3 garage 4 industrial 5 military 6 rural
"""
import math
import os
import random
import numpy as np
from PIL import Image
from wa_core import Tex, fbm, value_noise, LEAF_ORANGE, MOSS, outline_img

WALL = {0: (150, 142, 126), 1: (168, 160, 140), 2: (150, 128, 96), 3: (120, 62, 44),
        4: (96, 104, 108), 5: (96, 104, 84), 6: (110, 96, 80)}
TRIM = {0: (120, 114, 102), 1: (58, 98, 80), 2: (112, 90, 66), 3: (140, 136, 124),
        4: (70, 76, 82), 5: (70, 78, 62), 6: (190, 186, 172)}


def bands():
    out = Image.new('RGBA', (32, 126))
    for s in range(7):
        base = np.array(WALL[s], float)
        t = Tex(32, 8, tuple(base * 1.12), seed=900 + s)
        n = fbm(32, 8, 8, 900 + s, 2)
        t.mul(np.ones((8, 32), bool), 0.88 + 0.24 * n)
        t.fill(t.mask_rect(0, 0, 32, 1), tuple(min(255, int(c * 1.3)) for c in base))
        t.fill(t.mask_rect(0, 5, 32, 6), tuple(int(c * 0.7) for c in base))
        t.fill(t.mask_rect(0, 6, 32, 8), (24, 24, 22))                 # cornice shadow on wall
        t.a[6:8, :] = 150
        if s in (3, 6):
            t.fill(t.mask_rect(0, 1, 32, 5), TRIM[s])
        t.speckle(t.mask_rect(0, 0, 32, 2), 0.2, MOSS, seed=s)
        out.alpha_composite(t.image(), (0, s * 18))
        p = Tex(32, 10, (86, 84, 78), seed=950 + s)
        n2 = fbm(32, 10, 8, 950 + s, 2)
        p.mul(np.ones((10, 32), bool), 0.84 + 0.3 * n2)
        if s == 6:
            p.rgb[:] = (76, 70, 62)
            p.fill(p.mask_rect(0, 0, 32, 1), (110, 100, 86))
        else:
            p.fill(p.mask_rect(0, 0, 32, 1), (120, 118, 110))
            p.fill(p.mask_rect(0, 1, 32, 2), (60, 58, 54))
            p.fill((np.mgrid[0:10, 0:32][1] % 16) == 0, (62, 60, 56))
        p.speckle(p.mask_rect(0, 5, 32, 10), 0.3, MOSS + [(60, 52, 40)], seed=s)
        p.leaves(p.mask_rect(0, 7, 32, 10), 0.12, seed=s)
        p.mul(p.mask_rect(0, 8, 32, 10), 0.7)
        out.alpha_composite(p.image(), (0, s * 18 + 8))
    return out


# ---------------------------------------------------------------- windows --
def _glass(t, m, lit, seed):
    yy, xx = np.mgrid[0:t.h, 0:t.w]
    ys = np.nonzero(m)[0]
    if len(ys) == 0:
        return
    y0, y1 = ys.min(), ys.max() + 1
    g = np.clip((yy - y0) / max(1, y1 - y0), 0, 1)
    if lit:
        col = np.array((226, 164, 76.0)) * (1.05 - 0.3 * g)[..., None]
        t.rgb[m] = col[m]; t.a[m] = 255
        cur = m & (value_noise(t.w, t.h, 3, seed) > 0.62)
        t.blend(cur, (170, 96, 50), 0.6)                    # curtain folds
    else:
        col = np.array((44, 58, 68.0)) * (1.2 - 0.4 * g)[..., None]
        t.rgb[m] = col[m]; t.a[m] = 255
        refl = m & (np.abs((xx - xx[m].min() - 2) - (yy - y0) * 0.8) < 1.6)
        t.blend(refl, (126, 146, 156), 0.5)
        if random.Random(seed).random() < 0.5:
            t.blend(m & (xx < xx[m].min() + 4) & (yy > y0 + 2), (116, 90, 72), 0.55)


def _damage(t, m, state, seed):
    rng = random.Random(seed)
    ys, xs = np.nonzero(m)
    if state == 1:
        cx, cy = xs.mean(), ys.mean()
        hole = t.mask_poly([(cx - 5, cy - 4), (cx + 2, cy - 6), (cx + 5, cy + 1), (cx - 1, cy + 6), (cx - 6, cy + 2)])
        t.fill(hole & m, (16, 16, 18))
        for _ in range(3):
            x0, y0 = cx + rng.uniform(-4, 4), cy + rng.uniform(-4, 4)
            t.line([(x0, y0), (x0 + rng.uniform(-5, 5), y0 + rng.uniform(-5, 5))], (180, 190, 196))
    elif state == 2:
        x0, x1, y0, y1 = xs.min() - 2, xs.max() + 2, ys.min(), ys.max()
        for k, fy in enumerate((0.15, 0.5, 0.82)):
            y = y0 + (y1 - y0) * fy
            sk = (k - 1) * 1.2
            pm = t.mask_poly([(x0, y - 2 + sk), (x1, y - 2 - sk), (x1, y + 2 - sk), (x0, y + 2 + sk)])
            t.fill(pm, (118, 86, 54)); t.a[pm] = 255
            t.speckle(pm, 0.15, [(92, 66, 44), (140, 106, 70)], seed=k + seed)
            t.px(x0 + 1, y, (60, 60, 60), 255); t.px(x1 - 1, y, (60, 60, 60), 255)


def window_cell(style, state, seed):
    t = Tex(48, 40, (0, 0, 0), alpha=0, seed=seed)
    frame = {0: (170, 164, 150), 1: (206, 204, 196), 2: (96, 76, 56), 3: (90, 92, 90),
             4: (70, 76, 80), 5: (80, 86, 70), 6: (214, 210, 196)}[style]
    lit = state == 3
    if style in (0, 1, 2):
        w, h = (22, 20) if style == 0 else ((24, 20) if style == 1 else (26, 20))
        x0, y0 = 24 - w // 2, 20 - h // 2
        t.fill(t.mask_rect(x0 - 1, y0 - 1, x0 + w + 1, y0 + h + 1), (40, 38, 34)); t.a[y0 - 1:y0 + h + 1, x0 - 1:x0 + w + 1] = 255
        g = t.mask_rect(x0 + 1, y0 + 1, x0 + w - 1, y0 + h - 1)
        _glass(t, g, lit, seed)
        for m in (t.mask_rect(x0, y0, x0 + w, y0 + 1), t.mask_rect(x0, y0 + h - 1, x0 + w, y0 + h),
                  t.mask_rect(x0, y0, x0 + 1, y0 + h), t.mask_rect(x0 + w - 1, y0, x0 + w, y0 + h),
                  t.mask_rect(x0 + w // 2, y0, x0 + w // 2 + 1, y0 + h), t.mask_rect(x0, y0 + 7, x0 + w, y0 + 8)):
            t.fill(m, frame); t.a[m] = 255
        if style == 1 and not lit:            # blinds
            for y in range(y0 + 9, y0 + h - 1, 2):
                t.blend(t.mask_rect(x0 + 1, y, x0 + w - 1, y + 1), (170, 168, 160), 0.5)
        sill = t.mask_rect(x0 - 2, y0 + h, x0 + w + 2, y0 + h + 2)
        t.fill(sill, (150, 146, 134)); t.a[sill] = 255
        t.fill(t.mask_rect(x0 - 2, y0 + h + 1, x0 + w + 2, y0 + h + 2), (70, 68, 62))
        drip = t.mask_rect(x0, y0 + h + 2, x0 + w, y0 + h + 6)
        t.rgb[drip] = (30, 26, 22); t.a[drip] = 50
        g_all = t.mask_rect(x0, y0, x0 + w, y0 + h)
    elif style == 3:                          # small high garage window
        x0, y0, w, h = 13, 12, 22, 10
        t.fill(t.mask_rect(x0 - 1, y0 - 1, x0 + w + 1, y0 + h + 1), (40, 38, 34)); t.a[y0 - 1:y0 + h + 1, x0 - 1:x0 + w + 1] = 255
        g = t.mask_rect(x0, y0, x0 + w, y0 + h)
        _glass(t, g, lit, seed)
        for x in range(x0 + 5, x0 + w, 6):
            t.fill(t.mask_rect(x, y0, x + 1, y0 + h), frame)
        g_all = g
    elif style == 4:                          # industrial grid window
        x0, y0, w, h = 8, 12, 32, 16
        t.fill(t.mask_rect(x0 - 1, y0 - 1, x0 + w + 1, y0 + h + 1), (36, 38, 40)); t.a[y0 - 1:y0 + h + 1, x0 - 1:x0 + w + 1] = 255
        g = t.mask_rect(x0, y0, x0 + w, y0 + h)
        _glass(t, g, lit, seed)
        for x in range(x0, x0 + w + 1, 4):
            t.fill(t.mask_rect(x, y0, x + 1, y0 + h), frame)
        for y in (y0, y0 + 5, y0 + 10, y0 + h - 1):
            t.fill(t.mask_rect(x0, y, x0 + w, y + 1), frame)
        if not lit:
            rng = random.Random(seed)
            for _ in range(4):
                x, y = rng.randrange(x0 + 1, x0 + w - 3, 4), rng.choice([y0 + 1, y0 + 6, y0 + 11])
                t.fill(t.mask_rect(x, y, x + 3, y + 4), (18, 18, 20))
        g_all = g
    elif style == 5:                          # barred military window
        x0, y0, w, h = 15, 12, 18, 14
        t.fill(t.mask_rect(x0 - 1, y0 - 1, x0 + w + 1, y0 + h + 1), (38, 40, 36)); t.a[y0 - 1:y0 + h + 1, x0 - 1:x0 + w + 1] = 255
        g = t.mask_rect(x0, y0, x0 + w, y0 + h)
        _glass(t, g, lit, seed)
        for x in range(x0 + 2, x0 + w, 4):
            t.fill(t.mask_rect(x, y0 - 1, x + 1, y0 + h + 1), (50, 52, 50))
        t.fill(t.mask_rect(x0 - 1, y0 + 6, x0 + w + 1, y0 + 7), (50, 52, 50))
        g_all = g
    else:                                     # rural: carved nalichnik + open shutters
        x0, y0, w, h = 15, 10, 18, 18
        top = t.mask_poly([(x0 - 3, y0 - 1), (x0 + w / 2, y0 - 6), (x0 + w + 3, y0 - 1), (x0 + w + 3, y0 + 1), (x0 - 3, y0 + 1)])
        t.fill(top, (214, 210, 196)); t.a[top] = 255
        for x in range(x0 - 2, x0 + w + 3, 3):
            t.px(x, y0 + 2, (214, 210, 196), 255)
        frm = t.mask_rect(x0 - 2, y0 + 1, x0 + w + 2, y0 + h + 2)
        t.fill(frm, frame); t.a[frm] = 255
        g = t.mask_rect(x0, y0 + 2, x0 + w, y0 + h)
        _glass(t, g, lit, seed)
        t.fill(t.mask_rect(x0 + w // 2, y0 + 2, x0 + w // 2 + 1, y0 + h), frame)
        t.fill(t.mask_rect(x0, y0 + 8, x0 + w, y0 + 9), frame)
        for sx in (x0 - 9, x0 + w + 2):                      # shutters
            sm = t.mask_rect(sx, y0 + 1, sx + 7, y0 + h + 2)
            t.fill(sm, (70, 104, 120)); t.a[sm] = 255
            t.mul(sm & t.mask_rect(0, y0 + 9, 48, y0 + 10), 0.7)
            t.mul(sm & t.mask_rect(sx + 6, 0, sx + 7, 40), 0.75)
        sill = t.mask_rect(x0 - 3, y0 + h + 2, x0 + w + 3, y0 + h + 4)
        t.fill(sill, (200, 196, 182)); t.a[sill] = 255
        g_all = g
    if state in (1, 2):
        _damage(t, g_all, state, seed)
    return t.image()


def windows():
    out = Image.new('RGBA', (192, 280))
    for s in range(7):
        for st in range(4):
            out.alpha_composite(window_cell(s, st, 1000 + s * 10 + st), (st * 48, s * 40))
    return out


# ---------------------------------------------------------------- features --
def features():
    out = Image.new('RGBA', (512, 48))
    def cell(i, img):
        out.alpha_composite(img, (i * 64, 0))
    # 0 glazed balcony (panel): slab + railing panel + glazing
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=1)
    t.fill(t.mask_rect(12, 6, 52, 30), (60, 70, 76)); t.a[6:30, 12:52] = 255
    _glass(t, t.mask_rect(13, 7, 51, 29), False, 11)
    for x in range(12, 53, 8):
        t.fill(t.mask_rect(x, 6, x + 1, 30), (190, 186, 176))
    t.fill(t.mask_rect(10, 4, 54, 6), (160, 156, 146)); t.a[4:6, 10:54] = 255
    rail = t.mask_rect(10, 30, 54, 42)
    t.fill(rail, (92, 110, 128)); t.a[rail] = 255
    yy, xx = np.mgrid[0:48, 0:64]
    t.mul(rail & (xx % 4 == 0), 0.8)
    t.blend(rail & (fbm(64, 48, 6, 3, 2) > 0.6), (120, 64, 34), 0.6)
    t.fill(t.mask_rect(8, 42, 56, 45), (140, 136, 126)); t.a[42:45, 8:56] = 255
    t.fill(t.mask_rect(8, 45, 56, 47), (40, 38, 34)); t.a[45:47, 8:56] = 180
    # junk: skis / box on balcony, laundry
    t.fill(t.mask_rect(40, 26, 46, 31), (150, 120, 80)); t.a[26:31, 40:46] = 255
    t.speckle(rail, 0.05, LEAF_ORANGE, seed=4)
    cell(0, t.image())
    # 1 shop display window with half-down shutter
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=2)
    t.fill(t.mask_rect(6, 10, 58, 44), (40, 36, 32)); t.a[10:44, 6:58] = 255
    _glass(t, t.mask_rect(8, 12, 56, 42), False, 22)
    t.fill(t.mask_rect(8, 34, 56, 36), (96, 76, 56))
    for x in (8, 31, 55):
        t.fill(t.mask_rect(x, 12, x + 1, 42), (96, 76, 56))
    sh = t.mask_rect(6, 10, 58, 24)
    t.fill(sh, (120, 124, 124)); t.a[sh] = 255
    t.mul(sh & (yy % 2 == 0), 0.82)
    t.blend(sh & (fbm(64, 48, 6, 5, 2) > 0.62), (160, 60, 50), 0.7)       # graffiti on shutter
    t.fill(t.mask_rect(4, 8, 60, 10), (70, 70, 68)); t.a[8:10, 4:60] = 255
    t.fill(t.mask_rect(20, 16, 44, 19), (60, 60, 60))                  # sticker/posters
    cell(1, t.image())
    # 2,3 roller doors (closed / half-open)
    for i, open_ in ((2, False), (3, True)):
        t = Tex(64, 48, (0, 0, 0), alpha=0, seed=3 + i)
        t.fill(t.mask_rect(6, 6, 58, 48), (46, 44, 40)); t.a[6:48, 6:58] = 255
        door = t.mask_rect(8, 9 if not open_ else 9, 56, 48 if not open_ else 30)
        col = [(92, 110, 120), (140, 70, 50), (96, 112, 84)][(i + 1) % 3]
        t.fill(door, col)
        t.mul(door & (yy % 3 == 0), 0.72)
        t.mul(door & (yy % 3 == 1), 1.12)
        t.blend(door & (fbm(64, 48, 6, 7 + i, 3) > 0.6), (122, 60, 30), 0.65)
        if open_:
            dark = t.mask_rect(8, 30, 56, 48)
            t.fill(dark, (14, 14, 16))
            t.fill(t.mask_rect(8, 30, 56, 31), (60, 60, 58))
        t.fill(t.mask_rect(6, 4, 58, 7), (70, 72, 72)); t.a[4:7, 6:58] = 255   # roll housing
        for x in (6, 57):                                                        # hazard stripes
            for y in range(7, 48, 4):
                t.fill(t.mask_rect(x, y, x + 1, y + 2), (200, 160, 40))
        t.fill(t.mask_rect(28, 42, 36, 44), (40, 40, 40)) if not open_ else None
        cell(i, t.image())
    # 4 ribbon window (industrial upper band)
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=8)
    t.fill(t.mask_rect(2, 18, 62, 32), (36, 38, 40)); t.a[18:32, 2:62] = 255
    _glass(t, t.mask_rect(3, 19, 61, 31), False, 88)
    for x in range(3, 62, 5):
        t.fill(t.mask_rect(x, 19, x + 1, 31), (70, 76, 80))
    t.fill(t.mask_rect(3, 25, 61, 26), (70, 76, 80))
    rng = random.Random(8)
    for _ in range(5):
        x = rng.randrange(4, 58, 5); y = rng.choice([20, 26])
        t.fill(t.mask_rect(x, y, x + 4, y + 5), (16, 16, 18))
    cell(4, t.image())
    # 5 industrial sliding gate
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=9)
    t.fill(t.mask_rect(4, 4, 60, 48), (40, 40, 38)); t.a[4:48, 4:60] = 255
    g = t.mask_rect(6, 7, 58, 48)
    t.fill(g, (86, 96, 102))
    t.mul(g & (xx % 4 == 0), 0.76); t.mul(g & (xx % 4 == 1), 1.16)
    t.fill(g & ((xx == 32) | (yy == 26)), (60, 64, 68))
    t.blend(g & (fbm(64, 48, 6, 10, 3) > 0.58), (124, 62, 30), 0.65)
    t.fill(t.mask_rect(4, 4, 60, 7), (190, 160, 40)); t.mul(t.mask_rect(4, 4, 60, 7) & ((xx // 4) % 2 == 0), 0.2)
    cell(5, t.image())
    # 6 hazard plinth (checkpoint)
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=10)
    m = t.mask_rect(0, 38, 64, 48)
    t.fill(m, (200, 160, 40)); t.a[m] = 255
    t.fill(m & (((xx + yy) // 5) % 2 == 0), (36, 36, 36))
    t.blend(m & (fbm(64, 48, 5, 11, 2) > 0.6), (80, 70, 50), 0.6)
    cell(6, t.image())
    # 7 flower box / window planter (rural)
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=12)
    b = t.mask_rect(16, 36, 48, 44)
    t.fill(b, (120, 84, 54)); t.a[b] = 255
    rng = random.Random(12)
    for _ in range(26):
        x, y = rng.randrange(17, 47), rng.randrange(30, 37)
        t.px(x, y, rng.choice([(180, 60, 50), (200, 150, 50), (90, 110, 50), (70, 90, 40)]), 255)
    cell(7, t.image())
    return out


# ---------------------------------------------------------------- entrances --
def entrance(style, seed):
    W, H = 64, 80
    t = Tex(W, H, (0, 0, 0), alpha=0, seed=seed)
    yy, xx = np.mgrid[0:H, 0:W]
    cx = 32
    dw, dh = (18, 30) if style not in (4, 5) else (20, 30)
    steps = style in (0, 1, 6)
    base = H - (6 if steps else 1)
    dx0, dy0 = cx - dw // 2, base - dh
    # recess / frame
    fr = t.mask_rect(dx0 - 3, dy0 - 3, dx0 + dw + 3, base)
    t.fill(fr, (38, 36, 32)); t.a[fr] = 255
    frame_col = {0: (120, 116, 106), 1: (200, 198, 190), 2: (96, 76, 56), 3: (80, 82, 80),
                 4: (70, 76, 80), 5: (80, 86, 70), 6: (214, 210, 196)}[style]
    for m in (t.mask_rect(dx0 - 2, dy0 - 2, dx0 + dw + 2, dy0), t.mask_rect(dx0 - 2, dy0, dx0, base),
              t.mask_rect(dx0 + dw, dy0, dx0 + dw + 2, base)):
        t.fill(m, frame_col)
    door = t.mask_rect(dx0, dy0, dx0 + dw, base)
    door_col = {0: (62, 88, 72), 1: (46, 58, 68), 2: (92, 70, 48), 3: (96, 104, 106),
                4: (90, 98, 104), 5: (70, 80, 62), 6: (116, 84, 54)}[style]
    t.fill(door, door_col)
    n = fbm(W, H, 6, seed, 2)
    t.mul(door, 0.86 + 0.28 * n)
    if style == 1:                                  # glass double door
        _glass(t, t.mask_rect(dx0 + 1, dy0 + 1, dx0 + dw - 1, base - 3), False, seed)
        t.fill(t.mask_rect(cx, dy0, cx + 1, base), (200, 198, 190))
        t.fill(t.mask_rect(dx0, dy0 + 14, dx0 + dw, dy0 + 15), (200, 198, 190))
    elif style == 2:                                # shop door with glass top
        _glass(t, t.mask_rect(dx0 + 2, dy0 + 2, dx0 + dw - 2, dy0 + 16), False, seed)
    elif style == 6:                                # wooden planks
        t.mul(door & (xx % 4 == 0), 0.7)
    else:
        t.fill(t.mask_rect(dx0 + 2, dy0 + 3, dx0 + dw - 2, dy0 + 4), tuple(int(c * 1.2) for c in door_col))
        t.fill(t.mask_rect(dx0 + 2, dy0 + 16, dx0 + dw - 2, dy0 + 17), tuple(int(c * 0.7) for c in door_col))
    t.px(dx0 + dw - 4, dy0 + dh // 2 + 1, (190, 180, 140), 255)       # handle
    t.px(dx0 + dw - 3, dy0 + dh // 2 + 1, (120, 110, 90), 255)
    t.blend(t.mask_rect(dx0, base - 6, dx0 + dw, base), (40, 34, 28), 0.35)
    if style == 0:
        t.fill(t.mask_rect(dx0 + dw + 4, dy0 + 10, dx0 + dw + 8, dy0 + 16), (70, 72, 74))   # intercom
        t.px(dx0 + dw + 5, dy0 + 11, (160, 200, 120), 255)
    # canopy slab (3/4: top face + front face) with lamp
    cw = {0: 22, 1: 26, 2: 0, 3: 18, 4: 20, 5: 18, 6: 18}[style]
    if style == 2:                                  # striped awning
        for i in range(-12, 12):
            col = (150, 60, 50) if (i // 3) % 2 == 0 else (196, 186, 164)
            t.fill(t.mask_poly([(cx + i * 1.5, dy0 - 12), (cx + i * 1.5 + 1.5, dy0 - 12),
                                (cx + i * 1.9 + 1.9, dy0 - 4), (cx + i * 1.9, dy0 - 4)]), col)
        am = (yy >= dy0 - 12) & (yy < dy0 - 3) & (np.abs(xx - cx) < 24)
        t.a[am] = np.maximum(t.a[am], 255)
        t.fill(t.mask_rect(cx - 23, dy0 - 4, cx + 23, dy0 - 2), (100, 44, 36)); t.a[dy0 - 4:dy0 - 2, cx - 23:cx + 23] = 255
    elif style == 6:                                # little gable porch roof
        roof = t.mask_poly([(cx - cw - 3, dy0 - 3), (cx, dy0 - 16), (cx + cw + 3, dy0 - 3), (cx + cw + 3, dy0 - 1), (cx - cw - 3, dy0 - 1)])
        t.fill(roof, (134, 62, 46)); t.a[roof] = 255
        t.mul(roof & (xx > cx), 0.8)
        for x in (cx - cw, cx + cw - 2):
            pm = t.mask_rect(x, dy0 - 3, x + 2, base)
            t.fill(pm, (150, 120, 84)); t.a[pm] = 255
    else:
        top = t.mask_rect(cx - cw, dy0 - 10, cx + cw, dy0 - 6)
        front = t.mask_rect(cx - cw, dy0 - 6, cx + cw, dy0 - 3)
        slab_col = {0: (140, 136, 126), 1: (150, 148, 140), 3: (96, 102, 108), 4: (90, 98, 104), 5: (96, 104, 84)}[style]
        t.fill(top, tuple(int(c * 1.1) for c in slab_col)); t.a[top] = 255
        t.fill(front, tuple(int(c * 0.78) for c in slab_col)); t.a[front] = 255
        if style == 1:
            t.fill(front, (58, 98, 80))
        if style in (3, 4):
            for x in range(cx - cw, cx + cw, 3):
                t.fill(t.mask_rect(x, dy0 - 10, x + 1, dy0 - 6), tuple(int(c * 0.8) for c in slab_col))
        t.leaves(top, 0.15, seed=seed)
        t.speckle(top, 0.12, MOSS, seed=seed + 1)
        sh = t.mask_rect(cx - cw + 2, dy0 - 3, cx + cw - 2, dy0 + 1) & (t.a > 0)
        t.mul(sh, 0.6)
    # lamp under the canopy / over the door
    lamp_y = dy0 - 2 if style not in (2, 6) else dy0 - 1
    t.fill(t.mask_rect(cx - 2, lamp_y, cx + 2, lamp_y + 2), (250, 214, 140)); t.a[lamp_y:lamp_y + 2, cx - 2:cx + 2] = 255
    t.px(cx - 2, lamp_y + 2, (140, 110, 70), 255); t.px(cx + 1, lamp_y + 2, (140, 110, 70), 255)
    # plaque / signs
    if style == 1:
        pm = t.mask_rect(cx - 5, dy0 - 22, cx + 5, dy0 - 12)
        t.fill(pm, (220, 216, 206)); t.a[pm] = 255
        t.fill(t.mask_rect(cx - 1, dy0 - 21, cx + 1, dy0 - 13), (180, 40, 34))
        t.fill(t.mask_rect(cx - 4, dy0 - 18, cx + 4, dy0 - 16), (180, 40, 34))
    if style == 0:
        pm = t.mask_rect(dx0 - 10, dy0 + 2, dx0 - 4, dy0 + 7)
        t.fill(pm, (52, 90, 140)); t.a[pm] = 255
        t.fill(t.mask_rect(dx0 - 8, dy0 + 3, dx0 - 6, dy0 + 6), (220, 220, 210))
    if style in (3, 4):
        for x in (dx0 - 4, dx0 + dw + 3):
            for y in range(dy0, base, 4):
                t.fill(t.mask_rect(x, y, x + 1, y + 2), (200, 160, 40)); t.a[y:y + 2, x:x + 1] = 255
    if style == 5:                                  # sandbags beside the door
        for (x, y) in [(dx0 - 12, base - 5), (dx0 - 12, base - 10), (dx0 + dw + 4, base - 5)]:
            bm = t.mask_ellipse(x + 4, y + 2, 5, 2.8)
            t.fill(bm, (134, 122, 88)); t.a[bm] = 255
            t.mul(bm & (yy > y + 2), 0.78)
        pm = t.mask_rect(cx - 4, dy0 - 20, cx + 4, dy0 - 13)
        t.fill(pm, (160, 40, 34)); t.a[pm] = 255
    # steps
    if steps:
        for k in range(3):
            y = base + k * 2
            sw = dw + 6 + k * 4
            sm = t.mask_rect(cx - sw // 2, y, cx + sw // 2, y + 2)
            t.fill(sm, (132, 128, 118) if style != 6 else (120, 92, 62)); t.a[sm] = 255
            t.fill(t.mask_rect(cx - sw // 2, y + 1, cx + sw // 2, y + 2), (88, 84, 76) if style != 6 else (80, 60, 40))
        t.leaves(t.mask_rect(cx - 20, base, cx + 20, H), 0.1, seed=seed + 3)
        if style in (0, 1):                         # handrails
            for x in (cx - dw // 2 - 6, cx + dw // 2 + 5):
                t.fill(t.mask_rect(x, base - 8, x + 1, H - 1), (70, 72, 70)); t.a[base - 8:H - 1, x:x + 1] = 255
    img = t.image()
    return outline_img(img, (20, 18, 16), alpha_cut=250)


def entrances():
    out = Image.new('RGBA', (64 * 7, 80))
    for s in range(7):
        out.alpha_composite(entrance(s, 1200 + s), (s * 64, 0))
    return out


def build_all(P):
    bands().save(os.path.join(P, 'facade_bands_v1.png'))
    windows().save(os.path.join(P, 'facade_windows_v1.png'))
    features().save(os.path.join(P, 'facade_features_v1.png'))
    entrances().save(os.path.join(P, 'entrance_v1.png'))


# ======================================================== 0.90 working doors ==
def door_geometry(style):
    dw = 20 if style in (4, 5) else 18
    base = 80 - (6 if style in (0, 1, 6) else 1)
    return 32 - dw // 2, base - 30, dw, base      # dx0, dy0, dw, base


def entrances_with_leaves():
    """entrance_v2.png: doorway is an open dark interior; door_leaf_v1.png: 7 x 24x32 leaves."""
    ent = Image.new('RGBA', (64 * 7, 80))
    leaves = Image.new('RGBA', (24 * 7, 32))
    for s in range(7):
        img = entrance(s, 1200 + s)
        dx0, dy0, dw, base = door_geometry(s)
        leaf = img.crop((dx0, dy0, dx0 + dw, base))
        # leaf outline so the swinging leaf reads against the dark opening
        leaf = outline_img(Image.fromarray(np.pad(np.array(leaf), ((1, 1), (1, 1), (0, 0)))), (20, 18, 16), alpha_cut=250)
        leaves.alpha_composite(leaf.crop((1, 1, dw + 1, 31)), (s * 24, 2))
        a = np.array(img).astype(float)
        ys = np.arange(dy0, base)
        for y in ys:                                   # dark interior with a warm floor glow
            t = (y - dy0) / 30.0
            col = np.array((14, 14, 16)) * (1 - t) + np.array((58, 40, 24)) * t
            a[y, dx0:dx0 + dw, :3] = col
            a[y, dx0:dx0 + dw, 3] = 255
        a[dy0:dy0 + 3, dx0:dx0 + dw, :3] *= 0.6
        ent.alpha_composite(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), (s * 64, 0))
    return ent, leaves


def light_pool():
    """128x96 warm pool with a vertical wet reflection streak and glints."""
    W, H = 128, 96
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx - 64) / 60.0) ** 2 + ((yy - 48) / 40.0) ** 2)
    a = np.clip(1 - d, 0, 1) ** 1.8 * 150
    streak = np.clip(1 - np.abs(xx - 64) / 5.0, 0, 1) * np.clip(1 - np.abs(yy - 56) / 34.0, 0, 1) * 120
    n = fbm(W, H, 4, 77, 2)
    streak *= (n > 0.4)
    a = np.clip(a + streak, 0, 210)
    rgb = np.zeros((H, W, 3)); rgb[...] = (255, 190, 110)
    rng = np.random.default_rng(78)
    gl = (rng.random((H, W)) < 0.012) & (d < 0.7)
    rgb[gl] = (255, 236, 190); a[gl] = 230
    img = np.dstack([rgb, a]).astype(np.uint8)
    return Image.fromarray(img, 'RGBA')


def extras():
    """facade_extras_v1.png 192x120: fire ladder (48x120), brick chimney (64x64 @48),
    industrial exhaust stack (64x120 @112)."""
    from wa_core import Scene, V, grunge
    out = Image.new('RGBA', (192, 120))
    t = Tex(48, 120, (0, 0, 0), alpha=0, seed=91)
    for x in (16, 30):
        m = t.mask_rect(x, 0, x + 2, 120)
        t.fill(m, (70, 72, 72)); t.a[m] = 255
        t.mul(t.mask_rect(x + 1, 0, x + 2, 120), 0.7)
    for y in range(4, 120, 6):
        m = t.mask_rect(16, y, 32, y + 1)
        t.fill(m, (96, 98, 96)); t.a[m] = 255
    for y in range(20, 120, 24):                       # safety cage hoops
        m = t.mask_rect(12, y, 36, y + 1)
        t.fill(m, (62, 64, 64)); t.a[m] = 255
        for x in (12, 35):
            mm = t.mask_rect(x, y, x + 1, y + 6); t.fill(mm, (62, 64, 64)); t.a[mm] = 255
    rn = fbm(48, 120, 6, 92, 2)
    t.blend((t.a > 0) & (rn > 0.6), (124, 62, 30), 0.7)
    sh = (t.a == 0) & (np.roll(t.a, -2, axis=1) > 0)
    t.rgb[sh] = (10, 10, 10); t.a[sh] = 70
    out.alpha_composite(t.image(), (0, 0))
    s = Scene(64, 64, (32, 58))
    s.box(V(0, 0, 11), (5, 5, 11), (128, 62, 44))
    s.box(V(0, 0, 22.6), (6.2, 6.2, 1.4), (100, 96, 90))
    for z in range(3, 22, 3):
        s.line([V(-5, 5.1, z), V(5, 5.1, z)], (96, 80, 70), 1, bias=1)
    out.alpha_composite(grunge(s.render(), 93, 0.14), (48, 0))
    s = Scene(64, 120, (32, 114))
    s.cyl(V(0, 0, 0), 6, 88, (110, 112, 110), bands=((20, (80, 80, 78)), (44, (80, 80, 78)), (68, (170, 60, 44)), (74, (220, 214, 200)), (80, (170, 60, 44))))
    s.box(V(0, 0, 2), (9, 9, 2), (90, 90, 86))
    for (x, y) in [(-18, 10), (18, 10), (0, -16)]:
        s.line([V(0, 0, 70), V(x, y, 0)], (60, 60, 60))
    out.alpha_composite(grunge(s.render(), 94, 0.12, rust=0.3), (112, 0))
    return out


def build_090(P):
    ent, leaves = entrances_with_leaves()
    ent.save(os.path.join(P, 'entrance_v2.png'))
    leaves.save(os.path.join(P, 'door_leaf_v1.png'))
    light_pool().save(os.path.join(P, 'light_pool_v1.png'))
    extras().save(os.path.join(P, 'facade_extras_v1.png'))
