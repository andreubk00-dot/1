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

# ---------------------------------------------------------------- outfits --
# dev63: marauders are drawn on the same rig with their own clothes. An outfit
# swaps the palette and a few gear switches; the survivor is OUTFITS['survivor'].
HEADGEAR = 'helmet'      # helmet | cap | beanie | balaclava | hair | bun | scarf | ushanka
PACK_ON = True
KNEEPADS = True
STRIPES = None           # tracksuit stripe colour, or None
VEST = None              # plate carrier colour, or None
BEARD_ON = True
CAPC = (40, 40, 42)
# dev78: settlement people - a long coat, an apron, bare hair, no belt kit
HAIR = (70, 52, 38)
COAT = None              # long coat / dress colour, or None
APRON = None             # apron colour, or None
KIT = True               # belt pouch and canteen
ARMBAND = None           # armband colour on the left sleeve, or None

OUTFITS = {
    'survivor': {},
    # a tracksuit, a knitted hat and nothing on the back: the district's own
    'gopnik': dict(JACKET=(42, 46, 72), JACKET_D=(32, 35, 56), JEANS=(38, 40, 56), JEANS_D=(30, 32, 44),
                   BOOTS=(40, 40, 42), SKIN=(196, 150, 116), BEARD=(70, 54, 40), HEADGEAR='beanie',
                   CAPC=(34, 34, 36), PACK_ON=False, KNEEPADS=False, STRIPES=(206, 206, 196), BEARD_ON=False,
                   GLOVE=(52, 46, 40), POUCH=(60, 58, 54), CANTEEN=(70, 72, 70)),
    # a black leather jacket, brown work trousers, the face under a balaclava
    'bandit': dict(JACKET=(48, 44, 42), JACKET_D=(34, 31, 30), JEANS=(84, 70, 54), JEANS_D=(66, 54, 42),
                   BOOTS=(42, 32, 26), SKIN=(186, 140, 108), HEADGEAR='balaclava', CAPC=(30, 30, 32),
                   PACK=(70, 66, 58), PACK_D=(54, 50, 44), ROLL=(60, 58, 52), KNEEPADS=False, BEARD_ON=False),
    # an army deserter: faded flora camo, helmet and a plate carrier
    'deserter': dict(JACKET=(104, 92, 64), JACKET_D=(82, 72, 50), JEANS=(66, 68, 50), JEANS_D=(52, 54, 40),
                     BOOTS=(34, 30, 26), SKIN=(190, 146, 112), HELMET=(66, 70, 66), VEST=(40, 42, 40),
                     PACK=(70, 72, 56), PACK_D=(54, 56, 44), ROLL=(84, 76, 56), BEARD=(64, 50, 38)),
}

# dev78: the settlements' named people, each in their own clothes
def _civ(**kw):
    base = dict(PACK_ON=False, KNEEPADS=False, KIT=False, BEARD_ON=False, HEADGEAR='hair',
                GLOVE=(184, 140, 106), GAITER=(92, 84, 72))
    base.update(kw)
    return base


NPC_OUTFITS = {
    'perron_steward': _civ(HEADGEAR='scarf', CAPC=(122, 50, 44), JACKET=(78, 70, 62), JACKET_D=(62, 55, 48),
                           COAT=(84, 74, 64), JEANS=(52, 48, 46), JEANS_D=(42, 38, 36), BOOTS=(44, 36, 30),
                           SKIN=(204, 160, 128), GAITER=(150, 136, 110)),
    'perron_trader': _civ(HEADGEAR='cap', CAPC=(66, 56, 42), JACKET=(74, 80, 66), JACKET_D=(58, 63, 52),
                          APRON=(124, 104, 78), BEARD_ON=True, BEARD=(150, 76, 36), JEANS=(60, 58, 52),
                          JEANS_D=(48, 46, 42), KIT=True, POUCH=(110, 92, 64)),
    'perron_cook': _civ(HEADGEAR='scarf', CAPC=(214, 208, 194), JACKET=(92, 100, 118), JACKET_D=(74, 80, 96),
                        COAT=(96, 104, 122), APRON=(216, 210, 198), JEANS=(62, 60, 64), JEANS_D=(50, 48, 52),
                        SKIN=(208, 162, 130)),
    'perron_radio': _civ(HEADGEAR='hair', HAIR=(66, 50, 34), JACKET=(62, 84, 102), JACKET_D=(48, 66, 82),
                         JEANS=(56, 64, 84), PACK_ON=True, PACK=(70, 74, 70), PACK_D=(56, 58, 56), ROLL=(60, 64, 62)),
    'rubezh_commander': _civ(HEADGEAR='cap', CAPC=(66, 74, 54), JACKET=(84, 92, 64), JACKET_D=(66, 72, 50),
                             JEANS=(70, 74, 54), JEANS_D=(56, 60, 44), BOOTS=(30, 28, 26), KIT=True,
                             ARMBAND=(150, 46, 40), GLOVE=(46, 44, 40)),
    'rubezh_armorer': _civ(HEADGEAR='beanie', CAPC=(34, 34, 36), JACKET=(60, 62, 56), JACKET_D=(46, 48, 44),
                           APRON=(96, 72, 50), BEARD_ON=True, BEARD=(70, 58, 46), JEANS=(56, 54, 48), KIT=True),
    'rubezh_quartermaster': _civ(HEADGEAR='ushanka', CAPC=(84, 70, 54), JACKET=(76, 80, 62), JACKET_D=(60, 64, 48),
                                 JEANS=(66, 68, 52), PACK_ON=True, KIT=True, BEARD_ON=True, BEARD=(96, 84, 70),
                                 ARMBAND=(150, 46, 40)),
    'rubezh_dispatch': _civ(HEADGEAR='bun', HAIR=(98, 64, 40), JACKET=(90, 96, 72), JACKET_D=(72, 76, 56),
                            JEANS=(66, 70, 54), JEANS_D=(52, 56, 42), SKIN=(206, 162, 130), ARMBAND=(150, 46, 40)),
    'mechanics_master': _civ(HEADGEAR='cap', CAPC=(40, 52, 74), JACKET=(54, 70, 102), JACKET_D=(42, 54, 80),
                             JEANS=(52, 66, 96), JEANS_D=(40, 52, 76), BEARD_ON=True, BEARD=(134, 130, 124),
                             KIT=True, POUCH=(80, 70, 52), GLOVE=(46, 44, 40)),
    'mechanics_trader': _civ(HEADGEAR='bun', HAIR=(146, 72, 38), JACKET=(66, 80, 106), JACKET_D=(52, 64, 86),
                             APRON=(92, 86, 74), JEANS=(54, 64, 88), SKIN=(208, 164, 132)),
    'mechanics_electrician': _civ(HEADGEAR='helmet', HELMET=(196, 140, 40), JACKET=(70, 82, 98), JACKET_D=(54, 64, 78),
                                  JEANS=(58, 68, 90), KIT=True, POUCH=(70, 60, 44), GLOVE=(46, 44, 40)),
    'mechanics_storekeeper': _civ(HEADGEAR='beanie', CAPC=(84, 34, 32), JACKET=(52, 46, 42), JACKET_D=(38, 34, 32),
                                  JEANS=(60, 56, 50), BEARD_ON=True, BEARD=(52, 42, 34), KIT=True),
    'lazaret_doctor': _civ(HEADGEAR='bun', HAIR=(168, 148, 110), JACKET=(208, 210, 204), JACKET_D=(176, 180, 174),
                           COAT=(214, 216, 210), JEANS=(52, 52, 58), JEANS_D=(42, 42, 48), BOOTS=(40, 38, 38),
                           SKIN=(210, 168, 138), GAITER=(170, 176, 170)),
    'lazaret_supplier': _civ(HEADGEAR='beanie', CAPC=(50, 56, 60), JACKET=(78, 86, 74), JACKET_D=(62, 68, 58),
                             JEANS=(58, 62, 66), PACK_ON=True, KIT=True, BEARD_ON=True, BEARD=(40, 32, 26),
                             SKIN=(176, 132, 100)),
    'lazaret_nurse': _civ(HEADGEAR='scarf', CAPC=(226, 226, 220), JACKET=(150, 170, 176), JACKET_D=(124, 142, 148),
                          COAT=(156, 176, 182), JEANS=(62, 62, 68), SKIN=(206, 162, 132), ARMBAND=(190, 50, 44)),
    'lazaret_researcher': _civ(HEADGEAR='hair', HAIR=(92, 82, 72), JACKET=(200, 204, 198), JACKET_D=(168, 172, 166),
                               COAT=(206, 210, 204), JEANS=(64, 62, 58), GAITER=(90, 96, 104)),
    # people of no name: a faction's rank and file, for the passing survivors
    'resident_a': _civ(HEADGEAR='beanie', CAPC=(70, 62, 52), JACKET=(86, 78, 62), JACKET_D=(68, 62, 48),
                       JEANS=(56, 60, 72), PACK_ON=True, BEARD_ON=True, BEARD=(80, 62, 46)),
    'resident_b': _civ(HEADGEAR='scarf', CAPC=(88, 90, 110), JACKET=(96, 76, 66), JACKET_D=(76, 60, 52),
                       COAT=(100, 80, 70), JEANS=(54, 50, 50), SKIN=(204, 160, 128)),
}
OUTFITS.update(NPC_OUTFITS)
_OUTFIT_DEFAULTS = {}


