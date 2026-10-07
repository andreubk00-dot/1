# QA — OSTATOK 1.25.0-dev3 High Risk Environmental Traces

## Baseline

- Source baseline: `OSTATOK_1.25.0-dev2_Authored_POI_Traces.zip`.
- Baseline SHA-256: `6f6900b9c489ef220d92b53ae8fb80c3726cd2d6e5dbbb20c6d3a452942cc87b`.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- Historical 1.22 Stable version gates are not rewritten.

## High Risk narrative audit — PASS (static/reference)

`HighRiskStoryCatalog` contains exactly **8** unique story ids:

- 4 ground traces — one per existing High Risk site;
- 4 floor traces — one per existing High Risk site, all on existing floor 3.

Explicit boundary:

- floor 2 receives **0** new story traces;
- no ordinary POI or faction settlement lookup resolves through this catalog;
- ids do not collide with dev1 finite-encounter or dev2 ordinary-POI story ids.

## Progression / strategic boundary — PASS

The catalog contains no reward, loot, enemy-count, route, objective, target, reputation, items, spawn-id, map-marker, strategic-item, cache-id or access fields.

Authored text was also checked for progression leakage: it does not name `cache_3`, strategic items, keys or item locations.

No changes were made to:

- `world/high_risk_mechanics.gd`;
- `world/high_risk_floor_catalog.gd`;
- `world/high_risk_site_catalog.gd`;
- `loot_refresh_sites` logic;
- strategic-item installation/access;
- incident generation/resolution.

## Geometry / placement — PASS (static/reference)

Ground traces use open authored yard/courtyard positions, remain inside chunk-safe bounds and are separated from loose `cache_3` containers. Deep-floor traces are inside floor bounds, more than the interaction clearance from authored containers, and away from the down-transition position.

Runtime/capture scripts additionally verify actual production scene construction under Godot.

## Persistence boundary — PASS (static/reference)

Dev3 adds no top-level narrative save state. Read state continues through existing `WorldChronicle.append_story()` / `story_seen` under `faction_state.world_chronicle`.

Static checks confirm:

- production writer still emits `save_version 122`;
- no `high_risk_story` / `high_risk_story_seen` save key is written;
- `world/world_chronicle.gd` remains unchanged from dev2.

## Static / regression QA — PASS

Short independent batches verified:

1. New catalog + four QA scripts pass quote/comment-stripped delimiter balance.
2. New literal `preload("res://...")` references resolve.
3. 8 story ids are unique and contain no gameplay/progression fields.
4. Dev2→dev3 functional diff is limited to the integration layer, new catalog/tests and current version metadata/gate/docs.
5. Protected High Risk, POI, region, economy, contracts, projects, endgame, supply/crisis, trading and save files are byte-identical to dev2.
6. Named NPC roster remains **16 unique** — 4 per faction.
7. Source PNG: **651/651 byte-identical** to dev2; changed 0.
8. Production schema remains **122**.

## Runtime certification — PENDING

Run in short independent groups under Godot 4.7.2:

```bash
godot --headless --path . --script tests/test_high_risk_storytelling_125.gd

godot --headless --path . --script tests/test_high_risk_storytelling_runtime_125.gd

QA=/tmp/ostatok_125_dev3_save_qa
rm -rf "$QA" && mkdir -p "$QA"
XDG_DATA_HOME="$QA" OSTATOK_QA_SAVE_ROOT="$QA" \
  godot --headless --path . --script tests/test_high_risk_storytelling_save_runtime_125.gd

CAP=/tmp/ostatok_125_dev3_captures
rm -rf "$CAP" && mkdir -p "$CAP"
xvfb-run -a godot --path . --script tests/qa_high_risk_storytelling_capture.gd -- --qa-output="$CAP"
```

Then separately run current High Risk visual QA, clean import, `main.tscn` SELFTEST and broad regression in small groups.

No runtime/capture/SELFTEST PASS is fabricated in this report.
