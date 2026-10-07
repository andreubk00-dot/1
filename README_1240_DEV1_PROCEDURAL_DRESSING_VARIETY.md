# OSTATOK 1.24.0-dev1 — Procedural Dressing Variety

Первый срез этапа **1.24.0 World Content Final Pass**.

База: **1.23.0-dev18 District Survey Context** (`SHA-256 85c6ec33e05e824779c679b73ec4f17cb5e9b0d1bb5f41ea05978e2d32f89c56`).

## Что исправлено

Аудит 1.23 показал, что позиции/масштабы procedural-зданий уже меняются от сектора к сектору, но визуальная внутренняя вариативность была частично привязана к повторяющимся persistent id `building_0..building_3`. Поэтому одинаковые слоты в разных секторах могли получать слишком похожие детали пола/крыши и один и тот же набор визуальных акцентов.

Dev1 добавляет **детерминированный cosmetic-only dressing** для обычных procedural-зданий:

- жилые: `panel_block`, `panel_entry`, `utility_house`, `country_house`, `dacha`;
- торговые: `grocery`, `pharmacy`, `cafe`, `service_shop`;
- гаражные: `garage_row`, `repair_bay`;
- складские/промышленные: `workshop`, `warehouse`, `factory_admin`, `rail_store`, `rail_service`.

У каждой группы есть три небольших варианта. Вариант определяется координатой сектора + архетипом + номером persistent building-slot. Он добавляет по одному небольшому существующему визуальному акценту в интерьер, на фасад и во двор и солит уже существующий визуальный seed пола/крыши.

## Что НЕ меняется

Dev1 не меняет:

- `building_id` / `cache_0..cache_3`;
- стены, двери, окна и collision;
- размер/положение persistent building-slot;
- loot profile и контейнеры;
- rarity / spawn chances / enemy logic;
- authored major POI, faction settlements и High Risk geometry;
- named NPC roster;
- route/economy/projects/endgame/supply/crisis/trading;
- save schema **122**.

Новых графических ассетов нет: используются существующие регионы `world_props_v19.png`.

## Старые сейвы

`content_variant` и `content_seed` — только derived runtime-данные. В save они не записываются.

Сектора, помеченные старой миграцией `legacy_building_layout_chunks`, dev1-variety не получают. Это сохраняет внешний вид уже закреплённой legacy-layout территории и не «переодевает» знакомые здания после загрузки старого schema-122 save.

## Authored content boundary

Major POI / faction settlement, которые строятся через authored compound path, dev1-variety не получают. Их внешний вид остаётся авторским и не смешивается с procedural dressing.

## QA

Добавлены:

- `tests/test_world_content_variety_124.gd`;
- `tests/test_world_content_variety_runtime_124.gd`;
- `tests/test_world_content_variety_save_runtime_124.gd`;
- `tests/qa_world_content_variety_capture.gd`.

Подробности: `QA_1240_DEV1_PROCEDURAL_DRESSING_VARIETY.md`.

Runtime-сертификация Godot 4.7.2 в текущей рабочей среде остаётся **PENDING**: исполняемого Godot здесь нет, а внешний бинарник среда скачать не позволяет. Статические PASS не выдаются за engine PASS.

## Состояние roadmap

`1.23.0 Map Structure & Exploration Goals` отмечен как завершённый после dev17–dev18.

`1.24.0 World Content Final Pass` остаётся **В РАБОТЕ**: dev1 закрывает только procedural building dressing/repetition. Minor POI/event variety и финальный world-content audit ещё не объявлены завершёнными.
