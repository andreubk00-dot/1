"""OSTATOK 0.77 infected renderer.

Four original infected variants rendered from a small 3D rig into 128x128
3/4 top-down pixel-art cells. Locomotion uses a 12-frame distance-driven gait;
attack uses 8 frames. The world sprite is drawn at 0.5 scale.
"""
import math
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from char3d import Scene, V, norm, CELL, save_png, darker
import char3d

# 1.38 dev56: drawn at 1.24 px per rig unit and shown at sprite scale 0.5, so a
# texel is one screen pixel (the old 1x sheets at scale 0.62 showed 1.24 px per
# texel, unevenly doubled); same world size, feet in the same place
RENDER_K = 1.24
char3d.set_density(RENDER_K)

OUT = CELL
DIRS = 8
WALK_FRAMES = 12
ATTACK_FRAMES = 8
VARIANTS = 4

# Muted, post-Soviet survival palette: each variant has a distinct readable outfit.
VARIANT = [
    dict(name='worker', top=(78, 86, 60), top2=(61, 68, 48), pants=(57, 60, 60),
         boots=(47, 38, 31), skin=(143, 139, 116), hair=(54, 43, 34), wound=(112, 37, 31),
         accent=(142, 105, 48), hunch=0.19, drag='L', head_tilt=0.10),
    dict(name='clinic', top=(72, 91, 87), top2=(55, 72, 70), pants=(69, 74, 76),
         boots=(45, 42, 39), skin=(151, 145, 125), hair=(63, 57, 50), wound=(120, 43, 36),
         accent=(173, 166, 145), hunch=0.15, drag='R', head_tilt=-0.11),
    dict(name='civilian', top=(62, 72, 88), top2=(46, 54, 68), pants=(67, 58, 50),
         boots=(49, 38, 29), skin=(137, 134, 113), hair=(73, 57, 40), wound=(105, 34, 30),
         accent=(104, 83, 62), hunch=0.23, drag='L', head_tilt=0.15),
    dict(name='militia', top=(70, 77, 57), top2=(49, 55, 42), pants=(44, 49, 53),
         boots=(36, 32, 29), skin=(130, 132, 111), hair=(46, 42, 36), wound=(128, 42, 32),
         accent=(98, 92, 65), hunch=0.18, drag='R', head_tilt=-0.08),
]


