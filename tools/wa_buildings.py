"""OSTATOK 1.22-dev4 faction settlement buildings (32 models, 8 per faction).

Every model is built on the game's building contract:
  * footprint W x D (world px) centred on the building node, south wall at y = +D/2;
  * south facade height H (the game lifts the roof by H);
  * one entrance on the south wall at door_x, opening 20 x 32 px (the game draws
    the swinging leaf into it);
  * the render is split at the top edge of the south wall into a ROOF layer and a
    FACADE layer so the existing roof/facade fading keeps working.
"""
import math
import random
import numpy as np
from PIL import Image, ImageDraw
from wa_town import Model, Face, V, MAT, render, dark, mix, shade, DENS

DOOR_W, DOOR_H = 20.0, 32.0

# --------------------------------------------------------------------------- DSL --
class B:
    def __init__(self, mid, W, D, H, wall, seed, archetype, plinth=(96, 94, 88), plinth_h=5.0):
        self.id = mid
        self.W, self.D, self.H = float(W), float(D), float(H)
        self.m = Model(W, D, H, seed)
        self.rng = random.Random(seed)
        self.seed = seed
        self.archetype = archetype
        self.x0, self.x1 = -W / 2, W / 2
        self.y0, self.y1 = -D / 2, D / 2
        self.front = self.m.box(self.x0, self.x1, self.y0, self.y1, 0, H, wall, cap=False)['front']
        self.front_faces = [self.front]
        self.wall = wall
        if plinth is not None:
            self.m.rect(self.front, 0, 0, W, plinth_h, plinth)
            self.m.rect(self.front, 0, plinth_h - 0.8, W, 0.8, dark(plinth, 0.75))
        self.door_x = 0.0
        self.roof_rise = 0.0
        self.roof_fn = lambda x, y: self.H
        self.sign = None
        self.grime, self.rust, self.moss = 0.10, 0.0, 0.0
        self.opening_xs = []

    # --- walls ---------------------------------------------------------------
    def fu(self, x):
        """world x -> u on the main front face"""
        return x - self.x0

    def corner_boards(self, col, w=3.0):
        for u in (0, self.W - w):
            self.m.rect(self.front, u, 0, w, self.H, col)

    def band(self, z, h, col):
        self.m.rect(self.front, 0, z, self.W, h, col)

    def eave_shadow(self, h=6.0, alpha=90):
        self.m.front_shadow = True
        self.front.decals.append(('shade', dict(u=0, v=self.H - h, w=self.W, h=h, alpha=alpha)))

    # --- roofs ---------------------------------------------------------------
    def gable(self, mat, rise, over=6.0, over_x=5.0, ridge_col=None):
        s, n = self.m.gable_x(self.x0, self.x1, self.y0, self.y1, self.H, rise, mat, over=over, over_x=over_x, bias=100)
        self.roof_rise = rise
        yc = 0.0
        half = self.D / 2
        self.roof_fn = lambda x, y: self.H + rise * max(0.0, 1 - abs(y - yc) / half)
        rc = ridge_col or dark(MAT[mat][0], 0.8)
        self.m.line3([V(self.x0 - over_x, 0, self.H + rise + 0.6), V(self.x1 + over_x, 0, self.H + rise + 0.6)], rc, 2, bias=150)
        # fascia board along the south eave
        za = self.H - over * rise / half
        self.m.line3([V(self.x0 - over_x, self.y1 + over, za), V(self.x1 + over_x, self.y1 + over, za)], dark(MAT[mat][0], 0.55), 2, bias=150)
        self.eave_shadow(7.0, 100)
        return s, n

    def hip(self, mat, rise, over=6.0):
        self.m.hip(self.x0, self.x1, self.y0, self.y1, self.H, rise, mat, over=over, bias=100)
        self.roof_rise = rise
        half = self.D / 2
        self.roof_fn = lambda x, y: self.H + rise * max(0.0, 1 - abs(y) / half)
        self.eave_shadow(7.0, 100)

    def flat(self, mat='tar', parapet='concrete_s', ph=5.0, inset=0.0):
        m = self.m
        x0, x1, y0, y1, H = self.x0, self.x1, self.y0, self.y1, self.H
        m.add(Face(V(x0, y1, H), V(1, 0, 0), V(0, -1, 0), x1 - x0, y1 - y0, MAT[mat][0], MAT[mat][1], 100))
        if parapet:
            pc = MAT[parapet]
            t = 3.0
            # south parapet shows its face on the facade and its cap on the roof
            m.box(x0, x1, y1 - t, y1, H, H + ph, parapet, bias=105)
            m.box(x0, x1, y0, y0 + t, H, H + ph, parapet, bias=101)
            m.box(x0, x0 + t, y0, y1, H, H + ph, parapet, bias=102)
            m.box(x1 - t, x1, y0, y1, H, H + ph, parapet, bias=102)
        self.roof_rise = ph
        self.roof_fn = lambda x, y: H
        # flat roof life: tar patches, puddles, a hatch and vent boxes
        r = self.rng
        for _ in range(3):
            w, d = r.uniform(18, 40), r.uniform(10, 24)
            x = r.uniform(x0 + w / 2 + 6, x1 - w / 2 - 6)
            y = r.uniform(y0 + d / 2 + 6, y1 - d / 2 - 6)
            m.poly3([V(x - w / 2, y + d / 2, H + 0.2), V(x + w / 2, y + d / 2, H + 0.2), V(x + w / 2, y - d / 2, H + 0.2), V(x - w / 2, y - d / 2, H + 0.2)],
                    dark(MAT[mat][0], r.choice([0.82, 1.12])), 'none', bias=103, outline=False)
        for _ in range(2):
            x, y = r.uniform(x0 + 20, x1 - 20), r.uniform(y0 + 16, y1 - 16)
            pts = [V(x + math.cos(a) * r.uniform(7, 12), y + math.sin(a) * r.uniform(4, 7), H + 0.3) for a in np.linspace(0, 2 * math.pi, 12, endpoint=False)]
            m.poly3(pts, (70, 84, 92), 'none', bias=103.5, outline=False)
        hx, hy = x0 + (x1 - x0) * 0.72, y0 + (y1 - y0) * 0.35
        m.box(hx - 7, hx + 7, hy - 7, hy + 7, H, H + 4, ((104, 106, 102), 'none'), bias=190)
        for k in range(2):
            vx, vy = r.uniform(x0 + 16, x1 - 16), r.uniform(y0 + 14, y1 - 18)
            m.box(vx - 5, vx + 5, vy - 4, vy + 4, H, H + 6, ((128, 130, 126), 'none'), bias=190)

    def arch(self, mat, over=3.0):
        r = self.W / 2
        zs = 0.62
        front = self.m.arch_y(self.x0, self.x1, self.y0, self.y1, self.H, mat, segs=14, bias=100, zs=zs)
        self.roof_rise = r * zs
        self.roof_fn = lambda x, y: self.H + zs * math.sqrt(max(0.0, r * r - x * x))
        # front end-wall of the arch (semicircle) as a polygon on the facade plane
        col = MAT[self.wall][0]
        pts = [V(self.x0, self.y1, self.H)] + front + [V(self.x1, self.y1, self.H)]
        self.m.poly3(pts, col, MAT[self.wall][1], bias=90,
                     frame=(V(self.x0, self.y1, self.H), V(1, 0, 0), V(0, 0, 1)))
        return front

    def sawtooth(self, mat, glass_mat='glass', teeth=3, rise=18.0):
        m = self.m
        H = self.H
        depth = self.D / teeth
        for i in range(teeth):
            ys = self.y1 - i * depth
            yn = ys - depth
            # sloped solid roof rising to the north, vertical glazing on the north side (hidden),
            # and a lit vertical glazing band facing south on the next tooth
            m.poly3([V(self.x0 - 3, ys + (2 if i == 0 else 0), H), V(self.x1 + 3, ys + (2 if i == 0 else 0), H),
                     V(self.x1 + 3, yn, H + rise), V(self.x0 - 3, yn, H + rise)], MAT[mat][0], MAT[mat][1], bias=100 + i,
                    frame=(V(self.x0 - 3, ys, H), V(1, 0, 0), np.array([0, -depth, rise]) / math.hypot(depth, rise)))
            if i < teeth - 1:
                m.poly3([V(self.x0 - 3, yn, H), V(self.x1 + 3, yn, H), V(self.x1 + 3, yn, H + rise), V(self.x0 - 3, yn, H + rise)],
                        MAT[glass_mat][0], MAT[glass_mat][1], bias=100 + i + 0.5,
                        frame=(V(self.x0 - 3, yn, H), V(1, 0, 0), V(0, 0, 1)))
        self.roof_rise = rise
        self.roof_fn = lambda x, y: H + rise * 0.5
        self.eave_shadow(4.0, 70)

    def gambrel(self, mat, rise1, rise2, over=5.0):
        """barn roof: steep lower slopes + flatter upper slopes (ridge along x)."""
        m = self.m
        H = self.H
        half = self.D / 2
        yb = half * 0.55
        xa, xb = self.x0 - 4, self.x1 + 4
        col, pat = MAT[mat]
        # south lower, south upper, north upper, north lower
        segs = [((self.y1 + over, H - 2), (yb, H + rise1)), ((yb, H + rise1), (0, H + rise1 + rise2)),
                ((0, H + rise1 + rise2), (-yb, H + rise1)), ((-yb, H + rise1), (self.y0 - over, H - 2))]
        for i, ((ya, za), (yc, zc)) in enumerate(segs):
            v = np.array([0, yc - ya, zc - za]); L = np.linalg.norm(v); v = v / L
            c = col if i < 2 else dark(col, 0.9)
            m.add(Face(V(xa, ya, za), V(1, 0, 0), v, xb - xa, L, c, pat, 100 + (2 - abs(1.5 - i))))
        self.roof_rise = rise1 + rise2
        self.roof_fn = lambda x, y: H + rise1 + rise2 * max(0.0, 1 - abs(y) / yb) if abs(y) < yb else H + rise1 * (1 - (abs(y) - yb) / (half - yb))
        self.eave_shadow(6.0, 100)

    # --- openings ---------------------------------------------------------------
    def door(self, x, kind='door', frame=(58, 50, 42), canopy=None, steps=True, lamp=True):
        self.door_x = float(x)
        u = self.fu(x) - DOOR_W / 2
        self.m.door(self.front, u, DOOR_W, DOOR_H, frame_col=frame)
        self.opening_xs.append((x, DOOR_W / 2 + 6))
        if canopy:
            mat, depth = canopy
            z = DOOR_H + 5
            col = MAT[mat][0]
            self.m.poly3([V(x - 17, self.y1 + depth, z - 3), V(x + 17, self.y1 + depth, z - 3), V(x + 17, self.y1, z + 2), V(x - 17, self.y1, z + 2)],
                         col, MAT[mat][1], bias=60, frame=(V(x - 17, self.y1 + depth, z - 3), V(1, 0, 0), norm3(V(0, -depth, 5))))
            self.m.box(x - 17, x + 17, self.y1 + depth - 1.2, self.y1 + depth, z - 5, z - 3, mat, bias=61, cap=False)
        if lamp:
            self.m.rect(self.front, self.fu(x) + DOOR_W / 2 + 3, DOOR_H + 1, 3, 3, (60, 58, 54))
            self.m.rect(self.front, self.fu(x) + DOOR_W / 2 + 3.5, DOOR_H - 1.5, 2, 2.5, (250, 214, 140), lit_shade=False)

    def gate(self, x, w, h, col=(96, 100, 100), kind='shutter'):
        u = self.fu(x) - w / 2
        self.m.door(self.front, u, w, h, col=col, frame_col=(52, 54, 54), kind=kind)
        self.opening_xs.append((x, w / 2 + 4))

    def windows(self, v, w, h, step, style='frame', frame=(186, 182, 168), glass=(50, 64, 72), x_from=None, x_to=None,
                shutters=None, bars=False, lit_chance=0.0, skip=(), streaks=True, sill=True, avoid_openings=True):
        a = (x_from if x_from is not None else self.x0 + 10)
        b = (x_to if x_to is not None else self.x1 - 10)
        n = max(1, int((b - a + step - w) // step))
        total = (n - 1) * step + w
        start = a + ((b - a) - total) / 2
        k = 0
        for i in range(n):
            x = start + i * step
            cx = x + w / 2
            if i in skip:
                continue
            if avoid_openings and any(abs(cx - ox) < ow + w / 2 for ox, ow in self.opening_xs):
                continue
            lit = self.rng.random() < lit_chance
            self.m.window(self.front, self.fu(x), v, w, h, style=style, frame_col=frame, glass=glass, shutters=shutters,
                          bars=bars, lit=lit, sill=sill)
            if streaks and self.rng.random() < 0.55:
                for s in range(self.rng.randint(1, 3)):
                    self.front.decals.append(('streak', dict(u=self.fu(x) + self.rng.uniform(1, w - 1), v=v - 2, h=self.rng.uniform(3, 9))))
            k += 1
        return k

    def signboard(self, x, z, w, h=8.0, col=(40, 44, 42), border=(150, 140, 110)):
        u = self.fu(x) - w / 2
        self.m.rect(self.front, u, z, w, h, col, border=border, lit_shade=False)
        self.sign = (x, z, w, h)

    # --- attachments ------------------------------------------------------------
    def roof_z(self, x, y):
        return self.roof_fn(x, y)

    def chimney(self, x, y, h=16.0, w=8.0, mat='brick', smoke=False, cap_col=(70, 70, 68)):
        z = self.roof_z(x, y)
        self.m.box(x - w / 2, x + w / 2, y - w / 2, y + w / 2, z - 6, z + h, mat, bias=200)
        self.m.box(x - w / 2 - 1, x + w / 2 + 1, y - w / 2 - 1, y + w / 2 + 1, z + h, z + h + 2, (cap_col, 'none'), bias=201)
        if smoke:
            for k, (dx, dz, r) in enumerate([(1, 6, 3.0), (3, 13, 4.0), (2, 21, 5.0)]):
                self.m.cyl(x + dx, y, z + h + dz, z + h + dz + r * 1.2, r, ((150, 150, 146), 'none'), segs=8, bias=260 + k)

    def pipe(self, x, y, h=14.0, r=2.2, mat='metal', cap=True):
        z = self.roof_z(x, y)
        self.m.cyl(x, y, z - 4, z + h, r, mat, bias=200)
        if cap:
            self.m.cyl(x, y, z + h, z + h + 2, r + 1.5, mat, bias=201)

    def antenna(self, x, y, h=40.0, col=(90, 92, 90)):
        z = self.roof_z(x, y)
        self.m.line3([V(x, y, z), V(x, y, z + h)], col, 1, bias=210)
        for k in (0.55, 0.75, 0.92):
            w = 10 * (1 - k) + 3
            self.m.line3([V(x - w, y, z + h * k), V(x + w, y, z + h * k)], col, 1, bias=211)

    def mast(self, x, y, h=70.0, col=(140, 142, 138)):
        z = self.roof_z(x, y)
        for dx, dy in ((-4, -4), (4, -4), (4, 4), (-4, 4)):
            self.m.line3([V(x + dx, y + dy, z), V(x + dx * 0.2, y + dy * 0.2, z + h)], col, 1, bias=210)
        zz = z + 6
        while zz < z + h - 6:
            k = 1 - (zz - z) / h * 0.8
            self.m.line3([V(x - 4 * k, y + 4 * k, zz), V(x + 4 * k, y + 4 * k, zz + 7)], dark(col, 0.85), 1, bias=211)
            zz += 7
        self.m.line3([V(x, y, z + h), V(x, y, z + h + 10)], (70, 70, 70), 1, bias=212)
        self.m.cyl(x, y, z + h + 10, z + h + 12, 1.4, ((230, 60, 40), 'none'), segs=6, bias=213)

    def dish(self, x, y, r=5.0):
        z = self.roof_z(x, y)
        self.m.line3([V(x, y, z), V(x, y, z + 5)], (70, 70, 70), 1, bias=210)
        pts = [V(x + math.cos(a) * r, y + 1.5, z + 7 + math.sin(a) * r) for a in np.linspace(0, 2 * math.pi, 16)]
        self.m.poly3(pts, (176, 178, 172), 'none', bias=211)

    def solar(self, x, y, w=28.0, d=14.0):
        z = self.roof_z(x, y) + 1.2
        self.m.poly3([V(x - w / 2, y + d / 2, z), V(x + w / 2, y + d / 2, z), V(x + w / 2, y - d / 2, z + 5), V(x - w / 2, y - d / 2, z + 5)],
                     (48, 60, 88), 'glass', bias=205, frame=(V(x - w / 2, y + d / 2, z), V(1, 0, 0), norm3(V(0, -d, 5))))

    def roof_patch(self, x, y, w, d, mat):
        """replacement sheets / tar patch on a roof (follows the roof height)."""
        z0 = self.roof_z(x, y + d / 2) + 0.4
        z1 = self.roof_z(x, y - d / 2) + 0.4
        col, pat = MAT[mat]
        self.m.poly3([V(x - w / 2, y + d / 2, z0), V(x + w / 2, y + d / 2, z0), V(x + w / 2, y - d / 2, z1), V(x - w / 2, y - d / 2, z1)],
                     col, pat, bias=150, frame=(V(x - w / 2, y + d / 2, z0), V(1, 0, 0), norm3(V(0, -d, z1 - z0))))

    def roof_cross(self, x, y, s=10.0, disc=(226, 226, 218)):
        z0 = self.roof_z(x, y) + 0.6
        f = Face(V(x - s * 1.3, y + s * 1.3, z0), V(1, 0, 0), norm3(V(0, -1, (self.roof_z(x, y - 1) - self.roof_z(x, y)))), s * 2.6, s * 2.6,
                 disc, 'none', bias=160, outline=False)
        self.m.add(f)
        self.m.rect(f, 0, 0, 0, 0, disc)
        f.decals.append(('cross', dict(u=s * 1.3, v=s * 1.3, s=s, col=(176, 48, 42))))

    def ac_unit(self, x, z):
        u = self.fu(x)
        self.m.box(x - 5, x + 5, self.y1, self.y1 + 4, z, z + 7, ((150, 152, 148), 'none'), bias=55)
        self.m.line3([V(x - 3, self.y1 + 4.2, z + 3.5), V(x + 3, self.y1 + 4.2, z + 3.5)], (90, 90, 88), 1, bias=56)

    def drainpipe(self, x):
        self.m.box(x - 1.2, x + 1.2, self.y1, self.y1 + 2, 0, self.H - 1, ((104, 108, 106), 'none'), bias=52, cap=False)

    def awning(self, x, w, z, depth, c1, c2):
        f = Face(V(x - w / 2, self.y1 + depth, z - 4), V(1, 0, 0), norm3(V(0, -depth, 6)), w, math.hypot(depth, 6), c1, 'none', bias=62)
        self.m.add(f)
        f.decals.append(('stripe', dict(u=0, v=0, w=w, h=math.hypot(depth, 6), c1=c1, c2=c2, period=8)))

    def lean_to(self, x0, x1, depth, h, wall, roof_mat, rise=6.0, door=False):
        """annex on the south side (porch / veranda); keeps the doorway clear."""
        y1 = self.y1 + depth
        f = self.m.box(x0, x1, self.y1, y1, 0, h, wall, cap=False, bias=40)['front']
        col, pat = MAT[roof_mat]
        self.m.poly3([V(x0 - 2, y1 + 3, h - 1), V(x1 + 2, y1 + 3, h - 1), V(x1 + 2, self.y1, h + rise), V(x0 - 2, self.y1, h + rise)],
                     col, pat, bias=70, frame=(V(x0 - 2, y1 + 3, h - 1), V(1, 0, 0), norm3(V(0, -depth - 3, rise + 1))))
        return f

    def finish(self, grime=None, rust=None, moss=None):
        g = self.grime if grime is None else grime
        r = self.rust if rust is None else rust
        mo = self.moss if moss is None else moss
        c = render(self.m, grime=g, rust=r, moss=mo)
        return c


def norm3(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


# ======================================================================= PERRON ==
# Railway community: timber, logs, red brick station, slate and tin roofs,
# carved blue window frames (наличники), laundry and warm lamps.
def perron_barrack():
    b = B('perron_barrack', 240, 112, 50, 'plank', 11, 'barracks')
    b.corner_boards((96, 72, 50))
    b.door(0, canopy=('tin_grey', 10))
    b.windows(12, 14, 20, 34, style='nalichnik', frame=(206, 200, 184))
    b.gable('slate', 32)
    b.roof_patch(-60, 18, 30, 16, 'tin_grey')
    b.chimney(-70, -10, 14, smoke=True)
    b.chimney(70, -10, 14)
    b.pipe(30, 20, 10)
    b.drainpipe(b.x0 + 4); b.drainpipe(b.x1 - 4)
    b.moss = 0.06
    return b


def perron_izba():
    b = B('perron_izba', 156, 108, 46, 'log', 12, 'utility_house')
    b.corner_boards((92, 66, 42), 4)
    b.door(-44, canopy=('shingle', 9))
    b.windows(12, 13, 18, 30, style='nalichnik', frame=(214, 208, 190), x_from=-24, x_to=70, shutters=(84, 110, 132))
    b.gable('shingle', 36)
    b.chimney(30, -6, 16, smoke=True)
    b.antenna(-40, 8, 24)
    b.moss = 0.10
    return b


def perron_station():
    b = B('perron_station', 280, 132, 78, 'brick', 13, 'rail_service', plinth=(120, 112, 100), plinth_h=7)
    b.band(40, 3, (200, 190, 168))
    b.band(73, 5, (200, 190, 168))
    b.corner_boards((190, 180, 160), 5)
    b.door(0, canopy=('tin_grey', 14))
    b.windows(10, 14, 22, 30, style='arch', frame=(206, 198, 178))
    b.windows(46, 14, 20, 30, style='arch', frame=(206, 198, 178), avoid_openings=False, skip=())
    b.signboard(0, 60, 80, 9, col=(34, 52, 48), border=(200, 190, 150))
    b.hip('tin_green', 34)
    # clock tower on the ridge
    z = b.roof_z(0, 0)
    b.m.box(-12, 12, -12, 12, z - 10, z + 22, 'brick', bias=200)
    b.m.box(-15, 15, -15, 15, z + 22, z + 25, ((200, 190, 168), 'none'), bias=201)
    b.m.poly3([V(-15, 15, z + 25), V(15, 15, z + 25), V(0, 0, z + 42)], (78, 108, 84), 'seam', bias=202,
              frame=(V(-15, 15, z + 25), V(1, 0, 0), norm3(V(0, -15, 17))))
    clock = Face(V(-7, 12.2, z + 4), V(1, 0, 0), V(0, 0, 1), 14, 14, (224, 220, 204), 'none', bias=203, outline=False)
    b.m.add(clock)
    clock.decals.append(('rect', dict(u=6.4, v=6.4, w=1.2, h=6, col=(30, 30, 30), lit_shade=False)))
    clock.decals.append(('rect', dict(u=6.4, v=6.4, w=4.5, h=1.2, col=(30, 30, 30), lit_shade=False)))
    b.chimney(-90, -20, 12)
    b.chimney(90, -20, 12)
    b.drainpipe(b.x0 + 5); b.drainpipe(b.x1 - 5)
    return b


def perron_market():
    b = B('perron_market', 260, 128, 58, 'plank_v', 14, 'grocery')
    b.door(0, canopy=None)
    # big shopfront openings with stall counters
    for x in (-86, -42, 42, 86):
        u = b.fu(x) - 16
        b.m.rect(b.front, u - 1.5, 6, 35, 34, (60, 50, 40))
        b.m.rect(b.front, u, 16, 32, 22, (34, 30, 26))
        b.m.rect(b.front, u, 6, 32, 10, (140, 108, 70))
        for k in range(5):
            b.m.rect(b.front, u + 3 + k * 6, 16, 4, 3, [(170, 70, 40), (120, 140, 56), (196, 150, 60), (160, 90, 60), (110, 130, 70)][k])
        b.opening_xs.append((x, 18))
    b.awning(-64, 88, 48, 12, (150, 64, 46), (206, 196, 168))
    b.awning(64, 88, 48, 12, (70, 104, 84), (206, 196, 168))
    b.signboard(0, 44, 64, 9, col=(120, 50, 36), border=(210, 190, 140))
    b.gambrel('tin_red', 14, 16)
    b.moss = 0.04
    b.rust = 0.08
    return b


def perron_canteen():
    b = B('perron_canteen', 210, 120, 54, 'plaster_y', 15, 'cafe')
    b.band(0, 12, (150, 90, 66))
    b.corner_boards((160, 132, 90), 4)
    b.door(-50, canopy=('tin_red', 12))
    b.windows(16, 22, 22, 36, style='cross', frame=(206, 200, 184), x_from=-26, x_to=96, lit_chance=0.3)
    b.signboard(-50, 42, 60, 8, col=(40, 44, 42))
    b.gable('tiles', 28)
    b.chimney(50, -10, 22, w=10, smoke=True)
    b.pipe(-20, 16, 10)
    b.ac_unit(80, 40)
    return b


def perron_warehouse():
    b = B('perron_warehouse', 230, 124, 62, 'plank_grey', 16, 'warehouse')
    b.gate(40, 56, 46, col=(112, 86, 58), kind='gate')
    b.door(-60)
    b.windows(44, 12, 8, 30, style='strip', x_from=-110, x_to=-80)
    b.signboard(40, 50, 54, 8)
    b.gambrel('slate_dark', 16, 14)
    b.roof_patch(-40, 22, 34, 18, 'tin_grey')
    b.moss = 0.08
    b.rust = 0.05
    return b


def perron_radio():
    b = B('perron_radio', 146, 104, 50, 'brick_dark', 17, 'comms')
    b.door(-30, canopy=('tin_grey', 8))
    b.windows(14, 14, 20, 30, style='frame', x_from=-4, x_to=62)
    b.signboard(-30, 38, 44, 8)
    b.flat('tar', 'brick_dark', 4)
    b.mast(30, -18, 64)
    b.dish(-40, -20, 6)
    b.antenna(-50, 10, 22)
    return b


def perron_bathhouse():
    b = B('perron_bathhouse', 128, 96, 42, 'log', 18, 'shed')
    b.corner_boards((92, 66, 42), 4)
    b.door(-28, canopy=None)
    b.windows(16, 10, 10, 24, style='frame', x_from=4, x_to=50)
    b.gable('shingle', 26)
    b.chimney(30, 6, 14, w=6, mat=('metal' and MAT['metal']), smoke=True)
    b.moss = 0.12
    return b


# ======================================================================= RUBEZH ==
# Garrison: silicate brick, concrete, asbestos slate, olive steel, sandbags.
def rubezh_hq():
    b = B('rubezh_hq', 272, 140, 82, 'silicate', 21, 'barracks', plinth=(110, 108, 100), plinth_h=8)
    b.band(40, 3, (140, 136, 120))
    b.door(0, canopy=('concrete_s', 16), frame=(60, 60, 58))
    b.windows(12, 16, 20, 34, style='frame', frame=(200, 200, 192))
    b.windows(48, 16, 20, 34, style='frame', frame=(200, 200, 192), avoid_openings=False)
    b.signboard(0, 66, 96, 9, col=(52, 60, 44), border=(190, 180, 130))
    # sandbag breastworks either side of the entrance
    for x in (-34, 34):
        b.m.box(x - 10, x + 10, b.y1 + 4, b.y1 + 12, 0, 12, 'sandbag', bias=58)
    b.flat('tar', 'concrete_s', 5)
    b.mast(-100, -30, 56)
    b.dish(80, -30, 7)
    b.pipe(40, 10, 8)
    b.m.box(96, 116, -10, 10, 82, 96, ((150, 150, 144), 'none'), bias=200)       # roof water tank
    b.m.line3([V(0, 0, 87), V(0, 0, 140)], (180, 182, 178), 1, bias=220)          # flag pole
    fl = Face(V(0, 0.5, 124), V(1, 0, 0), V(0, 0, 1), 26, 14, (84, 98, 62), 'none', bias=221, outline=True)
    b.m.add(fl)
    fl.decals.append(('rect', dict(u=0, v=5, w=26, h=4, col=(200, 190, 150), lit_shade=False)))
    return b


def rubezh_barracks():
    b = B('rubezh_barracks', 250, 118, 50, 'silicate', 22, 'barracks')
    b.door(-60, canopy=('slate', 10), frame=(60, 60, 58))
    b.windows(14, 14, 20, 30, style='cross', frame=(170, 170, 162))
    b.gable('slate', 30)
    b.pipe(-80, -10, 12); b.pipe(0, -10, 12); b.pipe(80, -10, 12)
    b.roof_patch(40, 20, 26, 16, 'tin_olive')
    b.drainpipe(b.x0 + 4); b.drainpipe(b.x1 - 4)
    b.moss = 0.05
    return b


def rubezh_hangar():
    b = B('rubezh_hangar', 230, 150, 30, 'steel_olive', 23, 'garage_row', plinth=(90, 90, 84), plinth_h=4)
    front = b.arch('steel_olive')
    b.gate(0, 90, 60, col=(78, 88, 58), kind='gate')
    b.door(-80)
    b.signboard(0, 96, 70, 9, col=(52, 60, 44), border=(190, 180, 130))
    b.rust = 0.10
    return b


def rubezh_guardhouse():
    b = B('rubezh_guardhouse', 150, 104, 52, 'concrete_s', 24, 'checkpoint')
    b.band(0, 18, (150, 138, 100))
    b.door(-40, frame=(60, 60, 58))
    b.windows(20, 26, 18, 40, style='strip', frame=(140, 140, 132), x_from=-10, x_to=70, bars=True)
    b.flat('tar', 'concrete_s', 4)
    # observation cupola
    z = b.H
    b.m.box(10, 50, -30, 0, z, z + 16, 'concrete_s', bias=200)
    cf = b.m.box(8, 52, -32, 2, z + 16, z + 18, ((80, 84, 78), 'none'), bias=202)
    b.m.add(Face(V(14, 0.2, z + 5), V(1, 0, 0), V(0, 0, 1), 32, 8, (52, 66, 74), 'glass', bias=201))
    for x in (-60, 70):
        b.m.box(x - 8, x + 8, b.y1 + 2, b.y1 + 10, 0, 14, 'sandbag', bias=58)
    return b


def rubezh_garages():
    b = B('rubezh_garages', 262, 112, 48, 'concrete', 25, 'garage_row')
    for i, x in enumerate((-96, -32, 32, 96)):
        if i == 1:
            b.door(x)
            continue
        b.gate(x, 46, 38, col=(88, 98, 66))
    for i in range(4):
        b.signboard(-96 + i * 64, 41, 14, 5, col=(200, 190, 150), border=(40, 40, 40))
    b.sign = None
    b.flat('tar', 'concrete', 3)
    b.rust = 0.12
    return b


def rubezh_armory():
    b = B('rubezh_armory', 206, 124, 46, 'concrete', 26, 'mil_store')
    b.door(0, frame=(50, 54, 48))
    b.m.rect(b.front, b.fu(0) - 14, 0, 28, 38, (90, 96, 70))
    b.m.rect(b.front, b.fu(0) - 10, 0, 20, 32, (22, 22, 20))
    b.windows(30, 10, 6, 40, style='strip', bars=True, frame=(90, 90, 86))
    b.signboard(0, 40, 60, 5, col=(160, 50, 40), border=(40, 40, 40))
    # earth berm over the roof
    H = b.H
    b.m.poly3([V(b.x0 - 6, b.y1 + 2, H - 2), V(b.x1 + 6, b.y1 + 2, H - 2), V(b.x1 - 10, 0, H + 18), V(b.x0 + 10, 0, H + 18)],
              MAT['earth'][0], 'earth', bias=100, frame=(V(b.x0, b.y1, H), V(1, 0, 0), norm3(V(0, -60, 20))))
    b.m.poly3([V(b.x0 + 10, 0, H + 18), V(b.x1 - 10, 0, H + 18), V(b.x1 + 6, b.y0 - 2, H - 2), V(b.x0 - 6, b.y0 - 2, H - 2)],
              dark(MAT['earth'][0], 0.9), 'earth', bias=99, frame=(V(b.x0, 0, H + 18), V(1, 0, 0), norm3(V(0, -60, -20))))
    b.roof_rise = 18
    b.roof_fn = lambda x, y: H + 18 * max(0, 1 - abs(y) / 62)
    b.pipe(-50, -6, 10); b.pipe(50, -6, 10)
    for x in (-70, 70):
        b.m.box(x - 12, x + 12, b.y1 + 3, b.y1 + 11, 0, 10, 'sandbag', bias=58)
    b.moss = 0.10
    return b


def rubezh_medpoint():
    b = B('rubezh_medpoint', 196, 116, 50, 'plaster', 27, 'clinic')
    b.band(0, 10, (110, 120, 100))
    b.door(-40, canopy=('tin_olive', 10))
    b.windows(14, 16, 20, 34, style='frame', x_from=-10, x_to=90)
    b.front.decals.append(('cross', dict(u=b.fu(-40), v=40, s=5, col=(176, 48, 42), disc=(226, 226, 218))))
    b.gable('slate', 28)
    b.roof_cross(0, 18, 9)
    b.pipe(60, -10, 10)
    return b


def rubezh_comms():
    b = B('rubezh_comms', 164, 110, 56, 'silicate', 28, 'comms')
    b.door(40, frame=(60, 60, 58))
    b.windows(20, 12, 14, 30, style='frame', bars=True, x_from=-74, x_to=10)
    b.signboard(40, 42, 40, 7)
    b.flat('tar', 'concrete_s', 4)
    b.mast(-30, -20, 84)
    b.dish(40, -24, 8)
    b.dish(10, 20, 5)
    b.m.box(-72, -52, -40, -20, 56, 68, ((110, 116, 104), 'none'), bias=200)    # generator housing
    return b


# ===================================================================== MECHANICS ==
# Artel: corrugated steel, brick workshops, sawtooth roofs, chimneys, hazard paint,
# cables and lamps. Everything patched and rusted.
def mech_hangar():
    b = B('mech_hangar', 284, 150, 70, 'steel', 31, 'repair_bay', plinth=(90, 90, 84), plinth_h=5)
    b.gate(-40, 100, 58, col=(160, 128, 44))
    b.m.rect(b.front, b.fu(-40) - 52, 58, 104, 3, (40, 40, 38))
    for k in range(8):
        b.front.decals.append(('stripe', dict(u=b.fu(-40) - 50, v=0, w=100, h=4, c1=(206, 164, 44), c2=(36, 36, 34), period=10)))
        break
    b.door(80)
    b.windows(62, 30, 6, 40, style='strip', x_from=-140, x_to=140, avoid_openings=False, sill=False)
    b.signboard(80, 44, 60, 8, col=(206, 164, 44), border=(40, 40, 38))
    b.gable('steel', 22, over=5)
    b.roof_patch(-80, 20, 40, 22, 'steel_rust')
    b.roof_patch(60, -20, 30, 18, 'steel_blue')
    b.pipe(100, -10, 16, 3)
    b.rust = 0.18
    return b


def mech_workshop():
    b = B('mech_workshop', 244, 138, 60, 'brick', 32, 'workshop', plinth=(100, 98, 92), plinth_h=6)
    b.door(-70)
    b.gate(50, 60, 46, col=(100, 110, 116))
    b.windows(14, 24, 28, 34, style='strip', frame=(90, 96, 96), x_from=-110, x_to=10, glass=(64, 80, 84))
    b.signboard(50, 50, 60, 7)
    b.sawtooth('tin_grey', teeth=3, rise=18)
    b.pipe(-90, -10, 14, 2.5)
    b.rust = 0.10
    return b


def mech_boiler():
    b = B('mech_boiler', 164, 118, 64, 'brick_dark', 33, 'workshop')
    b.band(56, 4, (150, 90, 66))
    b.door(-40)
    b.windows(30, 16, 22, 30, style='arch', frame=(150, 100, 80), x_from=-10, x_to=70)
    b.flat('tar', 'brick_dark', 4)
    # tall chimney with hazard bands and a pipe bridge
    b.m.cyl(40, -30, b.H - 4, b.H + 120, 9, 'brick', segs=14, bias=200)
    for z in (b.H + 100, b.H + 108):
        b.m.cyl(40, -30, z, z + 4, 9.6, ((200, 60, 44), 'none'), segs=14, bias=201)
    for k, (dz, r) in enumerate([(128, 7), (140, 9), (154, 11)]):
        b.m.cyl(44 + k * 4, -30, b.H + dz, b.H + dz + r, r, ((110, 108, 104), 'none'), segs=10, bias=260 + k)
    b.m.cyl(-40, -10, b.H - 2, b.H + 8, 6, 'metal', bias=200)
    b.rust = 0.08
    return b


def mech_containers():
    b = B('mech_containers', 204, 112, 40, 'container_b', 34, 'utility_house', plinth=None)
    b.m.rect(b.front, 100, 0, 104, 40, (128, 62, 44))
    b.m.rect(b.front, 100, 0, 1.5, 40, (40, 30, 26))
    b.door(-60)
    b.windows(14, 18, 14, 30, style='frame', frame=(170, 170, 160), x_from=-30, x_to=96)
    b.flat('tar', None, 0)
    # upper container (living module) set back, with a balcony rail
    H = b.H
    up = b.m.box(-96, 60, -50, 30, H, H + 38, 'container_g', bias=120)
    up['top'].pattern = 'seam'
    for x in (-80, -44, 26):
        b.m.window(up['front'], x + 96, 12, 18, 14, style='frame', frame_col=(170, 170, 160))
    b.m.line3([V(-96, 36, H + 10), V(60, 36, H + 10)], (70, 72, 70), 1, bias=130)
    for x in range(-96, 61, 12):
        b.m.line3([V(x, 36, H), V(x, 36, H + 10)], (70, 72, 70), 1, bias=130)
    b.m.box(62, 100, 26, 40, 0, H, ((70, 72, 70), 'none'), bias=45, cap=False)       # stair tower
    for z in range(4, int(H), 6):
        b.m.line3([V(62, 40.2, z), V(100, 40.2, z + 4)], (110, 112, 110), 1, bias=46)
    b.roof_rise = 38
    b.roof_fn = lambda x, y: H + 38 if (-96 < x < 60 and -50 < y < 30) else H
    b.solar(-20, -10, 40, 18)
    b.ac_unit(-20, 28)
    b.rust = 0.20
    return b


def mech_office():
    b = B('mech_office', 262, 132, 80, 'concrete', 35, 'factory_admin', plinth=(100, 98, 92), plinth_h=7)
    b.band(40, 4, (206, 164, 44))
    b.door(0, canopy=('steel', 14))
    b.windows(12, 20, 20, 34, style='frame', frame=(170, 172, 168))
    b.windows(50, 20, 20, 34, style='frame', frame=(170, 172, 168), avoid_openings=False, lit_chance=0.2)
    b.signboard(0, 70, 100, 9, col=(206, 164, 44), border=(40, 40, 38))
    b.flat('tar', 'concrete', 5)
    b.m.cyl(-90, -20, 85, 110, 12, 'steel_rust', bias=200)                   # water tank on legs
    for dx in (-8, 8):
        b.m.line3([V(-90 + dx, -12, 80), V(-90 + dx, -12, 85)], (70, 70, 70), 2, bias=199)
    b.solar(40, -20, 44, 20)
    b.solar(90, -20, 30, 20)
    b.antenna(110, 20, 30)
    b.ac_unit(-60, 60); b.ac_unit(70, 22)
    b.rust = 0.06
    return b


def mech_garages():
    b = B('mech_garages', 244, 112, 48, 'steel_blue', 36, 'garage_row')
    for i, x in enumerate((-90, -30, 30, 90)):
        if i == 2:
            b.door(x)
            continue
        b.gate(x, 44, 38, col=[(160, 128, 44), (120, 124, 124), (140, 70, 50)][i % 3])
    b.gable('steel', 16)
    b.roof_patch(-40, 10, 40, 20, 'steel_rust')
    b.rust = 0.22
    return b


def mech_fuel():
    b = B('mech_fuel', 156, 104, 46, 'plaster_y', 37, 'service_shop')
    b.band(0, 14, (160, 60, 44))
    b.door(-40)
    b.windows(16, 22, 18, 34, style='frame', x_from=-10, x_to=70)
    b.signboard(-40, 38, 50, 7, col=(160, 60, 44), border=(230, 220, 200))
    b.flat('tar', 'plaster_y', 3)
    b.m.cyl(30, -20, 46, 66, 14, 'steel_rust', bias=200)
    b.pipe(-50, -10, 10)
    b.rust = 0.10
    return b


def mech_electro():
    b = B('mech_electro', 206, 122, 58, 'brick', 38, 'workshop')
    b.door(-60)
    b.windows(18, 18, 22, 32, style='strip', frame=(90, 96, 96), x_from=-30, x_to=90)
    b.signboard(-60, 44, 58, 7, col=(40, 44, 42), border=(206, 164, 44))
    b.gable('tin_grey', 24)
    b.solar(-50, 22, 60, 18)
    b.solar(40, 22, 60, 18)
    b.antenna(80, -20, 28)
    # cable run from the roof
    b.m.line3([V(b.x1 - 6, b.y1, b.H + 2), V(b.x1 + 30, b.y1 + 20, b.H + 20)], (30, 30, 30), 1, bias=250)
    b.rust = 0.06
    return b


# ======================================================================= LAZARET ==
# Medical town: whitewash, pale green plaster, green/red tin roofs, red crosses,
# tidy frames, canopies and hedges.
def laz_hospital():
    b = B('laz_hospital', 284, 142, 84, 'plaster', 41, 'clinic', plinth=(120, 130, 120), plinth_h=8)
    b.band(42, 3, (150, 170, 154))
    b.door(0, canopy=('tin_green', 18), frame=(80, 100, 90))
    b.windows(14, 16, 22, 32, style='frame', frame=(222, 222, 214))
    b.windows(52, 16, 22, 32, style='frame', frame=(222, 222, 214), avoid_openings=False, lit_chance=0.25)
    b.front.decals.append(('cross', dict(u=b.fu(0), v=72, s=6, col=(176, 48, 42), disc=(230, 230, 222))))
    b.hip('tin_green', 36)
    b.roof_cross(-70, 26, 11)
    b.chimney(80, -20, 12, mat='plaster')
    b.pipe(40, -30, 8)
    return b


def laz_pavilion():
    b = B('laz_pavilion', 244, 118, 52, 'plaster_g', 42, 'clinic')
    b.corner_boards((210, 214, 204), 4)
    b.door(0, canopy=('tin_green', 12))
    b.windows(14, 18, 22, 32, style='cross', frame=(224, 224, 216))
    b.gable('tin_green', 28)
    b.pipe(-70, -12, 10); b.pipe(70, -12, 10)
    b.moss = 0.04
    return b


def laz_pharmacy():
    b = B('laz_pharmacy', 170, 110, 52, 'plaster', 43, 'pharmacy')
    b.band(0, 14, (110, 150, 128))
    b.door(-40, canopy=None)
    b.awning(30, 76, 44, 10, (70, 120, 96), (220, 220, 212))
    b.windows(14, 26, 24, 34, style='frame', x_from=-8, x_to=76, frame=(222, 222, 214), glass=(60, 84, 88))
    b.front.decals.append(('cross', dict(u=b.fu(-40), v=42, s=5, col=(60, 150, 90), disc=(230, 230, 222))))
    b.flat('tar', 'plaster', 4)
    b.ac_unit(60, 46)
    return b


def laz_lab():
    b = B('laz_lab', 206, 124, 46, 'brick', 44, 'pharmacy', plinth=(110, 108, 100), plinth_h=6)
    b.door(-70)
    b.windows(14, 20, 22, 30, style='strip', frame=(200, 204, 200), x_from=-40, x_to=90, glass=(70, 96, 100))
    b.signboard(-70, 38, 50, 6, col=(220, 222, 214), border=(60, 90, 80))
    # glazed greenhouse roof
    H = b.H
    s, n = b.m.gable_x(b.x0, b.x1, b.y0, b.y1, H, 26, 'glass', over=2, over_x=2, bias=100)
    s.alpha = 200; n.alpha = 190
    b.roof_rise = 26
    b.roof_fn = lambda x, y: H + 26 * max(0, 1 - abs(y) / 62)
    b.m.line3([V(b.x0, 0, H + 26.5), V(b.x1, 0, H + 26.5)], (220, 222, 216), 2, bias=150)
    b.eave_shadow(4, 60)
    return b


def laz_isolation():
    b = B('laz_isolation', 220, 116, 50, 'plaster', 45, 'clinic')
    b.band(0, 16, (170, 150, 60))
    b.door(60, frame=(90, 90, 86))
    b.windows(20, 14, 16, 34, style='frame', bars=True, x_from=-100, x_to=30, frame=(200, 200, 192))
    b.signboard(60, 38, 44, 7, col=(206, 170, 44), border=(40, 40, 38))
    b.gable('tin_red', 26)
    b.pipe(-40, -10, 16, 3)
    b.pipe(40, -10, 16, 3)
    return b


def laz_residence():
    b = B('laz_residence', 220, 122, 76, 'plaster', 46, 'panel_entry', plinth=(120, 124, 118), plinth_h=6)
    b.band(38, 3, (190, 194, 184))
    b.door(-60, canopy=('tin_green', 10))
    b.windows(12, 16, 20, 32, style='frame', frame=(224, 224, 216))
    b.windows(46, 16, 20, 32, style='frame', frame=(224, 224, 216), avoid_openings=False, lit_chance=0.3)
    # balconies on the upper floor
    for x in (-10, 54):
        b.m.box(x - 16, x + 16, b.y1, b.y1 + 8, 40, 43, ((180, 184, 176), 'none'), bias=55)
        b.m.box(x - 16, x + 16, b.y1 + 7, b.y1 + 8, 43, 50, ((120, 130, 124), 'none'), bias=56)
    b.hip('tin_red', 30)
    b.chimney(-60, -10, 12, mat='plaster')
    b.antenna(40, 10, 24)
    return b


def laz_laundry():
    b = B('laz_laundry', 170, 112, 54, 'plaster_g', 47, 'utility_house')
    b.door(40)
    b.windows(22, 22, 14, 34, style='strip', frame=(220, 220, 212), x_from=-76, x_to=14)
    b.signboard(40, 40, 50, 7, col=(220, 222, 214), border=(60, 90, 80))
    b.gable('tin_green', 22)
    b.m.cyl(-40, -10, b.roof_z(-40, -10) - 4, b.roof_z(-40, -10) + 26, 5, 'metal', bias=200)
    for k, (dz, r) in enumerate([(30, 5), (38, 6.5), (48, 8)]):
        b.m.cyl(-40 + k * 2, -10, b.roof_z(-40, -10) + dz, b.roof_z(-40, -10) + dz + r, r, ((220, 222, 220), 'none'), segs=10, bias=260 + k)
    return b


def laz_checkpoint():
    b = B('laz_checkpoint', 152, 102, 48, 'plaster', 48, 'checkpoint')
    b.band(0, 12, (110, 150, 128))
    b.door(-30, canopy=None)
    b.awning(-30, 40, 42, 10, (70, 120, 96), (220, 220, 212))
    b.windows(18, 22, 18, 30, style='strip', x_from=14, x_to=70, frame=(222, 222, 214))
    b.front.decals.append(('cross', dict(u=b.fu(40), v=40, s=4, col=(176, 48, 42), disc=(230, 230, 222))))
    b.flat('tar', 'plaster', 3)
    return b


MODELS = {
    'perron': [perron_barrack, perron_izba, perron_station, perron_market, perron_canteen, perron_warehouse, perron_radio, perron_bathhouse],
    'rubezh': [rubezh_hq, rubezh_barracks, rubezh_hangar, rubezh_guardhouse, rubezh_garages, rubezh_armory, rubezh_medpoint, rubezh_comms],
    'mechanics': [mech_hangar, mech_workshop, mech_boiler, mech_containers, mech_office, mech_garages, mech_fuel, mech_electro],
    'lazaret': [laz_hospital, laz_pavilion, laz_pharmacy, laz_lab, laz_isolation, laz_residence, laz_laundry, laz_checkpoint],
}


# ================================================================== build / pack ==
LEAF_STYLES = {
    'perron': ((112, 82, 54), (84, 60, 40)),
    'rubezh': ((86, 96, 64), (60, 68, 44)),
    'mechanics': ((110, 116, 116), (78, 82, 84)),
    'lazaret': ((206, 208, 200), (150, 160, 154)),
}


def _leaf_image():
    """front door leaves at 1x (the game scales leaves itself): 24x32 per faction."""
    out = Image.new('RGBA', (24 * 4, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    for i, f in enumerate(['perron', 'rubezh', 'mechanics', 'lazaret']):
        base, dk = LEAF_STYLES[f]
        x = i * 24
        d.rectangle([x, 0, x + 19, 31], fill=base + (255,), outline=(24, 22, 20, 255))
        if f == 'perron':
            for k in range(3, 19, 4):
                d.line([(x + k, 1), (x + k, 30)], fill=dk + (255,))
            d.line([(x + 2, 8), (x + 17, 14)], fill=dk + (255,))
            d.line([(x + 2, 22), (x + 17, 28)], fill=dk + (255,))
        elif f == 'rubezh':
            d.rectangle([x + 3, 3, x + 16, 13], outline=dk + (255,))
            d.rectangle([x + 3, 17, x + 16, 28], outline=dk + (255,))
        elif f == 'mechanics':
            for k in range(2, 31, 3):
                d.line([(x + 1, k), (x + 18, k)], fill=dk + (255,))
            d.rectangle([x + 1, 12, x + 18, 14], fill=(200, 160, 40, 255))
        else:
            d.rectangle([x + 4, 4, x + 15, 12], fill=(90, 120, 130, 255), outline=dk + (255,))
            d.rectangle([x + 8, 17, x + 11, 25], fill=(176, 48, 42, 255))
            d.rectangle([x + 5, 20, x + 14, 22], fill=(176, 48, 42, 255))
        d.rectangle([x + 15, 16, x + 17, 18], fill=(210, 190, 120, 255))
    return out


def _pack(items, width=2048, pad=2):
    """shelf packer: items = [(key, img)] -> (atlas, {key: (x, y, w, h)})"""
    items = sorted(items, key=lambda t: -t[1].height)
    x = y = shelf = 0
    pos = {}
    for key, im in items:
        if x + im.width > width:
            x = 0
            y += shelf + pad
            shelf = 0
        pos[key] = (x, y, im.width, im.height)
        x += im.width + pad
        shelf = max(shelf, im.height)
    atlas = Image.new('RGBA', (width, y + shelf), (0, 0, 0, 0))
    for key, im in items:
        atlas.alpha_composite(im, pos[key][:2])
    return atlas, pos


def _gd(v):
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, float):
        return ('%.2f' % v).rstrip('0').rstrip('.') if '.' in '%.2f' % v else '%.1f' % v
    return str(v)


def build_all(P, gd_path):
    import os
    lines = ['extends RefCounted', '',
             '# GENERATED by tools/wa_buildings.py - do not edit by hand.',
             '# Settlement building models: exterior art for the faction towns.',
             '# roof_pos / facade_pos are the model-space (world px) top-left of each layer',
             '# relative to the footprint centre at ground level; layers are drawn at 0.5.',
             'const MODELS = {']
    entries = []
    for fac, fns in MODELS.items():
        items = []
        meta = {}
        for fn in fns:
            b = fn()
            c = b.finish()
            img = c.img
            split = int(round((b.D / 2 - b.H - c.y0) * DENS))
            roof = img.crop((0, 0, img.width, split))
            facade = img.crop((0, split, img.width, img.height))
            for key, layer, oy in (('roof', roof, 0), ('facade', facade, split)):
                bb = layer.getbbox()
                if bb is None:
                    continue
                cropped = layer.crop(bb)
                items.append(((b.id, key), cropped))
                meta[(b.id, key)] = (c.x0 + bb[0] / DENS, c.y0 + (oy + bb[1]) / DENS)
            meta[b.id] = b
        atlas, pos = _pack(items)
        name = 'settlement_buildings_%s_v1.png' % fac
        atlas.save(os.path.join(P, name))
        for key in [k for k in meta if isinstance(k, str)]:
            b = meta[key]
            rx, ry, rw, rh = pos[(key, 'roof')]
            fx, fy, fw, fh = pos[(key, 'facade')]
            rpx, rpy = meta[(key, 'roof')]
            fpx, fpy = meta[(key, 'facade')]
            sign = 'Rect2(%s,%s,%s,%s)' % tuple(_gd(float(v)) for v in b.sign) if b.sign else 'Rect2()'
            entries.append('    "%s":{"faction":"%s","archetype":"%s","size":Vector2(%s,%s),"facade_height":%s,"roof_rise":%s,'
                           '"door_x":%s,"atlas":"res://%s","roof_region":Rect2(%d,%d,%d,%d),"roof_pos":Vector2(%s,%s),'
                           '"facade_region":Rect2(%d,%d,%d,%d),"facade_pos":Vector2(%s,%s),"sign":%s,"leaf":%d}' % (
                               key, fac, b.archetype, _gd(b.W), _gd(b.D), _gd(b.H), _gd(float(b.roof_rise)), _gd(b.door_x), name,
                               rx, ry, rw, rh, _gd(float(rpx)), _gd(float(rpy)), fx, fy, fw, fh, _gd(float(fpx)), _gd(float(fpy)),
                               sign, ['perron', 'rubezh', 'mechanics', 'lazaret'].index(fac)))
    lines.append(',\n'.join(entries))
    lines += ['}', '', 'static func has(model_id:String) -> bool:', '    return MODELS.has(model_id)', '',
              'static func model(model_id:String) -> Dictionary:', '    return MODELS.get(model_id,{}).duplicate(true)', '']
    open(gd_path, 'w', encoding='utf-8').write('\n'.join(lines))
    _leaf_image().save(os.path.join(P, 'settlement_door_leaves_v1.png'))


if __name__ == '__main__':
    import sys, os
    P = sys.argv[1] if len(sys.argv) > 1 else '.'
    build_all(P, os.path.join(P, 'world', 'settlement_building_models.gd'))
    print('settlement buildings ok')
