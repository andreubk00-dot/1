"""OSTATOK 0.75 survivor: rig, outfit (from the reference), weapons in hands,
animation clips, and the sheet baker.

Sheet contract (unchanged from the pack, but 2x density):
  1024x1024 = 8 rows (E, SE, S, SW, W, NW, N, NE) x 8 frames of 128x128.
  Drawn in game with sprite scale 0.5 -> same world size as the old 64px cells.
"""
import math
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from char3d import Scene, V, norm, CELL, save_png, darker
import char3d

# 1.38 dev52: sheets are drawn at 1.28 px per rig unit; the game shows them at
# sprite scale 0.5 / 1.28 so one texel is one screen pixel (see char3d.K)
RENDER_K = 1.28
char3d.set_density(RENDER_K)

# ---------------------------------------------------------------- outfit --
JACKET = (94, 102, 62)
JACKET_D = (74, 81, 48)
JEANS = (58, 66, 86)
BOOTS = (54, 42, 32)
SKIN = (200, 154, 118)
BEARD = (86, 62, 44)
HELMET = (72, 80, 58)
PACK = (118, 106, 72)
PACK_D = (92, 82, 56)
ROLL = (78, 86, 60)
BELT = (60, 48, 36)
EYE = (34, 26, 22)
JEANS_D = (44, 50, 66)
KNEEPAD = (50, 52, 48)
GLOVE = (46, 44, 40)
SOLE = (30, 26, 22)
GAITER = (104, 104, 88)
POUCH = (104, 96, 66)
CANTEEN = (86, 92, 80)
BRASS = (190, 150, 70)
GOGGLE = (40, 44, 44)
LENS = (84, 100, 98)
NOSE = (176, 128, 96)

# gun palette
GM = (64, 68, 72)
GM_D = (44, 46, 50)
WOOD = (138, 74, 38)
BAKE = (122, 60, 30)
STEEL = (170, 172, 168)
FRED = (176, 40, 34)
BLK = (36, 36, 38)

CLIPS = ['Attack1', 'Attack2', 'Attack3', 'Attack4', 'CrouchIdle', 'CrouchRun', 'Die', 'Idle',
         'Idle2', 'Idle3', 'Run', 'RunAttack', 'RunBackwards', 'RunBackwardsAttack', 'StrafeLeft',
         'StrafeLeftAttack', 'StrafeRight', 'StrafeRightAttack', 'TakeDamage', 'Taunt', 'Walk']
MOVE_CLIPS = ('Walk', 'Run', 'RunBackwards', 'StrafeLeft', 'StrafeRight', 'CrouchRun')


def frame_count(clip):
    # 0.76: locomotion cycles use 12 frames for smoother, more anatomical motion
    return 12 if clip in MOVE_CLIPS else 8


WEAPONS = [None, 'makarov', 'shotgun', 'akm', 'pps43', 'izh81', 'aks74u', 'mosin', 'knife', 'pipe', 'axe']
FILE_PREFIX = {None: '', 'makarov': 'makarov_', 'shotgun': 'shotgun_', 'akm': 'akm_',
               'pps43': 'pps43_', 'izh81': 'izh81_', 'aks74u': 'aks74u_', 'mosin': 'mosin_',
               'knife': 'knife_', 'pipe': 'pipe_', 'axe': 'axe_'}

