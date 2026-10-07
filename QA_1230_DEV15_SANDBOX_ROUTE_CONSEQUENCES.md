# QA — OSTATOK 1.23.0-dev15 Sandbox Route Consequences

## Среда

- Godot Engine **4.7.2.stable.official.ed1daf0bf**.
- Baseline: чисто распакованный `OSTATOK_1.23.0-dev14_Sandbox_Route_Identity.zip`.
- Production save-tests, которые этого требуют, запускаются с отдельными `XDG_DATA_HOME` и `OSTATOK_QA_SAVE_ROOT`.
- Save schema остаётся **122**.

## Dev15 system QA

### Route consequence system

`test_sandbox_route_consequences_123.gd`: **87 checks, 0 failures**.

Проверено для всех четырёх starter-routes:

- faction ↔ route mapping;
- эффект отсутствует до открытия маршрута;
- профильный restock-factor: Перрон/Lazaret/Mechanics `1.12`, Rubezh `1.10`;
- unrelated category и другие фракции не получают бонус;
- четыре NPC-note и четыре radio-text различаются;
- route summary читаема;
- depleted профильный товар после forced restock возвращается сильнее, чем в baseline state;
- существующий daily route-effect продолжает улучшать профильный abstract resource — dev15 не создаёт второй resource grant;
- one-shot opening package добавляет реальные позиции в реальные trader stocks;
- повторный вызов opening package не фармится;
- `opening_stock_applied` хранится внутри существующей route-record;
- dev14 migration не выдаёт бесплатный opening package, но сразу получает derived restock effect.

### Runtime / real completion

`test_sandbox_route_consequences_runtime_123.gd`: **36/36**.

Проверено:

- разговоры NPC четырёх фракций содержат route-specific consequence и cross-faction contrast;
- реакция реально рисуется новой HUD feedback-плашкой, а не остаётся только строкой в памяти;
- chronicle получает ровно одну specific route-news;
- реальная сдача `ДОРОГА К «ЗАРЕ»` через main UI открывает route;
- ставится one-shot marker;
- trader stock действительно увеличивается;
- в эфир уходит authored Zarya-news.

### Production save / migration

`test_sandbox_route_consequences_save_runtime_123.gd`: **14/14**.

Проверено production `_save_state/_load_state`:

- `save_version == 122`;
- open route сохраняется;
- one-shot marker сохраняется;
- trader stock сохраняет opening package;
- повторная загрузка не выдаёт ещё один пакет;
- dev14-style open route без marker мигрирует без подарка, но получает ongoing market consequence.

## UI regression found and fixed

Во время dev15 OpenGL QA обнаружены два старых дефекта.

1. Trader panel был выше логического viewport и мог уходить ниже экрана. Он уплотнён до 564×336. `test_trader_ui_layout_123.gd`: **13/13**.
2. `survival_feedback` нигде не рендерился. Добавлена transient-плашка `SurvivalFeedback` 420×40; runtime test теперь проверяет её видимость и route-specific текст.

Финальный NPC capture показывает длинную реплику Тёти Гали двумя строками без обрезки. Между feedback panel и interaction prompt остаётся зазор; objective/quickbar не перекрываются.

## Regression pass

Подтверждено в dev15:

- trading economy: **512/512**;
- supply events: **35/35**, runtime **15/15**, save **8/8**;
- named NPC: **105/105**, runtime **14/14**, save **8/8**;
- faction relations: **65/65**;
- world chronicle: **14/14**, save **7/7**;
- rest/midnight: **38/38**;
- world events/encounters: **1819/1819**;
- strategic projects: **153/153**, runtime **75/75**, save **23/23**, soak **178/178**;
- High Risk mechanics: **92/92**;
- High Risk integration: **170/170**;
- High Risk anti-farm: **440/440**;
- High Risk visual/multifloor: **130/130**;
- save recovery: **18/18**;
- faction endgame production save: **9/9**.

Historical gates are left intact:

- `test_release_candidate_balance_122.gd`: **7891 checks, 1 expected version failure** → 7890 mechanics checks pass;
- `test_faction_endgame_122.gd`: **87 checks, 1 expected version failure** → 86 mechanics checks pass.

## Visual QA

OpenGL 4.5 (Mesa llvmpipe) under Xvfb:

- `dev15_perron_route_trader.png` — Zarya opening package visible in real trader stock;
- `dev15_mechanics_route_trader.png` — depot opening package/profile visible;
- `dev15_perron_route_radio.png` — specific Zarya chronicle entry fits;
- `dev15_perron_route_npc.png` — rendered NPC route consequence in the new feedback panel.

Capture command exits 0. ALSA unavailable → dummy audio fallback only.

## Asset integrity

Compared by relative path and SHA-256 against dev14 release ZIP:

- dev14 PNG: **651**;
- dev15 PNG: **651**;
- changed: **0**;
- added: **0**;
- removed: **0**.

## Release invariants

- Version: `1.23.0-dev15` in project/build/branch metadata.
- Production save schema: **122**.
- No global escape objective.
- No new source graphics.
- No parallel route-economy save state.

## Финальный clean-import / post-import gate

`.godot` удалён полностью. Первый `Godot --import` был обрезан внешним лимитом уже после 99% asset import, но сам процесс успел штатно завершить `Finalizing Asset Import`, post-reimport operations и editor layout. В import log ошибок нет; итоговый кэш содержит **1340 imported resources**.

На этом свежем кэше повторно:

- route consequences system — **87/87**;
- route consequences runtime/HUD — **36/36**;
- route consequences production save — **14/14**;
- trader layout — **13/13**;
- High Risk visual — **130/130**;
- trading — **512/512**;
- direct boot — `OSTATOK 1.23.0-dev15 SELFTEST: OK`, exit 0, script/resource errors 0.

Перед release ZIP `.godot` удаляется ещё раз.
