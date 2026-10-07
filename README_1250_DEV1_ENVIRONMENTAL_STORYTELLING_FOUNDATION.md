# OSTATOK 1.25.0-dev1 — Environmental Storytelling Foundation

Первый срез этапа **1.25.0 Narrative & Environmental Storytelling**.

База: **1.24.0-dev3 Minor POI Final Pass** (`SHA-256 1917ef1f4b1093a64d018fbde07759edc6eb69280a75d555bdcb4d1103ac177d`).

## Что добавлено

В существующие deterministic finite encounters текущей карты добавлен первый редкий authored narrative layer: **8 уникальных читаемых traces**.

Они размещены только в заранее проверенных encounter-чанках, не занятых authored POI:

- 2 записи в брошенных лагерях;
- 1 журнал брошенной ремонтной бригады;
- 2 документа у разгромленных колонн;
- 3 записи на местах недавних схваток.

Каждая запись имеет стабильный story id, короткий interaction prompt и небольшой существующий atlas-prop (`paper_stack` / `newspapers`). Это physical world traces, а не новые quest markers.

## Полевой журнал

`world/world_chronicle.gd` расширен kind `story` и вложенным списком `story_seen`.

При первом чтении запись:

- показывается через существующий transient survival feedback;
- один раз попадает в **ЭФИР / ПОЛЕВУЮ ХРОНИКУ**;
- помечается как прочитанная;
- сохраняется внутри уже существующего `faction_state.world_chronicle`.

Повторное чтение не плодит записи в истории.

Старые schema-122 saves, где `story_seen` отсутствует, мигрируют в пустой список через существующий sanitize/ensure path. Новый top-level save object не добавлялся.

## Что намеренно НЕ добавлено

Dev1 не создаёт:

- квесты, цели и quest arrows;
- награды, репутацию или предметы за чтение;
- новые маршруты или route unlocks;
- новые enemy/loot/container/spawn semantics;
- глобальную цель или «путь наружу»;
- новых NPC;
- новые графические assets.

## Presentation safety

Все 8 clue positions проверены внутри encounter footprints. После ручного scene-аудита позиции разведены от базового и dev2 cosmetic-декора: минимальный center clearance — **22 px**.

## Compatibility

- Production save schema: **122**, unchanged.
- Named NPC roster: **16 unique**, 4 × 4 factions.
- Existing Encounter/Region/POI/economy/contracts/High Risk/projects/endgame/supply/trading/save-store gameplay files остаются byte-identical baseline dev3.
- Source PNG: **651/651 byte-identical** baseline dev3.
- Historical 1.22 Stable version gates не переписывались.

## QA

Добавлены:

- `tests/test_environmental_storytelling_125.gd`;
- `tests/test_environmental_storytelling_runtime_125.gd`;
- `tests/test_environmental_storytelling_save_runtime_125.gd`;
- `tests/qa_environmental_storytelling_capture.gd`.

Подробности: `QA_1250_DEV1_ENVIRONMENTAL_STORYTELLING_FOUNDATION.md`.

Godot 4.7.2 runtime/capture gate остаётся **PENDING** в текущей среде: исполняемого Godot здесь нет. Static/reference PASS не выдаются за engine PASS.
