"""OSTATOK 0.75 survivor renderer.

The survivor is a small 3D rig (boxes + spheres) posed per frame and projected
into a 3/4 top-down pixel sprite. Weapons are parented to the hand bones, so the
gun is in the hands in every direction and every frame by construction.

World axes: X = screen right, Y = toward the camera (screen down on the ground),
Z = up.  Units are sprite pixels at the 2x sheet density (128px cells).
"""
import math
import numpy as np
from PIL import Image, ImageDraw

CELL = 128
GROUND = (64.0, 92.0)            # pixel of the character's ground origin
YK = 0.55                        # ground-plane compression of the 3/4 camera
CAM = np.array([0.0, 1.0, YK]); CAM /= np.linalg.norm(CAM)
LIGHT = np.array([-0.45, 0.30, 0.84]); LIGHT /= np.linalg.norm(LIGHT)
OUTLINE = (20, 18, 16)

V = lambda *a: np.array(a, float)


def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def proj(p):
    return (GROUND[0] + p[0], GROUND[1] + p[1] * YK - p[2])


def shade(col, n, amb=0.60, dif=0.52):
    k = amb + dif * max(0.0, float(np.dot(n, LIGHT)))
    k = round(k * 12) / 12.0
    return tuple(int(max(0, min(255, c * k))) for c in col)


