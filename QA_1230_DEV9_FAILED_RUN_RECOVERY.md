# OSTATOK 1.23.0-dev9 — QA / Failed Run Recovery

Дата: 2026-10-05  
Движок: Godot 4.7.2 stable Linux x86_64

## Baseline dev8 HOTFIX1

Перед изменениями после полного Godot import:

- `test_vertical_slice_123.gd` — **55/55**;
- `test_vertical_slice_runtime_123.gd` — **28/28**;
- `test_vertical_slice_save_runtime_123.gd` — **22/22**.

## Новые dev9 tests

- `test_vertical_slice_recovery_123.gd` — **39/39**
  - default/sanitize recovery state;
  - rescue не включается до обязательных milestones;
  - первая clinical incapacitation записывается;
  - one-time aid eligibility/idempotence;
  - regroup HUD objective / retry marker;
  - выход из Лазарета снимает только temporary regroup state;
  - повторная incapacitation не выдаёт aid второй раз;
  - полный medical cargo переживает incapacitation;
  - dev8-style state migration не придумывает recovery history.
- `test_vertical_slice_recovery_runtime_123.gd` — **35/35**
  - реальная `main.tscn`;
  - surface clinic rescue;
  - floor-2 clinic rescue;
  - точный 6-hour gameplay cost с допустимой frame-time погрешностью;
  - partial recovery вместо perfect heal;
  - inventory aid x1 only;
  - cargo survives rescue;
  - HUD `ПЕРЕПРОВЕРИТЬ СНАРЯЖЕНИЕ` / `СДАТЬ АВАРИЙНЫЙ ЗАКАЗ`;
  - обычный respawn вне клиники не получает dev9 penalty/state.
- `test_vertical_slice_recovery_save_runtime_123.gd` — **17/17**
  - production SaveStore;
  - recovery count/pending/aid/floor persistence;
  - aid не становится доступным повторно после load;
  - schema 122 dev8-style migration.

## Existing vertical-slice / visual gates

- `test_vertical_slice_123.gd` — **55/55**;
- `test_vertical_slice_runtime_123.gd` — **28/28**;
- `test_vertical_slice_save_runtime_123.gd` — **22/22**;
- `test_high_risk_visual_multifloor.gd` — **130/130**;
- built-in self-test repeatedly reports **`OSTATOK 1.23.0-dev9 SELFTEST: OK`**.

## Regression — contracts / NPC / supply / projects

- contracts — **52/52**;
- contract UI runtime — **18/18**;
- personal contracts — **123/123**;
- personal contract UI runtime — **23/23**;
- personal contract soak — **31/31**;
- named NPC state — **105/105**;
- named NPC runtime — **14/14**;
- supply events — **35/35**;
- supply event runtime — **15/15**;
- strategic projects — **153/153**;
- strategic projects runtime — **75/75**;
- strategic projects soak — **178/178**.

## Regression — settlements / economy / world

- settlement crisis — **31/31**;
- settlement crisis UI — **8/8**;
- faction settlement runtime — **169/169**;
- settlement layout — **674/674**;
- trading economy — **512/512**;
- faction relations — **65/65**;
- world chronicle — **14/14**;
- rest/midnight — **38/38**;
- world events / encounters — **1819/1819**;
- expedition regression — **45/45**.

## Regression — High Risk

- mechanics — **92/92**;
- locations — **373/373**;
- integration — **170/170**;
- anti-farm soak — **440/440**, 57 cycles;
- target farming/world layout — **1324/1324**;
- clinical complex endgame — **368/368**;
- reception model — **10/10**;
- visual/multifloor — **130/130**.

## Production save/load regression

Изолированные `XDG_DATA_HOME` / `OSTATOK_QA_SAVE_ROOT`:

- contracts — **10/10**;
- personal contracts — **17/17**;
- supply events — **8/8**;
- High Risk mechanics — **17/17**;
- named NPC — **8/8**;
- strategic projects — **23/23**;
- world chronicle — **7/7**;
- faction relations — **9/9**;
- faction endgame — **9/9**;
- expedition save — **54/54**;
- release-candidate migration — **15/15**;
- save recovery — **18/18**;
- dev9 recovery — **17/17**.

## Long-run release-candidate gate

`test_release_candidate_balance_122.gd`: **7891 checks / 1 expected failure**. Fail только исторический: `project version must be 1.22.0 Stable`. Остальные **7890 механических проверок проходят**.

`test_faction_endgame_122.gd`: **87 checks / 1 expected failure** по той же причине; 86 механических проверок проходят.

Stable-gates намеренно не переписаны под dev9.

## Visual QA

Godot 4.7.2 + Xvfb/OpenGL compatibility:

- `recovery_hud.png`: HUD после эвакуации показывает partial vitals и `ПЕРЕПРОВЕРИТЬ СНАРЯЖЕНИЕ`; текст не конфликтует с quickbar/weapon/vitals panels.
- `recovery_map.png`: retry marker `ПОЛЕВОЙ МАРШРУТ • ПОВТОР КЛИНИКИ` читается на fog-of-war, текущая позиция остаётся в Лазарете.

ALSA в Xvfb недоступна, Godot корректно перешёл на dummy audio driver. Script/resource errors отсутствуют.

## Graphics diff

Dev8 HOTFIX1 → dev9: **651 → 651 raster assets; changed 0, added 0, removed 0** (SHA-256 comparison by relative path).

## Final clean-import verification

Финальный прогон выполнен после полного удаления `.godot` и повторного импорта Godot 4.7.2:

- editor import exit code **0**; импортировано **1340** ресурсов; `SCRIPT ERROR` / `Parse Error` / resource-loading errors — **0**;
- `test_vertical_slice_recovery_123.gd` — **39/39**;
- `test_vertical_slice_recovery_runtime_123.gd` — **35/35**;
- `test_vertical_slice_recovery_save_runtime_123.gd` — **17/17**;
- `test_high_risk_visual_multifloor.gd` — **130/130**;
- built-in self-test — **`OSTATOK 1.23.0-dev9 SELFTEST: OK`**;
- `project.godot`, `BUILD_VERSION.txt`, `BRANCH.txt` согласованы на **1.23.0-dev9**;
- production save payload по-прежнему пишет `save_version: 122`.

Перед архивированием `.godot` удаляется; archive CRC и отсутствие Python/import caches проверяются отдельно.
