# QA — OSTATOK 1.27.0-dev1 Idle Animation Polish

## Static/reference PASS

- 10 firearm anim-prefixes audited.
- 3 melee anim-prefixes audited.
- Every prefix has `Idle`, `Idle2`, `Idle3`.
- Every runtime-requested baked clip has a corresponding weapon-specific sheet.
- No new PNG assets were created or modified.
- Idle windows are deterministic from transient `modern_survivor_idle_time`.
- Action blockers are explicit and testable through `_modern_survivor_idle_can_advance()`.
- firearm/melee switch and respawn reset the timer.

## QA suites

- `tests/test_idle_animation_polish_127.gd`
- `tests/test_idle_animation_save_boundary_127.gd`
- `tests/qa_idle_animation_capture.gd`

Production save boundary suite requires isolated `XDG_DATA_HOME` / `OSTATOK_QA_SAVE_ROOT`.

## Godot 4.7.2 — PENDING

Runtime/capture tests are prepared but cannot be claimed PASS in the current environment because no Godot 4.7.2 executable is available.