def apply_outfit(name):
    g = globals()
    if not _OUTFIT_DEFAULTS:
        for k in ('JACKET', 'JACKET_D', 'JEANS', 'JEANS_D', 'BOOTS', 'SKIN', 'BEARD', 'HELMET', 'PACK', 'PACK_D',
                  'ROLL', 'GLOVE', 'POUCH', 'CANTEEN', 'HEADGEAR', 'PACK_ON', 'KNEEPADS', 'STRIPES', 'VEST',
                  'BEARD_ON', 'CAPC', 'HAIR', 'COAT', 'APRON', 'KIT', 'ARMBAND', 'GAITER'):
            _OUTFIT_DEFAULTS[k] = g[k]
    for k, v in _OUTFIT_DEFAULTS.items():
        g[k] = v
    for k, v in OUTFITS[name].items():
        g[k] = v


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
         'StrafeLeftAttack', 'StrafeRight', 'StrafeRightAttack', 'TakeDamage', 'Taunt', 'Walk',
         'Pickup', 'Use', 'Jog']
MOVE_CLIPS = ('Walk', 'Jog', 'Run', 'RunBackwards', 'StrafeLeft', 'StrafeRight', 'CrouchRun')
# dev77: firing on the move - the same step cycle with the gun held up; the
# game plays them by the stride like any walk (it used to run a whole step
# cycle per shot off the recoil timer) and draws the muzzle flash itself
MOVE_ATTACK_CLIPS = ('RunAttack', 'RunBackwardsAttack', 'StrafeLeftAttack', 'StrafeRightAttack')


