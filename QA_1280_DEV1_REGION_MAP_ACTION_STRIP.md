# QA — OSTATOK 1.28.0-dev1 Region Map Action Strip

## Engine

Godot `4.7.2.stable.official.ed1daf0bf`.
Engine ZIP SHA-256:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

## Import

Clean import from package-style project without `.godot`: PASS, exit 0, parse/load errors 0.

## Runtime

- `test_region_map_action_strip_128.gd`: 12/12.
- `test_district_survey_context_runtime_123.gd`: 10/10.
- `test_freeplay_handoff_runtime_123.gd`: 13/13.
- `test_established_route_map_runtime_123.gd`: 10/10.
- Main `--qa-selftest-exit`: failures=0.

Selected map/free-play checks: **45/45**.

## Visual QA

Xvfb + X11 + OpenGL compatibility capture at the project 640×360 viewport:
- long known-sector district survey context;
- both fixed expedition buttons fully visible;
- bottom navigation remains unobstructed;
- scroll remains available for marker/details content.

The ALSA warning in the QA container falls back to Dummy audio and does not affect UI rendering.

## Boundary

Compared with 1.27.0-dev3:
- only expected version/roadmap/UI integration + 2 new QA files changed before documentation;
- PNG: 651/651 present, 0 changed;
- `.godot` and import-only newly generated `.gd.uid` excluded;
- save writer remains schema 122.
