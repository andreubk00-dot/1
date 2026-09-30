# OSTATOK 1.21.0-dev2 — Infected Variety / Screamer + Spitter

Вторая development-итерация 1.21 добавляет **вторую качественно отличающуюся угрозу** —
заражённого **«Плевун»** (`spitter`). Крикун из dev1 сохранён без смены роли.

## Плевун: тактическая роль

Плевун не является bullet sponge: у него меньше HP, скорость и melee damage ниже обычного заражённого.
Опасность — дальняя контролирующая атака:

- плевок возможен только при реальной видимости/chase;
- рабочая дистанция: **92–300 px**;
- windup: **~0.72 с**;
- точка попадания фиксируется **в начале windup**, а не следит за игроком;
- игрок может полностью уклониться, покинув небольшую (~25 px) зону цели;
- любой урон или stopping/stagger прерывает подготовку;
- после прерывания действует ~3.5 с cooldown, после завершённого плевка — 7.5 с;
- попадание наносит небольшой урон, снимает немного stamina и на ~2.4 с снижает скорость до 78%;
- Developer invulnerability блокирует и урон, и slow; no-aggro отменяет уже начатый windup.

Таким образом Крикун наказывает за шум/затяжной контакт и собирает группу, а Плевун заставляет
менять позицию и не позволяет безнаказанно стоять в одном безопасном углу.

## Encounter scope

В dev2 оба специальных заражённых всё ещё **не глобальные**. Их нет в `standard`, high-risk perimeter,
Clinical perimeter и Vector access. Они редки только во внутренних/core-профилях.

- Clinical сохраняет runner-heavy identity и получает немного больше Плевунов как давление длинных коридоров.
- Vector сохраняет brute-heavy identity; Плевун там заметно реже, чтобы тесные тоннели не превращались
  в spam дальних атак.

Глобальный balance pass плотности, stopping power, патронов, шума и сложности данжей ещё не начат.

## Совместимость

- Save schema: **105**, без изменений.
- Spitter slow — transient combat state и в save не пишется.
- Новых предметов нет; `ТЕСТ: ВСЕ ПРЕДМЕТЫ` не меняется.
- Loot/farming high-risk объектов 1.20 не менялись.
- Developer Mode F10 доступен только потому, что версия содержит `-dev`; Stable guard сохранён.

## QA

- Godot 4.7.2 stable official `ed1daf0bf`.
- Runtime SELFTEST: **OK**.
- Screamer suite: **48/48**.
- Spitter suite: **71/71**.
- Clinical: **332/332**.
- Vector: **399/399**.
- Spawn safety: **879/879**, `0/439` overlaps.
- Full external regression: **50/50 suites, 8755 checks, 0 failures**.
- Across external regression: **0 Godot ERROR, 0 Godot WARNING**.

Подробности: `QA_1210_DEV2/ENGINE_QA_DEV2.md`, `ROADMAP_RELEASE_RU.md`.
