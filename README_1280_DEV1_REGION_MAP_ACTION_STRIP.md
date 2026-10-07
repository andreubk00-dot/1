# OSTATOK 1.28.0-dev1 — Region Map Action Strip

Первый срез UI/UX Finalization.

## Проблема

Реальный 640×360 capture исследованного сектора с длинным district survey context показал, что основные действия карты `НАЗНАЧИТЬ ЦЕЛЬ / СБРОСИТЬ ПЛАН` могут начинаться ниже видимой области правого ScrollContainer. На неизвестных секторах проблема не проявлялась, поэтому это был именно overflow длинного информационного блока.

## Решение

- Основные expedition-actions вынесены из scroll-content в фиксированную полосу над нижней навигацией карты.
- Каждая кнопка получает минимум 92 px ширины.
- Информационный блок, маркеры и план вылазки по-прежнему скроллируются.
- Expedition logic, route planning, save state и gameplay не менялись.

## Совместимость

- Save schema: 122.
- Art assets: 651 PNG, изменений нет.
- Historical 1.22 Stable version gate не переписан.

Подробности — `QA_1280_DEV1_REGION_MAP_ACTION_STRIP.md`.
