"""OSTATOK dev73 dog renderer (v2).

A shepherd-type yard mongrel - dark saddle and muzzle, tan legs and chest, a
worn red collar - built from the same small 3D rig as the survivor and the
infected (tools/char3d.py) and projected into 128 px 3/4 top-down cells,
shown at sprite scale 0.5 like them.

The rig is a dog's, not a stool's: front legs shoulder - elbow - wrist - paw
(the wrist folds on the swing), hind legs hip - stifle - hock - paw (the hock
points back, the long metatarsus stands near upright), a deep chest and a
tucked waist, a bushy tail that hangs in a sabre and lifts with the mood, a
jaw that opens to bark. Gaits come from one leg cycle (stance / swing) with
per-leg phases: a trot moves the diagonal pairs together, the gallop leads
with the front pair and gathers the hind under the body.

Sheets (8 direction rows; direction d faces d*45 degrees, 0 = screen right,
2 = toward the camera), in art/dog/:
    dog_walk.png   12 frames  trot
    dog_run.png     8 frames  gallop
    dog_idle.png    8 frames  standing, breathing, panting, a slow wag
    dog_sit.png     4 frames  sitting (the "wait" command)
    dog_rest.png    4 frames  lying like a sphinx (a long wait)
    dog_alert.png   4 frames  head low, tail stiff, lips up (growling)
    dog_bark.png    4 frames  a bark: the head snaps up, the jaw opens
    dog_sniff.png   6 frames  nose to the ground (eating, drinking, sniffing)
    dog_lie.png     2 frames  on its side (dead)
"""
import math
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from char3d import Scene, V, norm, CELL, save_png, darker
import char3d

RENDER_K = 1.24
char3d.set_density(RENDER_K)
DIRS = 8
SIZE = 1.12          # a touch larger than life, so it reads beside a man

TAN = (164, 122, 78)
SADDLE = (58, 48, 40)
LIGHT = (196, 164, 118)
CHEST = (180, 146, 104)
MASK = (64, 52, 44)
NOSE = (24, 20, 18)
MOUTH = (70, 30, 30)
TONGUE = (196, 96, 96)
COLLAR = (122, 42, 34)
EYE = (18, 16, 14)
FAR = 0.64           # far-side legs: much darker, so the four never blur


def two_bone(a, target, l1, l2, pole):
    d = target - a
    dist = np.linalg.norm(d)
    dist = max(1e-3, min(dist, l1 + l2 - 0.05))
    dn = norm(d)
    target = a + dn * dist
    ca = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    ca = max(-1.0, min(1.0, ca))
    sa = math.sqrt(max(0.0, 1.0 - ca * ca))
    p = pole - dn * np.dot(pole, dn)
    if np.linalg.norm(p) < 1e-4:
        p = V(0, 0, -1) - dn * dn[2]
    p = norm(p)
    return a + dn * (l1 * ca) + p * (l1 * sa), target


def rot_about(p, origin, axis, ang):
    axis = norm(axis)
    v = p - origin
    c, s = math.cos(ang), math.sin(ang)
    return origin + v * c + np.cross(axis, v) * s + axis * np.dot(axis, v) * (1 - c)


class Sized:
    """The Scene, with every length scaled about the ground origin."""
    def __init__(self, k):
        self.s = Scene()
        self.k = k

    def capsule(self, a, b, ra, rb, col, **kw):
        self.s.capsule(a * self.k, b * self.k, ra * self.k, rb * self.k, col, **kw)

    def ball(self, c, r, col, **kw):
        self.s.ball(c * self.k, r * self.k, col, **kw)

    def pixel(self, p, col, **kw):
        self.s.pixel(p * self.k, col, **kw)

    def render(self):
        return self.s.render()


class Pose:
    def __init__(self, direction):
        a = direction * math.pi / 4.0
        self.f = V(math.cos(a), math.sin(a), 0)
        self.r = V(-math.sin(a), math.cos(a), 0)
        self.z = V(0, 0, 1)
        self.hip_z = 13.0
        self.chest_z = 14.2
        self.half = 5.4            # half the hip-chest distance
        self.pitch = 0.0           # + lowers the chest
        self.head = (3.4, 0.0, 5.8)  # head centre from the chest (f, r, z)
        self.head_turn = 0.0
        self.head_tilt = 0.0       # nose down (+) / up (-)
        self.mouth = 0.0           # jaw open 0..1
        self.tongue = False
        self.tail_lift = 0.0       # -1 tucked .. 0 hanging .. 1 raised
        self.tail_wag = 0.0
        self.paws = {
            'FL': (5.8, -2.3, 0.0), 'FR': (5.8, 2.3, 0.0),
            'RL': (-6.4, -2.3, 0.0), 'RR': (-6.4, 2.3, 0.0),
        }
        self.fold = {'FL': 0.0, 'FR': 0.0, 'RL': 0.0, 'RR': 0.0}   # swing fold 0..1
        self.roll = 0.0            # lying on its side
        self.sit = False
        self.rest = False          # lying like a sphinx
        self.ears_back = 0.0

    def L(self, f, r, z):
        return self.f * f + self.r * r + self.z * z


