"""OSTATOK Blender kit: model props in real 3D, bake them to game pixel art.

Run with the `bpy` module (pip install bpy==4.2.0) — no Blender UI needed.

Coordinates follow the 2D art pipeline (wa_core): X right, Y toward the camera
(south), Z up, 1 unit = 1 world pixel. The game projects a point to
screen (x, y*0.55 - z); an orthographic camera tilted to atan(0.55) above the
horizon gives the same picture up to a vertical stretch of 1/cos(a), applied in
post. Light matches wa_core.LIGHT (upper left, slightly toward the camera).

Output is "HD" density: 2 texels per world unit (survivor sprites use the same
density, drawn at scale 0.5), rendered at 2x that and box-filtered down, then
alpha is hardened, colours are snapped to a small palette and the 1 px dark
outline every sprite in the game has is added.
"""
import math
import os
import random

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix
from PIL import Image

ALPHA = math.atan(0.55)
STRETCH = 1.0 / math.cos(ALPHA)
LIGHT = np.array([-0.45, 0.30, 0.84])
OUTLINE = (18, 16, 14)
HD = 2            # final texels per world unit
SS = 2            # supersampling on top of HD


def srgb2lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def G(x, y, z):
    """game coords -> blender coords (blender Y points away from the camera)."""
    return Vector((x, -y, z))


# ------------------------------------------------------------------ scene ---
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 48
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 4
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    world = bpy.data.worlds.new('w')
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs[0].default_value = (0.42, 0.45, 0.50, 1)
    bg.inputs[1].default_value = 0.32
    # sun
    d = Vector((LIGHT[0], -LIGHT[1], LIGHT[2])).normalized()
    sun = bpy.data.lights.new('sun', 'SUN')
    sun.energy = 4.2
    sun.angle = math.radians(6)
    sun.color = (1.0, 0.96, 0.9)
    o = bpy.data.objects.new('sun', sun)
    sc.collection.objects.link(o)
    o.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    # ground shadow catcher
    bpy.ops.mesh.primitive_plane_add(size=2000, location=(0, 0, 0))
    g = bpy.context.active_object
    g.name = 'ground'
    g.is_shadow_catcher = True
    _MAT.clear()
    return sc


def camera(cell=192, oy=166, ox=96):
    """ortho camera so that world (0,0,0) lands on pixel (ox, oy) of a cell-sized
    sprite (same convention as wa_core.Scene)."""
    sc = bpy.context.scene
    cam = bpy.data.cameras.new('cam')
    cam.type = 'ORTHO'
    cam.ortho_scale = cell
    cam.clip_start = 1
    cam.clip_end = 5000
    o = bpy.data.objects.new('cam', cam)
    sc.collection.objects.link(o)
    sc.camera = o
    # point the camera at the world point that projects to the cell centre
    # screen offset of the centre from origin, in world units (pre-stretch)
    dx = cell / 2 - ox
    dy_screen = cell / 2 - oy           # down positive in the final sprite
    # a point on the ground plane at game y = dy_screen/0.55 projects there
    tgt = G(dx, dy_screen / 0.55, 0)
    fwd = Vector((0, math.cos(ALPHA), -math.sin(ALPHA)))
    o.location = tgt - fwd * 1500
    o.rotation_euler = fwd.to_track_quat('-Z', 'Y').to_euler()
    px = cell * HD * SS
    sc.render.resolution_x = px
    sc.render.resolution_y = int(round(px / STRETCH))
    sc.render.resolution_percentage = 100
    cam.shift_y = 0
    return o


# -------------------------------------------------------------- materials ---
_MAT = {}


