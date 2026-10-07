# QA — OSTATOK 1.23.0-dev18 District Survey Context

## Baseline

- Source baseline: `OSTATOK_1.23.0-dev17_Established_Route_Map.zip`.
- Baseline SHA-256: `f42544c4beb1917f9f1d963296b96f57604cead2bbe8312893b125d080e834e0` — verified after the interrupted dev17 packaging step.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- Historical 1.22.0 version gates remain untouched.

## Problem verified before implementation

Dev17 exposed already-open geographic route links, but the selected-sector detail remained mostly generic:

- district display name;
- danger level;
- discovered POI description;
- route endpoint label.

The authored district description in `RegionCatalog.DISTRICTS` was not used by the field-map decision layer, and the map did not summarize the player's actual survey knowledge inside that district.

A second presentation edge existed on remote authored POIs: the visible cell district came directly from coordinate-based `district_id_for_chunk()`. For a discovered POI whose authored `district` intentionally differs from the procedural outskirts macrocell, map identity could therefore disagree with authored world identity.

## Dev18 derived model

New `world/region_survey_context.gd` derives context from:

- `discovered_chunks`;
- `discovered_pois`;
- `RegionCatalog.DISTRICTS` / `RegionCatalog.POIS`;
- dev17 `SandboxRouteMap.links()` output.

Returned public fields are limited to:

- `district_id`;
- `name`;
- `description`;
- public risk band;
- `known_sectors`;
- already-known landmark names;
- count of already-known established geographic links touching the district.

No data is written back to state or save.

## Discovery boundary

`context_for_coord()` returns `{}` unless the selected chunk is explicitly present with a truthy value in `discovered_chunks`.

`visible_district_id_for_coord()` uses an authored POI district only if that POI id is already truthy in `discovered_pois`. Otherwise it falls back to the normal procedural/authored macro district by coordinate.

Known-landmark summary iterates only discovered POI ids and deliberately does not expose a total POI count.

## Authored district override reference check

Lazaret anchor: `(-8,-2)`.

The current outer-district hash produces:

- macrocell pick: `5`;
- coordinate-only district: `outer_rural`.

The authored `settlement_lazaret` POI district is `outer_residential`.

Dev18 therefore has a deterministic QA case:

- POI unknown → `outer_rural` remains visible;
- POI discovered → authored `outer_residential` becomes visible.

This proves the override is both meaningful and discovery-gated.

## Static/regression QA — PASS

Verified in short independent packages:

1. New dev18 GDScript files have balanced delimiters and valid `res://` preload targets.
2. The dev18 delta does not alter the pre-existing net delimiter balance of `main_script_mod.gd`.
3. No merge-conflict markers were introduced.
4. `region_survey_context.gd` does not consume/return hidden loot, farming, restock, building-set or spawn multiplier fields.
5. Unknown-sector UI branch does not call or display survey context.
6. `_save_state()` is text-identical to dev17.
7. `_load_state()` is text-identical to dev17.
8. `_navigation_target_chunk()` is text-identical to dev17.
9. `_expedition_route_chunks()` is text-identical to dev17.
10. `_plan_selected_expedition()` and `_cancel_expedition()` are text-identical to dev17.
11. Production writer still emits `save_version: 122`.
12. No production `district_survey` / `region_survey_context` save field exists.
13. Named NPC roster remains 16 unique IDs / 4 per faction.
14. Historical `test_faction_endgame_122.gd` and `test_stable_release_gate_122.gd` are unchanged.
15. Protected gameplay files are SHA-identical to dev17:
    - `world/faction_economy.gd`;
    - `world/sandbox_route_consequences.gd`;
    - `world/sandbox_route_map.gd`;
    - `world/contract_system.gd`;
    - `world/contract_catalog.gd`;
    - `world/high_risk_mechanics.gd`;
    - `world/settlement_projects.gd`;
    - `world/faction_endgame.gd`;
    - `world/save_store.gd`;
    - `world/trading_market.gd`;
    - `world/supply_event_system.gd`;
    - `world/settlement_crisis.gd`.
16. Source art: **651 PNG baseline / 651 PNG dev18 / changed 0 / added 0 / removed 0**.
17. `RegionMapView.SHORT_NAMES` now covers all four `outer_*` district identities without new assets or gameplay data.

## Expected changed paths before README/QA

Functional delta is limited to:

- `project.godot` — current dev build version;
- `main_script_mod.gd` — preload, visible district projection and selected-sector detail;
- `world/region_survey_context.gd` — new derived helper;
- `world/region_map_view.gd` — four missing `outer_*` cartographic short labels;
- `tests/test_high_risk_visual_multifloor.gd` — expected current dev build version;
- `tests/test_district_survey_context_123.gd`;
- `tests/test_district_survey_context_runtime_123.gd`;
- `tests/test_district_survey_context_save_runtime_123.gd`;
- `tests/qa_district_survey_context_capture.gd`.

README/QA are the only additional release-document paths.

## Runtime certification — PENDING

The current container has no native Godot executable. A short attempt to fetch the official/mirrored 4.7.2 Linux build failed at host resolution, so no repeated long download was attempted.

The following remain pending rather than falsely marked PASS:

1. `test_district_survey_context_123.gd`;
2. `test_district_survey_context_runtime_123.gd`;
3. `test_district_survey_context_save_runtime_123.gd` with isolated `XDG_DATA_HOME` / `OSTATOK_QA_SAVE_ROOT`;
4. `qa_district_survey_context_capture.gd` visual review at 640×360;
5. dev17 established-route map suites;
6. dev16 multi-route economy suites;
7. map/expedition/discovery regression;
8. broad trading/contracts/endgame/projects/High Risk/save regression;
9. clean Godot 4.7.2 import;
10. direct `main.tscn` SELFTEST.

No engine pass counts are fabricated.