def frame_count(clip):
    # 1.38 dev77: smoother - a step cycle in 16 frames (was 12), breathing and
    # the fall in 12 (was 8); the game reads the count from the sheet width
    if clip in MOVE_CLIPS or clip in MOVE_ATTACK_CLIPS:
        return 16
    if clip in ('Idle', 'Idle2', 'Idle3', 'CrouchIdle', 'Die'):
        return 12
    if clip == 'Pickup':
        return 10
    return 8


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
# thigh, shin. 1.38 dev74: a touch shorter than the pelvis height asks (the
# old 9.2 + 9.0 left the knees bent even standing, and the walk's dip made it
# a squat-walk); now the leg is near straight at mid-stance and flexes at the
# heel-strike and in the swing, as a man's does
# the survivor's own proportions (dev82 tried human-length legs - rejected:
# the figure lost its look); pelvis heights below follow LEG through LEG_K
LEG = (8.9, 8.7)
LEG_K = (LEG[0] + LEG[1]) / 17.6          # against the old legs (8.9 + 8.7)
PELVIS_Z = 3.4 + LEG[0] + LEG[1]          # standing pelvis height (was 21.0)


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
        self.pelvis_z = PELVIS_Z
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
        # dev60 secondary motion: the pack and bedroll trail the torso on a
        # spring, the head steadies the gaze against the shoulder swing
        self.pack = (0.0, 0.0, 0.0)          # (f, r, z) lag of the backpack
        self.head_yaw = 0.0
        self.head_dz = 0.0

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
        knee, ankle = two_bone(hip, ankle, LEG[0], LEG[1], P.f * 1.0 + P.z * 0.1)
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
        hands.setdefault('L', U(0.8, -7.3, -0.6))
        hands.setdefault('R', U(0.8, 7.3, -0.6))

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
        if KNEEPADS:
            s.ball(knee + kfront * 1.8 + V(0, 0, 0.2), 1.3, KNEEPAD, bias=0.6)
        if STRIPES:
            s.capsule(hip + P.r * (2.3 * sg), ankle + P.r * (1.6 * sg) + V(0, 0, 1.0), 0.45, 0.4, STRIPES, edge=False)
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
    if KIT:
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
        if PACK_ON:
            s.box(U(3.9, 3.5 * sg, 12.9), fU, rU, zU, 0.2, 0.75, 1.3, PACK_D, edge=False)      # pack strap
            s.pixel(U(4.1, 3.5 * sg, 12.0), BRASS, bias=0.2)                                  # strap buckle
    if COAT:
        # the coat's skirt hangs from the waist to below the knee, flaring out
        cc = []
        for i in range(8):
            top = i & 4
            wr_ = 5.55 if top else 6.4
            dp = 3.6 if top else 4.1
            zz = 5.0 if top else -7.4 * LEG_K
            cc.append(U((dp if i & 1 else -dp), (wr_ if i & 2 else -wr_), zz))
        s.block(cc, COAT)
        s.box(U(0.0, 0, -7.2 * LEG_K), fU, rU, zU, 4.15, 6.45, 0.4, darker(COAT, 0.78), edge=False)   # hem
        s.box(U(3.95, 0, -1.0), fU, rU, zU, 0.12, 0.25, 6.0, darker(COAT, 0.72), edge=False)  # front edge
    else:
        s.box(U(0.0, 0, 4.5), fU, rU, zU, 3.55, 5.45, 0.55, JACKET_D, edge=False)       # hem
    if APRON:
        bottom = -6.0 * LEG_K if COAT else -2.0
        s.box(U(3.9 if not COAT else 4.25, 0, (11.0 + bottom) * 0.5), fU, rU, zU, 0.15, 3.5, (11.0 - bottom) * 0.5, APRON, edge=False)
        s.box(U(3.75, 0, 11.4), fU, rU, zU, 0.15, 2.4, 0.4, darker(APRON, 0.8), edge=False)
    # collar + neck gaiter
    s.box(U(0.3, 0, 14.5), fU, rU, zU, 2.8, 3.4, 0.95, JACKET_D, edge=False)
    if VEST:
        # plate carrier: front and back plates, a row of mag pouches
        s.box(U(0.2, 0, 9.4), fU, rU, zU, 4.05, 5.0, 4.0, VEST)
        for r in (-2.6, 0.0, 2.6):
            s.box(U(4.15, r, 8.0), fU, rU, zU, 0.6, 1.1, 1.5, darker(VEST, 0.8))
    if STRIPES:
        for sg in (-1, 1):
            s.box(U(3.7, 4.6 * sg, 9.0), fU, rU, zU, 0.15, 0.35, 4.6, STRIPES, edge=False)
    # backpack: body, lid, side pockets, front pocket, bedroll with straps
    if PACK_ON:
        pf, pr, pzl = P.pack

        def PK(f, r, z, k=1.0):
            # the load hangs on the straps: lower parts swing further than the lid
            return U(f + pf * k, r + pr * k, z + pzl * k)
        s.box(PK(-6.1, 0, 8.6), fU, rU, zU, 2.7, 4.9, 5.9, PACK)
        # (the parts move together: pockets and bedroll ride the pack, not on their own)
        s.box(PK(-6.3, 0, 13.6, 0.9), fU, rU, zU, 2.9, 5.0, 1.3, darker(PACK, 1.1))
        for sg in (-1, 1):
            s.box(PK(-6.0, 5.5 * sg, 6.4, 1.05), fU, rU, zU, 1.8, 0.8, 2.8, PACK_D)
        s.box(PK(-8.95, 0, 6.8, 1.05), fU, rU, zU, 0.5, 3.3, 2.9, PACK_D, edge=False)
        s.box(PK(-9.25, 0, 8.6, 1.05), fU, rU, zU, 0.25, 3.4, 0.5, darker(PACK_D, 0.8), edge=False)
        s.pixel(PK(-9.5, 0, 7.4, 1.05), BRASS, bias=0.3)
        s.capsule(PK(-6.0, -5.8, 15.6, 1.1), PK(-6.0, 5.8, 15.6, 1.1), 1.8, 1.8, ROLL)
        for sg in (-1, 1):
            s.box(PK(-6.0, 3.6 * sg, 15.6, 1.1), fU, rU, zU, 1.9, 0.35, 1.9, BELT, edge=False)
    # head frame: it turns against the shoulders to keep the gaze steady
    fH = norm(rot_about(fU, V(0, 0, 0), zU, P.head_yaw)) if P.head_yaw else fU
    rH = norm(rot_about(rU, V(0, 0, 0), zU, P.head_yaw)) if P.head_yaw else rU
    head = head + zU * P.head_dz
    # neck + gaiter
    s.capsule(neck, head - zU * 3.2, 1.7, 1.6, SKIN, edge=False)
    s.capsule(neck + zU * 0.2, neck + zU * 1.5, 2.3, 2.1, GAITER, bias=0.1)
    # head: ears, face, nose, brows, beard, moustache
    masked = HEADGEAR == 'balaclava'
    s.ball(head, 4.4, CAPC if masked else SKIN)
    for sg in (-1, 1):
        ear = head + rH * (4.2 * sg) + zU * -0.6 - fH * 0.3
        s.ball(ear, 1.0, darker(CAPC if masked else SKIN, 0.9), bias=-0.2 if np.dot(rH * sg, V(0, 1, 0.55)) < 0 else 0.3)
    face_vis = np.dot(fH, V(0, 1, 0.55)) + 0.35
    if face_vis > 0:
        if masked:
            # the eye slit: a band of skin across the knitted mask
            s.box(head + fH * 3.95 + zU * 0.7, fH, rH, zU, 0.3, 2.6, 0.75, SKIN, edge=False)
        elif BEARD_ON:
            s.ball(head + fH * 2.7 + zU * -2.9, 2.3, BEARD, bias=0.8)
            for sg in (-1, 1):
                s.ball(head + fH * 2.2 + rH * 2.6 * sg + zU * -1.6, 1.3, BEARD, bias=0.7)   # jaw beard
            s.box(head + fH * 3.9 + zU * -1.0, fH, rH, zU, 0.3, 1.3, 0.4, (104, 76, 54), edge=False)
        else:
            s.box(head + fH * 3.95 + zU * -1.6, fH, rH, zU, 0.25, 1.1, 0.25, darker(SKIN, 0.72), edge=False)   # mouth
        if not masked:
            s.box(head + fH * 4.2 + zU * 0.0, fH, rH, zU, 0.35, 0.45, 0.7, NOSE, edge=False)
        for sg in (-1, 1):
            n = norm(fH * 0.9 + rH * 0.45 * sg)
            if np.dot(n, V(0, 1, 0.55)) > 0.05:
                s.pixel(head + fH * 4.1 + rH * (1.6 * sg) + zU * 0.6, EYE, bias=1.2)
                s.box(head + fH * 4.05 + rH * (1.7 * sg) + zU * 1.45, fH, rH, zU, 0.2, 0.8, 0.22, (70, 52, 38), edge=False)
    hc = head + zU * 1.9 - fH * 0.4
    if HEADGEAR == 'helmet':
        # helmet: dome, band, brim, goggles, chin strap
        s.box(hc + zU * 0.6, fH, rH, zU, 4.6, 4.6, 1.9, HELMET)
        s.ball(hc + zU * 1.9, 4.2, HELMET, bias=1.0)
        s.box(hc + zU * -1.0 + fH * 0.4, fH, rH, zU, 5.0, 5.0, 0.45, (60, 66, 48), edge=False)
        s.box(hc + zU * 0.1, fH, rH, zU, 4.75, 4.75, 0.35, darker(HELMET, 0.8), edge=False)  # cover band
        s.box(hc + fH * 4.3 + zU * 1.0, fH, rH, zU, 0.5, 2.6, 0.75, GOGGLE, edge=False)
        for sg in (-1, 1):
            s.pixel(hc + fH * 4.9 + rH * 1.2 * sg + zU * 1.1, LENS, bias=0.4)
            s.capsule(hc + rH * 4.3 * sg + zU * -1.2, head + rH * 3.2 * sg + fH * 1.2 + zU * -3.6, 0.35, 0.35,
                      (52, 46, 36), bias=0.5, edge=False)
    elif HEADGEAR == 'beanie':
        # a knitted hat pulled low, the turned-up band
        s.ball(head + zU * 1.5 - fH * 0.3, 4.35, CAPC, bias=0.6)
        s.box(head + zU * 0.6 - fH * 0.2, fH, rH, zU, 4.45, 4.45, 0.7, darker(CAPC, 1.25), edge=False)
    elif HEADGEAR == 'balaclava':
        # the mask's crown and a seam down the back
        s.ball(head + zU * 1.2 - fH * 0.4, 4.0, darker(CAPC, 1.1), bias=0.6)
    elif HEADGEAR == 'cap':
        s.ball(head + zU * 1.4 - fH * 0.2, 4.3, CAPC, bias=0.6)
        s.box(head + zU * 1.0 + fH * 4.3, fH, rH, zU, 1.8, 3.2, 0.3, darker(CAPC, 0.8), edge=False)
    elif HEADGEAR in ('hair', 'bun'):
        # bare head: the hair sits back off the brow
        s.ball(head + zU * 1.3 - fH * 0.75, 4.35, HAIR, bias=0.6)
        if HEADGEAR == 'bun':
            s.ball(head - fH * 4.0 + zU * 1.6, 1.9, darker(HAIR, 0.9), bias=0.5)
    elif HEADGEAR == 'scarf':
        # a headscarf over the crown, tied under the chin, the ends down the back
        s.ball(head + zU * 1.1 - fH * 0.55, 4.75, CAPC, bias=0.6)
        s.box(head + zU * 2.4 + fH * 2.9, fH, rH, zU, 0.6, 3.6, 0.45, darker(CAPC, 0.85), edge=False)
        s.ball(head + fH * 2.4 + zU * -4.3, 1.1, darker(CAPC, 0.85), bias=0.5)
        s.ball(head - fH * 3.4 + zU * -2.6, 2.3, darker(CAPC, 0.92), bias=0.3)
    elif HEADGEAR == 'ushanka':
        # a fur hat, the ear flaps down
        s.ball(head + zU * 1.9 - fH * 0.2, 4.7, CAPC, bias=0.7)
        s.box(head + zU * 1.3 + fH * 3.9, fH, rH, zU, 0.9, 4.2, 1.1, darker(CAPC, 1.12), edge=False)
        for sg in (-1, 1):
            s.ball(head + rH * 4.4 * sg + zU * -0.9 - fH * 0.3, 1.9, darker(CAPC, 1.08), bias=0.4)

    # arms: rounded sleeves, elbow patch, cuff, fingerless gloves
    for side, sg in (('L', -1), ('R', 1)):
        el, wr = pts['el' + side], pts['wr' + side]
        # sleeves a shade off the body so the arm reads against the chest
        JK = darker(JACKET, 0.72) if far(rU * sg) else darker(JACKET, 0.88)
        s.capsule(sh[side], el, 2.35, 2.05, JK)
        s.ball(sh[side] + zU * 0.4, 2.3, JK, bias=0.1)                                     # shoulder cap
        s.capsule(el, wr, 2.0, 1.65, JK)
        if STRIPES:
            s.capsule(sh[side] + rU * (1.9 * sg), el + rU * (1.5 * sg), 0.4, 0.4, STRIPES, edge=False)
        s.ball(el, 1.45, JACKET_D, bias=0.2)                                               # elbow patch
        if ARMBAND and side == 'L':
            s.capsule(sh[side] + norm(el - sh[side]) * 1.6, sh[side] + norm(el - sh[side]) * 3.4, 2.45, 2.4, ARMBAND, bias=0.2, edge=False)
        s.capsule(wr - norm(wr - el) * 1.4, wr - norm(wr - el) * 0.3, 1.8, 1.8, JACKET_D, bias=0.1, edge=False)
        hand = wr + norm(wr - el) * 0.9
        s.ball(hand, 1.9, GLOVE, bias=0.4)
        s.ball(hand + norm(wr - el) * 1.0, 1.15, SKIN, bias=0.5)                             # fingers

    # weapon
    if gun:
        g, G, gu, gv, gw = gun
        for (u0, u1, w0, w1, hv, col) in g['parts']:
            c = G + gu * ((u0 + u1) / 2) + gw * ((w0 + w1) / 2)
            s.box(c, gu, gv, gw, (u1 - u0) / 2, hv, (w1 - w0) / 2, col, edge=(u1 - u0) > 2.5)
        if g['muzzle']:
            # where the muzzle lands in the cell (the game's moving-shot flash)
            import char3d as _c3
            mz = G + gu * g['muzzle'] + gw * g['muzzle_w']
            LAST_MUZZLE[0] = (_c3.proj(mz), _c3.proj(mz + gu))
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
    # 1.38 dev75: the weight shift and the shoulder twist are a third of
    # what they were - walking toward or away from the camera the head swung
    # almost four texels side to side every stride and the figure rocked
    # dev81: the walk is only the raiders' patrol now (the survivor jogs);
    # longer steps on a softer knee - see WALK_DROP
    'walk': dict(S=0.58, A=8.8,
                 swing=[(0.0, -1.0, 1.3, -0.6), (0.34, -0.45, 3.0, -0.3), (0.7, 0.55, 2.0, 0.1), (1.0, 1.0, 0.0, 0.4)],
                 stance=[(0.0, 0.4), (0.16, 0.0), (0.66, 0.0), (1.0, -0.65)],
                 heel=1.8, bob=0.62, hip=0.85, twist=0.08, shift=0.22, lean=0.04),
    'run': dict(S=0.36, A=7.8,
                swing=[(0.0, -0.8, 2.8, -0.8), (0.3, -1.1, 9.4, -0.95), (0.62, 0.4, 7.6, 0.0), (1.0, 0.6, 0.0, 0.2)],
                stance=[(0.0, 0.2), (0.25, 0.0), (0.7, -0.1), (1.0, -0.8)],
                heel=2.6, bob=1.85, hip=1.05, twist=0.15, shift=0.2, lean=0.3),
    # dev81: the knees bent low reach far - a crouching step twice as long
    # (it was 9 px a cycle against the game's 72: the feet skated)
    'crouch': dict(S=0.6, A=11.0,
                   swing=[(0.0, -1.0, 1.0, -0.5), (0.4, -0.4, 2.8, -0.3), (1.0, 1.0, 0.0, 0.2)],
                   stance=[(0.0, 0.2), (0.2, 0.0), (0.7, 0.0), (1.0, -0.5)],
                   heel=1.0, bob=0.5, hip=0.5, twist=0.06, shift=0.4, lean=0.3),
}


