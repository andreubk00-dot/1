# OSTATOK 1.21.0 — Infected Variety & Encounter Balance — Stable

`1.21.0` фиксирует качественные роли заражённых и финальный encounter-balance этапа 1.21.
База — принятый `1.21.0-dev5`; Stable не добавляет новые gameplay-механики.

## Infected Variety

В дополнение к normal / runner / brute закреплены три редкие high-risk роли:

- **Крикун / Screamer** — хрупкий caller с телеграфированным и прерываемым вызовом; поднимает ближайших заражённых через hearing AI, не выдавая им позицию игрока напрямую.
- **Плевун / Spitter** — ranged-control враг с windup и фиксируемой точкой плевка; вынуждает менять позицию, но слаб в ближнем бою.
- **Носитель / Carrier** — после смерти кратковременно оставляет опасную зону; выгодно оттолкнуть или добить с дистанции.

Обычный мир и внешние/perimeter encounters не получают эти специальные роли. Они заменяют часть базовых заражённых только во внутренних/core-профилях high-risk зон.

## Encounter Balance

- Clinical сохраняет runner-heavy идентичность, Vector — brute-heavy.
- Runner слегка ограничен по скорости, Brute не превращается в bullet sponge и реагирует на stopping power.
- Screamer / Spitter / Carrier ограничены по частоте и силе chain-pressure.
- Верхние этажи high-risk объектов: 10 заражённых на промежуточном слое и 12 на глубоком/верхнем.
- Оружейные роли по шуму, урону и stopping power сохранены без расширения ассортимента.
- Новые архетипы после этого этапа в 1.21 не добавляются.

## Multi-floor high-risk foundation

Существующая многоэтажная механика high-risk объектов остаётся функциональной: отдельные игровые слои, лестничные переходы, containers/encounters и persistence. Визуальная переработка этих объектов намеренно **отложена на будущий visual/world pass** и не является условием Stable 1.21.

## Save / Developer Mode

- Save schema остаётся **105**.
- Код F10 developer tools остаётся в проекте для следующих `-dev` веток.
- В Stable `1.21.0` developer tools автоматически недоступны: F10 action, HUD-кнопка, god mode, no-aggro и dev-телепорты не активируются.

## Stable QA

- Godot 4.7.2 stable official `ed1daf0bf`.
- Runtime SELFTEST: **OK**.
- Full external regression: **53/53 suites, 9040 checks, 0 failures**.
- Godot log cleanliness across external regression: **0 ERROR, 0 WARNING**.
- Encounter Balance: **82/82**.
- Developer release-guard + isolated dev implementation regression: **96/96**.
- Screamer **48/48**, Spitter **71/71**, Carrier **73/73**.
- High-risk multi-floor **130/130**.
- Spawn Safety **879/879**; Target Farming / World Layout **1324/1324**.
- Clean imported-resource cache rebuilt with Godot 4.7.2: **1362 files**, 0 ERROR / 0 WARNING.

Подробности: `QA_1210/ENGINE_QA_STABLE.md`, `RELEASE_1210_STABLE.md`, `ROADMAP_RELEASE_RU.md`.