def darker(col, k):
    return tuple(int(c * k) for c in col)


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
    def __init__(self):
        self.items = []     # (depth, kind, payload)

    # --- primitives ------------------------------------------------------
    def block(self, corners, col, edge=True, detail=False):
        """corners: 8 points, index bits = (a, b, c) along three axes."""
        cen = np.mean(corners, axis=0)
        faces = []
        for f in FACES:
            q = [corners[i] for i in f]
            n = norm(np.cross(q[1] - q[0], q[3] - q[0]))
            fc = np.mean(q, axis=0)
            if np.dot(n, fc - cen) < 0:
                n = -n
            if np.dot(n, CAM) > 0.02:
                faces.append((float(np.dot(fc, CAM)), [proj(p) for p in q], shade(col, n)))
        faces.sort(key=lambda t: t[0])
        outline = hull([proj(p) for p in corners]) if edge else None
        self.items.append((float(np.dot(cen, CAM)), 'block', (faces, outline, darker(col, 0.52))))

    def box(self, c, ax, ay, az, hx, hy, hz, col, **kw):
        ax, ay, az = norm(ax), norm(ay), norm(az)
        cs = []
        for i in range(8):
            sx = hx if i & 4 else -hx
            sy = hy if i & 2 else -hy
            sz = hz if i & 1 else -hz
            cs.append(c + ax * sx + ay * sy + az * sz)
        self.block(cs, col, **kw)

    def limb(self, a, b, wa, wb, col, side_hint, **kw):
        """Tapered square-section bone from a to b (half widths wa, wb)."""
        u = norm(b - a)
        v = np.cross(u, V(0, 0, 1))
        if np.linalg.norm(v) < 0.2:
            v = side_hint
        v = norm(v - u * np.dot(v, u))
        w = norm(np.cross(v, u))
        cs = []
        for i in range(8):
            base, wd = (b, wb) if i & 4 else (a, wa)
            cs.append(base + v * (wd if i & 2 else -wd) + w * (wd if i & 1 else -wd))
        self.block(cs, col, **kw)

    def capsule(self, a, b, ra, rb, col, bias=0.0, edge=True):
        """Rounded limb with cylindrical shading (lit side / shadow side)."""
        a, b = np.asarray(a, float), np.asarray(b, float)
        dep = float(np.dot((a + b) / 2, CAM)) + bias
        self.items.append((dep, 'caps', (proj(a), proj(b), ra, rb, col, edge)))

    def ball(self, c, r, col, bias=0.0):
        self.items.append((float(np.dot(c, CAM)) + bias, 'ball', (proj(c), r, col)))

    def flat(self, pts3, col, bias=0.0):
        cen = np.mean(pts3, axis=0)
        self.items.append((float(np.dot(cen, CAM)) + bias, 'poly', ([proj(p) for p in pts3], col)))

    def pixel(self, p, col, bias=0.0):
        self.items.append((float(np.dot(p, CAM)) + bias, 'px', (proj(p), col)))

    def flash(self, p, direction):
        self.items.append((1e6, 'flash', (proj(p), direction)))

    # --- rasterise -------------------------------------------------------
    def render(self):
        im = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for depth, kind, pl in sorted(self.items, key=lambda t: t[0]):
            if kind == 'block':
                faces, outline, oc = pl
                for _, q, col in faces:
                    d.polygon(q, fill=col + (255,))
                if outline and len(outline) >= 3:
                    d.polygon(outline, outline=oc + (255,))
            elif kind == 'caps':
                pa, pb, ra, rb, col, edge = pl
                def hullc(pa, pb, ra, rb, ox=0.0, oy=0.0):
                    pts = []
                    for k in range(14):
                        t = k * math.pi * 2 / 14
                        pts.append((pa[0] + ox + ra * math.cos(t), pa[1] + oy + ra * math.sin(t)))
                        pts.append((pb[0] + ox + rb * math.cos(t), pb[1] + oy + rb * math.sin(t)))
                    return hull(pts)
                d.polygon(hullc(pa, pb, ra, rb), fill=darker(col, 0.66) + (255,))
                d.polygon(hullc(pa, pb, max(0.6, ra - 0.8), max(0.6, rb - 0.8), -0.55, -0.6), fill=col + (255,))
                d.polygon(hullc(pa, pb, ra * 0.38, rb * 0.38, -ra * 0.42, -ra * 0.46),
                          fill=tuple(min(255, int(c * 1.14)) for c in col) + (255,))
                if edge:
                    d.polygon(hullc(pa, pb, ra, rb), outline=darker(col, 0.45) + (255,))
            elif kind == 'ball':
                (x, y), r, col = pl
                d.ellipse([x - r, y - r, x + r, y + r], fill=darker(col, 0.62) + (255,))
                r2 = r - 0.8
                d.ellipse([x - r2 - 0.6, y - r2 - 0.6, x + r2 - 0.6, y + r2 - 0.6], fill=col + (255,))
                r3 = r * 0.42
                hx, hy = x - r * 0.38, y - r * 0.42
                d.ellipse([hx - r3, hy - r3, hx + r3, hy + r3], fill=tuple(min(255, int(c * 1.16)) for c in col) + (255,))
            elif kind == 'poly':
                q, col = pl
                d.polygon(q, fill=col + (255,))
            elif kind == 'px':
                (x, y), col = pl
                d.point((int(x), int(y)), fill=col + (255,))
            elif kind == 'flash':
                (x, y), dr = pl
                dx, dy = dr
                pts = []
                for k, (L, W) in enumerate(((0, 2.2), (3, 3.2), (6, 1.8), (9, 0.2))):
                    pts.append((x + dx * L - dy * W, y + dy * L + dx * W))
                pts2 = [(x + dx * L + dy * W, y + dy * L - dx * W) for L, W in ((0, 2.2), (3, 3.2), (6, 1.8), (9, 0.2))]
                d.polygon(pts + pts2[::-1], fill=(250, 150, 40, 255))
                inner = [(x + dx * L - dy * W * 0.5, y + dy * L + dx * W * 0.5) for L, W in ((0, 2.0), (3, 2.6), (5.5, 0.4))]
                inner2 = [(x + dx * L + dy * W * 0.5, y + dy * L - dx * W * 0.5) for L, W in ((0, 2.0), (3, 2.6), (5.5, 0.4))]
                d.polygon(inner + inner2[::-1], fill=(255, 238, 150, 255))
                for s in (-1, 1):
                    d.line([(x + dx * 2, y + dy * 2), (x + dx * 3 - dy * 4.5 * s, y + dy * 3 + dx * 4.5 * s)], fill=(255, 200, 80, 255))
        a = np.array(im)
        A = a[..., 3] > 0
        g = np.zeros_like(A)
        g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
        e = g & ~A
        a[e] = OUTLINE + (255,)
        return Image.fromarray(a, 'RGBA')


def save_png(im, path):
    """Exact (lossless) palette PNG when the sheet has <=256 colours, else RGBA."""
    a = np.array(im.convert('RGBA'))
    a[a[..., 3] == 0] = 0
    key = (a[..., 0].astype(np.uint32) << 24) | (a[..., 1].astype(np.uint32) << 16) | \
          (a[..., 2].astype(np.uint32) << 8) | a[..., 3].astype(np.uint32)
    uniq, inv = np.unique(key.ravel(), return_inverse=True)
    if len(uniq) > 256:
        Image.fromarray(a, 'RGBA').save(path, optimize=True)
        return len(uniq)
    pal = [((u >> 24) & 255, (u >> 16) & 255, (u >> 8) & 255, u & 255) for u in uniq.tolist()]
    out = Image.fromarray(inv.reshape(a.shape[:2]).astype(np.uint8), 'P')
    out.putpalette([v for c in pal for v in c[:3]] + [0] * (768 - 3 * len(pal)))
    out.save(path, optimize=True, transparency=bytes([c[3] for c in pal]))
    return len(uniq)
