OSTATOK 1.04.0 — World Survival & Exploration Polish

This stage polishes the existing exploration/survival loop without adding a parallel gameplay system.

Key changes
- Removed the temporary global infected slowdown left from development. Base infected movement is 60 px/s; healthy player walk is 64 px/s and sprint remains 1.32x. Existing fatigue, injury and encumbrance penalties still apply to the player.
- Added lightweight local obstacle steering for infected. It does not add a second AI state machine: chase/investigate/search/return remain authoritative. Steering only avoids ordinary solid geometry and never dodges an active breachable door/window/barricade.
- Infected keep a stable temporary avoidance side long enough to get around short obstacles instead of oscillating against walls.
- Firearm ray origin is clamped to the player's side of nearby world collision, preventing close-wall shots from starting beyond the wall.
- Dropped items are clamped to the player's side of nearby world collision instead of appearing through walls.
- Interactions now require an unobstructed world line. Containers and other interactables behind a separate solid wall cannot be selected through it; the blocking breach object itself remains interactable.
- Loot generation and building loot tables were audited and regression-tested for deterministic persistent-container generation, known item IDs and valid grid placement. No new loot economy was added.
- Quick slots 1–6 and inventory input ownership remain unchanged and regression-tested.
- Shelter assault behavior and breach routing remain compatible with 1.03.1.

Save compatibility
- save_version remains 97.
- No new persistent fields were introduced by this stage.

QA
- New tests/test_world_survival_polish.gd covers wall-safe firing/dropping/interactions, infected movement balance and local steering, loot generation and quick slots.