# ---------------------------------------------------------------- weapons --
# parts: (u0,u1, w0,w1, halfv, colour) in gun space: u along barrel from the
# right-hand grip, w up, v sideways.
GUNS = {
    'akm': dict(parts=[(-12, -2.5, -1.4, 1.6, 0.9, WOOD), (-12.6, -12, -1.6, 1.8, 1.0, GM_D),
                       (-2.5, 7.5, -0.2, 2.4, 1.2, GM), (-1.2, 1.0, -4.2, -0.2, 0.9, BAKE),
                       (3.0, 5.8, -5.0, -0.2, 1.0, BAKE), (4.2, 6.8, -7.5, -4.8, 0.9, BAKE),
                       (7.5, 13.0, 0.2, 2.2, 1.1, WOOD), (8.0, 12.5, 2.2, 3.0, 0.7, WOOD),
                       (12.5, 17.5, 0.8, 1.8, 0.5, GM_D), (15.6, 16.3, 1.8, 3.8, 0.4, GM_D),
                       (17.5, 18.8, 0.6, 2.0, 0.6, GM)],
                fore=10.0, muzzle=19.0, muzzle_w=1.3, cls='rifle'),
    'shotgun': dict(parts=[(-12, -2.0, -1.8, 1.6, 0.9, WOOD), (-12.6, -12, -1.9, 1.8, 1.0, BLK),
                           (-2.0, 5.5, -0.4, 2.4, 1.2, GM), (5.5, 20.0, 1.2, 2.3, 0.6, GM),
                           (5.5, 16.5, -0.2, 1.1, 0.55, GM_D), (8.0, 13.0, -0.8, 1.6, 1.1, WOOD),
                           (19.3, 19.8, 2.3, 3.0, 0.3, STEEL)],
                    fore=10.5, muzzle=20.5, muzzle_w=1.75, cls='rifle'),
    'makarov': dict(parts=[(-1.2, 7.0, 0.6, 2.8, 0.8, GM), (-1.0, 1.6, -3.4, 0.8, 0.75, BAKE),
                           (1.6, 3.4, -1.4, 0.6, 0.4, GM_D), (6.6, 7.2, 2.8, 3.4, 0.3, GM_D)],
                    fore=0.0, muzzle=7.4, muzzle_w=1.7, cls='pistol'),
    # 1.18 Arsenal Expansion II: each added firearm owns real in-hands geometry.
    # They share the anatomical rifle hold, but silhouette/length/foregrip/muzzle are authored per gun.
    'pps43': dict(parts=[
        (-11.0, -7.8, -0.5, 0.5, 0.55, GM_D), (-10.8, -10.1, -0.9, 0.9, 0.45, GM_D),
        (-7.8, -3.2, -1.0, 1.0, 0.55, GM_D), (-3.5, 5.2, -1.0, 2.0, 1.15, GM),
        (-0.2, 2.2, -5.8, -0.8, 0.90, GM_D), (1.0, 3.8, -7.0, -5.4, 0.75, GM_D),
        (4.8, 10.8, 0.1, 1.5, 0.65, GM_D), (10.6, 13.4, 0.5, 1.3, 0.42, STEEL),
        (12.8, 13.8, 0.3, 1.5, 0.55, GM),
    ], fore=6.7, muzzle=14.2, muzzle_w=0.9, cls='rifle'),
    'izh81': dict(parts=[
        (-12.5, -2.8, -1.8, 1.7, 0.95, WOOD), (-13.0, -12.3, -1.9, 1.8, 1.0, BLK),
        (-2.8, 5.0, -0.5, 2.3, 1.15, GM), (5.0, 20.8, 1.25, 2.15, 0.52, GM),
        (5.2, 17.5, -0.1, 0.8, 0.48, GM_D), (6.4, 12.0, -1.0, 1.4, 1.0, BAKE),
        (8.0, 12.4, -1.5, -0.9, 0.95, WOOD), (20.3, 20.8, 2.15, 2.9, 0.28, STEEL),
    ], fore=9.4, muzzle=21.2, muzzle_w=1.65, cls='rifle'),
    'aks74u': dict(parts=[
        (-10.2, -6.0, -0.5, 0.5, 0.50, GM_D), (-9.8, -9.0, -2.0, -0.5, 0.45, GM_D),
        (-6.2, -2.6, -1.2, 1.4, 0.65, GM_D), (-2.8, 6.2, -0.2, 2.3, 1.15, GM),
        (-0.4, 2.5, -4.6, -0.3, 0.85, BAKE), (1.2, 3.9, -6.8, -4.3, 0.72, BAKE),
        (5.7, 10.5, 0.0, 2.0, 1.0, WOOD), (10.2, 13.4, 0.6, 1.5, 0.48, GM_D),
        (12.9, 14.2, 0.35, 1.75, 0.70, GM), (13.8, 14.8, 0.2, 1.9, 0.58, GM_D),
    ], fore=8.0, muzzle=15.1, muzzle_w=1.05, cls='rifle'),
    'mosin': dict(parts=[
        (-14.5, -4.0, -1.9, 1.8, 0.95, WOOD), (-15.1, -14.3, -2.0, 1.9, 1.0, BLK),
        (-4.3, 8.0, -1.0, 1.9, 1.05, WOOD), (-3.0, 4.8, 1.1, 2.45, 0.72, GM),
        (2.0, 3.4, 2.2, 3.2, 0.42, GM_D), (4.6, 5.5, 1.8, 3.4, 0.38, STEEL),
        (7.6, 22.6, 0.6, 1.45, 0.42, GM_D), (10.0, 18.0, -0.2, 0.65, 0.48, WOOD),
        (16.8, 18.2, 1.45, 2.25, 0.30, GM_D), (22.2, 23.4, 0.35, 1.75, 0.48, GM),
    ], fore=10.7, muzzle=23.7, muzzle_w=1.0, cls='rifle'),
    'knife': dict(parts=[(-3.2, 0.2, -0.8, 0.8, 0.8, BLK), (0.2, 0.9, -1.6, 1.6, 0.9, GM),
                         (0.9, 8.0, -0.9, 0.9, 0.35, STEEL)],
                  fore=None, muzzle=None, cls='knife'),
    'pipe': dict(parts=[(-3.5, 2.5, -1.0, 1.0, 1.0, (60, 62, 62)), (2.5, 17.0, -0.9, 0.9, 0.9, (112, 116, 112)),
                        (16.5, 18.2, -1.2, 1.2, 1.2, GM)],
                 fore=None, muzzle=None, cls='heavy'),
    'axe': dict(parts=[(-3.5, 1.0, -0.8, 0.8, 0.8, BLK), (1.0, 17.0, -0.7, 0.7, 0.75, (170, 106, 60)),
                       (14.5, 17.8, -1.4, 1.4, 1.0, FRED), (14.8, 17.5, 1.4, 4.2, 0.7, FRED),
                       (13.2, 19.2, -5.6, -1.4, 0.8, FRED), (13.0, 19.4, -6.4, -5.4, 0.7, STEEL)],
             fore=6.0, muzzle=None, cls='heavy'),
}


# ---------------------------------------------------------------- math ----
def two_bone(a, target, l1, l2, pole):
    d = target - a
    dist = np.linalg.norm(d)
    dist = max(1e-3, min(dist, l1 + l2 - 0.05))
    dn = norm(d)
    target = a + dn * dist
    cos_a = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    cos_a = max(-1.0, min(1.0, cos_a))
    sin_a = math.sqrt(1 - cos_a * cos_a)
    p = pole - dn * np.dot(pole, dn)
    if np.linalg.norm(p) < 1e-4:
        p = V(0, 0, -1) - dn * dn[2]
    p = norm(p)
    mid = a + dn * (l1 * cos_a) + p * (l1 * sin_a)
    return mid, target