def build(P):
    s = Sized(SIZE)
    hip = P.L(-P.half, 0, P.hip_z)
    chest = P.L(P.half, 0, P.chest_z)
    if P.pitch:
        mid = (hip + chest) / 2
        hip = rot_about(hip, mid, P.r, P.pitch)
        chest = rot_about(chest, mid, P.r, P.pitch)
    fwd = norm(chest - hip)
    up = norm(np.cross(fwd, P.r))
    waist = hip + (chest - hip) * 0.45 + up * 0.5

    def body(f, r, z):
        return chest + fwd * f + P.r * r + up * z

    head = body(P.head[0], P.head[1], P.head[2])
    if P.head_turn:
        head = rot_about(head, chest, P.z, P.head_turn)
    hd = head - chest
    head_f = norm(V(hd[0], hd[1], 0.0)) if np.linalg.norm(hd[:2]) > 0.3 else P.f
    head_r = norm(np.cross(head_f, P.z))
    # the muzzle points along head_f, tipped down by the tilt
    tilt = 0.32 + P.head_tilt
    muzzle = norm(head_f * math.cos(tilt) - P.z * math.sin(tilt))

    def lean(p):
        if not P.roll:
            return p
        return rot_about(p, P.L(0, 0, 0), P.f, P.roll)

    # ---- legs --------------------------------------------------------------
    legs = {}
    for leg in ('FL', 'FR', 'RL', 'RR'):
        side = -1.0 if leg.endswith('L') else 1.0
        pf, pr, pz = P.paws[leg]
        paw = P.L(pf, pr, pz + 1.0)
        fold = P.fold[leg]
        if leg[0] == 'F':
            top = body(-0.8, 2.1 * side, -1.6)
            # the pastern stands near upright; on the swing the paw flips back
            wrist = paw + P.z * (1.5 - 0.4 * fold) + P.f * (-0.25 + 1.3 * fold)
            elbow, wrist = two_bone(top, wrist, 5.4, 5.0, -P.f + P.z * 0.05)
            legs[leg] = [top, elbow, wrist, paw]
        else:
            top = hip + P.r * (2.2 * side) + up * -0.6
            if P.sit or P.rest:
                # folded: the hock on the ground, the paw ahead of it
                hock = paw + P.f * -2.6 + P.z * 0.2
                stifle, hock = two_bone(top, hock, 4.8, 4.8, P.f + P.z * 0.8)
                legs[leg] = [top, stifle, hock, paw]
            else:
                hock = paw + P.z * (3.3 - 0.8 * fold) + P.f * (-1.1 - 0.9 * fold)
                stifle, hock = two_bone(top, hock, 5.2, 5.2, P.f + P.z * 0.1)
                legs[leg] = [top, stifle, hock, paw]

    far = lambda leg: float(np.dot(P.r * (-1 if leg.endswith('L') else 1), V(0, 1, 0))) < -0.2

    def draw_leg(leg, shade):
        a, b, c, d = (lean(x) for x in legs[leg])
        coat = darker(TAN, shade)
        low = darker(LIGHT, shade)
        bias = -0.3 if shade < 1.0 else 0.4
        if leg[0] == 'R':
            s.capsule(a, b, 2.5, 1.5, coat, bias=bias)        # the haunch
            s.capsule(b, c, 1.35, 1.0, coat, bias=bias)
            s.capsule(c, d, 0.95, 0.85, low, bias=bias + 0.05)
        else:
            s.capsule(a, b, 1.9, 1.35, coat, bias=bias)
            s.capsule(b, c, 1.2, 1.0, low, bias=bias)
            s.capsule(c, d, 0.95, 0.9, low, bias=bias + 0.05)
        s.ball(d + P.f * 0.35, 1.15, darker(LIGHT, shade * 0.92), bias=bias + 0.1)

    for leg in ('FL', 'FR', 'RL', 'RR'):
        if far(leg):
            draw_leg(leg, FAR)

    # ---- tail: a bushy sabre --------------------------------------------------
    lift = P.tail_lift
    t0 = hip - fwd * 3.3 + up * 1.2
    d0 = norm(-fwd * 0.75 + P.z * (-0.65 + 1.15 * lift) + P.r * (0.5 * P.tail_wag))
    d1 = norm(-fwd * 0.5 + P.z * (-0.9 + 1.4 * lift) + P.r * (0.9 * P.tail_wag))
    t1 = t0 + d0 * 3.2
    t2 = t1 + d1 * 3.0
    t3 = t2 + norm(d1 - fwd * 0.4 + P.z * (0.35 if lift > -0.3 else -0.2)) * 2.2
    s.capsule(lean(t0), lean(t1), 1.2, 1.6, TAN)
    s.capsule(lean(t1), lean(t2), 1.6, 1.4, SADDLE)
    s.capsule(lean(t2), lean(t3), 1.3, 0.6, SADDLE)

    # ---- body: rump, tucked waist, deep chest; the dark saddle on top --------
    if P.sit or P.rest:
        for sg in (-1, 1):
            hc = hip + P.r * (2.3 * sg) + up * 0.2 + fwd * 1.0
            fr = float(np.dot(P.r * sg, V(0, 1, 0))) < -0.2
            s.ball(lean(hc), 2.9, darker(TAN, FAR if fr else 1.0), bias=-0.4 if fr else 0.35)
    s.capsule(lean(hip), lean(waist), 3.9, 3.3, TAN)
    s.capsule(lean(waist), lean(chest), 3.3, 4.4, TAN)
    s.ball(lean(chest + fwd * 1.2 - up * 1.2), 3.6, CHEST, bias=0.1)
    s.capsule(lean(hip + up * 2.0 - fwd * 0.4), lean(chest + up * 2.2 - fwd * 1.0), 2.6, 3.0, SADDLE, bias=0.25, edge=False)

    # ---- neck, collar ------------------------------------------------------------
    neck_a = chest + fwd * 1.8 + up * 1.4
    neck_b = head - P.z * 1.2 - head_f * 0.6
    s.capsule(lean(neck_a), lean(neck_b), 2.9, 2.2, TAN, bias=0.1)
    s.capsule(lean(neck_a + (neck_b - neck_a) * 0.2 + up * 1.0), lean(neck_b + P.z * 0.8), 2.0, 1.6, SADDLE, bias=0.15, edge=False)
    cmid = neck_a + (neck_b - neck_a) * 0.55
    s.capsule(lean(cmid - (neck_b - neck_a) * 0.06), lean(cmid + (neck_b - neck_a) * 0.06), 2.55, 2.45, COLLAR, bias=0.3, edge=False)

    # ---- head: skull, muzzle with a dark mask, jaw, nose, ears, eyes ---------------
    s.ball(lean(head), 2.9, TAN, bias=0.3)
    s.ball(lean(head + P.z * 1.1 - head_f * 0.9), 1.6, SADDLE, bias=0.32)
    snout_a = head + muzzle * 1.6 - P.z * 0.2
    snout_b = head + muzzle * 5.0
    s.capsule(lean(snout_a), lean(snout_b), 1.65, 1.05, MASK, bias=0.4)
    if P.mouth > 0.05:
        # the jaw drops: a dark gap, a pink tongue
        jaw_dir = norm(muzzle * math.cos(0.7 * P.mouth) - P.z * math.sin(0.7 * P.mouth))
        jaw_b = snout_a + jaw_dir * 3.2 - P.z * 0.6
        s.capsule(lean(snout_a - P.z * 0.6), lean(jaw_b), 1.1, 0.7, MOUTH, bias=0.38, edge=False)
        s.capsule(lean(snout_a - P.z * 0.9), lean(jaw_b - P.z * 0.2), 0.8, 0.55, MASK, bias=0.37)
    if P.tongue:
        s.capsule(lean(snout_a + muzzle * 1.2 - P.z * 1.0), lean(snout_a + muzzle * 2.2 - P.z * 2.2), 0.6, 0.5, TONGUE, bias=0.36, edge=False)
    s.ball(lean(snout_b + muzzle * 0.45 + P.z * 0.25), 0.9, NOSE, bias=0.7)
    for sg in (-1, 1):
        base = head + head_r * (1.6 * sg) + P.z * 1.9 - head_f * 0.5
        tip = base + P.z * (2.8 - 2.0 * P.ears_back) - head_f * (0.3 + 2.0 * P.ears_back) + head_r * (0.55 * sg)
        s.capsule(lean(base), lean(tip), 1.25, 0.3, SADDLE, bias=0.5, edge=True)
        s.pixel(lean(head + muzzle * 1.9 + head_r * (1.25 * sg) + P.z * 0.85), EYE, bias=0.9)

    for leg in ('FL', 'FR', 'RL', 'RR'):
        if not far(leg):
            draw_leg(leg, 1.0)
    return s.render()


