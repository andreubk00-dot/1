# OSTATOK 1.29.0-dev1 — World Interaction SFX

First Audio & Atmosphere final-pass slice.

## What changed

Eight deterministic original WAV assets are added under `audio/world/` and connected to existing committed gameplay actions:

- walk footsteps;
- sprint footsteps;
- door open;
- door close;
- dropped item impact;
- melee swing;
- melee hit;
- loud workbench / construction / repair operations.

The audible layer mirrors existing actions only. AI hearing still uses the pre-existing `_emit_ai_sound()` radii, signatures and timers; none of those values were changed.

## Safety boundaries

- Save schema remains **122**.
- No new persistent audio state.
- Weapon audio is unchanged and keeps its existing voice pool.
- Door collision/state, melee damage/range, movement speed, stamina, crafting/build costs and interaction timing are unchanged.
- Bedroll deploy/pack intentionally remains soft and does not reuse the metal workbench sound.
- Existing 651 PNG assets are byte-identical to 1.28.0-dev3.

## Engine verification

Godot 4.7.2 stable was supplied and verified by SHA-256 before use.
Clean import and selected runtime regression were run in isolated short batches; see `QA_1290_DEV1_WORLD_INTERACTION_SFX.md`.
