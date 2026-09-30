"""OSTATOK settlement architecture renderer.

Buildings in the game are drawn in a "lifted roof" oblique view: a point (x, y, z)
of the world lands on screen at (x, y - z). The south facade therefore shows at
full height below the roof, and roofs are seen from above. This module renders
whole building models in that projection so they line up exactly with the game's
interior footprint, facade layer and roof layer.

Geometry is built from textured planar faces (walls, roof slopes, parapets,
chimneys ...). Each face has a local (u, v) frame, a material pattern (planks,
logs, brick, plaster, corrugated sheet, slate, roof tiles, standing seam, glass)
and optional openings (windows, doors, gates). Faces are flat-shaded with the
shared OSTATOK light and painted back-to-front.
"""
import math
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from wa_core import fbm, clamp8, outline_img, LEAF_ORANGE, MOSS

DENS = 2                      # art pixels per world pixel
VIEW = np.array([0.0, 1.0, 1.0]) / math.sqrt(2.0)
LIGHT = np.array([-0.42, 0.40, 0.82]); LIGHT /= np.linalg.norm(LIGHT)


def V(*a):
    return np.array(a, float)


def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def shade(col, n, amb=0.60, dif=0.52):
    k = amb + dif * max(0.0, float(np.dot(n, LIGHT)))
    return tuple(int(max(0, min(255, c * k))) for c in col)


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def dark(c, k):
    return tuple(int(v * k) for v in c)


# ------------------------------------------------------------------ materials --
MAT = {
    'plank':      ((124, 94, 64), 'plank_h'),
    'plank_v':    ((118, 90, 60), 'plank_v'),
    'plank_grey': ((112, 106, 96), 'plank_h'),
    'log':        ((120, 88, 58), 'log'),
    'brick':      ((138, 76, 56), 'brick'),
    'brick_dark': ((112, 66, 52), 'brick'),
    'silicate':   ((178, 172, 154), 'brick'),
    'plaster':    ((188, 186, 174), 'plaster'),
    'plaster_y':  ((182, 156, 102), 'plaster'),
    'plaster_g':  ((150, 166, 150), 'plaster'),
    'concrete':   ((138, 136, 126), 'panel'),
    'concrete_s': ((132, 130, 122), 'plaster'),
    'steel':      ((122, 128, 128), 'corrugated_v'),
    'steel_blue': ((76, 102, 118), 'corrugated_v'),
    'steel_rust': ((128, 84, 54), 'corrugated_v'),
    'steel_olive': ((90, 100, 66), 'corrugated_v'),
    'container_r': ((128, 62, 44), 'corrugated_v'),
    'container_b': ((60, 90, 112), 'corrugated_v'),
    'container_g': ((78, 100, 70), 'corrugated_v'),
    'slate':      ((126, 128, 120), 'slate'),
    'slate_dark': ((96, 100, 96), 'slate'),
    'tiles':      ((142, 72, 50), 'tiles'),
    'tin_green':  ((78, 108, 84), 'seam'),
    'tin_red':    ((134, 64, 48), 'seam'),
    'tin_grey':   ((120, 124, 122), 'seam'),
    'tin_olive':  ((88, 98, 64), 'seam'),
    'tar':        ((66, 68, 66), 'tar'),
    'shingle':    ((96, 78, 60), 'shingle'),
    'glass':      ((120, 160, 170), 'glass'),
    'earth':      ((90, 100, 60), 'earth'),
    'sandbag':    ((156, 138, 98), 'sandbag'),
    'wood_dark':  ((88, 66, 46), 'plank_h'),
    'metal':      ((96, 100, 100), 'none'),
    'tarp_blue':  ((58, 88, 124), 'tarp'),
    'tarp_green': ((72, 92, 60), 'tarp'),
    'tarp_orange': ((168, 96, 44), 'tarp'),
    'tarp_grey':  ((118, 116, 106), 'tarp'),
    'plywood':    ((150, 124, 86), 'plank_h'),
    'hole':       ((24, 22, 20), 'none'),
    'none':       ((128, 128, 128), 'none'),
}


class Face:
    """planar quad: o + u*a + v*b, a in [0, lu], b in [0, lv]."""

    def __init__(self, o, u, v, lu, lv, col, pattern='none', bias=0.0, pat_scale=1.0, outline=True, alpha=255):
        self.o = np.asarray(o, float)
        self.u = norm(np.asarray(u, float))
        self.v = norm(np.asarray(v, float))
        self.lu, self.lv = float(lu), float(lv)
        # v x u: front walls face +y (toward the camera), roofs face +z
        self.n = norm(np.cross(self.v, self.u))
        self.col = col
        self.pattern = pattern
        self.bias = bias
        self.pat_scale = pat_scale
        self.outline = outline
        self.alpha = alpha
        self.decals = []       # (kind, params) drawn clipped to this face after the pattern

    def pt(self, a, b):
        return self.o + self.u * a + self.v * b

    def corners(self):
        return [self.pt(0, 0), self.pt(self.lu, 0), self.pt(self.lu, self.lv), self.pt(0, self.lv)]

    def depth(self):
        c = self.pt(self.lu / 2, self.lv / 2)
        return float(np.dot(c, VIEW)) + self.bias

    def visible(self):
        return float(np.dot(self.n, VIEW)) > 0.02


