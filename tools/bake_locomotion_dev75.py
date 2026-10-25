"""Rebuild authored 24-frame movement sheets with restrained gear follow-through.
python tools/bake_locomotion_dev75.py PROJECT --jobs 4
"""
from pathlib import Path
from multiprocessing import Pool
import argparse
import shutil
import survivor3d as rig


def bake(task):
    project,outfit,weapon,clip=task
    rig.apply_outfit(outfit)
    if outfit=='survivor':
        path=Path(project)/('survivor_'+rig.FILE_PREFIX[weapon]+clip+'.png')
    else:
        path=Path(project)/'art/marauders'/f'{outfit}_{weapon or "none"}_{clip}.png'
    rig.save_png(rig.sheet(clip,weapon),str(path))
    return path.name


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project',type=Path)
    parser.add_argument('--jobs',type=int,default=4)
    a=parser.parse_args()
    project=str(a.project.resolve())
    clips=rig.MOVE_CLIPS
    tasks=[(project,'survivor',w,c) for w in rig.WEAPONS for c in clips]
    tasks += [(project,o,w,c) for o in rig.MARAUDER_OUTFITS for w in [None,*rig.MARAUDER_WEAPONS] for c in ['Walk','Run']]
    with Pool(a.jobs) as pool:
        for i,name in enumerate(pool.imap_unordered(bake,tasks),1):
            print(f'{i}/{len(tasks)} {name}',flush=True)
    root=Path(project)
    for alias,source in {'tt33':'makarov','sks':'akm','toz34':'shotgun'}.items():
        for c in clips: shutil.copyfile(root/f'survivor_{source}_{c}.png',root/f'survivor_{alias}_{c}.png')


if __name__=='__main__': main()
