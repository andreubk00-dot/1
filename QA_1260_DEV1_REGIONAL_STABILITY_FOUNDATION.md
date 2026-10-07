# QA — OSTATOK 1.26.0-dev1 Regional Stability Foundation

## Static/system coverage

- `tests/test_regional_stability_126.gd`
  - fresh state not ready;
  - 4/4 routes, projects, networks;
  - STABLE threshold exactly 55;
  - 75% state when infrastructure is complete but settlements are below STABLE;
  - 100% calm state becomes ready;
  - active SOS keeps 100% infrastructure score but blocks launch readiness;
  - one sub-55 resource blocks exactly that settlement.
- `tests/test_regional_stability_runtime_126.gd`
  - common contract board exposes readiness;
  - ready and SOS-blocked states are reflected in UI.
- `tests/test_regional_stability_save_runtime_126.gd`
  - JSON/save-style roundtrip through `FactionEconomy.sanitize_state()`;
  - no `regional_stability` persistence field;
  - readiness reconstructs to 100% from schema-122 compatible state.

## Boundary checks completed in this environment

- 474/474 literal `preload()` paths resolve.
- New/changed GDScript delimiter/static checks pass after QA-script cleanup.
- Protected gameplay/save/catalog files are byte-identical to 1.25.0-dev4:
  `faction_economy`, `faction_endgame`, `settlement_projects`, `settlement_crisis`,
  `supply_event_system`, contracts, trading, High Risk catalogs/mechanics, POI/Region,
  SaveStore and faction/NPC catalogs.
- Production save writer remains `save_version: 122`.
- PNG assets: 651/651 byte-identical to dev4.
- No new art.

## Runtime gate

Godot 4.7.2 executable is not available in the current container, so the new GDScript suites,
clean import and `main.tscn` SELFTEST are **PENDING**. No runtime PASS is claimed here.
