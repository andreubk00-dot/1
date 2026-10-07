#!/usr/bin/env python3
"""1.27-dev2 source/asset reference QA. No substitute for Godot runtime tests."""
from pathlib import Path
from math import floor
from hashlib import sha256
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
GUNS = ('makarov','tt33','shotgun','toz34','sks','akm','pps43','izh81','aks74u','mosin')
MELEE = ('knife','pipe','axe')
PREFIXES = GUNS + MELEE
IDLES = ('Idle','Idle2','Idle3')
LOCOMOTION = ('Walk','Run','RunBackwards','StrafeLeft','StrafeRight')
ATTACK = ('Attack1','RunAttack','RunBackwardsAttack','StrafeLeftAttack','StrafeRightAttack','Attack2','Attack3','Attack4','Taunt','TakeDamage')
checks = 0
failures = []

def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)

def png_size(path):
    with path.open('rb') as f:
        header = f.read(24)
    if len(header) < 24 or header[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    return struct.unpack('>II', header[16:24])

source = (ROOT/'main_script_mod.gd').read_text()
check('return _modern_survivor_idle_sheet(weapon_id)\n        var melee_side' in source,
      'melee idle selector bypasses authored variants')
check('var cycle = fposmod(modern_survivor_idle_time - 5.0,12.0)' in source,
      'idle variants must use uninterrupted idle timer')
check('var window_start = 0.0 if sheet_name == "Idle2" else 6.25' in source,
      'idle variant windows lost')
check('window_elapsed / 2.25 * float(frames)' in source,
      'idle variants must start from local phase')
check('"save_version":122' in source,
      'save schema changed')
check((ROOT/'BUILD_VERSION.txt').read_text().strip() == '1.27.0-dev2','build version')
check((ROOT/'BRANCH.txt').read_text().strip() == '1.27.0-dev2','branch')
check('config/version="1.27.0-dev2"' in (ROOT/'project.godot').read_text(), 'Godot project version')
check('== "1.27.0-dev2"' in (ROOT/'tests/test_high_risk_visual_multifloor.gd').read_text(), 'current visual gate')

for prefix in PREFIXES:
    for clip in IDLES + LOCOMOTION + ATTACK:
        filename = ROOT/f'survivor_{prefix}_{clip}.png'
        geom = png_size(filename) if filename.exists() else None
        expected = (1536,1024) if clip in LOCOMOTION else (1024,1024)
        check(geom==expected, f'{prefix}/{clip}: actual={geom}, expected={expected}')

# External deterministic timeline audit, 1.27-dev2 authored idle windows.
for which, start in [('Idle2',5.0),('Idle3',11.25)]:
    for elapsed, expected in [(0,0),(0.28125,1),(0.5625,2),(1.125,4),(1.6875,6),(2.249,7)]:
        cycle = (start + elapsed - 5.0) % 12.0
        window_start = 0 if which=='Idle2' else 6.25
        frame = max(0,min(7,floor(max(0,min(2.25,cycle-window_start))/2.25 * 8)))
        check(frame == expected, f'{which} @ {elapsed}: got {frame}, expected {expected}')

# All explicit preload paths must exist. Skip runtime-formatted paths.
for gd in list(ROOT.rglob('*.gd')):
    for res in re.findall(r'preload\(["\']res://([^"\']+)["\']\)',gd.read_text(errors='replace')):
        if '%' in res or '{' in res:
            continue
        check((ROOT/res).is_file(), f'broken preload {gd.relative_to(ROOT)} : {res}')

# Pre-authored Idle2 and Idle3 starts should be close to the base Idle silhouette.
try:
    import numpy as np
    from PIL import Image
    for prefix in PREFIXES:
        base = np.asarray(Image.open(ROOT/f'survivor_{prefix}_Idle.png').convert('RGBA'))[0:128,0:128,:]
        for clip in ('Idle2','Idle3'):
            first = np.asarray(Image.open(ROOT/f'survivor_{prefix}_{clip}.png').convert('RGBA'))[0:128,0:128,:]
            pixel_difference = float(np.any(base!=first,axis=2).mean())
            check(pixel_difference < 0.018, f'non-neutral transition {prefix}/{clip}: {pixel_difference:.4f}')
except ImportError:
    print('INFO: numpy/Pillow not available: pixel similarity QA skipped')

print(f'127-dev2 static/reference: {checks} checks, {len(failures)} failures')
for item in failures[:30]:
    print('FAIL:',item)
sys.exit(1 if failures else 0)
