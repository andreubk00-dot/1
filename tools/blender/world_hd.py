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
    """game-built objects (bk.G coords) -> lifted-roof projection space.
    An object matrix cannot hold a shear (Blender re-derives it from
    location/rotation/scale), so the transform is baked into the data."""
    bpy.context.view_layer.update()
    done = set()
    for o in list(bpy.context.scene.objects):
        if o.type not in ('MESH', 'CURVE'):
            continue
        if o.data.name in done:
            continue
        mw = o.matrix_world.copy()
        o.data.transform(mw)
        o.data.transform(SHEAR)
        o.matrix_world = Matrix.Identity(4)
        done.add(o.data.name)


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


# --------------------------------------------------------------- walls ---
# facade_wall_tiles_v4: 4 variants (32 u) x 7 styles (28 u). variant 0 plain,
# 1 downpipe, 2 split AC unit, 3 cracked / scrawled. Styles: 0 panel, 1 clinic
# tile, 2 shop plaster, 3 brick, 4 corrugated, 5 military brick, 6 rural planks.
WT_W, WT_H = 32, 28


def _wgrid(w, h):
    nu, nv = w * HD, h * HD
    u = (np.arange(nu) + 0.5) / HD
    v = (np.arange(nv) + 0.5) / HD          # v measured from the top of the tile
    return np.meshgrid(u, v)


def _wnoise(w, h, seed, cell=6, oct=3):
    return fbm(w * HD, h * HD, cell, seed, oct, wrap=True)


def wall_field(style, variant, w=WT_W, h=WT_H, seed=0):
    U, V = _wgrid(w, h)
    n = _wnoise(w, h, 300 + style * 7 + variant + seed)
    hf = np.zeros(U.shape)
    if style == 0:            # precast concrete panels
        base = np.array((146, 142, 130), float)
        joint = ((U % 16) < 0.7) | ((V % 14) < 0.7)
        hf -= joint * 0.5
        alb = base * (0.9 + 0.18 * n)[..., None]
        alb[joint] *= 0.62
        alb = _wblob(alb, 301 + variant, w, h, 8, 0.7, (118, 114, 104))
    elif style == 1:          # glazed tiles with a green band
        tile = ((U % 4) < 0.45) | ((V % 4) < 0.45)
        hf -= tile * 0.2
        alb = np.array((214, 212, 200), float) * (0.92 + 0.1 * n)[..., None]
        alb[tile] = (168, 166, 156)
        band = (V > 14) & (V < 17)
        alb[band] = np.array((86, 140, 116), float) * (0.9 + 0.12 * n[band])[..., None]
        hf += band * 0.25
        alb = _wblob(alb, 311 + variant, w, h, 7, 0.74, (182, 176, 160))
    elif style == 2:          # rendered plaster
        alb = np.array((178, 156, 116), float) * (0.88 + 0.22 * n)[..., None]
        hf += 0.15 * (_wnoise(w, h, 320 + variant, 2, 2) - 0.5)
        alb = _wblob(alb, 321 + variant, w, h, 6, 0.72, (150, 128, 92), edge=(196, 176, 140))
    elif style in (3, 5):     # brick (red) / painted brick blocks (military green)
        bw, bh = (6.0, 3.0) if style == 3 else (8.0, 4.0)
        row = np.floor(V / bh)
        off = (row % 2) * bw * 0.5
        mortar = ((V % bh) < 0.6) | (((U + off) % bw) < 0.6)
        hf += np.where(mortar, -0.4, 0.15 * (_wnoise(w, h, 330 + variant, 2, 2)))
        if style == 3:
            k = (np.floor((U + off) / bw) * 7 + row * 3) % 5
            alb = np.array((140, 72, 52), float)[None, None, :] * (0.86 + 0.06 * k + 0.1 * n)[..., None]
            alb[mortar] = (150, 140, 124)
        else:
            alb = np.array((94, 108, 76), float) * (0.88 + 0.16 * n)[..., None]
            alb[mortar] = (70, 80, 58)
            alb = _wblob(alb, 335 + variant, w, h, 7, 0.7, (124, 118, 100), edge=(140, 132, 112))
    elif style == 4:          # corrugated cladding, rust
        hf += 0.5 * np.sin(U / 3.0 * 2 * math.pi)
        alb = np.array((110, 118, 120), float) * (0.9 + 0.12 * n)[..., None]
        alb *= (0.9 + 0.12 * (0.5 + 0.5 * np.sin(U / 3.0 * 2 * math.pi + 1.2)))[..., None]
        alb = _wblob(alb, 341 + variant, w, h, 6, 0.6, (124, 66, 36), edge=(150, 88, 50))
    else:                     # rural planks, four paints
        plank = (V % 4) < 0.5
        hf += np.where(plank, -0.35, 0.1 * (V % 4) / 4)
        paint = [(66, 104, 136), (86, 122, 82), (176, 138, 64), (128, 100, 72)][variant]
        alb = np.array(paint, float) * (0.86 + 0.2 * n)[..., None]
        alb[plank] *= 0.55
        alb = _wblob(alb, 351 + variant, w, h, 7, 0.7, (120, 96, 70), edge=(150, 124, 94))    # paint peeled to wood
    # grime: rain streaks from the top, damp at the foot
    streak = np.clip((_wnoise(w, h, 360 + style + variant, 2, 2) - 0.55) * 4, 0, 1) * np.clip(1.0 - V / h * 1.4, 0, 1)
    alb *= (1 - 0.18 * streak)[..., None]
    alb *= (1 - 0.07 * np.clip((V - h * 0.8) / (h * 0.2), 0, 1))[..., None]
    if variant == 3 and style != 6:
        alb, hf = _wcracks(alb, hf, 370 + style, w, h)
    return hf, alb


def _wblob(alb, seed, w, h, cell, thr, col, edge=None):
    n = fbm(w * HD, h * HD, cell, seed, 4, wrap=True)
    m = n > thr
    alb[m] = alb[m] * 0.3 + np.array(col, float) * 0.7
    if edge is not None:
        e = m & ~np.roll(m, 1, 0)
        alb[e] = edge
    return alb


def _wcracks(alb, hf, seed, w, h):
    from wa_core import Tex
    t = Tex(w * HD, h * HD, seed=seed)
    for _ in range(2):
        x, y = t.rng.uniform(w * HD * 0.5, w * HD - 4), t.rng.uniform(2, h * HD * 0.5)
        for (px, py) in t.crack(x, y, t.rng.randint(16, 30), (0, 0, 0), None, 0.7):
            ix, iy = int(px) % (w * HD), int(py) % (h * HD)
            alb[iy, ix] = (40, 38, 36)
            hf[iy, ix] -= 0.3
    return alb, hf


