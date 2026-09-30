"""OSTATOK 0.87 exterior props: trees, cars, fence, street decals, puddles,
street props (patched into world_props) and a new street-furniture atlas."""
import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw
from wa_core import (Tex, fbm, value_noise, Scene, V, grunge, outline_img, fit_canvas,
                     LEAF_ORANGE, MOSS, clamp8)


# ================================================================== TREES ==
def tree(kind, seed, W=88, H=136):
    rng = random.Random(seed)
    img = np.zeros((H, W, 4), float)
    yy, xx = np.mgrid[0:H, 0:W]
    base_x, base_y = W / 2, H - 6
    # ground shadow
    sh = ((xx - base_x - 6) / 26.0) ** 2 + ((yy - base_y) / 6.0) ** 2 <= 1
    img[sh] = (8, 10, 8, 90)

    def put(mask, rgb, a=255):
        img[mask, :3] = rgb[mask] if np.ndim(rgb) == 3 else rgb
        img[mask, 3] = a

    if kind == 'spruce':
        trunk = (np.abs(xx - base_x) <= 2) & (yy > base_y - 16) & (yy <= base_y)
        put(trunk, np.array((74, 52, 36.0)))
        tiers = 7
        for i in range(tiers):
            ty = base_y - 12 - i * 15
            half = 34 - i * 4.2
            tri = (yy >= ty - 22) & (yy <= ty) & (np.abs(xx - base_x) <= half * (yy - (ty - 22)) / 22.0)
            jag = value_noise(W, H, 3, seed + i) > 0.35
            tri &= jag | (np.abs(xx - base_x) < half * 0.7 * (yy - (ty - 22)) / 22.0)
            lit = np.clip(0.55 + 0.6 * (base_x - xx) / (half + 1) * 0.5 + 0.35 * (ty - yy) / 22.0, 0.4, 1.3)
            col = np.array((40, 62, 44.0))[None, None, :] * lit[..., None]
            put(tri, col)
            edge = tri & (yy >= ty - 1)
            put(edge, np.array((26, 38, 28.0)))
        n = fbm(W, H, 5, seed + 9, 2)
        a = img[..., 3] > 200
        m = a & (n > 0.66) & (yy < base_y - 12)
        img[m, :3] = img[m, :3] * 1.25 + np.array((6, 10, 4))
        rs = np.random.default_rng(seed)
        m2 = a & (rs.random((H, W)) < 0.04) & (yy < base_y - 12)
        img[m2, :3] = (150, 100, 40)                       # dry needles / cones
    else:
        birch = kind == 'birch'
        # trunk + branches
        tw = 2.5 if birch else 3.5
        trunk_top = base_y - (70 if birch else 58)
        for y in range(int(trunk_top), int(base_y) + 1):
            w_ = tw + (base_y - y) * (0.02 if birch else 0.04)
            sway = math.sin((base_y - y) * 0.05 + seed) * (2 if birch else 1)
            for x in range(int(base_x + sway - w_), int(base_x + sway + w_) + 1):
                if 0 <= x < W:
                    t_ = (x - (base_x + sway - w_)) / (2 * w_ + 1e-3)
                    if birch:
                        c = np.array((214, 208, 196.0)) * (1.1 - 0.5 * t_)
                        if rng.random() < 0.10:
                            c = np.array((40, 36, 32.0))
                    else:
                        c = np.array((84, 60, 42.0)) * (1.15 - 0.5 * t_)
                    img[y, x, :3] = c; img[y, x, 3] = 255
        d = Image.fromarray(clamp8(img), 'RGBA')
        dr = ImageDraw.Draw(d)
        for _ in range(9 if birch else 7):
            y0 = rng.uniform(trunk_top + 6, base_y - 26)
            ang = rng.choice([-1, 1]) * rng.uniform(0.5, 1.1)
            L = rng.uniform(14, 26)
            dr.line([(base_x, y0), (base_x + math.sin(ang) * L, y0 - math.cos(ang) * L)],
                    fill=((196, 190, 180, 255) if birch else (70, 50, 36, 255)), width=1)
        img = np.array(d).astype(float)
        # crown: union of blobs
        blobs = []
        cy0 = trunk_top + (10 if birch else 16)
        for _ in range(16 if birch else 20):
            bx = base_x + rng.gauss(0, 13 if birch else 15)
            by = cy0 + rng.gauss(0, 13 if birch else 12)
            br = rng.uniform(7, 11) if birch else rng.uniform(9, 14)
            blobs.append((bx, by, br))
        pal_birch = [(94, 70, 22), (180, 138, 40), (214, 176, 60), (236, 206, 96)]
        pal_maple = [(84, 36, 20), (156, 70, 28), (200, 110, 36), (226, 156, 60)]
        pal = pal_birch if birch else pal_maple
        leafn = value_noise(W, H, 2, seed + 3)
        clump = fbm(W, H, 6, seed + 4, 2)
        for (bx, by, br) in sorted(blobs, key=lambda b: b[1]):
            dx, dy = (xx - bx) / br, (yy - by) / br
            inside = dx * dx + dy * dy <= 1.0
            inside &= (clump > (0.46 if birch else 0.38)) | (dx * dx + dy * dy < 0.45)
            light = np.clip(0.5 - 0.55 * dx * 0.7 - 0.6 * dy * 0.7 + (leafn - 0.5) * 0.6, 0, 1)
            idx = np.clip((light * 3.99).astype(int), 0, 3)
            col = np.array(pal, float)[idx]
            m = inside
            img[m, :3] = col[m]; img[m, 3] = 255
        # remnant green + a few falling leaves
        a = img[..., 3] > 200
        g = a & (fbm(W, H, 10, seed + 6, 2) > 0.68) & (yy < base_y - 20)
        img[g, :3] = img[g, :3] * 0.5 + np.array((74, 90, 40)) * 0.5
        for _ in range(14):
            x, y = int(rng.uniform(10, W - 10)), int(rng.uniform(cy0 + 20, base_y))
            if img[y, x, 3] < 10:
                img[y, x] = (*rng.choice(pal[1:]), 255)
    out = Image.fromarray(clamp8(img), 'RGBA')
    return outline_img(out, (20, 16, 12), alpha_cut=200)


