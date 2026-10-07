# OSTATOK 1.23.0-dev7 — QA / Vertical Slice

Дата: 2026-10-04  
Движок: Godot 4.7.2 stable Linux x86_64

## Новые проверки dev7

- `test_vertical_slice_123.gd` — **39/39**
  - fresh-game-only инициализация;
  - реальный shortage Лазарета;
  - существующий crisis contract;
  - встреча с Мироновой;
  - ускорение только первого supply incident;
  - need-score выбирает Лазарет;
  - supply recovered/lost milestones;
  - High Risk route;
  - неполный медицинский набор не считается готовым грузом;
  - полный набор приводит к возврату и системному восстановлению;
  - legacy migration не меняет экономику.
- `test_vertical_slice_runtime_123.gd` — **20/20**
  - реальная `main.tscn`;
  - HUD route;
  - полевая карта/system markers;
  - Lazaret arrival;
  - board Мироновой;
  - High Risk/return transitions;
  - отсутствие конфликтующего сообщения «сначала закрепите дом»;
  - legacy state не получает onboarding UI.
- `test_vertical_slice_save_runtime_123.gd` — **19/19**
  - production SaveStore;
  - schema 122;
  - milestones save/load;
  - реальный `_ready` с dev6-style schema 122 не запускает fresh-game setup.

## Regression — контракты / supply

- contracts — **52/52**
- contract UI runtime — **18/18**
- personal contracts — **123/123**
- personal contract UI — **23/23**
- supply events — **35/35**
- supply event runtime — **15/15**

## Regression — dev5/dev6

- strategic projects — **153/153**
- strategic projects runtime — **75/75**
- High Risk mechanics — **92/92**
- High Risk integration — **170/170**
- High Risk visual/multifloor — **130/130**

## Regression — economy/world

- settlement crisis — **31/31**
- faction settlements runtime — **169/169**
- settlement layout — **674/674**
- trading economy — **512/512**
- world chronicle — **14/14**
- rest/midnight — **38/38**
- world events/encounters — **1819/1819**
- factions — **244/244**
- faction relations — **65/65**
- named NPC state — **105/105**
- named NPC runtime — **14/14**

## Production save/load regression

Без падений:
- contracts **10/10**
- faction endgame **9/9**
- faction relations **9/9**
- High Risk mechanics **17/17**
- named NPC **8/8**
- personal contracts **17/17**
- strategic projects **23/23**
- supply events **8/8**
- world chronicle **7/7**
- vertical slice **19/19**

## Long-run balance

`test_release_candidate_balance_122.gd`: **7890 механических проверок проходят**; формальный итог скрипта — 7891 checks / 1 failure из-за намеренного исторического release-gate `project version must be 1.22.0 Stable`. Этот gate не переписывался под dev7.

## Visual QA

Реальные OpenGL captures:
- стартовый HUD: цель «ДОБРАТЬСЯ ДО ЛАЗАРЕТА» помещается в штатный блок;
- карта с fog-of-war: системная метка и подпись «ПОЛЕВОЙ МАРШРУТ • ЛАЗАРЕТ» видимы и не обрезаны;
- найден и исправлен конфликт текста карты с требованием сначала закрепить дом.

Графические ассеты dev6 → dev7: **651/651 идентичны побайтово**.

## Известный ожидаемый gate

`test_faction_endgame_122.gd` имеет **86 механических успешных проверок + 1 ожидаемый version-gate failure**, потому что тест исторически требует `1.22.0 Stable`. Механику ради зелёной строки dev-сборки не меняли.
