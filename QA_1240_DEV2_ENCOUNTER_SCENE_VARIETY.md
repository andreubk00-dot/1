# QA — OSTATOK 1.24.0-dev2 Encounter Scene Variety

## Baseline

- Source baseline: `OSTATOK_1.24.0-dev1_Procedural_Dressing_Variety.zip`.
- Baseline SHA-256: `b6706c2a6e3f082c9a02d830421145a18ce291eb077eb9208ccf57a0030845b6`.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- Historical 1.22 Stable version gates are not rewritten.

## Repetition audit before implementation

Reference implementation reproduced `RegionCatalog.chunk_profile()` + `EncounterCatalog.event_for()` over `[-20..20]²` while excluding authored POI cells exactly as production does.

Result: **100 finite encounter scenes**:

- abandoned_camp 46;
- failed_evacuation 4;
- repair_breakdown 14;
- feeding_site 24;
- looted_convoy 12.

Event selection already varied by world position, but each event-id had one fixed prop arrangement in `_build_world_event()`.

## Dev2 implementation

New `world/encounter_scene_variety.gd`:

- supports only the five finite `EncounterCatalog.EVENTS` ids;
- `VARIANT_COUNT = 3`;
- uses coordinate + event-id derived integer mix;
- returns exactly two cosmetic sprite accents per variant;
- has no loot/enemy/container/collision/persistence fields;
- returns `-1` / empty accents for `supply_convoy` and all unsupported ids.

`main_script_mod.gd` applies this cosmetic layer after the existing base event scene and before unchanged loot/enemy creation. `scene_variant` is node metadata only.

## Hash-correlation regression — PASS

The first draft hash collapsed all four reference `failed_evacuation` scenes into one modulo-3 cosmetic result. That draft was rejected before packaging.

Final reference distribution:

- abandoned_camp 46 → v0 14 / v1 22 / v2 10;
- failed_evacuation 4 → v0 1 / v1 1 / v2 2;
- repair_breakdown 14 → v0 6 / v1 5 / v2 3;
- feeding_site 24 → v0 11 / v1 10 / v2 3;
- looted_convoy 12 → v0 3 / v1 6 / v2 3.

All five finite event ids exercise variants `{0,1,2}` in the audited reference world.

## Static / boundary QA — PASS

Short independent batches verified:

1. Baseline dev1 ZIP SHA matches the recorded release SHA.
2. `world/encounter_catalog.gd` is byte-identical to dev1.
3. Protected gameplay/catalog files are byte-identical to dev1: faction economy, save store, contracts, High Risk, supply events, settlement crises, faction endgame, settlement projects and trading market.
4. `_save_state()` and `_load_state()` are byte-identical to dev1.
5. `_create_container()` is byte-identical to dev1.
6. Production save writer still emits `save_version: 122`.
7. New helper has balanced delimiters after quote/comment stripping.
8. New dev2 system/runtime/save/capture QA files have balanced delimiters.
9. No merge-conflict markers.
10. **388** project `preload()` references resolve; missing 0.
11. All **19** prop kinds referenced by dev2 profiles exist in the current `_world_prop_region()` atlas mapping.
12. New profiles contain no loot/enemy/spawn/container/interaction/collision/risk/refresh fields.
13. `supply_convoy` explicitly bypasses dev2 variety in both helper and integration path.
14. Named NPC roster remains **16 unique**.
15. Source PNG: **651/651 byte-identical** to dev1; changed 0.
16. No baseline files removed.
17. Functional source delta before docs is limited to `main_script_mod.gd` + new `world/encounter_scene_variety.gd`; remaining baseline changes are version metadata/current visual gate.

## Runtime certification — PENDING

No Godot executable is available in the current container. The following must be run as short independent groups when Godot 4.7.2 is available:

```bash
godot --headless --path . --script tests/test_encounter_scene_variety_124.gd

godot --headless --path . --script tests/test_encounter_scene_variety_runtime_124.gd

QA=/tmp/ostatok_dev2_save_qa
rm -rf "$QA" && mkdir -p "$QA"
XDG_DATA_HOME="$QA" OSTATOK_QA_SAVE_ROOT="$QA" \
  godot --headless --path . --script tests/test_encounter_scene_variety_save_runtime_124.gd

CAP=/tmp/ostatok_dev2_captures
rm -rf "$CAP" && mkdir -p "$CAP"
xvfb-run -a godot --path . --script tests/qa_encounter_scene_variety_capture.gd -- --qa-output="$CAP"
```

Then separately run clean import, direct `main.tscn` SELFTEST and the broad historical regression in small groups.

No Godot runtime/capture/SELFTEST counts are fabricated in this report.
