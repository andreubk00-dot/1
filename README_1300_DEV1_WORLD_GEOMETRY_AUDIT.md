# OSTATOK 1.30.0-dev1 — World Geometry Audit

Первый срез финального Visual & World Geometry QA. Это намеренно QA-first релиз: геометрия мира не менялась, потому что runtime-аудит не подтвердил production-дефектов.

## Что проверено

Новый `test_world_geometry_final_audit_130.gd` строит реальные чанки через production `_build_procedural_chunk()` и охватывает обычный мир плюс все authored POI footprint-cells. Проверяются:

- границы building footprint;
- отделение procedural building от публичной дороги;
- пересечения процедурных зданий;
- автомобили: bounds, building/car overlap, z-order;
- деревья: bounds, road/sidewalk для procedural мира, фактический building clipping;
- street furniture;
- finite world-event footprints;
- door collision body/shape и z-order.

Итог на Godot 4.7.2: **6232/6232**, 106 чанков, 85 authored cells, минимум один finite event.

## Почему геометрия не правилась

Первый вариант QA дал 21 срабатывание. Разбор показал два неверных предположения теста:

- authored settlements используют собственный асимметричный door/facade-aware clearance для деревьев, а не procedural 24 px guard;
- High Risk exterior models намеренно объединяют основную архитектурную массу с пристройками/постами, поэтому их presentation-envelope нельзя трактовать как независимые procedural дома.

Существующий authored-layout regression остаётся строгим к gameplay footprint. Дополнительные captures карантинного центра и объекта «Вектор» подтвердили, что стыкующиеся массы визуально читаются корректно и не перекрывают основные проходы.

## Boundary

- save schema: **122**;
- gameplay geometry: без изменений;
- PNG: без изменений;
- historical 1.22 version gates: без изменений;
- новых механик нет.
