# OSTATOK 1.25.0-dev2 — Authored POI Traces

Второй срез этапа **1.25.0 Narrative & Environmental Storytelling**.

База: **1.25.0-dev1 Environmental Storytelling Foundation** (`SHA-256 8e1b2915932c1cf1a733d1a73744d330e74ebbe7b5d90b4904bf6926504e1275`).

## Что добавлено

Добавлен `world/poi_story_catalog.gd`: по одной уникальной служебной записи в восьми обычных authored compound-POI:

- ГСК «Север» — наряд на ремонт;
- Промкомбинат №7 — сменный лист;
- Железнодорожное депо — лист диспетчера;
- СНТ «Заря» — объявление правления;
- Районная больница — лист приёмного отделения;
- Районный отдел полиции — журнал дежурной части;
- Охотничий кордон «Сосны» — журнал кордона;
- Военный КПП «Восток» — приказ караулу.

Dev2 переиспользует reader/interaction/chronicle dev1. Новая запись появляется только в одном authored cell своего POI и после первого чтения сохраняется в существующем `faction_state.world_chronicle.story_seen`.

## Почему только 8

Цель — environmental storytelling, а не коллекционный чеклист. Поэтому:

- стартовая поликлиника не заполняется дополнительной запиской;
- faction settlements не получают случайных документов;
- High Risk намеренно оставлен отдельным следующим narrative-срезом;
- один POI получает одну значимую trace, а не документ в каждом секторе.

## Что НЕ меняется

Dev2 не меняет:

- `PoiCatalog` / `RegionCatalog` и физические footprints POI;
- buildings, doors, collision, navigation;
- loot/container ids, target farming или enemy semantics;
- encounter selection;
- economy, routes, projects, endgame, supply/crisis, trading;
- High Risk / strategic items;
- named NPC roster;
- production save schema **122**;
- graphical assets.

## Geometry QA

Все 8 positions проверены против authored building rectangles с 12 px margin, loose containers, props и workbenches. Пересечений — **0**. Поздний `_dress_major_poi()` также проверен: fixed/random set-pieces занимают другие зоны выбранных cells.

## QA

Добавлены:

- `tests/test_poi_storytelling_125.gd`;
- `tests/test_poi_storytelling_runtime_125.gd`;
- `tests/test_poi_storytelling_save_runtime_125.gd`;
- `tests/qa_poi_storytelling_capture.gd`.

Подробности: `QA_1250_DEV2_AUTHORED_POI_TRACES.md`.

Godot 4.7.2 runtime/capture gate остаётся **PENDING** в текущей среде: исполняемого Godot здесь нет. Static/reference PASS не выдаются за engine PASS.