# dev59: archetype and high-risk bodies, each in its own sheet (8 dirs).
# size scales the render density (a big body gets more pixels, not bigger
# ones); girth/limb thicken the torso and the limbs; gait picks the walk.
EXTRA = [
    dict(name='runner', top=(58, 66, 86), top2=(44, 50, 66), pants=(52, 56, 74),
         boots=(60, 58, 54), skin=(146, 140, 118), hair=(40, 34, 30), wound=(118, 38, 32),
         accent=(170, 168, 158), hunch=0.34, drag='R', head_tilt=0.18,
         size=0.97, girth=0.82, limb=0.82, gait='run', stripes=True),
    dict(name='brute', top=(66, 62, 52), top2=(50, 47, 40), pants=(48, 52, 58),
         boots=(36, 30, 26), skin=(138, 128, 108), hair=None, wound=(124, 40, 32),
         accent=(92, 80, 56), hunch=0.12, drag='L', head_tilt=0.05,
         size=1.2, girth=1.42, limb=1.38, gait='heavy', straps=True),
    dict(name='screamer', top=(92, 86, 80), top2=(70, 66, 60), pants=(58, 54, 50),
         boots=(44, 38, 32), skin=(168, 160, 140), hair=(80, 74, 68), wound=(130, 42, 36),
         accent=(120, 110, 96), hunch=0.08, drag='L', head_tilt=-0.42,
         size=1.03, girth=0.74, limb=0.74, gait='shamble', long_neck=True, mouth=True, long_arms=True),
    dict(name='spitter', top=(88, 96, 70), top2=(68, 76, 54), pants=(60, 64, 58),
         boots=(44, 40, 34), skin=(150, 152, 104), hair=(52, 50, 40), wound=(110, 120, 46),
         accent=(160, 168, 82), hunch=0.22, drag='R', head_tilt=0.12,
         size=1.0, girth=1.0, limb=0.92, gait='shamble', throat=True, mouth=True),
    dict(name='carrier', top=(150, 98, 44), top2=(118, 76, 34), pants=(136, 90, 42),
         boots=(48, 44, 38), skin=(150, 150, 112), hair=None, wound=(150, 160, 64),
         accent=(70, 70, 64), hunch=0.16, drag='L', head_tilt=0.08,
         size=1.08, girth=1.32, limb=1.08, gait='heavy', bloat=True, pustules=True),
    dict(name='soldier', top=(84, 90, 62), top2=(64, 70, 48), pants=(78, 82, 58),
         boots=(34, 30, 26), skin=(132, 130, 110), hair=None, wound=(124, 40, 32),
         accent=(56, 60, 44), hunch=0.17, drag='R', head_tilt=0.06,
         size=1.03, girth=1.08, limb=1.0, gait='shamble', helmet=True, armor=True),
    dict(name='patient', top=(170, 182, 184), top2=(140, 152, 156), pants=(150, 142, 122),
         boots=(140, 132, 112), skin=(156, 148, 126), hair=(70, 64, 56), wound=(134, 44, 38),
         accent=(196, 194, 182), hunch=0.2, drag='L', head_tilt=-0.12,
         size=0.98, girth=0.9, limb=0.86, gait='shamble', gown=True),
    dict(name='hazmat', top=(176, 160, 56), top2=(142, 128, 42), pants=(170, 154, 52),
         boots=(40, 40, 38), skin=(140, 136, 114), hair=None, wound=(120, 40, 34),
         accent=(42, 44, 42), hunch=0.18, drag='R', head_tilt=0.04,
         size=1.02, girth=1.12, limb=1.08, gait='shamble', hazmat=True),
]
EXTRA_BASE = len(VARIANT)
VARIANT.extend(EXTRA)


def two_bone(a, target, l1, l2, pole):
    d = target - a
    dist = np.linalg.norm(d)
    dist = max(1e-3, min(dist, l1 + l2 - 0.05))
    dn = norm(d)
    target = a + dn * dist
    ca = (l1*l1 + dist*dist - l2*l2) / (2*l1*dist)
    ca = max(-1.0, min(1.0, ca))
    sa = math.sqrt(max(0.0, 1.0 - ca*ca))
    p = pole - dn * np.dot(pole, dn)
    if np.linalg.norm(p) < 1e-4:
        p = V(0, 0, -1) - dn * dn[2]
    p = norm(p)
    mid = a + dn * (l1 * ca) + p * (l1 * sa)
    return mid, target


def rot_about(p, origin, axis, ang):
    axis = norm(axis)
    v = p - origin
    c, s = math.cos(ang), math.sin(ang)
    return origin + v*c + np.cross(axis, v)*s + axis*np.dot(axis, v)*(1-c)


class Pose:
    def __init__(self, direction, variant):
        a = direction * math.pi / 4.0
        self.f = V(math.cos(a), math.sin(a), 0)
        self.r = V(-math.sin(a), math.cos(a), 0)
        self.z = V(0, 0, 1)
        self.variant = variant
        self.pelvis_z = 20.0
        self.bob = 0.0
        self.lean = VARIANT[variant]['hunch']
        self.side_lean = 0.0
        self.twist = 0.0
        self.head_tilt = VARIANT[variant]['head_tilt']
        self.feet = {'L': (0.8, -2.8, 3.0), 'R': (0.8, 2.8, 3.0)}
        self.hands = {'L': (3.0, -5.8, 6.0), 'R': (3.2, 5.8, 6.3)}
        self.attack = 0.0
        self.attack_side = 1 if variant % 2 == 0 else -1
        self.shift_r = 0.0
        self.head_forward = 0.0

    def L(self, f, r, z):
        return self.f*f + self.r*r + self.z*z