# ------------------------------------------------------------------ gaits --
STANCE = {'FL': 5.8, 'FR': 5.8, 'RL': -6.4, 'RR': -6.4}


def step_leg(P, leg, phase, duty, stride, lift):
    """One leg's place in its cycle: on the ground sliding back for the
    stance, lifted, folded and carried forward for the swing."""
    p = phase % 1.0
    f0, r0, _ = P.paws[leg]
    if p < duty:
        t = p / duty
        df = stride * (0.5 - t)
        z = 0.0
        fold = 0.0
    else:
        t = (p - duty) / (1.0 - duty)
        e = 0.5 - 0.5 * math.cos(math.pi * t)
        df = stride * (-0.5 + e)
        z = lift * math.sin(math.pi * t)
        fold = math.sin(math.pi * min(1.0, t * 1.15))
    P.paws[leg] = (STANCE[leg] + df, r0, z)
    P.fold[leg] = fold


def walk_pose(d, k, frames=12):
    ph = k / float(frames)
    P = Pose(d)
    # a trot: the diagonal pairs move together
    for leg, off in (('FL', 0.0), ('RR', 0.0), ('FR', 0.5), ('RL', 0.5)):
        step_leg(P, leg, ph + off, 0.56, 5.6, 1.9)
    w = math.sin(ph * math.tau * 2.0)
    P.hip_z += 0.3 * w
    P.chest_z += 0.3 * math.sin(ph * math.tau * 2.0 + 0.5)
    P.head = (3.4, 0.0, 5.5 + 0.25 * math.sin(ph * math.tau * 2.0 + 1.0))
    P.head_tilt = 0.08
    P.tail_wag = 0.35 * math.sin(ph * math.tau)
    P.tail_lift = 0.05
    return P


