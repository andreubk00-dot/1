OSTATOK 0.67.1 — DEV ZOMBIE SLOWDOWN

Temporary development balance change:
- infected base speed remains documented as 60 px/s
- active development multiplier: 0.36
- effective infected chase speed: 21.6 px/s
- investigate/search/return speeds scale from the same reduced value

Purpose:
- keep infected functional for AI/navigation/combat testing
- stop them from immediately dog-piling the player while character/world/UI development is in progress

To restore normal infected movement later:
- set DEV_ENEMY_SPEED_MULT back to 1.0

No player art, animation sheets, HUD, inventory, save data or world art changed in this pass.