class Model:
    def __init__(self, W, D, H, seed=1):
        self.W, self.D, self.H = W, D, H
        self.faces = []
        self.polys = []      # free 3D polygons / lines with depth: (depth, kind, data)
        self.rng = random.Random(seed)
        self.seed = seed

    # ---------------------------------------------------------- primitives --
    def add(self, face):
        self.faces.append(face)
        return face

    def box(self, x0, x1, y0, y1, z0, z1, mat, top=None, front=None, bias=0.0, pat_scale=1.0, cap=True, outline=True):
        """axis aligned box; returns dict of visible faces (front, top)."""
        col, pat = MAT[mat] if isinstance(mat, str) else mat
        tcol, tpat = MAT[top] if isinstance(top, str) else (top if top else (col, pat))
        fcol, fpat = MAT[front] if isinstance(front, str) else (front if front else (col, pat))
        out = {}
        # south face (y = y1), u along +x, v along +z
        out['front'] = self.add(Face(V(x0, y1, z0), V(1, 0, 0), V(0, 0, 1), x1 - x0, z1 - z0, fcol, fpat, bias, pat_scale, outline))
        if cap:
            # top face (z = z1), u along +x, v along -y (from south edge to north)
            out['top'] = self.add(Face(V(x0, y1, z1), V(1, 0, 0), V(0, -1, 0), x1 - x0, y1 - y0, tcol, tpat, bias + 0.01, pat_scale, outline))
        return out

    def gable_x(self, x0, x1, y0, y1, z0, rise, mat, over=4.0, over_x=4.0, bias=0.0):
        """ridge along x at the middle of y; both slopes visible from above."""
        col, pat = MAT[mat]
        yc = (y0 + y1) / 2
        ya, yb = y0 - over, y1 + over
        za = z0 - over * rise / ((y1 - y0) / 2)
        xa, xb = x0 - over_x, x1 + over_x
        # south slope: from eave (yb, za) up to ridge (yc, z0+rise)
        L = math.hypot(yb - yc, z0 + rise - za)
        s = self.add(Face(V(xa, yb, za), V(1, 0, 0), norm(V(0, yc - yb, z0 + rise - za)), xb - xa, L, col, pat, bias))
        n = self.add(Face(V(xa, yc, z0 + rise), V(1, 0, 0), norm(V(0, ya - yc, za - (z0 + rise))), xb - xa, L, dark(col, 0.92), pat, bias - 0.5))
        return s, n

    def hip(self, x0, x1, y0, y1, z0, rise, mat, over=4.0, bias=0.0):
        col, pat = MAT[mat]
        xa, xb, ya, yb = x0 - over, x1 + over, y0 - over, y1 + over
        za = z0 - over * 0.5
        inset = min((yb - ya) / 2, (xb - xa) / 2) * 0.9
        zr = z0 + rise
        yc = (ya + yb) / 2
        rx0, rx1 = xa + inset, xb - inset
        # south trapezoid as a face with a clip polygon
        self.poly3([V(xa, yb, za), V(xb, yb, za), V(rx1, yc, zr), V(rx0, yc, zr)], col, pat, bias, frame=(V(xa, yb, za), V(1, 0, 0), norm(V(0, yc - yb, zr - za))))
        self.poly3([V(xa, ya, za), V(rx0, yc, zr), V(rx1, yc, zr), V(xb, ya, za)], dark(col, 0.9), pat, bias - 0.5, frame=(V(xa, ya, za), V(1, 0, 0), norm(V(0, yc - ya, zr - za))))
        self.poly3([V(xa, ya, za), V(xa, yb, za), V(rx0, yc, zr)], dark(col, 0.86), pat, bias - 0.4, frame=(V(xa, yb, za), V(0, -1, 0), norm(V(rx0 - xa, 0, zr - za))))
        self.poly3([V(xb, yb, za), V(xb, ya, za), V(rx1, yc, zr)], mix(col, (255, 240, 220), 0.05), pat, bias - 0.4, frame=(V(xb, ya, za), V(0, 1, 0), norm(V(rx1 - xb, 0, zr - za))))

    def poly3(self, pts, col, pat='none', bias=0.0, frame=None, outline=True):
        """textured arbitrary planar polygon (frame = (origin, u, v) for the pattern)."""
        cen = np.mean(pts, axis=0)
        n = norm(np.cross(pts[1] - pts[0], pts[2] - pts[0]))
        if np.dot(n, VIEW) < 0:
            n = -n
        self.polys.append((float(np.dot(cen, VIEW)) + bias, 'poly', (pts, col, pat, n, frame, outline)))

    def line3(self, pts, col, width=1, bias=0.0):
        cen = np.mean(pts, axis=0)
        self.polys.append((float(np.dot(cen, VIEW)) + bias, 'line', (pts, col, width)))

    def cyl(self, cx, cy, z0, z1, r, mat, segs=14, bias=0.0, cap=True):
        col, pat = MAT[mat] if isinstance(mat, str) else mat
        for i in range(segs):
            a0 = math.pi * i / segs          # only the south half faces the camera
            a1 = math.pi * (i + 1) / segs
            p0 = V(cx + math.cos(a0) * r, cy + math.sin(a0) * r, z0)
            p1 = V(cx + math.cos(a1) * r, cy + math.sin(a1) * r, z0)
            n = norm(V(math.cos((a0 + a1) / 2), math.sin((a0 + a1) / 2), 0))
            c = shade(col, n)
            pts = [p0, p1, p1 + V(0, 0, z1 - z0), p0 + V(0, 0, z1 - z0)]
            self.polys.append((float(np.dot(V(cx, cy + r, (z0 + z1) / 2), VIEW)) + bias + i * 1e-4, 'flat', (pts, c)))
        if cap:
            pts = [V(cx + math.cos(2 * math.pi * i / 18) * r, cy + math.sin(2 * math.pi * i / 18) * r, z1) for i in range(18)]
            self.polys.append((float(np.dot(V(cx, cy, z1), VIEW)) + bias + 0.2, 'flat', (pts, shade(col, V(0, 0, 1)))))

    def arch_y(self, x0, x1, y0, y1, z0, mat, segs=12, bias=0.0, zs=1.0):
        """Quonset half-cylinder with its axis along y; returns front arch outline pts."""
        col, pat = MAT[mat]
        r = (x1 - x0) / 2
        cx = (x0 + x1) / 2
        for i in range(segs):
            a0 = math.pi * i / segs
            a1 = math.pi * (i + 1) / segs
            pa0 = V(cx - math.cos(a0) * r, 0, z0 + math.sin(a0) * r * zs)
            pa1 = V(cx - math.cos(a1) * r, 0, z0 + math.sin(a1) * r * zs)
            pts = [pa0 + V(0, y1, 0), pa1 + V(0, y1, 0), pa1 + V(0, y0, 0), pa0 + V(0, y0, 0)]
            self.poly3(pts, col, pat, bias - 1.0 + i * 1e-3, frame=(pa0 + V(0, y1, 0), V(0, -1, 0), norm(pa1 - pa0)))
        front = [V(cx - math.cos(math.pi * i / 24) * r, y1, z0 + math.sin(math.pi * i / 24) * r * zs) for i in range(25)]
        return front

    # ------------------------------------------------------------ openings --
    def window(self, face, u, v, w, h, style='frame', frame_col=(186, 182, 168), glass=(52, 66, 74), shutters=None, bars=False, lit=False, sill=True):
        face.decals.append(('window', dict(u=u, v=v, w=w, h=h, style=style, frame=frame_col, glass=glass,
                                           shutters=shutters, bars=bars, lit=lit, sill=sill)))

    def door(self, face, u, w, h, col=(92, 70, 48), frame_col=(60, 52, 44), kind='door', glass=False):
        face.decals.append(('door', dict(u=u, w=w, h=h, col=col, frame=frame_col, kind=kind, glass=glass)))

    def rect(self, face, u, v, w, h, col, kind='rect', **kw):
        d = dict(u=u, v=v, w=w, h=h, col=col)
        d.update(kw)
        face.decals.append((kind, d))