def walk_pose(direction, variant, k):
    t = k / float(WALK_FRAMES)
    ph = t * math.tau
    P = Pose(direction, variant)
    C = VARIANT[variant]
    gait = C.get('gait', 'shamble')
    if gait == 'run':
        return run_pose(direction, variant, k)
    drag_side = C['drag']
    # Asymmetrical shambling gait. One leg drags, the other carries more weight.
    base_amp = 5.2
    if variant == 2:
        base_amp = 5.8
    if gait == 'heavy':
        base_amp = 4.2
    for side, off, sg in [('L', 0.0, -1), ('R', math.pi, 1)]:
        s = math.sin(ph + off)
        lift = max(0.0, math.sin(ph + off))
        # dev56: the bad leg barely leaves the ground - it is hauled forward,
        # scuffing, while the good one steps high and takes the weight
        amp = base_amp * (0.5 if side == drag_side else 1.05)
        zlift = (0.6 if side == drag_side else 3.2) * lift
        # dragging foot trails slightly behind and turns inward visually
        trail = -1.8 if side == drag_side else 0.0
        P.feet[side] = (0.5 + s*amp + trail, 2.9*sg, 3.0 + zlift)
    # the body drops onto the bad leg when it has to carry it (a lurch), and
    # rises again over the good one
    drag_ph = ph + (0.0 if drag_side == 'L' else math.pi)
    P.bob = -0.35*abs(math.sin(ph)) - 0.55*max(0.0, -math.sin(drag_ph)) + 0.15*math.sin(ph*2.0)
    P.shift_r = 1.1*math.sin(ph) * (1 if drag_side == 'L' else -1)
    P.twist = 0.10*math.sin(ph + math.pi*0.35)
    P.side_lean = 0.05*math.sin(ph) + (0.04 if drag_side == 'L' else -0.04)
    P.head_tilt += 0.045*math.sin(ph*0.5 + variant)
    # arms mostly hang, with unequal swing and occasional clawing reach
    P.hands['L'] = (3.1 + 1.2*math.sin(ph+math.pi), -5.6, 5.7 + 0.5*math.cos(ph))
    P.hands['R'] = (3.5 + 1.7*math.sin(ph), 5.6, 6.0 + 0.6*math.cos(ph+0.4))
    if variant == 1:
        P.hands['L'] = (4.4 + 0.8*math.sin(ph), -5.2, 7.2)
    elif variant == 3:
        P.hands['R'] = (4.8 + 0.9*math.sin(ph), 5.1, 7.6)
    if gait == 'heavy':
        # wide, sagging stance: each step drops the whole mass, arms hang wide
        P.bob *= 1.5
        P.side_lean *= 1.6
        for side, sg in [('L', -1), ('R', 1)]:
            f, r, z = P.feet[side]
            P.feet[side] = (f, r*1.25, z)
        P.hands['L'] = (2.6 + 1.0*math.sin(ph+math.pi), -6.9, 5.2)
        P.hands['R'] = (2.9 + 1.2*math.sin(ph), 6.9, 5.4)
    if C.get('long_arms'):
        P.hands['L'] = (P.hands['L'][0] + 0.6, P.hands['L'][1], P.hands['L'][2] - 2.0)
        P.hands['R'] = (P.hands['R'][0] + 0.6, P.hands['R'][1], P.hands['R'][2] - 2.0)
    if C.get('hazmat') or C.get('armor'):
        P.hands['L'] = (P.hands['L'][0], P.hands['L'][1] - 0.6, P.hands['L'][2])
        P.hands['R'] = (P.hands['R'][0], P.hands['R'][1] + 0.6, P.hands['R'][2])
    return P


