OSTATOK 0.71.0 — WEAPON HAND POLISH PASS

Main change:
- fixed floating hand-held firearms on the imported survivor character
- ranged hand weapons now go through the same runtime hand-anchor update as melee and legacy weapons
- the firearm root is updated every frame from the engine pose anchor instead of staying in a stale position
- retuned directional sprite offsets for PM / shotgun / AKM to sit tighter in the survivor hands
- preserved the clean single-body survivor path; no legacy body/arm junk is allowed to leak back in

QA:
- Godot 4.7.2 import: OK
- runtime selftest: OK
- QA captures checked for PM / shotgun / AKM, clinic, inventory and workbench
