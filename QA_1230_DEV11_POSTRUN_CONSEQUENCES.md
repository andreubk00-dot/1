# QA — OSTATOK 1.23.0-dev11 Post-Run Consequences

## Цель проверки

Проверить, что финал стартового вертикального среза реально закрывается через production UI после физического изъятия груза, последствия выдаются ровно один раз, Миронова не фармится повторным диалогом, карта освобождается от системного маршрута, а schema 122 и поздняя игра не регрессируют.

## Найденный и исправленный дефект dev10

Реальная `_contract_complete_selected()` для delivery-контракта сначала удаляет предметы из `inventory_entries`, затем вызывает `ContractSystem.complete()`. Старый `VerticalSlice.refresh_progress()` до проверки `contract_history` повторно вычислял `clinical_cargo_secured` из уже пустого рюкзака. В результате настоящий UI-turn-in мог оставить `crisis_contract_completed=true`, но `clinical_cargo_secured=false`, и вертикальный срез не закрывался.

Dev11 меняет порядок:

1. сначала проверяется факт завершённого `crisis_lazaret_medicine` в contract history;
2. завершённый реальный delivery фиксирует `clinical_cargo_secured=true` как доставленный груз;
3. только пока контракт **не** закрыт, cargo milestone остаётся не-липким и отражает текущий рюкзак.

Это сохраняет антисофтлок dev10 и исправляет production UI completion.

## Post-run state

Новые поля вложены в `faction_state.vertical_slice`:

- `completion_feedback_issued` / `completion_feedback_day`;
- `doctor_debrief_seen` / `doctor_debrief_day`.

Save schema: **122, без изменения**. Sanitizer старого dev10 state добавляет поля безопасными значениями по умолчанию и не меняет ресурсы поселения.

## Новые тесты

- `test_vertical_slice_postrun_123.gd`: **31 checks, 0 failures**.
  - реальная последовательность cargo → contract complete → пустой backpack;
  - сохранение delivered-cargo milestone;
  - completion feedback idempotence;
  - Mironova debrief idempotence;
  - отсутствие post-run route marker;
  - двухдневный HUD handoff;
  - dev10 same-schema migration;
  - честный stage-aware текст при повторном дефиците.
- `test_vertical_slice_postrun_runtime_123.gd`: **21 checks, 0 failures**.
  - production contract panel;
  - фактическое удаление 4 sterile_bandage + 3 painkillers;
  - реальное завершение среза после удаления;
  - ровно одна world-chronicle запись;
  - +6 личного отношения Мироновой ровно один раз;
  - переход HUD в `СВОБОДНЫЙ МАРШРУТ`.
- `test_vertical_slice_postrun_save_runtime_123.gd`: **16 checks, 0 failures**.
  - production SaveStore;
  - schema 122;
  - idempotence flags survive load;
  - dev10 migration не меняет экономику.

## Регрессии

Пройдены:

- vertical slice 55/55; runtime 28/28;
- recovery 39/39; runtime 35/35;
- clinical polish 23/23; runtime 16/16;
- contract UI 18/18; save 10/10;
- personal contracts 123/123; UI 23/23; save 17/17;
- named NPC 105/105; runtime 14/14; save 8/8;
- world chronicle 14/14; save 7/7;
- High Risk integration 170/170;
- High Risk visual/multifloor 130/130;
- High Risk anti-farm 440/440, 57 cycles;
- target farming/world layout 1324/1324;
- faction settlements 169/169;
- settlement layout 674/674;
- settlement crisis 31/31;
- trading 512/512;
- strategic projects 153/153; runtime 75/75; save 23/23; soak 178/178;
- supply runtime 15/15; save 8/8;
- rest 38/38;
- world events 1819/1819;
- faction relations 65/65; save 9/9;
- endgame save 9/9;
- release-candidate save migration 15/15;
- save recovery 18/18.

Historical version-gated tests are not rewritten:

- `test_release_candidate_balance_122.gd`: **7891 checks, 1 failure** — only `project version must be 1.22.0 Stable`;
- `test_faction_endgame_122.gd`: **87 checks, 1 failure** — only the same stable-version gate.

## Visual QA

OpenGL 4.5 / Mesa llvmpipe under Xvfb. Audio device is absent in the container, Godot correctly falls back to dummy audio; this is not a game defect.

Captured:

- `postrun_hud_before_debrief.png` — `ПЕРВЫЙ ЦИКЛ ЗАВЕРШЁН`, text fits;
- `postrun_map_free.png` — no authored field-route marker remains;
- `postrun_hud_after_debrief.png` — `СВОБОДНЫЙ МАРШРУТ`, text fits;
- `postrun_radio.png` — consequence chronicle wraps inside panel without overlap.

Graphics source diff dev10 → dev11: **651 identical source assets, 0 changed / 0 added / 0 removed**.

## Final release gate

Before packaging:

1. remove `.godot`;
2. run full Godot 4.7.2 `--import` to completion;
3. rerun dev11 post-run logic/runtime/save, vertical-slice critical tests, High Risk visual gate and built-in selftest on the fresh cache;
4. verify `project.godot`, `BUILD_VERSION.txt`, `BRANCH.txt` all report `1.23.0-dev11`;
5. verify `save_version` remains 122;
6. remove `.godot` again, package and run `unzip -t`.

## Final clean import / post-import gate — завершено

После полного удаления `.godot` чистый импорт Godot 4.7.2 потребовал два запуска из-за внешнего лимита выполнения, затем завершился штатно с **exit code 0**. В итоговом import log: **0 parse/resource/script errors**.

На свежем кэше повторно:

- post-run logic **31/31**;
- post-run runtime **21/21**;
- post-run production save/load **16/16**;
- vertical slice **55/55**;
- failed-run recovery **39/39**;
- clinical-run polish **23/23**;
- High Risk visual/multifloor **130/130**;
- direct `main.tscn` boot: `OSTATOK 1.23.0-dev11 SELFTEST: OK`, exit code 0, script/resource errors 0.

Release metadata before packaging:

- `project.godot`: `1.23.0-dev11`;
- `BUILD_VERSION.txt`: `1.23.0-dev11`;
- `BRANCH.txt`: `1.23.0-dev11`;
- production `save_version`: **122**.
