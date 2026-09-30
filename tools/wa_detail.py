"""OSTATOK 0.89 detail pass: vegetation, rooftop clutter, facade attachments.

vegetation_v1.png      8 x 64x64: bush_orange, bush_yellow, bush_olive, weeds, tall_grass,
                       leaf_pile, fallen_branch, bush_bare
roof_details_v1.png    8 x 64x64: water_tank, sat_dish, stair_housing, pipe_run, roof_puddle,
                       roof_debris, vent_small, skylight_row
facade_details_v1.png  8 x 48x80: drainpipe, ivy, grime_streaks, ac_unit, wires, graffiti_a,
                       graffiti_b, wall_lamp
"""
import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw
from wa_core import Tex, fbm, value_noise, Scene, V, grunge, outline_img, fit_canvas, LEAF_ORANGE, MOSS, clamp8


# ================================================================ VEGETATION ==
def bush(pal, seed, W=64, H=64, blobs=9, spread=13, bare=False):
    rng = random.Random(seed)
    img = np.zeros((H, W, 4), float)
    yy, xx = np.mgrid[0:H, 0:W]
    bx0, by0 = W / 2, H - 20
    sh = ((xx - bx0 - 4) / 22.0) ** 2 + ((yy - (H - 10)) / 5.0) ** 2 <= 1
    img[sh] = (8, 10, 8, 80)
    d = Image.fromarray(clamp8(img), 'RGBA')
    dr = ImageDraw.Draw(d)
    for _ in range(7 if bare else 4):                         # twigs
        a = rng.uniform(-1.3, 1.3)
        L = rng.uniform(10, 20)
        dr.line([(bx0, H - 10), (bx0 + math.sin(a) * L, H - 10 - math.cos(a) * L)], fill=(70, 52, 38, 255), width=1)
    img = np.array(d).astype(float)
    if not bare:
        clump = fbm(W, H, 5, seed + 1, 2)
        leafn = value_noise(W, H, 2, seed + 2)
        for _ in range(blobs):
            cx = bx0 + rng.gauss(0, spread)
            cy = by0 + rng.gauss(0, spread * 0.55)
            r = rng.uniform(6, 10)
            dx, dy = (xx - cx) / r, (yy - cy) / r
            m = (dx * dx + dy * dy <= 1.0) & ((clump > 0.4) | (dx * dx + dy * dy < 0.5))
            light = np.clip(0.55 - 0.45 * dx - 0.5 * dy + (leafn - 0.5) * 0.7, 0, 1)
            idx = np.clip((light * 3.99).astype(int), 0, 3)
            col = np.array(pal, float)[idx]
            img[m, :3] = col[m]; img[m, 3] = 255
    else:
        for _ in range(40):                                   # sparse remaining leaves
            x, y = int(bx0 + rng.gauss(0, 12)), int(by0 + rng.gauss(0, 7))
            if 0 <= x < W and 0 <= y < H:
                img[y, x] = (*rng.choice(LEAF_ORANGE), 255)
    out = Image.fromarray(clamp8(img), 'RGBA')
    return outline_img(out, (20, 16, 12), alpha_cut=200)


def weeds(seed, tall=False):
    rng = random.Random(seed)
    im = Image.new('RGBA', (64, 64))
    d = ImageDraw.Draw(im)
    d.ellipse([14, 52, 50, 60], fill=(8, 10, 8, 70))
    for _ in range(46 if tall else 30):
        x = 32 + rng.gauss(0, 8)
        h = rng.uniform(10, 26 if tall else 14)
        lean = rng.uniform(-5, 5)
        col = rng.choice([(118, 110, 60), (140, 128, 70), (96, 104, 52), (160, 140, 80)] if tall else
                         [(76, 96, 44), (92, 110, 50), (110, 100, 50), (64, 80, 38)])
        d.line([(x, 56), (x + lean, 56 - h)], fill=col + (255,), width=1)
        if tall and rng.random() < 0.3:
            d.point((x + lean, 56 - h - 1), fill=(180, 160, 110, 255))
    return outline_img(im, (26, 24, 16), alpha_cut=200)


