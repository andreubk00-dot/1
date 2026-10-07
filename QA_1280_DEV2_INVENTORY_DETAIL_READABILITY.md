# QA — OSTATOK 1.28.0-dev2 Inventory Detail Readability

## Engine

Godot `4.7.2.stable.official.ed1daf0bf`.
Engine ZIP SHA-256:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

## Import

Clean import from package-style project without `.godot`: PASS, exit 0, parse/load errors 0.

## Runtime

- `test_inventory_detail_readability_128.gd`: 24/24.
- `test_inventory_art_contract.gd`: 193/193.
- `test_quickbar_loadout.gd`: 33/33.
- `test_reusable_water_containers.gd`: 39/39.
- `test_save_recovery.gd`: 18/18.
- `test_high_risk_visual_multifloor.gd`: 130/130.
- `test_trading_economy_122.gd`: 512/512.
- Main `--qa-selftest-exit`: failures=0; reports `OSTATOK 1.28.0-dev2 SELFTEST: OK`.

Selected explicit checks: **949/949**.

## Visual QA

Xvfb + X11 + OpenGL compatibility captures at the project 640×360 viewport:

- `inventory_firearm_details.png`: six-line AKM description with extended magazine + muzzle brake remains fully above `ИСП. / ВЫБРОС / СОРТ / ЗАКРЫТЬ`;
- `container_firearm_details.png`: compact three-line firearm inspection remains fully above `ЗАБРАТЬ / ЗАБРАТЬ ВСЕ` and the panel stays inside the viewport.

The ALSA warning in the QA container falls back to Dummy audio and does not affect UI rendering.

## QA correction

The legacy inventory-art test previously required exact atlas art for every item and therefore failed four strategic items. This contradicted the production SELFTEST and `_make_item_icon()` implementation, where category `strategic` intentionally uses procedural schematic icons. The QA expectation was corrected; game art was not changed.

## Boundary

Compared with 1.28.0-dev1:

- inventory/container presentation only; gameplay state and persistence unchanged;
- current High Risk visual version gate updated to dev2; historical 1.22 Stable gate untouched;
- PNG: 651/651 present, 0 changed;
- `.godot` and import-only newly generated `.gd.uid` excluded;
- save writer remains schema 122.