def run_pose(direction, variant, k):
    # the runner: a stumbling sprint, pitched forward, arms flung back
    t = k / float(WALK_FRAMES)
    ph = t * math.tau
    P = Pose(direction, variant)
    for side, off, sg in [('L', 0.0, -1), ('R', math.pi, 1)]:
        s = math.sin(ph + off)
        lift = max(0.0, math.sin(ph + off))
        P.feet[side] = (0.8 + s*7.4, 2.6*sg, 3.0 + 4.6*lift)
    P.pelvis_z = 19.2
    P.bob = -0.9*abs(math.cos(ph)) + 0.5
    P.twist = 0.2*math.sin(ph)
    P.side_lean = 0.06*math.sin(ph)
    P.head_tilt += 0.08*math.sin(ph*2.0)
    P.head_forward = 1.2
    P.hands['L'] = (-1.0 - 4.2*math.sin(ph), -5.9, 8.4 + 1.2*math.cos(ph))
    P.hands['R'] = (-1.0 + 4.2*math.sin(ph), 5.9, 8.4 - 1.2*math.cos(ph))
    return P


def attack_pose(direction, variant, k):
    t = k / float(max(1, ATTACK_FRAMES-1))
    P = Pose(direction, variant)
    # anticipate -> lunge -> contact -> recoil
    if t < 0.30:
        a = t/0.30
        lunge = -1.5*a
        reach = 1.0 + 2.0*a
    elif t < 0.62:
        a = (t-0.30)/0.32
        lunge = -1.5 + 6.0*math.sin(a*math.pi*0.5)
        reach = 3.0 + 8.5*math.sin(a*math.pi*0.5)
    else:
        a = (t-0.62)/0.38
        lunge = 4.5*(1-a)
        reach = 11.5*(1-a) + 3.0*a
    P.attack = max(0.0, math.sin(t*math.pi))
    P.lean += 0.16*P.attack
    P.pelvis_z -= 1.5*P.attack
    P.head_forward = 1.8*P.attack
    P.bob = -1.0*P.attack
    P.feet = {'L': (1.0 + lunge*0.30, -3.0, 3.0), 'R': (-1.2 + lunge*0.10, 3.1, 3.0)}
    if P.attack_side > 0:
        P.hands['R'] = (reach, 2.7, 9.2)
        P.hands['L'] = (reach-2.2, -4.3, 7.4)
        P.twist = -0.23*P.attack
    else:
        P.hands['L'] = (reach, -2.7, 9.2)
        P.hands['R'] = (reach-2.2, 4.3, 7.4)
        P.twist = 0.23*P.attack
    return P


