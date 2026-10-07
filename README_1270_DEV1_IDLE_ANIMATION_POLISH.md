# OSTATOK 1.27.0-dev1 — Idle Animation Polish

Первый срез Character & Animation Final Pass использует уже существующие authored survivor sheets и не меняет graphical assets.

## Аудит

Проверено полное runtime-покрытие baked clips для 10 firearms и 3 melee prefixes. Для всех реально запрашиваемых `Idle / Walk / Run / RunBackwards / Strafe / Attack / TakeDamage / Taunt` файлов соответствующие weapon-specific sheets существуют.

Найден конкретный остаточный gap: `Idle2` и `Idle3` существуют для каждого firearm/melee prefix, но runtime selector всегда возвращал только `Idle`.

## Dev1

- первые 5 секунд неподвижности — обычный `Idle`;
- затем короткое окно `Idle2`;
- возврат в основной Idle;
- затем короткое окно `Idle3`;
- цикл остаётся редким, а не постоянным переключением поз;
- любое реальное действие сбрасывает idle timer:
  - движение;
  - reload;
  - weapon cycle;
  - melee swing;
  - firearm recoil;
  - hit reaction;
  - смена firearm/melee;
  - respawn.

Timer visual-only и не сохраняется.

## Осознанно не сделано

`CrouchIdle/CrouchRun` sheets существуют, но в текущей игре нет отдельного player crouch gameplay-state/input. Dev1 не добавляет новую механику crouch только ради использования art. Death flow также не меняется: это отдельное ограничение проекта.

## Не изменено

- movement speed / acceleration;
- sprint rules;
- collision;
- stealth/noise;
- combat timings;
- weapon stats;
- death/recovery;
- save schema 122;
- graphical assets.