# ================================================================== CARS ==
def car(kind, seed):
    """96x56 sprite; car-local ground origin at canvas (53,37); faces +x.
    Ground footprint projects to ~66x28 (the collision rect)."""
    s = Scene(96, 56, (53, 37))
    Yd = 13.5 / 0.55
    if kind == 'lada':
        body = (164, 152, 116); L, c0, c1, zb, zc, inset = 31, -13, 11, 8, 15, (5, 7)
    elif kind == 'niva':
        body = (88, 108, 72); L, c0, c1, zb, zc, inset = 26, -18, 9, 9, 17, (2, 5)
    else:
        body = (132, 60, 50); L, c0, c1, zb, zc, inset = 30, -19, 10, 8, 15, (2, 7)
    glass = (46, 58, 68)
    dark = tuple(int(c * 0.55) for c in body)
    # tyres
    for x in (-L * 0.64, L * 0.64):
        s.box(V(x, Yd - 2.5, 2.6), (3.6, 1.6, 2.6), (28, 28, 28), bias=-0.3)
        s.box(V(x, -Yd + 2.5, 2.6), (3.6, 1.6, 2.6), (28, 28, 28), bias=-0.3)
    # lower body with a slightly lower hood/trunk line
    s.box(V(0, 0, zb / 2 + 1), (L, Yd - 1, zb / 2), body)
    # cabin: trapezoid prism with raked glass
    yb, yt = Yd - 2.5, Yd - 4.5
    zb1 = zb + 1
    cs = []
    for i in range(8):
        top = i & 1
        x = (c1 - inset[1] if top else c1) if i & 4 else (c0 + inset[0] if top else c0)
        y = (yt if top else yb) * (1 if i & 2 else -1)
        cs.append(V(x, y, zc + 1 if top else zb1))
    s.hexa(cs, body, face_cols={0: glass, 1: glass, 3: glass, 2: glass, 5: tuple(int(c * 1.05) for c in body)})
    # pillars / roof edge on the near side
    for (xb, xt) in [(c0, c0 + inset[0]), ((c0 + c1) / 2 - 1, (c0 + c1) / 2 - 1), (c1, c1 - inset[1])]:
        s.line([V(xb, yb + 0.1, zb1), V(xt, yt + 0.1, zc + 1)], dark, 1, bias=3)
    # bumpers, lights, grille
    s.box(V(L + 0.6, 0, 3.5), (0.8, Yd - 2, 1.2), (60, 60, 58))
    s.box(V(-L - 0.6, 0, 3.5), (0.8, Yd - 2, 1.2), (60, 60, 58))
    for y in (-Yd + 5, Yd - 5):
        s.box(V(L + 0.2, y, 6.2), (0.5, 2.6, 1.1), (224, 216, 170), edge=False, bias=1)
        s.box(V(-L - 0.2, y, 6.2), (0.5, 2.4, 1.0), (160, 40, 30), edge=False, bias=1)
    # hood seam + door lines on top/near side
    s.line([V(c1 + 1, -Yd + 3, zb + 1.1), V(c1 + 1, Yd - 3, zb + 1.1)], dark, 1, bias=2)
    s.line([V((c0 + c1) / 2, Yd - 0.9, 2), V((c0 + c1) / 2, Yd - 0.9, zb)], dark, 1, bias=2)
    s.px(V((c0 + c1) / 2 - 3, Yd - 0.9, zb - 1.5), (30, 30, 30), bias=2.5)
    if kind == 'niva':
        for x in range(int(c0 + 3), int(c1 - 5), 3):
            s.line([V(x, -yt + 1, zc + 2.2), V(x, yt - 1, zc + 2.2)], (60, 60, 58), 1, bias=2)
        s.box(V(-L - 1.4, 0, 8), (1.2, 4.5, 4), (36, 36, 36))
    if kind == 'moskvich':
        s.box(V(-4, 0, zc + 2.4), (6, 5, 0.8), (70, 60, 50), bias=2)          # tied luggage
    img = s.render()
    return grunge(img, seed, 0.14, rust=0.16, dirt_bottom=0.3, leaves=0.005)