def run_pose(d, k, frames=8):
    ph = k / float(frames)
    P = Pose(d)
    # a gallop: the front pair lands just apart, the hind pair half a beat on
    for leg, off in (('FL', 0.0), ('FR', 0.1), ('RL', 0.5), ('RR', 0.6)):
        step_leg(P, leg, ph + off, 0.38, 8.4, 2.8)
    c = math.sin(ph * math.tau)
    # the spine stretches in the flight, gathers when the hind legs reach under
    P.half = 5.4 + 0.9 * c
    P.pitch = 0.10 * math.sin(ph * math.tau + 1.2)
    P.hip_z += 0.6 + 0.6 * math.sin(ph * math.tau + math.pi)
    P.chest_z += 0.6 + 0.6 * c
    P.head = (3.8, 0.0, 4.6)
    P.head_tilt = 0.05
    P.ears_back = 0.6
    P.tail_lift = 0.25
    P.tongue = True
    P.mouth = 0.25
    return P


def idle_pose(d, k, frames=8):
    ph = k / float(frames) * math.tau
    P = Pose(d)
    P.chest_z += 0.22 * math.sin(ph * 2.0)       # panting breath
    P.tail_wag = 0.4 * math.sin(ph)
    P.tail_lift = -0.1
    P.head_turn = 0.12 * math.sin(ph * 0.5)
    P.mouth = 0.3 + 0.1 * math.sin(ph * 2.0)
    P.tongue = True
    return P


def sit_pose(d, k, frames=4):
    ph = k / float(frames) * math.tau
    P = Pose(d)
    P.sit = True
    P.hip_z = 4.6
    P.chest_z = 14.0 + 0.18 * math.sin(ph)
    P.half = 4.0
    P.paws['RL'] = (-1.4, -2.6, 0.0)
    P.paws['RR'] = (-1.4, 2.6, 0.0)
    P.paws['FL'] = (4.4, -1.9, 0.0)
    P.paws['FR'] = (4.4, 1.9, 0.0)
    P.head = (2.4, 0.0, 6.2)
    P.head_tilt = -0.05
    P.tail_lift = -0.6
    P.tail_wag = 0.2 * math.sin(ph)
    return P


