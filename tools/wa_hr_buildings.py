"""OSTATOK 1.23-dev2 High Risk architecture.

Every High Risk building gets an authored exterior model, fitted to the exact
gameplay footprint that main_script_mod._high_risk_visual_specs() gives it, so
interiors, doors, containers and collisions stay untouched. The four sites have
their own architecture and their own way of having died:

  clinic     - Soviet regional hospital campus: tiled plaster blocks, green tin,
               ward balconies, a helipad on the surgical block, gutted by fire.
  quarantine - the hospital turned into a quarantine camp: prefab modules,
               plastic-sealed windows, hazmat tunnels, hand-painted biohazard.
  bastion    - reserve arsenal: hardened arched hangars, earth-covered bunkers,
               silicate barracks, sandbagged windows, radar and masts.
  vector     - underground research object: brutalist concrete, blast doors,
               vent stacks, cooling arrays, antenna fields; almost no windows.

Shares the wa_town renderer / wa_buildings DSL with the settlements so the art
reads as one world. Run:  python3 tools/wa_hr_buildings.py <project_dir>
"""
import math
import os
import random
import zlib
import numpy as np
from PIL import Image
from wa_town import Face, V, MAT, dark, mix, DENS, sprinkle_leaves, render
import wa_buildings as WB
from wa_buildings import B, norm3, _pack, _gd, DOOR_W, DOOR_H

# door_x of the building archetypes (world/building_catalog.gd)
ARCH_DOOR = {
    'clinic': -0.10, 'pharmacy': -0.16, 'utility_house': 0.18, 'service_shop': 0.22, 'warehouse': 0.22,
    'checkpoint': -0.20, 'barracks': 0.0, 'factory_admin': 0.0, 'repair_bay': -0.20, 'mil_store': 0.22,
    'comms': -0.18, 'workshop': -0.22,
}

# (site, cell, index) -> (sign, archetype, (W, D)); mirrors _high_risk_visual_specs
SPECS = {
    'clinic': {
        '0,0': [None, ('НЕОТЛОЖНАЯ ПОМОЩЬ', 'pharmacy', (150, 108)), ('ОХРАНА', 'utility_house', (118, 72))],
        '1,0': [('ДИАГНОСТИЧЕСКИЙ КОРПУС', 'clinic', (432, 330)), ('ЛУЧЕВОЙ ЦЕНТР', 'clinic', (210, 244)), ('МЕДИЦИНСКИЙ АРХИВ', 'utility_house', (152, 96))],
        '2,0': [('ГАРАЖ САНТРАНСПОРТА', 'service_shop', (300, 220)), ('КИСЛОРОДНАЯ СТАНЦИЯ', 'warehouse', (270, 202)), ('ЭВАКУАЦИОННАЯ ДИСПЕТЧЕРСКАЯ', 'utility_house', (168, 104))],
        '0,1': [('ПАЛАТНЫЙ КОРПУС А', 'clinic', (500, 365)), ('ПАЛАТНЫЙ КОРПУС Б', 'clinic', (180, 265)), ('ПОСТ МЕДСЕСТРЫ', 'pharmacy', (148, 96))],
        '1,1': [('ИЗОЛЯЦИОННЫЙ КОРПУС', 'clinic', (506, 365)), ('ПОСЛЕОПЕРАЦИОННЫЙ', 'clinic', (178, 258)), ('САНШЛЮЗ', 'utility_house', (144, 94))],
        '2,1': [('ОПЕРАЦИОННЫЙ КОРПУС', 'clinic', (488, 354)), ('СТЕРИЛЬНЫЙ РЕЗЕРВ', 'pharmacy', (190, 218)), ('РЕАНИМАЦИЯ', 'clinic', (250, 174))],
    },
    'quarantine': {
        '0,0': [('КПП • КАРАНТИН', 'checkpoint', (188, 128)), ('ТРИАЖ И ДЕЗИНФЕКЦИЯ', 'clinic', (360, 272)), ('ДЕЗПОСТ', 'utility_house', (146, 96))],
        '1,0': [('ИЗОЛЯТОР А', 'clinic', (520, 360)), ('ПОСТ НАБЛЮДЕНИЯ', 'pharmacy', (176, 230)), ('САНПРОПУСКНИК', 'utility_house', (148, 94))],
        '2,0': [('ЛАБОРАТОРНЫЙ КОРПУС', 'clinic', (500, 352)), ('ХОЛОДИЛЬНЫЙ БЛОК', 'utility_house', (178, 220)), ('ТЕХСЕКТОР', 'service_shop', (228, 118))],
        '0,1': [('САНТРАНСПОРТ', 'service_shop', (300, 218)), ('ХОЗЯЙСТВЕННЫЙ СКЛАД', 'warehouse', (286, 198)), ('ОХРАНА', 'utility_house', (142, 94))],
        '1,1': [('КРАСНАЯ ЗОНА', 'clinic', (518, 364)), ('ИЗОЛЯТОР Б', 'clinic', (176, 246)), ('ГЕРМОШЛЮЗ', 'utility_house', (142, 92))],
        '2,1': [('СТЕРИЛЬНЫЙ РЕЗЕРВ №12', 'clinic', (500, 356)), ('ЧИСТЫЙ СКЛАД', 'pharmacy', (184, 226)), ('ВНУТРЕННИЙ ПОСТ', 'checkpoint', (146, 94))],
    },
    'bastion': {
        '0,0': [('БАСТИОН • КПП', 'checkpoint', (192, 132)), ('КАРАУЛЬНЫЙ КОРПУС', 'barracks', (342, 260)), ('ДОСМОТР', 'utility_house', (142, 94))],
        '1,0': [('КАЗАРМЕННЫЙ КОРПУС', 'barracks', (480, 350)), ('ШТАБ СЕКТОРА', 'factory_admin', (184, 230)), ('СКЛАД ЗИП', 'warehouse', (150, 96))],
        '2,0': [('ГЛАВНЫЙ АНГАР • СЕВЕР', 'warehouse', (650, 414)), ('МЕХПОСТ', 'repair_bay', (166, 94)), ('ПОГРУЗОЧНАЯ', 'utility_house', (162, 94))],
        '0,1': [('РЕМОНТНЫЙ БОКС', 'repair_bay', (320, 232)), ('АВТОПАРК • СКЛАД', 'warehouse', (286, 214)), ('ТОПЛИВНЫЙ ПОСТ', 'utility_house', (146, 96))],
        '1,1': [('АРСЕНАЛЬНЫЙ СКЛАД', 'mil_store', (468, 344)), ('КОМЕНДАТУРА', 'factory_admin', (190, 236)), ('УЗЕЛ СВЯЗИ', 'comms', (150, 96))],
        '2,1': [('ГЛАВНЫЙ АНГАР • ЮГ', 'warehouse', (650, 414)), ('БОЕПРИПАСЫ', 'mil_store', (166, 94)), ('ОХРАНА АНГАРА', 'barracks', (162, 94))],
    },
    'vector': {
        '0,0': [('ВЕКТОР • ШАХТА ДОСТУПА', 'checkpoint', (590, 350)), ('ПОСТ ДОПУСКА', 'comms', (170, 206)), ('АВАРИЙНЫЙ ЗАПАС', 'warehouse', (178, 104))],
        '1,0': [('УЗЕЛ ОХРАНЫ', 'barracks', (420, 310)), ('СВЯЗЬ И КОНТРОЛЬ', 'comms', (190, 220)), ('ТЕХШКАФ', 'utility_house', (150, 96))],
        '0,1': [('ЭНЕРГОБЛОК', 'repair_bay', (340, 248)), ('НАСОСНАЯ', 'workshop', (294, 230)), ('РЕЗЕРВ ПИТАНИЯ', 'utility_house', (152, 100))],
        '1,1': [('КОМАНДНЫЙ БЛОК', 'factory_admin', (400, 300)), ('СЕРВЕРНАЯ', 'comms', (194, 218)), ('РЕЗЕРВ СВЯЗИ', 'mil_store', (218, 110))],
        '0,2': [('СЕРВИСНЫЙ ШЛЮЗ', 'service_shop', (324, 234)), ('АВАРИЙНЫЙ СКЛАД', 'warehouse', (290, 216)), ('ВЕНТУЗЕЛ', 'utility_house', (152, 98))],
        '1,2': [('ИНЖЕНЕРНОЕ ЯДРО', 'workshop', (450, 330)), ('АВТОНОМНЫЙ РЕЗЕРВ', 'mil_store', (186, 224)), ('КОНТРОЛЬ СИСТЕМ', 'comms', (170, 106))],
    },
}
SITE_POI = {'clinic': 'regional_clinical_complex_4', 'quarantine': 'quarantine_center_12',
            'bastion': 'reserve_arsenal_bastion', 'vector': 'underground_object_vector'}
SITE_LEAF = {'clinic': 3, 'quarantine': 3, 'bastion': 1, 'vector': 2}

TILE_BAND = (150, 172, 160)       # soviet hospital green tile band
RED = (168, 46, 40)


def door_x(arch, W):
    return max(-0.31 * W, min(0.31 * W, ARCH_DOOR.get(arch, 0.0) * W))


