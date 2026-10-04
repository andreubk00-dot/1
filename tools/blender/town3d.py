"""OSTATOK building renderer, Blender backend for wa_town models.

The 2D pipeline (wa_town / wa_buildings / wa_hr_buildings) describes every
building as textured planar faces with decals (windows, doors, boards, signs
...) plus free polygons, cylinders and lines, and paints them flat-shaded in the
game's "lifted roof" oblique projection, screen = (x, y - z).

This module rebuilds the same model as real geometry in Blender and renders it
with Cycles, so every building gets cast shadows, ambient occlusion and true
depth without redrawing the 90+ building definitions:

  * the oblique projection is reproduced exactly by shearing the scene
    (blender X = x, Y = z - y, Z = z) under a top-down orthographic camera;
  * the light is sheared with it, so shadows fall where the game light puts them;
  * windows become openings: the wall texture is cut, the glass sits 2 units
    back behind a lit reveal, the lintel and jambs throw shadow on the pane and
    a real sill sticks out under it; boards and plywood are nailed on the
    outside, broken panes are painted on the recessed glass;
  * painter's-order biases of the 2D model are kept by nudging elements along
    the view axis (0, 1, 1), which changes depth but never the screen position.

render_model(model) returns a wa_town.Canvas whose .img is the final sprite at
DENS (2) texels per world unit — a drop-in replacement for wa_town.render().
"""
import math
import os
import random
import sys
import tempfile

import bpy
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)
import wa_town
from wa_town import Canvas, Face, V, norm, dark, mix, DENS, _pattern, _draw_decal, _weather
from wa_core import outline_img, clamp8
import bk

SS = 2                       # render supersampling on top of DENS
FRONT_K = 0.6 + 0.52 * max(0.0, float(np.dot(V(0, 1, 0), wa_town.LIGHT)))
RECESS = 2.0                 # window glass depth behind the wall plane
OVER_GLASS = {'broken'}
OVER_OUTSIDE = {'boards', 'plywood', 'sandbags', 'plastic', 'sheet', 'stovepipe'}
VIEW = V(0, 1, 1) / math.sqrt(2)
_TMP = tempfile.mkdtemp(prefix='ostatok_town3d_')
_tex_id = [0]


# ------------------------------------------------------------------ helpers --
def T(p, shift=0.0):
    """game point -> sheared blender point (+ nudge along the view axis)."""
    p = np.asarray(p, float) + VIEW * shift
    return (float(p[0]), float(p[2] - p[1]), float(p[2]))


def bias_shift(b):
    return float(np.clip(b, -60, 320)) * 0.006


class FlatCanvas:
    """paint target for one face in its own (a, b) frame, b pointing up."""

    def __init__(self, a0, b0, a1, b1, pad=0):
        self.a0, self.b0, self.a1, self.b1 = a0 - pad, b0 - pad, a1 + pad, b1 + pad
        self.w = max(1, int(math.ceil((self.a1 - self.a0) * DENS)))
        self.h = max(1, int(math.ceil((self.b1 - self.b0) * DENS)))
        self.img = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))

    def P(self, p):
        # p is a game point produced by a flat face_pt: (a, 0, b)
        return ((p[0] - self.a0) * DENS, (self.b1 - p[2]) * DENS)


def flat_face(f):
    """copy of face f lying in the x-z plane at the origin (front-facing)."""
    g = Face(V(0, 0, 0), V(1, 0, 0), V(0, 0, 1), f.lu, f.lv, f.col, f.pattern, f.bias, f.pat_scale, f.outline, f.alpha)
    return g


def _save_tex(img):
    _tex_id[0] += 1
    path = os.path.join(_TMP, 't%05d.png' % _tex_id[0])
    img.save(path)
    return path


def unshade(img):
    a = np.array(img).astype(float)
    a[..., :3] = a[..., :3] / FRONT_K
    return Image.fromarray(clamp8(a), 'RGBA')


