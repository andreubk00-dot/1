# QA — OSTATOK 1.26.0-dev5 Regional Endgame Closure

## Scope

Dev5 не меняет функциональный gameplay endgame-код. Это regression/soak closure поверх dev4.

## Подготовленные QA suites

- `tests/test_regional_endgame_soak_126.gd`
- `tests/test_regional_endgame_closure_126.gd`

Soak использует production-модули:

- `FactionEconomy.daily_tick()`;
- real `ContractCatalog` starter routes;
- `SettlementProjects`;
- `FactionEndgame` + реальные relation effects;
- `RegionalEndgame.daily_tick()` / `resolve_outcome()`.

Проверяется:

- завершение ровно после 21 сезонного дня;
- bounds ресурсов 0..100;
- прямая поддержка не ухудшает состояние относительно idle;
- selective support защищает выбранные поселения;
- outcome существует и остаётся замороженным;
- `pressure_applied_day` не двигается после финала;
- ещё 60 sandbox-дней не запускают сезон снова;
- completed endgame нельзя повторно запустить.

## Static/release boundary

Ожидаемая functional delta dev4 → dev5: **0 gameplay files**. Разрешены только version metadata, roadmap/docs, current visual version gate и новые QA-файлы.

Save schema: **122**.

Graphical assets должны остаться 651/651 byte-identical dev4.

## Godot 4.7.2 gate — PENDING

В текущей среде нет исполняемого Godot 4.7.2, поэтому новые soak suites подготовлены, но фактический Godot PASS не заявляется. Clean import / main.tscn SELFTEST / runtime soak должны быть выполнены в среде с Godot 4.7.2.
