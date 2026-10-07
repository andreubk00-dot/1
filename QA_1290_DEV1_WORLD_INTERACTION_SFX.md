# QA — OSTATOK 1.29.0-dev1 World Interaction SFX

## Engine

Godot: `4.7.2.stable.official.ed1daf0bf`

Engine ZIP SHA-256:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

## Clean import

`.godot` removed before import.

`godot --headless --path . --import`: **exit 0**.

Parse/load errors in the import log: **0**.

## New audio runtime

- `test_world_interaction_sfx_129.gd`: **68/68**.
- `test_world_audio_save_boundary_129.gd`: **7/7**.

All eight WAV assets load through Godot and have plausible authored durations (0.18–0.46 s). The six-voice world pool accepts every clip and unknown IDs fail safely.

The immediate playback test can print Godot shutdown cleanup warnings for WAV resources when SceneTree exits directly after testing. The process exits 0 and reports no playback/load failure; this does not occur during normal game lifetime.

## Protected runtime regression

Short independent batches:

- `test_weapon_audio.gd`: **113/113**.
- `test_weapon_action_cycles.gd`: **48/48**.
- `test_high_risk_visual_multifloor.gd`: **130/130**.
- `test_trading_economy_122.gd`: **512/512**.
- `test_save_recovery.gd`: **18/18**.

Selected explicit checks: **896/896**.

Main scene:

- `OSTATOK 1.29.0-dev1 SELFTEST: OK`
- `QA_SELFTEST_EXIT: failures=0`
- process exit 0.

## Deterministic source-audio build

`tools/build_world_audio.py` was run again after generation.
Combined SHA state before/after regeneration was identical:

`6d78758755084c281c95f899835f53b3d7058aba6a02c05d574c5f47054ab5cc`

## Compatibility / boundary

Compared with 1.28.0-dev3:

- save writer remains `save_version: 122`;
- no world-audio cursor/cache/player state is serialized;
- 651/651 PNG files present and byte-identical;
- no gameplay changes to AI hearing values, movement, melee damage, door mechanics, crafting or building costs;
- historical 1.22 Stable version gate is not rewritten;
- current High Risk visual version gate updated to 1.29.0-dev1 only.
