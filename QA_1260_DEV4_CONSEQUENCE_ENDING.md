# QA — OSTATOK 1.26.0-dev4 Consequence Ending

## Статические / reference проверки — PASS

- Все 4 фракционных категории достигаются ожидаемыми порогами.
- Все 5 глобальных итогов достигаются ожидаемыми комбинациями.
- Supply tie-break учитывает только `closed_day > started_day && closed_day <= completion_day`.
- События до старта и после окончания сезона не попадают в consequence snapshot.
- Completion на 21-й день не фиксирует outcome до same-day supply recovery.
- Мигрированный dev3-complete save получает `resolved_day == completion_day`, а не текущий день загрузки.
- Замороженный outcome не пересчитывается после изменения ресурсов/hardship/supply history в post-game sandbox.
- Sanitizer отклоняет partial или несогласованный сохранённый outcome.
- Пять global chronicle сообщений укладываются в `WorldChronicle.TEXT_LIMIT=220`.
- Пять board-сообщений укладываются в 220 символов; максимум — 220.
- Literal `preload/load` paths новых/изменённых GDScript разрешаются.
- Delimiter/static structure новых/изменённых GDScript — clean.

## Dev3 → dev4 boundary — PASS

До документации функциональная дельта:

- changed baseline files: 6;
- added QA files: 4 system/runtime/save suites + 1 visual capture suite;
- removed files: 0.

15 protected gameplay/catalog files byte-identical dev3, включая:

- `faction_economy.gd`;
- `regional_stability.gd`;
- `supply_event_system.gd`;
- `settlement_crisis.gd`;
- `faction_endgame.gd`;
- `settlement_projects.gd`;
- contracts;
- High Risk / strategic items;
- trading;
- faction/POI/region catalogs;
- world chronicle.

Graphical PNG assets: **651/651 identical**.

Production save writer: **save_version 122**.

## Новые QA suites

- `tests/test_regional_consequence_ending_126.gd`
- `tests/test_regional_consequence_save_126.gd`
- `tests/test_regional_consequence_production_save_126.gd`
- `tests/test_regional_consequence_runtime_126.gd`
- `tests/qa_regional_consequence_capture.gd`

Production save/load suite требует изолированный `XDG_DATA_HOME` / `OSTATOK_QA_SAVE_ROOT`.

## Godot 4.7.2 runtime gate — PENDING

В текущей рабочей среде исполняемый Godot 4.7.2 недоступен. Поэтому system/runtime/production-save/capture suites подготовлены, но их фактический Godot PASS не заявляется. Clean import, `main.tscn SELFTEST` и визуальный capture также остаются PENDING до среды с Godot 4.7.2.
