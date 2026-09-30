OSTATOK 0.80.0 — ATMOSPHERE WEATHER PASS

NEXT STAGE OF THE ART-INTEGRATION PLAN
- exterior atmosphere: night readability, practical street lighting, wet asphalt/rain response, fog depth and authored street storytelling clusters.

LIGHTING
- street lamps now switch on through the dusk/night cycle instead of glowing uniformly all day;
- stronger warm pools at night, weather boost during rain/cloud, deterministic broken-lamp flicker on a subset;
- exterior shop/pharmacy practical lights are also night-aware.

WEATHER
- rain now has splash pulses in addition to falling streaks;
- cloudy/rain states add subtle moving fog bands, stronger at night;
- wet_surface_v1 reacts smoothly to cloudy/rain states and remains below actors/loot.

WORLD STORYTELLING
- added visual-only evacuation/abandonment cluster to the showcase street;
- procedural commercial/industrial/military/residential/rural zones receive restrained themed clusters;
- no collision/nav/save footprint changes.

PIPELINE
- tools/atmosphere_art.py generates wet_surface_v1; build_art.py includes atmosphere art.

QA
- Godot 4.7.2 import/selftest; exterior day/night/rain/night-rain; clinic/player/infected/inventory/workbench regression.
