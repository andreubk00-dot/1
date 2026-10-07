# OSTATOK 1.29.0-dev4 — UI Feedback & Audio Closure

Final Audio & Atmosphere slice.

## What changed

Three deterministic compact UI cues were added:

- `ui_open`;
- `ui_close`;
- `ui_confirm`.

They reuse the existing six-voice world-audio pool. Open/close cues are wired only to central panel transitions; confirm plays only after already-successful craft, trade and contract actions. No audio cue participates in validation or changes the result of an action.

## 1.29 closure

Together with dev1–dev3 the final audio pass now covers:

- firearm/reload/cycle audio;
- footsteps, doors, item drops, melee and workbench/world interaction;
- infected attack/hurt/death/call/spit and player hit feedback;
- day/night/interior ambience and rain;
- compact UI feedback.

## Safety boundaries

- Save schema remains **122**.
- AI hearing remains controlled only by gameplay noise functions.
- Prices, contracts, crafting outputs, combat values, weather and survival are unchanged.
- 651 PNG assets remain unchanged.
