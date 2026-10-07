# QA — OSTATOK 1.23.0-dev10 Clinical Run Polish

Engine: **Godot 4.7.2 stable** (`ed1daf0bf`).

## Результаты до финального clean import

- Dev10 clinical polish logic: **23/23**.
- Dev10 clinical polish runtime: **16/16**.
- Vertical slice: **55/55**.
- Vertical slice runtime: **28/28**.
- Vertical slice save runtime: **22/22**.
- Failed-run recovery: **39/39**.
- Failed-run recovery runtime: **35/35**.
- Failed-run recovery save runtime: **17/17**.
- High Risk mechanics: **92/92**.
- High Risk mechanics production save: **17/17**.
- High Risk integration: **170/170**.
- High Risk anti-farm 30/60/180: **440/440**, 57 cycles.
- High Risk visual/multifloor: **130/130**.
- Target farming / world layout: **1324/1324**.
- Contracts: **52/52**, runtime UI **18/18**.
- Supply events: **35/35**, runtime **15/15**.
- Settlement runtime: **169/169**; crisis **31/31**, crisis UI **8/8**, layout **674/674**.
- Trading economy: **512/512**.
- Personal contracts: **123/123**, UI **23/23**, soak **31/31**.
- Strategic projects: **153/153**, runtime **75/75**, soak **178/178**.
- World events: **1819/1819**.
- Named NPC: **105/105**, runtime **14/14**, production save **8/8**.
- World Chronicle: **14/14**, production save **7/7**.
- Rest/midnight: **38/38**.
- Release-candidate save migration: **15/15**.
- Release-candidate balance: **7890 mechanical checks pass**; the one deliberate failing assertion is the historical release gate requiring project version `1.22.0 Stable` instead of the intentional dev version.

## Найденные и исправленные дефекты dev10

1. Обязательный первый вертикальный маршрут имел 29 authored enemies (7/10/12), слишком агрессивный для стартового среза. Первый цикл теперь 5/7/9, поздняя игра остаётся 7/10/12.
2. После уменьшения floor-2 spawn count старый floor-clear gate мог бы ждать исходные 10 целей. Spawn и clear-gate теперь используют один effective count.
3. Статус `clinical_cargo_secured` был липким: игрок мог потратить нужные для заказа медикаменты, а HUD продолжал вести к невозможной сдаче. Флаг теперь пересчитывается по фактическому грузу до завершения контракта.
4. Глубокий маршрут не гарантировал, что игрок найдёт одну полностью валидную комбинацию аварийного заказа. Одноразовый хирургический резерв на 3 этаже теперь гарантирует 4 sterile bandage + 3 painkillers.
5. Финальный onboarding objective был фактически недостижим после `enabled=false`. Добавлено короткое completion acknowledgement на два игровых дня.
6. Контрактный status change во время клиники мог потенциально переключить first-run budget обратно на full authored count. Теперь баланс привязан к незавершённому vertical slice после первого supply outcome.
7. Старый runtime QA ожидал `ВЕРНУТЬСЯ В ЛАЗАРЕТ`, хотя фикстура физически находилась в Лазарете с полным грузом. Тест исправлен на реальный `СДАТЬ АВАРИЙНЫЙ ЗАКАЗ`; игровой код не откатывался.

## Visual QA

OpenGL3 + Xvfb engine captures выполнены для 2 и 3 этажей клиники. Обе сцены рендерятся без resource/script errors; HUD и floor-name панель не перекрывают игровое поле критически. Runtime-тест отдельно валидирует новые transition labels. ALSA в headless окружении недоступна, Godot штатно использовал dummy audio driver; это не ресурсная/игровая ошибка.

Raster comparison с dev9: **651/651 идентичны побайтово**.

## Финальный clean-import gate

Перед упаковкой `.godot` удаляется полностью, затем проект заново импортируется Godot 4.7.2. После импорта повторяются dev10 logic/runtime, vertical slice save, recovery save, High Risk visual и self-test. Итоговые значения дописываются ниже после прогона.

### Финальный post-import результат

- Godot 4.7.2 `--import`: **exit code 0**; imported cache содержит **1342** файлов; parse/resource/script errors: **0**.
- Dev10 clinical polish logic: **23/23**.
- Dev10 clinical polish runtime: **16/16**.
- Vertical slice production save: **22/22**.
- Failed-run recovery production save: **17/17**.
- High Risk visual/multifloor: **130/130**.
- Built-in `--qa-selftest-exit`: **failures=0** (`OSTATOK 1.23.0-dev10 SELFTEST: OK`).
- `project.godot`, `BUILD_VERSION.txt`, `BRANCH.txt`: **1.23.0-dev10**.
- Production payload still writes `save_version: 122`.
