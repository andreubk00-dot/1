"""Rebuild survivor sheets. Usage: python3 tools/build_survivor.py <project> [weapon ...]
weapon names: none makarov shotgun akm pps43 izh81 aks74u mosin knife pipe axe (default: all)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import survivor3d as S

P = sys.argv[1]
names = sys.argv[2:] or ['none', 'makarov', 'shotgun', 'akm', 'pps43', 'izh81', 'aks74u', 'mosin', 'knife', 'pipe', 'axe']
for n in names:
    w = None if n == 'none' else n
    for clip in S.CLIPS:
        S.save_png(S.sheet(clip, w), os.path.join(P, 'survivor_%s%s.png' % (S.FILE_PREFIX[w], clip)))
    print('done', n, flush=True)