def wall_mesh(hf, alb, w, h, copies=1, name='wall', bump=0.15):
    """vertical relief panel facing the camera: u along x, v down from the top
    edge at z = h, relief toward +y; periodic copies along x for shadows."""
    nv, nu = hf.shape
    m = image_material(Image.fromarray(clamp8(alb), 'RGB'), rough=0.85, bump=bump, name=name)
    su, sv = w / nu, h / nv
    for cx, cz in [(a, b) for a in range(-copies, copies + 1) for b in range(-copies, copies + 1)]:
        verts, faces, uvs = [], [], []
        N = nu + 1
        for j in range(nv + 1):
            for i in range(N):
                d = float(hf[j % nv, i % nu])
                verts.append(tuple(bk.G(cx * w + i * su, d, cz * h + h - j * sv)))
                uvs.append((i / nu, 1 - j / nv))
        for j in range(nv):
            for i in range(nu):
                a = j * N + i
                faces.append((a, a + 1, a + N + 1, a + N))
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts, [], faces)
        me.update()
        uvl = me.uv_layers.new(name='UV')
        for poly in me.polygons:
            for li in poly.loop_indices:
                uvl.data[li].uv = uvs[me.loops[li].vertex_index]
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(m)


def _downpipe(x, h):
    p = M((110, 114, 112), rough=0.5, metal=0.4, grime=0.2)
    bk.cyl((x, 1.6, -2), 1.1, h + 4, p, bevel=0.2, verts=16)
    for z in (6, 20):
        bk.box((x, 1.0, z), (1.6, 1.0, 0.4), M((70, 72, 70)), bevel=0.1)


def _split_ac(x, z):
    body = M((168, 168, 160), rough=0.5, metal=0.2, grime=0.25)
    bk.box((x, 3.0, z), (5.5, 3.0, 3.6), body, bevel=0.5)
    bk.box((x, 6.05, z + 3.0), (5.3, 0.15, 0.4), M((120, 120, 112)), bevel=0)
    for k in range(-5, 0):
        bk.box((x + k * 0.9, 6.05, z - 0.4), (0.22, 0.12, 2.6), M((96, 96, 90)), bevel=0)
    bk.cyl((x + 2.4, 6.1, z - 0.2), 2.4, 0.3, M((70, 70, 68), rough=0.6), axis='y', bevel=0)
    bk.cyl((x + 2.4, 6.3, z - 0.2), 1.9, 0.3, M((28, 28, 28), rough=1), axis='y', bevel=0)
    for a in range(3):
        bk.box((x + 2.4, 6.45, z - 0.2), (1.7, 0.1, 0.35), M((130, 130, 124)), bevel=0, rot=(0, a * 1.05, 0))
    bk.box((x, 2.8, z - 4.2), (5.0, 2.8, 0.3), M((84, 84, 80), metal=0.4), bevel=0)      # bracket shelf
    bk.box((x + 4.6, 6.1, z + 1.8), (0.6, 0.1, 0.9), M((118, 66, 40)), bevel=0)          # rust run
    bk.tube([(x - 5, 1.0, z - 2), (x - 7, 1.0, z - 9)], 0.35, M((40, 40, 38)))


def bake_wall_tile(style, variant):
    hf, alb = wall_field(style, variant)
    alb = alb.copy()
    oblique_scene(0, -WT_H, WT_W, WT_H, samples=32, sun=1.8, amb=0.46)
    wall_mesh(hf, alb, WT_W, WT_H, name='w%d%d' % (style, variant))
    if variant == 1 and style in (0, 1, 2, 3, 5):
        _downpipe(8.0, WT_H)
    if variant == 2 and style in (0, 2, 3, 5):
        _split_ac(19.0, 20.0)
    shear_all()
    raw = render_raw('w%d%d' % (style, variant))
    t = downsample(raw, WT_W * HD, WT_H * HD)
    a = np.array(t).astype(float)
    al = np.maximum(a[..., 3:4] / 255.0, 1e-3)
    a[..., :3] = np.where(a[..., 3:4] > 0, a[..., :3] / al, 0)
    a[..., 3] = 255
    return Image.fromarray(clamp8(a), 'RGBA')


