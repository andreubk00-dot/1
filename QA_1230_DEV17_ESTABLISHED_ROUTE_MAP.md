# QA — OSTATOK 1.23.0-dev17 Established Route Map

## Baseline

- Source baseline: `OSTATOK_1.23.0-dev16_Multi_Route_Economy.zip`.
- Baseline SHA-256: `15260cc2a40795aee600120e3ec0392b3e0be72f12dea187a7d04f2f3ecf6f13` — verified before dev17 work.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- Historical stable-version gate that expects `1.22.0 Stable` remains untouched.

## Problem verified before implementation

The field map snapshot in dev16 contained:

- known cells / discovered POIs;
- manual markers;
- supply-event marker;
- vertical-slice system marker;
- current player/home;
- active expedition `target` and temporary expedition `route`.

It did **not** consume `faction_state.world_routes`. Therefore a route could be permanently open, affect economy/traders/NPC/radio, and still have no persistent representation on the exploration map.

## Dev17 presentation rule

`world/sandbox_route_map.gd` derives presentation-only links from current authored data.

A link is eligible only when:

- the saved route is `open`;
- its authored contract resolves to a concrete `poi_id`;
- source settlement exists in `FactionCatalog` / `RegionCatalog`;
- target exists in `RegionCatalog`;
- both endpoint POIs are already present in player `discovered_pois`.

No route coordinates, labels or derived links are written to save.

### Legacy fallback

If an older open route has no `source_contract`, the renderer resolves its authored contract by unique route id. This lookup is presentation-only and does not add `source_contract` to the state.

### Duplicate physical links

Two outcomes can improve the same physical connection (for example depot-related Mechanics routes). Identical source/target endpoint pairs are deduplicated so map weight does not accidentally visualize economy stacking.

## Discovery-first / information leak audit

Map link payload contains only:

- route/template internal id;
- faction id;
- source/target POI ids;
- source/target coordinates;
- human-readable endpoint label.

It does not contain resource deltas, loot identity, risk, restock factor or farming cooldown.

The route is drawn as a muted connection with no arrowheads or intermediate waypoints. If neither endpoint is in the current map window, it is not drawn, preventing an off-screen straight segment from masquerading as a surveyed road through unknown territory.

Abstract final networks without a concrete authored POI are intentionally not projected.

## New QA suites

### `test_established_route_map_123.gd`

Covers:

- empty state does not fabricate links;
- undiscovered endpoint suppresses link;
- Perron → Zarya source/target coordinates and label;
- no economic/loot/risk fields in presentation payload;
- endpoint-only detail identity;
- dev14/dev15-style route without `source_contract` resolves by route id;
- four starter routes create four distinct geographic links;
- duplicate Mechanics depot connection does not overdraw;
- later POI-backed Rubezh checkpoint route projects correctly;
- abstract final network does not fabricate geography;
- non-open route is hidden.

### `test_established_route_map_runtime_123.gd`

Covers:

- real `_region_map_snapshot()` includes established route;
- established route alone creates neither navigation target nor expedition path;
- source and target detail panels explain the established connection;
- active expedition and persistent route coexist as separate fields/layers;
- removing target POI knowledge hides the route immediately.

### `test_established_route_map_save_runtime_123.gd`

Requires isolated `XDG_DATA_HOME` / `OSTATOK_QA_SAVE_ROOT` and checks:

- `save_version == 122`;
- open route survives production save/load;
- discovered endpoint knowledge survives;
- no `established_routes` derived block is persisted;
- loaded state reconstructs the correct source/target link;
- dev15-style route fallback works after sanitize without mutating legacy state.

### Visual capture

`qa_established_route_map_capture.gd` prepares the four starter routes, discovered geography and the field map at 640×360 for a dedicated screenshot. Visual acceptance criteria:

- established links remain visibly weaker than the active navigation style;
- map remains legible at normal panel size;
- legend stays inside the 384 px map footer area;
- right-side details remain inside the existing scroll column;
- no line or label escapes the map panel.

## Static change-boundary audit — PASS

Dev16 → current dev17 work modifies only:

- version/branch metadata;
- `main_script_mod.gd` map integration + dev17 title/version;
- `world/region_map_view.gd` established-link drawing;
- new `world/sandbox_route_map.gd` derived projection helper;
- high-risk visual suite expected build version;
- three new functional dev17 suites + one capture runner;
- dev17 README/QA.

Protected gameplay files are SHA-identical to dev16:

- `world/faction_economy.gd`;
- `world/sandbox_route_consequences.gd`;
- `world/contract_system.gd`;
- `world/contract_catalog.gd`;
- `world/high_risk_mechanics.gd`;
- `world/settlement_projects.gd`;
- `world/faction_endgame.gd`;
- `world/save_store.gd`;
- `world/trading_market.gd`;
- `world/supply_event_system.gd`.

Additional static invariants verified:

- production writer still emits save schema **122**;
- named-NPC catalog remains **16 unique IDs / 4 per faction**;
- no `established_routes` field is part of production save data;
- source graphics remain **651 PNG / 651 PNG / changed 0**;
- no global escape/endgame goal was introduced.

## Runtime certification status

Native Godot 4.7.2 is still unavailable in the current container. The official release is known, but network/materialization restrictions prevent executing the binary here. Therefore the following are **PENDING**, not claimed as PASS:

1. `test_established_route_map_123.gd`;
2. `test_established_route_map_runtime_123.gd`;
3. `test_established_route_map_save_runtime_123.gd` in isolated save root;
4. `qa_established_route_map_capture.gd` and visual review;
5. dev13–dev16 sandbox route/economy regression;
6. map/expedition/discovery regression;
7. broad trading/contracts/endgame/projects/High Risk/save regression;
8. clean Godot 4.7.2 import;
9. direct `main.tscn` SELFTEST.

No fabricated engine pass counts are recorded.