def rot_about(p, origin, axis, ang):
    axis = norm(axis)
    v = p - origin
    c, s = math.cos(ang), math.sin(ang)
    return origin + v * c + np.cross(axis, v) * s + axis * np.dot(axis, v) * (1 - c)


# ---------------------------------------------------------------- pose ----
class Pose:
    def __init__(self, d):
        a = d * math.pi / 4
        self.f = V(math.cos(a), math.sin(a), 0)       # forward (aim)
        self.r = V(-math.sin(a), math.cos(a), 0)      # character's right
        self.z = V(0, 0, 1)
        # defaults (body-local numbers)
        self.pelvis_z = 21.0
        self.lean = 0.0          # forward lean (rad)
        self.side_lean = 0.0
        self.twist = 0.0         # upper-body yaw
        self.bob = 0.0
        self.feet = {}           # side -> (f, r, z) local ankle
        self.hands = {}          # side -> (f, r, z) local target (unarmed)
        self.weapon = None
        self.grip = None         # (f, r, z) local
        self.gun_pitch = 0.0
        self.gun_yaw = 0.0
        self.two_hand = True
        self.fore_override = None
        self.flash = False
        self.fall = 0.0          # die: backward rotation angle
        self.head_pitch = 0.0
        self.foot_pitch = {'L': 0.0, 'R': 0.0}
        self.hip_f = {'L': 0.0, 'R': 0.0}   # pelvis rotation: hip moved forward/back
        self.shift_r = 0.0                   # weight shift over the stance leg

    def L(self, f, r, z):
        return self.f * f + self.r * r + self.z * z


