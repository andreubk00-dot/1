# QA — OSTATOK 1.29.0-dev2 Infected & Combat SFX

## Engine

Godot `4.7.2.stable.official.ed1daf0bf`.
Engine ZIP SHA-256:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`

## Clean import

`.godot` removed before import.
`godot --headless --path . --import`: **exit 0**.
Parse/load errors: **0**.

## New runtime audio

- `test_infected_combat_sfx_129.gd`: **44/44**.

This test loads all seven new WAVs, validates distance attenuation and exercises real nonlethal `_damage_enemy`, `_apply_enemy_hit`, and completed Screamer-call paths while asserting their gameplay results are unchanged.

## Protected runtime regression

- High Risk visual/multifloor: **130/130**.
- Save recovery: **18/18**.
- Main selftest: `OSTATOK 1.29.0-dev2 SELFTEST: OK`, failures=0.

Historical role suites were run without editing their old version gate:

- Screamer: **48 checks / 1 failure** — only `current build version mismatch` (`1.22.0` historical gate).
- Spitter: **71 / 1** — only the same historical gate.
- Carrier: **73 / 1** — only the same historical gate.

The infected-navigation suite exceeded the deliberately short external 30 s timeout because it advances thousands of physics frames. This is not recorded as a game failure and was not used as a release blocker for an audio-only additive change.

## Deterministic assets

Re-running `tools/build_infected_audio.py` produced byte-identical WAVs.
Combined generated-audio SHA state:
`15558f71e407c083523b54c6a80cf01e3b3656e4f81e84e4eadfdf28725f9689`

## Boundary

Compared with 1.29.0-dev1:

- only version/roadmap/current visual gate, additive audio wiring, seven WAV files, one audio builder and one new runtime test changed;
- 651/651 PNG assets present, 0 changed;
- save writer remains schema 122;
- no new persistent audio state;
- historical 1.22 version gates untouched.
