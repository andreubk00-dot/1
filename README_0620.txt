OSTATOK 0.62.0 — CHARACTER REPLACEMENT PASS

Main change:
- integrated the external ready-made survivor set FREE Character 16-bit Thug Outlined by SmallScaleInt as the new primary firearm player visual
- old custom firearm body atlases are no longer the default for guns; the ready-made 8-direction sprite now renders in gameplay
- aim-driven movement clips now switch between Idle / Walk / Run / RunBackwards / StrafeLeft / StrafeRight and firearm attack variants based on relative move direction vs aim
- preserved the existing melee fallback: knife / pipe / axe still use the older baked melee presentation until a matching melee-ready replacement set is chosen
- imported the full sheet set into the project root for future extension (Attack1-4, Idle1-3, Walk, Run, strafes, crouch, die, damage, taunt)
- hidden legacy layered body parts and firearm overlay while the new ready-made survivor is active, to avoid silhouette conflicts

Implementation notes:
- row mapping for the 8-way sheet was calibrated in-engine for right / left / up / down and diagonal continuity
- weapon gameplay logic, inventory, HUD, crafting and save logic were left intact
- this pass is intentionally a character-visual replacement pass, not a full combat animation rewrite

QA:
- Godot 4.7.2 asset import completed
- normal runtime selftest: OK
- QA captures checked for player stage, clinic, inventory and workbench

Known limitation of this pass:
- because the free pack is a firearm survivor, melee still falls back to the previous art path; a future pass can replace melee with a matching purchased/custom pack