def build(pose):
    s = Scene()
    P = pose
    pz = P.pelvis_z + P.bob
    pelvis = P.L(0, P.shift_r, pz)
    lean_axis = P.r

    def up(p):
        """apply upper-body lean/twist about the pelvis"""
        q = rot_about(p, pelvis, V(0, 0, 1), P.twist)
        q = rot_about(q, pelvis, lean_axis, P.lean)
        if P.side_lean:
            q = rot_about(q, pelvis, P.f, P.side_lean)
        return q

    # upper-body frame after lean
    fU = norm(up(pelvis + P.f) - pelvis)
    rU = norm(up(pelvis + P.r) - pelvis)
    zU = norm(up(pelvis + P.z) - pelvis)

    def U(f, r, z):
        return pelvis + fU * f + rU * r + zU * z

    pts = {}
    # --- legs
    for side, sg in (('L', -1), ('R', 1)):
        hip = pelvis + P.r * (2.7 * sg) + P.z * (-1.2) + P.f * P.hip_f[side]
        ff, fr, fz = P.feet.get(side, (0.6, 2.7 * sg, 3.0))
        ankle = P.L(ff, fr, fz)
        knee, ankle = two_bone(hip, ankle, 9.2, 9.0, P.f * 1.0 + P.z * 0.1)
        pts['hip' + side], pts['knee' + side], pts['ankle' + side] = hip, knee, ankle
    # --- torso anchor points
    chest = U(0, 0, 13.0)
    neck = U(0.2, 0, 15.2)
    head = U(0.6, 0, 19.6)
    if P.head_pitch:
        head = rot_about(head, neck, rU, P.head_pitch)
    sh = {'L': U(0, -6.0, 12.6), 'R': U(0, 6.0, 12.6)}

    # --- weapon frame
    gun = None
    if P.weapon:
        g = GUNS[P.weapon]
        gf, gr, gz = P.grip
        G = U(gf, gr, gz) if P.weapon else None
        gu = rot_about(fU, V(0, 0, 0), zU, P.gun_yaw)
        side_ax = norm(np.cross(zU, gu)) * -1          # points to character right
        gu = rot_about(gu, V(0, 0, 0), side_ax, P.gun_pitch)
        gv = norm(np.cross(gu, zU)) * -1
        if np.linalg.norm(np.cross(gu, zU)) < 0.1:
            gv = rU
        gw = norm(np.cross(gv, gu)) * -1
        if gw[2] < 0 and abs(gu[2]) < 0.9:
            gw = -gw
        gun = (g, G, gu, gv, gw)
        hands = {'R': G}
        if P.two_hand and g['fore'] is not None:
            fore = g['fore'] if P.fore_override is None else P.fore_override
            hands['L'] = G + gu * fore + gw * (0.4 if g['cls'] == 'rifle' else 0.0)
        elif P.two_hand and g['cls'] == 'pistol':
            hands['L'] = G - gv * 1.4 + gw * -0.6
        else:
            hl = P.hands.get('L', (0.8, -5.2, 12.0))
            hands['L'] = U(*hl) if len(hl) == 3 else hl
    else:
        hands = {k: U(*v) for k, v in P.hands.items()}
        hands.setdefault('L', U(0.8, -6.9, -0.6))
        hands.setdefault('R', U(0.8, 6.9, -0.6))

    if P.weapon:
        arm_pole = {'L': -rU * 0.8 - zU * 0.6 - fU * 0.2, 'R': rU * 0.8 - zU * 0.6 - fU * 0.2}
    else:   # free arms: elbows point back, slightly out (anatomical)
        arm_pole = {'L': -fU * 1.0 - rU * 0.25 - zU * 0.2, 'R': -fU * 1.0 + rU * 0.25 - zU * 0.2}
    for side in ('L', 'R'):
        el, wr = two_bone(sh[side], hands[side], 7.6, 7.4, arm_pole[side])
        pts['el' + side], pts['wr' + side] = el, wr

    # ------------------------------------------------------------- draw --
    # legs: rounded thigh + calf, knee pad, cuffs, pitched boots
    def far(vec):   # limb on the side away from the camera -> darker for depth
        return float(np.dot(vec, V(0, 1, 0))) < -0.2

    for side, sg in (('L', -1), ('R', 1)):
        hip, knee, ankle = pts['hip' + side], pts['knee' + side], pts['ankle' + side]
        JEANS_S = darker(JEANS, 0.8) if far(P.r * sg) else JEANS
        s.capsule(hip, knee, 2.8, 2.3, JEANS_S)
        shin_dir = norm(ankle - knee)
        s.capsule(knee, ankle, 2.25, 1.75, JEANS_S)
        # calf muscle bulge (behind the shin)
        back = norm(-P.f - shin_dir * np.dot(-P.f, shin_dir))
        s.capsule(knee + shin_dir * 1.5 + back * 0.8, knee + shin_dir * 5.0 + back * 0.6, 1.9, 1.5, JEANS_S, bias=-0.3, edge=False)
        # knee pad on the front of the knee
        kfront = norm(P.f - norm(knee - hip) * np.dot(P.f, norm(knee - hip)))
        s.ball(knee + kfront * 1.9 + V(0, 0, 0.2), 1.65, KNEEPAD, bias=0.6)
        s.capsule(ankle + V(0, 0, 1.3), ankle + V(0, 0, 0.3), 2.05, 2.1, JEANS_D, bias=0.2, edge=False)
        pitch = P.foot_pitch[side]
        toe_dir = norm(rot_about(P.f, V(0, 0, 0), P.r, -pitch))
        boot_up = norm(rot_about(P.z, V(0, 0, 0), P.r, -pitch))
        boot_c = ankle + toe_dir * 1.3 + boot_up * (-1.3)
        s.box(boot_c, toe_dir, P.r, boot_up, 3.1, 2.0, 1.6, BOOTS)
        s.box(boot_c + boot_up * -1.55, toe_dir, P.r, boot_up, 3.3, 2.1, 0.35, SOLE, edge=False)
        s.box(boot_c + toe_dir * 2.2 + boot_up * 0.4, toe_dir, P.r, boot_up, 0.9, 1.9, 1.1, darker(BOOTS, 1.15), edge=False)
    # pelvis, belt, buckle, pouch, canteen
    s.box(U(0, 0, 1.0), fU, rU, zU, 3.3, 5.1, 2.5, JEANS)
    s.box(U(0.05, 0, 3.4), fU, rU, zU, 3.45, 5.35, 0.75, BELT, edge=False)
    s.box(U(3.5, 0, 3.4), fU, rU, zU, 0.15, 0.8, 0.6, BRASS, edge=False)
    s.box(U(1.0, 5.9, 2.2), fU, rU, zU, 1.6, 0.9, 1.6, POUCH)
    s.box(U(1.0, 6.85, 2.6), fU, rU, zU, 1.5, 0.15, 0.3, darker(POUCH, 0.8), edge=False)
    s.capsule(U(-1.6, -5.9, 3.0), U(-1.6, -5.9, 0.4), 1.6, 1.6, CANTEEN)
    # torso (tapered: hips narrower than shoulders)
    tc = []
    for i in range(8):
        top = i & 4
        wr_ = 6.5 if top else 5.3
        dp = 3.7 if top else 3.3
        zz = 14.0 if top else 3.8
        tc.append(U((dp if i & 1 else -dp), (wr_ if i & 2 else -wr_), zz))
    s.block(tc, JACKET)
    # jacket: zip, pocket bodies + flaps + buttons, hem, fold lines, straps
    s.box(U(3.62, 0.3, 8.6), fU, rU, zU, 0.12, 0.3, 5.0, JACKET_D, edge=False)
    for sg in (-1, 1):
        s.box(U(3.7, 2.9 * sg, 10.2), fU, rU, zU, 0.25, 1.7, 1.5, JACKET_D, edge=False)
        s.box(U(3.85, 2.9 * sg, 11.6), fU, rU, zU, 0.2, 1.85, 0.5, darker(JACKET, 1.12), edge=False)
        s.pixel(U(4.0, 2.9 * sg, 11.2), BRASS, bias=0.2)
        s.box(U(3.65, 3.1 * sg, 5.4), fU, rU, zU, 0.25, 1.8, 1.4, JACKET_D, edge=False)
        s.box(U(3.8, 3.1 * sg, 6.7), fU, rU, zU, 0.2, 1.9, 0.4, darker(JACKET, 1.12), edge=False)
        s.box(U(3.9, 3.5 * sg, 12.9), fU, rU, zU, 0.2, 0.75, 1.3, PACK_D, edge=False)      # pack strap
        s.pixel(U(4.1, 3.5 * sg, 12.0), BRASS, bias=0.2)                                  # strap buckle
    s.box(U(0.0, 0, 4.5), fU, rU, zU, 3.55, 5.45, 0.55, JACKET_D, edge=False)           # hem
    # collar + neck gaiter
    s.box(U(0.3, 0, 14.5), fU, rU, zU, 2.8, 3.4, 0.95, JACKET_D, edge=False)
    # backpack: body, lid, side pockets, front pocket, bedroll with straps
    s.box(U(-6.1, 0, 8.6), fU, rU, zU, 2.7, 4.9, 5.9, PACK)
    s.box(U(-6.3, 0, 13.6), fU, rU, zU, 2.9, 5.0, 1.3, darker(PACK, 1.1))
    for sg in (-1, 1):
        s.box(U(-6.0, 5.5 * sg, 6.4), fU, rU, zU, 1.8, 0.8, 2.8, PACK_D)
    s.box(U(-8.95, 0, 6.8), fU, rU, zU, 0.5, 3.3, 2.9, PACK_D, edge=False)
    s.box(U(-9.25, 0, 8.6), fU, rU, zU, 0.25, 3.4, 0.5, darker(PACK_D, 0.8), edge=False)
    s.pixel(U(-9.5, 0, 7.4), BRASS, bias=0.3)
    s.capsule(U(-6.0, -5.8, 15.6), U(-6.0, 5.8, 15.6), 1.8, 1.8, ROLL)
    for sg in (-1, 1):
        s.box(U(-6.0, 3.6 * sg, 15.6), fU, rU, zU, 1.9, 0.35, 1.9, BELT, edge=False)
    # neck + gaiter
    s.capsule(neck, head - zU * 3.2, 1.7, 1.6, SKIN, edge=False)
    s.capsule(neck + zU * 0.2, neck + zU * 1.5, 2.3, 2.1, GAITER, bias=0.1)
    # head: ears, face, nose, brows, beard, moustache
    s.ball(head, 4.4, SKIN)
    for sg in (-1, 1):
        ear = head + rU * (4.2 * sg) + zU * -0.6 - fU * 0.3
        s.ball(ear, 1.0, darker(SKIN, 0.9), bias=-0.2 if np.dot(rU * sg, V(0, 1, 0.55)) < 0 else 0.3)
    face_vis = np.dot(fU, V(0, 1, 0.55)) + 0.35
    if face_vis > 0:
        s.ball(head + fU * 2.7 + zU * -2.9, 2.3, BEARD, bias=0.8)
        for sg in (-1, 1):
            s.ball(head + fU * 2.2 + rU * 2.6 * sg + zU * -1.6, 1.3, BEARD, bias=0.7)   # jaw beard
        s.box(head + fU * 3.9 + zU * -1.0, fU, rU, zU, 0.3, 1.3, 0.4, (104, 76, 54), edge=False)
        s.box(head + fU * 4.2 + zU * 0.0, fU, rU, zU, 0.35, 0.45, 0.7, NOSE, edge=False)
        for sg in (-1, 1):
            n = norm(fU * 0.9 + rU * 0.45 * sg)
            if np.dot(n, V(0, 1, 0.55)) > 0.05:
                s.pixel(head + fU * 4.1 + rU * (1.6 * sg) + zU * 0.6, EYE, bias=1.2)
                s.box(head + fU * 4.05 + rU * (1.7 * sg) + zU * 1.45, fU, rU, zU, 0.2, 0.8, 0.22, (70, 52, 38), edge=False)
    # helmet: dome, band, brim, goggles, chin strap
    hc = head + zU * 1.9 - fU * 0.4
    s.box(hc + zU * 0.6, fU, rU, zU, 4.6, 4.6, 1.9, HELMET)
    s.ball(hc + zU * 1.9, 4.2, HELMET, bias=1.0)
    s.box(hc + zU * -1.0 + fU * 0.4, fU, rU, zU, 5.0, 5.0, 0.45, (60, 66, 48), edge=False)
    s.box(hc + zU * 0.1, fU, rU, zU, 4.75, 4.75, 0.35, darker(HELMET, 0.8), edge=False)  # cover band
    s.box(hc + fU * 4.3 + zU * 1.0, fU, rU, zU, 0.5, 2.6, 0.75, GOGGLE, edge=False)
    for sg in (-1, 1):
        s.pixel(hc + fU * 4.9 + rU * 1.2 * sg + zU * 1.1, LENS, bias=0.4)
        s.capsule(hc + rU * 4.3 * sg + zU * -1.2, head + rU * 3.2 * sg + fU * 1.2 + zU * -3.6, 0.35, 0.35,
                  (52, 46, 36), bias=0.5, edge=False)

    # arms: rounded sleeves, elbow patch, cuff, fingerless gloves
    for side, sg in (('L', -1), ('R', 1)):
        el, wr = pts['el' + side], pts['wr' + side]
        JK = darker(JACKET, 0.82) if far(rU * sg) else JACKET
        s.capsule(sh[side], el, 2.35, 2.05, JK)
        s.ball(sh[side] + zU * 0.4, 2.3, JK, bias=0.1)                                     # shoulder cap
        s.capsule(el, wr, 2.0, 1.65, JK)
        s.ball(el, 1.45, JACKET_D, bias=0.2)                                               # elbow patch
        s.capsule(wr - norm(wr - el) * 1.4, wr - norm(wr - el) * 0.3, 1.8, 1.8, JACKET_D, bias=0.1, edge=False)
        hand = wr + norm(wr - el) * 0.9
        s.ball(hand, 1.75, GLOVE, bias=0.4)
        s.ball(hand + norm(wr - el) * 0.9, 1.0, SKIN, bias=0.5)                             # fingers

    # weapon
    if gun:
        g, G, gu, gv, gw = gun
        for (u0, u1, w0, w1, hv, col) in g['parts']:
            c = G + gu * ((u0 + u1) / 2) + gw * ((w0 + w1) / 2)
            s.box(c, gu, gv, gw, (u1 - u0) / 2, hv, (w1 - w0) / 2, col, edge=(u1 - u0) > 2.5)
        if P.flash and g['muzzle']:
            m = G + gu * g['muzzle'] + gw * g['muzzle_w']
            from char3d import proj
            a, b = proj(m), proj(m + gu)
            dx, dy = b[0] - a[0], b[1] - a[1]
            n = math.hypot(dx, dy) or 1
            s.flash(m, (dx / n, dy / n))
    return s