def build(P):
    s = Scene()
    C = VARIANT[P.variant]
    g = C.get('girth', 1.0)
    lm = C.get('limb', 1.0)
    pz = P.pelvis_z + P.bob
    pelvis = P.L(0, P.shift_r, pz)

    def up(p):
        q = rot_about(p, pelvis, V(0,0,1), P.twist)
        q = rot_about(q, pelvis, P.r, P.lean)
        if P.side_lean:
            q = rot_about(q, pelvis, P.f, P.side_lean)
        return q

    fU = norm(up(pelvis + P.f) - pelvis)
    rU = norm(up(pelvis + P.r) - pelvis)
    zU = norm(up(pelvis + P.z) - pelvis)
    def U(f,r,z):
        return pelvis + fU*f + rU*r + zU*z

    pts = {}
    for side, sg in [('L',-1),('R',1)]:
        hip = pelvis + P.r*(2.65*sg) + P.z*(-1.0)
        ff, fr, fz = P.feet[side]
        ankle = P.L(ff, fr, fz)
        knee, ankle = two_bone(hip, ankle, 9.0, 8.8, P.f*1.0 + P.z*0.12)
        pts['hip'+side], pts['knee'+side], pts['ankle'+side] = hip,knee,ankle

    chest = U(0,0,12.4)
    neck = U(0.4,0,15.0)
    head = U(1.4 + P.head_forward,0,18.7)
    head = rot_about(head, neck, rU, P.head_tilt)
    sh = {'L':U(0,-5.4,12.2),'R':U(0,5.4,12.2)}
    hands = {k:U(*v) for k,v in P.hands.items()}
    for side in ('L','R'):
        pole = (-fU*0.65 + (-rU if side=='L' else rU)*0.35 - zU*0.15)
        el,wr = two_bone(sh[side], hands[side], 7.4, 7.2, pole)
        pts['el'+side],pts['wr'+side]=el,wr

    # Shadow is intentionally omitted here; Godot draws the shared world shadow.
    # Legs (far side slightly darker for depth)
    for side, sg in [('L',-1),('R',1)]:
        far = float(np.dot(P.r*sg, V(0,1,0))) < -0.2
        pants = darker(C['pants'],0.80) if far else C['pants']
        hip,knee,ankle=pts['hip'+side],pts['knee'+side],pts['ankle'+side]
        if C.get('gown'):
            pants = darker(C['skin'],0.86) if far else C['skin']
        s.capsule(hip,knee,2.5*lm,2.05*lm,pants)
        s.capsule(knee,ankle,2.0*lm,1.6*lm,pants)
        if C.get('stripes'):
            s.capsule(hip + P.f*0.2 + P.r*(1.9*sg*lm),ankle + P.r*(1.3*sg*lm),0.45,0.4,C['accent'],edge=False)
        # dirty knee / torn fabric marker
        if (P.variant + (0 if side=='L' else 1)) % 2 == 0:
            s.ball(knee + P.f*1.4 + V(0,0,0.2),1.25,darker(C['pants'],0.58),bias=0.4)
        boot_c = ankle + P.f*1.1 + P.z*(-1.2)
        s.box(boot_c,P.f,P.r,P.z,2.8*lm,1.75*lm,1.45,C['boots'])

    # pelvis and torso
    s.box(U(0,0,1.0),fU,rU,zU,3.2*g,4.8*g,2.3,C['pants'])
    s.box(U(0.2,0,7.0),fU,rU,zU,3.7*g,5.4*g,5.1,C['top'])
    s.box(U(3.65*g,0,7.2),fU,rU,zU,0.35,4.8*g,4.4,C['top2'],edge=False)
    if C.get('gown'):
        # hospital gown: one loose sheet from the shoulders to the knees
        s.box(U(0.2,0,4.0),fU,rU,zU,3.9*g,5.7*g,8.6,C['top'])
        s.box(U(3.95*g,0,4.0),fU,rU,zU,0.25,5.0*g,7.8,C['top2'],edge=False)
    if C.get('bloat'):
        s.ball(U(2.6*g,0,5.4),4.4*g,C['top'],bias=0.3)
    if C.get('armor'):
        # plate carrier over the jacket, pouches across the front
        s.box(U(0.6,0,7.6),fU,rU,zU,4.0*g,5.0*g,4.2,C['accent'])
        for r in (-2.4, 0.0, 2.4):
            s.box(U(4.0*g,r,6.6),fU,rU,zU,0.9,1.9,1.6,darker(C['accent'],0.8))
    if C.get('straps'):
        s.box(U(3.9*g,-1.7*g,8.0),fU,rU,zU,0.2,0.9,5.2,C['accent'],edge=False)
        s.box(U(3.9*g,1.7*g,8.0),fU,rU,zU,0.2,0.9,5.2,C['accent'],edge=False)
    # collar / waist breakup
    s.box(U(3.9*g,0,10.6),fU,rU,zU,0.30,3.7*g,0.55,C['accent'],edge=False)
    s.box(U(3.8*g,0,3.7),fU,rU,zU,0.28,4.5*g,0.45,darker(C['top2'],0.72),edge=False)

    # arms with torn cuffs and exposed infected skin
    for side, sg in [('L',-1),('R',1)]:
        far = float(np.dot(P.r*sg,V(0,1,0))) < -0.2
        top = darker(C['top'],0.78) if far else C['top']
        el,wr=pts['el'+side],pts['wr'+side]
        if C.get('gown'):
            top = darker(C['skin'],0.86) if far else C['skin']
        s.capsule(sh[side],el,2.35*lm,1.95*lm,top)
        # forearms partly exposed on alternating variants
        expose = ((P.variant + (0 if side=='L' else 1)) % 3) != 0
        if C.get('hazmat') or C.get('armor'):
            expose = False
        fore_col = C['skin'] if expose else top
        s.capsule(el,wr,1.85*lm,1.45*lm,fore_col)
        glove = C['accent'] if C.get('hazmat') else darker(C['skin'],0.92)
        s.ball(wr,1.7*lm,glove)
        if C.get('stripes'):
            s.capsule(sh[side] + rU*(1.6*sg*lm),el + rU*(1.3*sg*lm),0.4,0.4,C['accent'],edge=False)

    # neck/head, gaunt and asymmetric
    if C.get('long_neck'):
        neck = neck + zU*1.2
        head = head + zU*1.4 - fU*0.6
    if C.get('throat'):
        # a swollen, glistening throat sac
        s.ball(U(2.4,0,13.6),2.9,C['wound'],bias=0.5)
    neck_col = C['top'] if C.get('hazmat') else darker(C['skin'],0.90)
    s.capsule(U(0.4,0,14.0),neck,1.55,1.45,neck_col,bias=0.2)
    head_col = C['top'] if C.get('hazmat') else C['skin']
    s.ball(head,4.15,head_col,bias=0.4)
    if C.get('hazmat'):
        # hood with a dark visor and the twin filter canister
        s.box(head + fU*3.3 + zU*0.4,fU,rU,zU,0.6,4.6,2.6,C['accent'],edge=False)
        s.ball(head + fU*3.6 - zU*1.8 - rU*1.1,1.0,C['accent'])
        s.ball(head + fU*3.6 - zU*1.8 + rU*1.1,1.0,C['accent'])
    else:
        # sunken face and hair/scalp silhouette
        s.ball(head + fU*3.15 + zU*0.15,1.35,darker(C['skin'],0.68),bias=0.8)
        if C.get('mouth'):
            s.ball(head + fU*3.5 - zU*1.4,1.15,(40,16,14),bias=1.0)
        if C.get('helmet'):
            s.ball(head + zU*1.5,4.5,C['top'],bias=0.25)
            s.box(head + zU*0.5 + fU*0.3,fU,rU,zU,4.6,4.8,0.5,darker(C['top'],0.75),edge=False)
        elif P.variant != 0 and C.get('hair') is not None:
            s.ball(head - fU*0.5 + zU*2.5,3.1,C['hair'],bias=0.2)
    if C.get('pustules'):
        for (f, r, z, rad) in [(3.6,1.8,8.8,0.9),(3.2,-2.4,6.0,1.1),(1.0,4.6,9.5,0.8),(3.9,0.2,4.4,0.8),(-0.6,-4.8,7.2,0.9)]:
            s.ball(U(f*g,r*g,z),rad,(186,182,86),bias=0.9)
        s.ball(head + fU*2.4 + rU*2.4,0.9,(186,182,86),bias=1.0)
    # wounds by variant
    if P.variant >= EXTRA_BASE:
        s.ball(U(3.9*g,1.6,7.4),1.3,C['wound'],bias=0.8)
    elif P.variant == 0:
        s.ball(U(3.9,2.1,7.8),1.55,C['wound'],bias=0.8)
        s.pixel(head + fU*3.7 + rU*1.0,C['wound'],bias=1.1)
    elif P.variant == 1:
        s.ball(U(3.9,-2.0,5.9),1.35,C['wound'],bias=0.8)
        s.pixel(head + fU*3.6 - rU*0.9,C['wound'],bias=1.1)
    elif P.variant == 2:
        s.ball(pts['elR'] + fU*0.8,1.25,C['wound'],bias=0.8)
        s.ball(U(3.9,1.2,9.0),1.25,C['wound'],bias=0.8)
    else:
        s.ball(pts['kneeL'] + P.f*1.0,1.15,C['wound'],bias=0.6)
        s.ball(U(3.9,-1.3,8.0),1.4,C['wound'],bias=0.8)

    # variant silhouette details
    if P.variant >= EXTRA_BASE:
        pass
    elif P.variant == 0:  # worker shoulder patch / tool pouch
        s.box(U(1.0,5.2,8.4),fU,rU,zU,1.2,0.7,1.8,C['accent'],edge=False)
        s.box(U(0.5,-4.5,2.7),fU,rU,zU,1.6,0.8,1.6,darker(C['accent'],0.8))
    elif P.variant == 1:  # clinic scrub pocket / torn white bandage
        s.box(U(3.95,-2.2,7.4),fU,rU,zU,0.22,1.5,1.1,C['accent'],edge=False)
        s.capsule(pts['elL'],pts['elL']+(pts['wrL']-pts['elL'])*0.28,2.05,1.8,C['accent'],bias=0.4,edge=False)
    elif P.variant == 2:  # civilian jacket lapel / belt pouch
        s.box(U(3.95,0.8,8.3),fU,rU,zU,0.20,1.7,3.1,C['accent'],edge=False)
        s.box(U(0.4,4.4,2.7),fU,rU,zU,1.5,0.9,1.5,C['accent'])
    else:  # militia webbing / small satchel
        s.box(U(3.95,-1.7,8.0),fU,rU,zU,0.20,0.65,4.0,C['accent'],edge=False)
        s.box(U(3.95,1.9,7.3),fU,rU,zU,0.20,0.65,3.3,C['accent'],edge=False)
        s.box(U(-1.2,-5.0,5.0),fU,rU,zU,2.2,1.0,2.7,darker(C['accent'],0.72))

    return s.render()


