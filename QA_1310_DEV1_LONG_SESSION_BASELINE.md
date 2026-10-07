# QA — OSTATOK 1.31.0-dev1 Long Session Baseline

Engine: Godot 4.7.2 stable (`ed1daf0bf`).

## New 1.31 tests

- `test_long_session_chunk_churn_131.gd`: 201/201.
- `test_long_session_entity_cleanup_131.gd`: 170/170.
- `test_long_session_save_stress_131.gd`: 50/50.

## Existing long-horizon suites

- `test_multi_route_economy_soak_123.gd`: 29419/29419.
- `test_high_risk_farming_soak_123.gd`: 440/440.
- `test_personal_contract_soak_123.gd`: 31/31.
- `test_regional_endgame_soak_126.gd`: 42/42.

## Baseline metrics

- chunk transitions: 96;
- max active chunks: 9;
- node count: 7616 -> 7616;
- roof records: 35 -> 35;
- `_refresh_chunks()` avg/max: 41626 / 334653 microseconds;
- repeated encounter cleanup: 24 cycles, final node count 4 -> 4;
- stress save: 251539 bytes stable across 20 rewrites;
- maximum stress-save write: 45518 microseconds.

## Boundary

- save schema remains 122;
- no gameplay GDScript is intentionally modified in this slice;
- art assets remain unchanged;
- runtime import and final selftest are required before packaging.

## Final version gates

- current High Risk visual/multifloor gate: **130/130**.
- main SELFTEST marker: `OSTATOK 1.31.0-dev1 SELFTEST: OK`.
- the outer runner timed out after the OK marker; no Godot process remained afterward.
- PNG assets: **651/651 byte-identical** to 1.30-dev3.
- non-test gameplay GDScript changes vs 1.30-dev3: **0**.
