# OSTATOK 1.29.0-dev2 — Infected & Combat SFX

Second Audio & Atmosphere final-pass slice.

## What changed

Seven deterministic original WAV assets were added under `audio/infected/`:

- infected attack;
- infected hurt;
- infected death;
- Screamer call;
- Spitter launch;
- player melee-hit feedback;
- Spitter impact feedback.

Infected-source sounds use presentation-only distance attenuation from the player. The audio layer does not participate in AI hearing and does not alter combat values.

## Safety boundaries

- Save schema remains **122**.
- `damage`, `attack_interval`, detection/hearing radius, Screamer/Spitter/Carrier cooldowns and encounter spawn mixes are unchanged.
- Existing `_emit_ai_sound()` remains authoritative for AI hearing.
- 651 PNG assets remain byte-identical to dev1.
- Historical infected test version gates requiring `1.22.0` remain intentionally untouched.