# ================================================================== FENCE ==
def fence(seed=5):
    t = Tex(64, 64, (0, 0, 0), alpha=0, seed=seed)
    yy, xx = np.mgrid[0:64, 0:64]
    top, bot = 16, 55
    # chain-link mesh between x=11..53
    mesh = (xx >= 12) & (xx < 53) & (yy >= top + 2) & (yy <= bot - 1)
    lattice = mesh & ((((xx + yy) % 5) == 0) | (((xx - yy) % 5) == 0))
    rust = fbm(64, 64, 8, seed, 2)
    col = np.where((rust > 0.68)[..., None], np.array((120, 70, 40.0)), np.array((126, 128, 124.0)))
    t.rgb[lattice] = col[lattice]; t.a[lattice] = 235
    # sag: tear
    # top + bottom rails
    for y in (top, top + 1):
        m = (xx >= 11) & (xx < 53) & (yy == y)
        t.fill(m, (104, 106, 104) if y == top else (70, 72, 70))
    # concrete post
    post = (xx >= 9) & (xx < 14) & (yy >= top - 4) & (yy <= bot + 2)
    t.fill(post, (140, 136, 126))
    t.mul(post & (xx == 13), 0.66); t.mul(post & (xx == 9), 1.12)
    t.speckle(post, 0.15, [(110, 106, 98), (160, 156, 146)], seed=2)
    t.fill(post & (yy == top - 4), (170, 166, 156))
    # barbed wire above
    for x in range(10, 54):
        y = top - 4 + int(1.5 * math.sin(x * 0.5))
        t.px(x, y, (90, 90, 88), 255)
        if x % 5 == 0:
            t.px(x, y - 1, (110, 110, 108), 255); t.px(x, y + 1, (60, 60, 58), 255)
    # weeds + leaves at the base
    base = (yy >= bot - 4) & (yy <= bot + 2) & (xx >= 8) & (xx < 54)
    rs = np.random.default_rng(seed)
    wm = base & (rs.random((64, 64)) < 0.35)
    t.rgb[wm] = np.array(MOSS)[rs.integers(0, 3, wm.sum())]; t.a[wm] = 255
    lm = base & (rs.random((64, 64)) < 0.08)
    t.rgb[lm] = np.array(LEAF_ORANGE)[rs.integers(0, 5, lm.sum())]; t.a[lm] = 255
    # ground shadow
    shm = (yy >= bot + 3) & (yy <= bot + 5) & (xx >= 10) & (xx < 54) & (t.a == 0)
    t.rgb[shm] = (10, 10, 10); t.a[shm] = 80
    img = t.image()
    return outline_img(img, (24, 24, 22), alpha_cut=250)


