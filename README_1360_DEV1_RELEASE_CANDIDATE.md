# OSTATOK 1.36.0-dev1 — Release Candidate

Release Candidate собран поверх принятого 1.35.0-dev1 Balance Lock без новых gameplay systems,
контента или числового rebalance. Производственная логика игры не менялась; изменены только
release metadata, current-version High Risk QA gate, roadmap и RC-документация.

Проверено короткими независимыми пакетами на официальном Godot 4.7.2:
- fresh clean import: exit 0, 651 PNG `.ctex`;
- full playthrough supported: 196/196;
- full playthrough strained: 197/197;
- full playthrough unsupported: 197/197;
- save migration/recovery: 15/15 + 18/18;
- save migration boundaries/malformed: 42/42 + 39/39;
- current-schema roundtrip/expedition save: 42/42 + 54/54;
- trading economy: 512/512;
- High Risk visual closure: 494/494;
- long-session chunk/entity/save/mixed: 201/201 + 170/170 + 50/50 + 82/82;
- world geometry final audit: 6232/6232;
- UI/weapon/world/infected/ambience audio checks: 35/35 + 113/113 + 48/48 + 68/68 + 44/44 + 41/41;
- audio closure save-boundary: 6/6.

Visual QA: 52 daytime High Risk runtime captures across Clinical Complex #4, Quarantine Center 12,
Reserve Arsenal Bastion and Underground Object Vector were generated and reviewed. No new clipping
or geometry defect requiring an asset rebuild was found.

Save schema remains 122. Named NPC roster remains 16 unique NPC. Balance Lock remains in force.
Next roadmap stage: 1.37.0 Final Release; only critical fixes are allowed between RC and Final.

Final post-version-bump gates:
- High Risk current-version visual/multifloor: 130/130;
- main.tscn: `OSTATOK 1.36.0-dev1 SELFTEST: OK`;
- `QA_SELFTEST_EXIT: failures=0`;
- feature-lock release surface: 7/7;
- named NPC state: 105/105, including exactly 16 authored records.
