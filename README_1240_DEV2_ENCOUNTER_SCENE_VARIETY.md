# OSTATOK 1.24.0-dev2 — Encounter Scene Variety

Второй срез этапа **1.24.0 World Content Final Pass**.

База: **1.24.0-dev1 Procedural Dressing Variety** (`SHA-256 b6706c2a6e3f082c9a02d830421145a18ce291eb077eb9208ccf57a0030845b6`).

## Что исправлено

Аудит 1.24-dev1 подтвердил, что выбор finite world-event уже разнообразен, но визуальная раскладка каждого event-id была полностью фиксированной. На reference-сетке 41×41 текущий каталог создаёт 100 конечных сцен:

- `abandoned_camp` — 46;
- `failed_evacuation` — 4;
- `repair_breakdown` — 14;
- `feeding_site` — 24;
- `looted_convoy` — 12.

До dev2 каждая из этих сцен всегда имела один и тот же набор/раскладку prop-декора для своего типа.

Dev2 добавляет **3 deterministic cosmetic variants** для каждой из пяти finite encounter-сцен. Variant зависит только от координаты чанка и event-id и добавляет ровно два небольших существующих sprite-акцента из `world_props_v19.png`.

## Что НЕ меняется

Dev2 не меняет:

- `EncounterCatalog.event_for()` и вероятность появления событий;
- zones / min/max risk;
- enemy_count, enemy type logic и spawn ids;
- loot profile, cache id и container persistence;
- event footprint / placement / anchor selection;
- supply events / `supply_convoy`;
- faction economy, routes, projects, endgame, crisis, trading;
- High Risk и strategic items;
- named NPC roster;
- save schema **122**.

`scene_variant` — derived runtime metadata. В production save он не записывается.

## Распределение после исправления hash

Первый dev2 draft использовал слишком простой modulo-3 hash: четыре редких `failed_evacuation` случайно попадали в один cosmetic variant. Это было найдено reference-аудитом до упаковки.

Финальная decorrelated integer-mix формула на тех же 100 сценах даёт:

- abandoned_camp: `{0:14, 1:22, 2:10}`;
- failed_evacuation: `{0:1, 1:1, 2:2}`;
- repair_breakdown: `{0:6, 1:5, 2:3}`;
- feeding_site: `{0:11, 1:10, 2:3}`;
- looted_convoy: `{0:3, 1:6, 2:3}`.

То есть все пять event-id реально используют все три варианта на reference-world sample.

## QA

Добавлены:

- `tests/test_encounter_scene_variety_124.gd`;
- `tests/test_encounter_scene_variety_runtime_124.gd`;
- `tests/test_encounter_scene_variety_save_runtime_124.gd`;
- `tests/qa_encounter_scene_variety_capture.gd`.

Подробности: `QA_1240_DEV2_ENCOUNTER_SCENE_VARIETY.md`.

Runtime Godot 4.7.2 gate остаётся **PENDING** в текущей среде: исполняемого Godot здесь нет. Статические/reference PASS не выдаются за engine PASS.

## Roadmap

`1.24.0 World Content Final Pass` остаётся **В РАБОТЕ**. Dev1 закрыл повторяемость procedural-building dressing; dev2 закрывает повторяемость finite encounter-scene dressing. Следующий шаг — финальный audit minor POI/world-content, без перехода к 1.25 до завершения 1.24.
