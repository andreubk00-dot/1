"""OSTATOK dev73 dog renderer.

A mongrel of the region - a shepherd-sized yard dog with a darker saddle, a
lighter chest and a worn collar - built from the same small 3D rig as the
survivor and the infected (tools/char3d.py) and projected into 128 px 3/4
top-down pixel-art cells, shown at sprite scale 0.5 like them.

Sheets (8 direction rows; direction d faces d*45 degrees, 0 = screen right,
2 = toward the camera), in art/dog/:
    dog_walk.png   12 frames  trot (diagonal legs together)
    dog_run.png     8 frames  gallop
    dog_idle.png    8 frames  standing, breathing, a slow wag
    dog_sit.png     4 frames  sitting (the "wait" command)
    dog_alert.png   4 frames  head low, tail stiff, a tremble (growling)
    dog_lie.png     2 frames  lying on its side (hurt / dead)
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

COAT = (132, 106, 78)
SADDLE = (78, 62, 48)
LIGHT = (184, 162, 128)
CHEST = (160, 136, 104)
NOSE = (28, 24, 22)
COLLAR = (112, 42, 34)
EYE = (20, 18, 16)


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


class Pose:
    def __init__(self, direction):
        a = direction * math.pi / 4.0
        self.f = V(math.cos(a), math.sin(a), 0)
        self.r = V(-math.sin(a), math.cos(a), 0)
        self.z = V(0, 0, 1)
        self.hip_z = 12.0
        self.chest_z = 13.0
        self.half = 5.6            # half the hip-chest distance
        self.pitch = 0.0           # + raises the chest
        self.head = (3.6, 0.0, 6.2)  # head centre from the chest (f, r, z)
        self.head_turn = 0.0
        self.tail = (-0.9, 0.0, 0.55)  # tail direction (f, r, z), normalised
        self.tail_len = 7.5
        self.paws = {
            'FL': (6.2, -2.5, 1.2), 'FR': (6.2, 2.5, 1.2),
            'RL': (-5.6, -2.5, 1.2), 'RR': (-5.6, 2.5, 1.2),
        }
        self.roll = 0.0            # lying on its side
        self.sit = False
        self.ears_back = 0.0

    def L(self, f, r, z):
        return self.f * f + self.r * r + self.z * z


def build(P):
    s = Scene()
    hip = P.L(-P.half, 0, P.hip_z)
    chest = P.L(P.half, 0, P.chest_z)
    if P.pitch:
        mid = (hip + chest) / 2
        hip = rot_about(hip, mid, P.r, P.pitch)
        chest = rot_about(chest, mid, P.r, P.pitch)
    fwd = norm(chest - hip)
    up = norm(np.cross(fwd, P.r))   # body "up", tilted with the pitch
    pts = {}

    def body(f, r, z):
        return chest + fwd * f + P.r * r + up * z

    head = body(P.head[0], P.head[1], P.head[2])
    if P.head_turn:
        head = rot_about(head, chest, P.z, P.head_turn)
    hd = norm(head - chest)
    head_f = norm(V(hd[0], hd[1], 0.0)) if abs(hd[2]) < 0.99 else P.f
    head_r = norm(np.cross(head_f, P.z))
    # legs: front legs fold back at the elbow, hind legs forward at the stifle
    for leg, base, pole in [('FL', body(-0.6, -2.3, -2.6), -P.f), ('FR', body(-0.6, 2.3, -2.6), -P.f),
                            ('RL', hip + P.r * -2.3 + up * -2.0, P.f), ('RR', hip + P.r * 2.3 + up * -2.0, P.f)]:
        pf, pr, pz = P.paws[leg]
        paw = P.L(pf, pr, pz)
        if P.sit and leg in ('RL', 'RR'):
            knee, paw = two_bone(base, paw, 5.0, 5.2, P.f * 1.0 + P.z * 0.6)
        else:
            knee, paw = two_bone(base, paw, 5.6, 5.4, pole + P.z * 0.1)
        pts[leg] = (base, knee, paw)

    def lean(p):
        # lying: roll the whole body onto its side about the ground under it
        if not P.roll:
            return p
        return rot_about(p, P.L(0, 0, 0), P.f, P.roll)

    far_side = lambda leg: float(np.dot(P.r * (-1 if leg.endswith('L') else 1), V(0, 1, 0))) < -0.2
    # far legs first (darker), then the body, then near legs
    for leg in ('FL', 'FR', 'RL', 'RR'):
        if not far_side(leg):
            continue
        b, k, p = (lean(x) for x in pts[leg])
        col = darker(COAT, 0.78)
        s.capsule(b, k, 1.75, 1.35, col)
        s.capsule(k, p, 1.3, 1.05, darker(LIGHT, 0.80))
        s.ball(p, 1.2, darker(LIGHT, 0.74))
    # tail
    tdir = norm(P.L(*P.tail))
    t0 = hip - fwd * 3.6 + up * 1.4
    t1 = t0 + tdir * P.tail_len * 0.55
    t2 = t0 + tdir * P.tail_len + P.z * (0.8 if P.tail[2] > 0.2 else 0.0)
    s.capsule(lean(t0), lean(t1), 1.25, 1.1, COAT)
    s.capsule(lean(t1), lean(t2), 1.1, 0.75, SADDLE)
    # body: rump, barrel, chest; a darker saddle along the back
    s.capsule(lean(hip), lean(chest), 3.9, 4.5, COAT)
    s.capsule(lean(hip + up * 1.9), lean(chest + up * 1.6 - fwd * 0.8), 2.5, 2.7, SADDLE, bias=0.2, edge=False)
    s.ball(lean(chest + fwd * 2.0 - up * 1.6), 2.8, CHEST, bias=0.15)
    if P.sit:
        # folded hind legs: the haunches show beside the rump
        for sg in (-1, 1):
            hc = hip + P.r * (2.4 * sg) + up * 0.6 + fwd * 1.2
            far = float(np.dot(P.r * sg, V(0, 1, 0))) < -0.2
            s.ball(lean(hc), 2.7, darker(COAT, 0.82) if far else COAT, bias=-0.4 if far else 0.35)
    # neck and collar
    neck_a = chest + fwd * 2.0 + up * 1.6
    neck_b = head - up * 1.4 - (head - chest) * 0.1
    s.capsule(lean(neck_a), lean(neck_b), 2.7, 2.2, COAT, bias=0.1)
    s.capsule(lean(neck_a + (neck_b - neck_a) * 0.48 - P.z * 0.2), lean(neck_a + (neck_b - neck_a) * 0.58), 2.8, 2.45, COLLAR, bias=0.25, edge=False)
    # head, muzzle, nose, ears, eyes
    s.ball(lean(head), 3.2, COAT, bias=0.3)
    snout_a = head + head_f * 1.8 - P.z * 0.9
    snout_b = head + head_f * 5.0 - P.z * 1.6
    s.capsule(lean(snout_a), lean(snout_b), 1.75, 1.25, LIGHT, bias=0.4)
    s.ball(lean(snout_b + head_f * 0.5 + P.z * 0.2), 0.95, NOSE, bias=0.7)
    for sg in (-1, 1):
        base = head + head_r * (1.7 * sg) + P.z * 1.9 - head_f * 0.4
        tip = base + P.z * (2.4 - 1.6 * P.ears_back) - head_f * (0.6 + 1.6 * P.ears_back) + head_r * (0.5 * sg)
        s.capsule(lean(base), lean(tip), 1.05, 0.35, SADDLE, bias=0.5, edge=True)
        s.pixel(lean(head + head_f * 2.6 + head_r * (1.25 * sg) + P.z * 0.7), EYE, bias=0.9)
    # near legs over the body
    for leg in ('FL', 'FR', 'RL', 'RR'):
        if far_side(leg):
            continue
        b, k, p = (lean(x) for x in pts[leg])
        s.capsule(b, k, 1.85, 1.4, COAT, bias=0.4)
        s.capsule(k, p, 1.35, 1.1, LIGHT, bias=0.5)
        s.ball(p, 1.25, darker(LIGHT, 0.9), bias=0.6)
    return s.render()


# ------------------------------------------------------------------ poses --
def walk_pose(d, k, frames=12):
    ph = k / float(frames) * math.tau
    P = Pose(d)
    amp, lift = 3.0, 2.1
    for leg, off in (('FL', 0.0), ('RR', 0.0), ('FR', math.pi), ('RL', math.pi)):
        f0, r0, _ = P.paws[leg]
        P.paws[leg] = (f0 + amp * math.sin(ph + off), r0, 1.2 + lift * max(0.0, math.cos(ph + off)))
    P.hip_z += 0.35 * abs(math.sin(ph * 2.0))
    P.chest_z += 0.35 * abs(math.sin(ph * 2.0 + 0.6))
    P.tail = (-0.85, 0.45 * math.sin(ph), 0.5)
    P.head = (3.6, 0.0, 6.0 + 0.3 * math.sin(ph * 2.0))
    return P


def run_pose(d, k, frames=8):
    ph = k / float(frames) * math.tau
    P = Pose(d)
    amp, lift = 5.2, 2.6
    for leg, off in (('FL', 0.0), ('FR', 0.45), ('RL', math.pi), ('RR', math.pi + 0.45)):
        f0, r0, _ = P.paws[leg]
        P.paws[leg] = (f0 + amp * math.sin(ph + off), r0 * 0.8, 1.2 + lift * max(0.0, math.cos(ph + off)))
    # the body stretches and gathers with the stride
    P.half = 5.6 + 1.0 * math.sin(ph)
    P.pitch = 0.12 * math.sin(ph + 0.8)
    P.hip_z += 0.9 * math.sin(ph + math.pi) * 0.5 + 0.4
    P.chest_z += 0.9 * math.sin(ph) * 0.5 + 0.4
    P.tail = (-1.0, 0.0, 0.15)
    P.head = (3.9, 0.0, 5.0)
    P.ears_back = 0.6
    return P


def idle_pose(d, k, frames=8):
    ph = k / float(frames) * math.tau
    P = Pose(d)
    P.chest_z += 0.25 * math.sin(ph)
    P.tail = (-0.8, 0.25 * math.sin(ph), 0.45)
    P.head_turn = 0.10 * math.sin(ph * 0.5)
    return P


def sit_pose(d, k, frames=4):
    ph = k / float(frames) * math.tau
    P = Pose(d)
    P.sit = True
    P.hip_z = 5.2
    P.chest_z = 14.2 + 0.2 * math.sin(ph)
    P.half = 4.2
    P.paws['RL'] = (-2.0, -2.8, 1.2)
    P.paws['RR'] = (-2.0, 2.8, 1.2)
    P.paws['FL'] = (4.6, -2.0, 1.2)
    P.paws['FR'] = (4.6, 2.0, 1.2)
    P.head = (2.6, 0.0, 6.6)
    P.tail = (-0.7, 0.6, -0.1)
    P.tail_len = 6.5
    return P


def alert_pose(d, k, frames=4):
    P = Pose(d)
    tremble = 0.18 * math.sin(k * math.pi)
    P.hip_z = 11.2
    P.chest_z = 10.6 + tremble
    P.paws['FL'] = (7.0, -2.8, 1.2)
    P.paws['FR'] = (7.0, 2.8, 1.2)
    P.head = (4.2, 0.0, 3.4)
    P.tail = (-1.0, 0.0, 0.05)
    P.ears_back = 0.85
    return P


def lie_pose(d, k, frames=2):
    P = Pose(d)
    P.roll = 1.25
    P.hip_z = 6.0
    P.chest_z = 6.2 + 0.25 * k
    P.head = (3.6, 0.0, 2.0)
    for leg in P.paws:
        f0, r0, _ = P.paws[leg]
        P.paws[leg] = (f0 + (1.5 if leg[0] == 'F' else -1.0), r0 * 2.6, 5.0)
    P.tail = (-1.0, 0.0, -0.2)
    return P


ANIMS = [('walk', walk_pose, 12), ('run', run_pose, 8), ('idle', idle_pose, 8),
         ('sit', sit_pose, 4), ('alert', alert_pose, 4), ('lie', lie_pose, 2)]


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