def mat(col, rough=0.62, metal=0.0, grime=0.12, dust=0.0, emit=None, name=None, scale=0.08):
    """paint material: base colour with low-frequency mottling, optional dust
    rising from the ground (by world Z), optional emission."""
    key = name or (tuple(col), rough, metal, grime, dust, emit, scale)
    if key in _MAT:
        return _MAT[key]
    m = bpy.data.materials.new(str(key)[:60])
    m.use_nodes = True
    nt = m.node_tree
    N = nt.nodes
    L = nt.links
    bsdf = N['Principled BSDF']
    lin = tuple(srgb2lin(c) for c in col) + (1,)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    tc = N.new('ShaderNodeTexCoord')
    noise = N.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = scale
    noise.inputs['Detail'].default_value = 4
    L.new(tc.outputs['Object'], noise.inputs['Vector'])
    ramp = N.new('ShaderNodeMapRange')
    ramp.inputs['From Min'].default_value = 0.3
    ramp.inputs['From Max'].default_value = 0.7
    ramp.inputs['To Min'].default_value = 1 - grime
    ramp.inputs['To Max'].default_value = 1 + grime * 0.4
    L.new(noise.outputs['Fac'], ramp.inputs['Value'])
    mul = N.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    mul.inputs['A'].default_value = lin
    L.new(ramp.outputs['Result'], mul.inputs['B'])
    out = mul.outputs['Result']
    if dust > 0:
        geo = N.new('ShaderNodeNewGeometry')
        sep = N.new('ShaderNodeSeparateXYZ')
        L.new(geo.outputs['Position'], sep.inputs['Vector'])
        mr = N.new('ShaderNodeMapRange')
        mr.inputs['From Min'].default_value = 16
        mr.inputs['From Max'].default_value = 0
        mr.inputs['To Min'].default_value = 0
        mr.inputs['To Max'].default_value = dust
        L.new(sep.outputs['Z'], mr.inputs['Value'])
        mix = N.new('ShaderNodeMix')
        mix.data_type = 'RGBA'
        L.new(mr.outputs['Result'], mix.inputs['Factor'])
        L.new(out, mix.inputs['A'])
        mix.inputs['B'].default_value = tuple(srgb2lin(c) for c in (112, 98, 76)) + (1,)
        out = mix.outputs['Result']
    L.new(out, bsdf.inputs['Base Color'])
    if emit:
        bsdf.inputs['Emission Color'].default_value = tuple(srgb2lin(c) for c in emit) + (1,)
        bsdf.inputs['Emission Strength'].default_value = 2.0
    _MAT[key] = m
    return m


def glass(tint=(24, 32, 38)):
    key = ('glass', tint)
    if key in _MAT:
        return _MAT[key]
    m = bpy.data.materials.new('glass')
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = tuple(srgb2lin(c) for c in tint) + (1,)
    b.inputs['Roughness'].default_value = 0.22
    b.inputs['Metallic'].default_value = 0.0
    b.inputs['Specular IOR Level'].default_value = 0.22
    _MAT[key] = m
    return m


# ---------------------------------------------------------------- objects ---
def _finish(o, m, bevel=0.0, seg=2, smooth=False):
    if m is not None:
        o.data.materials.append(m)
    if bevel > 0:
        b = o.modifiers.new('bv', 'BEVEL')
        b.width = bevel
        b.segments = seg
        b.limit_method = 'ANGLE'
        b.angle_limit = math.radians(30)
        b.harden_normals = False
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    return o


def box(c, size, m, bevel=0.6, rot=(0, 0, 0), seg=2):
    """c = centre (game coords), size = half extents (x, y, z)."""
    bpy.ops.mesh.primitive_cube_add(size=2, location=G(*c))
    o = bpy.context.active_object
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = (rot[0], -rot[1], rot[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, m, min(bevel, min(size) * 0.9), seg)


def cyl(c, r, h, m, axis='z', bevel=0.4, verts=32, rot=None):
    """cylinder: base centre c for axis z; for axis x/y, c is the centre."""
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts, location=G(*c))
    o = bpy.context.active_object
    if axis == 'z':
        o.location.z += h / 2
    elif axis == 'x':
        o.rotation_euler = (0, math.pi / 2, 0)
    elif axis == 'y':
        o.rotation_euler = (math.pi / 2, 0, 0)
    if rot:
        o.rotation_euler = rot
    return _finish(o, m, min(bevel, r * 0.4), 2, smooth=True)


def sphere(c, r, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=G(*c), segments=24, ring_count=12)
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, m, smooth=True)


