OSTATOK 0.70.0 — MELEE CLEANUP PASS

Fixes:
- melee no longer switches back to the legacy full-body/segmented player
- imported survivor remains the only visible player body for knife, pipe, axe and firearms
- legacy pose layers, segmented body parts, procedural arm rigs and old melee trail are hard-hidden while the modern survivor is active
- knife uses the authored Attack4 survivor clip during swings; pipe/axe use Attack3
- melee weapon sprite is still displayed and positioned by the existing grip system without reviving old body art
- weapon mod sprites and muzzle flash are explicitly disabled for melee

QA:
- Godot 4.7.2 import: OK
- runtime selftest includes melee visibility/leak checks
- QA captures: knife, pipe, axe, handgun, clinic, inventory, workbench
