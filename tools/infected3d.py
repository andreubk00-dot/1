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
    drag_side = VARIANT[variant]['drag']
    # Asymmetrical shambling gait. One leg drags, the other carries more weight.
    base_amp = 5.2
    if variant == 2:
        base_amp = 5.8
    for side, off, sg in [('L', 0.0, -1), ('R', math.pi, 1)]:
        s = math.sin(ph + off)
        lift = max(0.0, math.sin(ph + off))
        amp = base_amp * (0.58 if side == drag_side else 1.0)
        zlift = (1.1 if side == drag_side else 2.8) * lift
        # dragging foot trails slightly behind and turns inward visually
        trail = -1.4 if side == drag_side else 0.0
        P.feet[side] = (0.5 + s*amp + trail, 2.9*sg, 3.0 + zlift)
    P.bob = -0.45*abs(math.sin(ph)) + 0.20*math.sin(ph*2.0)
    P.shift_r = 0.85*math.sin(ph) * (1 if drag_side == 'L' else -1)
    P.twist = 0.08*math.sin(ph + math.pi*0.35)
    P.side_lean = 0.035*math.sin(ph) + (0.025 if drag_side == 'L' else -0.025)
    P.head_tilt += 0.045*math.sin(ph*0.5 + variant)
    # arms mostly hang, with unequal swing and occasional clawing reach
    P.hands['L'] = (3.1 + 1.2*math.sin(ph+math.pi), -5.6, 5.7 + 0.5*math.cos(ph))
    P.hands['R'] = (3.5 + 1.7*math.sin(ph), 5.6, 6.0 + 0.6*math.cos(ph+0.4))
    if variant == 1:
        P.hands['L'] = (4.4 + 0.8*math.sin(ph), -5.2, 7.2)
    elif variant == 3:
        P.hands['R'] = (4.8 + 0.9*math.sin(ph), 5.1, 7.6)
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
        s.capsule(hip,knee,2.5,2.05,pants)
        s.capsule(knee,ankle,2.0,1.6,pants)
        # dirty knee / torn fabric marker
        if (P.variant + (0 if side=='L' else 1)) % 2 == 0:
            s.ball(knee + P.f*1.4 + V(0,0,0.2),1.25,darker(C['pants'],0.58),bias=0.4)
        boot_c = ankle + P.f*1.1 + P.z*(-1.2)
        s.box(boot_c,P.f,P.r,P.z,2.8,1.75,1.45,C['boots'])

    # pelvis and torso
    s.box(U(0,0,1.0),fU,rU,zU,3.2,4.8,2.3,C['pants'])
    s.box(U(0.2,0,7.0),fU,rU,zU,3.7,5.4,5.1,C['top'])
    s.box(U(3.65,0,7.2),fU,rU,zU,0.35,4.8,4.4,C['top2'],edge=False)
    # collar / waist breakup
    s.box(U(3.9,0,10.6),fU,rU,zU,0.30,3.7,0.55,C['accent'],edge=False)
    s.box(U(3.8,0,3.7),fU,rU,zU,0.28,4.5,0.45,darker(C['top2'],0.72),edge=False)

    # arms with torn cuffs and exposed infected skin
    for side, sg in [('L',-1),('R',1)]:
        far = float(np.dot(P.r*sg,V(0,1,0))) < -0.2
        top = darker(C['top'],0.78) if far else C['top']
        el,wr=pts['el'+side],pts['wr'+side]
        s.capsule(sh[side],el,2.35,1.95,top)
        # forearms partly exposed on alternating variants
        expose = ((P.variant + (0 if side=='L' else 1)) % 3) != 0
        fore_col = C['skin'] if expose else top
        s.capsule(el,wr,1.85,1.45,fore_col)
        s.ball(wr,1.7,darker(C['skin'],0.92))

    # neck/head, gaunt and asymmetric
    s.capsule(U(0.4,0,14.0),neck,1.55,1.45,darker(C['skin'],0.90),bias=0.2)
    s.ball(head,4.15,C['skin'],bias=0.4)
    # sunken face and hair/scalp silhouette
    s.ball(head + fU*3.15 + zU*0.15,1.35,darker(C['skin'],0.68),bias=0.8)
    if P.variant != 0:
        s.ball(head - fU*0.5 + zU*2.5,3.1,C['hair'],bias=0.2)
    # wounds by variant
    if P.variant == 0:
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
    if P.variant == 0:  # worker shoulder patch / tool pouch
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
    for v in range(VARIANTS):
        for d in range(DIRS):
            row=v*DIRS+d
            for k in range(frames):
                fr = render_walk(d,v,k) if kind=='walk' else render_attack(d,v,k)
                im.alpha_composite(fr,(k*CELL,row*CELL))
    return im


def build_all(project):
    save_png(sheet('walk'),os.path.join(project,'infected_walk_v12.png'))
    save_png(sheet('attack'),os.path.join(project,'infected_attack_v12.png'))


if __name__=='__main__':
    build_all(sys.argv[1])