def prism(profile, y0, y1, m, bevel=0.8, seg=3, plane='xz'):
    """extrude a 2D profile. plane 'xz': profile is [(x,z)...] extruded along
    game y from y0 to y1 (side silhouette). plane 'xy': [(x,y)...] footprint
    extruded along z from y0 to y1."""
    bm = bmesh.new()
    vs0, vs1 = [], []
    for (a, b) in profile:
        if plane == 'xz':
            vs0.append(bm.verts.new(G(a, y0, b)))
            vs1.append(bm.verts.new(G(a, y1, b)))
        else:
            vs0.append(bm.verts.new(G(a, b, y0)))
            vs1.append(bm.verts.new(G(a, b, y1)))
    n = len(profile)
    bm.faces.new(vs0)
    bm.faces.new(list(reversed(vs1)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([vs0[i], vs0[j], vs1[j], vs1[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('p')
    bm.to_mesh(me)
    o = bpy.data.objects.new('p', me)
    bpy.context.scene.collection.objects.link(o)
    return _finish(o, m, bevel, seg)


def mesh(verts, faces, m, bevel=0.0, smooth=False):
    me = bpy.data.meshes.new('m')
    me.from_pydata([G(*v) for v in verts], [], faces)
    me.update()
    o = bpy.data.objects.new('m', me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    return _finish(o, m, bevel, 2, smooth)


def tube(points, r, m, verts=10):
    """pipe / cable / rotor blade through game-space points."""
    cu = bpy.data.curves.new('t', 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = r
    cu.bevel_resolution = 2
    sp = cu.splines.new('POLY')
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        v = G(*p)
        sp.points[i].co = (v.x, v.y, v.z, 1)
    o = bpy.data.objects.new('t', cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    return o


def rotate(objs, angle, pivot=(0, 0, 0), axis='z'):
    """rotate objects about a game-space pivot (z axis = yaw seen from above)."""
    pv = G(*pivot)
    ax = {'z': 'Z', 'x': 'X', 'y': 'Y'}[axis]
    a = -angle if axis == 'y' else angle
    R = Matrix.Translation(pv) @ Matrix.Rotation(a, 4, ax) @ Matrix.Translation(-pv)
    for o in objs:
        o.matrix_world = R @ o.matrix_world


def wheel(x, y, z, r, w, tyre=None, rim=None, side=1, flat=False, hub_bolts=5):
    """road wheel with tread blocks, sidewall, pressed steel rim and hub."""
    tyre = tyre or mat((30, 30, 30), rough=0.9, grime=0.05)
    rim = rim or mat((92, 96, 92), rough=0.45, metal=0.5)
    zc = z if z else r * (0.86 if flat else 1.0)
    out = [cyl((x, y, zc), r, w, tyre, axis='y', bevel=r * 0.28, verts=28)]
    face = y + side * w * 0.5
    # sidewall ring
    out.append(cyl((x, face - side * 0.05, zc), r * 0.86, 0.5, mat((44, 44, 42), rough=0.85, grime=0.05), axis='y', bevel=0.1, verts=28))
    out.append(cyl((x, face - side * 0.2, zc), r * 0.62, 0.9, rim, axis='y', bevel=0.3, verts=24))
    out.append(cyl((x, face + side * 0.2, zc), r * 0.26, 0.8, mat((150, 152, 148), rough=0.35, metal=0.6), axis='y', bevel=0.2, verts=16))
    for i in range(hub_bolts):
        a = i / hub_bolts * math.tau
        out.append(box((x + math.cos(a) * r * 0.42, face + side * 0.45, zc + math.sin(a) * r * 0.42), (0.35, 0.3, 0.35),
                       mat((60, 62, 60)), bevel=0.05))
    return out


# ----------------------------------------------------------------- render ---
def render(path_tmp):
    sc = bpy.context.scene
    sc.render.filepath = path_tmp
    bpy.ops.render.render(write_still=True)
    return Image.open(path_tmp).convert('RGBA')


def to_sprite(img, cell=192, colours=40, outline=True, shadow=True):
    """big render -> HD pixel-art sprite (cell*HD square)."""
    W = cell * HD
    # undo the camera foreshortening of Z, then box-filter down
    im = img.resize((W * SS, int(round(img.height * STRETCH))), Image.LANCZOS)
    im = im.resize((W, im.height // SS), Image.BOX)
    a = np.array(im).astype(float)
    # pad / crop to a square cell anchored at the bottom
    out = np.zeros((W, W, 4))
    h = min(W, a.shape[0])
    out[W - h:, :, :] = a[a.shape[0] - h:, :W, :]
    a = out
    rgb, al = a[..., :3], a[..., 3]
    # un-premultiply soft edge pixels before hardening alpha
    solid = al >= 140
    shad = (al > 18) & ~solid
    lum = rgb.mean(axis=2)
    # shadow-catcher pixels are black with partial alpha
    is_shadow = shad & (lum < 40)
    res = np.zeros_like(a)
    res[solid, :3] = rgb[solid]
    res[solid, 3] = 255
    if shadow:
        sh = is_shadow & (al > 40)
        res[sh, :3] = (8, 10, 10)
        res[sh, 3] = np.clip(al[sh] * 0.85, 0, 120)
        res[sh, 3] = np.round(res[sh, 3] / 40) * 40
    pim = Image.fromarray(np.clip(res, 0, 255).astype(np.uint8), 'RGBA')
    # palette snap on the solid part
    if colours:
        solid_img = Image.fromarray(np.clip(res[..., :3], 0, 255).astype(np.uint8), 'RGB')
        q = solid_img.quantize(colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
        qa = np.array(q)
        r2 = np.array(pim)
        r2[solid, :3] = qa[solid]
        pim = Image.fromarray(r2, 'RGBA')
    if outline:
        r2 = np.array(pim)
        A = r2[..., 3] == 255
        g = np.zeros_like(A)
        g[1:] |= A[:-1]; g[:-1] |= A[1:]; g[:, 1:] |= A[:, :-1]; g[:, :-1] |= A[:, 1:]
        e = g & ~A
        r2[e] = OUTLINE + (255,)
        # darken inner silhouette edge slightly for a drawn look
        pim = Image.fromarray(r2, 'RGBA')
    return pim


def fit_cell(spr, cell_px, pad=2):
    """bottom-anchor and centre the solid part of a sprite in a cell_px square,
    the HD twin of wa_core.fit_canvas (ground contact = cell bottom)."""
    def solid_box(im):
        a = np.array(im)
        ys, xs = np.nonzero(a[..., 3] == 255)
        return (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1) if len(xs) else None
    sb = solid_box(spr)
    out = Image.new('RGBA', (cell_px, cell_px), (0, 0, 0, 0))
    if sb is None:
        return out
    k = min(1.0, (cell_px - 2 * pad) / (sb[2] - sb[0]), (cell_px - 2 * pad) / (sb[3] - sb[1]))
    if k < 1.0:
        spr = spr.resize((int(spr.width * k), int(spr.height * k)), Image.NEAREST)
        sb = solid_box(spr)
    ox = (cell_px - (sb[2] - sb[0])) // 2 - sb[0]
    oy = cell_px - pad - sb[3]
    layer = Image.new('RGBA', (cell_px, cell_px), (0, 0, 0, 0))
    layer.paste(spr, (ox, oy))
    out.alpha_composite(layer)
    return out


def img_mat(pil_img, rough=0.6, name='img'):
    """material from a PIL image (signs, stencils), UV-mapped by the caller."""
    import tempfile
    path = os.path.join(tempfile.gettempdir(), 'bk_%d_%s.png' % (id(pil_img), name))
    pil_img.save(path)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(path)
    t.interpolation = 'Closest'
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = rough
    return m


def panel(corners, m):
    """UV-mapped quad through 4 game-space corners (bl, br, tr, tl)."""
    me = bpy.data.meshes.new('pn')
    me.from_pydata([G(*c) for c in corners], [], [(0, 1, 2, 3)])
    me.update()
    uv = me.uv_layers.new(name='UV')
    for li, (u, v) in zip(range(4), ((0, 0), (1, 0), (1, 1), (0, 1))):
        uv.data[li].uv = (u, v)
    o = bpy.data.objects.new('pn', me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    return o
