# QA — OSTATOK 1.25.0-dev2 Authored POI Traces

## Baseline

- Source baseline: `OSTATOK_1.25.0-dev1_Environmental_Storytelling_Foundation.zip`.
- Baseline SHA-256: `8e1b2915932c1cf1a733d1a73744d330e74ebbe7b5d90b4904bf6926504e1275`.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- Historical 1.22 Stable version gates are not rewritten.

## Authored POI trace audit — PASS

`PoiStoryCatalog` contains exactly **8** traces for **8 distinct ordinary compound POIs** and **8 unique story ids**.

Targets:

- `garage_coop_sever|0,-1`;
- `factory_7|0,1`;
- `rail_depot|0,0`;
- `dacha_coop_zarya|0,0`;
- `district_hospital|0,0`;
- `district_police|0,0`;
- `hunting_cordon|0,0`;
- `military_checkpoint|0,0`.

All target cells exist in the current `PoiCatalog`. IDs do not collide with the 8 dev1 finite-encounter story ids.

Explicit negative boundaries:

- `central_clinic` — no dev2 trace;
- faction settlements — no dev2 trace;
- `regional_clinical_complex_4` / other High Risk — no dev2 trace.

## Narrative boundary — PASS

The new catalog contains no reward, loot, enemy-count, route, objective, target, reputation, items, spawn-id or map-marker fields.

All story ids fit the existing chronicle id limit; all authored texts fit the existing chronicle text limit. Only existing `paper_stack` / `newspapers` world atlas props are used.

## Geometry audit — PASS

For all eight traces:

- building-footprint overlap with 12 px margin: **0**;
- chunk-bound violations: **0**;
- authored prop / loose-container / workbench overlap: **0**;
- selected positions are also outside the fixed/random late set-piece zones used by `_dress_major_poi()`.

Reference clearances to catalog object centers are all >= **124 px** except the garage/factory/dacha/hunting cells, which are even farther away.

## Persistence boundary — PASS (static/reference)

Dev2 introduces no new save field. It reuses dev1 `WorldChronicle.append_story()` and `story_seen` inside the existing `faction_state.world_chronicle` dictionary.

Static checks confirm:

- production writer still emits `save_version 122`;
- no `poi_story` / `poi_story_seen` top-level save keys are written;
- `world/world_chronicle.gd` is byte-identical to dev1.

## Static / regression QA — PASS

Short independent batches verified:

1. New catalog + four QA scripts pass quote/comment-stripped delimiter balance.
2. All changed/new literal `preload("res://...")` paths resolve.
3. Catalog: 8 POIs / 8 unique IDs / no collision with dev1 IDs.
4. Target authored cells and geometry are valid.
5. Protected gameplay/catalog/save files are byte-identical to dev1: dev1 environmental catalog, world chronicle, encounter/region/POI catalogs, faction economy, supply, projects, endgame, contracts, High Risk, trader catalog and save store.
6. Named NPC roster remains **16 unique** (4 × 4 factions).
7. Source PNG: **651/651 byte-identical** to dev1; changed 0.
8. Removed baseline files: **0**.
9. Baseline modifications before docs are limited to `main_script_mod.gd`, version metadata, roadmap and the current visual version gate.
10. New functional code is limited to `world/poi_story_catalog.gd` plus four dev2 QA scripts.

## Runtime certification — PENDING

Run under Godot 4.7.2 as separate short groups:

```bash
godot --headless --path . --script tests/test_poi_storytelling_125.gd

godot --headless --path . --script tests/test_poi_storytelling_runtime_125.gd

QA=/tmp/ostatok_125_dev2_save_qa
rm -rf "$QA" && mkdir -p "$QA"
XDG_DATA_HOME="$QA" OSTATOK_QA_SAVE_ROOT="$QA" \
  godot --headless --path . --script tests/test_poi_storytelling_save_runtime_125.gd

CAP=/tmp/ostatok_125_dev2_captures
rm -rf "$CAP" && mkdir -p "$CAP"
xvfb-run -a godot --path . --script tests/qa_poi_storytelling_capture.gd -- --qa-output="$CAP"
```

Then separately run clean import, `main.tscn` SELFTEST and broad regression in small groups.

No runtime/capture/SELFTEST PASS is fabricated in this report.
