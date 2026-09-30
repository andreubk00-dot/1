OSTATOK 0.56.0 — LIGHTING / MOTION / DEPTH POLISH
====================================================

Visual pass goals
- Increase depth and material readability without copying/cropping reference art.
- Make interiors feel less like flat debug rooms.
- Add practical-light behavior and subtle motion without changing gameplay contracts.
- Keep the current atlas sizes/scene logic compatible with the existing project.

Implemented
- New world_props_v17 atlas with original clinic/street props: reception desk, filing cabinet,
  damaged trolley, wall phone, tipped chair, rolling stand, crates, folded screen, trash,
  broken tiles, blood smear, floor cable, newspapers, mop, damaged cabinet, medical boxes,
  stretcher, puddles and related clutter.
- New interior_floor_tiles_v3, facade_wall_tiles_v2, interior_wall_band_v2 and interior_trim_v2.
- Layered interior wall/floor depth shading and restrained corner occlusion.
- Subtle practical-light pools and deterministic lamp flicker.
- Richer clinic layout and denser environmental storytelling while preserving walkable lanes.
- More street-story clutter in showcase/commercial/residential zones.
- Player idle breathing/weight shift and restrained weapon sway.
- Infected idle sway; movement cycle remains distance driven.
- Fixed infected ground shadow being parented to the animated body, which made the shadow
  bob/attack with the sprite. Shadow now stays on the ground.
- Added QA night mode and strengthened visual/runtime self-tests.

Pipeline / release fixes
- Asset cache was deliberately invalidated and rebuilt from scratch during QA.
- Release does not rely on a pre-existing .godot cache or stale *.import sidecars.
- project.godot application name was intentionally left unchanged to preserve user:// save paths.

Art provenance
- No user reference image fragments were cut out or embedded.
- No third-party art was introduced in this pass.
- New/modified visual assets in this pass were produced specifically for this project.

Verified with Godot 4.7.2
- clean import
- normal runtime
- inventory QA
- clinic QA (day/night visual capture)
- player QA
- infected QA
- infected-motion QA
- facade QA
- exterior QA