def leaf_pile(seed):
    t = Tex(64, 64, (0, 0, 0), alpha=0, seed=seed)
    yy, xx = np.mgrid[0:64, 0:64]
    n = fbm(64, 64, 6, seed, 2)
    m = (((xx - 32) / 22.0) ** 2 + ((yy - 44) / 9.0) ** 2 + (n - 0.5) * 0.8) < 1
    rng = np.random.default_rng(seed)
    cols = np.array(LEAF_ORANGE + [(120, 70, 30), (90, 60, 30)], float)
    idx = rng.integers(0, len(cols), (64, 64))
    shade = np.clip(1.15 - (yy - 36) / 20.0 * 0.4, 0.6, 1.2)
    t.rgb[m] = (cols[idx] * shade[..., None])[m]
    t.a[m] = 255
    return outline_img(t.image(), (30, 20, 12), alpha_cut=250)


def fallen_branch(seed):
    s = Scene(64, 64, (32, 48))
    s.hcyl(V(-22, 2, 1.5), V(20, -3, 2.5), 2, (96, 70, 48))
    s.hcyl(V(0, 0, 2), V(10, 8, 1.5), 1, (90, 66, 44))
    s.hcyl(V(-8, 1, 2), V(-14, -8, 1.5), 1, (90, 66, 44))
    img = s.render()
    d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    for _ in range(18):
        x, y = rng.randint(10, 54), rng.randint(38, 52)
        d.point((x, y), fill=rng.choice(LEAF_ORANGE) + (255,))
    return img


def vegetation():
    out = Image.new('RGBA', (512, 64))
    items = [
        bush([(96, 40, 20), (160, 72, 28), (206, 118, 40), (230, 168, 70)], 11),
        bush([(110, 84, 26), (178, 138, 42), (214, 178, 64), (238, 210, 104)], 12),
        bush([(44, 54, 28), (72, 86, 40), (104, 112, 52), (140, 132, 64)], 13),
        weeds(14), weeds(15, tall=True), leaf_pile(16), fallen_branch(17),
        bush(None, 18, bare=True),
    ]
    for i, im in enumerate(items):
        out.alpha_composite(fit_canvas(im, 64, 64), (i * 64, 0))
    return out


VEG_KINDS = ['bush_orange', 'bush_yellow', 'bush_olive', 'weeds', 'tall_grass', 'leaf_pile', 'fallen_branch', 'bush_bare']


# ================================================================ ROOF DETAILS ==
def roof_details():
    out = Image.new('RGBA', (512, 64))
    cells = []
    # 0 water tank on a steel stand
    s = Scene(64, 64, (32, 58))
    for (x, y) in [(-8, -6), (8, -6), (-8, 6), (8, 6)]:
        s.box(V(x, y, 7), (0.9, 0.9, 7), (70, 70, 68))
    s.box(V(0, 0, 14.6), (10, 8, 0.6), (80, 80, 76))
    s.cyl(V(0, 0, 15), 10, 18, (70, 104, 132), bands=((5, (50, 76, 98)), (12, (50, 76, 98))))
    s.cyl(V(0, 0, 33), 7, 2, (60, 90, 114))
    cells.append(grunge(s.render(), 21, 0.14, rust=0.3))
    # 1 satellite dish on bracket
    s = Scene(64, 64, (30, 54))
    s.box(V(0, 0, 1), (5, 4, 1), (90, 90, 86))
    s.box(V(0, 0, 8), (0.8, 0.8, 7), (80, 80, 80))
    img = s.render()
    d = ImageDraw.Draw(img)
    d.ellipse([28, 20, 50, 42], fill=(186, 186, 180, 255), outline=(40, 40, 40, 255))
    d.ellipse([33, 25, 47, 37], fill=(160, 160, 154, 255))
    d.line([(39, 31), (46, 22)], fill=(60, 60, 60, 255)); d.point((46, 22), fill=(30, 30, 30, 255))
    cells.append(grunge(img, 22, 0.1, rust=0.1))
    # 2 stair housing / exit kiosk with door
    s = Scene(64, 64, (32, 58))
    s.box(V(0, 0, 10), (14, 10, 10), (128, 124, 114))
    s.box(V(0, 0, 20.6), (15, 11, 0.8), (84, 84, 80))
    s.box(V(4, 10.1, 7), (4, 0.2, 7), (70, 80, 84), edge=False, bias=1)
    s.box(V(-8, 10.1, 13), (2.5, 0.2, 2), (40, 48, 54), edge=False, bias=1)
    cells.append(grunge(s.render(), 23, 0.14, rust=0.08, leaves=0.02))
    # 3 pipe run with supports + elbow
    s = Scene(64, 64, (32, 40))
    s.hcyl(V(-28, 0, 4), V(16, 0, 4), 2.5, (130, 132, 128))
    s.hcyl(V(16, 0, 4), V(16, -14, 4), 2.5, (130, 132, 128))
    for x in (-20, -6, 8):
        s.box(V(x, 0, 1.2), (1.2, 3, 1.2), (70, 70, 68))
    cells.append(grunge(s.render(), 24, 0.12, rust=0.35))
    # 4 roof puddle (flat, reflective)
    t = Tex(64, 64, (0, 0, 0), alpha=0, seed=25)
    yy, xx = np.mgrid[0:64, 0:64]
    n = fbm(64, 64, 8, 25, 3)
    m = (((xx - 32) / 24.0) ** 2 + ((yy - 34) / 14.0) ** 2 + (n - 0.5)) < 1
    t.rgb[m] = (44, 54, 64); t.a[m] = 200
    t.blend(m & (np.abs((xx - 24) * 0.6 + (yy - 30)) < 1.5), (150, 164, 176), 0.6)
    t.leaves(m, 0.03, seed=2)
    cells.append(t.image())
    # 5 debris: bricks, plank, bottles, leaves
    s = Scene(64, 64, (32, 44))
    rng = random.Random(26)
    for _ in range(6):
        s.box(V(rng.uniform(-14, 14), rng.uniform(-6, 6), 1.2), (2.4, 1.2, 1.2), (130, 62, 44))
    s.box(V(0, 4, 0.6), (14, 1.6, 0.6), (120, 90, 58))
    s.cyl(V(10, -4, 0), 1.2, 3, (60, 110, 70))
    cells.append(grunge(s.render(), 26, 0.12, leaves=0.06))
    # 6 small vent mushroom cluster
    s = Scene(64, 64, (32, 48))
    for (x, y) in [(-10, 0), (8, -4), (2, 8)]:
        s.cyl(V(x, y, 0), 2.6, 7, (150, 150, 146))
        s.cyl(V(x, y, 7), 4.2, 1.6, (120, 120, 116))
    cells.append(grunge(s.render(), 27, 0.1, rust=0.2))
    # 7 skylight row (industrial)
    s = Scene(64, 64, (32, 40))
    for x in (-18, 0, 18):
        s.box(V(x, 0, 2.5), (7, 9, 2.5), (100, 100, 96))
        s.box(V(x, 0, 5.3), (6, 8, 0.4), (70, 92, 106), edge=False)
        s.px(V(x - 3, -4, 5.8), (170, 196, 206))
    cells.append(grunge(s.render(), 28, 0.1, rust=0.1))
    for i, c in enumerate(cells):
        out.alpha_composite(fit_canvas(c, 64, 64, 'center'), (i * 64, 0))
    return out


