"""dev81: does the planted foot hold still on the ground? For each locomotion
clip the body is moved the way the game moves it (one stride a cycle, from
world/gait_strides.gd) and the IK-placed ankle of a planted foot is followed in
world pixels; its drift while the foot is down is the skating a player sees.
python3 tools/check_gait_slip.py"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char3d  # noqa: E402
import survivor3d as S  # noqa: E402


def planted_drift(clip, stride_px, d=0, w='akm', samples=4):
    """Largest drift (world px) of a planted ankle over one stance, side view."""
    n = S.frame_count(clip) * samples
    track = []
    for i in range(n):
        t = i / n
        # make_pose takes a frame index; a fractional one samples between frames
        k = t * S.frame_count(clip)
        P = S.make_pose(clip, w, d, k)
        pz = P.pelvis_z + P.bob
        pelvis = P.L(0, P.shift_r, pz)
        hip = pelvis + P.r * (2.7 * -1) + P.z * (-1.2) + P.f * P.hip_f['L']
        _, ankle = S.two_bone(hip, P.L(*P.feet['L']), S.LEG[0], S.LEG[1], P.f)
        sx = char3d.proj(ankle)[0] * S.SHEET_WORLD_SCALE
        body = t * stride_px                     # the game moves the sprite this far
        track.append((t, P.feet['L'][2], sx + body))
    # the stance that begins the cycle: the foot is down from contact until it lifts
    down = []
    for (t, z, x) in track:
        if z > 3.05:
            break
        down.append(x)
    return max(down) - min(down) if down else float('nan')


if __name__ == '__main__':
    for clip in ('Walk', 'Run', 'RunAttack', 'CrouchRun'):
        print('%-10s stride %5.1f px  planted foot drifts %.2f px' % (clip, S.stride_px(clip), planted_drift(clip, S.stride_px(clip))))
    S.TRUE_WALK = True
    for clip in ('Walk', 'Jog', 'Run'):
        print('raider %-6s stride %5.1f px  planted foot drifts %.2f px' % (clip, S.stride_px(clip), planted_drift(clip, S.stride_px(clip))))
