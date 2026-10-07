# QA — OSTATOK 1.29.0-dev4 UI Feedback & Audio Closure

## Engine

Godot `4.7.2.stable.official.ed1daf0bf`.
Engine ZIP SHA-256:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

## Import / new tests

- clean import: Godot return code **0**, parse/load errors **0**;
- UI audio feedback: **35/35**;
- audio closure save-boundary: **6/6**.

Immediate headless shutdown after WAV playback can print the known AudioServer resource-cleanup warning. Functional test exit codes remain 0.

## Audio regression

- weapon audio: **113/113**;
- weapon action cycles: **48/48**;
- world interaction SFX: **68/68**;
- infected/combat SFX: **44/44**;
- ambience: **41/41**.

## Protected gameplay regression

- High Risk visual/multifloor: **130/130**;
- trading economy: **512/512**;
- save recovery: **18/18**;
- main selftest: `OSTATOK 1.29.0-dev4 SELFTEST: OK`, failures=0.

## Boundary

- save schema: **122**;
- UI/audio runtime state is not persisted;
- historical 1.22 gates are untouched;
- no audio cue changes gameplay validation, AI hearing or world simulation;
- 1.29 is marked **ГОТОВО** after this closure slice.