def tex_material(path, rough=0.85, emit=False, alpha=True, bump=0.35):
    m = bpy.data.materials.new('tx')
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    t = nt.nodes.new('ShaderNodeTexImage')
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = 'sRGB'
    t.image = im
    t.interpolation = 'Closest'
    t.extension = 'CLIP'
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    if alpha:
        nt.links.new(t.outputs['Alpha'], b.inputs['Alpha'])
        m.blend_method = 'CLIP' if hasattr(m, 'blend_method') else None
    b.inputs['Roughness'].default_value = rough
    b.inputs['Specular IOR Level'].default_value = 0.25
    if bump > 0:
        # micro relief from the painted pattern itself: mortar joints, panel
        # seams, sheet ribs and gravel catch the low sun
        bw = nt.nodes.new('ShaderNodeRGBToBW')
        bn = nt.nodes.new('ShaderNodeBump')
        bn.inputs['Strength'].default_value = bump
        bn.inputs['Distance'].default_value = 0.6
        nt.links.new(t.outputs['Color'], bw.inputs['Color'])
        nt.links.new(bw.outputs['Val'], bn.inputs['Height'])
        nt.links.new(bn.outputs['Normal'], b.inputs['Normal'])
    if emit:
        nt.links.new(t.outputs['Color'], b.inputs['Emission Color'])
        b.inputs['Emission Strength'].default_value = 0.6
    return m


def col_material(col, rough=0.85, metal=0.0):
    return bk.mat(tuple(int(c) for c in col), rough=rough, metal=metal, grime=0.0)


def add_mesh(verts, faces, m, uvs=None, name='f', smooth=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    if uvs is not None:
        uvl = me.uv_layers.new(name='UV')
        k = 0
        for poly in me.polygons:
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                uvl.data[li].uv = uvs[vi]
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    if m is not None:
        o.data.materials.append(m)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    return o


def quad(f, a0, b0, a1, b1, m, push=0.0, shift=0.0):
    """textured quad on face f covering (a0..a1, b0..b1), pushed along the
    face normal by `push` (negative = into the wall)."""
    n = f.n * push
    ps = [f.pt(a0, b0) + n, f.pt(a1, b0) + n, f.pt(a1, b1) + n, f.pt(a0, b1) + n]
    return add_mesh([T(p, shift) for p in ps], [(0, 1, 2, 3)], m, uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])


def slab(f, a0, b0, a1, b1, d0, d1, m, shift=0.0):
    """box aligned to face f: (a, b) rectangle extruded from d0 to d1 along n."""
    cs = []
    for (a, b) in ((a0, b0), (a1, b0), (a1, b1), (a0, b1)):
        for d in (d0, d1):
            cs.append(T(f.pt(a, b) + f.n * d, shift))
    # vertex order: (a0b0,d0)=0,(a0b0,d1)=1,(a1b0,d0)=2,(a1b0,d1)=3,(a1b1,d0)=4,(a1b1,d1)=5,(a0b1,d0)=6,(a0b1,d1)=7
    faces = [(0, 2, 4, 6), (1, 7, 5, 3), (0, 1, 3, 2), (2, 3, 5, 4), (4, 5, 7, 6), (6, 7, 1, 0)]
    return add_mesh(cs, faces, m)


def overlap(r1, r2):
    ax0, ay0, aw, ah = r1
    bx0, by0, bw, bh = r2
    ix = max(0.0, min(ax0 + aw, bx0 + bw) - max(ax0, bx0))
    iy = max(0.0, min(ay0 + ah, by0 + bh) - max(ay0, by0))
    return ix * iy


# ------------------------------------------------------------------ painting --
def paint_face(f, decals, rng, base=True, outline=True, cut=()):
    """paint face f (pattern + decals) into its own flat texture."""
    g = flat_face(f)
    c = FlatCanvas(0, 0, f.lu, f.lv)
    d = ImageDraw.Draw(c.img)
    col = wa_town.shade(f.col, g.n)
    if base:
        d.rectangle([0, 0, c.w, c.h], fill=col + (f.alpha,))
        _pattern(d, g.pt, c.P, f.lu, f.lv, f.pattern, col, rng, f.pat_scale)
        # mud / damp at the foot of walls that stand on the ground
        zs = [p[2] for p in f.corners()]
        if abs(f.n[2]) < 0.2 and min(zs) < 1.0:
            ov = Image.new('RGBA', c.img.size, (0, 0, 0, 0))
            od = ImageDraw.Draw(ov)
            for i in range(8):
                b0, b1 = i * 2.0, i * 2.0 + 2.0
                od.rectangle([0, c.h - b1 * DENS, c.w, c.h - b0 * DENS], fill=(30, 24, 16, int(80 * (1 - i / 8) ** 1.5)))
            c.img.alpha_composite(ov)
            d = ImageDraw.Draw(c.img)
    for kind, p in decals:
        _draw_decal(d, c, g, kind, p, col, rng, c.img)
        d = ImageDraw.Draw(c.img)
    a = np.array(c.img)
    for (u, v, w, h) in cut:
        x0, x1 = int(round(u * DENS)), int(round((u + w) * DENS))
        y0, y1 = int(round((f.lv - v - h) * DENS)), int(round((f.lv - v) * DENS))
        a[max(0, y0):max(0, y1), max(0, x0):max(0, x1), 3] = 0
    if outline and base and f.outline:
        oc = dark(col, 0.62) + (255,)
        A = a[..., 3] > 0
        a[0, :][A[0, :]] = oc
        a[-1, :][A[-1, :]] = oc
        a[:, 0][A[:, 0]] = oc
        a[:, -1][A[:, -1]] = oc
    return unshade(Image.fromarray(a, 'RGBA'))