class HB(B):
    WINDOW_WEAR = dict(B.WINDOW_WEAR)
    # broken, boarded, plywood, sandbags, taped, stovepipe
    WINDOW_WEAR.update({
        'clinic': (0.34, 0.08, 0.04, 0.0, 0.0, 0.0),
        'quarantine': (0.18, 0.12, 0.16, 0.0, 0.0, 0.0),
        'bastion': (0.20, 0.06, 0.06, 0.30, 0.0, 0.02),
        'vector': (0.30, 0.04, 0.10, 0.0, 0.0, 0.0),
    })

    def __init__(self, site, cell, idx, H, wall, plinth=(96, 94, 88), plinth_h=6.0):
        sign, arch, (W, D) = SPECS[site][cell][idx]
        mid = 'hr_%s_%s_b%d' % (site, cell.replace(',', ''), idx)
        seed = zlib.crc32(mid.encode()) % 100000 + 7
        super().__init__(mid, W, D, H, wall, seed, arch, plinth=plinth, plinth_h=plinth_h)
        self.rng = random.Random(seed)
        self.style = site
        self.site = site
        self.sign_text = sign
        self.dx = door_x(arch, W)


    def flat(self, *a, **k):
        super().flat(*a, **k)
        self.auto_roof()

    def hip(self, *a, **k):
        super().hip(*a, **k)
        self.pitched_life()

    def gable(self, *a, **k):
        r = super().gable(*a, **k)
        self.pitched_life()
        return r

    def pitched_life(self):
        r = self.rng
        # rows of vent pipes, dormers on big roofs, moss and missing sheets
        for i in range(int(self.W // 60)):
            x = self.x0 + (i + 0.5) * self.W / int(self.W // 60)
            self.pipe(x, self.D * 0.18, 7, 1.8)
        if self.W > 300:
            for i in range(3):
                x = self.x0 + self.W * (0.2 + 0.3 * i)
                self.roof_patch(x, self.D * 0.25, 30, 16, r.choice(['tin_grey', 'steel_rust', 'tarp_green']))
        for _ in range(int(self.W * self.D / 14000)):
            x, y = r.uniform(self.x0 + 14, self.x1 - 14), r.uniform(self.y0 + 10, self.y1 - 10)
            z = self.roof_z(x, y) + 0.4
            pts = [V(x + math.cos(t) * r.uniform(6, 16), y + math.sin(t) * r.uniform(3, 8), z) for t in np.linspace(0, 2 * math.pi, 9, endpoint=False)]
            self.m.poly3(pts, r.choice([(72, 86, 48), (90, 96, 56), (40, 40, 38)]), 'none', bias=164, outline=False)
        if r.random() < 0.6:
            self.sapling(r.uniform(self.x0 + 30, self.x1 - 30), self.D * 0.2, None, 16)

    # ------------------------------------------------------------- roofscape --
    def roof_tier(self, x0, x1, y0, y1, h, mat='concrete_s', top=((74, 76, 74), 'tar')):
        """a raised upper storey set back on the roof (breaks the big flat plate)"""
        z = self.H
        f = self.m.box(x0, x1, y0, y1, z, z + h, mat, top=top, bias=150)
        self.m.box(x0, x1, y1 - 2.5, y1, z + h, z + h + 3, (MAT[mat][0], 'none'), bias=152)
        self.m.box(x0, x1, y0, y0 + 2.5, z + h, z + h + 3, (MAT[mat][0], 'none'), bias=151)
        k = 0
        for a in np.arange(10, x1 - x0 - 12, 26):
            self.m.window(f['front'], a, h * 0.3, 12, h * 0.42, style='strip', frame_col=(170, 170, 160))
            if self.rng.random() < 0.35:
                f['front'].decals.append(('broken', dict(u=a, v=h * 0.3, w=12, h=h * 0.42)))
            k += 1
        prev = self.roof_fn
        self.roof_fn = lambda x, y, prev=prev: (z + h) if (x0 < x < x1 and y0 < y < y1) else prev(x, y)
        return f

    def light_well(self, x, y, w, d):
        """glazed atrium lantern over an inner courtyard (half its panes gone)"""
        z = self.roof_z(x, y)
        self.m.box(x - w / 2, x + w / 2, y - d / 2, y + d / 2, z, z + 5, ((150, 150, 144), 'none'), bias=170)
        rise = d * 0.35
        for side, (ya, yb) in enumerate(((y + d / 2, y), (y - d / 2, y))):
            n = int(w // 10)
            for i in range(n):
                xa, xb = x - w / 2 + i * w / n, x - w / 2 + (i + 1) * w / n
                broken = self.rng.random() < 0.45
                col = (26, 28, 30) if broken else ((120, 150, 160) if side == 0 else (96, 122, 132))
                self.m.poly3([V(xa + 0.5, ya, z + 5), V(xb - 0.5, ya, z + 5), V(xb - 0.5, yb, z + 5 + rise), V(xa + 0.5, yb, z + 5 + rise)],
                             col, 'none', bias=171 + side * 0.5 + i * 0.001)
        self.m.line3([V(x - w / 2, y, z + 5 + rise), V(x + w / 2, y, z + 5 + rise)], (180, 182, 176), 2, bias=173)
        prev = self.roof_fn
        self.roof_fn = lambda xx, yy, prev=prev: (z + 5 + rise) if (abs(xx - x) < w / 2 and abs(yy - y) < d / 2) else prev(xx, yy)

    def skylights(self, x0, x1, y, n, w=14.0, d=10.0):
        for i in range(n):
            x = x0 + (x1 - x0) * (i + 0.5) / n
            z = self.roof_z(x, y)
            broken = self.rng.random() < 0.4
            col = (40, 44, 46) if broken else (110, 140, 150)
            self.m.box(x - w / 2, x + w / 2, y - d / 2, y + d / 2, z, z + 3, ((150, 150, 144), 'none'), bias=175)
            self.m.poly3([V(x - w / 2 + 1, y + d / 2 - 1, z + 3.2), V(x + w / 2 - 1, y + d / 2 - 1, z + 3.2), V(x + w / 2 - 1, y - d / 2 + 1, z + 6), V(x - w / 2 + 1, y - d / 2 + 1, z + 6)],
                         col, 'glass' if not broken else 'none', bias=176, frame=(V(x - w / 2, y + d / 2, z + 3), V(1, 0, 0), norm3(V(0, -d, 3))))

    def duct(self, xa, ya, xb, yb, r=3.0):
        za, zb = self.roof_z(xa, ya) + r, self.roof_z(xb, yb) + r
        self.m.line3([V(xa, ya, za), V(xb, yb, zb)], (150, 152, 148), int(r * 1.4), bias=180)
        self.m.line3([V(xa, ya + 1, za + r * 0.6), V(xb, yb + 1, zb + r * 0.6)], (186, 188, 184), 1, bias=181)

    def sapling(self, x, y, z=None, h=18.0):
        z = self.roof_z(x, y) if z is None else z
        self.m.line3([V(x, y, z), V(x, y, z + h)], (200, 196, 180), 1, bias=240)
        leaves = [(196, 150, 52), (170, 120, 40), (120, 130, 60), (210, 170, 70)]
        for i in range(7):
            a = self.rng.uniform(0, 2 * math.pi)
            rr = self.rng.uniform(1, 6)
            self.m.cyl(x + math.cos(a) * rr, y + math.sin(a) * rr * 0.6, z + h * self.rng.uniform(0.55, 1.0), z + h * self.rng.uniform(0.55, 1.0) + 3,
                       self.rng.uniform(2.5, 4.5), (self.rng.choice(leaves), 'none'), segs=8, bias=241 + i * 0.01)

    def roof_life(self, density=1.0):
        """membrane seams, puddles, moss, junk and saplings over a flat roof"""
        r = self.rng
        area = self.W * self.D
        for _ in range(int(area / 9000 * density)):
            x, y = r.uniform(self.x0 + 12, self.x1 - 12), r.uniform(self.y0 + 10, self.y1 - 10)
            z = self.roof_z(x, y) + 0.25
            kind = r.random()
            if kind < 0.35:    # puddle
                pts = [V(x + math.cos(a) * r.uniform(6, 16), y + math.sin(a) * r.uniform(4, 9), z) for a in np.linspace(0, 2 * math.pi, 10, endpoint=False)]
                self.m.poly3(pts, (58, 70, 80), 'none', bias=164, outline=False)
            elif kind < 0.6:   # moss / dirt drift
                pts = [V(x + math.cos(a) * r.uniform(8, 22), y + math.sin(a) * r.uniform(5, 12), z) for a in np.linspace(0, 2 * math.pi, 10, endpoint=False)]
                self.m.poly3(pts, r.choice([(72, 86, 48), (80, 70, 52), (90, 96, 56)]), 'earth', bias=163, outline=False,
                             frame=(V(x - 20, y + 12, z), V(1, 0, 0), V(0, -1, 0)))
            elif kind < 0.75:  # sapling
                self.sapling(x, y, None, r.uniform(12, 22))
            elif kind < 0.9:   # junk: crates, a mattress, a chair
                w, d = r.uniform(4, 10), r.uniform(3, 7)
                self.m.box(x - w, x + w, y - d, y + d, z, z + r.uniform(1.5, 5), (r.choice([(120, 96, 66), (150, 140, 120), (90, 100, 110)]), 'none'), bias=185)
            else:              # membrane seam strip
                self.m.poly3([V(x - 40, y + 1.5, z), V(x + 40, y + 1.5, z), V(x + 40, y - 1.5, z), V(x - 40, y - 1.5, z)], (44, 46, 46), 'none', bias=162, outline=False)

    def auto_roof(self, rich=True):
        """big flat roofs get tiers, wells, skylights and ducts so they never read as one plate"""
        if self.D < 180 or self.W < 200:
            self.roof_life(0.8)
            return
        r = self.rng
        # raised tier along the north edge, about a third of the width
        tw = self.W * r.uniform(0.32, 0.45)
        tx = r.choice([self.x0 + tw / 2 + 14, self.x1 - tw / 2 - 14])
        self.roof_tier(tx - tw / 2, tx + tw / 2, self.y0 + 10, self.y0 + 10 + self.D * 0.34, 26, top=((74, 76, 74), 'tar'))
        if rich:
            lx = -tx * 0.55
            self.light_well(lx, self.y0 + self.D * 0.52, min(110, self.W * 0.24), 54)
            self.lantern_x = lx
        self.skylights(self.x0 + 30, self.x1 - 30, self.y1 - 40, max(3, int(self.W // 70)))
        self.duct(self.x0 + 20, self.y1 - 22, self.x1 - 30, self.y1 - 22)
        self.roof_life(1.4)

    # ------------------------------------------------------------------ helpers --
    def storeys(self, n, floor_h, w, h, step, first=10.0, style='frame', frame=(200, 198, 186), glass=(48, 62, 70),
                bars_ground=False, lit=0.0, band=None, skip_cols=(), x_from=None, x_to=None):
        for k in range(n):
            v = first + k * floor_h
            if v + h > self.H - 4:
                break
            self.windows(v, w, h, step, style=style, frame=frame, glass=glass, bars=bars_ground and k == 0,
                         lit_chance=lit, avoid_openings=(k == 0), skip=skip_cols, x_from=x_from, x_to=x_to)
            if band and k > 0:
                self.m.rect(self.front, 0, v - 5, self.W, 2.5, band)

    def penthouse(self, x, y, w, d, h, mat='concrete_s', door=True):
        z = self.roof_z(x, y)
        f = self.m.box(x - w / 2, x + w / 2, y - d / 2, y + d / 2, z, z + h, mat, bias=200)
        if door:
            self.m.rect(f['front'], w * 0.6, 0, 6, min(10, h - 2), (40, 38, 34))
        return f

    def hvac(self, x, y, w=16, d=10, h=7):
        z = self.roof_z(x, y)
        f = self.m.box(x - w / 2, x + w / 2, y - d / 2, y + d / 2, z, z + h, ((148, 150, 146), 'none'), bias=205)
        pts = [V(x + math.cos(a) * d * 0.32, y + math.sin(a) * d * 0.32, z + h + 0.3) for a in np.linspace(0, 2 * math.pi, 12)]
        self.m.poly3(pts, (60, 62, 60), 'none', bias=206)
        return f

    def helipad(self, x, y, r=30.0):
        z = self.roof_z(x, y) + 0.4
        ring = [V(x + math.cos(a) * r, y + math.sin(a) * r, z) for a in np.linspace(0, 2 * math.pi, 28, endpoint=False)]
        self.m.poly3(ring, (196, 170, 60), 'none', bias=160, outline=False)
        inner = [V(x + math.cos(a) * (r - 3), y + math.sin(a) * (r - 3), z + 0.1) for a in np.linspace(0, 2 * math.pi, 28, endpoint=False)]
        self.m.poly3(inner, (70, 72, 70), 'none', bias=161, outline=False)
        hw, hh = r * 0.42, r * 0.6
        for (x0, x1, y0, y1) in ((-hw, -hw + 4, -hh, hh), (hw - 4, hw, -hh, hh), (-hw, hw, -2, 2)):
            self.m.poly3([V(x + x0, y + y1, z + 0.2), V(x + x1, y + y1, z + 0.2), V(x + x1, y + y0, z + 0.2), V(x + x0, y + y0, z + 0.2)],
                         (226, 224, 214), 'none', bias=162, outline=False)
        for a in np.linspace(0, 2 * math.pi, 8, endpoint=False):
            self.m.cyl(x + math.cos(a) * (r + 3), y + math.sin(a) * (r + 3), z, z + 1.6, 1.2, ((220, 60, 40), 'none'), segs=6, bias=163)

    def dome(self, x, y, r=16.0, col=(212, 212, 204)):
        z = self.roof_z(x, y)
        self.m.cyl(x, y, z, z + 4, r * 0.9, ((120, 120, 114), 'none'), bias=200)
        for k in range(6):
            t0, t1 = k / 6, (k + 1) / 6
            rr = r * math.cos(t0 * math.pi / 2)
            self.m.cyl(x, y, z + 4 + r * math.sin(t0 * math.pi / 2), z + 4 + r * math.sin(t1 * math.pi / 2), rr,
                       (dark(col, 0.86 + 0.03 * k), 'none'), segs=16, bias=201 + k * 0.1)

    def tank(self, x, y, r, h, mat='steel', legs=0.0):
        z = self.roof_z(x, y) + legs
        if legs:
            for dx, dy in ((-r * 0.7, -r * 0.5), (r * 0.7, -r * 0.5), (-r * 0.7, r * 0.5), (r * 0.7, r * 0.5)):
                self.m.line3([V(x + dx, y + dy, z - legs), V(x + dx, y + dy, z)], (70, 72, 70), 2, bias=199)
        self.m.cyl(x, y, z, z + h, r, mat, segs=16, bias=200)

    def vent_stack(self, x, y, h=30.0, r=4.0, steam=False):
        z = self.roof_z(x, y)
        self.m.cyl(x, y, z - 2, z + h, r, ((132, 134, 130), 'none'), segs=12, bias=210)
        self.m.cyl(x, y, z + h * 0.7, z + h * 0.7 + 3, r + 1, ((190, 60, 44), 'none'), segs=12, bias=211)
        if steam:
            self.steam.append((x, y - (z + h + 2)))

    def antenna_field(self, x0, x1, y, n=4, h=46.0):
        for i in range(n):
            x = x0 + (x1 - x0) * (i + 0.5) / n
            self.antenna(x, y, h * self.rng.uniform(0.75, 1.1))

    def collapse(self, x, y, w, d):
        """caved-in roof section: dark void, broken joists, rubble lip."""
        z0 = self.roof_z(x, y + d / 2) + 0.2
        z1 = self.roof_z(x, y - d / 2) + 0.2
        pts = []
        for i in range(12):
            a = 2 * math.pi * i / 12
            rr = self.rng.uniform(0.6, 1.0)
            py = y + math.sin(a) * d / 2 * rr
            pts.append(V(x + math.cos(a) * w / 2 * rr, py, z0 + (z1 - z0) * (0.5 - (py - y) / d)))
        self.m.poly3(pts, (16, 14, 12), 'none', bias=166)
        for i in range(4):
            jx = x - w * 0.35 + i * w * 0.24
            self.m.line3([V(jx, y + d * 0.42, z0 + 1), V(jx + self.rng.uniform(-4, 4), y - d * 0.3, z1 - 3)], (96, 74, 52), 2, bias=167)
        for i in range(10):
            a = self.rng.uniform(0, 2 * math.pi)
            px, py = x + math.cos(a) * w * 0.55, y + math.sin(a) * d * 0.55
            self.m.box(px - 2, px + 2, py - 1.5, py + 1.5, self.roof_z(px, py), self.roof_z(px, py) + 2,
                       (self.rng.choice([(150, 148, 138), (138, 80, 60), (110, 108, 100)]), 'none'), bias=168)

    def scorch(self, n=2):
        for _ in range(n):
            spot = self._free_wall_spot(24, 20, 10)
            if spot:
                self.front.decals.append(('soot', dict(u=spot[0] - 4, v=spot[1], w=30, h=self.H - spot[1])))

    def breach(self, n=1, size=(18, 16)):
        for _ in range(n):
            spot = self._free_wall_spot(size[0], size[1], 6)
            if spot:
                self.front.decals.append(('breach', dict(u=spot[0], v=spot[1], w=size[0], h=size[1])))

    def _wall_free(self, u, v, w, h, pad=2.0):
        if u < 2 or u + w > self.W - 2 or v < 2 or v + h > self.H - 2:
            return False
        blocked = list(self.win_rects) + [(self.fu(x) - ow, 0, ow * 2, DOOR_H + 6) for x, ow in self.opening_xs] + list(self.blockers)
        return not any(u < bu + bw + pad and u + w > bu - pad and v < bv + bh + pad and v + h > bv - pad for (bu, bv, bw, bh) in blocked)

    def _slide(self, u, v, w, h):
        """nearest free wall spot to (u, v): signs and paint go between windows, not over them"""
        for dv in (0, -4, 4, -8, 8, -12, 12):
            for du in sorted(range(-90, 91, 3), key=abs):
                if self._wall_free(u + du, v + dv, w, h):
                    return u + du, v + dv
        return None

    def hazard(self, x, z, sym='bio', s=10.0):
        # one warning plate per building is enough
        if getattr(self, '_hazard_done', False):
            return
        self._hazard_done = True
        spot = self._slide(self.fu(x) - s / 2, z, s, s)
        if spot:
            self.front.decals.append(('hazard', dict(u=spot[0], v=spot[1], s=s, sym=sym)))
            self.win_rects.append((spot[0], spot[1], s, s))

    def slogan(self, x, z, w, h=8.0, col=(180, 40, 34)):
        """hand-painted warning: only where the wall is clear"""
        spot = self._slide(self.fu(x) - w / 2, z, w, h)
        if spot:
            self.front.decals.append(('graffiti', dict(u=spot[0], v=spot[1], w=w, h=h, col=col, underline=True)))
            self.win_rects.append((spot[0], spot[1], w, h))

    def stripes(self, x, z, w, h=4.0, c1=(206, 164, 44), c2=(36, 36, 34)):
        self.front.decals.append(('stripe', dict(u=self.fu(x) - w / 2, v=z, w=w, h=h, c1=c1, c2=c2, period=8)))

    def plastic_windows(self, chance=0.5):
        for (u, v, w, h) in list(self.win_rects):
            if self.rng.random() < chance:
                self.front.decals.append(('plastic', dict(u=u, v=v, w=w, h=h)))

    def rubble_front(self, n=6):
        for _ in range(n):
            x = self.rng.uniform(self.x0 + 8, self.x1 - 8)
            if abs(x - self.dx) < 18:
                continue
            w = self.rng.uniform(3, 7)
            self.m.box(x - w, x + w, self.y1 + 1, self.y1 + 5, 0, self.rng.uniform(2, 5),
                       (self.rng.choice([(150, 148, 138), (138, 80, 60), (112, 108, 100)]), 'none'), bias=50)

    def roof_sign(self, x, y, text_w=60.0, col=(40, 44, 42)):
        """big letters on a rooftop frame (no text: a lit panel + frame)."""
        z = self.roof_z(x, y)
        for dx in (-text_w / 2 + 4, text_w / 2 - 4):
            self.m.line3([V(x + dx, y, z), V(x + dx, y, z + 14)], (70, 70, 70), 1, bias=215)
        f = Face(V(x - text_w / 2, y + 0.2, z + 10), V(1, 0, 0), V(0, 0, 1), text_w, 9, col, 'none', bias=216)
        self.m.add(f)
        return f


# ===================================================================== CLINIC ==
def clinic_tile(b):
    b.band(0, 14, TILE_BAND)
    b.m.rect(b.front, 0, 13.4, b.W, 1.2, dark(TILE_BAND, 0.7))


def c_emergency():
    b = HB('clinic', '0,0', 1, 46, 'plaster')
    clinic_tile(b)
    b.door(b.dx, canopy=('tin_grey', 16))
    b.windows(16, 16, 18, 30, frame=(220, 220, 212))
    b.stripes(b.dx, 40, 60, 4, RED, (226, 224, 214))
    b.flat('tar', 'plaster', 4)
    b.roof_cross(30, 0, 9)
    b.hvac(-40, -20)
    b.scorch(1)
    return b


def c_guard():
    b = HB('clinic', '0,0', 2, 40, 'brick_dark')
    b.door(b.dx)
    b.windows(16, 14, 14, 26, bars=True, x_from=-55, x_to=0)
    b.flat('tar', 'brick_dark', 3)
    b.antenna(-30, -10, 26)
    b.m.box(-50, -30, b.y1, b.y1 + 8, 0, 12, 'sandbag', bias=58)
    return b


def c_diagnostics():
    b = HB('clinic', '1,0', 0, 122, 'plaster', plinth=(110, 116, 110), plinth_h=10)
    clinic_tile(b)
    b.door(b.dx, canopy=('concrete_s', 22))
    b.storeys(4, 28, 34, 16, 42, first=16, style='strip', frame=(206, 206, 196), band=(176, 180, 170), lit=0.04)
    b.signboard(b.dx, 112, 140, 9, col=(36, 52, 48), border=(200, 196, 170))
    b.flat('tar', 'plaster', 6)
    b.penthouse(-120, -60, 60, 40, 22)
    b.penthouse(110, -80, 40, 30, 16)
    for x in (-40, 0, 40):
        b.hvac(x, 30, 22, 14, 9)
    b.collapse(140, 40, 70, 50)
    b.roof_cross(-120, 40, 14)
    b.scorch(3)
    b.breach(1, (26, 20))
    b.rubble_front(8)
    return b


def c_radiology():
    b = HB('clinic', '1,0', 1, 64, 'concrete_s', plinth=(110, 110, 104))
    b.band(0, 64, (156, 154, 144))
    b.door(b.dx, frame=(70, 70, 66))
    for k in range(4):
        b.m.rect(b.front, 14 + k * 46, 48, 30, 5, (40, 44, 46))          # slit lights
    b.hazard(50, 26, 'rad', 14)
    b.hazard(-80, 26, 'rad', 10)
    b.flat('tar', 'concrete_s', 6)
    for x in (-50, 0, 50):
        b.vent_stack(x, -40, 22, 5)
    b.hvac(40, 40, 30, 20, 10)
    b.scorch(1)
    return b


def c_archive():
    b = HB('clinic', '1,0', 2, 44, 'brick')
    b.door(b.dx)
    b.windows(18, 12, 16, 26, bars=True)
    b.gable('slate', 22)
    b.collapse(-30, 10, 40, 30)
    b.m.box(-40, -10, b.y1 + 2, b.y1 + 10, 0, 6, ((214, 208, 186), 'none'), bias=52)   # spilled files
    return b


def c_garage():
    b = HB('clinic', '2,0', 0, 58, 'plaster_y')
    b.band(0, 12, (110, 104, 92))
    b.door(b.dx)
    for x in (-110, -50):
        b.gate(x, 50, 40, col=(120, 124, 124))
    b.m.rect(b.front, b.fu(-80) - 64, 42, 128, 3, (40, 40, 38))
    b.stripes(-80, 0, 120, 4)
    b.windows(46, 14, 8, 26, style='strip', avoid_openings=False, x_from=10, x_to=140)
    b.gable('tin_grey', 20)
    b.roof_patch(-60, 20, 50, 28, 'steel_rust')
    b.collapse(60, -20, 50, 34)
    return b


def c_oxygen():
    b = HB('clinic', '2,0', 1, 50, 'steel')
    b.door(b.dx)
    b.gate(-60, 60, 42, col=(70, 100, 130))
    b.stripes(-60, 0, 70, 4, (60, 120, 170), (226, 226, 220))
    b.flat('tar', 'concrete_s', 3)
    for i, x in enumerate((-90, -40, 10, 60)):
        b.tank(x, -30, 14, 46 + (i % 2) * 8, ((206, 210, 214), 'none'), legs=6)
    b.m.line3([V(-110, -14, b.H + 36), V(80, -14, b.H + 36)], (120, 124, 124), 2, bias=230)
    b.rust = 0.14
    return b


def c_dispatch():
    b = HB('clinic', '2,0', 2, 46, 'plaster')
    clinic_tile(b)
    b.door(b.dx)
    b.windows(16, 16, 16, 28, x_from=-80, x_to=10)
    b.flat('tar', 'plaster', 3)
    f = b.penthouse(-30, -10, 46, 36, 22, door=False)
    b.m.add(Face(V(-52, 8.2, b.H + 8), V(1, 0, 0), V(0, 0, 1), 44, 10, (70, 96, 104), 'glass', bias=203))
    b.mast(40, -20, 52)
    return b


def c_ward_a():
    b = HB('clinic', '0,1', 0, 124, 'plaster', plinth=(110, 116, 110), plinth_h=10)
    clinic_tile(b)
    b.door(b.dx, canopy=('tin_green', 20))
    b.storeys(4, 28, 16, 18, 30, first=16, frame=(220, 220, 212), band=(180, 184, 174), lit=0.05)
    # loggia balconies on floors 2-4, one burnt out
    for k in range(1, 4):
        z = 14 + k * 28
        for x in (-150, -60, 60, 150):
            if abs(x - b.dx) < 30 and k == 0:
                continue
            b.m.box(x - 26, x + 26, b.y1, b.y1 + 7, z, z + 2, ((190, 192, 184), 'none'), bias=55 + k)
            b.m.box(x - 26, x + 26, b.y1 + 6, b.y1 + 7, z + 2, z + 9, ((120, 132, 124), 'none'), bias=56 + k)
    b.hip('tin_green', 40)
    b.collapse(-110, 20, 80, 50)
    b.chimney(160, -40, 16, mat='plaster')
    b.scorch(3)
    b.rubble_front(8)
    return b


def c_ward_b():
    b = HB('clinic', '0,1', 1, 100, 'plaster', plinth=(110, 116, 110), plinth_h=8)
    clinic_tile(b)
    b.door(b.dx)
    b.storeys(3, 28, 18, 18, 34, first=16, frame=(220, 220, 212), band=(180, 184, 174))
    b.flat('tar', 'plaster', 5)
    b.penthouse(0, -60, 50, 34, 18)
    b.tank(40, 60, 12, 24, ((140, 140, 136), 'none'), legs=10)
    b.scorch(2)
    return b


def c_nurse():
    b = HB('clinic', '0,1', 2, 42, 'plaster_g')
    b.door(b.dx, canopy=('tin_green', 10))
    b.windows(16, 16, 16, 28, x_from=-10, x_to=70)
    b.front.decals.append(('cross', dict(u=b.fu(b.dx), v=36, s=4, col=RED, disc=(230, 230, 222))))
    b.gable('tin_green', 20)
    return b


def c_isolation():
    b = HB('clinic', '1,1', 0, 96, 'plaster', plinth=(110, 116, 110), plinth_h=10)
    clinic_tile(b)
    b.door(b.dx, frame=(110, 90, 40))
    b.storeys(3, 28, 22, 16, 40, first=16, bars_ground=True, frame=(206, 206, 196), band=(176, 180, 170))
    b.plastic_windows(0.7)
    for x in (-180, 180):
        b.hazard(x, 40, 'bio', 14)
    b.stripes(b.dx, 0, 80, 5, (206, 170, 44), (36, 36, 34))
    b.flat('tar', 'plaster', 6)
    for x in (-150, -70, 70, 150):
        b.vent_stack(x, -80, 26, 5, steam=(x == -70))
    for x in (-110, 110):
        b.hvac(x, 40, 30, 20, 10)
    b.collapse(20, 20, 60, 40)
    return b


def c_postop():
    b = HB('clinic', '1,1', 1, 78, 'plaster')
    clinic_tile(b)
    b.door(b.dx)
    b.storeys(2, 28, 18, 18, 34, first=16, frame=(220, 220, 212))
    b.flat('tar', 'plaster', 4)
    b.hvac(0, -40, 26, 16, 8)
    b.roof_cross(0, 40, 12)
    b.scorch(1)
    return b


def c_sluice():
    b = HB('clinic', '1,1', 2, 40, 'container_g', plinth=None)
    b.door(b.dx)
    b.hazard(-40, 20, 'bio', 12)
    b.windows(18, 14, 10, 26, x_from=-60, x_to=-10)
    b.plastic_windows(1.0)
    b.flat('tar', None, 0)
    return b


def c_surgical():
    b = HB('clinic', '2,1', 0, 104, 'plaster', plinth=(110, 116, 110), plinth_h=10)
    clinic_tile(b)
    b.door(b.dx, canopy=('concrete_s', 24))
    b.storeys(3, 30, 40, 16, 50, first=18, style='strip', frame=(206, 206, 196), band=(176, 180, 170))
    b.signboard(b.dx, 94, 160, 9, col=(36, 52, 48), border=(200, 196, 170))
    b.flat('tar', 'plaster', 6)
    b.helipad(80, -20, 52)
    b.penthouse(-150, -60, 70, 44, 20)
    b.hvac(-150, 50, 30, 18, 10)
    b.mast(-190, 60, 40)
    b.scorch(2)
    b.rubble_front(6)
    return b


def c_sterile():
    b = HB('clinic', '2,1', 1, 62, 'plaster_g')
    b.door(b.dx)
    b.windows(22, 26, 14, 40, style='strip', bars=True)
    b.hazard(50, 44, 'bio', 10)
    b.flat('tar', 'plaster', 4)
    b.hvac(0, -30, 30, 20, 10)
    return b


def c_icu():
    b = HB('clinic', '2,1', 2, 72, 'plaster')
    clinic_tile(b)
    b.door(b.dx, canopy=('tin_green', 14))
    b.storeys(2, 28, 22, 18, 36, first=16, frame=(220, 220, 212), lit=0.08)
    b.flat('tar', 'plaster', 4)
    b.hvac(-60, -30)
    b.hvac(40, -30)
    b.roof_cross(0, 30, 10)
    return b


# ================================================================= QUARANTINE ==
def prefab(b, rows, panel=36.0, col=(186, 190, 182)):
    """modular sandwich-panel joints over the whole facade"""
    a = panel
    while a < b.W:
        b.m.rect(b.front, a, 0, 1.2, b.H, dark(col, 0.72))
        a += panel
    for k in range(1, rows):
        b.m.rect(b.front, 0, b.H * k / rows, b.W, 1.2, dark(col, 0.72))


def q_gate():
    b = HB('quarantine', '0,0', 0, 50, 'concrete_s')
    b.band(0, 50, (170, 160, 120))
    b.door(b.dx, frame=(80, 80, 76))
    b.windows(20, 30, 16, 44, style='strip', bars=True, x_from=-20, x_to=90)
    b.stripes(0, 40, b.W, 5, (206, 170, 44), (36, 36, 34))
    b.hazard(70, 6, 'bio', 12)
    b.flat('tar', 'concrete_s', 4)
    b.m.box(-90, -60, b.y1 + 2, b.y1 + 10, 0, 14, 'sandbag', bias=58)
    b.mast(60, -30, 46)
    return b


def q_triage():
    # big membrane hall on a steel frame: emergency triage set up in the first days
    b = HB('quarantine', '0,0', 1, 34, 'tarp_grey', plinth=(90, 90, 84), plinth_h=4)
    b.door(b.dx, frame=(80, 80, 76))
    for x in range(int(b.x0) + 30, int(b.x1), 60):
        b.m.rect(b.front, b.fu(x), 0, 2, b.H, (80, 84, 84))
    b.windows(18, 20, 10, 60, style='strip', frame=(140, 146, 144), glass=(150, 170, 170))
    b.front.decals.append(('cross', dict(u=b.fu(b.dx) + 40, v=24, s=6, col=RED, disc=(226, 226, 220))))
    b.gable('tarp_grey', 50, over=4)
    b.roof_cross(-80, 30, 16)
    b.roof_patch(60, -40, 60, 40, 'tarp_blue')
    b.vent_stack(120, -60, 20, 4, steam=True)
    b.grime = 0.14
    return b


def q_desk():
    b = HB('quarantine', '0,0', 2, 40, 'container_b', plinth=None)
    b.door(b.dx)
    b.windows(16, 18, 14, 30, x_from=-60, x_to=0)
    b.plastic_windows(0.8)
    b.hazard(-40, 20, 'bio', 10)
    b.flat('tar', None, 0)
    b.tank(-30, -10, 10, 18, ((210, 210, 200), 'none'))
    return b


def q_isolator_a():
    b = HB('quarantine', '1,0', 0, 92, 'silicate', plinth=(110, 110, 100), plinth_h=8)
    b.door(b.dx, frame=(110, 90, 40))
    b.storeys(3, 28, 18, 18, 34, first=14, bars_ground=True, frame=(190, 190, 180), band=(150, 150, 140))
    b.plastic_windows(0.75)
    b.stripes(b.dx, 0, 80, 5, (206, 170, 44), (36, 36, 34))
    for x in (-200, 200):
        b.hazard(x, 50, 'bio', 16)
    # hand-painted warning across the facade
    b.slogan(-150, 70, 70, 7)
    b.flat('tar', 'concrete_s', 5)
    for x in (-180, -60, 60, 180):
        b.vent_stack(x, -70, 22, 4, steam=(x == 60))
    b.roof_patch(-100, 30, 80, 50, 'tarp_grey')
    b.collapse(120, 40, 50, 36)
    return b


def q_watch():
    b = HB('quarantine', '1,0', 1, 70, 'concrete_s')
    b.door(b.dx)
    b.windows(44, 40, 12, 56, style='strip', avoid_openings=False, frame=(150, 150, 146))
    b.flat('tar', 'concrete_s', 4)
    f = b.penthouse(0, 0, 70, 60, 22, door=False)
    b.m.add(Face(V(-34, 30.2, b.H + 8), V(1, 0, 0), V(0, 0, 1), 68, 10, (70, 96, 104), 'glass', bias=203))
    b.m.line3([V(-35, 32, b.H + 30), V(35, 32, b.H + 30)], (80, 82, 80), 1, bias=204)
    b.m.cyl(30, 20, b.H + 22, b.H + 28, 4, ((60, 62, 60), 'none'), bias=205)   # searchlight
    return b


def q_sanpass():
    b = HB('quarantine', '1,0', 2, 40, 'container_g', plinth=None)
    b.door(b.dx)
    b.windows(16, 16, 12, 30, x_from=-60, x_to=0)
    b.plastic_windows(1.0)
    b.stripes(0, 34, b.W, 4, (206, 170, 44), (36, 36, 34))
    b.flat('tar', None, 0)
    return b


def q_lab():
    b = HB('quarantine', '2,0', 0, 96, 'concrete', plinth=(110, 110, 104), plinth_h=8)
    b.door(b.dx, canopy=('concrete_s', 18))
    b.storeys(3, 28, 42, 14, 54, first=16, style='strip', frame=(170, 172, 168), band=(120, 122, 118))
    b.plastic_windows(0.35)
    b.hazard(-180, 40, 'bio', 16)
    b.hazard(180, 40, 'rad', 12)
    b.flat('tar', 'concrete_s', 5)
    for x in (-160, -110):
        b.vent_stack(x, -60, 34, 6, steam=(x == -160))
    b.hvac(0, -40, 40, 24, 12)
    b.hvac(100, 40, 30, 20, 10)
    b.antenna_field(120, 220, -100, 3, 40)
    return b


def q_cold():
    b = HB('quarantine', '2,0', 1, 46, 'container_r', plinth=None)
    b.door(b.dx)
    b.m.rect(b.front, 0, 0, b.W / 2, b.H, (196, 200, 196))          # reefer container half
    for x in (-40, 40):
        b.m.box(x - 12, x + 12, b.y1, b.y1 + 3, 18, 32, ((150, 152, 148), 'none'), bias=55)   # reefer units
    b.flat('tar', None, 0)
    for x in (-40, 40):
        b.hvac(x, -40, 30, 20, 10)
    return b


def q_tech():
    b = HB('quarantine', '2,0', 2, 42, 'steel')
    b.door(b.dx)
    b.gate(-50, 50, 34, col=(110, 116, 116))
    b.flat('tar', 'concrete_s', 3)
    b.tank(-60, -10, 12, 22, ((160, 162, 156), 'none'))
    b.antenna(50, -20, 28)
    return b


def q_transport():
    b = HB('quarantine', '0,1', 0, 56, 'steel_olive')
    b.door(b.dx)
    for x in (-100, -40):
        b.gate(x, 50, 42, col=(90, 100, 66))
    b.front.decals.append(('cross', dict(u=b.fu(40), v=40, s=6, col=RED, disc=(230, 230, 222))))
    b.arch('steel_olive')
    b.rust = 0.14
    return b


def q_store():
    b = HB('quarantine', '0,1', 1, 34, 'steel', plinth=(90, 90, 84), plinth_h=4)
    b.door(b.dx)
    b.gate(-50, 70, 30, col=(120, 124, 124))
    b.arch('steel')
    b.rust = 0.2
    return b


def q_guard():
    b = HB('quarantine', '0,1', 2, 40, 'concrete_s')
    b.door(b.dx)
    b.windows(18, 24, 12, 34, style='strip', bars=True, x_from=-60, x_to=0)
    b.flat('tar', 'concrete_s', 3)
    b.m.box(-60, -30, b.y1 + 2, b.y1 + 10, 0, 14, 'sandbag', bias=58)
    b.antenna(-40, -10, 30)
    return b


def q_redzone():
    b = HB('quarantine', '1,1', 0, 98, 'concrete_s', plinth=(100, 100, 94), plinth_h=8)
    b.band(0, 98, (164, 152, 136))
    b.door(b.dx, frame=(150, 40, 36))
    b.storeys(3, 28, 18, 14, 40, first=16, bars_ground=True, frame=(140, 140, 132))
    b.plastic_windows(0.9)
    b.stripes(0, 0, b.W, 6, RED, (226, 224, 214))
    for x in (-180, -60, 60, 180):
        b.hazard(x, 70, 'bio', 16)
    b.slogan(60, 74, 60, 7, (200, 40, 34))
    b.flat('tar', 'concrete_s', 6)
    for x in (-160, -40, 80, 180):
        b.vent_stack(x, -60, 26, 5, steam=(x == 80))
    b.collapse(-80, 30, 70, 50)
    b.scorch(3)
    b.breach(2, (22, 18))
    b.rubble_front(10)
    return b


def q_isolator_b():
    b = HB('quarantine', '1,1', 1, 70, 'silicate')
    b.door(b.dx, frame=(110, 90, 40))
    b.storeys(2, 28, 18, 18, 34, first=14, bars_ground=True)
    b.plastic_windows(0.8)
    b.hazard(50, 50, 'bio', 12)
    b.flat('tar', 'concrete_s', 4)
    b.vent_stack(0, -50, 24, 5)
    return b


def q_airlock():
    b = HB('quarantine', '1,1', 2, 40, 'steel', plinth=None)
    b.door(b.dx, frame=(150, 40, 36))
    b.stripes(0, 0, b.W, 6, (206, 170, 44), (36, 36, 34))
    b.hazard(-40, 18, 'bio', 12)
    b.flat('tar', None, 0)
    b.tank(-30, -10, 8, 14, ((210, 210, 200), 'none'))
    return b


def q_sterile():
    b = HB('quarantine', '2,1', 0, 94, 'plaster_g', plinth=(110, 116, 110), plinth_h=8)
    b.door(b.dx, canopy=('tin_green', 18))
    b.storeys(3, 28, 20, 16, 36, first=16, frame=(220, 220, 212), band=(150, 168, 156))
    b.plastic_windows(0.5)
    b.hazard(180, 40, 'bio', 14)
    b.hip('tin_green', 36)
    b.collapse(80, 20, 60, 40)
    b.roof_cross(-120, 20, 14)
    return b


def q_clean():
    b = HB('quarantine', '2,1', 1, 56, 'plaster')
    b.door(b.dx)
    b.windows(22, 26, 14, 40, style='strip', bars=True)
    b.flat('tar', 'plaster', 4)
    b.hvac(0, -40, 30, 20, 10)
    return b


def q_inner_post():
    b = HB('quarantine', '2,1', 2, 40, 'concrete_s')
    b.door(b.dx)
    b.windows(18, 22, 12, 30, style='strip', bars=True, x_from=0, x_to=60)
    b.flat('tar', 'concrete_s', 3)
    b.m.box(20, 50, b.y1 + 2, b.y1 + 10, 0, 14, 'sandbag', bias=58)
    return b


# ==================================================================== BASTION ==
def earth_cover(b, rise=24.0, inset=12.0):
    """earth berm over the roof: two grassy slopes with tufts."""
    H = b.H
    em = MAT['earth'][0]
    b.m.poly3([V(b.x0 - 8, b.y1 + 2, H - 2), V(b.x1 + 8, b.y1 + 2, H - 2), V(b.x1 - inset, 0, H + rise), V(b.x0 + inset, 0, H + rise)],
              em, 'earth', bias=100, frame=(V(b.x0, b.y1, H), V(1, 0, 0), norm3(V(0, -b.D / 2, rise))))
    b.m.poly3([V(b.x0 + inset, 0, H + rise), V(b.x1 - inset, 0, H + rise), V(b.x1 + 8, b.y0 - 2, H - 2), V(b.x0 - 8, b.y0 - 2, H - 2)],
              dark(em, 0.88), 'earth', bias=99, frame=(V(b.x0, 0, H + rise), V(1, 0, 0), norm3(V(0, -b.D / 2, -rise))))
    b.roof_rise = rise
    b.roof_fn = lambda x, y: H + rise * max(0.0, 1 - abs(y) / (b.D / 2))
    # overgrown berm: patchy turf, bare earth, bushes, a few concrete vent caps
    r = b.rng
    for _ in range(int(b.W * b.D / 2500)):
        x, y = r.uniform(b.x0 + 10, b.x1 - 10), r.uniform(b.y0 + 6, b.y1 - 6)
        z = b.roof_z(x, y) + 0.4
        col = r.choice([(70, 88, 44), (84, 100, 52), (96, 84, 58), (60, 76, 40), (104, 108, 60)])
        pts = [V(x + math.cos(t) * r.uniform(5, 16), y + math.sin(t) * r.uniform(3, 9), z) for t in np.linspace(0, 2 * math.pi, 9, endpoint=False)]
        b.m.poly3(pts, col, 'none', bias=120, outline=False)
    for _ in range(int(b.W // 40)):
        x, y = r.uniform(b.x0 + 16, b.x1 - 16), r.uniform(b.y0 + 10, b.y1 - 10)
        z = b.roof_z(x, y)
        for i in range(4):
            a = r.uniform(0, 2 * math.pi)
            b.m.cyl(x + math.cos(a) * 3, y + math.sin(a) * 2, z, z + r.uniform(3, 6), r.uniform(3, 5.5),
                    (r.choice([(64, 82, 40), (90, 104, 50), (150, 110, 44), (120, 96, 40)]), 'none'), segs=8, bias=230 + i * 0.01)
    if r.random() < 0.7:
        b.sapling(r.uniform(b.x0 + 30, b.x1 - 30), r.uniform(-10, 10), None, 22)


def bunker_portal(b, x, w, h):
    """concrete portal frame around a blast door on the south face"""
    b.m.box(x - w / 2 - 8, x + w / 2 + 8, b.y1, b.y1 + 6, 0, h + 8, 'concrete', bias=60, cap=True)
    f = b.m.box(x - w / 2, x + w / 2, b.y1 + 6, b.y1 + 6.4, 0, h, ((84, 94, 70), 'corrugated_v'), bias=61, cap=False)
    return f


def b_gate():
    b = HB('bastion', '0,0', 0, 52, 'concrete', plinth=(100, 100, 94))
    b.door(b.dx, frame=(60, 60, 58))
    b.windows(22, 26, 12, 40, style='strip', bars=True, x_from=-20, x_to=80)
    b.stripes(0, 44, b.W, 6, RED, (226, 224, 214))
    b.flat('tar', 'concrete_s', 4)
    for x in (-80, 60):
        b.m.box(x - 14, x + 14, b.y1 + 2, b.y1 + 11, 0, 16, 'sandbag', bias=58)
    b.mast(60, -40, 48)
    b.m.cyl(-60, -20, b.H, b.H + 10, 5, ((60, 62, 60), 'none'), bias=205)
    return b


def b_guardhouse():
    b = HB('bastion', '0,0', 1, 72, 'silicate', plinth=(110, 108, 100), plinth_h=8)
    b.door(b.dx, canopy=('concrete_s', 16), frame=(60, 60, 58))
    b.storeys(2, 30, 18, 18, 34, first=14, frame=(200, 200, 192), band=(140, 136, 120))
    b.signboard(b.dx, 62, 110, 8, col=(52, 60, 44), border=(190, 180, 130))
    b.gable('slate', 34)
    b.roof_patch(-80, 30, 60, 36, 'tarp_green')
    b.collapse(100, 20, 50, 40)
    b.antenna(-130, -40, 34)
    return b


def b_search():
    b = HB('bastion', '0,0', 2, 40, 'concrete_s')
    b.door(b.dx)
    b.gate(-40, 46, 32, col=(84, 94, 70))
    b.flat('tar', 'concrete_s', 3)
    b.m.box(-60, -20, b.y1 + 2, b.y1 + 9, 0, 12, 'sandbag', bias=58)
    return b


def b_barracks():
    b = HB('bastion', '1,0', 0, 96, 'silicate', plinth=(110, 108, 100), plinth_h=8)
    b.door(b.dx, canopy=('concrete_s', 18), frame=(60, 60, 58))
    b.storeys(3, 28, 18, 18, 32, first=14, frame=(200, 200, 192), band=(150, 146, 130), lit=0.04)
    b.hip('slate', 40)
    for x in (-180, -60, 60, 180):
        b.pipe(x, -20, 12)
    b.collapse(-120, 30, 70, 50)
    b.scorch(3)
    b.breach(1, (24, 20))
    b.rubble_front(8)
    return b


def b_hq():
    b = HB('bastion', '1,0', 1, 92, 'silicate', plinth=(110, 108, 100), plinth_h=10)
    b.door(b.dx, canopy=('concrete_s', 18), frame=(60, 60, 58))
    b.storeys(3, 28, 18, 18, 32, first=14, frame=(200, 200, 192), band=(140, 136, 120))
    b.flat('tar', 'concrete_s', 5)
    b.dome(-30, -40, 24)
    b.mast(50, -60, 70)
    b.m.line3([V(0, 40, b.H), V(0, 40, b.H + 54)], (180, 182, 178), 1, bias=220)
    fl = Face(V(0, 40.5, b.H + 40), V(1, 0, 0), V(0, 0, 1), 24, 12, (84, 98, 62), 'none', bias=221)
    b.m.add(fl)
    fl.decals.append(('rect', dict(u=0, v=4, w=24, h=4, col=(200, 190, 150), lit_shade=False)))
    return b


def b_spares():
    b = HB('bastion', '1,0', 2, 40, 'concrete')
    b.door(b.dx)
    b.gate(-30, 48, 32, col=(84, 94, 70))
    earth_cover(b, 16, 8)
    return b


def b_hangar(cell):
    b = HB('bastion', cell, 0, 40, 'concrete', plinth=(100, 100, 94), plinth_h=6)
    # hardened aircraft shelter: concrete arch, huge sliding blast door
    b.arch_zs = 0.4
    front = b.arch('concrete')
    r0 = b.W / 2
    for k in range(-5, 6):
        y = k * b.D / 11
        pts = [V(-math.cos(math.pi * i / 24) * r0, y, b.H + 0.4 * math.sin(math.pi * i / 24) * r0 + 0.6) for i in range(25)]
        b.m.line3(pts, (118, 116, 108), 2, bias=140)
    for _ in range(18):          # moss and soot streaks running down the shell
        x = b.rng.uniform(-r0 * 0.9, r0 * 0.9)
        y = b.rng.uniform(b.y0 + 10, b.y1 - 10)
        z = b.H + 0.4 * math.sqrt(max(0, r0 * r0 - x * x))
        b.m.line3([V(x, y, z + 0.8), V(x + b.rng.uniform(-3, 3), y + b.rng.uniform(10, 30), z + 0.8)],
                  b.rng.choice([(84, 96, 56), (70, 70, 64), (96, 104, 60)]), 3, bias=141)
    gate_w = 300.0
    b.door(b.dx)
    b.gate(-60, gate_w * 0.6, 34, col=(78, 88, 62), kind='gate')
    b.m.rect(b.front, b.fu(-60) - gate_w * 0.3 - 6, 0, 6, 40, (70, 70, 66))
    b.stripes(-60, 36, gate_w * 0.6, 5)
    b.signboard(-60, 46, 120, 9, col=(52, 60, 44), border=(190, 180, 130))
    # camouflage net draped over one side of the arch + vents along the ridge
    for x in (-220, -80, 80, 220):
        b.vent_stack(x, -60, 14, 5)
    b.roof_patch(150, 30, 160, 90, 'tarp_green')
    b.collapse(-200, 10, 70, 50)
    b.rust = 0.1
    b.moss = 0.08
    return b


def b_mech():
    b = HB('bastion', '2,0', 1, 44, 'steel_olive')
    b.door(b.dx)
    b.gate(30, 56, 36, col=(84, 94, 70))
    b.gable('tin_olive', 16)
    b.rust = 0.16
    return b


def b_loading():
    b = HB('bastion', '2,0', 2, 42, 'concrete')
    b.door(b.dx)
    b.gate(-30, 56, 30, col=(110, 116, 116))
    b.m.box(b.x0, b.x1, b.y1, b.y1 + 8, 0, 10, 'concrete', bias=55)      # loading ramp
    b.stripes(-30, 10, 60, 3)
    b.flat('tar', 'concrete_s', 3)
    return b


def b_repair():
    b = HB('bastion', '0,1', 0, 62, 'steel_olive')
    b.door(b.dx)
    for x in (-10, 80):
        b.gate(x, 70, 50, col=(84, 94, 70))
    b.stripes(35, 52, 170, 4)
    b.sawtooth('tin_olive', teeth=3, rise=18)
    b.rust = 0.18
    return b


def b_motorpool():
    b = HB('bastion', '0,1', 1, 48, 'concrete')
    b.door(b.dx)
    for x in (-100, -40):
        b.gate(x, 50, 38, col=(84, 94, 70))
    earth_cover(b, 22, 14)
    return b


def b_fuel():
    b = HB('bastion', '0,1', 2, 40, 'concrete_s')
    b.door(b.dx)
    b.windows(18, 18, 12, 30, x_from=-60, x_to=0)
    b.stripes(0, 34, b.W, 4, RED, (226, 224, 214))
    b.flat('tar', 'concrete_s', 3)
    b.tank(-30, -10, 12, 22, ((110, 120, 80), 'none'))
    return b


def b_arsenal():
    b = HB('bastion', '1,1', 0, 58, 'concrete', plinth=(100, 100, 94), plinth_h=6)
    b.door(b.dx, frame=(60, 60, 58))
    bunker_portal(b, -100, 80, 46)
    bunker_portal(b, 100, 60, 40)
    b.stripes(-100, 50, 96, 5)
    earth_cover(b, 34, 20)
    for x in (-140, 0, 140):
        b.vent_stack(x, 0, 12, 6)
    b.moss = 0.1
    return b


def b_kommandatura():
    b = HB('bastion', '1,1', 1, 84, 'silicate', plinth=(110, 108, 100), plinth_h=8)
    b.door(b.dx, canopy=('concrete_s', 16), frame=(60, 60, 58))
    b.storeys(3, 26, 18, 16, 34, first=14, frame=(200, 200, 192), band=(140, 136, 120))
    for (u, v, w, h) in list(b.win_rects)[:4]:
        b.front.decals.append(('sandbags', dict(u=u, v=v - 1, w=w, h=h * 0.6)))
    b.flat('tar', 'concrete_s', 5)
    b.mast(-40, -50, 64)
    b.dish(40, -40, 9)
    return b


def b_comms():
    b = HB('bastion', '1,1', 2, 42, 'silicate')
    b.door(b.dx)
    b.windows(18, 14, 12, 26, bars=True, x_from=0, x_to=60)
    b.flat('tar', 'concrete_s', 3)
    b.mast(-30, -20, 80)
    b.dish(30, 0, 7)
    return b


def b_ammo():
    b = HB('bastion', '2,1', 1, 40, 'concrete')
    b.door(b.dx, frame=(60, 60, 58))
    bunker_portal(b, -30, 40, 32)
    b.stripes(-30, 34, 50, 4, RED, (226, 224, 214))
    earth_cover(b, 18, 10)
    return b


def b_hangar_guard():
    b = HB('bastion', '2,1', 2, 44, 'silicate')
    b.door(b.dx)
    b.windows(18, 14, 14, 28, x_from=-60, x_to=0)
    for (u, v, w, h) in list(b.win_rects):
        b.front.decals.append(('sandbags', dict(u=u, v=v - 1, w=w, h=h * 0.6)))
    b.gable('slate', 18)
    return b


# ===================================================================== VECTOR ==
def brutal(b, panel=48.0):
    """brutalist board-formed concrete: vertical form-tie rhythm and a deep cornice"""
    a = panel / 2
    while a < b.W:
        b.m.rect(b.front, a, 0, 1.4, b.H, (104, 104, 98))
        a += panel
    b.m.rect(b.front, 0, b.H - 8, b.W, 8, (120, 120, 114))
    b.m.rect(b.front, 0, b.H - 8.6, b.W, 0.8, (70, 70, 66))


def blast_door(b, x, w, h):
    f = b.m.box(x - w / 2 - 10, x + w / 2 + 10, b.y1, b.y1 + 10, 0, h + 12, 'concrete', bias=60)
    door = b.m.box(x - w / 2, x + w / 2, b.y1 + 10, b.y1 + 10.4, 0, h, ((120, 112, 70), 'none'), bias=61, cap=False)['front']
    door.decals.append(('stripe', dict(u=0, v=0, w=w, h=6, c1=(206, 164, 44), c2=(36, 36, 34), period=10)))
    door.decals.append(('rect', dict(u=w / 2 - 0.8, v=0, w=1.6, h=h, col=(40, 40, 38))))
    for k in range(4):
        door.decals.append(('rect', dict(u=4, v=8 + k * (h - 12) / 4, w=w - 8, h=1.2, col=(90, 86, 56))))
    return door


def v_shaft():
    b = HB('vector', '0,0', 0, 70, 'concrete', plinth=(90, 90, 86), plinth_h=8)
    brutal(b)
    b.door(b.dx, frame=(60, 60, 58))
    blast_door(b, 120, 110, 52)
    b.m.rect(b.front, b.fu(120) - 70, 64, 140, 2, (206, 164, 44))
    b.signboard(-150, 52, 120, 9, col=(40, 44, 42), border=(150, 140, 110))
    for x in (-230, -150, 0):
        b.m.rect(b.front, b.fu(x) - 12, 40, 24, 4, (40, 44, 46))     # firing slits
    earth_cover(b, 30, 30)
    for x in (-180, -60, 60, 180):
        b.vent_stack(x, -40, 26, 7, steam=(x in (-60, 180)))
    b.antenna_field(-240, -120, 40, 3, 50)
    b.moss = 0.14
    return b


def v_permit():
    b = HB('vector', '0,0', 1, 64, 'concrete')
    brutal(b, 40)
    b.door(b.dx)
    b.windows(36, 40, 10, 56, style='strip', avoid_openings=False, frame=(130, 130, 126))
    b.flat('tar', 'concrete', 5)
    b.dome(20, -30, 18)
    return b


def v_reserve():
    b = HB('vector', '0,0', 2, 42, 'concrete')
    b.door(b.dx)
    b.gate(-40, 50, 32, col=(110, 112, 70))
    b.flat('tar', 'concrete', 3)
    b.vent_stack(40, -20, 14, 4)
    return b


def v_guard():
    b = HB('vector', '1,0', 0, 86, 'concrete', plinth=(90, 90, 86), plinth_h=8)
    brutal(b)
    b.door(b.dx, canopy=('concrete', 20), frame=(60, 60, 58))
    b.storeys(2, 32, 40, 8, 60, first=30, style='strip', frame=(130, 130, 126))
    b.flat('tar', 'concrete', 6)
    b.penthouse(-120, -40, 80, 60, 26)
    b.m.cyl(150, 40, b.H, b.H + 30, 4, ((80, 82, 80), 'none'), bias=200)
    b.m.cyl(150, 40, b.H + 30, b.H + 36, 7, ((60, 62, 60), 'none'), bias=201)
    b.scorch(2)
    b.breach(1, (30, 24))
    b.rubble_front(8)
    return b


def v_comm():
    b = HB('vector', '1,0', 1, 70, 'concrete')
    brutal(b, 40)
    b.door(b.dx)
    b.windows(40, 30, 8, 46, style='strip', avoid_openings=False, frame=(130, 130, 126))
    b.flat('tar', 'concrete', 5)
    b.antenna_field(-70, 70, -60, 4, 70)
    b.dish(-40, 40, 12)
    b.dish(40, 40, 10)
    return b


def v_techcab():
    b = HB('vector', '1,0', 2, 40, 'steel')
    b.door(b.dx)
    b.stripes(-40, 0, 60, 4)
    b.flat('tar', None, 0)
    b.hvac(-30, -10, 24, 16, 8)
    return b


def v_energy():
    b = HB('vector', '0,1', 0, 70, 'concrete')
    brutal(b)
    b.door(b.dx)
    b.gate(60, 80, 52, col=(110, 112, 70))
    b.hazard(-100, 40, 'rad', 14)
    b.flat('tar', 'concrete', 5)
    for x in (-110, -40, 30, 100):
        b.hvac(x, -40, 40, 30, 16)
    b.collapse(80, 40, 50, 34)
    return b


def v_pumps():
    b = HB('vector', '0,1', 1, 62, 'brick_dark')
    b.door(b.dx)
    b.windows(36, 20, 16, 34, style='arch', frame=(140, 100, 80))
    b.flat('tar', 'brick_dark', 4)
    for x in (-90, -30, 30):
        b.tank(x, -40, 18, 30, 'steel_rust')
    b.m.line3([V(-120, 30, b.H + 10), V(120, 30, b.H + 10)], (120, 80, 50), 3, bias=230)
    b.m.line3([V(-120, 40, b.H + 6), V(120, 40, b.H + 6)], (90, 110, 120), 3, bias=230)
    b.rust = 0.2
    return b


def v_power_reserve():
    b = HB('vector', '0,1', 2, 40, 'concrete')
    b.door(b.dx)
    b.gate(-40, 48, 30, col=(110, 112, 70))
    b.flat('tar', 'concrete', 3)
    b.vent_stack(-40, -20, 18, 5)
    return b


def v_command():
    b = HB('vector', '1,1', 0, 100, 'concrete', plinth=(90, 90, 86), plinth_h=10)
    brutal(b)
    b.door(b.dx, canopy=('concrete', 24), frame=(60, 60, 58))
    b.storeys(3, 28, 60, 8, 76, first=26, style='strip', frame=(130, 130, 126), band=(90, 92, 88))
    b.signboard(b.dx, 88, 150, 9, col=(40, 44, 42), border=(150, 140, 110))
    b.flat('tar', 'concrete', 6)
    b.dome(-120, -60, 30)
    b.antenna_field(40, 180, -80, 4, 60)
    b.mast(-160, 60, 70)
    b.scorch(2)
    return b


def v_servers():
    b = HB('vector', '1,1', 1, 64, 'concrete')
    brutal(b, 40)
    b.door(b.dx)
    b.flat('tar', 'concrete', 5)
    for x in (-60, 0, 60):
        for y in (-70, -20, 30):
            b.hvac(x, y, 34, 24, 10)
    return b


def v_commreserve():
    b = HB('vector', '1,1', 2, 42, 'concrete')
    b.door(b.dx)
    b.gate(-50, 52, 32, col=(110, 112, 70))
    earth_cover(b, 16, 10)
    b.antenna(60, 0, 40)
    return b


def v_service_lock():
    b = HB('vector', '0,2', 0, 60, 'concrete')
    brutal(b)
    b.door(b.dx)
    blast_door(b, -60, 90, 44)
    b.flat('tar', 'concrete', 5)
    for x in (-100, 0, 100):
        b.vent_stack(x, -60, 20, 6)
    b.moss = 0.1
    return b


def v_emerg_store():
    b = HB('vector', '0,2', 1, 50, 'concrete')
    b.door(b.dx)
    b.gate(-60, 70, 40, col=(110, 112, 70))
    earth_cover(b, 26, 16)
    b.moss = 0.12
    return b


def v_vent():
    b = HB('vector', '0,2', 2, 42, 'concrete')
    b.door(b.dx)
    b.flat('tar', 'concrete', 3)
    b.vent_stack(-40, -10, 40, 10, steam=True)
    b.vent_stack(10, -10, 30, 7)
    for k in range(3):
        b.m.rect(b.front, 10 + k * 16, 12, 12, 16, (60, 62, 60))       # louvres
    return b


def v_core():
    b = HB('vector', '1,2', 0, 92, 'concrete', plinth=(90, 90, 86), plinth_h=10)
    brutal(b)
    b.door(b.dx, frame=(60, 60, 58))
    blast_door(b, 120, 120, 60)
    b.hazard(-150, 50, 'rad', 18)
    b.storeys(2, 30, 40, 8, 70, first=40, style='strip', frame=(130, 130, 126), x_from=-210, x_to=40)
    b.flat('tar', 'concrete', 6)
    # cooling tower stub on the roof
    b.m.cyl(-120, -60, b.H, b.H + 54, 34, ((150, 150, 144), 'none'), segs=18, bias=200)
    b.m.cyl(-120, -60, b.H + 54, b.H + 58, 30, ((60, 60, 58), 'none'), segs=18, bias=201)
    b.steam.append((-120, -60 - (b.H + 60)))
    for x in (40, 110, 180):
        b.hvac(x, -40, 40, 30, 14)
    return b


def v_autonomous():
    b = HB('vector', '1,2', 1, 60, 'concrete')
    brutal(b, 40)
    b.door(b.dx)
    b.gate(-30, 70, 44, col=(110, 112, 70))
    b.flat('tar', 'concrete', 4)
    b.tank(-40, -60, 22, 34, ((130, 130, 124), 'none'))
    b.vent_stack(40, -60, 30, 6, steam=True)
    return b


def v_systems():
    b = HB('vector', '1,2', 2, 44, 'concrete')
    b.door(b.dx)
    b.windows(24, 28, 8, 40, style='strip', x_from=-70, x_to=10, frame=(130, 130, 126))
    b.flat('tar', 'concrete', 3)
    b.antenna_field(-60, 60, -20, 3, 40)
    return b


MODELS = {
    'clinic': [c_emergency, c_guard, c_diagnostics, c_radiology, c_archive, c_garage, c_oxygen, c_dispatch,
               c_ward_a, c_ward_b, c_nurse, c_isolation, c_postop, c_sluice, c_surgical, c_sterile, c_icu],
    'quarantine': [q_gate, q_triage, q_desk, q_isolator_a, q_watch, q_sanpass, q_lab, q_cold, q_tech,
                   q_transport, q_store, q_guard, q_redzone, q_isolator_b, q_airlock, q_sterile, q_clean, q_inner_post],
    'bastion': [b_gate, b_guardhouse, b_search, b_barracks, b_hq, b_spares, lambda: b_hangar('2,0'), b_mech, b_loading,
                b_repair, b_motorpool, b_fuel, b_arsenal, b_kommandatura, b_comms, lambda: b_hangar('2,1'), b_ammo, b_hangar_guard],
    'vector': [v_shaft, v_permit, v_reserve, v_guard, v_comm, v_techcab, v_energy, v_pumps, v_power_reserve,
               v_command, v_servers, v_commreserve, v_service_lock, v_emerg_store, v_vent, v_core, v_autonomous, v_systems],
}


def finish_hr(b):
    """HR buildings are more ruined than the towns: heavier grime, fewer leaves on clean roofs."""
    b.wear()
    b.apply_blockers()
    c = render(b.m, grime=b.grime + 0.08, rust=b.rust + 0.04, moss=b.moss + 0.04)
    split = int(round((b.D / 2 - b.H - c.y0) * DENS))
    c.img = sprinkle_leaves(c.img, b.seed, 0.006, rows=(0, max(1, split)))
    return c


def build_all(P, gd_path):
    lines = ['extends RefCounted', '',
             '# GENERATED by tools/wa_hr_buildings.py - do not edit by hand.',
             '# High Risk building exteriors, keyed by poi_id / cell / building id.',
             '# Same schema as settlement_building_models.gd (layers drawn at 0.5).',
             'const MODELS = {']
    entries = []
    for site, fns in MODELS.items():
        items = []
        built = []
        for fn in fns:
            b = fn()
            c = finish_hr(b)
            img = c.img
            split = int(round((b.D / 2 - b.H - c.y0) * DENS))
            meta = {}
            for key, layer, oy in (('roof', img.crop((0, 0, img.width, split)), 0), ('facade', img.crop((0, split, img.width, img.height)), split)):
                bb = layer.getbbox()
                items.append(((b.id, key), layer.crop(bb)))
                meta[key] = (c.x0 + bb[0] / DENS, c.y0 + (oy + bb[1]) / DENS)
            built.append((b, meta))
        atlas, pos = _pack(items, width=4096)
        name = 'hr_buildings_%s_v1.png' % site
        os.makedirs(os.path.join(P, 'art', 'high_risk'), exist_ok=True)
        atlas.save(os.path.join(P, 'art', 'high_risk', name))
        for b, meta in built:
            rx, ry, rw, rh = pos[(b.id, 'roof')]
            fx, fy, fw, fh = pos[(b.id, 'facade')]
            sign = 'Rect2(%s,%s,%s,%s)' % tuple(_gd(float(v)) for v in b.sign) if b.sign else 'Rect2()'
            smoke = '[' + ','.join('Vector2(%s,%s)' % (_gd(float(px)), _gd(float(py))) for px, py in b.smoke) + ']'
            steam = '[' + ','.join('Vector2(%s,%s)' % (_gd(float(px)), _gd(float(py))) for px, py in b.steam) + ']'
            entries.append('    "%s":{"faction":"%s","archetype":"%s","size":Vector2(%s,%s),"facade_height":%s,"roof_rise":%s,'
                           '"door_x":%s,"atlas":"res://art/high_risk/%s","roof_region":Rect2(%d,%d,%d,%d),"roof_pos":Vector2(%s,%s),'
                           '"facade_region":Rect2(%d,%d,%d,%d),"facade_pos":Vector2(%s,%s),"sign":%s,"leaf":%d,"smoke":%s,"steam":%s}' % (
                               b.id, site, b.archetype, _gd(b.W), _gd(b.D), _gd(b.H), _gd(float(b.roof_rise)), _gd(float(b.dx)), name,
                               rx, ry, rw, rh, _gd(float(meta['roof'][0])), _gd(float(meta['roof'][1])),
                               fx, fy, fw, fh, _gd(float(meta['facade'][0])), _gd(float(meta['facade'][1])),
                               sign, SITE_LEAF[site], smoke, steam))
    lines.append(',\n'.join(entries))
    lines += ['}', '',
              'const SITE_KEYS = %s' % ('{' + ','.join('"%s":"%s"' % (v, k) for k, v in SITE_POI.items()) + '}'), '',
              'static func model_id(poi_id:String,cell_offset:Vector2i,building_id:String) -> String:',
              '    var site = str(SITE_KEYS.get(poi_id,""))',
              '    if site == "":',
              '        return ""',
              '    var mid = "hr_%s_%d%d_%s" % [site,cell_offset.x,cell_offset.y,building_id.replace("building_","b")]',
              '    return mid if MODELS.has(mid) else ""', '',
              'static func has(mid:String) -> bool:', '    return MODELS.has(mid)', '',
              'static func model(mid:String) -> Dictionary:', '    return MODELS.get(mid,{}).duplicate(true)', '']
    open(gd_path, 'w', encoding='utf-8').write('\n'.join(lines))


if __name__ == '__main__':
    import sys
    P = sys.argv[1] if len(sys.argv) > 1 else '.'
    build_all(P, os.path.join(P, 'world', 'high_risk_building_models.gd'))
    print('high risk buildings ok')
