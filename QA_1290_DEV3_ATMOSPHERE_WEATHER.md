# QA — OSTATOK 1.29.0-dev3 Atmosphere & Weather

## Engine

Godot `4.7.2.stable.official.ed1daf0bf`.
Engine ZIP SHA-256:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

## Clean import

`.godot` was removed before import.
`godot --headless --path . --import`: Godot return code **0**.
Parse/load errors: **0**.
(The surrounding shell emitted a TERM-environment message after Godot had already returned 0; this is not a project failure.)

## New runtime audio

- `test_ambience_audio_129.gd`: **41/41**.
- `test_ambience_audio_save_boundary_129.gd`: **6/6**.

The runtime test validates all four WAVs, 4-second duration, `AudioStreamWAV` forward-loop configuration and day/night/interior/rain selection. Immediate headless shutdown can print the known AudioServer cleanup warning while active loop resources are being released; test exit code is 0 and functional checks are clean.

## Protected runtime regression

- World survival polish: **120/120**.
- Shelter integrity: **22/22**.
- Main selftest: `OSTATOK 1.29.0-dev3 SELFTEST: OK`, failures=0.

## Boundary

Compared with 1.29.0-dev2:

- gameplay weather/survival/AI systems are not rewritten;
- four additive WAVs, one deterministic audio builder, ambience wiring and two QA files are added;
- save writer remains schema 122;
- no persistent ambience state;
- 651/651 PNG assets remain unchanged.
