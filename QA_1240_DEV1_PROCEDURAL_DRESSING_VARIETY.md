# QA — OSTATOK 1.24.0-dev1 Procedural Dressing Variety

## Baseline

- Source baseline: `OSTATOK_1.23.0-dev18_District_Survey_Context.zip`.
- Baseline SHA-256: `85c6ec33e05e824779c679b73ec4f17cb5e9b0d1bb5f41ea05978e2d32f89c56`.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- Historical 1.22 Stable version gates are not rewritten.

## Repetition audit before implementation

`ChunkLayoutCatalog` already varies slot position/scale by coordinate, but procedural archetype selection inside a building-set remains intentionally stable by persistent slot. Several purely visual detail functions also used only repeating ids such as `building_0` as their seed.

Result: two different sectors could have different building placement while still repeating conspicuously similar floor/roof dressing in corresponding slots.

Changing archetype/loot/container composition of already explored chunks would be much riskier for schema-122 compatibility, so dev1 deliberately fixes only the cosmetic layer.

## Dev1 implementation

New `world/world_content_variety.gd` provides:

- four cosmetic groups: residential / commercial / garage / warehouse;
- **3 variants per group**;
- deterministic `variant_for(coord, archetype_id, building_index)`;
- deterministic coordinate-aware `visual_seed_key()`;
- profiles containing only non-colliding visual prop specs.

The procedural generator attaches derived `content_variant/content_seed` only when:

- chunk is not on the legacy zone path;
- `preserve_082_layout` is false;
- the archetype belongs to dev1 scope.

Authored compound POIs bypass this path.

## Reference variety audit — PASS

Independent reference implementation reproduced the dev1 hash/selection formula.

Isolated coordinate grid `[-8..8]`:

- **16/16** target archetypes exercise variants `{0,1,2}`.

25×25 district-potential grid (`[-12..12]`):

- all common target archetypes (>=10 occurrences) exercise all three variants;
- low-frequency targets with >=3 occurrences exercise at least two variants;
- `cafe`: 4 occurrences / 2 variants (valid low-frequency case);
- `rail_service`: 5 occurrences / 2 variants;
- `rail_store`: 5 occurrences / 2 variants.

Building-set variant signatures:

- `mixed_residential`: 3;
- `dacha_coop`: 3;
- `industrial_belt`: 3;
- `old_center`: 3;
- `panel_estate`: 3 in district potential (core cells themselves are authored POI territory);
- `commercial_strip`: 2 across its four non-frequency-limited macro cells;
- `rail_service`: 2 across five macro cells.

This fixes the verified visual repetition without randomizing persistent gameplay identity.

## Static / boundary QA — PASS

Short independent batches verified:

1. New/changed dev1 GDScript files have balanced delimiters after quote/comment stripping.
2. No merge-conflict markers.
3. All changed/new `preload("res://...")` targets exist.
4. Project-wide literal resource scan: **730** `res://` references resolve.
5. System-test coverage includes **16/16** target archetypes.
6. All **19/19** prop kinds referenced by dev1 profiles exist in `_world_prop_region()` / current `world_props_v19.png` atlas mapping.
7. Profiles contain no loot/container/door/size/collision/risk/farm/refresh gameplay fields.
8. `_decorate_interior_floor_details()` now uses only `visual_seed_id`; no stale undefined `building_id` reference remains.
9. `_create_building()` passes the coordinate-aware visual seed to floor detail and generic roof decoration.
10. Major authored POI path has no WorldContentVariety injection before the non-authored procedural branch.
11. `preserve_082_layout` explicitly blocks `content_variant/content_seed` injection.
12. `_save_state()` and `_load_state()` are byte-identical to dev18.
13. `_add_segmented_south_wall`, `_breachable_window_xs`, `_create_door`, `_create_container` are byte-identical to dev18.
14. `BUILDING_LAYOUT_VERSION` remains **4**.
15. Production writer still emits `save_version: 122`.
16. `content_variant`, `content_seed`, `world_content_variety`, `procedural_dressing` do not appear in production save/load functions or `world/save_store.gd`.
17. Named NPC roster remains **16 unique / 4 per faction**.
18. Protected gameplay/catalog files: **16/16 SHA-identical** to dev18, including faction economy, contracts, High Risk, supply/crisis, endgame, projects, trading, save store, region/POI/building/chunk catalogs.
19. Source PNG: **651/651 byte-identical** to dev18; added 0 / removed 0 / changed 0.
20. No `.godot`, tmp, backup or merge artifacts are intended for the release ZIP.

## Release metadata repair

The dev18 package had a non-gameplay packaging inconsistency: `project.godot`/SELFTEST were dev18, while `BUILD_VERSION.txt` and `BRANCH.txt` still contained dev17 metadata.

Dev1 synchronizes release metadata to `1.24.0-dev1`. This does not change save schema or gameplay.

## Expected functional delta

Gameplay/runtime code delta is intentionally narrow:

- `main_script_mod.gd` — derived procedural dressing + coordinate-aware visual seeds + dev1 selftest/version;
- `world/world_content_variety.gd` — new cosmetic-only helper;
- `tests/test_world_content_variety_124.gd`;
- `tests/test_world_content_variety_runtime_124.gd`;
- `tests/test_world_content_variety_save_runtime_124.gd`;
- `tests/qa_world_content_variety_capture.gd`;
- current version gate / metadata / roadmap / release docs.

No canonical BuildingCatalog or ChunkLayoutCatalog data was changed.

## Runtime certification — PENDING

No Godot executable is available in the current container. Prior short attempts to retrieve the official Godot 4.7.2 Linux binary failed due environment network/DNS restrictions; no repeated long download is attempted.

Run these as separate short packages when Godot 4.7.2 is available:

```bash
godot --headless --path . --script tests/test_world_content_variety_124.gd

godot --headless --path . --script tests/test_world_content_variety_runtime_124.gd

QA=/tmp/ostatok_dev1_save_qa
rm -rf "$QA" && mkdir -p "$QA"
XDG_DATA_HOME="$QA" OSTATOK_QA_SAVE_ROOT="$QA" \
  godot --headless --path . --script tests/test_world_content_variety_save_runtime_124.gd

CAP=/tmp/ostatok_dev1_captures
rm -rf "$CAP" && mkdir -p "$CAP"
xvfb-run -a godot --path . --script tests/qa_world_content_variety_capture.gd -- --qa-output="$CAP"
```

Then separately run clean import, direct `main.tscn` SELFTEST, and the broad historical regression in small groups.

No Godot runtime/capture/SELFTEST counts are fabricated in this report.
