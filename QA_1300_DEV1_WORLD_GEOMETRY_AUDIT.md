# QA — OSTATOK 1.30.0-dev1 World Geometry Audit

## Engine

Godot `4.7.2.stable.official.ed1daf0bf`.
Engine ZIP SHA-256: `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.

## Baseline geometry regression

После clean import:

- world placement: **12/12**;
- settlement layout: **674/674**;
- target farming / world layout: **1338/1338**;
- world content POI: **267/267**;
- world events / encounters: **1819/1819**.

## New final audit

`test_world_geometry_final_audit_130.gd`:

- **6232/6232**;
- chunks built: **106**;
- authored cells: **85**;
- finite events encountered: **1**.

Первый черновой вариант теста дал 21 ложное срабатывание из-за применения procedural clearance к authored-композициям. После сверки с production placement helpers и High Risk capture правила теста были исправлены; игровой world geometry не менялся.

## Visual investigation

Отдельно сняты runtime captures для `quarantine_center_12` и `underground_object_vector` (по 13 кадров на объект). Увеличенные High Risk exterior envelopes формируют цельные пристройки/корпуса; основные проходы и двери визуально не перекрыты. Поэтому геометрическая правка в dev1 отклонена как рискованная и необоснованная.

## Boundary

- save schema: **122**;
- no gameplay geometry changes;
- historical 1.22 gates untouched;
- post-version-bump geometry audit: **6232/6232**;
- post-version-bump High Risk visual/multifloor: **130/130**;
- `main.tscn` selftest: `OSTATOK 1.30.0-dev1 SELFTEST: OK`, failures=0.
