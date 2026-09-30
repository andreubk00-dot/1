OSTATOK 0.59.0 — CHARACTER PROPORTION / GAIT POLISH

Character anatomy and gait pass:
- shortened/hidden neck; head seated deeper into collar/shoulders
- backpack moved lower onto the upper/mid back and reshaped with tapered silhouette
- legs rebuilt as separate thigh/calf/boot volumes instead of a single tapered column
- compact polygon boots replace long horizontal foot strokes
- 12-phase contact/loading/passing/swing gait instead of symmetric sine pendulum
- reduced vertical body bob and exaggerated sway; more grounded weight transfer
- longer distance-driven gait cycle: 60 px walk / 68 px sprint
- all weapon classes now use the v7 cohesive character atlases (fixed old v6 cache fallback)
- QA screenshot delay flag added for multi-phase engine gait verification

Gameplay movement speed remains from 0.58:
- walk: 64 px/s
- sprint multiplier: 1.32

QA performed in Godot 4.7.2:
- clean asset reimport
- runtime + inventory/clinic/player/infected/infected-motion/facade/exterior
- X11 visual captures for idle, walking, sprint, pistol, melee, reload and back view
- six timed in-engine gait-phase captures
