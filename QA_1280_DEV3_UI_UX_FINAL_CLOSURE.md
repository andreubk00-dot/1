# QA — OSTATOK 1.28.0-dev3 UI/UX Final Closure

## Engine

Godot `4.7.2.stable.official.ed1daf0bf`.
Engine ZIP SHA-256:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

## Import

Clean import from package-style dev2 base without `.godot`: PASS, exit 0, parse/load errors 0.

## Runtime

- `test_ui_ux_final_closure_128.gd`: 139/139.
- `test_contract_ui_layout_123.gd`: 9/9.
- `test_trader_ui_layout_123.gd`: 13/13.
- `test_contract_ui_runtime_122.gd`: 18/18.
- `test_trader_ui_runtime_122.gd`: 16/16.
- `test_personal_contract_ui_runtime_123.gd`: 23/23.
- `test_settlement_crisis_ui_122.gd`: 8/8.
- `test_region_map_action_strip_128.gd`: 12/12.
- `test_inventory_detail_readability_128.gd`: 24/24.
- Main `--qa-selftest-exit`: failures=0; reports `OSTATOK 1.28.0-dev3 SELFTEST: OK`.

Selected explicit UI checks: **262/262**.

## Tooltip sweep

`test_ui_ux_final_closure_128.gd` iterates all 66 item definitions through the real hover inspector.

- maximum tooltip height: 232 px;
- maximum body lines: 10 (`police_vest`);
- title overflow: 0;
- safe height overflow: 0.

## Visual QA

Xvfb + X11 + OpenGL compatibility at the project 640×360 viewport:

- long district survey map after dev1: fixed expedition actions remain visible;
- full six-line firearm inventory details after dev2: action-row unobstructed;
- compact firearm container inspection after dev2: take-buttons unobstructed;
- longest workbench recipe: panel/list/details stay inside viewport;
- long story-thread / consequence chronicle text: wrapping and footer remain clean;
- `qa_ui_ux_final_closure_capture.gd`: longest equipment tooltip at bottom-right cursor position clamps to rect `(332,6) 248×232`, `safe=true`.

The ALSA warning in the QA container falls back to Dummy audio and does not affect UI rendering.

## Boundary

Compared with 1.28.0-dev2:

- no gameplay GDScript behavior change;
- version/roadmap/current visual gate + closure QA/docs only;
- PNG: 651/651 present, 0 changed;
- `.godot` and import-only newly generated `.gd.uid` excluded;
- save writer remains schema 122.