# ================================================================== DECALS ==
def street_details():
    out = Image.new('RGBA', (384, 48))
    # 0 manhole cover
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=1)
    rim = t.mask_ellipse(32, 24, 12, 11); lid = t.mask_ellipse(32, 24, 10.5, 9.5)
    t.fill(rim, (36, 36, 36)); t.fill(lid, (82, 78, 70))
    yy, xx = np.mgrid[0:48, 0:64]
    t.fill(lid & (((xx + yy) % 4) == 0), (62, 58, 52))
    t.fill(lid & ~t.mask_ellipse(32, 24, 9, 8), (64, 60, 54))
    t.speckle(lid, 0.15, [(120, 72, 40), (96, 60, 36)], seed=2)
    t.mul(lid & (yy < 20), 1.1)
    out.alpha_composite(t.image(), (0, 0))
    # 1 pothole with water
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=3)
    hole = t.mask_poly([(14, 22), (22, 12), (40, 10), (52, 20), (48, 34), (30, 38), (16, 32)])
    rim = t.mask_poly([(11, 22), (21, 9), (41, 7), (55, 20), (50, 37), (30, 41), (13, 34)])
    t.fill(rim, (70, 70, 68)); t.a[rim] = 200
    t.speckle(rim, 0.3, [(90, 88, 84), (50, 50, 50)], seed=4)
    t.fill(hole, (30, 30, 30)); t.a[hole] = 255
    w = t.mask_ellipse(33, 25, 14, 8)
    t.fill(w & hole, (46, 56, 66))
    t.fill(t.mask_rect(24, 22, 34, 23) & hole, (130, 146, 160))
    t.leaves(hole, 0.05, seed=5)
    out.alpha_composite(t.image(), (64, 0))
    # 2 faded road paint remnants
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=6)
    wear = fbm(64, 48, 5, 7, 2)
    for x0 in range(8, 56, 10):
        m = t.mask_rect(x0, 8, x0 + 6, 40) & (wear < 0.6)
        t.fill(m, (176, 172, 156)); t.a[m] = 170
    out.alpha_composite(t.image(), (128, 0))
    # 3 storm drain grate
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=8)
    fr = t.mask_rect(16, 16, 48, 32); t.fill(fr, (70, 68, 64))
    t.fill(t.mask_rect(18, 18, 46, 30), (20, 20, 22))
    for x in range(19, 46, 3):
        t.fill(t.mask_rect(x, 18, x + 1, 30), (84, 80, 74))
    t.leaves(t.mask_rect(16, 16, 48, 32), 0.12, seed=9)
    out.alpha_composite(t.image(), (192, 0))
    # 4 alligator-cracked patch
    t = Tex(64, 48, (0, 0, 0), alpha=0, seed=10)
    m = t.mask_poly([(6, 20), (18, 8), (46, 6), (60, 22), (52, 40), (20, 42)])
    t.fill(m, (44, 44, 46)); t.a[m] = 150
    for _ in range(22):
        t.crack(t.rng.uniform(12, 52), t.rng.uniform(10, 38), 7, (22, 22, 24), None, 0.3, wrap=False)
    t.a[(t.a > 0) | (t.rgb.sum(-1) < 90)] = np.maximum(t.a[(t.a > 0) | (t.rgb.sum(-1) < 90)], 150)
    t.a[~m] = 0
    out.alpha_composite(t.image(), (256, 0))
    # 5 debris: brick bits, paper, bottle, leaves
    s = Scene(64, 48, (32, 30))
    rng = random.Random(11)
    for _ in range(5):
        s.box(V(rng.uniform(-18, 18), rng.uniform(-10, 10), 1.2), (2.2, 1.2, 1.2), (130, 62, 44))
    s.poly([V(-6, -4, 0.2), V(4, -6, 0.2), V(6, 2, 0.2), V(-4, 4, 0.2)], (196, 190, 170))
    s.cyl(V(10, 6, 0), 1.2, 1.4, (60, 110, 60))
    img = grunge(s.render(), 11, 0.1, leaves=0.05)
    out.alpha_composite(img, (320, 0))
    return out


def puddles():
    out = Image.new('RGBA', (256, 48))
    for i in range(4):
        rng = random.Random(40 + i)
        t = Tex(64, 48, (0, 0, 0), alpha=0, seed=40 + i)
        n = fbm(64, 48, 10, 41 + i, 3)
        yy, xx = np.mgrid[0:48, 0:64]
        d = ((xx - 32) / rng.uniform(22, 28)) ** 2 + ((yy - 24) / rng.uniform(12, 16)) ** 2
        m = d + (n - 0.5) * 0.9 < 1.0
        rim = (d + (n - 0.5) * 0.9 < 1.25) & ~m
        t.fill(rim, (30, 34, 38)); t.a[rim] = 120
        t.rgb[m] = np.array((40, 50, 62.0)) * (0.9 + 0.3 * (1 - yy[m][:, None] / 48.0))
        t.a[m] = 230
        # sky / lamp reflections
        refl = m & (np.abs((xx - 26) * 0.6 + (yy - 20)) < 2) & (n > 0.45)
        t.blend(refl, (150, 164, 176), 0.6)
        glint = m & (np.abs(xx - 38) < 3) & (np.abs(yy - 26) < 1)
        t.blend(glint, (220, 190, 120), 0.55)
        t.leaves(m, 0.02, seed=i)
        out.alpha_composite(t.image(), (i * 64, 0))
    return out


# ================================================================== PROPS ==
def p_barrel(seed=1, col=(60, 84, 110)):
    s = Scene(32, 40, (16, 36))
    s.cyl(V(0, 0, 0), 9, 26, col, bands=((5, (40, 40, 40)), (13, (40, 40, 40)), (21, (40, 40, 40))))
    s.ball(V(-3, -2, 26.5), 1.2, (50, 50, 50))
    return grunge(s.render(), seed, 0.12, rust=0.35, dirt_bottom=0.3)


