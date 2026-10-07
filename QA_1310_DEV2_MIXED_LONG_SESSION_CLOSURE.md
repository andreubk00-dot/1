# QA — OSTATOK 1.31.0-dev2 Mixed Long-Session Closure

Engine: Godot 4.7.2 stable (`ed1daf0bf`).

## New closure test

`test_mixed_long_session_closure_131.gd`: **82/82**.

Metrics:
- transitions: 48 + full revisit pass;
- node count: 8255 -> 8255; revisit 8255;
- roof records stable;
- first-pass saves: 170402, 183932, 197646, 212762, 231424, 251614 bytes;
- fully materialized baseline: 252012 bytes;
- full revisit: 252012 bytes;
- max save write: 40706 microseconds.

The first-pass growth is deterministic object persistence materialization, not an unbounded leak. Revisit stability is the closure criterion.

## Release gates

Run separately after version bump:
- save recovery;
- High Risk visual/multifloor;
- trading;
- main selftest.

## Final release gates

- save recovery: **18/18**.
- High Risk visual/multifloor: **130/130**.
- trading economy: **512/512**.
- main SELFTEST marker: `OSTATOK 1.31.0-dev2 SELFTEST: OK`.
- the outer runner timed out only after the OK marker; no Godot process remained.
- PNG assets: **651/651 byte-identical** to dev1.
- gameplay GDScript changes vs dev1: **0**.
- save schema remains **122**.