# --------------------------------------------------------------- rendering --
class Canvas:
    def __init__(self, model, pad=24):
        m = model
        self.m = m
        # bounding box of all geometry in screen units
        pts = []
        for f in m.faces:
            pts += f.corners()
        for d, kind, data in m.polys:
            pts += list(data[0])
        xs = [p[0] for p in pts]
        ys = [p[1] - p[2] for p in pts]
        self.x0 = math.floor(min(xs)) - pad
        self.y0 = math.floor(min(ys)) - pad
        self.x1 = math.ceil(max(xs)) + pad
        self.y1 = math.ceil(max(ys)) + pad
        self.w = int((self.x1 - self.x0) * DENS)
        self.h = int((self.y1 - self.y0) * DENS)
        self.img = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))

    def P(self, p):
        return ((p[0] - self.x0) * DENS, (p[1] - p[2] - self.y0) * DENS)

    def to_model(self, px, py):
        return (px / DENS + self.x0, py / DENS + self.y0)


def _pattern(draw, face_pt, P, lu, lv, pat, col, rng, s=1.0):
    """draw material pattern lines in face-local (u, v) coords."""
    d = draw
    dk = dark(col, 0.72)
    lt = mix(col, (255, 250, 235), 0.14)

    def L(a0, b0, a1, b1, c, w=1):
        d.line([P(face_pt(a0, b0)), P(face_pt(a1, b1))], fill=c + (255,), width=w)

    if pat in ('slate', 'tiles', 'shingle', 'seam', 'log', 'plank_h', 'brick', 'sandbag'):
        # tile / board colour jitter so large surfaces never read as one flat fill
        cw = {'slate': 8.0, 'tiles': 5.0, 'shingle': 5.0, 'seam': 7.0, 'log': 60.0, 'plank_h': 38.0, 'brick': 7.0, 'sandbag': 8.0}[pat] * s
        ch = {'slate': 4.0, 'tiles': 3.5, 'shingle': 3.0, 'seam': 1e9, 'log': 5.0, 'plank_h': 4.0, 'brick': 3.0, 'sandbag': 4.0}[pat] * s
        amp = {'slate': 0.07, 'tiles': 0.09, 'shingle': 0.10, 'seam': 0.05, 'log': 0.06, 'plank_h': 0.07, 'brick': 0.08, 'sandbag': 0.06}[pat]
        b = 0.0
        row = 0
        while b < lv:
            a = -((row % 2) * cw * 0.5)
            hh = min(ch, lv - b)
            while a < lu:
                k = 1.0 + rng.uniform(-amp, amp)
                cc = tuple(int(max(0, min(255, v * k))) for v in col)
                a0, a1 = max(0.0, a), min(lu, a + cw)
                if a1 > a0:
                    d.polygon([P(face_pt(a0, b)), P(face_pt(a1, b)), P(face_pt(a1, b + hh)), P(face_pt(a0, b + hh))], fill=cc + (255,))
                a += cw
            b += ch if ch < 1e8 else lv
            row += 1
    if pat == 'plank_h':
        step = 4.0 * s
        b = step
        i = 0
        while b < lv:
            L(0, b, lu, b, dk)
            # butt joints
            off = (i * 17) % 40
            a = off
            while a < lu:
                L(a, b - step, a, b, dark(col, 0.8))
                a += 38 + (i * 7) % 11
            b += step
            i += 1
    elif pat == 'plank_v':
        a = 0.0
        i = 0
        while a < lu:
            L(a, 0, a, lv, dk)
            a += 5.0 * s + (i % 3) * 0.5
            i += 1
    elif pat == 'log':
        step = 5.0 * s
        b = step
        while b < lv:
            L(0, b, lu, b, dark(col, 0.6), 2)
            L(0, b - step + 1.2, lu, b - step + 1.2, lt)
            b += step
    elif pat == 'brick':
        step = 3.0 * s
        b = step
        row = 0
        while b < lv:
            L(0, b, lu, b, dark(col, 0.78))
            a = (row % 2) * 3.5 * s
            while a < lu:
                L(a, b - step, a, b, dark(col, 0.82))
                a += 7.0 * s
            b += step
            row += 1
    elif pat == 'panel':
        a = 0.0
        while a < lu:
            L(a, 0, a, lv, dark(col, 0.8))
            a += 36.0 * s
        b = 14.0 * s
        while b < lv:
            L(0, b, lu, b, dark(col, 0.82))
            b += 14.0 * s
    elif pat == 'corrugated_v':
        a = 0.0
        i = 0
        while a < lu:
            L(a, 0, a, lv, dk if i % 2 else lt)
            a += 2.0 * s
            i += 1
    elif pat == 'slate':
        step = 4.0 * s
        b = 0.0
        row = 0
        while b < lv:
            L(0, b, lu, b, dk)
            a = (row % 2) * 4.0 * s
            while a < lu:
                L(a, b, a, b + step * 0.7, dark(col, 0.85))
                a += 8.0 * s
            b += step
            row += 1
    elif pat == 'tiles':
        step = 3.5 * s
        b = 0.0
        row = 0
        while b < lv:
            L(0, b, lu, b, dark(col, 0.62))
            a = (row % 2) * 2.5 * s
            while a < lu:
                L(a, b, a, b + step * 0.8, dark(col, 0.78))
                a += 5.0 * s
            b += step
            row += 1
    elif pat == 'seam':
        a = 0.0
        while a < lu:
            L(a, 0, a, lv, dk)
            L(a + 1.0, 0, a + 1.0, lv, lt)
            a += 7.0 * s
    elif pat == 'shingle':
        step = 3.0 * s
        b = 0.0
        row = 0
        while b < lv:
            L(0, b, lu, b, dk)
            a = (row % 2) * 2.0 + rng.random() * 2
            while a < lu:
                L(a, b, a, b + step, dark(col, 0.84))
                a += 4.0 + rng.random() * 3
            b += step
            row += 1
    elif pat == 'tarp':
        for _ in range(int(lu * lv / 90) + 3):
            a, b = rng.random() * lu, rng.random() * lv
            L(a, b, a + rng.uniform(-6, 6), b + rng.uniform(3, 10), dark(col, 0.78))
            L(a + 1, b, a + 1 + rng.uniform(-6, 6), b + rng.uniform(3, 10), mix(col, (255, 255, 255), 0.12))
    elif pat == 'tar':
        for _ in range(int(lu * lv / 140)):
            a, b = rng.random() * lu, rng.random() * lv
            L(a, b, a + 3 + rng.random() * 6, b, dark(col, 0.82))
    elif pat == 'glass':
        a = 0.0
        while a < lu:
            L(a, 0, a, lv, (150, 156, 150), 1)
            a += 10.0 * s
        b = 0.0
        while b < lv:
            L(0, b, lu, b, (150, 156, 150), 1)
            b += 8.0 * s
    elif pat == 'sandbag':
        step = 4.0
        b = step
        row = 0
        while b < lv + 0.1:
            L(0, b, lu, b, dark(col, 0.7))
            a = (row % 2) * 4.0
            while a < lu:
                L(a, b - step, a, b, dark(col, 0.75))
                a += 8.0
            b += step
            row += 1
    elif pat == 'earth':
        for _ in range(int(lu * lv / 40)):
            a, b = rng.random() * lu, rng.random() * lv
            c = rng.choice([(78, 92, 50), (104, 112, 64), (88, 76, 54)])
            L(a, b, a + 1, b, c)


