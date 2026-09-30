OSTATOK 0.81.0 — SURVIVAL SYSTEMS FOUNDATION

This pass turns the existing survival bars into a more interconnected physiological model.

Added:
- persistent long-term fatigue (0..100), separate from short-term stamina
- fatigue accumulation from movement, sprinting, cold/heat stress, wetness, pain, wounds, infection and bleeding
- safe stationary shelter/thermal comfort/dryness recover fatigue slowly; proper rest recovers it strongly
- fatigue reduces stamina cap, stamina regeneration, movement speed and can prevent sprinting at extreme exhaustion
- a combined survival strain model now raises stamina cost when multiple bad conditions stack
- infection increases thirst demand
- hunger reduces activity-generated heat and worsens cold exposure
- dehydration worsens heat accumulation
- warm exertion creates sweat/moisture, which can become a cold liability later
- high fatigue/infection now slow passive health recovery
- HUD gains a compact fatigue vital without replacing existing injury/wetness information
- rest UI shows fatigue and sleep actively reduces it
- fatigue is persistent in saves with backward-compatible defaults

Regression scope:
- no changes to player/infected art, weapon sheets, world geometry, loot placement, collision or chunk topology
