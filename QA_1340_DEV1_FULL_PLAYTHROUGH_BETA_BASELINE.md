# QA — 1.34.0-dev1 Full Playthrough Beta Baseline

Godot: 4.7.2 stable.

## Full playthrough
- supported: 196/196
- strained: 197/197
- unsupported: 197/197

Проверено:
- новый старт и onboarding;
- vertical slice;
- 4 starter routes;
- 4 settlement projects;
- 4 faction endgame chains;
- Regional Stability 100%;
- ручной запуск Crisis Season;
- 21 дней сезонного давления;
- разные consequence outcomes для разных стилей;
- post-ending sandbox;
- production save/reload schema 122;
- frozen outcome после reload.

## Current gates
- High Risk current-version suite: 130/130
- main.tscn selftest: OSTATOK 1.34.0-dev1 SELFTEST: OK

## Release boundary
- production GDScript changes vs 1.33: 1 file (main_script_mod.gd)
- gameplay delta: только динамический window title
- PNG: 651/651 byte-identical
- save schema: 122

Known QA note: некоторые headless runs оставляют Godot cleanup warnings о ресурсах при мгновенном завершении SceneTree; функциональные тесты завершаются без failures.