def _ambient(layer, c, face_pt, lu, lv, n, steps=10):
    """roof slopes darken toward the eave (occlusion), walls get a grime band at the ground."""
    ov = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    zs = [face_pt(0, lv * i / steps)[2] for i in range(steps + 1)]
    zmin, zmax = min(zs), max(zs)
    if n[2] > 0.3 and zmax - zmin > 2:
        for i in range(steps):
            b0, b1 = lv * i / steps, lv * (i + 1) / steps
            z = (zs[i] + zs[i + 1]) / 2
            t = 1 - (z - zmin) / (zmax - zmin)
            od.polygon([c.P(face_pt(0, b0)), c.P(face_pt(lu, b0)), c.P(face_pt(lu, b1)), c.P(face_pt(0, b1))],
                       fill=(8, 8, 10, int(46 * t * t)))
    elif abs(n[2]) < 0.2 and zmin < 1.0:
        # mud splash and damp rising from the ground
        for i in range(8):
            b0, b1 = i * 2.0, i * 2.0 + 2.0
            if b1 > lv:
                break
            od.polygon([c.P(face_pt(0, b0)), c.P(face_pt(lu, b0)), c.P(face_pt(lu, b1)), c.P(face_pt(0, b1))],
                       fill=(30, 24, 16, int(92 * (1 - i / 8) ** 1.5)))
        rng2 = random.Random(int(lu * 13 + lv * 7))
        for _ in range(int(lu / 10)):
            a = rng2.uniform(0, lu)
            hgt = rng2.uniform(4, 14)
            wd = rng2.uniform(3, 9)
            od.polygon([c.P(face_pt(a, 0)), c.P(face_pt(a + wd, 0)), c.P(face_pt(a + wd * 0.6, hgt)), c.P(face_pt(a + wd * 0.3, hgt))],
                       fill=(34, 30, 20, rng2.randint(30, 60)))
    layer.alpha_composite(ov)


