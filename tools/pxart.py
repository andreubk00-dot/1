"""OSTATOK 0.74 pixel-art engine.

Items are described once in their own design coordinates and rendered at any
target size / rotation. Every part gets automatic top-left light, bottom-right
shadow, optional grime noise, and the finished sprite gets a coloured dark
outline — the same visual language as the reference sheet.
"""
import math
import random
import numpy as np
from PIL import Image, ImageDraw

OUTLINE = (18, 16, 14)


def mul(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c[:3])


def mix(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))


class Canvas:
    """Draw in design units; `xf` maps design points to pixel points."""

    def __init__(self, w, h, design_box, pad=1, angle=0.0, flip_y=False,
                 squash_y=1.0, origin=None, scale=None, seed=7):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)
        self.rng = random.Random(seed)
        x0, y0, x1, y1 = design_box
        if scale is None:
            scale = min((w - 2 * pad) / max(1e-6, x1 - x0), (h - 2 * pad) / max(1e-6, y1 - y0))
        self.s = scale
        self.angle = angle
        self.flip_y = flip_y
        self.squash_y = squash_y
        if origin is None:
            # centre the design box
            self.cx, self.cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
            self.px, self.py = w / 2.0, h / 2.0
        else:
            # origin = (design_x, design_y, pixel_x, pixel_y)
            self.cx, self.cy, self.px, self.py = origin
        self.ca, self.sa = math.cos(angle), math.sin(angle)

    # -- geometry -------------------------------------------------------
    def xf(self, p):
        x, y = (p[0] - self.cx) * self.s, (p[1] - self.cy) * self.s
        if self.flip_y:
            y = -y
        rx = x * self.ca - y * self.sa
        ry = (x * self.sa + y * self.ca) * self.squash_y
        return (self.px + rx, self.py + ry)

    def _mask_from(self, fn):
        im = Image.new('L', (self.w, self.h), 0)
        fn(ImageDraw.Draw(im))
        return np.array(im) > 0

    def poly_mask(self, pts):
        q = [self.xf(p) for p in pts]
        return self._mask_from(lambda d: d.polygon(q, fill=255))

    def rect_mask(self, x0, y0, x1, y1):
        return self.poly_mask([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])

    def ellipse_mask(self, cx, cy, rx, ry, n=20):
        pts = [(cx + rx * math.cos(t * 2 * math.pi / n), cy + ry * math.sin(t * 2 * math.pi / n)) for t in range(n)]
        return self.poly_mask(pts)

    def line_mask(self, pts, width=1.0):
        q = [self.xf(p) for p in pts]
        wpx = max(1, int(round(width * self.s)))
        return self._mask_from(lambda d: d.line(q, fill=255, width=wpx))

    # -- painting -------------------------------------------------------
    def fill(self, m, col, shade=True, hl=1.28, sh=0.66, noise=0.0, grad=0.0, alpha=255):
        if not m.any():
            return m
        base = np.array(col[:3], float)
        out = np.tile(base, (self.h, self.w, 1))
        if grad:
            ys = np.nonzero(m)[0]
            y0, y1 = ys.min(), max(ys.max(), ys.min() + 1)
            t = (np.arange(self.h)[:, None] - y0) / (y1 - y0)
            out = out * (1 + grad * (0.5 - t))[..., None]
        if noise:
            n = np.array([[self.rng.uniform(-noise, noise) for _ in range(self.w)] for _ in range(self.h)])
            out = out * (1 + n)[..., None]
        if shade:
            up = np.zeros_like(m); up[1:] = m[:-1]
            dn = np.zeros_like(m); dn[:-1] = m[1:]
            lf = np.zeros_like(m); lf[:, 1:] = m[:, :-1]
            rt = np.zeros_like(m); rt[:, :-1] = m[:, 1:]
            top = m & ~up
            bot = m & ~dn
            left = m & ~lf
            right = m & ~rt
            thin = top & bot
            k = np.ones((self.h, self.w))
            k[right & ~thin] = (1 + sh) / 2
            k[left & ~thin] = (1 + hl) / 2 + 0.02
            k[bot & ~thin] = sh
            k[top & ~thin] = hl
            k[thin] = (1 + hl) / 2
            out = out * k[..., None]
        out = np.clip(out, 0, 255).astype(np.uint8)
        self.a[m, :3] = out[m]
        self.a[m, 3] = alpha
        return m

    def part(self, pts, col, **kw):
        return self.fill(self.poly_mask(pts), col, **kw)

    def rect(self, x0, y0, x1, y1, col, **kw):
        return self.fill(self.rect_mask(x0, y0, x1, y1), col, **kw)

    def ell(self, cx, cy, rx, ry, col, **kw):
        return self.fill(self.ellipse_mask(cx, cy, rx, ry), col, **kw)

    def line(self, pts, col, width=1.0, **kw):
        kw.setdefault('shade', False)
        return self.fill(self.line_mask(pts, width), col, **kw)

    def dot(self, x, y, col, only_on_body=True):
        px, py = self.xf((x, y))
        ix, iy = int(math.floor(px)), int(math.floor(py))
        if 0 <= ix < self.w and 0 <= iy < self.h:
            if only_on_body and self.a[iy, ix, 3] == 0:
                return
            self.a[iy, ix, :3] = col[:3]
            self.a[iy, ix, 3] = 255

    def tint_region(self, m, k):
        sel = m & (self.a[..., 3] > 0)
        self.a[sel, :3] = np.clip(self.a[sel, :3].astype(float) * k, 0, 255).astype(np.uint8)

    # -- finishing ------------------------------------------------------
    def outline(self, col=OUTLINE, selective=0.34):
        A = self.a[..., 3] > 0
        grow = np.zeros_like(A)
        grow[1:] |= A[:-1]; grow[:-1] |= A[1:]; grow[:, 1:] |= A[:, :-1]; grow[:, :-1] |= A[:, 1:]
        edge = grow & ~A
        ys, xs = np.nonzero(edge)
        for y, x in zip(ys, xs):
            acc = []
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < self.h and 0 <= xx < self.w and A[yy, xx]:
                    acc.append(self.a[yy, xx, :3].astype(float))
            nb = np.mean(acc, axis=0)
            c = np.array(col, float) * (1 - selective) + nb * 0.35 * selective
            self.a[y, x, :3] = np.clip(c, 0, 255).astype(np.uint8)
            self.a[y, x, 3] = 255
        return self

    def image(self):
        return Image.fromarray(self.a, 'RGBA')


def trim(img):
    bb = img.getbbox()
    return img.crop(bb) if bb else img