def p_lamp():
    s = Scene(32, 64, (16, 60))
    s.box(V(0, 0, 1.5), (3, 3, 1.5), (100, 100, 96))
    s.cyl(V(0, 0, 2), 1.6, 44, (96, 100, 98))
    s.box(V(0, 0, 48), (6.5, 3.0, 1.6), (70, 72, 70))
    s.box(V(0, 0, 46.2), (4.5, 2.2, 0.4), (255, 214, 140), edge=False, bias=2)
    s.box(V(-2, 3.2, 20), (1.8, 0.8, 2.6), (60, 64, 60), edge=False, bias=1)       # junction box
    return grunge(s.render(), 2, 0.1, rust=0.18)


def p_crate():
    s = Scene(40, 36, (20, 32))
    s.box(V(0, 0, 7.5), (11, 9, 7.5), (140, 104, 64))
    for z in (4, 9, 13.5):
        s.line([V(-11, 9.1, z), V(11, 9.1, z)], (100, 72, 44), 1, bias=2)
    s.line([V(-11, 9.1, 1), V(11, 9.1, 14.5)], (110, 80, 50), 1, bias=2)
    return grunge(s.render(), 3, 0.18, dirt_bottom=0.25)


def p_trash_bin():
    s = Scene(40, 48, (20, 44))
    s.cyl(V(0, 0, 0), 9, 24, (64, 92, 70), bands=((4, (44, 60, 48)), (20, (44, 60, 48))))
    s.cyl(V(0, 0, 24), 10, 2, (54, 76, 60))
    s.ball(V(3, -3, 27), 2.4, (196, 190, 170))          # paper sticking out
    s.ball(V(-4, 0, 27), 1.8, (80, 110, 70))
    return grunge(s.render(), 4, 0.14, rust=0.2, leaves=0.02)


def p_road_sign():
    s = Scene(32, 64, (16, 60))
    s.cyl(V(0, 0, 0), 1.2, 44, (130, 132, 130))
    img = s.render()
    d = ImageDraw.Draw(img)
    # warning triangle, faded + rusty
    d.polygon([(16, 2), (29, 24), (3, 24)], fill=(150, 40, 34, 255), outline=(30, 20, 18, 255))
    d.polygon([(16, 8), (24, 21), (8, 21)], fill=(212, 204, 186, 255))
    d.line([(16, 12), (16, 17)], fill=(30, 30, 30, 255)); d.point((16, 19), fill=(30, 30, 30, 255))
    return grunge(img, 5, 0.12, rust=0.12)


def p_sandbags():
    s = Scene(56, 32, (28, 26))
    for row, z in enumerate((2.5, 6.5, 10.5)):
        n = 4 - row
        for i in range(n):
            x = (i - (n - 1) / 2) * 11
            s.box(V(x, 0, z), (5.2, 5, 2.2), (134, 122, 88))
    return grunge(s.render(), 6, 0.18, dirt_bottom=0.2)


def p_cone():
    s = Scene(24, 40, (12, 36))
    s.box(V(0, 0, 0.6), (7, 7, 0.6), (40, 40, 40))
    for i in range(10):
        z = 1 + i * 2.2
        r = 6 - i * 0.55
        col = (200, 196, 186) if i in (4, 5) else (214, 96, 34)
        s.cyl(V(0, 0, z), r, 2.2, col, edge=False)
    return grunge(s.render(), 7, 0.1, dirt_bottom=0.3)


def p_barrier():
    s = Scene(32, 48, (16, 44))
    for x in (-10, 10):
        s.box(V(x, 0, 12), (1.2, 1.2, 12), (70, 72, 70))
    for i in range(6):
        col = (190, 40, 34) if i % 2 == 0 else (220, 214, 200)
        s.box(V(-12 + i * 4 + 2, 1.5, 20), (2, 0.8, 3), col, edge=False)
    s.box(V(0, 0, 20), (13, 0.6, 3.2), (60, 60, 60), bias=-0.5)
    return grunge(s.render(), 8, 0.12, rust=0.15)


def p_cardboard():
    s = Scene(56, 48, (28, 42))
    rng = random.Random(9)
    for (x, y, z, w, d, h) in [(-10, 0, 0, 9, 8, 7), (8, 2, 0, 10, 8, 8), (-2, -2, 14, 8, 7, 6), (14, 8, 0, 6, 5, 4)]:
        s.box(V(x, y, z + h), (w, d, h), (156, 120, 80))
        s.line([V(x - w, y + d + 0.1, z + h * 2 - 1), V(x + w, y + d + 0.1, z + h * 2 - 1)], (200, 190, 160), 1, bias=1)
    return grunge(s.render(), 9, 0.16, dirt_bottom=0.2)


def p_trash_bag():
    s = Scene(48, 40, (24, 34))
    for (x, y, r) in [(-7, 0, 8), (6, 2, 9), (0, -5, 7)]:
        s.ball(V(x, y, r * 0.8), r, (36, 38, 40))
    s.ball(V(8, 0, 16), 2, (60, 62, 64))
    return grunge(s.render(), 10, 0.1)