# ---------------------------------------------------------------- clips ---
def weapon_class(w):
    if w is None:
        return 'none'
    return GUNS[w]['cls']


def hold(P, w, t=0.0):
    """Set the weapon hold for class; t = breathing phase."""
    c = weapon_class(w)
    P.weapon = w
    br = 0.25 * math.sin(t * 2 * math.pi)
    if c == 'rifle':
        P.grip = (4.6, 3.0, 8.4 + br)
        P.gun_pitch = 0.04
    elif c == 'pistol':
        P.grip = (9.4, 0.8, 11.0 + br)
        P.gun_pitch = 0.0
    elif c == 'knife':
        P.grip = (5.2, 4.8, 5.0 + br)
        P.gun_pitch = -0.15
        P.two_hand = False
        P.hands['L'] = (0.8, -6.0, 1.8)
    elif c == 'heavy':
        P.grip = (3.4, 4.6, 4.4 + br)
        P.gun_pitch = 0.95
        P.two_hand = w == 'axe'
        P.hands['L'] = (1.0, -6.0, 1.8)
    else:
        P.weapon = None


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def keyinterp(keys, x):
    """keys: [(x, value...)] -> smoothstep-interpolated tuple"""
    for (x0, *v0), (x1, *v1) in zip(keys, keys[1:]):
        if x0 <= x <= x1:
            k = smooth((x - x0) / max(1e-6, x1 - x0))
            return tuple(a + (b - a) * k for a, b in zip(v0, v1))
    return tuple(keys[-1][1:])


