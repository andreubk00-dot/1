# OSTATOK 1.21.0-dev1 — Infected Variety & Encounter Balance / Screamer Foundation

Первая development-итерация 1.21 добавляет **одну** новую качественно отличающуюся угрозу —
заражённого **«Крикун»** (`screamer`). Это не HP-вариант и не глобальный рост сложности.

## Тактическая роль

Крикун слабее обычного заражённого в прямом бою: меньше HP, ниже melee damage и умеренная скорость.
Его опасность — **телеграфированный alarm call**:

- вызов начинается только при реальном chase/видимости игрока;
- перед криком есть ~0.78 с windup, во время которого Крикун останавливается и визуально пульсирует;
- любой урон или stopping/stagger impact прерывает вызов;
- после прерывания действует 5.5 с anti-spam cooldown;
- успешный крик имеет 13 с cooldown и сильный AI-hearing радиус;
- окружающие заражённые идут **исследовать источник крика**, а не получают позицию игрока «телепатически».

Это создаёт новый выбор: тихо обойти, быстро сфокусировать Крикуна или потратить stopping-power,
чтобы сбить вызов и выиграть время.

## Где появляется в dev1

Крикун пока не добавлен в обычные `standard` encounters, high-risk perimeter, Clinical perimeter
или Vector access. Он редок и появляется только в authored high-risk interior/core профилях.
Существующие идентичности сохранены: Clinical core остаётся runner-heavy, Vector core — brute-heavy.

Большой баланс плотности, шума, stopping power, патронов и всех данжей **ещё не выполнен** — это
следующие dev-итерации 1.21.

## Совместимость

- Save schema остаётся **105**.
- Новых предметов нет, поэтому QA-каталог `ТЕСТ: ВСЕ ПРЕДМЕТЫ` не меняется.
- 1.20 loot/farming/persistence не менялись.
- Developer Mode F10 снова доступен, потому что версия содержит `-dev`; release guard по-прежнему
  отключает его, если версия становится Stable без `-dev`.

## QA

- Godot 4.7.2 stable official `ed1daf0bf`.
- Runtime SELFTEST: **OK**.
- Screamer suite: **48/48**.
- Developer Mode: **96/96**.
- Full regression: **49/49 suites, 8684 checks, 0 failures**.
- Across external regression: **0 Godot ERROR, 0 Godot WARNING**.
- Spawn safety: **879/879**, existing world overlap contract unchanged.

Подробности: `QA_1210_DEV1/ENGINE_QA_DEV1.md`, `ROADMAP_RELEASE_RU.md`.
