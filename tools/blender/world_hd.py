"""OSTATOK open-world HD twins, rendered in Blender.

The open world assembles its buildings at runtime from small atlases (roof
materials, parapet strips, wall tiles, windows, entrances ...) so that any
procedural footprint can be covered. Those atlases were painted flat at 1 texel
per world unit. This module renders 2x "HD twins" of them from real geometry in
the same lifted-roof projection the 3D buildings use (screen = (x, y - z)), with
the shared OSTATOK light, so the whole world reads as one style. The game swaps
a twin in at half scale (see main_script_mod._facade_atlas_sprite and
_roof_surface_sprite); the 1x originals stay for older tooling and self-tests.

    python3 tools/blender/world_hd.py <project_dir> [part ...]

Roof materials are periodic height fields (membrane laps, slab joints,
corrugation, standing seams, asbestos waves) with periodic albedo; the tile is
rendered with its eight neighbours present so shadows wrap seamlessly.
"""
import math
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import bpy
import numpy as np
from mathutils import Vector, Matrix
from PIL import Image

import bk
import wa_town
from wa_core import fbm, clamp8, LEAF_ORANGE

HD = 2
SS = 2
TMP = tempfile.mkdtemp(prefix='ostatok_world_hd_')
ROOT = os.path.dirname(os.path.dirname(HERE))


def match_palette(img, ref_path, strength=1.0):
    """scale an HD render so its mean colour matches the 1x art it replaces:
    new detail, the game's established palette."""
    if not os.path.exists(ref_path):
        return img
    ref = np.array(Image.open(ref_path).convert('RGBA')).astype(float)
    m = ref[..., 3] > 0
    target = ref[m][:, :3].mean(axis=0)
    a = np.array(img.convert('RGB')).astype(float)
    cur = a.reshape(-1, 3).mean(axis=0)
    k = 1.0 + (target / np.maximum(cur, 1.0) - 1.0) * strength
    return Image.fromarray(clamp8(a * k[None, None, :]), 'RGB')


