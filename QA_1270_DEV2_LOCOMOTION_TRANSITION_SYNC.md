# QA — OSTATOK 1.27.0-dev2

## Completed — static/reference

- 1.27-dev2 source/atlas/timeline/preload audit: **816 / 816 PASS** (`python3 tools/qa_127_dev2_reference.py`).
- Prefix matrix: 10 firearms + 3 melee × idle/locomotion/attack atlases; all PNG geometries valid.
- Idle2 and Idle3 start at neutral frame 0; all 8 frames covered within each 2.25 s window.
- New assets created: 0; removed files: 0.
- Base dev1 archive SHA-256: `a08ab4f3d5e7f689e3090dca83dafef57df9a1f6aa91d795b684cc1895a03381`.
- Relative to dev1: 5 changed files before documentation (`main_script_mod.gd`, `project.godot`, `BRANCH.txt`, `BUILD_VERSION.txt`, `tests/test_high_risk_visual_multifloor.gd`); gameplay change only in visual selector/frame.
- Protected `SaveStore`, High Risk, economy, contracts, supply, crisis, regional endgame, NPC catalog etc. byte-identical: **12 / 12** representative modules.
- **651/651 PNG byte-identical** to dev1.
- Save writer remains `save_version: 122`; historical 1.22 Stable gate not modified.

## Added QA — requires Godot 4.7.2

- `tests/test_locomotion_transition_sync_127.gd`: per-weapon idle windows, exact frames, four walking directions, sprint, firing while moving, reload/cycle, melee swing, hit priority.
- `tests/test_locomotion_save_boundary_127.gd`: isolated production schema-122 save, transient idle time/frame not serialized.
- `tests/qa_locomotion_transition_capture.gd`: rifle/melee idle and moving-fire captures; freezes game process during snapshots.
- Existing `tests/test_idle_animation_polish_127.gd` and historical suites remain intact.

**Godot 4.7.2 import, actual runtime tests, visual captures, production selftest and broad gameplay regression: PENDING** — no Godot binary is available and the container cannot resolve external download hosts. No runtime PASS is claimed.

## Follow-up gate

Execute prepared tests in short independent batches under official Godot 4.7.2; inspect six capture PNGs at 640×360, then run high-risk visual, trading, save recovery and main.tscn SELFTEST. This is a release-candidate, not a runtime-certified stable release.
