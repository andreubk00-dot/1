# QA — OSTATOK 1.33.0-dev1 Feature Lock Audit

Engine: Godot 4.7.2 stable (`ed1daf0bf`).

## New release-surface QA

`test_feature_lock_release_surface_133.gd` переключает version surface внутри одного isolated runtime:

- Stable/RC style version без `-dev`: developer tools false;
- Stable world не содержит `garage_all_items_0163`;
- Stable world не содержит `ТЕСТ-ЯЩИК: ВСЕ ПРЕДМЕТЫ` label;
- `-dev` build сохраняет developer tools;
- `-dev` build сохраняет full-catalogue QA crate, `all_items_test` и 20×10 capacity.

Initial post-fix run after complete Godot import: **7/7**.

## Scope

Feature Lock does not change gameplay balance, art, save schema, High Risk, endgame, economy, NPC roster or ordinary world containers.

Historical Stable gate requiring `1.22.0` is not rewritten.

## Final 1.33.0-dev1 gates

- feature-lock release surface: **7/7**
- current High Risk visual/version gate: **130/130**
- main selftest marker: `OSTATOK 1.33.0-dev1 SELFTEST: OK`
- outer selftest runner timed out only after the OK marker; no Godot process remained and no parse/runtime errors were present
- PNG assets: **651/651 byte-identical** to 1.32-dev1
- save schema: **122**
- changed gameplay GDScript: only `main_script_mod.gd`, limited to the `-dev` guard around the QA all-items crate/label
- generated import-only `.uid` files removed before packaging
- `.godot` cache excluded from package; external `.tmp/.bak` junk: **0**