# ------------------------------------------------------------ dev81 run --
# A run built from running biomechanics instead of a sped-up walk:
#   * a stance of a quarter to a third of the cycle (32-38 % at a jog, falling
#     with speed) and a flight between the steps - both feet off the ground;
#   * the planted foot slides back under the body at one constant speed - the
#     speed the game moves the survivor at (tools: stride table, see
#     write_gait_strides), so a foot never skates;
#   * the swing: toe-off far behind, the heel kicked up toward the seat, the
#     knee driven forward and up, the shin thrown out ahead, then pawed back so
#     the foot meets the ground at the ground's own speed - one smooth curve
#     (Hermite through the keys, velocities matched at both ends: no pop);
#   * the body lowest at mid-stance, highest mid-flight (about 4 % of height),
#     the pelvis carried low and the trunk leaning forward 5-9 degrees, the
#     arms bent and driving against the legs.
# Leg length bounds the step: Lf / Lb (ankle ahead of / behind the hip at
# contact / toe-off) are the longest the rig's short legs reach with the knee
# still bent at contact; check_reach() guards it.
RUN_GAITS = {
    # the longest steps the survivor's legs reach; the knee lift and heel kick
    # are a runner's, not a sprinter-cartoon's (dev82: lower than dev81)
    # dev82 review: the upper body swings with the legs (shoulders against
    # the hips, a sway over each planted foot), the trailing foot leaves the
    # ground at once (a flight, not a lunge), the heel kick is eased; the
    # sprint leans in and plants under the hips, not out in front
    'jog': dict(S=0.31, Lf=6.4, Lb=10.2, drop=1.7, B=0.72, kick=5.2, knee=4.8, reach=0.3,
                lean=0.09, hip=1.1, twist=0.15, shift=0.15, heel=2.6, arms=3.6, lift=2.6, land=3.5),
    'sprint': dict(S=0.26, Lf=5.6, Lb=12.0, drop=2.1, B=0.7, kick=8.0, knee=6.8, reach=0.3,
                   lean=0.27, hip=1.3, twist=0.17, shift=0.12, heel=3.0, arms=4.6, lift=3.2, land=3.6),
}
# running backwards or sideways the steps are shorter (the legs cannot
# reach as far behind or across)
BACK_AMP = 0.9
STRAFE_AMP = 0.8
RUN_STANCE_PITCH = [(0.0, 0.12), (0.25, 0.0), (0.6, -0.08), (1.0, -0.85)]
RUN_SWING_PITCH = [(0.0, -0.85), (0.3, -1.05), (0.62, -0.25), (0.86, 0.18), (1.0, 0.12)]