def glass_texture(win, decals, rng):
    """the recessed pane: glass, reflection, mullions, bars, breakage."""
    u, v, w, h = win['u'], win['v'], win['w'], win['h']
    pane = Face(V(0, 0, 0), V(1, 0, 0), V(0, 0, 1), w, h, win['glass'], 'none')
    c = FlatCanvas(0, 0, w, h)
    d = ImageDraw.Draw(c.img)
    gl = (196, 160, 96) if win['lit'] else win['glass']
    fr = win['frame']
    P = c.P
    pt = pane.pt
    d.rectangle([0, 0, c.w, c.h], fill=dark(gl, 0.9) + (255,))
    d.polygon([P(pt(0, h)), P(pt(w * 0.55, h)), P(pt(0, h * 0.35))], fill=mix(gl, (170, 190, 196), 0.35) + (255,))
    # frame members of the sash (painted, the 3D frame sits around)
    def L(a0, b0, a1, b1, col, wd=1):
        d.line([P(pt(a0, b0)), P(pt(a1, b1))], fill=col + (255,), width=wd)
    st = win['style']
    if st in ('frame', 'cross', 'nalichnik', 'tall'):
        L(w / 2, 0, w / 2, h, fr, 2)
        if st != 'tall':
            L(0, h * 0.66, w, h * 0.66, fr, 2)
    elif st == 'strip':
        a = 6
        while a < w - 1:
            L(a, 0, a, h, fr, 2)
            a += 6
    elif st == 'arch':
        L(w / 2, 0, w / 2, h, fr, 2)
    for kind, p in decals:
        q = dict(p)
        q['u'] -= u
        q['v'] -= v
        _draw_decal(d, c, pane, kind, q, gl, rng, c.img)
        d = ImageDraw.Draw(c.img)
    if win['bars']:
        a = 1.5
        while a < w:
            L(a, 0, a, h, (40, 40, 40))
            a += 2.5
    return c.img


def outside_texture(f, decals, rng, wins):
    """boards / plywood / sandbags nailed over openings, on their own layer."""
    c = FlatCanvas(0, 0, f.lu, f.lv)
    g = flat_face(f)
    d = ImageDraw.Draw(c.img)
    for kind, p in decals:
        _draw_decal(d, c, g, kind, p, f.col, rng, c.img)
        d = ImageDraw.Draw(c.img)
    a = np.array(c.img)
    # the "boards" decal fills the opening behind the planks with near-black:
    # make that see-through so the real recess shows between the planks
    dark_px = (a[..., 3] > 0) & (a[..., :3].max(axis=2) < 32)
    a[dark_px, 3] = 0
    return unshade(Image.fromarray(a, 'RGBA'))


# --------------------------------------------------------------------- scene --
def setup(canvas):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bk._MAT.clear()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 40
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 3
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    w = bpy.data.worlds.new('w')
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs[0].default_value = (0.93, 0.95, 1.0, 1)
    bg.inputs[1].default_value = 0.56
    # game light, sheared like the geometry
    L = wa_town.LIGHT
    Ls = np.array([L[0], L[2] - L[1], L[2]])
    Ls /= np.linalg.norm(Ls)
    from mathutils import Vector
    dvec = Vector((float(Ls[0]), float(Ls[1]), float(Ls[2])))
    sun = bpy.data.lights.new('sun', 'SUN')
    sun.energy = 2.1
    sun.angle = math.radians(3)
    sun.color = (1.0, 0.97, 0.92)
    so = bpy.data.objects.new('sun', sun)
    sc.collection.objects.link(so)
    so.rotation_euler = (-dvec).to_track_quat('-Z', 'Y').to_euler()
    cam = bpy.data.cameras.new('cam')
    cam.type = 'ORTHO'
    wu = canvas.x1 - canvas.x0
    hu = canvas.y1 - canvas.y0
    cam.ortho_scale = max(wu, hu)
    cam.clip_start = 1
    cam.clip_end = 10000
    co = bpy.data.objects.new('cam', cam)
    sc.collection.objects.link(co)
    sc.camera = co
    cx = (canvas.x0 + canvas.x1) / 2
    cy = (canvas.y0 + canvas.y1) / 2          # screen y (down) = y - z  -> blender Y = -screen y
    co.location = (cx, -cy, 3000)
    co.rotation_euler = (0, 0, 0)
    sc.render.resolution_x = int(round(wu * DENS * SS))
    sc.render.resolution_y = int(round(hu * DENS * SS))
    sc.render.resolution_percentage = 100
    return sc


