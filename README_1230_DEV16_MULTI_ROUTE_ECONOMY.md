# OSTATOK 1.23.0-dev16 — Multi-Route Economy

Dev16 проверяет зрелый sandbox, где одновременно работают несколько постоянных маршрутов, settlement projects и faction endgame. Правка намеренно не меняет отдельные route-бонусы, restock-множители или аварийные recovery-механики: проблема оказалась именно в суммировании нескольких ежедневных пассивных источников abstract resources.

## Что показал soak до правки

Dev15 не перемножал daily-resource бонусы маршрутов друг на друга, однако несколько независимых пассивных источников складывались после ежедневного расхода. На реальных faction resource biases и authored route/endgame/project значениях это приводило к долгому удержанию части ресурсов на абсолютном `100` даже без участия игрока.

В 365-дневной reference-симуляции dev15:

- только четыре starter routes: security Перрона сидит на `100` 274 дня, security Рубежа — 108 дней;
- routes + projects: Перрон security 274, Рубеж security 280, Mechanics technical 273, Lazaret medicine 116 дней на `100`;
- routes + endgame: Перрон security 284, Рубеж security 316, Mechanics technical 324, Lazaret medicine 316;
- routes + projects + endgame: Перрон security 284, Рубеж security 330, Mechanics technical 337, Lazaret medicine 335;
- при добавлении реальных финальных endgame routes: Рубеж security 342, Mechanics technical 348, Mechanics security 190, Lazaret medicine 348 дней на `100`.

То есть дефицит терял смысл не из-за dev15 `×1.10/×1.12` trader restock, а из-за совокупного ежедневного `daily_resources` stacking.

## Dev16 guardrail

Добавлен один агрегатный soft ceiling для **пассивной логистики**:

`PASSIVE_LOGISTICS_SOFT_CEILING = 92.0`

Порядок ежедневного расчёта теперь такой:

1. обычный расход food / medicine / technical / security;
2. фиксируется post-consumption baseline;
3. применяются все открытые `world_routes` с существующим faction-relation factor;
4. применяются faction endgame daily effects;
5. применяются completed settlement projects;
6. только совокупный положительный прирост пунктов 3–5 ограничивается уровнем `92`;
7. старый emergency self-supply ниже `35` выполняется после guardrail и не режется им.

Если direct gameplay action поднял ресурс выше `92`, значение не переписывается мгновенно: обычный daily consumption постепенно опускает его вниз. Пассивная инфраструктура просто не может бесконечно возвращать верхушку шкалы к `100`.

## Что НЕ режется

Guardrail не применяется к прямым действиям игрока и аварийному восстановлению:

- обычные contract resource rewards;
- crisis contract recovery (`+18` нужного ресурса);
- supply-event success recovery;
- trading resource effects;
- emergency self-supply ниже `35`;
- one-shot route opening stock dev15.

Поэтому успешный supply/crisis recovery по-прежнему может поднять ресурс выше `92` и вплоть до `100`.

## Restock и цены

Dev16 не меняет существующие коэффициенты рынка:

- starter route: `×1.12` для Перрона / Лазарета / Механиков, `×1.10` для Рубежа;
- completed settlement project: `×1.06`;
- faction endgame restock: существующие `×1.20` / `×1.25`;
- SettlementCrisis, faction specialization, faction relations, reputation и market pressure остаются прежними.

Новый 365-day soak использует реальный `TradingMarket.restock_all()`, реальные buy/sell prices и отдельный active-buying сценарий, который ежедневно выкупает профильные товары.

## Новые QA-сценарии

Добавлены:

- `tests/test_multi_route_economy_123.gd` — локальная механика cap, direct recovery, restock stacking, migration;
- `tests/test_multi_route_economy_runtime_123.gd` — реальные day rollovers через main scene;
- `tests/test_multi_route_economy_save_runtime_123.gd` — production save/load schema 122 и dev15 migration;
- `tests/test_multi_route_economy_soak_123.gd` — 30/60/180/365 дней для routes-only, routes+projects, routes+endgame, full stack, real final endgame routes, supply failures/crises, active buying и passive waiting.

Soak также воспроизводит реальные relation outcomes faction endgame, потому что они меняют эффективность shared routes.

## Совместимость

- Production save schema остаётся **122**.
- Новый persistent save-блок не добавлен.
- Старый dev15 save не переписывает сохранённые resources при загрузке; новая логика начинает действовать только на следующих daily ticks.
- Старые открытые starter routes продолжают работать и не получают бесплатный dev15 opening package.
- Settlement Project `reserve floor 45`, emergency threshold `35`, contribution batch `12`, min reputation `75` не менялись.
- High Risk access, strategic item access, target farming `loot_refresh_sites`, incident IDs и anti-farm не менялись.
- Именованный NPC roster не менялся.
- Глобальная цель «выход из региона» не добавлялась.

## Графика

UI и source-art в dev16 не менялись. Сравнение с dev15: **651 PNG → 651 PNG, changed 0, added 0, removed 0**.

## Release gate

Финальная сертификация должна выполняться именно Godot **4.7.2 stable**: новые system/runtime/save/soak tests, широкая регрессия, clean import, `main.tscn` selftest и проверка release ZIP. Historical version gate `1.22.0 Stable` остаётся намеренно неизменным.
