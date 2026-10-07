# OSTATOK 1.29.0-dev3 — Atmosphere & Weather

Third Audio & Atmosphere final-pass slice.

## What changed

Four deterministic original 4-second ambience loops were added under `audio/ambience/`:

- outdoor day bed;
- outdoor night bed;
- rain layer;
- interior roomtone.

The layer is presentation-only. It reads the existing `world_minutes`, `weather_state` and `is_sheltered` values. Outdoor day/night and interior roomtone are mutually exclusive base beds; rain is a separate layer and is muted when the player is sheltered.

## Safety boundaries

- Save schema remains **122**.
- Weather generation, wetness, temperature, visibility, stamina and AI hearing are unchanged.
- No ambience value is persisted.
- Existing interaction/weapon/infected audio remains unchanged.
- 651 PNG assets remain byte-identical to dev2.