def build(model, roof_fn=None):
    rng = random.Random(model.seed)
    for f in model.faces:
        if not f.visible():
            continue
        sh = bias_shift(f.bias)
        wall = abs(f.n[2]) < 0.3
        wins = [p for k, p in f.decals if k == 'window'] if wall else []
        rects = [(p['u'], p['v'], p['w'], p['h']) for p in wins]
        wall_decals, over_glass, over_out = [], {i: [] for i in range(len(wins))}, []
        for kind, p in f.decals:
            if kind == 'window' and wall:
                continue
            if wall and kind in (OVER_GLASS | OVER_OUTSIDE) and 'w' in p:
                r = (p['u'], p['v'], p['w'], p.get('h', 1.0))
                hits = [i for i, wr in enumerate(rects) if overlap(r, wr) > 0.3 * r[2] * r[3]]
                if hits:
                    if kind in OVER_GLASS:
                        over_glass[hits[0]].append((kind, p))
                    else:
                        over_out.append((kind, p))
                    continue
            wall_decals.append((kind, p))
        # window surrounds are painted on the wall, the opening is cut out
        trims = []
        for p in wins:
            fr = wa_town.shade(p['frame'], V(0, 1, 0))
            trims.append(('rect', dict(u=p['u'] - 1.2, v=p['v'] - 1.2, w=p['w'] + 2.4, h=p['h'] + 2.4, col=p['frame'])))
            if p['style'] == 'nalichnik':
                trims.append(('rect', dict(u=p['u'] - 2.2, v=p['v'] + p['h'] + 0.4, w=p['w'] + 4.4, h=2.0, col=(80, 108, 132))))
            if p['style'] == 'arch':
                trims.append(('rect', dict(u=p['u'] - 1.2, v=p['v'] + p['h'], w=p['w'] + 2.4, h=p['w'] * 0.3, col=p['frame'])))
            if p['shutters']:
                sc_ = p['shutters']
                trims.append(('rect', dict(u=p['u'] - p['w'] * 0.5 - 1.5, v=p['v'], w=p['w'] * 0.5, h=p['h'], col=sc_)))
                trims.append(('rect', dict(u=p['u'] + p['w'] + 1.5, v=p['v'], w=p['w'] * 0.5, h=p['h'], col=sc_)))
        img = paint_face(f, trims + wall_decals, rng, cut=rects)
        quad(f, 0, 0, f.lu, f.lv, tex_material(_save_tex(img)), shift=sh)
        for i, p in enumerate(wins):
            u, v, w, h = p['u'], p['v'], p['w'], p['h']
            rev = col_material(mix(f.col, (90, 88, 84), 0.35))
            # reveal: sill floor, lintel soffit, jambs (the last two mostly cast shadow)
            slab(f, u, v - 0.6, u + w, v, -RECESS, 0, rev, sh)
            slab(f, u, v + h, u + w, v + h + 0.6, -RECESS, 0, rev, sh)
            slab(f, u - 0.6, v, u, v + h, -RECESS, 0, rev, sh)
            slab(f, u + w, v, u + w + 0.6, v + h, -RECESS, 0, rev, sh)
            gimg = glass_texture(p, over_glass[i], rng)
            quad(f, u, v, u + w, v + h, tex_material(_save_tex(gimg), rough=0.3, emit=p['lit'], bump=0), push=-RECESS, shift=sh)
            if p['sill']:
                sc = mix(p['frame'], (230, 226, 214), 0.2)
                slab(f, u - 2, v - 1.8, u + w + 2, v - 0.6, 0, 1.6, col_material(sc, 0.6), sh)
        if over_out:
            oimg = outside_texture(f, over_out, rng, rects)
            quad(f, 0, 0, f.lu, f.lv, tex_material(_save_tex(oimg)), push=0.5, shift=sh)
    for depth, kind, data in model.polys:
        if kind == 'poly':
            pts, col, pat, n, frame, outline = data
            sh = 0.0
            _poly(pts, col, pat, frame, outline, rng, depth, roof_fn)
        elif kind == 'flat':
            pts, col = data
            add_mesh([T(p) for p in pts], [tuple(range(len(pts)))], col_material(_unshade_col(col, pts)))
        elif kind == 'line':
            pts, col, wd = data
            _line(pts, col, wd)


