# QA — OSTATOK 1.27.0-dev3 Character & Animation Final Pass

## Engine

Godot: `4.7.2.stable.official.ed1daf0bf`
Engine ZIP SHA-256:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

## Clean import

- `.godot` removed before import.
- `godot --headless --path . --import`: exit 0.
- Parse/load errors in import log: 0.

## Character / weapon runtime

- `test_idle_animation_polish_127.gd`: 54/54.
- `test_locomotion_transition_sync_127.gd`: 684/684.
- `test_weapon_action_cycles.gd`: 48/48.
- `test_weapon_instances.gd`: 28/28.
- `test_fire_access.gd`: 7/7.
- `test_arsenal_combat_roles.gd`: 26/26.
- `test_arsenal_expansion.gd`: 414/414.
- `test_arsenal_expansion_ii.gd`: 303/303.
- `test_locomotion_save_boundary_127.gd`: 6/6.

Subtotal character/weapon/save: 1570/1570.

## Protected-system regression

- `test_high_risk_visual_multifloor.gd`: 130/130.
- `test_trading_economy_122.gd`: 512/512.
- `test_save_recovery.gd`: 18/18.

Subtotal protected regression: 660/660.
Total selected checks: **2230/2230**.

## Main scene

`main.tscn --qa-selftest-exit`:
- `OSTATOK 1.27.0-dev3 SELFTEST: OK`
- `QA_SELFTEST_EXIT: failures=0`
- process exit 0.

## Visual QA

Headless dummy renderer cannot emit `RenderingServer.frame_post_draw`, therefore capture tests were correctly run under `Xvfb` + X11 + OpenGL compatibility renderer (Mesa llvmpipe), not counted as a game timeout.

Captured successfully:
- idle_base
- idle_weight_shift
- idle_ready_shift
- akm_idle2_start
- akm_idle3_mid
- knife_idle2_start
- pipe_idle3_mid
- akm_strafe_fire
- akm_back_fire

Visual review: weapon remains visible; idle variants are distinct; melee idle uses baked weapon sheet; moving-fire direction/pose is coherent; no obvious body-position jump.

ALSA unavailable in the QA container; Godot fell back to Dummy audio. This does not affect image capture or animation-state tests.

## Compatibility / boundary

- Save writer remains `save_version: 122`.
- Gameplay crouch remains intentionally absent; existing Crouch sheets are not wired to a nonexistent mechanic.
- Death/recovery untouched.
- dev2 -> dev3 functional diff: diagnostic SELFTEST label only in `main_script_mod.gd`; no animation gameplay logic changes.
- PNG assets: 651/651 present, 0 changed vs dev2.
- Generated `.godot` and import-only new `.gd.uid` files excluded from release archive.

## Known expected historical condition

Historical stable-release version gate requiring `1.22.0 Stable` is not rewritten.
