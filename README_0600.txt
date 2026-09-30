OSTATOK 0.60.0 — ANATOMICAL LOCOMOTION POLISH

Character / locomotion pass:
- new v8 cohesive character atlases for longgun, pistol and melee
- pelvis now transfers over the planted leg while shoulders remain comparatively stable
- legs rebuilt with persistent left/right anatomical ownership instead of converging on the center line
- near/far leg depth in 3/4 views; far leg sits slightly higher/darker, near leg slightly lower/brighter
- separate thigh/calf volumes with stronger knee flexion and nested knee-pad volume
- compact tactical boots with toe lift instead of horizontal stretched foot strokes
- trigger hand moved closer to the torso; support hand farther forward; elbows lowered toward the ribcage
- backpack lowered and shortened; head seated slightly deeper in shoulders
- smaller exposed skin patch in hands/face; stronger beard/collar integration
- root-level body bob and side sway reduced: gait motion now comes primarily from the baked anatomy
- acceleration visual impulse reduced so starts/stops read as weight transfer instead of sprite sliding
- walk gait distance increased to 72 px; sprint gait distance to 88 px
- QA flag --qa-gait-phase=0..1 added for deterministic engine-side gait frame inspection

Movement speed remains:
- walk: 64 px/s
- sprint multiplier: 1.32

Godot 4.7.2 QA:
- clean import + normal runtime: SELFTEST OK
- inventory / clinic / player / infected / infected-motion / facade / exterior: exit 0, SELFTEST OK, no game errors
- X11 captures: idle, six fixed gait phases, sprint, walk-up, reload, pistol
- X11 logs: no game errors; only virtual-display V-Sync warning