GAITS = {
    # stance fraction, half stride, swing keys (s, forward*A, lift, toe pitch), stance pitch keys
    # 1.38 dev52: a juicier walk - longer stride, the knee lifted higher through
    # the swing, a clearer heel-strike and toe-off, more spring in the body
    # and a stronger hip / shoulder counter-swing (the old cycle read as a glide,
    # worst walking toward or away from the camera where the stride foreshortens)
    'walk': dict(S=0.60, A=6.6,
                 swing=[(0.0, -1.0, 1.8, -0.65), (0.32, -0.5, 4.4, -0.4), (0.68, 0.6, 3.2, 0.1), (1.0, 1.0, 0.0, 0.4)],
                 stance=[(0.0, 0.4), (0.16, 0.0), (0.66, 0.0), (1.0, -0.65)],
                 heel=1.8, bob=1.05, hip=0.85, twist=0.14, shift=0.7, lean=0.07),
    'run': dict(S=0.36, A=7.8,
                swing=[(0.0, -0.8, 2.8, -0.8), (0.3, -1.1, 9.4, -0.95), (0.62, 0.4, 7.6, 0.0), (1.0, 0.6, 0.0, 0.2)],
                stance=[(0.0, 0.2), (0.25, 0.0), (0.7, -0.1), (1.0, -0.8)],
                heel=2.6, bob=1.85, hip=1.05, twist=0.24, shift=0.4, lean=0.3),
    'crouch': dict(S=0.6, A=4.2,
                   swing=[(0.0, -1.0, 1.0, -0.5), (0.4, -0.4, 2.8, -0.3), (1.0, 1.0, 0.0, 0.2)],
                   stance=[(0.0, 0.2), (0.2, 0.0), (0.7, 0.0), (1.0, -0.5)],
                   heel=1.0, bob=0.5, hip=0.5, twist=0.06, shift=0.4, lean=0.3),
}


def gait(P, t, move, style='walk', amp_scale=1.0, pitch_scale=1.0):
    """Anatomical gait: planted stance with heel-strike/toe-off, lifted swing with
    knee flexion, pelvis rotation + counter-rotating shoulders, weight shift and
    double-bump bob. move = (forward, right) unit direction of travel (local)."""
    g = GAITS[style]
    S, A = g['S'], g['A'] * amp_scale
    mf, mr = move
    for side, sg, ph in (('L', -1, 0.0), ('R', 1, 0.5)):
        phi = (t + ph) % 1.0
        if phi < S:
            u = phi / S
            o = A * (1 - 2 * u) * (0.8 if style == 'run' else 1.0)
            pitch, = keyinterp(g['stance'], u)
            z = 3.0 + (g['heel'] * smooth((u - 0.7) / 0.3) if u > 0.7 else 0.0)
        else:
            sw = (phi - S) / (1 - S)
            fo, lift, pitch = keyinterp(g['swing'], sw)
            o = A * fo
            z = 3.0 + lift
        P.feet[side] = (0.6 + mf * o, 2.8 * sg + mr * o * 0.85, z)
        P.foot_pitch[side] = pitch * pitch_scale
    c = math.cos(2 * math.pi * t)
    # pelvis: forward leg's hip leads, shoulders counter-rotate
    P.hip_f['L'] = g['hip'] * c * mf
    P.hip_f['R'] = -g['hip'] * c * mf
    P.twist = -g['twist'] * c * mf
    stance_mid = g['S'] / 2
    P.shift_r = -g['shift'] * math.cos(2 * math.pi * (t - stance_mid))
    if style == 'run':
        P.bob = -g['bob'] * math.cos(4 * math.pi * (t - stance_mid))       # compress in stance, rise in flight
    else:
        P.bob = g['bob'] * math.cos(4 * math.pi * (t - stance_mid)) - g['bob']
    P.lean = g['lean'] * (1 if mf >= 0 else -0.3)
    return P