def _face_poly(c, f):
    return [c.P(p) for p in f.corners()]


def _draw_face(c, f, rng):
    img = c.img
    col = shade(f.col, f.n)
    poly = _face_poly(c, f)
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon(poly, fill=col + (f.alpha,))
    _pattern(d, f.pt, c.P, f.lu, f.lv, f.pattern, col, rng, f.pat_scale)
    _ambient(layer, c, f.pt, f.lu, f.lv, f.n)
    for kind, p in f.decals:
        _draw_decal(d, c, f, kind, p, col, rng, layer)
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    if f.alpha < 255:
        la = np.array(layer)
        la[..., 3] = np.minimum(la[..., 3], f.alpha)
        layer = Image.fromarray(la)
    img.paste(layer, (0, 0), Image.fromarray(np.minimum(np.array(mask), np.array(layer)[..., 3])))
    if f.outline:
        ImageDraw.Draw(img).polygon(poly, outline=dark(col, 0.5) + (255,))


def _draw_decal(d, c, f, kind, p, face_col, rng, layer=None):
    P = c.P
    pt = f.pt

    def R(a0, b0, a1, b1, col):
        d.polygon([P(pt(a0, b0)), P(pt(a1, b0)), P(pt(a1, b1)), P(pt(a0, b1))], fill=col + (255,))

    def L(a0, b0, a1, b1, col, w=1):
        d.line([P(pt(a0, b0)), P(pt(a1, b1))], fill=col + (255,), width=w)

    if kind == 'window':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        fr = shade(p['frame'], f.n)
        gl = p['glass']
        if p['lit']:
            gl = (196, 160, 96)
        # reveal / shadow
        R(u - 1.2, v - 1.2, u + w + 1.2, v + h + 1.2, fr)
        R(u, v, u + w, v + h, dark(gl, 0.9))
        # sky reflection gradient: lighter upper-left triangle
        d.polygon([P(pt(u, v + h)), P(pt(u + w * 0.55, v + h)), P(pt(u, v + h * 0.35))], fill=mix(gl, (170, 190, 196), 0.35) + (255,))
        R(u, v + h - 1.2, u + w, v + h, dark(gl, 0.6))        # lintel shadow
        if p['style'] in ('frame', 'cross', 'nalichnik', 'tall'):
            L(u + w / 2, v, u + w / 2, v + h, fr)
            if p['style'] != 'tall':
                L(u, v + h * 0.66, u + w, v + h * 0.66, fr)
        elif p['style'] == 'strip':
            a = u + 6
            while a < u + w - 1:
                L(a, v, a, v + h, fr)
                a += 6
        elif p['style'] == 'arch':
            d.polygon([P(pt(u - 1.2, v + h)), P(pt(u + w + 1.2, v + h)), P(pt(u + w / 2, v + h + w * 0.35))], fill=fr + (255,))
            L(u + w / 2, v, u + w / 2, v + h, fr)
        if p['bars']:
            a = u + 1.5
            while a < u + w:
                L(a, v, a, v + h, (40, 40, 40))
                a += 2.5
        if p['sill']:
            R(u - 2, v - 1.8, u + w + 2, v - 0.6, mix(fr, (230, 226, 214), 0.2))
        if p['style'] == 'nalichnik':
            nc = (80, 108, 132)
            R(u - 2.2, v + h + 0.4, u + w + 2.2, v + h + 2.4, nc)
            d.polygon([P(pt(u - 2.2, v + h + 2.4)), P(pt(u + w + 2.2, v + h + 2.4)), P(pt(u + w / 2, v + h + 5.0))], fill=nc + (255,))
            R(u - 2.2, v - 2.6, u + w + 2.2, v - 1.2, nc)
        if p['shutters']:
            sc = p['shutters']
            R(u - w * 0.5 - 1.5, v, u - 1.5, v + h, sc)
            R(u + w + 1.5, v, u + w + w * 0.5 + 1.5, v + h, sc)
            L(u - w * 0.25 - 1.5, v, u - w * 0.25 - 1.5, v + h, dark(sc, 0.7))
            L(u + w + w * 0.25 + 1.5, v, u + w + w * 0.25 + 1.5, v + h, dark(sc, 0.7))
    elif kind == 'door':
        u, w, h = p['u'], p['w'], p['h']
        fr = p['frame']
        R(u - 1.5, 0, u + w + 1.5, h + 1.5, fr)
        R(u, 0, u + w, h, (22, 22, 20))                       # dark doorway; the game adds the leaf
        if p['kind'] == 'gate':
            col = shade(p['col'], f.n)
            R(u, 0, u + w, h, col)
            a = u + 2
            while a < u + w - 1:
                L(a, 0, a, h, dark(col, 0.7))
                a += 4
            L(u + w / 2, 0, u + w / 2, h, dark(col, 0.5), 2)
        elif p['kind'] == 'shutter':
            col = shade(p['col'], f.n)
            R(u, 0, u + w, h, col)
            b = 2.0
            while b < h:
                L(u, b, u + w, b, dark(col, 0.72))
                b += 2.4
            R(u, h - 3, u + w, h, dark(col, 0.6))
    elif kind == 'rect':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        R(u, v, u + w, v + h, shade(p['col'], f.n) if p.get('lit_shade', True) else p['col'])
        if p.get('border'):
            bc = p['border']
            L(u, v, u + w, v, bc); L(u, v + h, u + w, v + h, bc)
            L(u, v, u, v + h, bc); L(u + w, v, u + w, v + h, bc)
    elif kind == 'cross':
        u, v, s = p['u'], p['v'], p['s']
        col = p['col']
        if p.get('disc'):
            dc = p['disc']
            pts = [P(pt(u + math.cos(a) * s * 1.25, v + math.sin(a) * s * 1.25)) for a in np.linspace(0, 2 * math.pi, 20)]
            d.polygon(pts, fill=dc + (255,))
        R(u - s, v - s * 0.33, u + s, v + s * 0.33, col)
        R(u - s * 0.33, v - s, u + s * 0.33, v + s, col)
    elif kind == 'stripe':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        n = int(w // p.get('period', 6))
        for i in range(n):
            a = u + i * p.get('period', 6)
            col = p['c1'] if i % 2 == 0 else p['c2']
            d.polygon([P(pt(a, v)), P(pt(a + p.get('period', 6) / 2, v)), P(pt(a + p.get('period', 6), v + h)), P(pt(a + p.get('period', 6) / 2, v + h))], fill=col + (255,))
    elif kind == 'shade':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        a = p.get('alpha', 90)
        ov = Image.new('RGBA', c.img.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).polygon([P(pt(u, v)), P(pt(u + w, v)), P(pt(u + w, v + h)), P(pt(u, v + h))], fill=(10, 10, 12, a))
        layer.alpha_composite(ov)
    elif kind == 'boards':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        R(u - 0.5, v - 0.5, u + w + 0.5, v + h + 0.5, (26, 24, 22))
        for i, t in enumerate(p.get('rows', (0.2, 0.55, 0.85))):
            b = v + h * t
            sl = rng.uniform(-1.6, 1.6)
            pc = mix(p.get('col', (132, 104, 72)), (60, 50, 40), rng.uniform(0, 0.35))
            d.polygon([P(pt(u - 2, b - 1.4 + sl)), P(pt(u + w + 2, b - 1.4 - sl)), P(pt(u + w + 2, b + 1.4 - sl)), P(pt(u - 2, b + 1.4 + sl))], fill=pc + (255,))
            d.line([P(pt(u - 2, b - 1.4 + sl)), P(pt(u + w + 2, b - 1.4 - sl))], fill=dark(pc, 0.6) + (255,))
            for a in (u - 1, u + w + 1):
                d.point(P(pt(a, b)), fill=(40, 40, 40, 255))
    elif kind == 'plywood':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        pc = p.get('col', (150, 124, 86))
        R(u - 1, v - 1, u + w + 1, v + h + 1, pc)
        for k in range(1, int(h // 5) + 1):
            L(u - 1, v + k * 5, u + w + 1, v + k * 5, dark(pc, 0.86))
        for a, b in ((u, v), (u + w, v), (u, v + h), (u + w, v + h)):
            d.point(P(pt(a, b)), fill=(50, 46, 40, 255))
        if rng.random() < 0.5:
            L(u + 1, v + 1, u + w - 1, v + h - 1, dark(pc, 0.7))
    elif kind == 'broken':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        cx, cy = u + w * rng.uniform(0.3, 0.7), v + h * rng.uniform(0.3, 0.7)
        pts = []
        for i in range(9):
            a = 2 * math.pi * i / 9
            r = rng.uniform(0.35, 0.95)
            pts.append(P(pt(min(u + w, max(u, cx + math.cos(a) * w * 0.5 * r)), min(v + h, max(v, cy + math.sin(a) * h * 0.5 * r)))))
        d.polygon(pts, fill=(14, 14, 14, 255))
        for i in range(3):
            a = rng.uniform(0, 2 * math.pi)
            L(cx, cy, cx + math.cos(a) * w * 0.6, cy + math.sin(a) * h * 0.6, (150, 164, 170))
    elif kind == 'tape':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        tc = (206, 196, 150)
        L(u + 1, v + 1, u + w - 1, v + h - 1, tc, 2)
        L(u + 1, v + h - 1, u + w - 1, v + 1, tc, 2)
    elif kind == 'sandbags':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        rows = int(h // 3.2)
        for r in range(rows):
            off = (r % 2) * 2.5
            a = u - 2 - off
            while a < u + w + 2:
                c = mix((156, 138, 98), (120, 104, 72), rng.random() * 0.5)
                R(max(u - 2, a), v + r * 3.2, min(u + w + 2, a + 5), v + r * 3.2 + 3.0, c)
                L(max(u - 2, a), v + r * 3.2, min(u + w + 2, a + 5), v + r * 3.2, dark(c, 0.6))
                a += 5.4
    elif kind == 'soot':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        ov = Image.new('RGBA', c.img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(ov)
        for i in range(6):
            t = i / 6
            od.polygon([P(pt(u + w * (0.5 - 0.5 * (1 - t) - 0.2 * t), v + h * t)), P(pt(u + w * (0.5 + 0.5 * (1 - t) + 0.2 * t), v + h * t)),
                        P(pt(u + w * (0.5 + 0.5 * (1 - t) + 0.2 * t), v + h * (t + 1 / 6))), P(pt(u + w * (0.5 - 0.5 * (1 - t) - 0.2 * t), v + h * (t + 1 / 6)))],
                       fill=(18, 16, 14, int(70 * (1 - t))))
        layer.alpha_composite(ov)
    elif kind == 'peel':
        # plaster fallen off: an irregular hole showing the brick underneath
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        pts = []
        for i in range(10):
            a = 2 * math.pi * i / 10
            r = rng.uniform(0.55, 1.0)
            pts.append((u + w / 2 + math.cos(a) * w / 2 * r, v + h / 2 + math.sin(a) * h / 2 * r))
        bc = shade((138, 80, 60), f.n)
        d.polygon([P(pt(a, b)) for a, b in pts], fill=bc + (255,))
        b = v + 1.5
        row = 0
        while b < v + h:
            L(u + w * 0.15, b, u + w * 0.85, b, dark(bc, 0.72))
            a = u + (row % 2) * 3
            while a < u + w:
                if abs(a - (u + w / 2)) < w * 0.38:
                    L(a, b - 3, a, b, dark(bc, 0.8))
                a += 6
            b += 3
            row += 1
        d.line([P(pt(a, b)) for a, b in pts + [pts[0]]], fill=mix(face_col, (240, 236, 224), 0.25) + (255,))
    elif kind == 'sheet':
        # corrugated patch screwed over a damaged wall area
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        sc = p.get('col', (124, 128, 128))
        R(u, v, u + w, v + h, sc)
        a = u
        i = 0
        while a < u + w:
            L(a, v, a, v + h, dark(sc, 0.75) if i % 2 else mix(sc, (255, 255, 255), 0.15))
            a += 2
            i += 1
        for a in (u + 1, u + w - 1):
            for b in (v + 1, v + h - 1):
                d.point(P(pt(a, b)), fill=(40, 40, 40, 255))
        if rng.random() < 0.6:
            L(u + w * 0.3, v + h, u + w * 0.35, v, (118, 70, 40))
    elif kind == 'graffiti':
        u, v, w, h = p['u'], p['v'], p['w'], p['h']
        col = p.get('col', rng.choice([(186, 56, 44), (214, 210, 196), (70, 110, 170), (210, 180, 60), (40, 40, 40)]))
        x = u
        while x < u + w - 2:
            seg = rng.uniform(2.5, 5)
            L(x, v + rng.uniform(0, h), x + seg, v + rng.uniform(0, h), col, 2)
            if rng.random() < 0.35:
                x += 2.5
            x += seg * 0.8
        if p.get('underline'):
            L(u, v - 1, u + w, v - 1.5, col, 1)
    elif kind == 'streak':
        # rain / rust streaks down from window sills
        u, v, h = p['u'], p['v'], p['h']
        col = p.get('col', dark(face_col, 0.78))
        L(u, v, u + 0.3, v - h, col, 2 if h > 12 else 1)
        L(u + 0.3, v - h, u + 0.5, v - h - 2, dark(col, 0.9))


def _draw_poly(c, data, rng):
    pts, col, pat, n, frame, outline = data
    colf = shade(col, n)
    poly = [c.P(p) for p in pts]
    layer = Image.new('RGBA', c.img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon(poly, fill=colf + (255,))
    if pat != 'none' and frame is not None:
        o, u, v = frame
        lu = max(np.dot(p - o, u) for p in pts) + 2
        lv = max(np.dot(p - o, v) for p in pts) + 2
        _pattern(d, lambda a, b: o + u * a + v * b, c.P, lu, lv, pat, colf, rng)
    mask = Image.new('L', c.img.size, 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    c.img.paste(layer, (0, 0), mask)
    if outline:
        ImageDraw.Draw(c.img).polygon(poly, outline=dark(colf, 0.5) + (255,))


def render(model, grime=0.10, rust=0.0, moss=0.0, seed=None, outline=True):
    c = Canvas(model)
    rng = random.Random(model.seed if seed is None else seed)
    items = []
    for f in model.faces:
        if f.visible():
            items.append((f.depth(), 'face', f))
    for depth, kind, data in model.polys:
        items.append((depth, kind, data))
    items.sort(key=lambda t: t[0])
    d = ImageDraw.Draw(c.img)
    for depth, kind, data in items:
        if kind == 'face':
            _draw_face(c, data, rng)
        elif kind == 'poly':
            _draw_poly(c, data, rng)
        elif kind == 'flat':
            pts, col = data
            d.polygon([c.P(p) for p in pts], fill=col + (255,))
        elif kind == 'line':
            pts, col, w = data
            d.line([c.P(p) for p in pts], fill=col + (255,), width=w)
    img = c.img
    img = _weather(img, model.seed, grime, rust, moss)
    if outline:
        img = outline_img(img)
    c.img = img
    return c


def _weather(img, seed, grime, rust, moss):
    a = np.array(img).astype(float)
    h, w = a.shape[:2]
    A = a[..., 3] > 0
    n = fbm(w, h, 10, seed, 4, wrap=False)
    a[..., :3] *= (1 - grime / 2 + grime * n)[..., None]
    fine = fbm(w, h, 3, seed + 3, 2, wrap=False)
    a[..., :3] *= (0.96 + 0.08 * fine)[..., None]
    if rust > 0:
        rn = fbm(w, h, 6, seed + 9, 3, wrap=False)
        rm = A & (rn > 1 - rust)
        a[rm, :3] = a[rm, :3] * 0.45 + np.array((118, 62, 32), float) * 0.55
    if moss > 0:
        mn = fbm(w, h, 7, seed + 21, 3, wrap=False)
        mm = A & (mn > 1 - moss)
        a[mm, :3] = a[mm, :3] * 0.55 + np.array((74, 88, 46), float) * 0.45
    a[..., 3] = np.where(A, a[..., 3], 0)
    return Image.fromarray(clamp8(a), 'RGBA')


def sprinkle_leaves(img, seed, density=0.004, rows=None):
    """fallen autumn leaves on roofs / ledges (the world's signature orange flecks)."""
    a = np.array(img)
    rng = random.Random(seed)
    h, w = a.shape[:2]
    y_lo, y_hi = rows if rows else (0, h)
    ys, xs = np.nonzero(a[y_lo:y_hi, :, 3] > 0)
    ys = ys + y_lo
    lf = fbm(w, h, 12, seed + 5, 3, wrap=False)
    for _ in range(int(len(xs) * density)):
        i = rng.randrange(len(xs))
        y, x = ys[i], xs[i]
        if lf[y, x] < 0.42:
            continue
        c = rng.choice(LEAF_ORANGE)
        a[y, x, :3] = c
        if x + 1 < w and a[y, x + 1, 3] > 0 and rng.random() < 0.5:
            a[y, x + 1, :3] = tuple(int(v * 0.8) for v in c)
    return Image.fromarray(a, 'RGBA')
