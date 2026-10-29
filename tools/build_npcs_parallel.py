"""Bake the settlement people's sheets (art/npcs/<outfit>_<clip>.png) in
parallel: python3 tools/build_npcs_parallel.py <project> [--jobs 4]"""
import os
import sys
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import survivor3d as S  # noqa: E402


def _one(args):
    project, outfit = args
    S.build_npcs(project, outfits=[outfit])
    return outfit


if __name__ == '__main__':
    project = sys.argv[1]
    jobs = int(sys.argv[sys.argv.index('--jobs') + 1]) if '--jobs' in sys.argv else 4
    with Pool(jobs) as pool:
        for o in pool.imap_unordered(_one, [(project, o) for o in S.NPC_OUTFITS]):
            print('baked', o, flush=True)