def rest_pose(d, k, frames=4):
    ph = k / float(frames) * math.tau
    P = Pose(d)
    P.rest = True
    P.hip_z = 4.4
    P.chest_z = 5.2 + 0.15 * math.sin(ph)
    P.half = 5.2
    P.paws['RL'] = (-2.4, -3.0, 0.0)
    P.paws['RR'] = (-2.4, 3.0, 0.0)
    # forelegs stretched out in front
    P.paws['FL'] = (11.0, -1.6, 0.0)
    P.paws['FR'] = (11.0, 1.6, 0.0)
    P.fold['FL'] = P.fold['FR'] = 0.0
    P.head = (3.0, 0.0, 4.2)
    P.head_tilt = 0.1
    P.tail_lift = -0.8
    return P


def alert_pose(d, k, frames=4):
    P = Pose(d)
    tremble = 0.16 * math.sin(k * math.pi)
    P.hip_z = 12.6
    P.chest_z = 12.2 + tremble
    P.paws['FL'] = (6.6, -2.6, 0.0)
    P.paws['FR'] = (6.6, 2.6, 0.0)
    P.paws['RL'] = (-7.0, -2.6, 0.0)
    P.paws['RR'] = (-7.0, 2.6, 0.0)
    P.head = (4.2, 0.0, 3.4)
    P.head_tilt = 0.12
    P.mouth = 0.2 if k % 2 else 0.12          # lips up, a snarl
    P.tail_lift = 0.7
    P.ears_back = 0.15
    return P


def bark_pose(d, k, frames=4):
    P = Pose(d)
    # the head snaps up and forward with the bark, the front feet planted
    snap = [0.0, 1.0, 0.6, 0.15][k % 4]
    P.paws['FL'] = (6.6, -2.7, 0.0)
    P.paws['FR'] = (6.6, 2.7, 0.0)
    P.chest_z = 14.0 + 0.5 * snap
    P.hip_z = 12.6
    P.head = (3.8 + 0.6 * snap, 0.0, 5.4 + 0.8 * snap)
    P.head_tilt = 0.05 - 0.35 * snap
    P.mouth = 0.15 + 0.85 * snap
    P.tail_lift = 0.6
    P.tail_wag = 0.15 * snap
    return P


def sniff_pose(d, k, frames=6):
    ph = k / float(frames) * math.tau
    P = Pose(d)
    # nose to the ground, working side to side
    P.pitch = -0.12
    P.chest_z = 12.6
    P.head = (4.6, 0.0, -4.2)
    P.head_turn = 0.18 * math.sin(ph)
    P.head_tilt = 0.75
    P.paws['FL'] = (6.4, -2.4, 0.0)
    P.paws['FR'] = (6.4, 2.4, 0.0)
    P.tail_lift = 0.1
    P.tail_wag = 0.45 * math.sin(ph * 2.0)
    return P


def lie_pose(d, k, frames=2):
    P = Pose(d)
    P.roll = 1.4
    P.hip_z = 4.4
    P.chest_z = 4.6 + 0.2 * k
    P.head = (3.4, 0.0, 1.2)
    P.head_tilt = -0.1
    # the legs stretched out straight; the roll lays them along the ground
    for leg in P.paws:
        f0, r0, _ = P.paws[leg]
        P.paws[leg] = (f0 + (1.8 if leg[0] == 'F' else -0.8), r0, -6.2)
    P.tail_lift = -0.2
    return P


ANIMS = [('walk', walk_pose, 12), ('run', run_pose, 8), ('idle', idle_pose, 8),
         ('sit', sit_pose, 4), ('rest', rest_pose, 4), ('alert', alert_pose, 4),
         ('bark', bark_pose, 4), ('sniff', sniff_pose, 6), ('lie', lie_pose, 2)]


def sheet(fn, frames):
    im = Image.new('RGBA', (CELL * frames, CELL * DIRS), (0, 0, 0, 0))
    for d in range(DIRS):
        for k in range(frames):
            im.alpha_composite(build(fn(d, k, frames)), (k * CELL, d * CELL))
    return im


def build_all(project):
    out = os.path.join(project, 'art', 'dog')
    os.makedirs(out, exist_ok=True)
    for name, fn, frames in ANIMS:
        save_png(sheet(fn, frames), os.path.join(out, 'dog_%s.png' % name))


if __name__ == '__main__':
    build_all(sys.argv[1] if len(sys.argv) > 1 else '.')