def _hermite(keys, x, d0, d1):
    """keys [(s, a, b)] with s ascending 0..1; Catmull-Rom tangents inside,
    d0 / d1 the (da, db) tangents at the ends. Returns (a, b)."""
    n = len(keys)
    tang = []
    for i in range(n):
        if i == 0:
            tang.append(d0)
        elif i == n - 1:
            tang.append(d1)
        else:
            s0, a0, b0 = keys[i - 1]
            s2, a2, b2 = keys[i + 1]
            ds = s2 - s0
            tang.append(((a2 - a0) / ds, (b2 - b0) / ds))
    for i in range(n - 1):
        s0, a0, b0 = keys[i]
        s1, a1, b1 = keys[i + 1]
        if x <= s1 or i == n - 2:
            h = s1 - s0
            u = min(1.0, max(0.0, (x - s0) / h))
            h00 = 2 * u ** 3 - 3 * u ** 2 + 1
            h10 = u ** 3 - 2 * u ** 2 + u
            h01 = -2 * u ** 3 + 3 * u ** 2
            h11 = u ** 3 - u ** 2
            ta0, tb0 = tang[i]
            ta1, tb1 = tang[i + 1]
            return (h00 * a0 + h10 * h * ta0 + h01 * a1 + h11 * h * ta1,
                    h00 * b0 + h10 * h * tb0 + h01 * b1 + h11 * h * tb1)
    return keys[-1][1:]


def run_foot(g, phi, amp=1.0):
    """(forward, height) of an ankle at foot phase phi (0 = contact)."""
    S = g['S']
    Lf, Lb = g['Lf'] * amp, g['Lb'] * amp
    if phi < S:
        u = phi / S
        o = Lf - (Lf + Lb) * u
        z = 3.0 + g['heel'] * smooth((u - 0.55) / 0.45) if u > 0.55 else 3.0
        return o, z, keyinterp(RUN_STANCE_PITCH, u)[0]
    sw = (phi - S) / (1.0 - S)
    v = -(Lf + Lb) / S * (1.0 - S)            # ground speed in swing-phase units
    keys = [(0.0, -Lb, 3.0 + g['heel']),
            (0.1, -Lb * 0.95, 3.0 + g['heel'] + g['lift']),
            (0.3, -Lb * 0.68, 3.0 + g['kick']),
            (0.52, Lf * 0.25, 3.0 + g['knee']),
            (0.80, Lf + g['reach'] * amp, g['land']),
            (1.0, Lf, 3.0)]
    o, z = _hermite(keys, sw, (v * 0.6, 22.0), (v * 0.35, -6.0))
    return o, max(3.0, z), keyinterp(RUN_SWING_PITCH, sw)[0]