def render_walk(direction, variant, k):
    return build(walk_pose(direction, variant, k))


def render_attack(direction, variant, k):
    return build(attack_pose(direction, variant, k))


def sheet(kind):
    frames = WALK_FRAMES if kind == 'walk' else ATTACK_FRAMES
    im = Image.new('RGBA',(CELL*frames,CELL*DIRS*VARIANTS),(0,0,0,0))
    for v in range(VARIANTS):  # the four base outfits only
        for d in range(DIRS):
            row=v*DIRS+d
            for k in range(frames):
                fr = render_walk(d,v,k) if kind=='walk' else render_attack(d,v,k)
                im.alpha_composite(fr,(k*CELL,row*CELL))
    return im


def render_sized(variant, fn):
    # a bigger body is drawn with more pixels, feet still on the same ground
    size = VARIANT[variant].get('size', 1.0)
    char3d.K = RENDER_K * size
    char3d.GROUND = (64.0, 64.0 + 28.0 * RENDER_K)
    try:
        return fn()
    finally:
        char3d.set_density(RENDER_K)


def extra_sheet(variant, kind):
    frames = WALK_FRAMES if kind == 'walk' else ATTACK_FRAMES
    im = Image.new('RGBA', (CELL*frames, CELL*DIRS), (0, 0, 0, 0))
    for d in range(DIRS):
        for k in range(frames):
            fr = render_sized(variant, lambda: render_walk(d, variant, k) if kind == 'walk' else render_attack(d, variant, k))
            im.alpha_composite(fr, (k*CELL, d*CELL))
    return im


def build_extra(project, names=None):
    out = os.path.join(project, 'art', 'infected')
    os.makedirs(out, exist_ok=True)
    for i, C in enumerate(EXTRA):
        if names and C['name'] not in names:
            continue
        v = EXTRA_BASE + i
        for kind in ('walk', 'attack'):
            save_png(extra_sheet(v, kind), os.path.join(out, '%s_%s.png' % (C['name'], kind)))


def build_all(project):
    save_png(sheet('walk'),os.path.join(project,'infected_walk_v12.png'))
    save_png(sheet('attack'),os.path.join(project,'infected_attack_v12.png'))
    build_extra(project)


if __name__=='__main__':
    build_all(sys.argv[1])
