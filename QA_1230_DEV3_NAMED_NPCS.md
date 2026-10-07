# OSTATOK 1.23.0-dev3 — QA report

Движок: **Godot 4.7.2.stable.official**.

## Импорт и загрузка проекта

Перед тестами выполнен чистый импорт ресурсов Godot 4.7.2. После финальных правок повторный editor import завершился без `ERROR` / `SCRIPT ERROR`.

Реальная `main.tscn` также запускалась в headless режиме, а встроенный self-test завершился:

`OSTATOK 1.23.0-dev3 SELFTEST: OK`

Save schema остаётся **122**.

## Новый NPC-слой

- `test_named_npc_state_123.gd` — **105 checks, 0 failures**;
- `test_named_npc_runtime_123.gd` — **14 checks, 0 failures**;
- `test_named_npc_save_runtime_123.gd` — **8 checks, 0 failures** в отдельном `XDG_DATA_HOME`.

Проверены 16 канонических NPC, sanitization повреждённых данных, статусы, доступность услуг, отношение, лимит истории, runtime spawn/despawn, wounded marker, trader/contract gating, разговоры, world chronicle и production save/load.

## Регрессии ключевых систем

После dev3 и финального исправления temporary supply NPC:

- world chronicle — **14/14**;
- world chronicle save/load — **7/7**;
- rest/day rollover — **38/38**;
- faction settlement runtime — **159/159**;
- contract UI runtime — **18/18**;
- contract save/load — **10/10**;
- trader UI runtime — **16/16**;
- supply event runtime — **15/15**;
- supply event save/load — **8/8**;
- faction relations — **65/65**, save/load **9/9**;
- faction endgame save/load — **9/9**;
- expeditions — **45/45**, save integration **54/54**;
- release-candidate save migration — **15/15**;
- save recovery — **18/18**;
- trading economy — **512/512**;
- settlement crisis — **31/31**;
- settlement layout — **674/674**;
- target farming/world layout — **1324/1324**;
- loot rarity/risk — **788/788**;
- spawn safety — **853/853**;
- world events/encounters — **1819/1819**;
- infected navigation — **17/17** (ускоренный QA tick через `--fixed-fps 240`).

## High Risk / графический QA

Обнаружен и исправлен дефект dev1: `tools/wa_hr_buildings.py` содержит авторскую модель `c_reception`, а README требует `hr_clinic_00_b0`, но в приложенном клиническом atlas/catalog эта модель отсутствовала.

После восстановления модели и переимпорта:

- reception model — **10/10**;
- High Risk visual/multifloor — **130/130**;
- High Risk locations — **373/373**;
- High Risk II integration — **170/170**.

Также выполнен реальный OpenGL render-capture клинического комплекса через `xvfb-run` + `opengl3`: обзор и 12 gameplay-кадров всех шести секторов. Приёмный корпус отображается, вход центрирован; ошибок ресурса/atlas при захвате нет. ALSA в контейнере недоступна, поэтому при графическом capture Godot ожидаемо переключился на dummy audio — к игре это не относится.

Все **651** source PNG/JPG/WebP/BMP файла успешно проходят декодирование Pillow; повреждённых изображений не найдено.

## Исторические тесты, которые намеренно не являются зелёными в dev-ветке

Часть старых release-gate тестов жёстко требует конкретную прежнюю версию (`1.21 Stable` или `1.22.0 Stable`) и/или отключённые developer tools Stable-сборки. Их проверки механики проходят, но сам version gate ожидаемо красный на `1.23.0-dev3`:

- `test_developer_mode.gd` — 3 assertions о `1.22.0 Stable` / Stable developer-mode;
- `test_encounter_balance_1210.gd` — 1 version assertion;
- `test_faction_endgame_122.gd` — 1 Stable version assertion;
- `test_infected_variety_carrier.gd` — 1 version assertion;
- `test_infected_variety_screamer.gd` — 1 version assertion;
- `test_infected_variety_spitter.gd` — 1 version assertion;
- `test_release_candidate_balance_122.gd` — 1 Stable version assertion;
- `test_stable_release_gate_122.gd` — 4 assertions о Stable version/developer UI.

Эти тесты намеренно **не переписаны под dev3**, чтобы не уничтожать исторический release gate. Например `test_release_candidate_balance_122.gd` выполняет 7891 проверку и имеет только один ожидаемый fail — требование `1.22.0 Stable`.

## Найденная dev3-регрессия и её закрытие

Первый полный прогон поймал реальный fail `test_supply_event_runtime_122.gd`: свежий distress convoy потерял двух временных faction NPC. Причина — новый named-NPC filter воспринимал `supply_<event>_<n>` как неизвестных постоянных NPC.

Исправление: `FactionNpcState` применяется только к ID из канонического roster; временные faction NPC по-прежнему принадлежат своим runtime-системам. После исправления supply-event runtime снова **15/15**, named NPC runtime **14/14**, settlement runtime **159/159**.

## Команды повторного прогона

Быстрые тесты:

```bash
godot --headless --fixed-fps 240 --path . --script tests/test_named_npc_state_123.gd
godot --headless --fixed-fps 240 --path . --script tests/test_named_npc_runtime_123.gd
godot --headless --fixed-fps 240 --path . --script tests/test_supply_event_runtime_122.gd
godot --headless --fixed-fps 240 --path . --script tests/test_high_risk_reception_model.gd
godot --headless --fixed-fps 240 --path . --script tests/test_high_risk_visual_multifloor.gd
```

Save/load тесты запускать с отдельным каталогом:

```bash
QA_ROOT=/tmp/ostatok_qa_dev3
mkdir -p "$QA_ROOT"
XDG_DATA_HOME="$QA_ROOT" OSTATOK_QA_SAVE_ROOT="$QA_ROOT" \
  godot --headless --fixed-fps 240 --path . --script tests/test_named_npc_save_runtime_123.gd
```