def run_foot_in(g, phi):
    """0..1: how far a swinging foot comes in toward the line it runs on"""
    S = g['S']
    if phi < S:
        return 0.0
    return math.sin(math.pi * (phi - S) / (1.0 - S))


def run_gait(P, t, move, style='jog', amp=1.0, pitch_scale=1.0):
    g = RUN_GAITS[style]
    mf, mr = move
    for side, sg, ph in (('L', -1, 0.0), ('R', 1, 0.5)):
        phi = (t + ph) % 1.0
        o, z, pitch = run_foot(g, phi, amp)
        # runners land near the midline: the swinging foot comes in a little
        width = 2.6 - 0.9 * run_foot_in(g, phi)
        P.feet[side] = (0.6 + mf * o, width * sg + mr * o, z)
        P.foot_pitch[side] = pitch * pitch_scale
    c = math.cos(2 * math.pi * t)
    P.hip_f['L'] = g['hip'] * c * mf
    P.hip_f['R'] = -g['hip'] * c * mf
    P.twist = -g['twist'] * c * mf
    S = g['S']
    P.shift_r = -g['shift'] * math.cos(2 * math.pi * (t - S / 2))

    def bob_at(tt):
        # lowest at each mid-stance (S/2 and 0.5 + S/2), highest mid-flight
        return -g['drop'] - g['B'] * math.cos(4 * math.pi * (tt - S / 2))
    P.bob = bob_at(t)
    P.lean = g['lean'] * (1 if mf > 0 else (-0.3 if mf < 0 else 0.4))
    # the rucksack is strapped tight (dev80); the head steadies a beat late
    pz = (bob_at(t - 0.07) - P.bob) * 0.4
    P.pack = (-abs(pz) * 0.2 - 0.15, -P.shift_r * 0.25, pz)
    P.head_yaw = -0.6 * P.twist
    P.head_dz = (bob_at(t - 0.05) - P.bob) * 0.3
    return P


def check_reach(style, amp=1.0, margin=0.35):
    """The worst stretch of a leg over the cycle: >0 means the IK would have
    to clamp (the ankle could not be where the plan puts it)."""
    worst = -99.0
    P = Pose(0)
    for k in range(64):
        t = k / 64.0
        run_gait(P, t, (1, 0), style, amp)
        pz = P.pelvis_z + P.bob
        for side, sg in (('L', -1), ('R', 1)):
            f, r, z = P.feet[side]
            hip = np.array([P.hip_f[side], 2.7 * sg, pz - 1.2])
            d = np.linalg.norm(np.array([f, r, z]) - hip)
            worst = max(worst, d - (LEG[0] + LEG[1] - margin))
    return worst


WALK_DROP = 1.4              # the walking pelvis rides this much lower


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
        if style == 'walk':
            P.bob -= WALK_DROP
    P.lean = g['lean'] * (1 if mf >= 0 else -0.3)

    # secondary motion: what the torso did a moment ago is what the pack and
    # the head do now - a damped follow-through instead of rigid parts
    def bob_at(tt):
        if style == 'run':
            return -g['bob'] * math.cos(4 * math.pi * (tt - stance_mid))
        return g['bob'] * math.cos(4 * math.pi * (tt - stance_mid)) - g['bob']

    def shift_at(tt):
        return -g['shift'] * math.cos(2 * math.pi * (tt - stance_mid))

    def twist_at(tt):
        return -g['twist'] * math.cos(2 * math.pi * tt) * mf
    # dev80: a packed rucksack is strapped tight - it only settles a little
    # behind the back (it used to bounce 2.3 units at a run and swing out with
    # every turn of the shoulders)
    lag = 0.06 if style == 'run' else 0.08
    pz = (bob_at(t - lag) - P.bob) * 0.32
    pr = (shift_at(t - lag) - P.shift_r) * 0.3 + (twist_at(t - lag) - P.twist) * 1.4
    pf = -abs(pz) * 0.2 - (0.2 if style == 'run' else 0.0)
    P.pack = (pf, pr, pz)
    P.head_yaw = -0.6 * P.twist
    P.head_dz = (bob_at(t - 0.05) - P.bob) * 0.35
    return P


def unarmed_swing(P, t, amp, run=False):
    for side, sg, ph in (('L', -1, 0.5), ('R', 1, 0.0)):
        c = math.cos((t + ph) * 2 * math.pi)
        if run:
            P.hands[side] = (1.6 + amp * c, 5.0 * sg, 7.0 + 2.2 * max(0.0, c))
        else:
            P.hands[side] = (0.8 + amp * c, 7.3 * sg, -0.8 + abs(c) * 0.6 + max(0.0, c) * 0.9)


