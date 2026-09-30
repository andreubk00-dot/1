"""OSTATOK 0.87 world-art core.

* tileable value noise (wraps at the texture size so chunks / roofs repeat seamlessly)
* numpy paint helpers (grime, leaves, cracks, speckle)
* a small 3/4 top-down block renderer for props / vehicles / roof equipment
  (same camera + light as the survivor rig, so everything shares one lighting language)
"""
import math
import random
import numpy as np
from PIL import Image, ImageDraw

YK = 0.55
CAM = np.array([0.0, 1.0, YK]); CAM /= np.linalg.norm(CAM)
LIGHT = np.array([-0.45, 0.30, 0.84]); LIGHT /= np.linalg.norm(LIGHT)
OUTLINE = (18, 16, 14)

# ---------------------------------------------------------------- palette --
LEAF_ORANGE = [(196, 112, 34), (170, 86, 28), (214, 150, 52), (150, 70, 26), (188, 132, 40)]
MOSS = [(70, 88, 42), (58, 74, 36), (86, 100, 48)]


def clamp8(a):
    return np.clip(a, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------- noise ---
def value_noise(w, h, cell, seed, wrap=True):
    rng = np.random.default_rng(seed)
    gw, gh = max(1, int(round(w / cell))), max(1, int(round(h / cell)))
    g = rng.random((gh + 1, gw + 1))
    if wrap:
        g[-1, :] = g[0, :]
        g[:, -1] = g[:, 0]
    ys = np.linspace(0, gh, h, endpoint=False)
    xs = np.linspace(0, gw, w, endpoint=False)
    y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
    fy = ys - y0; fx = xs - x0
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]; b = g[y0][:, x0 + 1]; c = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x0 + 1]
    top = a * (1 - fx) + b * fx
    bot = c * (1 - fx) + d * fx
    return top * (1 - fy)[:, None] + bot * fy[:, None]


def fbm(w, h, cell, seed, octaves=4, wrap=True):
    out = np.zeros((h, w)); amp = 1.0; tot = 0
    for o in range(octaves):
        c = max(1.0, cell / (2 ** o))
        out += value_noise(w, h, c, seed + o * 101, wrap) * amp
        tot += amp; amp *= 0.5
    return out / tot