def _unshade_col(col, pts):
    n = norm(np.cross(np.asarray(pts[1]) - pts[0], np.asarray(pts[2]) - pts[0]))
    if np.dot(n, VIEW) < 0:
        n = -n
    k = 0.6 + 0.52 * max(0.0, float(np.dot(n, wa_town.LIGHT)))
    return tuple(min(255, int(c / k)) for c in col)


def _poly(pts, col, pat, frame, outline, rng, depth, roof_fn=None):
    pts = [np.asarray(p, float) for p in pts]
    lift = [0.0] * len(pts)
    if roof_fn is not None and len(pts) >= 3:
        nn = norm(np.cross(pts[1] - pts[0], pts[2] - pts[0]))
        if abs(nn[2]) > 0.85:
            # flat roof decals (holes, moss, puddles) follow sloped roofs
            for i, p in enumerate(pts):
                need = roof_fn(p[0], p[1]) + 0.35 - p[2]
                if 0 < need < 8:          # follow slopes, never jump onto structures
                    lift[i] = need * math.sqrt(2)
    if frame is None:
        o = pts[0]
        u = norm(pts[1] - pts[0])
        nn = norm(np.cross(pts[1] - pts[0], pts[2] - pts[0]))
        v = norm(np.cross(nn, u))
    else:
        o, u, v = [np.asarray(x, float) for x in frame]
    ab = [(float(np.dot(p - o, u)), float(np.dot(p - o, v))) for p in pts]
    a0, a1 = min(a for a, b in ab), max(a for a, b in ab)
    b0, b1 = min(b for a, b in ab), max(b for a, b in ab)
    c = FlatCanvas(a0, b0, a1, b1)
    d = ImageDraw.Draw(c.img)
    face_pt = lambda a, b: V(a, 0, b)
    poly = [c.P(face_pt(a, b)) for a, b in ab]
    colf = wa_town.shade(col, V(0, 1, 0))
    d.polygon(poly, fill=colf + (255,))
    if pat != 'none':
        layer = Image.new('RGBA', c.img.size, (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        dl.rectangle([0, 0, c.w, c.h], fill=colf + (255,))
        _pattern(dl, face_pt, c.P, a1 + 2, b1 + 2, pat, colf, rng)
        mask = Image.new('L', c.img.size, 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        c.img.paste(layer, (0, 0), mask)
    if outline:
        ImageDraw.Draw(c.img).polygon(poly, outline=dark(colf, 0.62) + (255,))
    img = unshade(c.img)
    uvs = [((a - c.a0) / max(1e-6, c.a1 - c.a0), (b - c.b0) / max(1e-6, c.b1 - c.b0)) for a, b in ab]
    # painter's bias of the 2D model is folded into the depth: recover it
    cen = np.mean(pts, axis=0)
    sh = bias_shift(depth - float(np.dot(cen, wa_town.VIEW)))
    add_mesh([T(p, sh + lift[i]) for i, p in enumerate(pts)], [tuple(range(len(pts)))], tex_material(_save_tex(img)), uvs=uvs)


def _line(pts, col, wd):
    cu = bpy.data.curves.new('l', 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = max(0.22, wd * 0.28)
    cu.bevel_resolution = 1
    sp = cu.splines.new('POLY')
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        x, y, z = T(p, 0.6)
        sp.points[i].co = (x, y, z, 1)
    o = bpy.data.objects.new('l', cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(col_material(col, 0.6))


def render_model(model, grime=0.10, rust=0.0, moss=0.0, outline=True, roof_fn=None):
    canvas = Canvas(model)
    setup(canvas)
    build(model, roof_fn)
    out = os.path.join(_TMP, 'render.png')
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    big = Image.open(out).convert('RGBA')
    img = big.resize((canvas.w, canvas.h), Image.BOX)
    a = np.array(img)
    A = a[..., 3] >= 110
    rgb = a[..., :3].astype(float)
    al = a[..., 3:4].astype(float) / 255.0
    rgb = np.where(al > 0, rgb / np.maximum(al, 1e-3), 0)       # un-premultiply soft edges
    out_a = np.zeros_like(a)
    out_a[..., :3] = clamp8(rgb)
    out_a[..., 3] = np.where(A, 255, 0)
    img = Image.fromarray(out_a, 'RGBA')
    img = _weather(img, model.seed, grime * 0.7, rust, moss)
    if outline:
        img = outline_img(img)
    canvas.img = img
    return canvas