def unarmed_swing(P, t, amp, run=False):
    for side, sg, ph in (('L', -1, 0.5), ('R', 1, 0.0)):
        c = math.cos((t + ph) * 2 * math.pi)
        if run:
            P.hands[side] = (1.6 + amp * c, 5.0 * sg, 7.0 + 2.2 * max(0.0, c))
        else:
            P.hands[side] = (0.8 + amp * c, 6.9 * sg, -0.8 + abs(c) * 0.6 + max(0.0, c) * 0.9)


def carry_sway(P, t, k):
    """Weapon moves with the chest while walking/running."""
    if P.grip is None:
        return
    f, r, z = P.grip
    P.grip = (f, r, z + k * math.cos(4 * math.pi * t))
    P.gun_yaw += 0.02 * k * math.cos(2 * math.pi * t)
    P.twist *= 0.35          # a rifle keeps the torso squarer than free arms


def make_pose(clip, w, d, k):
    t = k / float(frame_count(clip))
    P = Pose(d)
    hold(P, w, t)
    cls = weapon_class(w)
    unarmed = cls == 'none'

    if clip.startswith('Idle'):
        amp = {'Idle': 0.35, 'Idle2': 0.5, 'Idle3': 0.3}[clip]
        P.bob = -amp * (0.5 + 0.5 * math.sin(t * 2 * math.pi))
        if clip == 'Idle3':
            P.twist = 0.08 * math.sin(t * 2 * math.pi)
        if unarmed:
            P.hands = {'L': (0.6, -6.9, -0.4 + P.bob), 'R': (0.6, 6.9, -0.4 + P.bob)}
    elif clip in ('Walk', 'Run', 'RunAttack'):
        run = clip != 'Walk'
        gait(P, t, (1, 0), 'run' if run else 'walk')
        if unarmed:
            unarmed_swing(P, t, 4.6 if run else 3.4, run)
        else:
            carry_sway(P, t, 0.85 if run else 0.5)
    elif clip.startswith('RunBackwards'):
        gait(P, t, (-1, 0), 'walk', amp_scale=0.8, pitch_scale=-0.5)
        P.lean = -0.04
        if unarmed:
            unarmed_swing(P, t, 2.0)
        else:
            carry_sway(P, t, 0.3)
    elif clip.startswith('StrafeLeft') or clip.startswith('StrafeRight'):
        sg = -1 if 'Left' in clip else 1
        gait(P, t, (0, sg), 'walk', amp_scale=0.7, pitch_scale=0.2)
        P.side_lean = 0.05 * sg
        P.lean = 0.03
        if unarmed:
            unarmed_swing(P, t, 1.2)
        else:
            carry_sway(P, t, 0.3)
    elif clip == 'CrouchIdle':
        P.pelvis_z = 13.5
        P.feet = {'L': (2.8, -3.4, 3.0), 'R': (-2.2, 3.2, 3.0)}
        P.foot_pitch = {'L': 0.0, 'R': -0.35}
        P.lean = 0.22
        P.bob = -0.3 * math.sin(t * 2 * math.pi)
        if unarmed:
            unarmed_swing(P, 0.25, 0.0)
    elif clip == 'CrouchRun':
        P.pelvis_z = 15.0
        gait(P, t, (1, 0), 'crouch')
        if unarmed:
            unarmed_swing(P, t, 2.0)
        else:
            carry_sway(P, t, 0.3)
    elif clip == 'TakeDamage':
        a = math.sin(min(1.0, t * 1.6) * math.pi)
        P.lean = -0.28 * a
        P.head_pitch = -0.25 * a
        P.feet = {'L': (0.6 - 1.5 * a, -2.8, 3.0), 'R': (0.6, 2.8, 3.0)}
        if unarmed:
            P.hands = {'L': (1.5, -6.0, 5 + 3 * a), 'R': (1.5, 6.0, 5 + 3 * a)}
        else:
            P.gun_pitch += 0.35 * a
    elif clip == 'Die':
        a = min(1.0, k / 6.0)
        P.pelvis_z = 21.0 - 7.0 * min(1.0, a * 1.6)
        P.feet = {'L': (1.8, -3.0, 3.0), 'R': (-0.6, 3.2, 3.0)}
        P.fall = (math.pi * 0.46) * (a ** 1.4)
        if w:
            P.gun_pitch = -0.5 * a
            if a > 0.5:
                P.two_hand = False
                P.hands['L'] = (0.0, -7.0, 4.0)
        else:
            P.hands = {'L': (0.0, -7.0, 4.0 + 6 * a), 'R': (0.0, 7.0, 4.0 + 6 * a)}
    elif clip == 'Taunt':        # reload
        a = math.sin(t * math.pi)
        if cls == 'rifle':
            P.gun_pitch = 0.04 + 0.22 * a
            P.gun_yaw = -0.25 * a
            P.fore_override = GUNS[w]['fore'] - 6.0 * a if w == 'akm' else GUNS[w]['fore'] - 3.0 * a
        elif cls == 'pistol':
            P.grip = (7.0, 1.2, 9.0)
            P.gun_pitch = 0.5 * a
            P.two_hand = a < 0.3
            P.hands['L'] = (4.0, 0.0, 4.0 + 3 * (1 - a))
        elif unarmed:
            P.hands = {'L': (3.0, -3.0, 10.0 * a + 2), 'R': (3.0, 3.0, 10.0 * a + 2)}
    if clip in ('Attack1', 'Attack2') or clip.endswith('Attack'):
        if cls in ('rifle', 'pistol'):
            kick = [1.8, 1.2, 0.6, 0.25, 0, 0, 0, 0][k]
            f, r, z = P.grip
            P.grip = (f - kick, r, z + kick * 0.3)
            P.gun_pitch += kick * 0.06
            P.flash = k in (0, 1) and clip in ('Attack1', 'RunAttack', 'StrafeLeftAttack',
                                               'StrafeRightAttack', 'RunBackwardsAttack')
            # Attack2 is reserved for post-shot mechanical cycling on manually-operated guns.
            if clip == 'Attack2' and w in ('shotgun', 'izh81') and 2 <= k <= 7:
                # Pump fore-end travels rearward, pauses, then locks forward.
                pump = [0.0, 0.0, 1.6, 3.8, 5.2, 4.0, 1.8, 0.0][k]
                P.fore_override = GUNS[w]['fore'] - pump
                P.gun_pitch += [0.0, 0.0, 0.02, 0.05, 0.08, 0.06, 0.03, 0.0][k]
            elif clip == 'Attack2' and w == 'mosin' and 1 <= k <= 7:
                # Bolt cycle: support hand stays on the rifle while the firing hand works the bolt.
                bolt = [0.0, 0.18, 0.45, 0.78, 1.0, 0.72, 0.32, 0.0][k]
                P.gun_yaw -= 0.12 * bolt
                P.gun_pitch += 0.08 * bolt
                f, r, z = P.grip
                P.grip = (f - 1.2 * bolt, r + 1.0 * bolt, z + 1.6 * bolt)
            elif w == 'shotgun' and 3 <= k <= 6 and clip != 'Attack2':
                # Legacy recoil motion on other attack clips.
                P.fore_override = GUNS[w]['fore'] - [0, 0, 0, 2.5, 4.5, 4.5, 2.0, 0][k]
    if clip == 'Attack3':            # heavy swing / punch
        if cls in ('heavy', 'knife', 'none'):
            ph = [0.0, 0.35, 0.8, 1.0, 1.0, 0.7, 0.4, 0.1][k]
            back = [0.0, 1.0, 0.6, 0.0, 0.0, 0.0, 0.0, 0.0][k]
            if unarmed:
                P.hands = {'L': (1.0, -6.0, 5.0), 'R': (2.0 + 9 * ph, 4.0 - 2 * ph, 9.0)}
            else:
                P.grip = (2.0 + 5.5 * ph - 2.5 * back, 4.6 - 2.5 * ph, 10.0 + 3.0 * back - 4.0 * ph)
                P.gun_pitch = 1.9 * back + 0.95 * (1 - back) - 1.35 * ph
            P.twist = 0.35 * back - 0.3 * ph
            P.lean = 0.15 * ph
    if clip == 'Attack4':            # stab / jab
        if cls in ('heavy', 'knife', 'none'):
            ph = [0.0, 0.5, 1.0, 1.0, 0.7, 0.4, 0.15, 0.0][k]
            if unarmed:
                P.hands = {'L': (2.0, -5.0, 9.0), 'R': (2.0 + 9 * ph, 3.5 - 3 * ph, 10.0)}
            else:
                P.grip = (5.2 + 6.0 * ph, 4.8 - 3.0 * ph, 6.0 + 2.0 * ph)
                P.gun_pitch = -0.15 + 0.1 * ph
            P.twist = -0.3 * ph
            P.lean = 0.12 * ph
    return P


