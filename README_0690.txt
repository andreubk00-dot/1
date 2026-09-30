OSTATOK 0.69.0 — REAL WEAPON HANDS PASS

Main change:
- integrated realistic free directional hand-weapon sprites from gunanimation.zip
- weapon mapping: HANDGUN -> PM, SHOTGUN -> shotgun, AK47 -> AKM
- the imported survivor character remains unedited; weapon changes happen through clean direction-aware overlays in Godot
- each firearm switches between dedicated 8-direction weapon frames instead of the previous wrong sci-fi set

Known limitation:
- the original survivor sprite still contains its baked-in generic firearm, so this pass overlays the correct weapon on top rather than redrawing the survivor sheet

QA:
- Godot 4.7.2 import: OK
- runtime selftest: OK
- QA captures checked for player, clinic, inventory and workbench
