OSTATOK 0.54.0 — DIRECTIONAL CHARACTER POLISH

Visual/animation stage focused on the playable character.

CHANGES
- New 8-direction upper-body atlases (player_pose_back_v17 / player_pose_front_v17).
- New 8-direction, distance-driven leg atlas with separate walk/run/idle rows.
- Player body no longer uses horizontal mirroring as the primary facing system.
- Upper body follows aim in 8 directions; legs follow actual movement direction, enabling readable strafing/backpedalling.
- Held firearms use 16-step quantized visual aim, reducing pixel shimmer while following the cursor much more closely.
- Visible recoil now pushes the held weapon back along the aim vector.
- Reload has a visible inward/tilt arc instead of only changing a state row.
- Melee held item now follows the existing swing curve through the unified weapon root.
- Character scale/alignment and leg overlap were retuned after engine-side screenshot review.

QA
- Godot 4.7.2 clean import.
- Runtime SELFTEST.
- inventory / clinic / player / infected / facade / exterior QA modes.
- X11 engine-side input test: idle aim, walk, sprint, vertical movement/aim and reload after firing.
- Visual QA now resets health/wounds and suppresses enemy damage so screenshots are deterministic instead of inheriting a wounded save.

NOTES
- References supplied by the user were used only as art direction; no reference image fragments are embedded.
- Existing save/application project name is intentionally preserved to keep user:// compatibility.
