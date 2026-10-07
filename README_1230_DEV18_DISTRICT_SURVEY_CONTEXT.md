# OSTATOK 1.23.0-dev18 — District Survey Context

Dev18 продолжает финальный проход **1.23 Map Structure & Exploration Goals** после dev17 Established Route Map. Dev17 вернул открытым географическим маршрутам постоянное место на полевой карте; dev18 добавляет вторую половину идентичности карты — контекст уже обследованных районов.

## Что изменено

При выборе **уже исследованного** сектора правая колонка полевой карты теперь показывает derived survey-context района:

- authored характер района из `RegionCatalog.DISTRICTS.description`;
- сколько секторов этого района игрок реально обследовал;
- какие ориентиры этого района уже обнаружены;
- сколько налаженных географических связей касается района;
- краткие подписи четырёх `outer_*` районов непосредственно на карте при достаточном количестве известных секторов.

Пример структуры:

`Район: СТАРЫЙ ЦЕНТР`

`Опасность: 2/5`

`Характер: Старая торгово-жилая застройка вокруг поликлиники и площади.`

`Обследовано секторов района: 3`

`Известные ориентиры: ПОЛИКЛИНИКА`

Dev18 не вводит рейтинг «куда лучше идти», не рекомендует loot и не оценивает экипировку игрока.

## Discovery-first

`world/region_survey_context.gd` является presentation-only helper. Он возвращает пустой контекст, если выбранный сектор не присутствует в `discovered_chunks`.

Неизвестный сектор по-прежнему показывает только:

- координаты;
- статус «НЕ ИССЛЕДОВАН»;
- возможность назначить разведывательную цель.

Для неизвестной территории не раскрываются район, authored POI, ориентиры, маршруты, риск POI или скрытая специализация места.

## Authored POI district identity

В старой карте дальние поселения могли визуально наследовать процедурный `outer_*` район только по координате, даже если сам authored POI намеренно относился к другому району.

Dev18 исправляет это **только после обнаружения POI**:

- известный POI использует свой authored `district`;
- неизвестный POI не переопределяет процедурный район и не раскрывает себя;
- тот же derived district используется для map fill/grouping и правой панели.

Это особенно важно для удалённых поселений. Например, Лазарет находится в procedural outer-rural macrocell, но его authored POI identity — `outer_residential`; после обнаружения карта показывает authored identity, до обнаружения — нет.

## Что НЕ показывается

Survey payload не содержит и UI не выводит:

- `loot` / `loot_theme`;
- `farm_profile`;
- `refresh_days`;
- `daily_resources`;
- restock factors;
- enemy/tree/car multipliers;
- building set;
- количество ещё не обнаруженных POI;
- точный путь к предмету или «правильный» маршрут.

Список ориентиров строится только из уже известных `discovered_pois`. Нет знаменателя вида `1/4`, который мог бы выдать наличие скрытых объектов.

## Совместимость

- Save schema: **122**, без изменений.
- Новых persistent blocks нет.
- `_save_state()` и `_load_state()` побитово не менялись относительно dev17.
- Expedition/navigation helpers не менялись.
- Dev17 established-route mechanics не менялись.
- Dev16 Multi-Route Economy не менялась.
- Dev15 route consequences не менялись.
- Contracts, projects, faction endgame, supply/crisis, trading и High Risk не менялись.
- Named NPC roster: прежние **16 NPC**, по 4 на фракцию.
- Глобальная цель «выход из региона» не добавлялась.

## QA

Добавлены:

- `tests/test_district_survey_context_123.gd` — discovery-first, survey counts, known landmarks, information-leak boundary, route count, authored settlement district override;
- `tests/test_district_survey_context_runtime_123.gd` — интеграция в реальную карту, unknown-sector boundary, coexistence с dev17 established links и отсутствие navigation side effects;
- `tests/test_district_survey_context_save_runtime_123.gd` — schema 122, отсутствие derived save-block и reconstruct-after-load;
- `tests/qa_district_survey_context_capture.gd` — 640×360 capture правой колонки карты.

Native Godot 4.7.2 в текущем execution environment недоступен: внешний host не резолвится, а локального бинарника нет. Поэтому Godot runtime suites/capture/selftest остаются **PENDING**, а не записываются как фиктивный PASS.

## Графика

Исходные графические ассеты не менялись: dev17 → dev18 **651 PNG / changed 0 / added 0 / removed 0**. Новые подписи окраин реализованы существующим текстовым map renderer без новых art assets.
