# QA — OSTATOK 1.25.0-dev1 Environmental Storytelling Foundation

## Baseline

- Source baseline: `OSTATOK_1.24.0-dev3_Minor_POI_Final_Pass.zip`.
- Baseline SHA-256: `1917ef1f4b1093a64d018fbde07759edc6eb69280a75d555bdcb4d1103ac177d`.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- `BUILDING_LAYOUT_VERSION = 4`, unchanged.
- Historical 1.22 Stable version gates are not rewritten.

## Authored-anchor reference audit — PASS

The live `RegionCatalog` district/POI rules plus `EncounterCatalog.event_for()` math were reproduced for the 8 authored coordinates.

All anchors remain non-POI finite encounters and resolve to the expected scene:

- `(1,-2)` — `north_woodland` / `abandoned_camp`;
- `(6,-2)` — `outer_woodland` / `abandoned_camp`;
- `(3,-6)` — `outer_residential` / `repair_breakdown`;
- `(-5,1)` — `outer_industrial` / `looted_convoy`;
- `(2,5)` — `industrial_belt` / `looted_convoy`;
- `(3,1)` — `industrial_belt` / `feeding_site`;
- `(-5,4)` — `dacha_west` / `feeding_site`;
- `(-6,5)` — `outer_rural` / `feeding_site`.

Unique story ids: **8/8**.

## Narrative boundary — PASS

`world/environmental_story_catalog.gd` contains no reward/loot/enemy-count/route/objective/target/reputation/items/spawn-id/map-marker fields.

All story ids fit `STORY_ID_LIMIT=80`; all authored body texts fit `TEXT_LIMIT=220`; interaction prompts are restricted to short nouns suitable for the existing 160×22 interaction surface.

Only existing `paper_stack` / `newspapers` atlas mappings are used.

## Scene-placement audit — PASS

All 8 trace positions are inside the corresponding encounter footprint.

After an additional overlap review, all traces were moved clear of existing scene props and cosmetic dev2 accents. Static minimum center clearance: **22 px** or greater for every trace.

No collision or navigation nodes are added; story traces are sprite-only interactables.

## Chronicle / save compatibility — PASS (static/reference)

`WorldChronicle` keeps the existing history format and adds:

- valid kind `story`;
- nested `story_seen` list, limit 96;
- `story_seen()` and `append_story()` helpers.

Reference/static checks confirm:

- first read appends one history entry and records story id;
- repeat read does not grow history;
- old chronicle dictionaries without `story_seen` sanitize to an empty seen list;
- production save payload still writes `"save_version":122`;
- story state remains inside existing `faction_state.world_chronicle`;
- no `environmental_story` / `story_clues` top-level save object is introduced.

The existing production save payload key was verified directly as `faction_state`; the dev1 save QA uses that actual key.

## Static / regression QA — PASS

Short independent batches verified:

1. New helper + four QA scripts and modified chronicle pass quote/comment-stripped delimiter balance.
2. Literal changed/new `preload("res://...")` references resolve.
3. Eight authored anchors reproduce the live Region/Encounter result and do not overlap authored POI footprints.
4. Protected gameplay/catalog files are byte-identical to dev3: encounter catalog, region catalog, POI catalog, faction economy, supply, projects, endgame, contracts, High Risk, trading and save store.
5. Production save writer remains schema **122**.
6. Named NPC roster remains **16 unique** (4 × 4 factions).
7. Source PNG: **651/651 byte-identical** to dev3; changed 0.
8. Dev3 → dev1 removed baseline files: **0**.
9. Current build metadata / SELFTEST / current High Risk visual gate consistently use `1.25.0-dev1`.
10. No `.godot`, temporary or backup files are intended for the release archive.

Expected functional baseline changes before docs:

- `world/world_chronicle.gd`;
- `main_script_mod.gd`;
- `project.godot`;
- `BUILD_VERSION.txt`;
- `BRANCH.txt`;
- `ROADMAP_RELEASE_RU.md`;
- current `tests/test_high_risk_visual_multifloor.gd` version gate.

New files:

- `world/environmental_story_catalog.gd`;
- `tests/test_environmental_storytelling_125.gd`;
- `tests/test_environmental_storytelling_runtime_125.gd`;
- `tests/test_environmental_storytelling_save_runtime_125.gd`;
- `tests/qa_environmental_storytelling_capture.gd`;
- this README and QA report.

## Runtime certification — PENDING

No Godot executable is available in the current container. Run as separate short groups under Godot 4.7.2:

```bash
godot --headless --path . --script tests/test_environmental_storytelling_125.gd

godot --headless --path . --script tests/test_environmental_storytelling_runtime_125.gd

QA=/tmp/ostatok_125_dev1_save_qa
rm -rf "$QA" && mkdir -p "$QA"
XDG_DATA_HOME="$QA" OSTATOK_QA_SAVE_ROOT="$QA" \
  godot --headless --path . --script tests/test_environmental_storytelling_save_runtime_125.gd

CAP=/tmp/ostatok_125_dev1_captures
rm -rf "$CAP" && mkdir -p "$CAP"
xvfb-run -a godot --path . --script tests/qa_environmental_storytelling_capture.gd -- --qa-output="$CAP"
```

Then separately run clean import, direct `main.tscn` SELFTEST and broad historical regression in small groups.

No Godot runtime/capture/SELFTEST counts are fabricated in this report.