def p_electrical_box():
    s = Scene(48, 48, (24, 44))
    s.box(V(0, 0, 13), (11, 6, 13), (104, 116, 100))
    s.box(V(0, 0, 26.6), (12, 7, 0.8), (84, 94, 80))
    s.line([V(0, 6.1, 2), V(0, 6.1, 25)], (70, 80, 66), 1, bias=1)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.polygon([(28, 22), (31, 27), (25, 27)], fill=(210, 180, 40, 255))
    return grunge(img, 11, 0.14, rust=0.2)


def p_generator():
    s = Scene(64, 48, (32, 42))
    s.box(V(0, 0, 8), (20, 9, 8), (170, 130, 40))
    s.box(V(-8, 0, 17), (8, 7, 1), (70, 70, 66))
    s.box(V(12, 9.2, 8), (5, 0.4, 4), (50, 50, 50), edge=False, bias=1)
    for x in (-18, 18):
        s.box(V(x, 0, 2), (2, 10, 2), (40, 40, 40))
    return grunge(s.render(), 12, 0.14, rust=0.2)


def p_gas_can():
    s = Scene(48, 56, (24, 50))
    s.box(V(0, 0, 11), (9, 4.5, 11), (170, 44, 34))
    s.box(V(4, 0, 23.5), (3.5, 1.2, 1.5), (60, 60, 60))
    s.box(V(-4, 0, 24), (1.2, 1.2, 2.2), (120, 120, 116))
    return grunge(s.render(), 13, 0.14, rust=0.25)


def p_shopping_cart():
    s = Scene(48, 40, (24, 36))
    for y in (-7, 7):
        s.line([V(-14, y, 4), V(12, y, 4), V(14, y, 16), V(-16, y, 16), V(-14, y, 4)], (150, 154, 152), 1)
    for x in range(-14, 14, 3):
        s.line([V(x, -7, 16), V(x, 7, 16)], (130, 134, 132), 1)
    for (x, y) in [(-12, -7), (-12, 7), (10, -7), (10, 7)]:
        s.ball(V(x, y, 1.5), 1.5, (40, 40, 40))
    s.line([V(-16, -7, 18), V(-16, 7, 18)], (60, 90, 150), 2)
    return grunge(s.render(), 14, 0.1, rust=0.15)


def p_rubble():
    s = Scene(64, 32, (32, 26))
    rng = random.Random(15)
    for _ in range(14):
        c = rng.choice([(130, 126, 116), (120, 62, 44), (96, 94, 88)])
        s.box(V(rng.uniform(-22, 22), rng.uniform(-8, 8), rng.uniform(1, 4)),
              (rng.uniform(1.5, 4), rng.uniform(1.5, 3), rng.uniform(1, 2.5)), c)
    s.line([V(-10, 2, 5), V(6, -4, 3)], (100, 70, 50), 1, bias=3)            # rebar
    return grunge(s.render(), 15, 0.12, dirt_bottom=0.15, leaves=0.01)


def p_street_debris():
    s = Scene(72, 40, (36, 30))
    rng = random.Random(16)
    for _ in range(6):
        s.poly([V(rng.uniform(-28, 28) + dx, rng.uniform(-8, 8) + dy, 0.2) for dx, dy in [(-3, -2), (3, -2), (3, 2), (-3, 2)]],
               rng.choice([(190, 186, 170), (160, 150, 120), (120, 110, 90)]))
    s.box(V(-14, 2, 2), (5, 3, 2), (130, 62, 44))
    s.cyl(V(12, -2, 0), 1.3, 1.5, (70, 120, 70))
    s.cyl(V(18, 4, 0), 1.3, 1.5, (120, 80, 40))
    s.box(V(4, 6, 1), (6, 1, 1), (100, 72, 46))
    return grunge(s.render(), 16, 0.1, leaves=0.05)


def p_wall_pipe():
    s = Scene(64, 32, (32, 20))
    s.hcyl(V(-28, 0, 6), V(28, 0, 6), 3, (120, 124, 122))
    for x in (-18, 0, 18):
        s.box(V(x, 0, 6), (1.2, 3.4, 3.4), (80, 82, 82))
    return grunge(s.render(), 17, 0.14, rust=0.3)


def p_campfire():
    s = Scene(64, 56, (32, 46))
    rng = random.Random(18)
    for i in range(9):
        a = i / 9 * math.tau
        s.box(V(math.cos(a) * 10, math.sin(a) * 10, 2), (2.5, 2.5, 2), (110, 108, 102))
    for a in (0.3, 1.4, 2.6):
        s.line([V(math.cos(a) * 8, math.sin(a) * 8, 1), V(-math.cos(a) * 8, -math.sin(a) * 8, 3)], (90, 60, 40), 2)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.polygon([(26, 40), (32, 22), (38, 40)], fill=(230, 120, 30, 255))
    d.polygon([(29, 40), (32, 30), (35, 40)], fill=(255, 220, 110, 255))
    return grunge(img, 18, 0.06)


