# OSTATOK 1.25.0-dev3 — High Risk Environmental Traces

Третий срез этапа **1.25.0 Narrative & Environmental Storytelling**.

База: **1.25.0-dev2 Authored POI Traces** (`SHA-256 6f6900b9c489ef220d92b53ae8fb80c3726cd2d6e5dbbb20c6d3a452942cc87b`).

## Что добавлено

Добавлен `world/high_risk_story_catalog.gd`: **8 уникальных читаемых traces** для четырёх уже существующих High Risk комплексов.

Для каждого комплекса:

- одна редкая наземная запись в authored sector;
- одна запись на существующем глубоком **3-м этаже/ярусе**.

Объекты:

- Областной клинический комплекс №4;
- Карантинный центр №12;
- Резервный арсенал «Бастион»;
- Подземный объект «Вектор».

Dev3 переиспользует dev1 reader/interaction и `faction_state.world_chronicle.story_seen`.

## Progression boundary

Записи не являются ключами и ничего не открывают. В catalog нет:

- reward / loot / objective / route / target semantics;
- enemy/spawn semantics;
- strategic-item ids;
- cache ids или подсказок к `cache_3`;
- access/floor-unlock flags;
- map markers.

Floor traces существуют только на **floor 3**, который игрок уже должен открыть существующей High Risk механикой. Floor 2 не получает новых traces, поэтому обязательный путь 2→3 и emergency override остаются без изменений.

## Что НЕ меняется

- `HighRiskMechanics`, `HighRiskFloorCatalog`, `HighRiskSiteCatalog`;
- floor access / emergency override;
- strategic items и first-cycle `cache_3`;
- `loot_refresh_sites` target farming;
- incident ids 5000+;
- enemy counts, containers, loot tables и repeat salvage;
- economy / contracts / projects / endgame / supply / crisis / trading;
- named NPC roster;
- production save schema **122**;
- graphical assets.

## QA

Добавлены:

- `tests/test_high_risk_storytelling_125.gd`;
- `tests/test_high_risk_storytelling_runtime_125.gd`;
- `tests/test_high_risk_storytelling_save_runtime_125.gd`;
- `tests/qa_high_risk_storytelling_capture.gd`.

Текущий High Risk visual version gate обновлён с dev2 на dev3. Historical 1.22 Stable gate не переписывается.

Подробности: `QA_1250_DEV3_HIGH_RISK_ENVIRONMENTAL_TRACES.md`.

Godot 4.7.2 runtime/capture gate остаётся **PENDING** в текущей среде: локального исполняемого Godot нет. Static/reference PASS не выдаются за engine PASS.
