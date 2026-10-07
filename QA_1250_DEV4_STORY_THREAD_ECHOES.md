# QA — OSTATOK 1.25.0-dev4 Story Thread Echoes

## Baseline

- Source baseline: `OSTATOK_1.25.0-dev3_High_Risk_Environmental_Traces.zip`.
- Baseline SHA-256: `06dd6a86356768eae1cc4645d3f568caab3cfcb7ada742032119cd6f6fd31bf9`.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- Historical 1.22 Stable version gate is untouched.

## Narrative coherence audit — PASS (static/reference)

Current 1.25 authored clue pool: **24 unique story ids**.

`StoryThreadCatalog` adds exactly **5** synthetic summary ids. Each thread:

- requires exactly 3 existing authored clue ids;
- has no duplicated prerequisite;
- does not collide with an authored clue id;
- does not trigger with only 2 prerequisites;
- does trigger when all 3 are seen;
- does not trigger again once its own synthetic id is seen.

## Chronicle length bug found/fixed

Initial dev4 draft had all five summary texts long enough that `title + body` exceeded `WorldChronicle.TEXT_LIMIT=220`, so the chronicle would silently truncate their endings.

Texts were shortened without changing meaning. Final combined lengths:

- medical: **215**;
- quarantine: **219**;
- security: **216**;
- infrastructure: **214**;
- logistics: **210**.

System QA now enforces the 220-character boundary.

## Gameplay / persistence boundary — PASS

The new thread catalog contains no reward, loot, objective, route, target, reputation, item, spawn, map-marker, strategic-item or access semantics.

Static checks confirm:

- production writer remains `save_version 122`;
- no `story_threads` / `story_thread_state` top-level save field exists;
- synthetic ids reuse `faction_state.world_chronicle.story_seen`;
- `world/world_chronicle.gd` is byte-identical to dev3;
- High Risk mechanics, POI/region, economy, contracts, projects, endgame, supply/crisis, trading and save store are byte-identical to dev3.

## Regression boundary — PASS

- Named NPC roster: **16 unique**, 4 per faction.
- PNG assets: **651/651 byte-identical** to dev3.
- Current High Risk visual version gate updated to dev4.
- Historical stable version gate not rewritten.

## Runtime certification — PENDING

Run under Godot 4.7.2 as separate short groups:

```bash
godot --headless --path . --script tests/test_story_thread_echoes_125.gd

godot --headless --path . --script tests/test_story_thread_echoes_runtime_125.gd

QA=/tmp/ostatok_125_dev4_save_qa
rm -rf "$QA" && mkdir -p "$QA"
XDG_DATA_HOME="$QA" OSTATOK_QA_SAVE_ROOT="$QA" \
  godot --headless --path . --script tests/test_story_thread_echoes_save_runtime_125.gd

CAP=/tmp/ostatok_125_dev4_captures
rm -rf "$CAP" && mkdir -p "$CAP"
xvfb-run -a godot --path . --script tests/qa_story_thread_chronicle_capture.gd -- --qa-output="$CAP"
```

Then separately run current High Risk visual QA, clean import, `main.tscn` SELFTEST and broad regression in small groups.

No runtime/capture/SELFTEST PASS is fabricated in this report.
