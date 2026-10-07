# OSTATOK 1.27.0-dev3 — Character & Animation Final Pass

Финальный closure-срез этапа 1.27.

## Что изменено

- Gameplay/animation mapping dev2 не меняется: после реального Godot 4.7.2 runtime/capture новых дефектов переходов не найдено.
- Исправлена только диагностическая строка встроенного SELFTEST: версия теперь берётся из `application/config/version`, а не из устаревшего hardcoded `1.26.0-dev4`.
- Исправлено неверное ожидание в dev2 locomotion QA: базовый `Idle` исторически остаётся wall-clock phased; frame-0 sync относится только к authored `Idle2/Idle3`.
- Этап 1.27 помечен ГОТОВО. Animation base замораживается.

## Что намеренно НЕ менялось

- movement speed / collision / stamina;
- stealth/noise;
- weapon timings/damage/reload/cycle;
- gameplay crouch (его отдельного state/input в игре нет);
- death/recovery flow;
- save schema 122;
- art assets.

## Runtime validation

Использован предоставленный Godot 4.7.2 stable Linux x86_64.
SHA-256 движка:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

Clean import: PASS.
Main SELFTEST: PASS (`failures=0`).
Selected Godot regression: 2230/2230 checks.
Visual capture: 9 PNG через Xvfb/OpenGL llvmpipe, все capture-save calls returned OK.

Подробности: `QA_1270_DEV3_CHARACTER_ANIMATION_FINAL_PASS.md`.
