# QA — OSTATOK 1.26.0-dev3 Crisis Season Pressure

New suites:
- `test_crisis_season_pressure_126.gd`
- `test_crisis_season_pressure_save_126.gd`

Environment-available checks:
- literal preloads resolve;
- new GDScript structure checks pass;
- pure 21-day pressure reference totals verified;
- duplicate same-day pressure is covered by the authored test;
- checkpoint days are exactly 7 and 14;
- pressure metrics sanitize/clamp under schema 122;
- 17 protected gameplay/save/catalog files are byte-identical to dev2;
- 651/651 PNG are byte-identical.

Godot 4.7.2 runtime/clean-import/SELFTEST remains PENDING because the executable is not present in this container.
