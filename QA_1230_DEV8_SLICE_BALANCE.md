# OSTATOK 1.23.0-dev8 — QA / Slice Balance

Дата: 2026-10-05  
Движок: Godot 4.7.2 stable Linux x86_64

## Dev8 vertical-slice checks

- `test_vertical_slice_123.gd` — **55/55**
  - preparation beat before High Risk;
  - first Lazaret supply event and recovered/lost outcomes;
  - first outcome is immutable after later world events;
  - later SOS does not hijack resolved onboarding route;
  - one-time field reserve eligibility/idempotence;
  - medical cargo threshold equals real crisis-contract alternatives;
  - delayed contract acceptance after supply recovery remains possible;
  - legacy state does not receive onboarding changes.
- `test_vertical_slice_runtime_123.gd` — **28/28**
  - real main runtime/self-test;
  - HUD/map preparation route;
  - supply event transition;
  - actual inventory gain: `ammo_9x18 +16`, `bandage +2`;
  - second reserve issue rejected;
  - transition to clinical route.
- `test_vertical_slice_save_runtime_123.gd` — **22/22**
  - production SaveStore;
  - schema 122;
  - supply outcome / field reserve save-load idempotence;
  - dev6/dev7-style migration remains non-invasive.
- `test_high_risk_visual_multifloor.gd` — **130/130**.
- built-in `--qa-selftest-exit` — **failures=0**.

## Regression — contracts / NPC / supply / strategic systems

- contracts — **52/52**
- contract UI runtime — **18/18**
- personal contracts — **123/123**
- personal contract UI — **23/23**
- personal contract soak — **31/31**
- named NPC state — **105/105**
- named NPC runtime — **14/14**
- supply events — **35/35**
- supply event runtime — **15/15**
- strategic projects — **153/153**
- strategic projects runtime — **75/75**
- strategic projects soak — **178/178**

## Regression — economy / world

- settlement crisis — **31/31**
- faction settlement runtime — **169/169**
- settlement layout — **674/674**
- trading economy — **512/512**
- factions — **244/244**
- faction relations — **65/65**
- world chronicle — **14/14**
- rest/midnight — **38/38**
- world events/encounters — **1819/1819**

## Regression — High Risk

- mechanics — **92/92**
- locations — **373/373**
- integration — **170/170**
- anti-farm soak 30/60/180 — **440/440**, 57 cycles
- target farming/world layout — **1324/1324**
- visual/multifloor — **130/130**

## Production save/load regression

Изолированные user-data каталоги, без падений:
- High Risk integration **170/170**
- High Risk mechanics save **17/17**
- contracts **10/10**
- personal contracts **17/17**
- named NPC **8/8**
- strategic projects **23/23**
- supply events **8/8**
- world chronicle **7/7**
- faction relations **9/9**
- faction endgame **9/9**
- release-candidate migration **15/15**
- save recovery **18/18**
- expedition save **54/54**
- vertical slice **22/22**

## Long-run balance gate

`test_release_candidate_balance_122.gd`: **7891 checks / 1 expected failure**. Единственный fail — исторический gate `project version must be 1.22.0 Stable`; остальные **7890 механических проверок проходят**. Gate намеренно не переписывался под dev-сборку.

## Visual QA

Godot 4.7.2 + Xvfb/OpenGL compatibility capture, 1280×720:
- preparation HUD — текст помещается в штатный objective panel;
- preparation map — waiting marker читаем на fog-of-war;
- post-supply HUD — клиническая цель читается, ammo counter показывает новый резерв;
- post-supply map — опасная системная метка клиники не конфликтует с пользовательскими controls.

Графические ассеты dev7 → dev8: **651/651 идентичны побайтово**.

## Expected dev-only gates / environment notes

- Stable release-gate не должен быть зелёным на `1.23.0-dev8`.
- Save/integration tests требуют отдельный `XDG_DATA_HOME` / `OSTATOK_QA_SAVE_ROOT`; без него они корректно завершаются environment guard, а не механическим failure.
- В Xvfb ALSA недоступна, поэтому Godot использует dummy audio driver; это не игровой script/resource error.

## Packaging hotfix 1

После финальной упаковки обнаружена несогласованность корневых метаданных: `project.godot` уже содержал `1.23.0-dev8`, а `BUILD_VERSION.txt` и `BRANCH.txt` по ошибке оставались `1.23.0-dev7`. В HOTFIX1 оба файла исправлены на `1.23.0-dev8`. Игровой код, баланс, save schema и графические ассеты не изменялись.
