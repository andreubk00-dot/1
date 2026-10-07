# QA — OSTATOK 1.24.0-dev3 Minor POI Final Pass

## Baseline

- Source baseline: `OSTATOK_1.24.0-dev2_Encounter_Scene_Variety.zip`.
- Baseline SHA-256: `0673d11d8637c686ca0b1d934425152daeef0a7d662cd823be5e1fbd0b80fdf7`.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- `BUILDING_LAYOUT_VERSION = 4`, unchanged.
- Historical 1.22 Stable version gates are not rewritten.

## Minor-POI density audit — PASS

Audited **25 cells** across the eight ordinary authored POIs before High Risk.

Before dev3:

- zero local props: **5**;
- bare/near-bare criterion (`props == 0` OR `props <= 1` with no lamps/fences/workbench): **6**.

Affected cells:

- `dacha_coop_zarya -1,0` — старые участки;
- `dacha_coop_zarya 0,1` — садовые участки;
- `dacha_coop_zarya -1,1` — край кооператива;
- `military_checkpoint 0,-1` — казарменный двор;
- `district_police 1,0` — закрытый двор;
- `hunting_cordon 1,0` — хозяйственная поляна.

Dev3 adds two small sprite accents to each through a separate derived helper. Re-running the same audit after the overlay:

- zero-prop cells: **0**;
- bare/near-bare cells: **0**.

## Implementation boundary — PASS

`world/minor_poi_dressing.gd`:

- target cells: **6**;
- accents: **12** total;
- referenced world-prop kinds: **10**, all present in the current atlas mapping;
- no loot/container/enemy/collision/door/risk/farm/refresh/items/save fields;
- unsupported POIs return an empty list;
- High Risk and faction settlements are not targeted.

Integration in `main_script_mod.gd` runs after existing authored cell props and creates only `_world_prop_sprite()` nodes. New nodes receive runtime metadata `minor_poi_dressing`, `minor_poi_id`, `minor_poi_cell` for QA/debugging.

## Geometry sanity — PASS

All **12** accent centers were checked against their authored building rectangles with an 8 px center-point margin:

- building-footprint overlaps: **0**;
- chunk-bound violations: **0**.

Props are non-colliding sprites, so navigation/collision geometry remains unchanged.

## Static / regression QA — PASS

Short independent batches verified:

1. Baseline dev2 ZIP SHA matches the recorded release SHA.
2. Dev2 → dev3 baseline changes before docs are limited to:
   - `main_script_mod.gd`;
   - `project.godot`;
   - `BUILD_VERSION.txt`;
   - `BRANCH.txt`;
   - current `tests/test_high_risk_visual_multifloor.gd` version gate.
3. New functional files are limited to the helper + 4 dev3 QA files.
4. Removed baseline files: **0**.
5. Protected gameplay/catalog files are byte-identical to dev2: `poi_catalog`, `region_catalog`, encounter catalog, faction economy, contracts, High Risk, projects, endgame, supply, crises, trading and save store.
6. Production save writer still emits **save_version 122**.
7. `BUILDING_LAYOUT_VERSION = 4`.
8. New helper and all new QA scripts pass quote/comment-stripped delimiter balance.
9. Literal changed-file `res://` references resolve; format-string resource templates are excluded from this static check.
10. Named NPC roster remains **16 unique** (4 × 4 factions).
11. Source PNG: **651/651 byte-identical** to dev2; changed 0.
12. Historical 1.22 Stable gates remain unchanged.

## Runtime certification — PENDING

No Godot executable is available in the current container. Run as short independent groups when Godot 4.7.2 is available:

```bash
godot --headless --path . --script tests/test_minor_poi_dressing_124.gd

godot --headless --path . --script tests/test_minor_poi_dressing_runtime_124.gd

QA=/tmp/ostatok_dev3_save_qa
rm -rf "$QA" && mkdir -p "$QA"
XDG_DATA_HOME="$QA" OSTATOK_QA_SAVE_ROOT="$QA" \
  godot --headless --path . --script tests/test_minor_poi_dressing_save_runtime_124.gd

CAP=/tmp/ostatok_dev3_captures
rm -rf "$CAP" && mkdir -p "$CAP"
xvfb-run -a godot --path . --script tests/qa_minor_poi_dressing_capture.gd -- --qa-output="$CAP"
```

Then separately run clean import, direct `main.tscn` SELFTEST and broad historical regression in small groups.

No Godot runtime/capture/SELFTEST counts are fabricated in this report.
