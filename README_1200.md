# OSTATOK 1.20.0 — High-Risk Locations II / Endgame Dungeons — Stable

`1.20.0` фиксирует второй уровень high-risk/endgame-локаций без добавления контента 1.21.
База — принятый интеграционный кандидат `1.20.0-dev5`.

## Новые endgame-локации

- **Областной клинический комплекс №4** — открытый медицинский кампус из шести секторов,
  отдельные вход/выход, runner-heavy давление и хирургический `clinical_core`.
- **Подземный объект «Вектор»** — тесный технический узел 2×3, отдельные вход/сервисный
  выход, choke-points, brute-heavy давление и инженерный `vector_core`.

Оба объекта имеют `hard_requirements = []`: первое прохождение не требует предмета,
который можно получить только внутри того же объекта.

## Loot-risk / target farming

- Clinical core: скрытый cooldown 12 игровых дней.
- Vector core: скрытый cooldown 14 игровых дней.
- Обновляется только глубокое ядро; промежуточные контейнеры конечные.
- Пользовательские вещи не перезаписываются.
- После refresh восстанавливается defeated-state соответствующей локации.
- Два cooldown независимы и сохраняются через `loot_refresh_sites`.
- Save schema остаётся **105**.

## Discovery-first

Карта показывает обнаруженное место и опасность, но не раскрывает loot profile,
содержимое core, точный cooldown или оптимальный маршрут.

## Developer Mode

Код QA-панели F10 остаётся в проекте для следующих development-веток, но Stable-версия
`1.20.0` не содержит `-dev`, поэтому developer tools автоматически отключены: F10 action,
HUD-кнопка, неуязвимость, no-aggro и dev-телепорты в обычной Stable-игре недоступны.

## Проверка Stable

- Godot 4.7.2 stable official `ed1daf0bf`.
- Runtime SELFTEST: **OK**.
- Full external regression: **48/48 suites, 8635 checks, 0 failures**.
- Godot log cleanliness across regression: **0 ERROR, 0 WARNING**.
- Developer release-guard suite: **95/95**.
- Save schema: **105**.
- Import-safe startup guard сохранён.

Подробности: `QA_1200/ENGINE_QA_STABLE.md`, `RELEASE_1200_STABLE.md`, `ROADMAP_RELEASE_RU.md`.