def p_rain_collector():
    s = Scene(64, 64, (32, 58))
    s.cyl(V(0, 0, 0), 14, 26, (60, 90, 120), bands=((8, (40, 60, 80)), (18, (40, 60, 80))))
    s.poly([V(-16, -10, 32), V(16, -10, 32), V(10, 0, 26), V(-10, 0, 26)], (120, 100, 70))
    s.line([V(-16, -10, 32), V(-16, -10, 0)], (90, 70, 50), 1)
    s.line([V(16, -10, 32), V(16, -10, 0)], (90, 70, 50), 1)
    return grunge(s.render(), 19, 0.12, rust=0.25)


# ------------------------------------------------ new street furniture atlas --
def f_bench():
    s = Scene(64, 48, (32, 40))
    for x in (-18, 18):
        s.box(V(x, 0, 4), (1.5, 5, 4), (60, 62, 60))
    for y in (-3.5, -1, 1.5, 4):
        s.box(V(0, y, 8.6), (24, 1.0, 0.6), (140, 100, 62))
    for z in (12, 15):
        s.box(V(0, -5.5, z), (24, 0.6, 1.1), (130, 92, 56))
    return grunge(s.render(), 31, 0.16, rust=0.1, leaves=0.03)


def f_dumpster():
    s = Scene(64, 48, (32, 42))
    s.box(V(0, 0, 10), (22, 10, 10), (58, 92, 70))
    s.poly([V(-22, -10, 21), V(0, -10, 21), V(0, 10, 20), V(-22, 10, 20)], (48, 76, 58))
    s.box(V(12, 0, 22.5), (8, 9, 2.5), (40, 40, 40))              # overflowing bag
    s.ball(V(8, 3, 23), 4, (36, 38, 40))
    for x in (-18, 18):
        s.ball(V(x, 10, 1.5), 1.6, (30, 30, 30))
    img = s.render()
    return grunge(img, 32, 0.16, rust=0.3, leaves=0.02)


def f_cabinet():
    s = Scene(64, 48, (32, 44))
    for i, (x, col) in enumerate([(-11, (120, 126, 118)), (0, (96, 104, 96)), (11, (130, 132, 124))]):
        s.box(V(x, 0, 12 + (i % 2) * 2), (5, 5, 12 + (i % 2) * 2), col)
        s.line([V(x, 5.1, 3), V(x, 5.1, 20)], tuple(int(c * 0.7) for c in col), 1, bias=1)
    img = s.render()
    d = ImageDraw.Draw(img)
    d.polygon([(30, 20), (33, 25), (27, 25)], fill=(210, 180, 40, 255))
    return grunge(img, 33, 0.16, rust=0.25)


def f_bus_stop_sign():
    s = Scene(64, 48, (32, 46))
    s.cyl(V(0, 0, 0), 1.2, 34, (140, 140, 136))
    img = s.render()
    d = ImageDraw.Draw(img)
    d.rectangle([24, 2, 40, 16], fill=(52, 96, 150, 255), outline=(24, 30, 40, 255))
    d.rectangle([27, 5, 37, 13], fill=(214, 210, 196, 255))
    d.text((28, 3), 'A', fill=(30, 40, 60, 255))
    return grunge(img, 34, 0.1, rust=0.15)


def f_bollards():
    s = Scene(64, 48, (32, 40))
    for x in (-18, -6, 6, 18):
        s.cyl(V(x, 0, 0), 2.2, 10, (130, 128, 120), bands=((7, (160, 40, 34)),))
    return grunge(s.render(), 35, 0.12, rust=0.1)


def f_planter():
    s = Scene(64, 48, (32, 40))
    s.box(V(0, 0, 5), (20, 8, 5), (130, 126, 116))
    s.box(V(0, 0, 10.2), (19, 7, 0.3), (60, 48, 36), edge=False)
    rng = random.Random(36)
    for _ in range(9):
        s.ball(V(rng.uniform(-16, 16), rng.uniform(-5, 5), 12), rng.uniform(2, 3.5),
               rng.choice([(90, 104, 50), (160, 100, 40), (120, 110, 50)]))
    return grunge(s.render(), 36, 0.14, leaves=0.03)


def f_tires():
    s = Scene(64, 48, (32, 40))
    for (x, y, z) in [(-8, 0, 0), (8, 0, 0), (0, 0, 4.5), (0, 8, 0)]:
        s.cyl(V(x, y, z), 7, 4.4, (34, 34, 34), bands=((2.2, (24, 24, 24)),))
        s.ball(V(x, y, z + 4.6), 2.5, (14, 14, 14))
    return grunge(s.render(), 37, 0.1)


