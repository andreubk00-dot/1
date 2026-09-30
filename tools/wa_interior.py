"""OSTATOK 0.92 interior art pass (same 3/4 renderer + palette as the exterior)."""
import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw
from wa_core import Tex, fbm, value_noise, Scene, V, grunge, outline_img, fit_canvas, LEAF_ORANGE, MOSS, clamp8

R = random.Random


# ================================================================= FLOORS ==
def floor_tile(row, v, seed):
    t = Tex(32, 32, (0, 0, 0), seed=seed)
    yy, xx = np.mgrid[0:32, 0:32]
    allm = np.ones((32, 32), bool)
    n = fbm(32, 32, 16, seed, 3)
    rng = R(seed)
    if row == 0:      # clinic: 8px ceramic tiles, beige/grey checker, dark grout
        a, b = np.array((150, 146, 132.0)), np.array((120, 122, 116.0))
        chk = ((xx // 8 + yy // 8) % 2 == 0)
        t.rgb[chk] = a; t.rgb[~chk] = b
        t.mul(allm, 0.86 + 0.26 * n)
        t.fill((xx % 8 == 0) | (yy % 8 == 0), (74, 72, 66))
        t.mul((xx % 8 == 1) | (yy % 8 == 1), 1.08)
        if v in (2, 5):
            for _ in range(2):
                t.crack(rng.uniform(2, 30), rng.uniform(2, 30), 9, (70, 68, 62), None, 0.4)
        if v == 6:
            tx, ty = rng.randrange(0, 4) * 8, rng.randrange(0, 4) * 8
            m = t.mask_rect(tx + 1, ty + 1, tx + 8, ty + 8); t.fill(m, (70, 60, 48)); t.speckle(m, 0.3, [(90, 80, 64)], 1)
    elif row == 1:    # retail: speckled linoleum with worn traffic lane
        t.rgb[:] = np.array((122, 112, 96.0)) * (0.88 + 0.2 * n)[..., None]
        t.speckle(allm, 0.18, [(104, 96, 82), (140, 130, 112), (96, 108, 110)], 1)
        t.fill((yy == 0) | (xx == 0), (92, 84, 72))
        if v % 3 == 0:
            t.blend(allm, (100, 92, 80), 0.3)
        if v == 4:
            m = t.mask_ellipse(16, 16, 9, 6); t.blend(m, (140, 132, 118), 0.4)     # torn patch
            t.fill(m & (t.mask_ellipse(16, 16, 7, 4)), (84, 76, 64))
    elif row == 2:    # industrial concrete slab, oil, expansion joint
        t.rgb[:] = np.array((104, 104, 98.0)) * (0.8 + 0.3 * n)[..., None]
        t.speckle(allm, 0.12, [(90, 90, 86), (120, 118, 112)], 1)
        t.fill(xx == 0, (70, 70, 66)); t.fill(yy == 0, (70, 70, 66))
        if v in (1, 5):
            m = t.mask_ellipse(rng.uniform(8, 24), rng.uniform(8, 24), rng.uniform(5, 9), rng.uniform(3, 6))
            t.blend(m, (40, 40, 44), 0.55)
        if v in (3, 6):
            t.crack(rng.uniform(4, 28), 0, 20, (64, 64, 60), (128, 126, 120), 0.5, math.pi / 2)
        if v == 7:
            t.fill((yy >= 14) & (yy < 18) & ((xx // 4) % 2 == 0), (190, 160, 40))
    else:             # residential parquet (herringbone-ish planks), worn varnish
        rowi = yy // 4
        off = (rowi * 13) % 32
        plank = ((rowi * 7) + ((xx + off) // 32) * 3) % 5
        base = np.array((122, 84, 54.0))
        t.rgb[:] = base * (0.84 + 0.07 * plank[..., None])
        t.mul(allm, 0.9 + 0.18 * n)
        t.fill(yy % 4 == 0, (84, 56, 36))
        t.fill(((xx + off) % 32 == 0), (84, 56, 36))
        grain = value_noise(32, 32, 2, seed + 3)
        t.mul(allm, 0.94 + 0.1 * grain)
        if v in (2, 6):
            t.blend(t.mask_ellipse(16, 16, 10, 7), (140, 110, 80), 0.3)           # worn spot
        if v == 5:
            t.fill(t.mask_rect(4, 8, 20, 12), (40, 28, 20))                        # missing plank
    t.speckle(allm, 0.02, [(60, 56, 50)], 9)
    if v == 3:
        t.blend(t.mask_ellipse(rng.uniform(8, 24), rng.uniform(8, 24), 6, 4), (60, 54, 44), 0.35)  # grime
    return t.image()


def floors():
    out = Image.new('RGBA', (256, 128))
    for row in range(4):
        for v in range(8):
            out.alpha_composite(floor_tile(row, v, 3000 + row * 20 + v), (v * 32, row * 32))
    return out


# ================================================================= WALL BANDS ==
def wall_band(i, seed):
    t = Tex(32, 28, (0, 0, 0), seed=seed)
    yy, xx = np.mgrid[0:28, 0:32]
    allm = np.ones((28, 32), bool)
    n = fbm(32, 28, 12, seed, 3)
    upper = {0: (176, 178, 166), 1: (176, 178, 166), 2: (150, 132, 104), 3: (104, 118, 104),
             4: (140, 110, 90), 5: (124, 66, 46), 6: (150, 130, 110), 7: (120, 120, 140)}[i]
    t.rgb[:] = np.array(upper, float) * (0.86 + 0.26 * n)[..., None]
    if i in (0, 1):   # clinic: white tile dado + green stripe
        low = yy >= 14
        t.rgb[low] = (190, 196, 190)
        t.fill(low & ((xx % 6 == 0) | (yy % 6 == 2)), (150, 156, 150))
        t.fill((yy >= 12) & (yy < 14), (58, 98, 80))
    elif i == 5:      # brick
        t.fill((yy % 4 == 3) | (((xx + (yy // 4 % 2) * 4) % 8) == 7), (84, 74, 64))
        t.mul(allm, 0.9 + 0.15 * value_noise(32, 28, 4, seed))
    elif i in (6, 7): # faded wallpaper pattern + wooden dado
        pat = ((xx % 8 == 3) & (yy % 6 == 2)) | ((xx % 8 == 7) & (yy % 6 == 5))
        t.blend(pat, tuple(int(c * 0.72) for c in upper), 0.7)
        t.fill(yy >= 20, (104, 76, 50)); t.fill(yy == 20, (130, 96, 62))
    elif i == 3:      # painted concrete, two-tone Soviet
        t.fill(yy >= 15, (84, 100, 92)); t.fill(yy == 15, (60, 70, 64))
    elif i == 4:      # shop: posters remnants
        t.fill(t.mask_rect(6, 4, 16, 16), (200, 190, 160)); t.fill(t.mask_rect(18, 6, 26, 14), (170, 70, 50))
    if i in (1, 7):   # damage: hairline cracks + water stain
        rr = R(seed)
        t.crack(rr.uniform(6, 26), 2, 12, tuple(int(c * 0.6) for c in upper), None, 0.5, math.pi / 2, wrap=False)
        t.blend(t.mask_ellipse(rr.uniform(8, 24), 6, 7, 5), (110, 96, 70), 0.25)
    t.mul(allm, 1 - 0.3 * np.clip((yy - 20) / 8, 0, 1))
    t.fill(yy >= 26, (48, 44, 40))                      # baseboard shadow
    t.fill(yy <= 1, (32, 30, 28))                       # wall top edge
    return t.image()


def wall_bands():
    out = Image.new('RGBA', (256, 28))
    for i in range(8):
        out.alpha_composite(wall_band(i, 3200 + i), (i * 32, 0))
    return out


def trims():
    out = Image.new('RGBA', (128, 32))
    def shadow(w, h, axis, rev=False):
        a = np.zeros((h, w, 4), np.uint8)
        for k in range(h if axis == 0 else w):
            L = (h if axis == 0 else w)
            v = int(120 * (1 - k / L) ** 1.6)
            kk = (L - 1 - k) if rev else k
            if axis == 0:
                a[kk, :, 3] = v
            else:
                a[:, kk, 3] = v
        return Image.fromarray(a, 'RGBA')
    out.alpha_composite(shadow(32, 16, 0), (0, 0))                 # top wall -> floor shadow
    b = Tex(32, 16, (0, 0, 0), alpha=0, seed=5)                    # bottom: baseboard lip
    b.fill(b.mask_rect(0, 10, 32, 13), (96, 84, 70)); b.a[10:13, :] = 255
    b.fill(b.mask_rect(0, 13, 32, 14), (50, 44, 38)); b.a[13, :] = 255
    out.alpha_composite(b.image(), (32, 0))
    out.alpha_composite(shadow(16, 32, 1), (64, 0))                # left wall shadow
    out.alpha_composite(shadow(16, 32, 1, rev=True), (80, 0))      # right wall shadow
    m = Tex(32, 16, (0, 0, 0), alpha=0, seed=6)                    # threshold doormat
    mm = m.mask_rect(3, 3, 29, 13); m.fill(mm, (84, 62, 44)); m.a[mm] = 255
    m.fill(mm & ((np.mgrid[0:16, 0:32][1] % 3) == 0), (66, 48, 34))
    m.speckle(mm, 0.1, LEAF_ORANGE, 2)
    out.alpha_composite(m.image(), (96, 0))
    return out


def floor_details():
    out = Image.new('RGBA', (384, 32))
    for i in range(8):
        t = Tex(48, 32, (0, 0, 0), alpha=0, seed=3400 + i)
        yy, xx = np.mgrid[0:32, 0:48]
        n = fbm(48, 32, 8, 3400 + i, 3)
        rng = R(3400 + i)
        blob = (((xx - 24) / 18.0) ** 2 + ((yy - 16) / 11.0) ** 2 + (n - 0.5) * 0.9) < 1
        if i == 0:      # dried blood
            t.fill(blob, (92, 18, 16)); t.a[blob] = 210
            t.blend(blob & (n > 0.6), (60, 10, 10), 0.6)
            for _ in range(6):
                t.fill(t.mask_ellipse(rng.uniform(4, 44), rng.uniform(3, 29), 1.5, 1.2), (100, 20, 18))
        elif i == 1:    # papers
            for _ in range(5):
                x, y = rng.uniform(6, 38), rng.uniform(4, 22)
                m = t.mask_poly([(x, y), (x + 9, y - 2), (x + 11, y + 6), (x + 2, y + 8)])
                t.fill(m, rng.choice([(208, 202, 186), (190, 184, 160), (200, 196, 176)])); t.a[m] = 255
                t.fill(m & (yy % 2 == 0) & (xx % 5 != 0), (150, 146, 136))
        elif i == 2:    # glass shards
            for _ in range(14):
                x, y = rng.uniform(4, 44), rng.uniform(4, 28)
                m = t.mask_poly([(x, y), (x + rng.uniform(2, 5), y + 1), (x + 1, y + rng.uniform(2, 4))])
                t.fill(m, (160, 190, 196)); t.a[m] = 200
        elif i == 3:    # muddy footprints
            for k in range(5):
                t.fill(t.mask_ellipse(8 + k * 8, 12 + (k % 2) * 8, 2.5, 3.5), (64, 52, 38)); 
            t.a[t.rgb.sum(-1) > 0] = 170
        elif i == 4:    # water from the roof
            t.fill(blob, (46, 56, 66)); t.a[blob] = 170
            t.blend(blob & (np.abs(xx - yy - 8) < 2), (150, 166, 178), 0.6)
        elif i == 5:    # broken tiles pile
            for _ in range(10):
                x, y = rng.uniform(8, 40), rng.uniform(6, 24)
                m = t.mask_rect(x, y, x + rng.uniform(3, 6), y + rng.uniform(2, 4))
                t.fill(m, rng.choice([(170, 166, 150), (130, 128, 118)])); t.a[m] = 255
        elif i == 6:    # plaster dust + debris
            t.fill(blob, (150, 144, 130)); t.a[blob] = 120
            t.speckle(blob, 0.3, [(110, 104, 94), (130, 70, 50)], 3)
            t.a[blob & (t.rgb.sum(-1) < 400)] = 255
        else:           # leaves blown in
            t.leaves(blob, 0.25, seed=3)
            t.a[(t.rgb.sum(-1) > 0)] = 255
        out.alpha_composite(t.image(), (i * 48, 0))
    return out


# ================================================================= FURNITURE ==
METAL = (150, 154, 150); METAL_D = (96, 100, 98); WOODC = (128, 88, 56); WOOD_D = (96, 64, 40)
CLINIC_W = (200, 202, 194); GREEN = (70, 104, 84)
ITEM_COLS = [(190, 60, 50), (60, 110, 160), (220, 214, 196), (200, 160, 60), (90, 130, 80), (150, 120, 90), (160, 90, 140)]


def items_row(s, x0, x1, y, z, depth, rng, kind='mixed', fill=0.8):
    x = x0 + 1
    while x < x1 - 2:
        if rng.random() > fill:
            x += rng.uniform(2, 4); continue
        if kind in ('med', 'mixed') and rng.random() < 0.5:        # jars / bottles
            r = rng.uniform(1.0, 1.6); h = rng.uniform(2.5, 4.5)
            s.cyl(V(x + r, y, z), r, h, rng.choice([(200, 204, 196), (150, 90, 40), (90, 140, 160), (230, 226, 214)]), edge=False, bias=0.5)
            x += r * 2 + 0.6
        else:                                                       # boxes / books
            w = rng.uniform(2.5, 5); h = rng.uniform(3, 6)
            s.box(V(x + w / 2, y, z + h / 2), (w / 2, depth, h / 2), rng.choice(ITEM_COLS), edge=False, bias=0.5)
            x += w + 0.5


def shelf_unit(w=30, d=7, h=34, levels=4, col=METAL, kind='mixed', seed=1, glass=False, items=True):
    rng = R(seed)
    s = Scene(160, 128, (80, 110))
    for x in (-w, w):
        s.box(V(x, 0, h / 2), (0.8, d, h / 2), col)
    s.box(V(0, -d + 0.4, h / 2), (w, 0.4, h / 2), tuple(int(c * 0.7) for c in col), edge=False, bias=-1)
    for k in range(levels + 1):
        z = 1 + k * (h - 2) / levels
        s.box(V(0, 0, z), (w, d, 0.6), col)
        if items and k < levels:
            items_row(s, -w + 1, w - 1, 0, z + 0.6, d * 0.7, rng, kind)
    if glass:
        for x in (-w, 0, w):
            s.line([V(x, d + 0.3, 1), V(x, d + 0.3, h - 1)], tuple(int(c * 0.8) for c in col), 1, bias=3)
        s.line([V(-w, d + 0.3, h - 1), V(w, d + 0.3, h - 1)], tuple(int(c * 0.8) for c in col), 1, bias=3)
    img = s.render()
    if glass:   # faint blue-grey glass sheen with a diagonal reflection
        a = np.array(img).astype(float)
        yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
        m = a[..., 3] > 0
        a[m, :3] = a[m, :3] * 0.86 + np.array((150, 180, 190)) * 0.14
        refl = m & (np.abs((xx - 70) - (yy - 70) * 0.7) < 2)
        a[refl, :3] = a[refl, :3] * 0.6 + np.array((210, 226, 230)) * 0.4
        img = Image.fromarray(a.astype(np.uint8))
    return grunge(img, seed, 0.12, rust=0.08 if col == METAL else 0.0, dirt_bottom=0.2)


def cabinet(w=16, d=8, h=30, col=METAL, doors=2, seed=2, drawers=0, glass_top=False):
    s = Scene(160, 128, (80, 110))
    s.box(V(0, 0, h / 2), (w, d, h / 2), col)
    dark = tuple(int(c * 0.72) for c in col)
    if drawers:
        for k in range(drawers):
            z = h * (k + 0.5) / drawers
            s.line([V(-w + 1, d + 0.1, z - h / drawers / 2 + 0.5), V(w - 1, d + 0.1, z - h / drawers / 2 + 0.5)], dark, 1, bias=2)
            s.box(V(0, d + 0.3, z), (3, 0.3, 0.5), (60, 60, 60), edge=False, bias=3)
    else:
        for k in range(1, doors):
            x = -w + 2 * w * k / doors
            s.line([V(x, d + 0.1, 1), V(x, d + 0.1, h - 1)], dark, 1, bias=2)
        for k in range(doors):
            x = -w + 2 * w * (k + 0.5) / doors + (2 if k == 0 else -2)
            s.box(V(x, d + 0.3, h * 0.55), (0.4, 0.3, 1.5), (60, 60, 60), edge=False, bias=3)
    if glass_top:
        s.box(V(0, d + 0.2, h * 0.75), (w - 1.5, 0.2, h * 0.2), (110, 140, 150), edge=False, bias=2.5)
    return grunge(s.render(), seed, 0.12, rust=0.1, dirt_bottom=0.2)


def table(w=26, d=13, h=13, top=WOODC, legs=WOOD_D, seed=3, clutter='office'):
    rng = R(seed)
    s = Scene(160, 128, (80, 104))
    for x in (-w + 2, w - 2):
        for y in (-d + 2, d - 2):
            s.box(V(x, y, h / 2), (0.9, 0.9, h / 2), legs)
    s.box(V(0, 0, h), (w, d, 1), top)
    if clutter == 'office':
        s.box(V(-10, 0, h + 1.4), (5, 4, 0.4), (214, 208, 190), edge=False, bias=1)
        s.box(V(8, -2, h + 4), (5, 3.5, 3.4), (60, 62, 64))          # monitor
        s.box(V(8, 1.6, h + 4), (4, 0.2, 2.6), (40, 70, 80), edge=False, bias=2)
        s.cyl(V(-2, 5, h + 1), 1.2, 2.5, (220, 220, 210), edge=False)
    elif clutter == 'tools':
        s.box(V(-8, 0, h + 2), (6, 4, 1.5), (170, 40, 34))
        for i in range(4):
            s.line([V(4 + i * 3, -4, h + 1.2), V(6 + i * 3, 4, h + 1.2)], rng.choice([(60, 60, 60), (150, 150, 150)]), 1, bias=1)
        s.box(V(w + 1, 0, h - 2), (1, d, 1), (80, 80, 80))
        s.box(V(0, d + 0.2, h * 0.5), (w - 2, 0.3, 0.6), (80, 80, 80), edge=False, bias=1)
    elif clutter == 'reception':
        s.box(V(0, d - 1, h + 5), (w, 1, 5), top)
        s.box(V(-12, -2, h + 1.5), (4, 3, 0.4), (214, 208, 190), edge=False, bias=1)
        s.box(V(10, -2, h + 3), (3, 3, 2), (40, 40, 40))
    return grunge(s.render(), seed, 0.12, dirt_bottom=0.2, leaves=0.002)


def bed(hospital=True, seed=4, blood=False, bare=False):
    s = Scene(192, 128, (96, 104))
    frame = (160, 164, 160) if hospital else (110, 80, 56)
    for x in (-30, 30):
        for y in (-12, 12):
            s.box(V(x, y, 5), (1, 1, 5), frame)
    s.box(V(0, 0, 10), (31, 13, 1.2), frame)
    if not bare:
        s.box(V(0, 0, 13), (30, 12, 2.5), (170, 176, 176) if hospital else (120, 100, 80))
        s.box(V(-24, 0, 16.5), (5, 9, 1.5), (220, 220, 212))                  # pillow
        s.box(V(6, 0, 16.2), (22, 12.4, 0.9), (120, 150, 160) if hospital else (140, 90, 70))   # blanket
    s.box(V(-31, 0, 14), (1, 13, 8), frame)
    s.box(V(31, 0, 11), (1, 13, 5), frame)
    if hospital:
        for x in (-31, 31):
            s.ball(V(x, 12, 1.2), 1.2, (40, 40, 40))
    img = s.render()
    if blood:
        d = ImageDraw.Draw(img)
        d.ellipse([96, 62, 118, 72], fill=(110, 20, 18, 255))
    return grunge(img, seed, 0.12, rust=0.12, dirt_bottom=0.2)


def stretcher(seed=5):
    s = Scene(192, 128, (96, 104))
    for x in (-28, 28):
        s.line([V(x, -8, 1), V(x, -8, 12)], (140, 140, 136), 1); s.line([V(x, 8, 1), V(x, 8, 12)], (140, 140, 136), 1)
        s.ball(V(x, 8, 1), 1.2, (40, 40, 40))
    s.box(V(0, 0, 13), (32, 9, 1), (150, 150, 146))
    s.box(V(0, 0, 14.5), (30, 8, 1), (70, 104, 120))
    s.box(V(-4, 0, 16), (18, 7.5, 1.2), (190, 186, 172))
    return grunge(s.render(), seed, 0.1, rust=0.12)


def wheelchair(seed=6):
    s = Scene(160, 128, (80, 104))
    s.cyl(V(-6, 8, 0), 9, 1.2, (40, 40, 42), edge=False)
    s.box(V(0, 0, 10), (8, 8, 1), (60, 70, 80))
    s.box(V(-8, 0, 17), (1, 8, 7), (60, 70, 80))
    for y in (-8, 8):
        s.line([V(-8, y, 24), V(-12, y, 26)], (140, 140, 140), 1)
        s.line([V(8, y, 10), V(10, y, 2)], (140, 140, 140), 1)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.ellipse([60, 78, 84, 102], outline=(40, 40, 42, 255), width=2)
    d.ellipse([70, 88, 74, 92], fill=(120, 120, 120, 255))
    return grunge(img, seed, 0.08, rust=0.15)


def iv_stand(seed=7):
    s = Scene(96, 128, (48, 120))
    for a in range(5):
        ang = a * math.tau / 5
        s.line([V(0, 0, 1), V(math.cos(ang) * 6, math.sin(ang) * 6, 0)], (150, 150, 146), 1)
    s.cyl(V(0, 0, 0), 0.8, 50, (170, 170, 166))
    s.line([V(-5, 0, 50), V(5, 0, 50)], (170, 170, 166), 1)
    s.box(V(-4, 0, 45), (1.8, 0.8, 3.5), (200, 214, 220), bias=1)
    s.line([V(-4, 0, 41), V(-3, 2, 20)], (200, 200, 200), 1, bias=1)
    return grunge(s.render(), seed, 0.06)


def fridge(seed=8):
    s = Scene(128, 128, (64, 118))
    s.box(V(0, 0, 22), (11, 9, 22), (214, 212, 200))
    s.line([V(-11, 9.1, 30), V(11, 9.1, 30)], (150, 150, 144), 1, bias=2)
    s.box(V(8, 9.4, 36), (0.5, 0.3, 3), (120, 120, 120), edge=False, bias=3)
    s.box(V(8, 9.4, 20), (0.5, 0.3, 4), (120, 120, 120), edge=False, bias=3)
    img = s.render()
    return grunge(img, seed, 0.12, rust=0.3, dirt_bottom=0.3)


def radiator(seed=9):
    s = Scene(128, 96, (64, 80))
    for i in range(10):
        s.box(V(-18 + i * 4, 0, 8), (1.4, 3, 8), (190, 186, 172))
    s.line([V(-20, 0, 2), V(20, 0, 2)], (150, 146, 134), 1, bias=2)
    return grunge(s.render(), seed, 0.14, rust=0.3)


def sink(seed=10, broken=False):
    s = Scene(128, 96, (64, 84))
    s.box(V(0, 0, 10), (2, 2, 10), (200, 200, 194))
    s.box(V(0, 0, 21), (10, 7, 2.5), (220, 220, 214))
    s.box(V(0, 1, 23.2), (8, 5, 0.3), (120, 130, 132), edge=False, bias=1)
    s.box(V(0, -6, 27), (0.8, 0.8, 3), (160, 160, 160))
    img = s.render()
    if broken:
        d = ImageDraw.Draw(img); d.polygon([(64, 46), (74, 44), (70, 52)], fill=(40, 40, 40, 255))
    return grunge(img, seed, 0.12, rust=0.25)


def chair(seed=11, tipped=False, stool=False):
    s = Scene(96, 96, (48, 84))
    for x in (-4, 4):
        for y in (-4, 4):
            s.line([V(x, y, 0), V(x, y, 9)], (70, 70, 70), 1)
    s.box(V(0, 0, 10), (5, 5, 0.8), (150, 90, 60) if not stool else (170, 170, 164))
    if not stool:
        s.box(V(0, -5, 16), (5, 0.6, 5), (150, 90, 60))
    img = s.render()
    if tipped:
        img = img.rotate(80, expand=True, resample=Image.NEAREST)
    return grunge(img, seed, 0.12)


def locker(seed=12, col=(90, 110, 118)):
    s = Scene(128, 128, (64, 118))
    for i, x in enumerate((-9, 0, 9)):
        s.box(V(x, 0, 22), (4.4, 8, 22), col)
        for z in (38, 40, 42):
            s.line([V(x - 2, 8.1, z), V(x + 2, 8.1, z)], tuple(int(c * 0.6) for c in col), 1, bias=2)
        s.box(V(x + 2.5, 8.3, 24), (0.4, 0.3, 1.2), (60, 60, 60), edge=False, bias=3)
    return grunge(s.render(), seed, 0.14, rust=0.2)


def workbench(seed=13):
    return table(28, 12, 14, (120, 110, 96), (70, 72, 70), seed, 'tools')


def medical_screen(seed=14, folded=False):
    s = Scene(160, 128, (80, 112))
    n = 3
    for i in range(n):
        x = -20 + i * 20
        ang = 0.35 if folded else 0.0
        s.box(V(x, (i % 2) * 3, 18), (9, 0.6, 16), (190, 200, 196))
        s.line([V(x - 9, 0, 1), V(x - 9, 0, 35)], (140, 140, 136), 1, bias=1)
    return grunge(s.render(), seed, 0.14)


def curtain(seed=15):
    s = Scene(96, 128, (48, 124))
    s.line([V(-20, 0, 60), V(20, 0, 60)], (150, 150, 146), 1)
    for i in range(9):
        x = -18 + i * 4.5
        s.box(V(x, (i % 2) * 1.5, 30), (2.4, 0.5, 29), (120, 160, 150) if i % 2 else (100, 140, 130))
    return grunge(s.render(), seed, 0.12, dirt_bottom=0.3)


def simple_box(size, col, seed, stripes=False):
    s = Scene(128, 96, (64, 84))
    s.box(V(0, 0, size[2]), (size[0], size[1], size[2]), col)
    if stripes:
        s.line([V(-size[0], size[1] + 0.1, size[2]), V(size[0], size[1] + 0.1, size[2])], (60, 60, 60), 1, bias=2)
    return grunge(s.render(), seed, 0.14, dirt_bottom=0.2)


def med_cart(seed=16):
    s = Scene(128, 96, (64, 86))
    for x in (-10, 10):
        for y in (-6, 6):
            s.line([V(x, y, 1), V(x, y, 18)], (150, 150, 146), 1)
            s.ball(V(x, y, 0.8), 0.9, (40, 40, 40))
    for z in (6, 12, 18):
        s.box(V(0, 0, z), (11, 7, 0.5), (190, 194, 190))
    rng = R(seed)
    items_row(s, -10, 10, 0, 18.5, 4, rng, 'med')
    items_row(s, -10, 10, 0, 12.5, 4, rng, 'med')
    return grunge(s.render(), seed, 0.1, rust=0.1)


def cot(seed=17):
    s = Scene(160, 96, (80, 80))
    for x in (-24, 24):
        s.line([V(x, -8, 0), V(x, 8, 7)], (80, 90, 70), 1); s.line([V(x, 8, 0), V(x, -8, 7)], (80, 90, 70), 1)
    s.box(V(0, 0, 7.5), (26, 8, 0.8), (96, 110, 72))
    s.box(V(-4, 0, 9), (14, 7, 1.2), (110, 96, 70))
    return grunge(s.render(), seed, 0.14)


def mattress(seed=18):
    s = Scene(192, 96, (96, 70))
    s.box(V(0, 0, 2.5), (34, 14, 2.5), (170, 156, 120))
    img = s.render()
    d = ImageDraw.Draw(img)
    d.ellipse([100, 58, 130, 70], fill=(120, 100, 70, 255))
    for x in range(66, 134, 8):
        d.point((x, 60), fill=(130, 120, 90, 255))
    return grunge(img, seed, 0.2, dirt_bottom=0.2)


def lamp_stand(seed=19, base=True):
    s = Scene(96, 128, (48, 120))
    s.cyl(V(0, 0, 0), 5, 1.5, (60, 60, 60))
    s.cyl(V(0, 0, 1.5), 0.8, 30, (80, 80, 80))
    s.cyl(V(0, 0, 31), 5, 5, (190, 160, 110))
    s.box(V(0, 0, 30), (2, 2, 0.5), (255, 220, 150), edge=False, bias=2)
    return grunge(s.render(), seed, 0.08)


def heater(seed=20):
    s = Scene(96, 96, (48, 86))
    s.box(V(0, 0, 10), (8, 5, 10), (110, 110, 104))
    for z in (5, 9, 13, 17):
        s.line([V(-6, 5.1, z), V(6, 5.1, z)], (200, 90, 40), 1, bias=2)
    return grunge(s.render(), seed, 0.14, rust=0.3)


def crate_stack(seed=21, military=False):
    s = Scene(128, 96, (64, 86))
    col = (96, 108, 70) if military else (140, 104, 64)
    s.box(V(-6, 0, 6), (10, 7, 6), col)
    s.box(V(8, 2, 5), (7, 6, 5), col)
    if military:
        s.box(V(-6, 7.2, 6), (6, 0.2, 2), (200, 190, 150), edge=False, bias=2)
    else:
        for z in (3, 8):
            s.line([V(-16, 7.1, z), V(4, 7.1, z)], (100, 72, 44), 1, bias=2)
    return grunge(s.render(), seed, 0.16, dirt_bottom=0.2)


def weapon_rack(seed=22):
    s = Scene(160, 128, (80, 110))
    s.box(V(0, 0, 16), (22, 3, 16), (110, 84, 56))
    for i in range(5):
        x = -16 + i * 8
        s.line([V(x, 3.4, 4), V(x + 1, 3.4, 28)], (50, 50, 50), 2, bias=2)
        s.line([V(x, 3.6, 4), V(x, 3.6, 12)], (120, 80, 50), 2, bias=3)
    return grunge(s.render(), seed, 0.14)


def monitor(seed=23):
    s = Scene(96, 96, (48, 84))
    s.box(V(0, 0, 8), (8, 6, 7), (70, 72, 74))
    s.box(V(0, 6.2, 8), (6, 0.3, 5), (30, 40, 40), edge=False, bias=2)
    img = s.render(); d = ImageDraw.Draw(img); d.line([(44, 62), (48, 58), (52, 64)], fill=(170, 200, 200, 255))
    return grunge(img, seed, 0.1)


def oxygen(seed=24):
    s = Scene(96, 128, (48, 120))
    s.cyl(V(0, 0, 0), 4, 30, (60, 110, 160), bands=((26, (220, 220, 214)),))
    s.cyl(V(0, 0, 30), 1.4, 3, (150, 150, 150))
    return grunge(s.render(), seed, 0.1, rust=0.1)


def mop_bucket(seed=25, mop=True):
    s = Scene(96, 128, (48, 118))
    s.cyl(V(0, 0, 0), 5, 8, (200, 170, 40))
    if mop:
        s.line([V(1, 0, 6), V(-6, -2, 36)], (140, 110, 70), 1)
    return grunge(s.render(), seed, 0.12)


def toolbox(seed=26):
    return simple_box((9, 4, 3.5), (170, 40, 34), seed, stripes=True)


def wall_flat(kind, W, H, seed):
    """front-facing wall-mounted items"""
    t = Tex(W, H, (0, 0, 0), alpha=0, seed=seed)
    yy, xx = np.mgrid[0:H, 0:W]
    rng = R(seed)
    def rect(x0, y0, x1, y1, col, a=255):
        m = t.mask_rect(x0, y0, x1, y1); t.fill(m, col); t.a[m] = a; return m
    if kind == 'poster':
        m = rect(W * 0.2, H * 0.1, W * 0.8, H * 0.85, (206, 196, 170))
        rect(W * 0.25, H * 0.16, W * 0.75, H * 0.45, (170, 60, 50))
        for y in range(int(H * 0.5), int(H * 0.8), 3):
            rect(W * 0.26, y, W * 0.74, y + 1, (110, 100, 90))
        t.mul(m & (fbm(W, H, 5, seed, 2) > 0.62), 0.75)
    elif kind == 'notice':
        rect(4, 6, W - 4, H - 6, (120, 90, 60)); rect(6, 8, W - 6, H - 8, (160, 124, 86))
        for _ in range(8):
            x, y = rng.uniform(8, W - 14), rng.uniform(10, H - 18)
            rect(x, y, x + 8, y + 10, rng.choice([(214, 208, 190), (200, 190, 150), (170, 60, 50), (190, 200, 210)]))
    elif kind == 'clock':
        m = t.mask_ellipse(W / 2, H / 2, W * 0.42, H * 0.42); t.fill(m, (220, 216, 204)); t.a[m] = 255
        t.fill(m & ~t.mask_ellipse(W / 2, H / 2, W * 0.36, H * 0.36), (40, 40, 40))
        t.line([(W / 2, H / 2), (W / 2, H * 0.22)], (30, 30, 30)); t.line([(W / 2, H / 2), (W * 0.7, H / 2)], (30, 30, 30))
    elif kind == 'phone':
        rect(W * 0.25, H * 0.2, W * 0.75, H * 0.8, (190, 60, 40)); rect(W * 0.3, H * 0.25, W * 0.7, H * 0.4, (60, 60, 60))
        t.line([(W * 0.5, H * 0.8), (W * 0.4, H * 0.98)], (40, 40, 40))
    elif kind == 'sign_med':
        rect(4, 6, W - 4, H - 6, (214, 212, 204)); rect(W / 2 - 2, 9, W / 2 + 2, H - 9, (180, 40, 34)); rect(W / 2 - 8, H / 2 - 2, W / 2 + 8, H / 2 + 2, (180, 40, 34))
    elif kind == 'sign':
        rect(3, 8, W - 3, H - 8, (52, 90, 140)); rect(6, 12, W - 6, H - 12, (220, 220, 210))
        for x in range(9, W - 9, 5):
            rect(x, 14, x + 3, H - 14, (52, 90, 140))
    elif kind == 'fluoro':
        rect(4, H * 0.35, W - 4, H * 0.65, (180, 180, 172)); rect(6, H * 0.42, W - 6, H * 0.58, (250, 244, 210))
    elif kind == 'surgery_lamp':
        for (cx, cy) in [(W * 0.35, H * 0.45), (W * 0.65, H * 0.45), (W * 0.5, H * 0.65)]:
            m = t.mask_ellipse(cx, cy, W * 0.16, H * 0.14); t.fill(m, (200, 204, 200)); t.a[m] = 255
            m2 = t.mask_ellipse(cx, cy, W * 0.08, H * 0.07); t.fill(m2, (250, 244, 214))
        rect(W * 0.48, 0, W * 0.52, H * 0.4, (120, 120, 120))
    elif kind in ('wires', 'hanging_wires'):
        im = Image.new('RGBA', (W, H)); d = ImageDraw.Draw(im)
        for k in range(4):
            pts = [(x, 4 + k * 4 + (H * 0.5) * math.sin(x / W * math.pi) * (0.5 + 0.2 * k)) for x in range(W)]
            d.line(pts, fill=(30 + k * 6, 30, 30, 255))
        return im
    elif kind == 'crack':
        for _ in range(4):
            t.crack(W / 2 + rng.uniform(-4, 4), 4, H - 8, (40, 36, 32), None, 0.6, math.pi / 2, wrap=False)
        t.a[t.rgb.sum(-1) > 0] = 255
    elif kind == 'grime':
        n = fbm(W, H, 6, seed, 3)
        t.rgb[:] = (40, 36, 30); t.a[:] = np.clip((n - 0.45) * 300, 0, 110) * np.clip(yy / H + 0.3, 0, 1)
    elif kind == 'tool_wall':
        rect(4, 4, W - 4, H - 4, (130, 104, 70))
        for x in range(8, W - 8, 4):
            for y in range(8, H - 8, 4):
                t.px(x, y, (90, 70, 50), 255)
        for (x, y, w_, h_, c) in [(10, 10, 3, 24, (60, 60, 60)), (18, 12, 10, 3, (170, 40, 34)), (34, 10, 3, 20, (150, 150, 150)),
                                  (44, 14, 14, 4, (200, 160, 40)), (62, 10, 4, 26, (60, 60, 60)), (72, 12, 12, 12, (150, 150, 150))]:
            rect(x, y, min(W - 5, x + w_), min(H - 5, y + h_), c)
    elif kind == 'pipes':
        for (y, r, c) in [(H * 0.3, 3, (140, 142, 138)), (H * 0.55, 4, (120, 70, 50)), (H * 0.78, 2.5, (90, 110, 96))]:
            rect(0, y - r, W, y + r, c); rect(0, y - r, W, y - r + 1, tuple(min(255, int(v * 1.25)) for v in c))
            rect(0, y + r - 1, W, y + r, tuple(int(v * 0.6) for v in c))
        t.blend((t.a > 0) & (fbm(W, H, 6, seed, 2) > 0.6), (124, 62, 30), 0.6)
    elif kind == 'tarp':
        m = t.mask_poly([(4, 4), (W - 4, 6), (W - 10, H - 4), (W / 2, H - 10), (8, H - 2)])
        t.fill(m, (70, 96, 110)); t.a[m] = 255
        t.mul(m & (fbm(W, H, 8, seed, 3) > 0.55), 0.8)
    t.speckle(t.a > 0, 0.03, [(90, 84, 70)], 1)
    return t.image()


def floor_decal(kind, W, H, seed):
    t = Tex(W, H, (0, 0, 0), alpha=0, seed=seed)
    yy, xx = np.mgrid[0:H, 0:W]
    n = fbm(W, H, 8, seed, 3)
    rng = R(seed)
    blob = (((xx - W / 2) / (W * 0.42)) ** 2 + ((yy - H / 2) / (H * 0.40)) ** 2 + (n - 0.5) * 0.9) < 1
    if kind in ('blood', 'blood_pool_large'):
        t.fill(blob, (104, 18, 16)); t.a[blob] = 225
        t.blend(blob & (n > 0.58), (70, 10, 10), 0.6)
        t.blend(blob & (np.abs((xx - W * 0.4) - (yy - H * 0.35)) < 1.5), (170, 60, 50), 0.5)
    elif kind == 'blood_smear':
        for k in range(5):
            m = t.mask_poly([(W * 0.1, H * 0.5 + k * 2 - 4), (W * 0.9, H * 0.4 + k * 2 - 4), (W * 0.9, H * 0.4 + k * 2 - 3), (W * 0.1, H * 0.5 + k * 2 - 3)])
            t.fill(m, (100, 18, 16)); t.a[m] = 200 - k * 25
    elif kind == 'puddle':
        t.fill(blob, (44, 54, 64)); t.a[blob] = 190
        t.blend(blob & (np.abs((xx - W * 0.35) * 0.5 + (yy - H * 0.4)) < 1.2), (150, 166, 178), 0.6)
    elif kind in ('papers', 'floor_papers', 'newspapers', 'newspapers_wide', 'paper_stack'):
        for _ in range(int(W * H / 180)):
            x, y = rng.uniform(4, W - 14), rng.uniform(3, H - 10)
            m = t.mask_poly([(x, y), (x + 10, y - 2), (x + 12, y + 6), (x + 2, y + 8)])
            t.fill(m, rng.choice([(208, 202, 186), (190, 184, 160), (180, 176, 160)])); t.a[m] = 255
            t.fill(m & (yy % 2 == 0) & (xx % 4 != 0), (140, 136, 126))
    elif kind in ('glass', 'shattered_glass'):
        for _ in range(int(W * H / 60)):
            x, y = rng.uniform(3, W - 6), rng.uniform(3, H - 5)
            m = t.mask_poly([(x, y), (x + rng.uniform(2, 5), y + 1), (x + 1, y + rng.uniform(2, 4))])
            t.fill(m, (170, 200, 206)); t.a[m] = 210
    elif kind in ('debris', 'rubble_papers', 'broken_tile_pile', 'cabinet_debris', 'wooden_debris', 'barricade_scraps', 'rubble_crate'):
        t.fill(blob, (140, 134, 120)); t.a[blob] = 110
        for _ in range(int(W * H / 50)):
            x, y = rng.uniform(4, W - 8), rng.uniform(3, H - 6)
            c = rng.choice([(170, 166, 150), (130, 70, 50), (120, 86, 56), (110, 108, 100), (210, 204, 186)])
            m = t.mask_rect(x, y, x + rng.uniform(2, 7), y + rng.uniform(1.5, 4)); t.fill(m, c); t.a[m] = 255
            t.fill(m & (yy == int(y)), tuple(min(255, int(v * 1.2)) for v in c))
    elif kind in ('cables', 'cable_clutter', 'floor_cable'):
        im = Image.new('RGBA', (W, H)); d = ImageDraw.Draw(im)
        for k in range(3):
            pts = [(x, H / 2 + math.sin(x / (6 + k * 3) + k) * (H * 0.3)) for x in range(W)]
            d.line(pts, fill=[(30, 30, 30, 255), (160, 60, 40, 255), (50, 70, 110, 255)][k], width=1)
        return im
    elif kind == 'scattered_bottles':
        s = Scene(W, H, (W / 2, H * 0.65))
        for _ in range(8):
            x, y = rng.uniform(-W * 0.35, W * 0.35), rng.uniform(-6, 6)
            col = rng.choice([(60, 110, 60), (120, 80, 40), (180, 190, 190)])
            if rng.random() < 0.5:
                s.cyl(V(x, y, 0), 1.3, 5, col, edge=False)
            else:
                a_ = rng.uniform(0, math.tau)
                s.hcyl(V(x, y, 1.2), V(x + math.cos(a_) * 5, y + math.sin(a_) * 3, 1.2), 1.2, col)
        return s.render()
    elif kind in ('dirty_linen', 'folded_blanket'):
        m = blob; t.fill(m, (180, 176, 164) if kind == 'dirty_linen' else (110, 96, 120)); t.a[m] = 255
        t.mul(m & (n > 0.55), 0.78); t.speckle(m, 0.05, [(120, 90, 70)], 2)
    t.a[(t.a > 0) & (t.a < 255) & (kind in ('debris',))] = t.a[(t.a > 0) & (t.a < 255) & (kind in ('debris',))]
    return t.image()


def corpse(seed=30, bag=False):
    s = Scene(192, 96, (96, 70))
    if bag:
        s.box(V(0, 0, 3), (30, 8, 3), (40, 44, 46))
        s.line([V(-28, 0, 6.2), V(28, 0, 6.2)], (140, 140, 130), 1, bias=2)
    else:
        s.box(V(-4, 0, 2.5), (12, 6, 2.5), (80, 86, 70))
        s.ball(V(-20, 0, 3), 3.4, (170, 140, 120))
        s.box(V(16, -3, 2), (10, 2.2, 2), (60, 66, 80)); s.box(V(16, 3, 2), (10, 2.2, 2), (60, 66, 80))
    img = s.render()
    if not bag:
        d = ImageDraw.Draw(img); d.ellipse([70, 62, 110, 74], fill=(100, 18, 16, 200))
    return grunge(img, seed, 0.1)


def plant(seed=31):
    s = Scene(96, 128, (48, 118))
    s.cyl(V(0, 0, 0), 5, 7, (140, 80, 50))
    rng = R(seed)
    for _ in range(9):
        s.ball(V(rng.uniform(-5, 5), rng.uniform(-3, 3), rng.uniform(9, 20)), rng.uniform(2.5, 4), rng.choice([(110, 90, 40), (140, 110, 50), (90, 100, 50)]))
    return grunge(s.render(), seed, 0.1)


def generator(seed=32):
    s = Scene(160, 128, (80, 104))
    s.box(V(0, 0, 9), (18, 9, 9), (170, 130, 40))
    s.box(V(-7, 0, 19), (8, 7, 1), (70, 70, 66))
    return grunge(s.render(), seed, 0.14, rust=0.2)


# ---------------------------------------------------------------- mapping --
def interior_art():
    A = {}
    A['medical_shelf'] = lambda: shelf_unit(28, 7, 32, 4, CLINIC_W, 'med', 101)
    A['retail_shelf'] = lambda: shelf_unit(30, 8, 30, 4, (150, 140, 120), 'mixed', 102)
    A['metal_shelving'] = lambda: shelf_unit(40, 8, 34, 4, METAL, 'boxes', 103)
    A['pharmacy_cabinet'] = lambda: shelf_unit(26, 7, 34, 4, (180, 176, 164), 'med', 104, glass=True)
    A['large_med_cabinet'] = lambda: shelf_unit(32, 8, 38, 5, CLINIC_W, 'med', 105, glass=True)
    A['toppled_shelf'] = lambda: shelf_unit(28, 7, 30, 3, METAL, 'mixed', 106).rotate(-78, expand=True, resample=Image.NEAREST)
    A['locker'] = lambda: locker(107)
    A['cabinet'] = lambda: cabinet(16, 8, 30, METAL, 2, 108)
    A['drawer_cabinet'] = lambda: cabinet(12, 8, 26, (120, 124, 118), 0, 109, drawers=4)
    A['filing_cabinet'] = lambda: cabinet(10, 9, 30, (110, 116, 110), 0, 110, drawers=4)
    A['broken_cabinet'] = lambda: cabinet(22, 8, 22, WOODC, 2, 111).rotate(12, expand=True, resample=Image.NEAREST)
    A['desk'] = lambda: table(26, 13, 13, WOODC, WOOD_D, 112, 'office')
    A['counter'] = lambda: table(32, 10, 16, (150, 120, 90), (110, 84, 60), 113, 'reception')
    A['reception_desk'] = lambda: table(40, 12, 15, (160, 150, 130), (110, 104, 96), 114, 'reception')
    A['workbench'] = lambda: workbench(115)
    A['hospital_bed'] = lambda: bed(True, 116)
    A['cot'] = lambda: cot(117)
    A['stretcher'] = lambda: stretcher(118)
    A['wheelchair'] = lambda: wheelchair(119)
    A['iv_stand'] = lambda: iv_stand(120)
    A['rolling_stand'] = lambda: iv_stand(121)
    A['old_fridge'] = lambda: fridge(122)
    A['radiator'] = lambda: radiator(123)
    A['sink'] = lambda: sink(124)
    A['broken_sink_detail'] = lambda: sink(125, broken=True)
    A['chair'] = lambda: chair(126)
    A['tipped_chair'] = lambda: chair(127, tipped=True)
    A['broken_chair_detail'] = lambda: chair(128, tipped=True)
    A['exam_stool'] = lambda: chair(129, stool=True)
    A['medical_screen'] = lambda: medical_screen(130)
    A['folded_screen'] = lambda: medical_screen(131, folded=True)
    A['hospital_curtain'] = lambda: curtain(132)
    A['med_cart'] = lambda: med_cart(133)
    A['broken_trolley'] = lambda: med_cart(134).rotate(70, expand=True, resample=Image.NEAREST)
    A['old_mattress'] = lambda: mattress(135)
    A['base_lamp'] = lambda: lamp_stand(136)
    A['desk_lamp'] = lambda: lamp_stand(137)
    A['heater'] = lambda: heater(138)
    A['supply_crate'] = lambda: crate_stack(139)
    A['ammo_crate'] = lambda: crate_stack(140, military=True)
    A['medicine_boxes'] = lambda: crate_stack(141)
    A['med_supply_stack'] = lambda: crate_stack(142)
    A['medboxes_large'] = lambda: crate_stack(143)
    A['weapon_rack'] = lambda: weapon_rack(144)
    A['broken_monitor'] = lambda: monitor(145)
    A['defib_unit'] = lambda: monitor(146)
    A['oxygen_cylinder'] = lambda: oxygen(147)
    A['mop_bucket'] = lambda: mop_bucket(148, False)
    A['mop'] = lambda: mop_bucket(149, True)
    A['toolbox'] = lambda: toolbox(150)
    A['tool_case'] = lambda: simple_box((10, 5, 4), (60, 62, 64), 151, True)
    A['extinguisher'] = lambda: oxygen(152)
    A['plant'] = lambda: plant(153)
    A['corpse'] = lambda: corpse(154)
    A['body_bag'] = lambda: corpse(155, bag=True)
    A['med_tray'] = lambda: med_cart(156)
    A['generator'] = lambda: generator(157)
    for k, W, H in [('wall_poster', 48, 56), ('wall_notice_board', 80, 56), ('wall_clock', 32, 32), ('wall_phone', 32, 40),
                    ('med_sign', 56, 32), ('wall_sign', 64, 32), ('ceiling_fluorescent', 64, 32), ('surgery_lamp', 64, 64),
                    ('wall_wires', 80, 40), ('hanging_wires', 72, 56), ('wall_crack', 64, 56), ('wall_grime', 96, 56),
                    ('tool_wall_detail', 96, 64), ('ceiling_pipes', 88, 48), ('pipe_cluster', 80, 48), ('hanging_tarp', 80, 64)]:
        kind = {'wall_poster': 'poster', 'wall_notice_board': 'notice', 'wall_clock': 'clock', 'wall_phone': 'phone',
                'med_sign': 'sign_med', 'wall_sign': 'sign', 'ceiling_fluorescent': 'fluoro', 'surgery_lamp': 'surgery_lamp',
                'wall_wires': 'wires', 'hanging_wires': 'hanging_wires', 'wall_crack': 'crack', 'wall_grime': 'grime',
                'tool_wall_detail': 'tool_wall', 'ceiling_pipes': 'pipes', 'pipe_cluster': 'pipes', 'hanging_tarp': 'tarp'}[k]
        A[k] = (lambda kind=kind, W=W, H=H, k=k: ('flat', wall_flat(kind, W, H, hash(k) % 1000)))
    for k, W, H in [('blood', 48, 32), ('blood_pool_large', 96, 48), ('blood_smear', 80, 40), ('debris', 48, 32),
                    ('floor_papers', 80, 40), ('newspapers', 72, 40), ('newspapers_wide', 88, 40), ('paper_stack', 48, 32),
                    ('shattered_glass', 64, 40), ('rubble_papers', 96, 48), ('broken_tile_pile', 72, 40),
                    ('cabinet_debris', 88, 56), ('wooden_debris', 48, 64), ('barricade_scraps', 88, 48), ('rubble_crate', 80, 48),
                    ('cable_clutter', 80, 40), ('floor_cable', 96, 40), ('scattered_bottles', 72, 48),
                    ('dirty_linen', 64, 40), ('folded_blanket', 64, 40)]:
        A[k] = (lambda k=k, W=W, H=H: ('flat', floor_decal(k, W, H, abs(hash(k)) % 1000)))
    return A


REGIONS = None


def patch_props(src, dst, regions):
    atlas = Image.open(src).convert('RGBA')
    art = interior_art()
    done = []
    for k, fn in art.items():
        if k not in regions:
            continue
        x, y, w, h = regions[k]
        r = fn()
        flat = isinstance(r, tuple)
        img = r[1] if flat else r
        atlas.paste((0, 0, 0, 0), (x, y, x + w, y + h))
        if flat:
            if img.size != (w, h):
                img = img.resize((w, h), Image.NEAREST)
            atlas.alpha_composite(img, (x, y))
        else:
            atlas.alpha_composite(fit_canvas(img, w, h, 'bottom'), (x, y))
        done.append(k)
    atlas.save(dst)
    return done


def build_all(P, regions):
    floors().save(os.path.join(P, 'interior_floor_tiles_v5.png'))
    wall_bands().save(os.path.join(P, 'interior_wall_band_v4.png'))
    trims().save(os.path.join(P, 'interior_trim_v4.png'))
    floor_details().save(os.path.join(P, 'floor_detail_v5.png'))
    return patch_props(os.path.join(P, 'world_props_v18.png'), os.path.join(P, 'world_props_v19.png'), regions)
