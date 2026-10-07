# OSTATOK 1.23.0-dev17 — Established Route Map

Dev17 продолжает этап **1.23 Map Structure & Exploration Goals** после sandbox route/economy проходов dev13–dev16. До этой версии открытый маршрут уже влиял на ресурсы, торговцев, NPC и радио, но полевая карта не сохраняла его как часть изученной структуры мира: на ней была только временная линия текущей экспедиции.

## Что изменено

Открытые **географические** маршруты теперь отображаются на полевой карте как тонкие приглушённые пунктирные связи между поселением фракции и уже обнаруженным POI.

Карта строит этот слой только из уже существующих данных:

- `faction_state.world_routes`;
- authored `ContractCatalog`;
- `FactionCatalog.settlement_id`;
- `RegionCatalog` coordinates;
- `discovered_pois` игрока.

Нового persistent state нет.

При выборе одного из концов связи правая панель показывает строку вида:

`Налаженный маршрут: ПЕРРОН ↔ СНТ «ЗАРЯ»`

Она не показывает:

- loot profile;
- spawn chance;
- target-farm cooldown;
- daily resource gain;
- restock multiplier;
- «правильный» путь через промежуточные сектора.

## Не navigation arrow

Established route и expedition route остаются разными слоями:

- established route — память о уже налаженной связи;
- expedition route — текущая назначенная цель игрока.

Постоянная связь не создаёт `target`, не активирует expedition и не меняет `_navigation_target_chunk()`.

Линия не имеет стрелок и промежуточных waypoints. Если оба её конца находятся вне текущего окна карты, сегмент не рисуется: это не должно выглядеть как точно разведанная дорога через неизвестную местность.

## Discovery-first

Маршрут появляется только когда:

1. route record имеет `state = open`;
2. authored contract явно содержит конкретный `poi_id`;
3. игрок знает и исходное поселение, и целевой POI.

Если legacy/corrupt save содержит открытый route, но не содержит knowledge о POI, dev17 не раскрывает его координаты.

Если старый route record не содержит `source_contract`, карта безопасно восстанавливает presentation через уникальный authored route id. Save при этом не переписывается.

## Что намеренно НЕ рисуется

Абстрактные финальные логистические сети без конкретного `poi_id` не получают выдуманную географию. Например, `route_perron_civilian_exchange` или `route_lazaret_medical_network` продолжают работать механически, но карта не проводит для них произвольную линию.

Если несколько outcomes усиливают одну и ту же физическую связь, одинаковые endpoints дедуплицируются в один map-link. Карта показывает географию, а не количество экономических stack-источников.

## Совместимость

- Save schema: **122**, без изменений.
- Новый save-block не добавлен.
- Dev14/dev15/dev16 open routes остаются совместимыми.
- Multi-Route Economy dev16 не менялась.
- Route consequences dev15 не менялись.
- Contract completion/rewards не менялись.
- High Risk access, strategic items, target farming, projects и faction endgame не менялись.
- Named NPC roster: прежние 16 NPC.
- Глобальная цель «выход из региона» не добавлялась.

## QA

Добавлены:

- `tests/test_established_route_map_123.gd` — authored projection, discovery-first, legacy fallback, no economy leak, endpoint dedupe;
- `tests/test_established_route_map_runtime_123.gd` — map snapshot/UI detail и separation от active expedition route;
- `tests/test_established_route_map_save_runtime_123.gd` — production schema 122, reconstruct-after-load, dev15-style route fallback без save mutation;
- `tests/qa_established_route_map_capture.gd` — визуальный capture четырёх starter links на полевой карте.

Финальный runtime/visual gate требует Godot **4.7.2 stable**. В текущем execution environment native Godot binary недоступен, поэтому новые Godot suites и capture не помечаются как PASS до реального запуска.

## Графика

Source art не менялся: dev16 → dev17 **651 PNG / changed 0 / added 0 / removed 0**. Изменение карты реализовано только drawing/UI code.