def carry_sway(P, t, k, keep_twist=0.35):
    """Weapon moves with the chest while walking/running."""
    if P.grip is None:
        return
    f, r, z = P.grip
    # the gun rides the step: up and down with each footfall, a little across
    P.grip = (f, r + 0.35 * k * math.cos(2 * math.pi * t), z + k * math.cos(4 * math.pi * t))
    P.gun_yaw += 0.03 * k * math.cos(2 * math.pi * t)
    P.twist *= keep_twist    # a rifle keeps the torso squarer than free arms


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
        # breathing lifts the straps a beat after the chest; idle eyes wander
        P.pack = (0.0, 0.0, -0.15 * amp * math.sin(t * 2 * math.pi - 0.9))
        P.head_yaw = {'Idle': 0.0, 'Idle2': 0.32, 'Idle3': -0.18}[clip] * math.sin(t * 2 * math.pi)
        if unarmed:
            P.hands = {'L': (0.6, -6.9, -0.4 + P.bob), 'R': (0.6, 6.9, -0.4 + P.bob)}
    elif clip == 'Walk':
        # dev82: a walk is a walk - at a slow pace (overloaded, hurt), the
        # raiders' patrol; the survivor's ordinary pace is the Jog
        gait(P, t, (1, 0), 'walk')
        if unarmed:
            unarmed_swing(P, t, 3.4)
        else:
            carry_sway(P, t, 0.5)
    elif clip in ('Jog', 'Run', 'RunAttack'):
        # dev81: the survivor's ordinary pace is a jog, the sprint a sprint
        # (the old Walk was a stroll at a jogger's speed - the feet skated)
        run = clip == 'Run'
        style = 'sprint' if run else 'jog'
        run_gait(P, t, (1, 0), style)
        if unarmed:
            unarmed_swing(P, t, RUN_GAITS[style]['arms'], True)
        else:
            # firing on the move (RunAttack) keeps the gun steady on the target
            aiming = clip == 'RunAttack'
            carry_sway(P, t, 0.5 if aiming else (1.3 if run else 1.0), keep_twist=0.35 if aiming else 0.7)
            if run and P.grip is not None:
                # a sprint carries the gun low across the body, not at the shoulder
                f, r, z = P.grip
                P.grip = (f - 0.8, r - 1.0, z - 4.0)
                P.gun_pitch += 0.38
    elif clip.startswith('RunBackwards'):
        run_gait(P, t, (-1, 0), 'jog', amp=BACK_AMP, pitch_scale=-0.4)
        P.lean = -0.04
        if unarmed:
            unarmed_swing(P, t, 2.2, True)
        else:
            carry_sway(P, t, 0.35)
    elif clip.startswith('StrafeLeft') or clip.startswith('StrafeRight'):
        sg = -1 if 'Left' in clip else 1
        run_gait(P, t, (0, sg), 'jog', amp=STRAFE_AMP, pitch_scale=0.2)
        P.side_lean = 0.05 * sg
        P.lean = 0.03
        if unarmed:
            unarmed_swing(P, t, 1.4, True)
        else:
            carry_sway(P, t, 0.35)
    elif clip == 'CrouchIdle':
        P.pelvis_z = 3.0 + 10.5 * LEG_K
        P.feet = {'L': (2.8, -3.4, 3.0), 'R': (-2.2, 3.2, 3.0)}
        P.foot_pitch = {'L': 0.0, 'R': -0.35}
        P.lean = 0.22
        P.bob = -0.3 * math.sin(t * 2 * math.pi)
        if unarmed:
            unarmed_swing(P, 0.25, 0.0)
    elif clip == 'CrouchRun':
        P.pelvis_z = 3.0 + 12.0 * LEG_K
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
        a = min(1.0, k / (frame_count('Die') * 0.75))
        P.pelvis_z = PELVIS_Z - 7.0 * LEG_K * min(1.0, a * 1.6)
        P.feet = {'L': (1.8, -3.0, 3.0), 'R': (-0.6, 3.2, 3.0)}
        P.fall = (math.pi * 0.46) * (a ** 1.4)
        if w:
            P.gun_pitch = -0.5 * a
            if a > 0.5:
                P.two_hand = False
                P.hands['L'] = (0.0, -7.0, 4.0)
        else:
            P.hands = {'L': (0.0, -7.0, 4.0 + 6 * a), 'R': (0.0, 7.0, 4.0 + 6 * a)}
    elif clip == 'Pickup':
        # dev77: down on one knee, the free hand to the floor, and up again
        # (the game used to borrow the first frames of the fall for this - the
        # survivor seemed to topple sideways at every crate)
        a = [0.0, 0.35, 0.7, 0.92, 1.0, 1.0, 0.9, 0.62, 0.3, 0.08][k]
        reach = [0.0, 0.1, 0.4, 0.8, 1.0, 1.0, 0.75, 0.35, 0.1, 0.0][k]
        P.pelvis_z = PELVIS_Z - 7.6 * LEG_K * a
        P.feet = {'L': (0.6 + 3.2 * a, -2.9, 3.0), 'R': (0.6 - 3.4 * a, 3.0, 3.0 + 0.4 * a)}
        P.foot_pitch = {'L': 0.0, 'R': -0.75 * a}
        P.lean = 0.42 * a
        P.head_pitch = 0.3 * a
        _free_left_hand(P, w, a)
        P.hands['L'] = (2.0 + 6.0 * reach, -2.6, 2.0 - (13.5 + 7.6 * (LEG_K - 1.0)) * reach)
        if cls == 'none':
            P.hands['R'] = (2.0 + 2.0 * a, 5.6, 0.5 - 2.0 * a)
    elif clip == 'Use':
        # dev77: a hand out to a door or a handle - a short push, the body
        # follows a little; feet stay put
        p = [0.0, 0.45, 0.85, 1.0, 1.0, 0.7, 0.35, 0.1][k]
        P.lean = 0.10 * p
        P.twist = -0.12 * p
        _free_left_hand(P, w, min(1.0, p * 1.4))
        P.hands['L'] = (3.0 + 8.0 * p, -3.4 + 0.8 * p, 6.0 + 5.5 * p)
        if cls == 'none':
            P.hands['R'] = (0.8, 7.3, -0.6)
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
    if clip in ('Attack1', 'Attack2'):
        if cls in ('rifle', 'pistol'):
            kick = [1.8, 1.2, 0.6, 0.25, 0, 0, 0, 0][k]
            f, r, z = P.grip
            P.grip = (f - kick, r, z + kick * 0.3)
            P.gun_pitch += kick * 0.06
            P.flash = k in (0, 1) and clip == 'Attack1'
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


def _free_left_hand(P, w, a):
    # the weapon goes to the right hand alone, muzzle down, so the left is free
    cls = weapon_class(w)
    if cls in ('rifle', 'pistol'):
        P.two_hand = False
        f, r, z = P.grip
        low = (2.6, 5.4, 4.6) if cls == 'rifle' else (2.8, 5.6, 3.6)
        P.grip = (f + (low[0] - f) * a, r + (low[1] - r) * a, z + (low[2] - z) * a)
        P.gun_pitch = P.gun_pitch + (-0.95 - P.gun_pitch) * a
    elif cls in ('knife', 'heavy'):
        P.two_hand = False


LAST_MUZZLE = [None]


def muzzle_table():
    """Muzzle point and barrel direction per gun and direction, in cell
    pixels, for the shot-on-the-move flash (world/muzzle_points.gd)."""
    out = {}
    for w in WEAPONS:
        if weapon_class(w) not in ('rifle', 'pistol'):
            continue
        rows = []
        for d in range(8):
            LAST_MUZZLE[0] = None
            P = make_pose('RunAttack', w, d, 0)
            build(P)
            (ax, ay), (bx, by) = LAST_MUZZLE[0]
            rows.append((round(ax, 1), round(ay, 1), round(bx - ax, 3), round(by - ay, 3)))
        out[w] = rows
    return out


