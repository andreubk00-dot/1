# QA — OSTATOK 1.23.0-dev12 Free-Play Handoff

## Цель

Проверить, что после завершения vertical slice игра не оставляет игрока без следующего осмысленного действия, но и не создаёт новую обязательную сюжетную цепочку. Handoff должен использовать уже существующие contracts, home/expedition journal, region map и faction reputation.

## Изменения dev12

### 1. Sandbox objective priority

`_hud_survival_objective()` после завершённого dev11 handoff теперь работает так:

1. критические survival-состояния;
2. активная экспедиция / возврат домой;
3. незавершённый authored vertical-slice beat;
4. **реальный активный контракт**;
5. если slice завершён и дома нет — `ЗАКРЕПИТЬ ДОМ`;
6. короткий `СВОБОДНЫЙ МАРШРУТ` dev11;
7. обычный home/free-play fallback.

Это не создаёт нового quest state и не меняет save schema.

### 2. Active contract HUD

`_sandbox_active_contract_objective()` берёт реально активные contracts, сортирует их детерминированно и показывает заголовок + `ContractSystem.progress_text()`. Для deadline добавляется оставшееся число дней. Контракт остаётся владельцем собственного прогресса; HUD ничего не отмечает выполненным сам.

### 3. Home/map handoff

Без закреплённого дома планирование expedition route по-прежнему недоступно, но UI теперь объясняет точную причину:

- map body: `Сначала закрепите здание: Дом / журнал. Исследовать мир можно и без плана.`;
- plan button tooltip: `Планирование маршрута требует закреплённого дома. Исследовать мир можно и без плана.`

После появления home identity возвращается обычный map planning UI.

### 4. First free-play reconnaissance

`lazaret_hospital_route` (`РАЙОННАЯ БОЛЬНИЦА`) остаётся обычным `discover_poi` contract. Изменён только `min_rep`: **25 → 10**.

Проверено:

- rep 9 — offer отсутствует;
- rep 10 — offer присутствует;
- refresh offers не меняет reputation;
- contract points to existing `district_hospital` POI;
- никаких `global_goal` / специальных sandbox marker metadata нет.

## Новые тесты

### `test_freeplay_handoff_123.gd`

**11 checks, 0 failures**:

- contract template существует;
- `min_rep == 10`;
- `kind == discover_poi`;
- correct POI id;
- no global goal;
- locked at rep 9;
- offered at rep 10;
- refresh does not mutate reputation;
- completed vertical slice survives sanitize;
- completed slice does not re-enable;
- schema bump не требуется.

### `test_freeplay_handoff_runtime_123.gd`

**13 checks, 0 failures**:

- direct `main.tscn` load;
- no-home post-slice HUD → `ЗАКРЕПИТЬ ДОМ`;
- wording explicitly allows exploration;
- map plan disabled without home;
- tooltip has correct reason;
- map body explains free exploration;
- successful-slice reputation exposes hospital reconnaissance;
- contract accepts through real `ContractSystem`;
- active contract returns to HUD;
- undiscovered progress shown;
- actual POI discovery changes progress to `ГОТОВО К СДАЧЕ`;
- no authored system pin is created;
- with home and no active contract, dev11 `СВОБОДНЫЙ МАРШРУТ` remains available.

## Regression results

Re-run during dev12 work:

- contracts **52/52**;
- contract UI **18/18**;
- contract save **10/10**;
- personal contracts **123/123**, UI **23/23**, save **17/17**;
- vertical slice **55/55**, runtime **28/28**, save **22/22**;
- recovery **39/39**, runtime **35/35**;
- dev11 post-run runtime after expected-handoff update **22/22**;
- expeditions **45/45**, expedition save **54/54**;
- field map **24/24**;
- faction relations **65/65**, save **9/9**;
- endgame save **9/9**;
- migration **15/15**, save recovery **18/18**;
- named NPC **105/105**, runtime **14/14**, save **8/8**;
- supply **35/35**, runtime **15/15**, save **8/8**;
- chronicle **14/14**, save **7/7**;
- rest **38/38**;
- crisis **31/31**, UI **8/8**;
- strategic projects **153/153**, runtime **75/75**, save **23/23**, soak **178/178**;
- High Risk mechanics **92/92**, save **17/17**, integration **170/170**, anti-farm **440/440**, visual **130/130**;
- settlements **169/169**, layout **674/674**;
- trading **512/512**;
- target farming/world layout **1324/1324**;
- world events **1819/1819**.

Historical gates remain intact:

- `test_faction_endgame_122.gd`: **87 checks, 1 failure** — only `project version must be 1.22.0 Stable`;
- `test_release_candidate_balance_122.gd`: **7891 checks, 1 failure** — only the same Stable version gate.

No historical test was rewritten to falsely mark a dev build as Stable.

## Visual QA

OpenGL/Xvfb captures:

- `freeplay_active_contract_hud.png` — active `РАЙОННАЯ БОЛЬНИЦА`, no overflow/overlap;
- `freeplay_map_no_home.png` — disabled planning has correct explanation, free exploration is explicit;
- `freeplay_map_with_home.png` — normal planning state returns after home is anchored.

No new art. Source graphics diff vs dev11: **651 identical, 0 changed, 0 added, 0 removed**.

## Release gate

Before packaging:

1. remove `.godot`;
2. full Godot 4.7.2 `--import` to completion;
3. rerun dev12 logic/runtime, updated post-run runtime, contracts/UI, High Risk visual and direct `main.tscn` self-test on fresh cache;
4. verify `project.godot`, `BUILD_VERSION.txt`, `BRANCH.txt` all equal `1.23.0-dev12`;
5. verify production save version remains **122**;
6. remove `.godot`, package, run `unzip -t`, inspect package metadata.

## Final clean import / post-import gate — завершено

Полный чистый импорт Godot 4.7.2 после удаления `.godot` потребовал два запуска из-за внешнего лимита выполнения; второй штатный `--import` завершился с **exit code 0**. В обоих import logs нет parse/resource/script loading errors. Итоговый fresh cache содержит 1343 imported resources.

На свежем кэше повторно:

- free-play handoff logic **11/11**;
- free-play handoff runtime **13/13**;
- updated dev11 post-run runtime **22/22**;
- contracts **52/52**;
- contract UI runtime **18/18**;
- field map **24/24**;
- High Risk visual/multifloor **130/130**;
- direct `main.tscn` boot: `OSTATOK 1.23.0-dev12 SELFTEST: OK`.

OpenGL/Xvfb capture также повторён на fresh cache: все три PNG записаны с result=0; resource/script errors — 0. ALSA device отсутствует в контейнере, Godot штатно использует dummy audio — это не дефект игры.

Release metadata перед упаковкой:

- `project.godot`: `1.23.0-dev12`;
- `BUILD_VERSION.txt`: `1.23.0-dev12`;
- `BRANCH.txt`: `1.23.0-dev12`;
- production payload: `save_version: 122`.