ROOF_KINDS = ['water_tank', 'sat_dish', 'stair_housing', 'pipe_run', 'roof_puddle', 'roof_debris', 'vent_small', 'skylight_row']


# ================================================================ FACADE DETAILS ==
def facade_details():
    out = Image.new('RGBA', (384, 80))
    # 0 drainpipe full height (8x80) with brackets + rusty funnel
    t = Tex(48, 80, (0, 0, 0), alpha=0, seed=31)
    pm = t.mask_rect(21, 4, 26, 80)
    t.fill(pm, (110, 114, 114)); t.a[pm] = 255
    t.mul(t.mask_rect(21, 0, 22, 80) & pm, 1.3); t.mul(t.mask_rect(25, 0, 26, 80) & pm, 0.65)
    fm = t.mask_poly([(18, 0), (29, 0), (26, 6), (21, 6)])
    t.fill(fm, (96, 100, 100)); t.a[fm] = 255
    for y in range(12, 80, 18):
        bm = t.mask_rect(19, y, 28, y + 2)
        t.fill(bm, (70, 72, 72)); t.a[bm] = 255
    rn = fbm(48, 80, 6, 31, 2)
    t.blend(pm & (rn > 0.62), (122, 62, 30), 0.7)
    sm = t.mask_rect(26, 4, 28, 80)
    t.rgb[sm] = (10, 10, 10); t.a[sm] = 70
    out.alpha_composite(t.image(), (0, 0))
    # 1 ivy / wild vine climbing (autumn red-green)
    t = Tex(48, 80, (0, 0, 0), alpha=0, seed=32)
    rng = random.Random(32)
    d = Image.new('RGBA', (48, 80)); dr = ImageDraw.Draw(d)
    x = 24.0
    for y in range(79, 6, -1):
        x += rng.uniform(-0.8, 0.8)
        dr.point((x, y), fill=(70, 52, 36, 255))
    t.rgb[:] = 0
    base = np.array(d).astype(float)
    t.rgb = base[..., :3]; t.a = base[..., 3]
    yy, xx = np.mgrid[0:80, 0:48]
    n = fbm(48, 80, 5, 33, 3)
    dens = np.clip((yy - 4) / 76.0, 0, 1)
    m = (n + dens * 0.45 > 0.78) & (np.abs(xx - 24) < 6 + dens * 16)
    pal = np.array([(120, 36, 26), (168, 60, 34), (98, 104, 46), (70, 80, 36), (196, 96, 40)], float)
    idx = np.random.default_rng(34).integers(0, 5, (80, 48))
    t.rgb[m] = pal[idx][m]; t.a[m] = 255
    out.alpha_composite(outline_img(t.image(), (30, 16, 12), alpha_cut=250), (48, 0))
    # 2 grime / rain streaks (semi-transparent)
    t = Tex(48, 80, (20, 18, 14), alpha=0, seed=35)
    n = value_noise(48, 80, 3, 35)
    streak = (n > 0.55)
    fade = np.clip(1 - (yy / 80.0), 0.2, 1)
    t.a[:] = np.where(streak, 70 * fade, 0)
    t.a[70:, :] = np.maximum(t.a[70:, :], 60)
    out.alpha_composite(t.image(), (96, 0))
    # 3 AC unit hanging on brackets with drip stain
    s = Scene(48, 80, (24, 40))
    s.box(V(0, 0, 6), (10, 4, 6), (176, 176, 170))
    s.box(V(-7, 1, 0), (0.7, 3, 0.7), (70, 70, 70))
    s.box(V(7, 1, 0), (0.7, 3, 0.7), (70, 70, 70))
    img = s.render()
    d = ImageDraw.Draw(img)
    d.ellipse([22, 29, 32, 39], fill=(80, 82, 82, 255), outline=(50, 50, 50, 255))
    d.line([(27, 30), (27, 38)], fill=(60, 60, 60, 255)); d.line([(23, 34), (31, 34)], fill=(60, 60, 60, 255))
    d.line([(24, 44), (24, 76)], fill=(40, 34, 28, 90), width=2)
    out.alpha_composite(grunge(img, 36, 0.1, rust=0.1), (144, 0))
    # 4 sagging wires with junction box
    im = Image.new('RGBA', (48, 80)); d = ImageDraw.Draw(im)
    for k, col in enumerate([(30, 30, 30), (40, 36, 30), (28, 30, 34)]):
        pts = [(0, 10 + k * 3 + 6 * math.sin(i / 47 * math.pi)) for i in range(0)]
        pts = [(x, 10 + k * 3 + 8 * math.sin(x / 47 * math.pi)) for x in range(0, 48)]
        d.line(pts, fill=col + (255,))
    d.rectangle([30, 14, 38, 22], fill=(96, 100, 92, 255), outline=(30, 30, 30, 255))
    d.line([(34, 22), (34, 60)], fill=(30, 30, 30, 255))
    out.alpha_composite(im, (192, 0))
    # 5, 6 graffiti tags (low on the wall)
    for i, (col, col2) in enumerate([((170, 60, 50), (230, 220, 200)), ((60, 110, 150), (210, 190, 70))]):
        im = Image.new('RGBA', (48, 80)); d = ImageDraw.Draw(im)
        rng = random.Random(40 + i)
        pts = [(4 + j * 4, 60 + rng.uniform(-6, 6)) for j in range(11)]
        d.line(pts, fill=col + (220,), width=3)
        d.line(pts, fill=col2 + (200,), width=1)
        if i == 1:
            d.ellipse([16, 48, 30, 62], outline=col + (220,), width=2)
        out.alpha_composite(im, (240 + i * 48, 0))
    # 7 wall lamp bracket (caged bulb)
    s = Scene(48, 80, (24, 30))
    s.box(V(0, 0, 4), (1.5, 1.5, 4), (60, 62, 60))
    s.box(V(0, 3, 7), (2.5, 3, 2), (70, 72, 70))
    img = s.render()
    d = ImageDraw.Draw(img)
    d.rectangle([22, 27, 26, 30], fill=(255, 214, 140, 255))
    out.alpha_composite(img, (336, 0))
    return out


FACADE_DETAIL_KINDS = ['drainpipe', 'ivy', 'grime', 'ac_unit', 'wires', 'graffiti_a', 'graffiti_b', 'wall_lamp']


def build_all(P):
    vegetation().save(os.path.join(P, 'vegetation_v1.png'))
    roof_details().save(os.path.join(P, 'roof_details_v1.png'))
    facade_details().save(os.path.join(P, 'facade_details_v1.png'))