def build_walls(P):
    out = os.path.join(P, 'art', 'world_hd')
    os.makedirs(out, exist_ok=True)
    sheet = Image.new('RGBA', (4 * WT_W * HD, 7 * WT_H * HD))
    ref = Image.open(os.path.join(ROOT, 'facade_wall_tiles_v4.png')).convert('RGBA')
    for st in range(7):
        row = Image.new('RGBA', (4 * WT_W * HD, WT_H * HD))
        for v in range(4):
            row.alpha_composite(bake_wall_tile(st, v), (v * WT_W * HD, 0))
        # palette matched per style row against the old art
        ref_row = ref.crop((0, st * WT_H, 4 * WT_W, (st + 1) * WT_H))
        tmp = os.path.join(TMP, 'ref_row.png')
        ref_row.save(tmp)
        row = match_palette(row.convert('RGB'), tmp, 0.85).quantize(64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
        sheet.alpha_composite(row, (0, st * WT_H * HD))
        print('wall row', st, flush=True)
    sheet.save(os.path.join(out, 'facade_wall_tiles_hd.png'))


# --------------------------------------------------------------- bands ---
# facade_bands_v1: per style 18 rows: 0-8 cornice (top of the facade),
# 8-18 plinth (ground course with weeds and litter). 32 u wide, periodic.
BAND_COLS = [(150, 146, 134), (206, 204, 192), (186, 168, 128), (150, 140, 124), (120, 124, 124), (110, 120, 92), (120, 96, 70)]


def band_field(style, part):
    w, h = 32, (8 if part == 'cornice' else 10)
    U, V = _wgrid(w, h)
    n = _wnoise(w, h, 400 + style * 3 + (part == 'plinth'), 3, 3)
    base = np.array(BAND_COLS[style], float)
    if part == 'cornice':
        hf = np.where(V < 2.5, 2.2, np.where(V < 4.0, 1.4, np.where(V < 5.0, 0.6, 0.0)))
        alb = base * (0.92 + 0.14 * n)[..., None]
        alb[(V >= 2.5) & (V < 3.0)] *= 0.7
        alb[V >= 5.0] *= 0.82
        if style == 3:
            alb[V >= 5.0] = (132, 70, 52)
    else:
        hf = np.where(V > 2.0, 0.8, 0.0)
        dark = np.array((88, 86, 80), float) if style != 6 else np.array((84, 70, 54), float)
        alb = dark * (0.88 + 0.2 * n)[..., None]
        alb[V <= 2.0] = base * 0.9
        alb[(V > 2.0) & (V < 2.6)] *= 0.6
        damp = np.clip((V - 3.0) / 7.0, 0, 1)
        alb *= (1 - 0.25 * damp)[..., None]
    return hf, alb


def _weeds_layer(img, seed, w_px, h_px):
    """crisp weed tufts and fallen leaves along the plinth, painted after render."""
    rng = np.random.default_rng(seed)
    a = np.array(img)
    for _ in range(int(w_px * 0.5)):
        x = int(rng.integers(0, w_px))
        hgt = int(rng.integers(2, 7))
        col = [(74, 92, 44), (92, 108, 52), (58, 72, 36)][int(rng.integers(0, 3))]
        for k in range(hgt):
            y = h_px - 1 - k
            xx = (x + (k // 3) * (1 if rng.random() < 0.5 else -1)) % w_px
            a[y, xx, :3] = col
            a[y, xx, 3] = 255
    for _ in range(int(w_px * 0.3)):
        x, y = int(rng.integers(0, w_px)), int(rng.integers(h_px - 6, h_px))
        c = LEAF_ORANGE[int(rng.integers(0, len(LEAF_ORANGE)))]
        a[y, x, :3] = c
        a[y, (x + 1) % w_px, :3] = np.array(c) * 0.8
    return Image.fromarray(a, 'RGBA')


def bake_band(style, part):
    hf, alb = band_field(style, part)
    w, h = 32, hf.shape[0] // HD
    oblique_scene(0, -h, w, h, samples=24, sun=1.8, amb=0.46)
    wall_mesh(hf, alb, w, h, name='band%d%s' % (style, part), bump=0.1)
    shear_all()
    raw = render_raw('band%d%s' % (style, part))
    t = downsample(raw, w * HD, h * HD)
    a = np.array(t).astype(float)
    al = np.maximum(a[..., 3:4] / 255.0, 1e-3)
    a[..., :3] = np.where(a[..., 3:4] > 0, a[..., :3] / al, 0)
    a[..., 3] = 255
    img = Image.fromarray(clamp8(a), 'RGBA')
    if part == 'plinth':
        img = _weeds_layer(img, 410 + style, w * HD, h * HD)
    return img


def build_bands(P):
    out = os.path.join(P, 'art', 'world_hd')
    sheet = Image.new('RGBA', (64, 7 * 18 * HD))
    for st in range(7):
        sheet.alpha_composite(bake_band(st, 'cornice'), (0, st * 18 * HD))
        sheet.alpha_composite(bake_band(st, 'plinth'), (0, (st * 18 + 8) * HD))
        print('band', st, flush=True)
    ref = os.path.join(ROOT, 'facade_bands_v1.png')
    sheet = match_palette(sheet.convert('RGB'), ref, 0.7).convert('RGBA')
    sheet.save(os.path.join(out, 'facade_bands_hd.png'))


# ------------------------------------------------------------- windows ---
# facade_windows_v1: 48 x 40 cells, columns = state (0 intact, 1 broken,
# 2 boarded, 3 lit), rows = style. Wall plane y = 0, cell spans x 0..48, z 0..40.
WIN_STYLE = {
    0: dict(w=22, h=18, frame=(214, 212, 204), mull='cross'),
    1: dict(w=22, h=18, frame=(226, 226, 220), mull='cross', blinds=True),
    2: dict(w=26, h=20, frame=(104, 76, 54), mull='cross'),
    3: dict(w=22, h=8, frame=(80, 82, 82), mull='vert3'),
    4: dict(w=34, h=14, frame=(84, 88, 90), mull='grid'),
    5: dict(w=18, h=14, frame=(80, 86, 70), mull='vert', bars=True),
    6: dict(w=20, h=18, frame=(230, 226, 214), mull='cross', shutters=(70, 104, 128), nalichnik=True),
}


def glass_image(w, h, state, style, seed):
    import random
    from PIL import ImageDraw
    rng = random.Random(seed)
    W, H = int(w * HD * 2), int(h * HD * 2)
    if state == 3:
        im = Image.new('RGB', (W, H), (206, 150, 70))
        d = ImageDraw.Draw(im)
        for k in range(3):
            x0 = rng.randint(0, W - 8)
            d.rectangle([x0, 0, x0 + rng.randint(4, 10), H], fill=(226, 176, 96))
        d.rectangle([0, 0, W, int(H * 0.18)], fill=(170, 112, 52))          # curtain rail shade
        return im
    im = Image.new('RGB', (W, H), (40, 52, 60))
    d = ImageDraw.Draw(im)
    d.polygon([(0, 0), (int(W * 0.55), 0), (0, int(H * 0.65))], fill=(84, 104, 114))     # sky reflection
    d.polygon([(int(W * 0.7), H), (W, H), (W, int(H * 0.6))], fill=(58, 74, 82))
    if style == 1:
        for y in range(2, H, 4):
            d.line([(0, y), (W, y)], fill=(176, 180, 176), width=2)
    if state == 1:
        cx, cy = rng.uniform(0.35, 0.65) * W, rng.uniform(0.35, 0.65) * H
        pts = []
        for i in range(11):
            a = i / 11 * math.tau
            r = rng.uniform(0.45, 1.0)
            pts.append((cx + math.cos(a) * W * 0.32 * r, cy + math.sin(a) * H * 0.34 * r))
        d.polygon(pts, fill=(16, 16, 16))
        for i in range(4):
            a = rng.uniform(0, math.tau)
            d.line([(cx, cy), (cx + math.cos(a) * W * 0.6, cy + math.sin(a) * H * 0.6)], fill=(150, 168, 176), width=2)
    return im


def build_window(style, state, cx=24.0, cz=21.0):
    st = WIN_STYLE[style]
    w, h = st['w'], st['h']
    x0, x1, z0, z1 = cx - w / 2, cx + w / 2, cz - h / 2, cz + h / 2
    fr = M(st['frame'], rough=0.55, grime=0.18)
    dark = M((22, 22, 22), rough=1, grime=0)
    # reveal: a shallow dark box the glass sits in
    bk.box((cx, -1.7, cz), (w / 2 - 0.2, 0.9, h / 2 - 0.4), dark, bevel=0)
    gimg = glass_image(w, h, state, style, style * 10 + state)
    g = image_material(gimg, rough=0.25 if state != 3 else 0.6, name='gl%d%d' % (style, state), repeat=False)
    if state == 3:
        b = g.node_tree.nodes['Principled BSDF']
        t = [n for n in g.node_tree.nodes if n.type == 'TEX_IMAGE'][0]
        g.node_tree.links.new(t.outputs['Color'], b.inputs['Emission Color'])
        b.inputs['Emission Strength'].default_value = 0.9
    bk.panel([(x0, -0.6, z0), (x1, -0.6, z0), (x1, -0.6, z1), (x0, -0.6, z1)], g)
    t = 1.1
    for (bx, bz, sx, sz) in ((cx, z1 + t / 2, w / 2 + t, t / 2), (cx, z0 - t / 2, w / 2 + t, t / 2),
                             (x0 - t / 2, cz, t / 2, h / 2), (x1 + t / 2, cz, t / 2, h / 2)):
        bk.box((bx, 0.2, bz), (sx, 0.8, sz), fr, bevel=0.2)
    mt = 0.45
    if st['mull'] == 'cross':
        bk.box((cx, -0.2, cz), (mt, 0.4, h / 2), fr, bevel=0)
        bk.box((cx, -0.2, z0 + h * 0.66), (w / 2, 0.4, mt), fr, bevel=0)
    elif st['mull'] in ('vert', 'vert3'):
        n = 2 if st['mull'] == 'vert' else 3
        for k in range(1, n):
            bk.box((x0 + w * k / n, -0.2, cz), (mt, 0.4, h / 2), fr, bevel=0)
    elif st['mull'] == 'grid':
        for k in range(1, 6):
            bk.box((x0 + w * k / 6, -0.2, cz), (mt * 0.8, 0.4, h / 2), fr, bevel=0)
        bk.box((cx, -0.2, cz), (w / 2, 0.4, mt * 0.8), fr, bevel=0)
    # sill
    if style not in (3, 4):
        bk.box((cx, 1.0, z0 - t - 0.5), (w / 2 + 2.2, 1.6, 0.5), M((196, 194, 184), rough=0.6, grime=0.2), bevel=0.2)
    if st.get('bars'):
        for k in range(1, 7):
            bk.cyl((x0 + w * k / 7, 1.4, z0 - 0.5), 0.35, h + 1, M((40, 40, 38), rough=0.5, metal=0.5), bevel=0)
    if st.get('shutters'):
        sc = M(st['shutters'], rough=0.7, grime=0.25)
        for side in (-1, 1):
            sx = cx + side * (w / 2 + 1.1 + w * 0.26)
            bk.box((sx, 0.6, cz), (w * 0.25, 0.5, h / 2 + 0.6), sc, bevel=0.2)
            for k in (-0.5, 0.0, 0.5):
                bk.box((sx, 1.15, cz + k * h * 0.6), (w * 0.22, 0.1, 0.3), M((50, 74, 92)), bevel=0)
    if st.get('nalichnik'):
        nc = M((232, 228, 216), rough=0.6, grime=0.2)
        bk.box((cx, 0.8, z1 + 2.2), (w / 2 + 2.4, 0.8, 1.1), nc, bevel=0.2)
        bk.prism([(cx - w / 2 - 2.6, z1 + 3.2), (cx + w / 2 + 2.6, z1 + 3.2), (cx, z1 + 7.6)], 0.0, 1.6, nc, bevel=0.3)
    if state == 2:
        planks = [(132, 104, 72), (120, 94, 64), (140, 112, 78)]
        for k, (zz, tilt) in enumerate(((z0 + h * 0.22, 0.03), (cz + h * 0.05, -0.04), (z1 - h * 0.18, 0.02))):
            bk.box((cx, 1.5, zz), (w / 2 + 2.0, 0.6, max(1.2, h * 0.11)), M(planks[k], rough=0.9, grime=0.3), bevel=0.15, rot=(0, tilt, 0))
            for nx in (x0 - 1.0, x1 + 1.0):
                bk.box((nx, 2.15, zz), (0.3, 0.1, 0.3), M((40, 40, 40)), bevel=0)


def bake_window(style, state):
    oblique_scene(0, -40, 48, 40, samples=32, sun=1.8, amb=0.46)
    build_window(style, state)
    shear_all()
    return post_sprite(render_raw('win%d%d' % (style, state)), 48 * HD, 40 * HD, colours=40)


def build_windows(P):
    out = os.path.join(P, 'art', 'world_hd')
    sheet = Image.new('RGBA', (4 * 48 * HD, 7 * 40 * HD))
    for st in range(7):
        for state in range(4):
            sheet.alpha_composite(bake_window(st, state), (state * 48 * HD, st * 40 * HD))
        print('windows', st, flush=True)
    sheet.save(os.path.join(out, 'facade_windows_hd.png'))


# ----------------------------------------------------- facade features ---
# facade_features_v1: 64 x 48 cells: 0 balcony, 1 shop window, 2 roller
# shutter, 3 rusty shutter half up, 4 strip window, 5 gate, 6 hazard band
# (only the bottom 10 rows are used), 7 flower box. Wall plane y = 0.
def _frame_rect(x0, x1, z0, z1, m, t=1.0, d=0.8):
    for (bx, bz, sx, sz) in (((x0 + x1) / 2, z1 + t / 2, (x1 - x0) / 2 + t, t / 2), ((x0 + x1) / 2, z0 - t / 2, (x1 - x0) / 2 + t, t / 2),
                             (x0 - t / 2, (z0 + z1) / 2, t / 2, (z1 - z0) / 2), (x1 + t / 2, (z0 + z1) / 2, t / 2, (z1 - z0) / 2)):
        bk.box((bx, d / 2, bz), (sx, d / 2, sz), m, bevel=0.15)


def _glass_panel(x0, x1, z0, z1, img, y=-0.6, name='g', emit=0.0):
    g = image_material(img, rough=0.25, name=name, repeat=False)
    if emit > 0:
        b = g.node_tree.nodes['Principled BSDF']
        t = [n for n in g.node_tree.nodes if n.type == 'TEX_IMAGE'][0]
        g.node_tree.links.new(t.outputs['Color'], b.inputs['Emission Color'])
        b.inputs['Emission Strength'].default_value = emit
    bk.panel([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], g)


def ft_balcony():
    slab = M((150, 148, 138), rough=0.85, grime=0.25)
    bk.box((32, 4.5, 6), (24, 4.5, 1.2), slab, bevel=0.3)
    rail = M((112, 118, 116), rough=0.5, metal=0.4, grime=0.2)
    bk.box((32, 8.6, 13), (23.5, 0.4, 6), M((120, 132, 128), rough=0.6, grime=0.25), bevel=0.2)   # parapet panel
    for k in range(-22, 23, 4):
        bk.box((32 + k, 8.9, 13), (0.3, 0.2, 5.6), M((96, 108, 104)), bevel=0)
    bk.box((32, 8.6, 19.4), (24, 0.6, 0.5), rail, bevel=0.1)
    for side in (-1, 1):
        bk.box((32 + side * 23.5, 4.5, 13), (0.5, 4.2, 6.6), rail, bevel=0.1)
    _glass_panel(18, 46, 7, 30, glass_image(28, 23, 0, 0, 7), y=-0.6, name='bal')
    _frame_rect(18, 46, 7, 30, M((214, 212, 204), rough=0.55, grime=0.2))
    bk.box((32, -0.2, 18.5), (0.4, 0.4, 11.5), M((214, 212, 204)), bevel=0)


def ft_shopwindow():
    _glass_panel(8, 56, 6, 34, glass_image(48, 28, 0, 2, 21), name='shop')
    _frame_rect(8, 56, 6, 34, M((70, 52, 40), rough=0.6, grime=0.2), t=1.4)
    bk.box((32, -0.2, 20), (0.5, 0.4, 14), M((70, 52, 40)), bevel=0)
    bk.box((32, 1.6, 4.6), (26, 1.8, 0.6), M((176, 172, 160)), bevel=0.2)
    # torn shutter box over the top
    bk.box((32, 2.0, 37.5), (25, 2.0, 2.2), M((110, 114, 112), rough=0.5, metal=0.4, grime=0.3), bevel=0.4)
    for k in range(3):
        bk.box((14 + k * 6, 1.2, 33 - k * 1.2), (2.6, 0.2, 2.0 + k * 0.5), M((120, 124, 122), metal=0.4), bevel=0, rot=(0.0, 0.2 * (k - 1), 0))


def _shutter(x0, x1, z0, z1, col, rustiness=0.25, up=0.0):
    sl = M(col, rough=0.6, metal=0.3, grime=0.3, scale=0.2)
    zc = z0 + up
    if up > 0:
        bk.box(((x0 + x1) / 2, -1.6, (z0 + zc) / 2), ((x1 - x0) / 2, 0.6, max(0.2, (zc - z0) / 2)), M((18, 18, 18), rough=1), bevel=0)
    for z in np.arange(zc, z1, 1.6):
        bk.box(((x0 + x1) / 2, 0.3, z + 0.8), ((x1 - x0) / 2, 0.35, 0.7), sl, bevel=0.15)
    bk.box(((x0 + x1) / 2, 1.4, z1 + 1.6), ((x1 - x0) / 2 + 1.2, 1.4, 1.6), M((96, 100, 100), metal=0.4, grime=0.3), bevel=0.3)
    for x in (x0 - 0.8, x1 + 0.8):
        bk.box((x, 0.6, (z0 + z1) / 2), (0.8, 0.6, (z1 - z0) / 2 + 1), M((80, 84, 84), metal=0.4), bevel=0.1)


def ft_shutter():
    _shutter(10, 54, 4, 34, (128, 132, 130))
    bk.box((32, 0.9, 6), (2.4, 0.3, 0.6), M((60, 60, 58)), bevel=0)


def ft_shutter_rust():
    _shutter(10, 54, 4, 34, (132, 72, 50), up=13.0)


def ft_strip():
    _glass_panel(4, 60, 14, 28, glass_image(56, 14, 0, 4, 41), name='strip')
    _frame_rect(4, 60, 14, 28, M((84, 88, 90), rough=0.5, metal=0.3), t=1.0)
    for k in range(1, 8):
        bk.box((4 + 56 * k / 8, -0.2, 21), (0.4, 0.4, 7), M((84, 88, 90)), bevel=0)
    bk.box((32, 0.4, 21), (28, 0.4, 0.4), M((84, 88, 90)), bevel=0)


def ft_gate():
    g = M((110, 116, 118), rough=0.55, metal=0.4, grime=0.3, scale=0.2)
    bk.box((32, 0.6, 18), (26, 0.6, 16), g, bevel=0.3)
    for k in range(-24, 25, 4):
        bk.box((32 + k, 1.3, 18), (0.5, 0.2, 15.5), M((92, 98, 100), metal=0.4), bevel=0)
    bk.box((32, 1.3, 18), (0.4, 0.4, 16), M((50, 52, 52)), bevel=0)
    stripe = _stripe_image(52 * HD * 2, 3 * HD * 2)
    _glass_panel(6, 58, 33, 36, stripe, y=1.4, name='gstripe')
    bk.box((32, 0.8, 3), (24, 0.3, 2), M((124, 70, 40), rough=0.9), bevel=0)


def _stripe_image(W, H, period=16):
    from PIL import ImageDraw
    im = Image.new('RGB', (W, H), (40, 40, 36))
    d = ImageDraw.Draw(im)
    for x in range(-H, W + H, period):
        d.polygon([(x, H), (x + period // 2, H), (x + period // 2 + H, 0), (x + H, 0)], fill=(210, 168, 48))
    return im


def ft_hazard():
    _glass_panel(0, 64, 0.5, 9.5, _stripe_image(256, 36), y=0.8, name='hz')
    bk.box((32, 0.3, 5), (32, 0.3, 4.6), M((40, 40, 36)), bevel=0)


def ft_flowerbox():
    bk.box((32, 2.4, 6), (13, 2.4, 2.6), M((120, 84, 56), rough=0.9, grime=0.3), bevel=0.3)
    import random
    rng = random.Random(77)
    for i in range(14):
        x = 21 + i * 1.6 + rng.uniform(-0.5, 0.5)
        h = rng.uniform(3, 8)
        bk.tube([(x, 2.4, 8.6), (x + rng.uniform(-1.5, 1.5), 2.6, 8.6 + h)], 0.25, M(rng.choice([(110, 92, 48), (92, 74, 40), (130, 98, 52)])))
    for i in range(4):
        bk.sphere((22 + i * 6, 3.0, 10 + rng.uniform(0, 3)), 1.2, M(LEAF_ORANGE[i % len(LEAF_ORANGE)], rough=0.9))


FEATURES = [ft_balcony, ft_shopwindow, ft_shutter, ft_shutter_rust, ft_strip, ft_gate, ft_hazard, ft_flowerbox]


def build_features(P):
    out = os.path.join(P, 'art', 'world_hd')
    sheet = Image.new('RGBA', (8 * 64 * HD, 48 * HD))
    for i, fn in enumerate(FEATURES):
        oblique_scene(0, -48, 64, 48, samples=32, sun=1.8, amb=0.46)
        fn()
        shear_all()
        sheet.alpha_composite(post_sprite(render_raw('ft%d' % i), 64 * HD, 48 * HD, colours=48), (i * 64 * HD, 0))
        print('feature', i, flush=True)
    sheet.save(os.path.join(out, 'facade_features_hd.png'))


# ------------------------------------------------------------ entrances ---
# entrance_v2: 64 x 80 per style. Doorway 20 x 32 centred at x = 32; its
# sill sits 6 u above the cell bottom for styles with steps (0, 1, 6), 1 u
# for the others (the game offsets the sprite so the sill meets the ground).
def build_entrance(style):
    steps = style in (0, 1, 6)
    g0 = 6.0 if steps else 1.0                 # doorway sill height above the cell bottom
    cx = 32.0
    dark = M((20, 18, 16), rough=1)
    bk.box((cx, -1.5, g0 + 16), (10, 1.5, 16), dark, bevel=0)                 # doorway
    frame_c = [(96, 98, 94), (210, 210, 202), (90, 70, 52), (60, 62, 60), (70, 72, 70), (78, 86, 62), (226, 220, 206)][style]
    _frame_rect(cx - 10, cx + 10, g0, g0 + 32, M(frame_c, rough=0.6, grime=0.25), t=1.6, d=1.2)
    if steps:
        st_m = M((150, 146, 136), rough=0.9, grime=0.3) if style != 6 else M((120, 92, 64), rough=0.9, grime=0.3)
        for k in range(3):
            bk.box((cx, 2.0 + k * 2.0, g0 - 1.0 - k * 2.0), (13 + k * 2.5, 2.0 + k * 1.0, 1.0), st_m, bevel=0.2)
    lamp = M((240, 214, 150), rough=0.3, emit=(255, 214, 140))
    if style in (0, 1, 3, 4, 5):
        # concrete / steel canopy slab
        cm = M((140, 138, 128) if style in (0, 1) else (100, 104, 104), rough=0.8, metal=0.3 if style in (3, 4) else 0.0, grime=0.3)
        bk.box((cx, 2.6, g0 + 40.0), (15, 2.6, 1.0), cm, bevel=0.25)
        bk.box((cx, 5.0, g0 + 39.4), (15, 0.25, 0.9), M((70, 72, 70), metal=0.3), bevel=0)     # drip edge
        for side in (-1, 1):
            bk.tube([(cx + side * 13, 0.2, g0 + 46), (cx + side * 13, 4.8, g0 + 41)], 0.25, M((60, 60, 58)))
        bk.box((cx + 13.5, 0.6, g0 + 30), (1.2, 0.8, 1.6), M((50, 50, 48)), bevel=0.1)
        bk.box((cx + 13.5, 1.2, g0 + 29.2), (0.9, 0.5, 0.8), lamp, bevel=0.1)
    if style == 0:
        bk.box((cx - 13.5, 0.4, g0 + 18), (1.4, 0.4, 2.2), M((70, 74, 76), metal=0.3), bevel=0.1)      # intercom
    if style == 1:
        bk.box((cx, 1.0, g0 + 44), (6, 0.6, 4.4), M((232, 232, 226), rough=0.5), bevel=0.2)
        bk.box((cx, 1.7, g0 + 44), (3.6, 0.2, 1.0), M((184, 44, 40)), bevel=0)
        bk.box((cx, 1.7, g0 + 44), (1.0, 0.2, 3.6), M((184, 44, 40)), bevel=0)
    if style == 2:
        # striped awning
        stripe = Image.new('RGB', (160, 40), (200, 196, 184))
        from PIL import ImageDraw
        d = ImageDraw.Draw(stripe)
        for x in range(0, 160, 20):
            d.rectangle([x, 0, x + 9, 40], fill=(168, 52, 44))
        g = image_material(stripe, rough=0.8, name='awning', repeat=False)
        bk.panel([(cx - 17, 6, g0 + 37), (cx + 17, 6, g0 + 37), (cx + 17, 0, g0 + 43), (cx - 17, 0, g0 + 43)], g)
        bk.panel([(cx - 17, 6, g0 + 34.5), (cx + 17, 6, g0 + 34.5), (cx + 17, 6, g0 + 37), (cx - 17, 6, g0 + 37)], g)
    if style in (3, 4):
        hz = image_material(_stripe_image(48, 160, 10), rough=0.7, name='hzv', repeat=False)
        for side in (-1, 1):
            x = cx + side * 12.2
            bk.panel([(x - 0.8, 1.3, g0), (x + 0.8, 1.3, g0), (x + 0.8, 1.3, g0 + 33), (x - 0.8, 1.3, g0 + 33)], hz)
    if style == 5:
        sb = M((150, 134, 96), rough=1, grime=0.3)
        for side in (-1, 1):
            for k in range(3):
                bk.box((cx + side * (15 + (k % 2) * 1.5), 3.0, g0 + 1.6 + k * 3.0), (3.8, 3.0, 1.5), sb, bevel=1.2)
        bk.box((cx, 1.4, g0 + 43), (2.2, 1.0, 1.6), M((200, 40, 36), rough=0.3, emit=(255, 60, 40)), bevel=0.3)
    if style == 6:
        # wooden porch with a little gable roof on posts
        wood = M((128, 96, 64), rough=0.9, grime=0.3)
        for side in (-1, 1):
            bk.box((cx + side * 14, 9, g0 + 18), (0.9, 0.9, 18), wood, bevel=0.2)
        roof = M((132, 60, 46), rough=0.7, grime=0.3)
        bk.mesh([(cx - 17, 11, g0 + 36), (cx + 17, 11, g0 + 36), (cx + 17, 0, g0 + 36), (cx - 17, 0, g0 + 36),
                 (cx, 11, g0 + 44), (cx, 0, g0 + 44)],
                [(0, 1, 5, 4), (3, 0, 4, 5), (1, 2, 5), (0, 3, 4)], roof)
        bk.mesh([(cx - 17, 11, g0 + 36), (cx + 17, 11, g0 + 36), (cx, 11, g0 + 44)], [(0, 1, 2)], M((214, 206, 188), rough=0.8))
        bk.box((cx + 12, 1.0, g0 + 29), (0.8, 0.6, 1.0), lamp, bevel=0.1)


def build_entrances(P):
    out = os.path.join(P, 'art', 'world_hd')
    sheet = Image.new('RGBA', (7 * 64 * HD, 80 * HD))
    for st in range(7):
        oblique_scene(0, -80, 64, 80, samples=32, sun=1.8, amb=0.46)
        build_entrance(st)
        shear_all()
        sheet.alpha_composite(post_sprite(render_raw('ent%d' % st), 64 * HD, 80 * HD, colours=48), (st * 64 * HD, 0))
        print('entrance', st, flush=True)
    sheet.save(os.path.join(out, 'entrance_hd.png'))


# ---------------------------------------------------------- door leaves ---
LEAF_COLS = [(64, 96, 76), None, (110, 78, 50), (124, 128, 126), (112, 118, 124), (70, 86, 60), (118, 86, 56)]


def leaf_field(style):
    w, h = 24, 32
    lw = 20 if style in (4, 5) else 18
    U, V = _wgrid(w, h)
    n = _wnoise(w, h, 500 + style, 4, 3)
    if style == 1:            # clinic: glazed aluminium door
        alb = np.zeros(U.shape + (3,)) + np.array((52, 66, 74), float)
        alb[(U < 2) | (U > lw - 2) | (V < 2) | (V > 30) | ((V > 15) & (V < 17))] = (214, 214, 206)
        hf = np.where((U < 2) | (U > lw - 2) | (V < 2) | (V > 30), 0.4, 0.0)
        refl = (U + V * 0.6) % 14 < 3
        alb[refl & (alb[..., 0] < 100)] = (90, 110, 120)
    elif style == 6:          # planked wooden door
        alb = np.array(LEAF_COLS[6], float) * (0.85 + 0.25 * n)[..., None]
        gap = (U % 4) < 0.5
        alb[gap] *= 0.55
        hf = np.where(gap, -0.3, 0.0)
        brace = (np.abs(V - 8) < 1.2) | (np.abs(V - 24) < 1.2)
        alb[brace] = (102, 74, 48)
        hf += brace * 0.4
    else:                     # painted steel door with two recessed panels
        alb = np.array(LEAF_COLS[style], float) * (0.88 + 0.2 * n)[..., None]
        panel = ((U > 3) & (U < lw - 3)) & (((V > 4) & (V < 14)) | ((V > 17) & (V < 28)))
        hf = np.where(panel, -0.35, 0.0)
        alb[panel] *= 0.9
        alb = _wblob(alb, 510 + style, w, h, 4, 0.7, (118, 70, 44))
    handle = (np.abs(U - (lw - 4.0)) < 1.4) & (np.abs(V - 17) < 0.6)
    alb[handle] = (200, 192, 160)
    hf += handle * 0.6
    return hf, alb


def build_leaves(P):
    out = os.path.join(P, 'art', 'world_hd')
    sheet = Image.new('RGBA', (7 * 24 * HD, 32 * HD))
    for st in range(7):
        hf, alb = leaf_field(st)
        oblique_scene(0, -32, 24, 32, samples=24, sun=1.8, amb=0.46)
        wall_mesh(hf, alb, 24, 32, copies=0, name='leaf%d' % st, bump=0.1)
        shear_all()
        raw = render_raw('leaf%d' % st)
        t = downsample(raw, 24 * HD, 32 * HD)
        a = np.array(t).astype(float)
        al = np.maximum(a[..., 3:4] / 255.0, 1e-3)
        a[..., :3] = np.where(a[..., 3:4] > 0, a[..., :3] / al, 0)
        a[..., 3] = 255
        # the leaf is only as wide as the doorway (18 u, 20 u for styles 4/5);
        # the rest of the 24 u cell stays transparent like the 1x atlas
        lw = 20 if st in (4, 5) else 18
        a[:, lw * HD:, 3] = 0
        sheet.alpha_composite(Image.fromarray(clamp8(a), 'RGBA'), (st * 24 * HD, 0))
        print('leaf', st, flush=True)
    sheet = match_palette(sheet.convert('RGB'), os.path.join(ROOT, 'door_leaf_v1.png'), 0.6).convert('RGBA')
    sheet.save(os.path.join(out, 'door_leaf_hd.png'))


# --------------------------------------------------------------- extras ---
# facade_extras_v1 (192 x 120): fire escape strip x 0..48 (cropped from the
# bottom by facade height), chimney 48..112 x 0..64, vent stack 112..176.
def ex_fire_escape():
    st = M((70, 72, 70), rough=0.5, metal=0.5, grime=0.3, scale=0.2)
    rust_m = M((118, 70, 42), rough=0.85)
    for side in (-1, 1):
        bk.box((24 + side * 5, 3.0, 60), (0.5, 0.5, 60), st, bevel=0)
    for z in np.arange(2, 120, 3.0):
        bk.box((24, 3.0, z), (5, 0.3, 0.3), st if int(z) % 9 else rust_m, bevel=0)
    for z in (18, 46, 74, 102):
        bk.box((24, 4.0, z), (10, 4.0, 0.5), st, bevel=0.1)              # landings
        bk.box((24, 7.6, z + 4), (10, 0.3, 0.3), st, bevel=0)              # handrail
        for xx in (15, 33):
            bk.box((xx, 7.6, z + 2), (0.3, 0.3, 2), st, bevel=0)
        bk.box((14.5, 2.0, z - 2), (0.4, 2.0, 0.4), st, bevel=0)
        bk.box((33.5, 2.0, z - 2), (0.4, 2.0, 0.4), st, bevel=0)


def ex_chimney():
    brick = M((132, 72, 54), rough=0.9, grime=0.35, scale=0.2)
    bk.box((32, -8, 12), (7, 7, 12), brick, bevel=0.3)
    for z in range(2, 24, 3):
        bk.box((32, -0.9, z), (7.05, 0.1, 0.25), M((150, 140, 124)), bevel=0)
    bk.box((32, -8, 25), (8.2, 8.2, 1.2), M((80, 80, 76), metal=0.3), bevel=0.3)
    bk.box((32, -8, 26.4), (4, 4, 0.4), M((24, 22, 20), rough=1), bevel=0)


def ex_vent_stack():
    p = M((120, 124, 122), rough=0.55, metal=0.4, grime=0.35, scale=0.15)
    bk.cyl((32, -6, 0), 5, 104, p, bevel=0.4)
    for z in (20, 48, 76, 100):
        bk.cyl((32, -6, z), 5.4, 1.2, M((84, 86, 84), metal=0.4), bevel=0.2)
    bk.cyl((32, -6, 104), 6.2, 2, M((70, 72, 70), metal=0.4), bevel=0.3)
    bk.box((32, -6, 2), (8, 8, 2), M((140, 138, 128), rough=0.9), bevel=0.3)
    for (dx, dy) in ((-18, 8), (18, 8)):
        bk.tube([(32, -6, 80), (32 + dx, -6 + dy, 0)], 0.25, M((40, 40, 38)))
    bk.box((32, -0.6, 70), (2.2, 0.3, 1.2), M((190, 50, 40)), bevel=0)


def build_extras(P):
    out = os.path.join(P, 'art', 'world_hd')
    sheet = Image.new('RGBA', (192 * HD, 120 * HD))
    for (fn, x0, w, h, name) in ((ex_fire_escape, 0, 48, 120, 'fe'), (ex_chimney, 48, 64, 64, 'ch'), (ex_vent_stack, 112, 64, 120, 'vs')):
        oblique_scene(0, -h, w, h, samples=32, sun=1.8, amb=0.46)
        fn()
        shear_all()
        sheet.alpha_composite(post_sprite(render_raw('ex' + name), w * HD, h * HD, colours=40), (x0 * HD, 0))
        print('extra', name, flush=True)
    sheet.save(os.path.join(out, 'facade_extras_hd.png'))


# -------------------------------------------------------------- details ---
# facade_details_v1: 48 x 80 per kind: drainpipe, ivy, grime, ac_unit,
# wires, graffiti_a, graffiti_b, wall_lamp (sprites are cropped from the
# bottom by the visible height, so content is bottom-anchored).
def dt_drainpipe():
    p = M((112, 116, 114), rough=0.5, metal=0.4, grime=0.3, scale=0.15)
    bk.cyl((10, 1.6, -2), 1.3, 80, p, bevel=0.2, verts=16)
    for z in range(8, 80, 16):
        bk.box((10, 0.8, z), (2.0, 0.8, 0.5), M((70, 72, 70)), bevel=0.1)
        bk.box((10, 1.6, z + 6), (1.45, 0.2, 0.6), M((118, 70, 42), rough=0.9), bevel=0)
    bk.cyl((10, 1.6, 79), 2.4, 1.4, p, bevel=0.3)
    bk.tube([(10, 1.6, 0.5), (13, 6, 0.5)], 1.2, p)


def dt_ac():
    _split_ac(24, 52)


def dt_wires():
    bk.box((26, 1.2, 62), (3, 1.2, 3), M((90, 92, 90), metal=0.3, grime=0.3), bevel=0.3)
    for k in range(4):
        bk.tube([(2, 0.6, 70 - k), (14, 0.8, 66 - k * 0.6), (24, 1.2, 63 - k * 0.3)], 0.25, M((26, 26, 26)))
        bk.tube([(28, 1.2, 63 - k * 0.3), (38, 0.8, 66 - k * 0.6), (48, 0.6, 69 - k)], 0.25, M((26, 26, 26)))
    bk.tube([(26, 1.0, 59), (26, 0.6, 10)], 0.3, M((30, 30, 30)))


def dt_lamp():
    bk.box((40, 0.6, 52), (1.6, 0.6, 1.4), M((50, 50, 48), metal=0.4), bevel=0.2)
    bk.box((40, 2.0, 50.6), (2.0, 1.4, 1.2), M((44, 44, 42), metal=0.4), bevel=0.3)
    bk.box((40, 2.0, 49.2), (1.5, 1.0, 0.4), M((250, 220, 150), rough=0.3, emit=(255, 220, 150)), bevel=0.1)


def _paint_layer(kind, W, H, seed):
    from PIL import ImageDraw
    import random
    rng = random.Random(seed)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if kind == 'grime':
        a = np.zeros((H, W, 4), np.uint8)
        n = fbm(W, H, 10, seed, 3, wrap=False)
        for y in range(H):
            t = y / H
            for x in range(W):
                k = (1 - abs(x - W / 2) / (W / 2)) * (1 - t * 0.6) * n[y, x]
                if k > 0.32:
                    a[y, x] = (30, 28, 24, int(min(110, (k - 0.32) * 300)))
        return Image.fromarray(a, 'RGBA')
    if kind == 'ivy':
        stems = [(W // 2 + rng.randint(-10, 10), H)]
        cols = [(150, 84, 34), (176, 108, 40), (122, 70, 30), (196, 130, 48), (92, 104, 46), (70, 86, 40)]
        for i in range(6):
            x, y = stems[0][0] + rng.randint(-16, 16), H
            for k in range(rng.randint(60, 120)):
                y -= 1
                x += rng.choice((-1, 0, 0, 1))
                if y < 10 or x < 2 or x > W - 3:
                    break
                d.point((x, y), fill=(70, 50, 34, 255))
                if rng.random() < 0.35:
                    c = rng.choice(cols)
                    d.ellipse([x - 2, y - 2, x + 2, y + 1], fill=c + (255,))
                    d.point((x - 1, y - 1), fill=tuple(min(255, int(v * 1.2)) for v in c) + (255,))
        return im
    if kind in ('graffiti_a', 'graffiti_b'):
        y0 = 88 + 6
        col = (184, 52, 44) if kind == 'graffiti_a' else (60, 110, 170)
        pts = []
        x = 10
        while x < W - 10:
            pts.append((x, y0 + rng.randint(-14, 14)))
            x += rng.randint(8, 14)
        d.line(pts, fill=col + (235,), width=3)
        d.line([(p[0], p[1] + 3) for p in pts], fill=(220, 200, 150, 160), width=1)
        if kind == 'graffiti_b':
            d.ellipse([W // 2 - 12, y0 - 14, W // 2 + 12, y0 + 10], outline=col + (235,), width=3)
        return im
    return im


DETAILS = [('drainpipe', dt_drainpipe), ('ivy', None), ('grime', None), ('ac_unit', dt_ac), ('wires', dt_wires),
           ('graffiti_a', None), ('graffiti_b', None), ('wall_lamp', dt_lamp)]


def build_details(P):
    out = os.path.join(P, 'art', 'world_hd')
    sheet = Image.new('RGBA', (8 * 48 * HD, 80 * HD))
    for i, (kind, fn) in enumerate(DETAILS):
        if fn is None:
            spr = _paint_layer(kind, 48 * HD, 80 * HD, 600 + i)
        else:
            oblique_scene(0, -80, 48, 80, samples=32, sun=1.8, amb=0.46)
            fn()
            shear_all()
            spr = post_sprite(render_raw('dt%d' % i), 48 * HD, 80 * HD, colours=40)
        sheet.alpha_composite(spr, (i * 48 * HD, 0))
        print('detail', kind, flush=True)
    sheet.save(os.path.join(out, 'facade_details_hd.png'))


if __name__ == '__main__':
    P = sys.argv[1] if len(sys.argv) > 1 else '.'
    parts = sys.argv[2:] or ['roofs']
    if 'roofs' in parts:
        build_roofs(P)
    if 'edges' in parts:
        build_roof_edges(P)
    if 'roofobj' in parts:
        build_roof_objects(P)
    if 'walls' in parts:
        build_walls(P)
    if 'bands' in parts:
        build_bands(P)
    if 'windows' in parts:
        build_windows(P)
    if 'features' in parts:
        build_features(P)
    if 'entrances' in parts:
        build_entrances(P)
    if 'leaves' in parts:
        build_leaves(P)
    if 'extras' in parts:
        build_extras(P)
    if 'details' in parts:
        build_details(P)
