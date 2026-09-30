OSTATOK 0.73.0 — BAKED FIREARM INTEGRATION PASS

Main fix:
- real firearms are no longer drawn as floating overlay sprites beside the survivor
- PM / shotgun / AKM are pre-baked into dedicated survivor animation sheets for all major clips
- the runtime modern-survivor path now loads weapon-specific baked sheets per active firearm
- separate firearm overlay sprite is disabled for the modern survivor, eliminating the floating-card look
- kept melee and the rest of the project logic intact