class Tex:
    """Float RGBA canvas with painting helpers."""

    def __init__(self, w, h, col=(0, 0, 0), alpha=255, seed=1):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3)) + np.array(col, float)
        self.a = np.full((h, w), float(alpha))
        self.rng = random.Random(seed)
        self.seed = seed

    # -- masks
    def mask_rect(self, x0, y0, x1, y1):
        m = np.zeros((self.h, self.w), bool)
        m[max(0, int(y0)):max(0, int(y1)), max(0, int(x0)):max(0, int(x1))] = True
        return m

    def mask_poly(self, pts):
        im = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=255)
        return np.array(im) > 0

    def mask_ellipse(self, cx, cy, rx, ry):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0

    # -- paint
    def fill(self, m, col, alpha=255):
        self.rgb[m] = col
        self.a[m] = alpha

    def mul(self, m, k):
        if np.ndim(k) == 0:
            self.rgb[m] *= k
        else:
            self.rgb[m] *= k[m][:, None]

    def blend(self, m, col, t):
        """t: scalar or HxW array opacity"""
        col = np.array(col, float)
        if np.ndim(t) == 0:
            self.rgb[m] = self.rgb[m] * (1 - t) + col * t
        else:
            tt = t[m][:, None]
            self.rgb[m] = self.rgb[m] * (1 - tt) + col * tt

    def px(self, x, y, col, alpha=None):
        x, y = int(x) % self.w, int(y) % self.h
        self.rgb[y, x] = col
        if alpha is not None:
            self.a[y, x] = alpha

    def line(self, pts, col, width=1, wrap=True):
        im = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(im).line([tuple(p) for p in pts], fill=255, width=width)
        m = np.array(im) > 0
        self.rgb[m] = col
        return m

    def speckle(self, m, density, cols, seed=0):
        rng = np.random.default_rng(self.seed + seed)
        r = rng.random((self.h, self.w))
        sel = m & (r < density)
        idx = rng.integers(0, len(cols), size=(self.h, self.w))
        for i, c in enumerate(cols):
            s = sel & (idx == i)
            self.rgb[s] = c

    def crack(self, x, y, length, col, hi=None, branch=0.5, dirx=None, wrap=True):
        rng = self.rng
        ang = rng.uniform(0, math.tau) if dirx is None else dirx
        pts = [(x, y)]
        for _ in range(length):
            ang += rng.uniform(-0.7, 0.7)
            x += math.cos(ang); y += math.sin(ang)
            pts.append((x, y))
        for (px, py) in pts:
            ix, iy = int(px) % self.w if wrap else int(px), int(py) % self.h if wrap else int(py)
            if 0 <= ix < self.w and 0 <= iy < self.h:
                self.rgb[iy, ix] = col
                if hi is not None and 0 <= iy + 1 < self.h:
                    self.rgb[iy + 1, ix] = self.rgb[iy + 1, ix] * 0.5 + np.array(hi) * 0.5
        if length > 6 and rng.random() < branch:
            bx, by = pts[length // 2]
            self.crack(bx, by, length // 2, col, hi, branch * 0.5, None, wrap)
        return pts

    def leaves(self, m, density, seed=0, cols=None):
        """Scatter autumn leaves: 1-3px clusters with a darker pixel."""
        cols = cols or LEAF_ORANGE
        rng = np.random.default_rng(self.seed * 7 + seed)
        ys, xs = np.nonzero(m)
        n = int(len(xs) * density)
        if n == 0:
            return
        pick = rng.integers(0, len(xs), n)
        for i in pick:
            x, y = xs[i], ys[i]
            c = cols[rng.integers(0, len(cols))]
            self.rgb[y, x] = c
            if rng.random() < 0.6 and x + 1 < self.w and m[y, x + 1]:
                self.rgb[y, x + 1] = tuple(v * 0.8 for v in c)
            if rng.random() < 0.35 and y + 1 < self.h and m[y + 1, x]:
                self.rgb[y + 1, x] = tuple(v * 0.62 for v in c)

    def image(self):
        out = np.dstack([clamp8(self.rgb), clamp8(self.a)])
        return Image.fromarray(out, 'RGBA')


def outline_img(img, col=OUTLINE, alpha_cut=128):
    a = np.array(img)
    A = a[..., 3] >= alpha_cut
    g = np.zeros_like(A)
    g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
    e = g & ~(a[..., 3] > 0)
    a[e] = col + (255,)
    return Image.fromarray(a, 'RGBA')


def grunge(img, seed, amount=0.10, rust=0.0, dirt_bottom=0.25, leaves=0.0):
    """Post-pass for 3D-rendered props: value noise, rust speckle, bottom grime, leaves."""
    a = np.array(img).astype(float)
    h, w = a.shape[:2]
    A = a[..., 3] > 0
    n = fbm(w, h, 6, seed, 3, wrap=False)
    a[..., :3] *= (1 - amount / 2 + amount * n)[..., None]
    if rust > 0:
        rn = fbm(w, h, 5, seed + 9, 3, wrap=False)
        rm = A & (rn > 1 - rust)
        rust_col = np.array((122, 62, 30), float)
        a[rm, :3] = a[rm, :3] * 0.35 + rust_col * 0.65
        rm2 = A & (rn > 1 - rust * 0.45)
        a[rm2, :3] = a[rm2, :3] * 0.3 + np.array((92, 44, 22)) * 0.7
    if dirt_bottom > 0:
        ys = np.nonzero(A)[0]
        if len(ys):
            y0, y1 = ys.min(), ys.max()
            t = np.clip((np.arange(h) - (y1 - (y1 - y0) * 0.35)) / max(1, (y1 - y0) * 0.35), 0, 1)
            a[..., :3] *= (1 - dirt_bottom * t)[:, None, None]
    img2 = Image.fromarray(clamp8(a), 'RGBA')
    if leaves > 0:
        rng = random.Random(seed)
        arr = np.array(img2)
        top = np.zeros((h, w), bool)
        top[1:] = (arr[1:, :, 3] > 0) & (arr[:-1, :, 3] == 0)
        ys, xs = np.nonzero(arr[..., 3] > 0)
        for _ in range(int(len(xs) * leaves)):
            i = rng.randrange(len(xs))
            arr[ys[i], xs[i], :3] = rng.choice(LEAF_ORANGE)
        img2 = Image.fromarray(arr, 'RGBA')
    return img2


# ------------------------------------------------------- 3/4 block renderer --
V = lambda *a: np.array(a, float)


def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def shade(col, n, amb=0.58, dif=0.55):
    k = amb + dif * max(0.0, float(np.dot(n, LIGHT)))
    return tuple(int(max(0, min(255, c * k))) for c in col)


def hull(pts):
    pts = sorted(set((round(x, 3), round(y, 3)) for x, y in pts))
    if len(pts) < 3:
        return pts
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]


class Scene:
    """World: X right, Y toward camera, Z up. origin = pixel of world (0,0,0)."""

    def __init__(self, w, h, origin):
        self.w, self.h = w, h
        self.o = origin
        self.items = []

    def P(self, p):
        return (self.o[0] + p[0], self.o[1] + p[1] * YK - p[2])

    def box(self, c, size, col, edge=True, face_cols=None, bias=0.0, ax=None):
        """axis-aligned (or ax=(ex,ey,ez)) box. size = half extents."""
        c = np.asarray(c, float)
        ex, ey, ez = ax if ax else (V(1, 0, 0), V(0, 1, 0), V(0, 0, 1))
        hx, hy, hz = size
        cs = []
        for i in range(8):
            cs.append(c + ex * (hx if i & 4 else -hx) + ey * (hy if i & 2 else -hy) + ez * (hz if i & 1 else -hz))
        faces = []
        for fi, f in enumerate(FACES):
            q = [cs[i] for i in f]
            n = norm(np.cross(q[1] - q[0], q[3] - q[0]))
            fc = np.mean(q, axis=0)
            if np.dot(n, fc - c) < 0:
                n = -n
            if np.dot(n, CAM) > 0.02:
                colf = col
                if face_cols:
                    key = 'top' if n[2] > 0.7 else ('front' if n[1] > 0.7 else ('side'))
                    colf = face_cols.get(key, col)
                faces.append((float(np.dot(fc, CAM)), [self.P(p) for p in q], shade(colf, n), n))
        faces.sort(key=lambda t: t[0])
        ol = hull([self.P(p) for p in cs]) if edge else None
        self.items.append((float(np.dot(c, CAM)) + bias, 'block', (faces, ol, tuple(int(v * 0.45) for v in col))))
        return faces

    def hexa(self, cs, col, face_cols=None, edge=True, bias=0.0):
        """arbitrary 8-corner solid; face_cols: {face_index: colour} (FACES order:
        0 x-, 1 x+, 2 y-, 3 y+, 4 z-, 5 z+)."""
        cs = [np.asarray(p, float) for p in cs]
        c = np.mean(cs, axis=0)
        faces = []
        for fi, f in enumerate(FACES):
            q = [cs[i] for i in f]
            n = norm(np.cross(q[1] - q[0], q[3] - q[0]))
            fc = np.mean(q, axis=0)
            if np.dot(n, fc - c) < 0:
                n = -n
            if np.dot(n, CAM) > 0.02:
                colf = (face_cols or {}).get(fi, col)
                faces.append((float(np.dot(fc, CAM)), [self.P(p) for p in q], shade(colf, n), n))
        faces.sort(key=lambda t: t[0])
        ol = hull([self.P(p) for p in cs]) if edge else None
        self.items.append((float(np.dot(c, CAM)) + bias, 'block', (faces, ol, tuple(int(v * 0.45) for v in col))))

    def cyl(self, c, r, hz, col, bias=0.0, edge=True, bands=()):
        """vertical cylinder standing at c (base centre), radius r, height hz."""
        c = np.asarray(c, float)
        self.items.append((float(np.dot(c + V(0, r * 0.2, hz / 2), CAM)) + bias, 'cyl', (c, r, hz, col, edge, bands)))

    def hcyl(self, a, b, r, col, bias=0.0, edge=True):
        self.items.append((float(np.dot((np.asarray(a) + np.asarray(b)) / 2, CAM)) + bias, 'hcyl',
                           (np.asarray(a, float), np.asarray(b, float), r, col, edge)))

    def poly(self, pts3, col, bias=0.0):
        cen = np.mean(pts3, axis=0)
        self.items.append((float(np.dot(cen, CAM)) + bias, 'poly', ([self.P(p) for p in pts3], col)))

    def line(self, pts3, col, width=1, bias=0.0):
        cen = np.mean(pts3, axis=0)
        self.items.append((float(np.dot(cen, CAM)) + bias, 'line', ([self.P(p) for p in pts3], col, width)))

    def px(self, p3, col, bias=0.0):
        self.items.append((float(np.dot(p3, CAM)) + bias, 'px', (self.P(p3), col)))

    def ball(self, c, r, col, bias=0.0):
        self.items.append((float(np.dot(c, CAM)) + bias, 'ball', (self.P(c), r, col)))

    def render(self, outline=True):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for depth, kind, pl in sorted(self.items, key=lambda t: t[0]):
            if kind == 'block':
                faces, ol, oc = pl
                for _, q, col, n in faces:
                    d.polygon(q, fill=col + (255,))
                if ol and len(ol) >= 3:
                    d.polygon(ol, outline=oc + (255,))
            elif kind == 'cyl':
                c, r, hz, col, edge, bands = pl
                x0, y0 = self.P(c)
                x1, y1 = self.P(c + V(0, 0, hz))
                ry = r * YK
                # body with horizontal shading ramp (lit left)
                for xi in range(int(math.floor(x0 - r)), int(math.ceil(x0 + r)) + 1):
                    t = (xi + 0.5 - x0) / r
                    if abs(t) > 1:
                        continue
                    k = 0.62 + 0.5 * max(0.0, -0.55 * t + 0.35 * math.sqrt(max(0, 1 - t * t)) + 0.35)
                    cc = tuple(int(min(255, v * k)) for v in col)
                    yy = ry * math.sqrt(max(0, 1 - t * t))
                    d.line([(xi, y1), (xi, y0 + yy)], fill=cc + (255,))
                for (bz, bcol) in bands:
                    by = self.P(c + V(0, 0, bz))[1]
                    for xi in range(int(math.floor(x0 - r)), int(math.ceil(x0 + r)) + 1):
                        t = (xi + 0.5 - x0) / r
                        if abs(t) <= 1:
                            yy = ry * math.sqrt(max(0, 1 - t * t))
                            d.point((xi, by + yy), fill=bcol + (255,))
                top = tuple(int(min(255, v * 1.12)) for v in col)
                d.ellipse([x1 - r, y1 - ry, x1 + r, y1 + ry], fill=top + (255,))
                if r > 2 and ry > 1.6:
                    d.ellipse([x1 - r + 1, y1 - ry + 1, x1 + r - 1, y1 + ry - 0.5], outline=tuple(int(v * 0.7) for v in col) + (255,))
                if edge:
                    oc = tuple(int(v * 0.45) for v in col) + (255,)
                    d.line([(x0 - r, y1), (x0 - r, y0)], fill=oc)
                    d.line([(x0 + r, y1), (x0 + r, y0)], fill=oc)
            elif kind == 'hcyl':
                a, b, r, col, edge = pl
                pa, pb = self.P(a), self.P(b)
                dx, dy = pb[0] - pa[0], pb[1] - pa[1]
                L = math.hypot(dx, dy) or 1
                nx, ny = -dy / L, dx / L
                if ny > 0:
                    nx, ny = -nx, -ny
                for k in range(-int(r), int(r) + 1):
                    t = k / max(1, r)
                    kk = 0.64 + 0.5 * max(0, 0.5 + 0.5 * t)
                    cc = tuple(int(min(255, v * kk)) for v in col)
                    d.line([(pa[0] - nx * k, pa[1] - ny * k), (pb[0] - nx * k, pb[1] - ny * k)], fill=cc + (255,), width=2)
                d.ellipse([pb[0] - r * 0.6, pb[1] - r, pb[0] + r * 0.6, pb[1] + r], fill=tuple(int(v * 0.8) for v in col) + (255,))
            elif kind == 'poly':
                q, col = pl
                d.polygon(q, fill=col + (255,))
            elif kind == 'line':
                q, col, wd = pl
                d.line(q, fill=col + (255,), width=wd)
            elif kind == 'px':
                (x, y), col = pl
                d.point((int(x), int(y)), fill=col + (255,))
            elif kind == 'ball':
                (x, y), r, col = pl
                d.ellipse([x - r, y - r, x + r, y + r], fill=tuple(int(v * 0.66) for v in col) + (255,))
                r2 = r - 0.8
                d.ellipse([x - r2 - 0.6, y - r2 - 0.6, x + r2 - 0.6, y + r2 - 0.6], fill=col + (255,))
                r3 = r * 0.4
                d.ellipse([x - r * 0.4 - r3, y - r * 0.45 - r3, x - r * 0.4 + r3, y - r * 0.45 + r3],
                          fill=tuple(min(255, int(v * 1.15)) for v in col) + (255,))
        return outline_img(im) if outline else im


def fit_canvas(img, w, h, anchor='bottom', pad=1):
    """Crop to content and paste into a WxH canvas (bottom- or centre-anchored)."""
    bb = img.getbbox()
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    if not bb:
        return out
    c = img.crop(bb)
    if c.width > w - 2 * pad or c.height > h - 2 * pad:
        s = min((w - 2 * pad) / c.width, (h - 2 * pad) / c.height)
        c = c.resize((max(1, int(c.width * s)), max(1, int(c.height * s))), Image.NEAREST)
    x = (w - c.width) // 2
    y = h - pad - c.height if anchor == 'bottom' else (h - c.height) // 2
    out.alpha_composite(c, (x, y))
    return out