def f_notice_board():
    s = Scene(64, 48, (32, 44))
    for x in (-14, 14):
        s.box(V(x, 0, 12), (1, 1, 12), (80, 60, 42))
    s.box(V(0, 0, 18), (16, 1.2, 7), (110, 84, 56))
    img = s.render()
    d = ImageDraw.Draw(img)
    rng = random.Random(38)
    for _ in range(6):
        x, y = rng.randint(19, 42), rng.randint(9, 20)
        d.rectangle([x, y, x + 4, y + 5], fill=rng.choice([(210, 204, 186, 255), (200, 190, 150, 255), (170, 60, 50, 255)]))
    return grunge(img, 38, 0.12, leaves=0.02)


FURNITURE = ['bench', 'dumpster', 'el_cabinets', 'bus_stop', 'bollards', 'planter', 'tires', 'notice_board']


def furniture_atlas():
    out = Image.new('RGBA', (64 * len(FURNITURE), 48))
    fns = [f_bench, f_dumpster, f_cabinet, f_bus_stop_sign, f_bollards, f_planter, f_tires, f_notice_board]
    for i, fn in enumerate(fns):
        out.alpha_composite(fit_canvas(fn(), 64, 48), (i * 64, 0))
    return out


def patch_world_props(src_path, dst_path, trees, cars):
    atlas = Image.open(src_path).convert('RGBA')
    regions = {
        'car': (0, 0, 96, 56), 'tree': (96, 0, 64, 72), 'barrel': (160, 0, 32, 40), 'lamp': (192, 0, 32, 64),
        'crate': (224, 0, 40, 36), 'trash_bin': (512, 0, 40, 48), 'road_sign': (552, 0, 32, 64),
        'sandbags': (584, 0, 56, 32), 'traffic_cone': (640, 0, 24, 40), 'shopping_cart': (664, 0, 48, 40),
        'road_barrier': (736, 0, 32, 48), 'wall_pipe': (640, 80, 64, 32), 'rubble': (640, 152, 64, 32),
        'generator_prop': (704, 152, 64, 48), 'street_debris': (896, 160, 72, 40),
        'electrical_box': (1064, 80, 48, 48), 'cardboard_boxes': (1352, 0, 56, 48),
        'gas_can': (1824, 80, 48, 56), 'trash_bag': (2368, 80, 48, 40),
        'campfire': (1920, 0, 64, 56), 'rain_collector': (1984, 0, 64, 64),
    }
    art = {
        'car': cars[0], 'tree': trees[1].resize((44, 68), Image.NEAREST), 'barrel': p_barrel(), 'lamp': p_lamp(),
        'crate': p_crate(), 'trash_bin': p_trash_bin(), 'road_sign': p_road_sign(), 'sandbags': p_sandbags(),
        'traffic_cone': p_cone(), 'shopping_cart': p_shopping_cart(), 'road_barrier': p_barrier(),
        'wall_pipe': p_wall_pipe(), 'rubble': p_rubble(), 'generator_prop': p_generator(),
        'street_debris': p_street_debris(), 'electrical_box': p_electrical_box(), 'cardboard_boxes': p_cardboard(),
        'gas_can': p_gas_can(), 'trash_bag': p_trash_bag(), 'campfire': p_campfire(), 'rain_collector': p_rain_collector(),
    }
    for k, (x, y, w, h) in regions.items():
        atlas.paste((0, 0, 0, 0), (x, y, x + w, y + h))
        anchor = 'center' if k in ('car', 'street_debris', 'rubble', 'wall_pipe') else 'bottom'
        atlas.alpha_composite(fit_canvas(art[k], w, h, anchor), (x, y))
    atlas.save(dst_path)


def build_all(P):
    trees = [tree('birch', 101), tree('maple', 202), tree('spruce', 303)]
    ta = Image.new('RGBA', (88 * 3, 136))
    for i, t in enumerate(trees):
        ta.alpha_composite(t, (i * 88, 0))
    ta.save(os.path.join(P, 'tree_v3.png'))
    cars = [car('lada', 501), car('niva', 502), car('moskvich', 503)]
    ca = Image.new('RGBA', (96 * 3, 56))
    for i, c in enumerate(cars):
        ca.alpha_composite(c, (i * 96, 0))
    ca.save(os.path.join(P, 'car_v4.png'))
    fence().save(os.path.join(P, 'fence_segment_v3.png'))
    street_details().save(os.path.join(P, 'street_detail_v2.png'))
    puddles().save(os.path.join(P, 'wet_surface_v2.png'))
    furniture_atlas().save(os.path.join(P, 'street_furniture_v1.png'))
    patch_world_props(os.path.join(P, 'world_props_v17.png'), os.path.join(P, 'world_props_v18.png'), trees, cars)