def render_frame(clip, w, d, k):
    P = make_pose(clip, w, d, k)
    if P.fall:
        return render_fallen(P)
    return build(P).render()


def render_fallen(P):
    """Die: the posed rig tips over backwards about the heels onto the ground."""
    import char3d
    ang = P.fall
    if abs(P.f[0]) >= 0.7:          # E / W / diagonals: face-down, readable sideways
        origin, axis = P.L(-1.5, 0, 0), P.r
    else:                            # S / N: topple onto the side so the body reads horizontally
        origin, axis = P.L(0, 2.0, 0), -P.f
    old = char3d.proj

    def rproj(p):
        q = rot_about(np.asarray(p, float), origin, axis, ang)
        q[2] = max(q[2], 0.4 * (q[2] - 0.0))
        return old(q)
    char3d.proj = rproj
    try:
        s = build(P)
    finally:
        char3d.proj = old
    return s.render()


def sheet(clip, w):
    n = frame_count(clip)
    im = Image.new('RGBA', (CELL * n, CELL * 8))
    for d in range(8):
        for k in range(n):
            im.alpha_composite(render_frame(clip, w, d, k), (k * CELL, d * CELL))
    return im


def build_all(project):
    for w in WEAPONS:
        for clip in CLIPS:
            save_png(sheet(clip, w), os.path.join(project, 'survivor_%s%s.png' % (FILE_PREFIX[w], clip)))


if __name__ == '__main__':
    build_all(sys.argv[1])
