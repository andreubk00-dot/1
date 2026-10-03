# OSTATOK 1.23.0-dev1 — High Risk Visual Rework

База: `OSTATOK 1.22.0 Stable`.

Это первый проход нового визуального пайплайна для High Risk зон. Вместо очередного процедурного здания в игру внедрена утверждённая пользователем 3D-мастер-модель `OSTATOK_HR_medical_entry_v03.glb`.

## Что внедрено

- объект: `ОБЛАСТНОЙ КЛИНИЧЕСКИЙ КОМПЛЕКС №4`;
- сектор: входной `0,0`;
- здание: `building_0 / ПРИЁМНЫЙ КОРПУС`;
- мастер-модель: `art/high_risk/medical_entry_v03/OSTATOK_HR_medical_entry_v03.glb`;
- модель остаётся исходником, а в 2D gameplay используются слои, отрендеренные именно из неё;
- внешний вид разделён на roof/upper и facade/lower, поэтому существующая логика перекрытия игрока и fade крыши продолжает работать;
- интерьер первого этажа использует top-down render из той же модели;
- внутренние collision-стены перенесены по исходному плану модели 24×16 м: коридор, триаж/приём, задние помещения и дверные разрывы совпадают с визуалом;
- главный вход теперь физически центрирован, как на принятой модели;
- существующие building/container ids, лут и save schema не менялись.

## Визуальная целостность

Все `644` существующих source image-файла из 1.22.0 Stable побайтно не изменены. Новая графика добавлена отдельным пакетом `art/high_risk/medical_entry_v03/`.

## Проверка

Выборочный regression систем, затронутых High Risk интеграцией:

- `test_high_risk_medical_model_v03.gd` — 11/11;
- `test_high_risk_locations.gd` — 373/373;
- `test_high_risk_locations_ii_skeleton.gd` — 26/26;
- `test_high_risk_locations_ii_integration.gd` — 170/170;
- `test_high_risk_visual_multifloor.gd` — 130/130;
- `test_clinical_complex_endgame.gd` — 368/368;
- `test_world_content_poi.gd` — 267/267.

Итого: `1345` проверок, `0` failures.

Godot 4.7.2 runtime smoke: `OSTATOK 1.23.0-dev1 SELFTEST: OK`.

## Скриншоты из реального runtime

- `screenshots/hr_medical_v03_ingame_exterior.png` — игровой zoom, фасад/вход;
- `screenshots/hr_medical_v03_ingame_interior.png` — интерьер при сработавшем roof fade;
- `screenshots/hr_medical_v03_ingame_overview.png` — временно широкий camera zoom для проверки всей модели в окружении.

Следующий логичный проход: детализировать оставшиеся корпуса этого же клинического комплекса в том же пайплайне, не возвращаясь к старым процедурным коробкам.