def write_muzzle_table(project):
    t = muzzle_table()
    alias = {'tt33': 'makarov', 'sks': 'akm', 'toz34': 'shotgun'}
    lines = ['extends RefCounted', '# Generated by tools/survivor3d.py write_muzzle_table(): where the muzzle',
             '# sits in a 128 px survivor cell (x, y) and the barrel direction (dx, dy)',
             '# per direction row, for the muzzle flash of a shot on the move.', '', 'const POINTS = {']
    for w in sorted(list(t.keys()) + list(alias.keys())):
        rows = t[alias.get(w, w)]
        cells = ', '.join('[%.1f, %.1f, %.3f, %.3f]' % r for r in rows)
        lines.append('    "%s": [%s],' % (w, cells))
    lines.append('}')
    with open(os.path.join(project, 'world', 'muzzle_points.gd'), 'w') as f:
        f.write('\n'.join(lines) + '\n')


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


MARAUDER_OUTFITS = ('gopnik', 'bandit', 'deserter')
MARAUDER_WEAPONS = ('makarov', 'akm', 'shotgun')
MARAUDER_CLIPS = ('Idle', 'Walk', 'Jog', 'Run', 'Attack1', 'TakeDamage', 'Die')


def build_marauders(project, outfits=MARAUDER_OUTFITS, weapons=MARAUDER_WEAPONS, clips=MARAUDER_CLIPS):
    out = os.path.join(project, 'art', 'marauders')
    os.makedirs(out, exist_ok=True)
    for o in outfits:
        apply_outfit(o)
        for w in weapons:
            for clip in clips:
                save_png(sheet(clip, w), os.path.join(out, '%s_%s_%s.png' % (o, w, clip)))
        # bare hands: a raider who threw the gun down to surrender
        for clip in ('Idle', 'Walk', 'Jog', 'Run', 'Die'):
            save_png(sheet(clip, None), os.path.join(out, '%s_none_%s.png' % (o, clip)))
    apply_outfit('survivor')


def leg_stretch(clip, w='akm', margin=0.35):
    """How far past a bent-knee reach the plan asks a leg to go over a
    clip (>0: the IK clamps and the drawn foot leaves its mark on the ground)."""
    worst = -99.0
    for k in range(frame_count(clip)):
        P = make_pose(clip, w, 0, k)
        pz = P.pelvis_z + P.bob
        for side, sg in (('L', -1), ('R', 1)):
            hip = np.array([P.hip_f[side], P.shift_r + 2.7 * sg, pz - 1.2])
            d = np.linalg.norm(np.array(P.feet[side]) - hip)
            worst = max(worst, d - (LEG[0] + LEG[1] - margin))
    return worst


# dev81: how far the body travels in one step cycle of each clip, in world
# pixels seen from the side (the sheets show 2 texels per world pixel). The
# game turns its distance into the cycle phase with these, so the planted foot
# keeps pace with the ground (world/gait_strides.gd).
SHEET_WORLD_SCALE = 0.5


def stride_units(clip):
    if clip == 'Walk':
        g = GAITS['walk']
        return 2.0 * g['A'] / g['S']
    if clip in ('Jog', 'RunAttack'):
        g = RUN_GAITS['jog']
        return (g['Lf'] + g['Lb']) / g['S']
    if clip == 'Run':
        g = RUN_GAITS['sprint']
        return (g['Lf'] + g['Lb']) / g['S']
    if clip.startswith('RunBackwards'):
        g = RUN_GAITS['jog']
        return (g['Lf'] + g['Lb']) * BACK_AMP / g['S']
    if clip.startswith('Strafe'):
        g = RUN_GAITS['jog']
        return (g['Lf'] + g['Lb']) * STRAFE_AMP / g['S']
    if clip == 'CrouchRun':
        g = GAITS['crouch']
        return 2.0 * g['A'] / g['S']
    return 0.0


def stride_px(clip):
    return stride_units(clip) * RENDER_K * SHEET_WORLD_SCALE


def write_gait_strides(project):
    survivor = {}
    for clip in MOVE_CLIPS + MOVE_ATTACK_CLIPS:
        survivor[clip] = round(stride_px(clip), 3)
    raider = {c: round(stride_px(c), 3) for c in ('Walk', 'Jog', 'Run')}
    fmt = lambda d: '{' + ', '.join('"%s": %s' % (k, v) for k, v in d.items()) + '}'
    src = ('extends RefCounted\n'
           '# Generated by tools/survivor3d.py write_gait_strides - do not edit.\n'
           '# World pixels the body travels in one step cycle of each locomotion clip,\n'
           '# seen from the side; the ground under a sprite is drawn foreshortened by\n'
           '# GROUND_YK toward and away from the camera.\n'
           'const SURVIVOR = %s\n'
           'const RAIDER = %s\n'
           'const GROUND_YK = %s\n'
           '# dev82: the share of that foreshortening the cadence follows. Full\n'
           '# (0.55) kept the foot planted toward the camera but nearly doubled the\n'
           '# leg speed there - the legs pattered; 0.8 keeps a runner\'s rhythm and\n'
           '# lets the foot drift a little along the line of sight, where it reads least.\n'
           'const VIEW_YK = 0.8\n'
           '# dev82: the survivor\'s legs are short for his speed (a third of his\n'
           '# height); matching the ground exactly made them patter at 2 to 3 cycles\n'
           '# a second. The cycle runs this much longer than the drawn stride - a\n'
           '# runner\'s 175-185 steps a minute - and the planted foot drifts a fifth\n'
           '# of a step, which at this size reads far better than the patter.\n'
           'const CADENCE_EASE = 1.25\n'
           '# a sprint turns the legs over faster than a jog (about 200 steps a minute)\n'
           'const CADENCE = {"Run": 1.15}\n' % (fmt(survivor), fmt(raider), char3d.YK))
    with open(os.path.join(project, 'world', 'gait_strides.gd'), 'w') as f:
        f.write(src)


NPC_CLIPS = ('Idle', 'Idle2')


def build_npcs(project, outfits=None, clips=NPC_CLIPS):
    out = os.path.join(project, 'art', 'npcs')
    os.makedirs(out, exist_ok=True)
    for o in (outfits or NPC_OUTFITS):
        apply_outfit(o)
        for clip in clips:
            save_png(sheet(clip, None), os.path.join(out, '%s_%s.png' % (o, clip)))
    apply_outfit('survivor')


def build_all(project):
    for w in WEAPONS:
        for clip in CLIPS:
            save_png(sheet(clip, w), os.path.join(project, 'survivor_%s%s.png' % (FILE_PREFIX[w], clip)))


if __name__ == '__main__':
    build_all(sys.argv[1])
