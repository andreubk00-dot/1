#!/usr/bin/env python3
"""Parallel survivor-sheet baker for the weapon-specific 8-way animation atlases.

Usage:
    python3 tools/build_survivor_parallel.py <project> [weapon ...]

The serial builder remains the simple reference implementation. This runner exists so
arsenal QA can rebake a complete weapon set without an 8+ minute single-core pass.
"""
from __future__ import annotations
import argparse
from multiprocessing import Pool, cpu_count
from pathlib import Path
import os
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import survivor3d as S


def _build_one(task: tuple[str, str, str]) -> str:
    project, weapon_name, clip = task
    weapon = None if weapon_name == "none" else weapon_name
    prefix = S.FILE_PREFIX[weapon]
    target = Path(project) / f"survivor_{prefix}{clip}.png"
    S.save_png(S.sheet(clip, weapon), str(target))
    return target.name


# guns that share another gun's hold and silhouette at sprite size: their
# sheets are the other gun's (the game picks them by anim_prefix)
ALIASES = {"tt33": "makarov", "sks": "akm", "toz34": "shotgun"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project")
    parser.add_argument("weapons", nargs="*", default=[])
    parser.add_argument("--jobs", type=int, default=max(1, min(4, cpu_count() or 1)))
    args = parser.parse_args()

    project = str(Path(args.project).resolve())
    names = args.weapons or ["none"] + [w for w in S.WEAPONS if w is not None]
    valid = {"none"} | {w for w in S.WEAPONS if w is not None}
    unknown = [name for name in names if name not in valid]
    if unknown:
        raise SystemExit("unknown weapon(s): " + ", ".join(unknown))

    tasks = [(project, name, clip) for name in names for clip in S.CLIPS]
    with Pool(processes=max(1, args.jobs)) as pool:
        for index, result in enumerate(pool.imap_unordered(_build_one, tasks), 1):
            print(f"[{index:03d}/{len(tasks):03d}] {result}", flush=True)
    import shutil
    for alias, source in ALIASES.items():
        if source not in names:
            continue
        for clip in S.CLIPS:
            shutil.copyfile(Path(project) / f"survivor_{source}_{clip}.png", Path(project) / f"survivor_{alias}_{clip}.png")
        print(f"aliased survivor_{alias}_* <- survivor_{source}_*", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
