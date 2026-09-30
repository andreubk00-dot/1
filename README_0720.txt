OSTATOK 0.72.0 — WEAPON GRIP FIX PASS

Main change:
- reworked firearm anchoring for the imported survivor
- the weapon root now sits on the runtime hand anchor instead of inheriting a legacy grip offset from the 144x48 weapon sheet
- each 8-way firearm sprite now has an explicit grip pixel so the chosen hand point lands on the actual hand anchor
- added directional root bias tuning for PM / shotgun / AKM to keep the gun seated tighter against the baked survivor pose
- kept the modern survivor path clean: no old body/arm junk re-enabled