# ------------------------------------------------------------------ scene ---
def oblique_scene(x0, y0, w, h, samples=48, sun=2.1, amb=0.56):
    """Cycles scene with a top-down ortho camera over the screen rectangle
    [x0, x0+w] x [y0, y0+h] (screen y = y - z) and the sheared game light."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bk._MAT.clear()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 3
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    wd = bpy.data.worlds.new('w')
    sc.world = wd
    wd.use_nodes = True
    bg = wd.node_tree.nodes['Background']
    bg.inputs[0].default_value = (0.93, 0.95, 1.0, 1)
    bg.inputs[1].default_value = amb
    L = wa_town.LIGHT
    Ls = np.array([L[0], L[2] - L[1], L[2]])
    Ls /= np.linalg.norm(Ls)
    d = Vector((float(Ls[0]), float(Ls[1]), float(Ls[2])))
    s = bpy.data.lights.new('sun', 'SUN')
    s.energy = sun
    s.angle = math.radians(3)
    s.color = (1.0, 0.97, 0.92)
    so = bpy.data.objects.new('sun', s)
    sc.collection.objects.link(so)
    so.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam = bpy.data.cameras.new('cam')
    cam.type = 'ORTHO'
    cam.ortho_scale = max(w, h)
    cam.clip_start = 1
    cam.clip_end = 10000
    co = bpy.data.objects.new('cam', cam)
    sc.collection.objects.link(co)
    sc.camera = co
    co.location = (x0 + w / 2, -(y0 + h / 2), 3000)
    sc.render.resolution_x = int(round(w * HD * SS))
    sc.render.resolution_y = int(round(h * HD * SS))
    sc.render.resolution_percentage = 100
    return sc


SHEAR = Matrix(((1, 0, 0, 0), (0, 1, 1, 0), (0, 0, 1, 0), (0, 0, 0, 1)))


def shear_all():
    """game-built objects (bk.G coords) -> lifted-roof projection space."""
    for o in bpy.context.scene.objects:
        if o.type in ('MESH', 'CURVE'):
            o.matrix_world = SHEAR @ o.matrix_world


def render_raw(name):
    path = os.path.join(TMP, name + '.png')
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return Image.open(path).convert('RGBA')


def downsample(img, w_px, h_px):
    return img.resize((w_px, h_px), Image.BOX)


def image_material(img, rough=0.85, bump=0.0, name='im', repeat=True):
    path = os.path.join(TMP, '%s_%d.png' % (name, id(img)))
    img.save(path)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(path)
    t.interpolation = 'Closest'
    t.extension = 'REPEAT' if repeat else 'CLIP'
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = rough
    b.inputs['Specular IOR Level'].default_value = 0.3
    if bump > 0:
        bw = nt.nodes.new('ShaderNodeRGBToBW')
        bn = nt.nodes.new('ShaderNodeBump')
        bn.inputs['Strength'].default_value = bump
        bn.inputs['Distance'].default_value = 0.4
        nt.links.new(t.outputs['Color'], bw.inputs['Color'])
        nt.links.new(bw.outputs['Val'], bn.inputs['Height'])
        nt.links.new(bn.outputs['Normal'], b.inputs['Normal'])
    return m


def heightfield(hf, albedo, tile, origin=(0.0, 0.0), z0=0.0, copies=1, res=2, rough=0.85, bump=0.0, name='hf'):
    """horizontal periodic height field: hf/albedo are (N, N) / (N, N, 3) arrays
    sampled over one tile (world units `tile`); copies=1 adds the 8 neighbours."""
    n = hf.shape[0]
    step = tile / n
    m = image_material(Image.fromarray(clamp8(albedo), 'RGB'), rough=rough, bump=bump, name=name)
    for cy in range(-copies, copies + 1):
        for cx in range(-copies, copies + 1):
            verts, faces, uvs = [], [], []
            N = n + 1
            for j in range(N):
                for i in range(N):
                    x = origin[0] + (cx * n + i) * step
                    y = origin[1] + (cy * n + j) * step
                    z = z0 + float(hf[j % n, i % n])
                    verts.append(bk.G(x, y, z))
                    uvs.append((i / n, 1.0 - j / n))
            for j in range(n):
                for i in range(n):
                    a = j * N + i
                    faces.append((a, a + N, a + N + 1, a + 1))
            me = bpy.data.meshes.new(name)
            me.from_pydata([tuple(v) for v in verts], [], faces)
            me.update()
            uvl = me.uv_layers.new(name='UV')
            for poly in me.polygons:
                for li in poly.loop_indices:
                    uvl.data[li].uv = uvs[me.loops[li].vertex_index]
            for p in me.polygons:
                p.use_smooth = True
            o = bpy.data.objects.new(name, me)
            bpy.context.scene.collection.objects.link(o)
            o.data.materials.append(m)


# --------------------------------------------------------- roof materials ---
T = 64          # roof tile, world units (128 px HD)
NS = 128        # height-field samples per tile side


def _grid():
    v = (np.arange(NS) + 0.5) / NS * T
    return np.meshgrid(v, v)


def _noise(seed, cell=10, oct=4):
    return fbm(NS, NS, cell, seed, oct, wrap=True)


def _tint(base, n, k=0.18):
    return np.array(base, float)[None, None, :] * (1 - k / 2 + k * n)[..., None]


def _mix(a, col, m):
    return a * (1 - m[..., None]) + np.array(col, float)[None, None, :] * m[..., None]


def _leaves(alb, seed, density=0.0025):
    rng = np.random.default_rng(seed)
    k = int(NS * NS * density)
    for _ in range(k):
        x, y = rng.integers(0, NS, 2)
        c = LEAF_ORANGE[rng.integers(0, len(LEAF_ORANGE))]
        alb[y, x] = c
        alb[y, (x + 1) % NS] = np.array(c) * 0.8
    return alb


def _speckle(alb, density, cols, seed):
    rng = np.random.default_rng(seed)
    m = rng.random((NS, NS)) < density
    idx = rng.integers(0, len(cols), (NS, NS))
    for i, c in enumerate(cols):
        alb[m & (idx == i)] = c
    return alb


def _clusters(alb, mask, cols, seed, density=0.08):
    """crisp 1-3 px clusters (moss tufts, lichen, grit) where mask is set."""
    rng = np.random.default_rng(seed)
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return alb
    k = int(len(xs) * density)
    pick = rng.integers(0, len(xs), k)
    for i in pick:
        x, y = xs[i], ys[i]
        c = np.array(cols[rng.integers(0, len(cols))], float)
        alb[y, x] = c
        if rng.random() < 0.6:
            alb[y, (x + 1) % NS] = c * 0.82
        if rng.random() < 0.4:
            alb[(y + 1) % NS, x] = c * 0.66
    return alb


def _blobs(alb, seed, cell, thr, col, edge=None, core=None):
    """hard-edged patches (rust, peeled paint, stains) from thresholded noise."""
    n = fbm(NS, NS, cell, seed, 4, wrap=True)
    m = n > thr
    alb[m] = alb[m] * 0.25 + np.array(col, float) * 0.75
    if core is not None:
        c = n > thr + 0.06
        alb[c] = alb[c] * 0.2 + np.array(core, float) * 0.8
    if edge is not None:
        e = m & ~np.roll(m, 1, 0)
        alb[e] = np.array(edge, float)
    return alb


def _cracks(alb, hf, seed, n, col, depth=0.25):
    from wa_core import Tex
    t = Tex(NS, NS, seed=seed)
    for _ in range(n):
        x, y = t.rng.uniform(0, NS), t.rng.uniform(0, NS)
        for (px, py) in t.crack(x, y, t.rng.randint(14, 34), (0, 0, 0), None, 0.6):
            ix, iy = int(px) % NS, int(py) % NS
            alb[iy, ix] = col
            hf[iy, ix] -= depth
    return alb, hf


def roof_bitumen():
    X, Y = _grid()
    n = _noise(11)
    hf = np.zeros((NS, NS))
    # rolls 16 units wide running east-west, raised welded laps
    lap = (Y % 16)
    hf += np.where(lap < 1.4, 0.45 * (1 - lap / 1.4), 0.0)
    hf += 0.12 * (_noise(12, 6, 3) - 0.5)                 # wrinkles
    alb = _tint((60, 62, 60), n, 0.26)
    alb = _mix(alb, (40, 42, 42), ((lap >= 1.4) & (lap < 2.4)) * 0.8)      # shadow under the lap
    alb = _mix(alb, (84, 86, 82), (lap < 0.8) * 0.6)                          # lit welded edge
    alb = _mix(alb, (96, 92, 82), np.clip((_noise(13, 18) - 0.66) * 4, 0, 1) * 0.5)   # dust drifts
    alb = _mix(alb, (74, 88, 52), np.clip((_noise(14, 9) - 0.74) * 6, 0, 1) * (lap < 2.5) * 0.8)   # moss in laps
    alb = _mix(alb, (40, 42, 42), np.clip((_noise(16, 20) - 0.62) * 3, 0, 1) * 0.5)   # patched / re-tarred areas
    alb = _speckle(alb, 0.10, [(84, 84, 80), (44, 46, 46), (98, 94, 86)], 17)
    alb = _clusters(alb, lap < 2.2, [(78, 96, 50), (96, 112, 58), (60, 74, 40)], 18, 0.12)
    alb, hf = _cracks(alb, hf, 19, 3, (34, 36, 36), 0.15)
    return hf, _leaves(alb, 15)


def roof_slab():
    X, Y = _grid()
    n = _noise(21)
    hf = np.zeros((NS, NS))
    jx, jy = X % 32, Y % 32
    joint = (jx < 1.0) | (jy < 1.0)
    hf -= joint * 0.5
    # slabs sit at slightly different heights
    idx = (np.floor(X / 32) + 3 * np.floor(Y / 32)) % 4
    hf += idx * 0.08
    alb = _tint((118, 116, 108), n, 0.24)
    alb += (idx[..., None] - 1.5) * 4
    alb = _mix(alb, (70, 70, 66), joint * 0.8)
    alb = _mix(alb, (78, 92, 54), np.clip((_noise(22, 7) - 0.7) * 5, 0, 1) * joint * 1.0)
    alb = _mix(alb, (84, 82, 76), np.clip((_noise(23, 16) - 0.55) * 3, 0, 1) * 0.45)   # water stains
    alb = _mix(alb, (78, 92, 54), np.clip((_noise(24, 6) - 0.78) * 6, 0, 1) * 0.7)     # moss cushions
    alb = _speckle(alb, 0.08, [(146, 142, 132), (96, 94, 88), (110, 106, 98)], 26)
    alb, hf = _cracks(alb, hf, 27, 5, (70, 68, 64), 0.3)
    alb = _clusters(alb, joint, [(78, 96, 50), (96, 112, 58), (60, 74, 40)], 28, 0.35)
    return hf, _leaves(alb, 25)


def _corrugated(base, seed, rust, period=4.0, amp=0.55, sheet=32.0):
    X, Y = _grid()
    n = _noise(seed)
    hf = amp * np.sin(X / period * 2 * math.pi)
    lap = Y % sheet
    hf += np.where(lap < 1.5, 0.35, 0.0)                    # sheet overlap step
    alb = _tint(base, n, 0.16)
    shade = 0.5 + 0.5 * np.sin(X / period * 2 * math.pi + 1.2)
    alb *= (0.9 + 0.12 * shade)[..., None]
    alb = _blobs(alb, seed + 1, 9, 0.66 - rust * 0.22, (122, 66, 36), edge=(146, 88, 50), core=(84, 42, 22))
    alb = _speckle(alb, 0.04, [(132, 74, 40), (70, 40, 24)], seed + 3)
    alb = _mix(alb, (40, 38, 34), (lap < 1.5) * 0.45)
    # fasteners along the overlap
    bolt = ((X % 8) < 1.0) & (np.abs(lap - 3) < 1.0)
    alb = _mix(alb, (200, 196, 180), bolt * 0.6)
    return hf, alb


def roof_corrugated_rust():
    hf, alb = _corrugated((104, 82, 62), 31, 0.6)
    return hf, _leaves(alb, 35)


def roof_corrugated_blue():
    hf, alb = _corrugated((76, 92, 104), 41, 0.3)
    return hf, _leaves(alb, 45, 0.0015)


def roof_standing_seam():
    X, Y = _grid()
    n = _noise(51)
    s = X % 12.8
    hf = np.where(s < 1.2, 0.9, 0.0) + 0.05 * (_noise(52, 5) - 0.5)
    alb = _tint((128, 56, 42), n, 0.24)
    alb = _mix(alb, (176, 80, 60), (s < 1.2) * 0.5)
    alb = _mix(alb, (70, 30, 22), ((s >= 1.2) & (s < 2.4)) * 0.75)            # seam shadow
    alb = _mix(alb, (118, 70, 48), np.clip((_noise(53, 9) - 0.62) * 4, 0, 1) * 0.6)    # faded paint
    alb = _mix(alb, (96, 52, 30), np.clip((_noise(54, 5) - 0.72) * 6, 0, 1) * 0.8)
    alb = _blobs(alb, 58, 10, 0.68, (112, 64, 46), edge=(150, 78, 58))
    alb = _speckle(alb, 0.035, [(96, 52, 30), (160, 90, 64)], 59)
    streak = np.clip((fbm(NS, NS, 3, 56, 2, wrap=True) - 0.5) * 3, 0, 1) * np.clip((_noise(57, 20) - 0.5) * 3, 0, 1)
    alb = _mix(alb, (104, 58, 34), streak * 0.5)                                              # rust runs
    return hf, _leaves(alb, 55, 0.003)


def roof_shifer():
    X, Y = _grid()
    n = _noise(61)
    row = Y % 16
    hf = 0.6 * np.sin(X / 5.33 * 2 * math.pi) + row * 0.06         # sheets step down the slope
    hf += np.where(row > 15.0, -0.8, 0.0)
    alb = _tint((130, 130, 122), n, 0.22)
    shade = 0.5 + 0.5 * np.sin(X / 5.33 * 2 * math.pi + 1.2)
    alb *= (0.9 + 0.12 * shade)[..., None]
    alb = _mix(alb, (80, 92, 56), np.clip((_noise(62, 7) - 0.62) * 4, 0, 1) * 0.75)    # moss
    alb = _mix(alb, (60, 62, 58), (row > 14.5) * 0.5)
    alb = _clusters(alb, _noise(64, 9) > 0.58, [(80, 98, 52), (98, 116, 60), (196, 150, 52)], 65, 0.18)
    alb = _speckle(alb, 0.05, [(112, 112, 106), (156, 156, 148)], 66)
    return hf, _leaves(alb, 65)


ROOFS = [roof_bitumen, roof_slab, roof_corrugated_rust, roof_corrugated_blue, roof_standing_seam, roof_shifer]


def bake_roof_tile(i):
    hf, alb = ROOFS[i]()
    # rendered with neighbours; camera over the central tile in screen space
    oblique_scene(0, 0, T, T, samples=32, sun=1.8, amb=0.46)
    heightfield(hf, alb, T, copies=1, rough=0.8, bump=0.25, name='roof%d' % i)
    shear_all()
    raw = render_raw('roof%d' % i)
    tile = downsample(raw, T * HD, T * HD).convert('RGB')
    tile = match_palette(tile, os.path.join(ROOT, 'roof_tile_s%d_v3.png' % i))
    tile = tile.quantize(40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
    return tile


def build_roofs(P):
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    for i in range(len(ROOFS)):
        bake_roof_tile(i).save(os.path.join(out, 'roof_tile_s%d_hd.png' % i))
        print('roof tile', i, flush=True)


# ------------------------------------------------------------- sprites ---
def post_sprite(raw, w_px, h_px, colours=48, outline=True):
    """supersampled oblique render -> HD pixel-art sprite with the game outline."""
    im = raw.resize((w_px, h_px), Image.BOX)
    a = np.array(im).astype(float)
    al = a[..., 3]
    solid = al >= 120
    rgb = np.where(al[..., None] > 0, a[..., :3] / np.maximum(al[..., None] / 255.0, 1e-3), 0)
    out = np.zeros((h_px, w_px, 4), np.uint8)
    out[solid, :3] = clamp8(rgb[solid])
    out[solid, 3] = 255
    img = Image.fromarray(out, 'RGBA')
    if colours:
        q = img.convert('RGB').quantize(colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
        o2 = np.array(img)
        o2[solid, :3] = np.array(q)[solid]
        img = Image.fromarray(o2, 'RGBA')
    if outline:
        o2 = np.array(img)
        A = o2[..., 3] == 255
        g = np.zeros_like(A)
        g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
        o2[g & ~A] = (18, 16, 14, 255)
        img = Image.fromarray(o2, 'RGBA')
    return img


def bake_object(fn, cell=64, name='obj'):
    """model built by fn() around the cell centre, rendered over one cell."""
    oblique_scene(-cell / 2, -cell / 2, cell, cell, samples=40)
    fn()
    shear_all()
    return post_sprite(render_raw(name), cell * HD, cell * HD)


M = bk.mat
CONC = (142, 140, 130)


def steel(c=(120, 124, 124)):
    return M(c, rough=0.5, metal=0.5, grime=0.14)


def rust(c=(118, 74, 46)):
    return M(c, rough=0.85, metal=0.2, grime=0.3, scale=0.2)


# roof_props_v4: 0 AC unit, 1 vent stacks, 2 twin boxes, 3 antenna
def rp_ac():
    by = 10
    bk.box((0, by - 6, 0.5), (14, 9, 0.5), M(CONC, rough=0.9), bevel=0.3)
    bk.box((0, by - 6, 8), (13, 8, 7), M((176, 178, 172), rough=0.55, metal=0.2), bevel=0.8)
    for k in range(-11, 2, 2):
        bk.box((k, by + 2.2, 6), (0.4, 0.2, 5), M((110, 112, 108)), bevel=0)
    bk.cyl((7, by + 2.3, 8.5), 4.6, 0.6, M((60, 62, 60), rough=0.6), axis='y', bevel=0.2)
    bk.cyl((7, by + 2.6, 8.5), 3.6, 0.4, M((28, 28, 28), rough=1), axis='y', bevel=0)
    for a in range(4):
        bk.box((7, by + 2.8, 8.5), (3.2, 0.2, 0.5), M((150, 152, 148)), bevel=0, rot=(0, a * 0.785, 0))
    bk.box((-7, by + 2.2, 11.5), (4, 0.3, 2), M((90, 92, 90)), bevel=0.2)
    bk.tube([(-12, by - 2, 2), (-16, by - 2, 2), (-16, by - 12, 2)], 0.7, M((60, 60, 58)))


def rp_vents():
    by = 12
    bk.box((0, by - 6, 1), (16, 8, 1), M(CONC, rough=0.9), bevel=0.4)
    for (x, y, r, h) in ((-9, by - 4, 3.2, 20), (0, by - 7, 3.6, 28), (9, by - 3, 2.8, 16)):
        bk.cyl((x, y, 2), r, h, steel(), bevel=0.4)
        bk.cyl((x, y, 2 + h), r + 1.4, 1.2, steel((96, 98, 96)), bevel=0.3)
        bk.cyl((x, y, 3.2 + h), r + 0.6, 0.8, M((40, 40, 38)), bevel=0.2)
        bk.box((x, y + r, 2 + h * 0.4), (r * 0.8, 0.3, 1.2), rust(), bevel=0)


def rp_twin():
    by = 10
    bk.box((-8, by - 6, 7), (9, 7, 7), M((86, 112, 126), rough=0.5, metal=0.2), bevel=0.8)
    bk.box((10, by - 5, 5), (6, 6, 5), M((150, 152, 148), rough=0.55, metal=0.2), bevel=0.6)
    for k in range(-15, -1, 2):
        bk.box((k, by + 1.2, 6), (0.4, 0.2, 4.5), M((60, 76, 86)), bevel=0)
    bk.box((10, by + 1.2, 6), (3.6, 0.2, 2.4), M((70, 72, 70)), bevel=0.1)
    bk.tube([(-2, by - 4, 3), (4, by - 4, 3)], 0.8, M((60, 60, 58)))


def rp_antenna():
    by = 8
    bk.box((0, by - 4, 1), (6, 6, 1), M(CONC, rough=0.9), bevel=0.3)
    mast = steel((70, 72, 70))
    bk.cyl((0, by - 4, 2), 0.8, 40, mast, bevel=0.1)
    for z in (24, 32, 38):
        bk.box((0, by - 4, z), (9 - z * 0.12, 0.4, 0.4), mast, bevel=0)
        for xx in (-6, 0, 6):
            bk.box((xx * (1 - z / 60), by - 4, z - 2), (0.25, 0.25, 2), mast, bevel=0)
    for (dx, dy) in ((-9, 4), (9, 4), (0, -9)):
        bk.tube([(0, by - 4, 30), (dx, by - 4 + dy, 2)], 0.2, M((40, 40, 38)))
    d = bk.cyl((5, by - 2, 16), 5, 1.2, M((220, 220, 214), rough=0.4), axis='y', bevel=0.4)
    d.rotation_euler = (math.radians(70), 0, math.radians(-20))
    bk.cyl((5, by - 2, 4), 0.6, 12, mast, bevel=0.1)


# roof_details_v1: water_tank, sat_dish, stair_housing, pipe_run, roof_puddle, roof_debris, vent_small, skylight_row
def rd_water_tank():
    by = 16
    for (x, y) in ((-5, by - 9), (5, by - 9), (-5, by - 2), (5, by - 2)):
        bk.box((x, y, 3), (0.8, 0.8, 3), M((40, 40, 38)), bevel=0.1)
    bk.cyl((0, by - 6, 6), 8.5, 16, M((70, 104, 132), rough=0.5, metal=0.3, grime=0.2), bevel=0.8)
    for z in (11, 16):
        bk.cyl((0, by - 6, z), 8.8, 0.6, M((52, 78, 100)), bevel=0.1)
    bk.cyl((0, by - 6, 22), 8.9, 1.0, M((60, 90, 116)), bevel=0.4)
    bk.box((0, by + 2.8, 14), (1.8, 0.4, 5), rust(), bevel=0.1)


def rd_sat_dish():
    by = 12
    bk.box((0, by - 4, 2), (4, 4, 2), M((70, 72, 70)), bevel=0.3)
    bk.cyl((0, by - 4, 4), 0.8, 10, steel(), bevel=0.1)
    d = bk.sphere((2, by - 2, 22), 11, M((214, 214, 208), rough=0.45), scale=(1, 0.35, 1))
    d.rotation_euler = (0, 0, math.radians(-25))
    bk.tube([(2, by + 2, 22), (6, by + 8, 20)], 0.3, M((50, 50, 48)))
    bk.box((6, by + 8, 20), (0.8, 0.8, 0.8), M((60, 60, 58)), bevel=0.1)


def rd_stair_housing():
    by = 16
    bk.box((0, by - 10, 10), (16, 12, 10), M(CONC, rough=0.85, grime=0.2), bevel=0.6)
    bk.box((0, by - 10, 20.8), (17, 13, 0.8), M((96, 96, 92), rough=0.9), bevel=0.3)
    bk.box((5, by + 2.1, 7), (4, 0.3, 7), M((90, 76, 60), rough=0.8), bevel=0.2)
    bk.box((-8, by + 2.1, 12), (3, 0.3, 2), M((30, 36, 40), rough=0.3), bevel=0.1)
    bk.cyl((-10, by - 16, 21), 1.4, 6, steel(), bevel=0.2)


def rd_pipe_run():
    by = 6
    p = steel((150, 152, 148))
    bk.cyl((-6, by, 4), 2.6, 44, p, axis='x', bevel=0.3)
    bk.cyl((16, by - 4, 4), 2.6, 8, p, axis='y', bevel=0.3)
    bk.cyl((16, by - 8, 4), 2.6, 9, p, bevel=0.3)
    for x in (-22, -8, 6):
        bk.box((x, by, 1), (1.2, 2.4, 1), M((60, 60, 58)), bevel=0.2)
        bk.cyl((x + 2, by, 4), 2.9, 1, rust(), axis='x', bevel=0.2)


def rd_puddle():
    import random
    rng = random.Random(7)
    pts = []
    for i in range(14):
        a = i / 14 * math.tau
        r = rng.uniform(0.75, 1.0)
        pts.append((math.cos(a) * 22 * r, math.sin(a) * 12 * r + 2, 0.15))
    bk.mesh(pts, [tuple(range(len(pts)))], M((46, 58, 66), rough=0.08, grime=0.05))


def rd_empty():
    pass


def rd_vent_small():
    by = 8
    for (x, y, h) in ((-6, by - 2, 7), (6, by - 4, 9), (1, by + 3, 6)):
        bk.cyl((x, y, 0), 2.4, h, steel(), bevel=0.3)
        bk.cyl((x, y, h), 3.6, 1.4, steel((100, 102, 100)), bevel=0.3)
        bk.cyl((x, y, h + 1.4), 2.6, 1.4, steel((84, 86, 84)), bevel=0.3)


def rd_skylights():
    by = 6
    for x in (-18, 0, 18):
        bk.box((x, by - 4, 1.5), (8, 7, 1.5), M(CONC, rough=0.9), bevel=0.3)
        bk.mesh([(x - 7, by + 2, 3), (x + 7, by + 2, 3), (x + 7, by - 10, 7), (x - 7, by - 10, 7)], [(0, 1, 2, 3)],
                M((80, 110, 124), rough=0.12) if x != 0 else M((30, 32, 34), rough=0.9))
        bk.box((x, by - 4, 5), (0.4, 6.4, 0.6), M((150, 150, 144)), bevel=0)


ROOF_PROPS = [rp_ac, rp_vents, rp_twin, rp_antenna]
ROOF_DETAILS = [rd_water_tank, rd_sat_dish, rd_stair_housing, rd_pipe_run, rd_puddle, rd_empty, rd_vent_small, rd_skylights]


def build_roof_objects(P):
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    sheet = Image.new('RGBA', (len(ROOF_PROPS) * 128, 128))
    for i, fn in enumerate(ROOF_PROPS):
        sheet.alpha_composite(bake_object(fn, 64, 'rp%d' % i), (i * 128, 0))
        print('roof prop', i, flush=True)
    sheet.save(os.path.join(out, 'roof_props_hd.png'))
    sheet = Image.new('RGBA', (len(ROOF_DETAILS) * 128, 128))
    for i, fn in enumerate(ROOF_DETAILS):
        if fn is rd_empty:
            continue
        sheet.alpha_composite(bake_object(fn, 64, 'rd%d' % i), (i * 128, 0))
        print('roof detail', i, flush=True)
    sheet.save(os.path.join(out, 'roof_details_hd.png'))


# ------------------------------------------------------------ roof edges ---
EDGE_COLS = [((150, 148, 138), 'conc'), ((150, 148, 138), 'conc'), ((112, 76, 52), 'metal'),
             ((76, 92, 104), 'metal'), ((128, 56, 42), 'gutter'), ((120, 120, 112), 'ridge')]


def edge_field(style):
    """north parapet / eave seen from above: 64 x 8 units, periodic along x."""
    nx, ny = 128, 28
    x = (np.arange(nx) + 0.5) / nx * 64
    y = (np.arange(ny) + 0.5) / ny * 14
    X, Y = np.meshgrid(x, y)
    col, kind = EDGE_COLS[style]
    n = fbm(nx, ny, 6, 70 + style, 3, wrap=True)
    alb = np.array(col, float)[None, None, :] * (0.9 + 0.2 * n)[..., None]
    if kind == 'conc':
        hf = np.where(Y < 6.0, 3.0, 0.0) + np.where(Y < 5.2, 0.4, 0.0)       # parapet with coping
        joint = (X % 16) < 0.8
        alb[joint & (Y < 6)] *= 0.7
        alb[Y >= 6.0] *= 0.55                                                  # inner shadow on the roof
    elif kind == 'metal':
        hf = np.where(Y < 3.0, 1.2, 0.0)
        alb[Y < 1.0] *= 1.2
        alb[(Y >= 3.0) & (Y < 4.0)] *= 0.5
    elif kind == 'gutter':
        hf = np.where(Y < 2.5, 0.6, 0.0) + np.where((Y > 0.5) & (Y < 2.0), -0.4, 0.0)
        alb[Y < 2.5] = np.array((96, 98, 96), float) * (0.9 + 0.2 * n[Y < 2.5])[..., None]
    else:
        hf = np.where(Y < 3.0, 1.0 + 0.4 * np.sin(X / 5.33 * 2 * math.pi), 0.0)
        alb[(Y >= 3.0) & (Y < 4.0)] *= 0.6
    return hf, alb


def bake_edge(style):
    hf, alb = edge_field(style)
    ny, nx = hf.shape
    oblique_scene(0, 0, 64, 8, samples=32, sun=1.8, amb=0.46)
    # rectangular periodic field: reuse the square builder by tiling three copies along x
    m = image_material(Image.fromarray(clamp8(alb), 'RGB'), rough=0.8, name='edge%d' % style)
    stepx, stepy = 64 / nx, 14 / ny
    for cx in (-1, 0, 1):
        verts, faces, uvs = [], [], []
        N = nx + 1
        for j in range(ny + 1):
            for i in range(N):
                verts.append(tuple(bk.G(cx * 64 + i * stepx, j * stepy, float(hf[min(j, ny - 1), i % nx]))))
                uvs.append((i / nx, 1 - j / ny))
        for j in range(ny):
            for i in range(nx):
                a = j * N + i
                faces.append((a, a + N, a + N + 1, a + 1))
        me = bpy.data.meshes.new('e')
        me.from_pydata(verts, [], faces)
        me.update()
        uvl = me.uv_layers.new(name='UV')
        for poly in me.polygons:
            for li in poly.loop_indices:
                uvl.data[li].uv = uvs[me.loops[li].vertex_index]
        o = bpy.data.objects.new('e', me)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(m)
    shear_all()
    raw = render_raw('edge%d' % style)
    h = downsample(raw, 128, 16)
    a = np.array(h).astype(float)
    al = np.maximum(a[..., 3:4] / 255.0, 1e-3)
    a[..., :3] = np.where(a[..., 3:4] > 0, a[..., :3] / al, 0)
    a[..., 3] = 255
    h = Image.fromarray(clamp8(a), 'RGBA').convert('RGB')
    h = h.quantize(32, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
    return h


def build_roof_edges(P):
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    for st in range(6):
        h = bake_edge(st)
        h.save(os.path.join(out, 'roof_edge_h_s%d_hd.png' % st))
        # west edge strip: the north strip turned so its outer side faces west
        h.rotate(90, expand=True).transpose(Image.FLIP_TOP_BOTTOM).save(os.path.join(out, 'roof_edge_v_s%d_hd.png' % st))
        print('roof edge', st, flush=True)


if __name__ == '__main__':
    P = sys.argv[1] if len(sys.argv) > 1 else '.'
    parts = sys.argv[2:] or ['roofs']
    if 'roofs' in parts:
        build_roofs(P)
    if 'edges' in parts:
        build_roof_edges(P)
    if 'roofobj' in parts:
        build_roof_objects(P)
