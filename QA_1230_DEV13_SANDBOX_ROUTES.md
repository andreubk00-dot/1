# QA — OSTATOK 1.23.0-dev13 Sandbox Routes

## Среда

- Godot Engine **4.7.2.stable.official.ed1daf0bf**.
- Dev12 release ZIP использован как baseline; dev13 разрабатывается поверх чисто распакованной копии.
- Save/integration tests запускаются с отдельными одинаковыми `XDG_DATA_HOME` и `OSTATOK_QA_SAVE_ROOT`, чтобы не касаться пользовательских сохранений.

## Новая механика

### Starter reconnaissance

`test_sandbox_routes_123.gd`: **80 checks, 0 failures**.

Проверено:

- starter-recon thresholds: Perron 8, Rubezh 9, Mechanics 9, Lazaret 10;
- все четыре шаблона остаются `discover_poi` и имеют реальный `poi_id`;
- при репутации ниже порога разведка не появляется;
- outsider сначала получает настоящий базовый delivery;
- реальный комплект поставки удовлетворяет ContractSystem;
- завершение первой поставки даёт ровно достаточную репутацию;
- разведка появляется сразу после завершения без дополнительного grind;
- разведка не закрывается без обнаружения POI;
- после обнаружения POI контракт закрывается и открывает authored persistent route;
- уже открытый route-contract не возвращается в offers;
- district hospital route заметно компенсирует ежедневное падение medicine;
- четыре фракционных контракта могут быть активны одновременно;
- глобальная цель не внедрена.

### Runtime / board UX

`test_sandbox_routes_runtime_123.gd`: **9 checks, 0 failures**.

Проверено:

- common board показывает `[ПОСТАВКА]` и `[РАЗВЕДКА]`;
- `ДОРОГА К «ЗАРЕ»` видна на Perron board при rep 8;
- `РАЙОННАЯ БОЛЬНИЦА` видна на Lazaret board при rep 16;
- старый `[ДОСТУПНО]` не скрывает тип задачи;
- personal board сохраняет `[ЛИЧНО]` и не получает common-board labels;
- main self-test: `OSTATOK 1.23.0-dev13 SELFTEST: OK`.

## Регрессии

- free-play handoff dev12: **11/11**, runtime **13/13**;
- contracts: **52/52**, UI **18/18**, production save **10/10**;
- personal contracts: **123/123**, UI **23/23**, production save **17/17**;
- expeditions: **45/45**, production save **54/54**;
- field map: **24/24**;
- strategic projects: **153/153**, runtime **75/75**, production save **23/23**, soak **178/178**;
- High Risk mechanics: **92/92**;
- High Risk integration: **170/170**;
- High Risk production save: **17/17**;
- High Risk anti-farm soak: **440/440**, 57 cycles;
- High Risk visual/multifloor: **130/130**;
- trading economy: **512/512**;
- settlement layout: **674/674**;
- target farming/world layout: **1324/1324**;
- world events/encounters: **1819/1819**;
- named NPC state/runtime: **105/105**, **14/14**;
- supply events: **35/35**, runtime **15/15**;
- world chronicle: **14/14**;
- rest: **38/38**;
- release candidate save migration: **15/15**;
- save recovery: **18/18**;
- faction relations: **65/65**.

Historical version gates:

- `test_faction_endgame_122.gd`: **87 checks / 1 failure** — only `project version must be 1.22.0 Stable`; 86 mechanics checks pass.
- `test_release_candidate_balance_122.gd`: **7891 checks / 1 failure** — only the same stable-version gate; 7890 mechanics checks pass.

These historical gates are intentionally not edited to make a dev build pretend to be Stable.

## Visual QA

Real OpenGL 4.5 / Mesa llvmpipe under Xvfb:

- `sandbox_perron_board.png` — `[РАЗВЕДКА] ДОРОГА К «ЗАРЕ»` + `[ПОСТАВКА] КУХОННЫЙ РЕЗЕРВ`; no clipping/overlap.
- `sandbox_lazaret_board.png` — `[ПОСТАВКА] ПЕРЕВЯЗОЧНАЯ` + `[РАЗВЕДКА] РАЙОННАЯ БОЛЬНИЦА`; no clipping/overlap.

ALSA is absent in the container and Godot falls back to dummy audio. Rendering and game logic are unaffected.

## Asset integrity

Compared every image entry in dev12 ZIP with the dev13 working tree by relative path and SHA-256:

- dev12 images: **651**;
- dev13 images: **651**;
- changed: **0**;
- added: **0**;
- removed: **0**.

## Release invariants

- Version: `1.23.0-dev13` in `project.godot`, `BUILD_VERSION.txt`, `BRANCH.txt`.
- Save schema stays **122**.
- No new global objective.
- No new graphics.
- No new persistent state required.

## Финальный clean-import / post-import gate

Перед упаковкой `.godot` был полностью удалён. Первый `Godot --import` был остановлен только внешним 180-секундным лимитом примерно на 64% без ошибок; второй штатный `--import` продолжил тот же кэш и завершился с **exit code 0**. В финальном import log нет `ERROR`, `SCRIPT ERROR`, `Parse Error` или `Failed loading resource`.

На свежем импортном кэше повторно:

- sandbox routes — **80/80**;
- sandbox runtime — **9/9**;
- dev12 free-play handoff — **11/11 + 13/13**;
- contracts — **52/52**, UI **18/18**;
- field map — **24/24**;
- High Risk visual/multifloor — **130/130**;
- direct `main.tscn` boot — `OSTATOK 1.23.0-dev13 SELFTEST: OK`.
