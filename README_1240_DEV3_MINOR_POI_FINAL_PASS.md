# OSTATOK 1.24.0-dev3 — Minor POI Final Pass

Закрывающий срез этапа **1.24.0 World Content Final Pass**.

База: **1.24.0-dev2 Encounter Scene Variety** (`SHA-256 0673d11d8637c686ca0b1d934425152daeef0a7d662cd823be5e1fbd0b80fdf7`).

## Что показал audit

Проверены все **25 authored cells** восьми обычных major/minor POI до High Risk:

- ГСК «Север»;
- Промкомбинат №7;
- Железнодорожное депо;
- СНТ «Заря»;
- военный КПП «Восток»;
- районная больница;
- районный отдел полиции;
- охотничий кордон «Сосны».

До dev3 обнаружено:

- **5 cells с 0 локальных props**;
- ещё **1 near-bare cell** с единственным prop и без lamps/fences/workbench.

Это были три сектора СНТ «Заря», казарменный двор КПП, закрытый двор полиции и хозяйственная поляна кордона.

## Что сделано

Добавлен `world/minor_poi_dressing.gd` — отдельный runtime-derived cosmetic overlay.

Он добавляет ровно по **2 небольших non-colliding atlas-props** в 6 подтверждённо недодекорированных cells. После overlay тот же audit даёт:

- zero-prop cells: **5 → 0**;
- bare/near-bare cells: **6 → 0**.

Overlay не изменяет `PoiCatalog` и не создаёт новых POI. Он использует только существующий `world_props_v19.png`.

## Что НЕ меняется

Dev3 не меняет:

- buildings, building ids, doors или collision;
- containers, cache ids, loot tables или target farming;
- enemy multipliers / encounter semantics;
- fences, authored navigation или chunk footprints;
- route/economy/projects/endgame/supply/crisis/trading;
- High Risk и strategic items;
- named NPC roster;
- save schema **122**.

`minor_poi_dressing` существует только как runtime sprite metadata и в production save не записывается.

## 1.24 закрыт

Этап **1.24.0 World Content Final Pass — ГОТОВО**:

- dev1 — Procedural Dressing Variety;
- dev2 — Encounter Scene Variety;
- dev3 — Minor POI Final Pass.

Следующий этап roadmap: **1.25.0 Narrative & Environmental Storytelling**.

## QA

Добавлены:

- `tests/test_minor_poi_dressing_124.gd`;
- `tests/test_minor_poi_dressing_runtime_124.gd`;
- `tests/test_minor_poi_dressing_save_runtime_124.gd`;
- `tests/qa_minor_poi_dressing_capture.gd`.

Подробности: `QA_1240_DEV3_MINOR_POI_FINAL_PASS.md`.

Godot 4.7.2 runtime/capture gate остаётся **PENDING** в текущей среде: исполняемого Godot здесь нет. Static/reference PASS не выдаются за engine PASS.
