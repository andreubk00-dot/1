# OSTATOK 1.22-dev4 (settlement pass): faction towns

This pass continues from 1.22-dev3 Contracts / World Influence. It rebuilds the four faction
settlements as real towns with their own architecture. The version string, save schema, NPCs,
traders, contracts and economy are unchanged.

## Before

All 36 settlement sectors (4 settlements × 3×3) used one template: the same three generic
panel boxes in the same slots, one road barrier and two fences across every sector. The
`settlement_*` grounds had no dressing of their own, so blood/debris decals and random cars
leaked into the "safe" towns.

## Town structure

- **Street grid.** A main street runs through the middle of every sector and lines up with
  the gates. Lanes run along the inner sector borders. Each settlement therefore splits into
  **36 blocks**.
- **Blocks.** Built blocks put their houses on the street line: every entrance faces the
  street, and there is a pavement and curb in front. The strip behind a house row that the
  roof does not cover becomes back gardens (beds, woodpiles, crates, scrap, herbs, depending
  on the faction). Other blocks are yards, squares and working areas with their own fences.
- **Centre.** The town square sits on the central crossing, with paving and a flowerbed.
  Lamps stand on the crossing corners.
- **Faction layouts:**
  - Перрон: a railway line with boxcars and a tank wagon runs along the lane below the
    station. It has a market square with stalls and garlands, a water tower, vegetable
    plots and greenhouses.
  - Рубеж: concrete slab roads, and a parade ground with BTRs in front of the HQ. It has a
    tent camp, a motor pool, a firing position and a supply yard with an ammo bunker.
  - Механики: dark asphalt with yellow markings. It has a crane yard, scrap and pipe yards,
    a wind farm and solar fields, a tank farm, container housing and a boiler-house chimney.
  - Лазарет: light pavers, lawns with clipped hedges and white picket fences, red-cross
    ambulance pads, a triage canopy, tent wards and a fenced quarantine yard.
- **Perimeter.** Faction walls run along the outer edge only. Gates open in the middle of
  every side, plus a service gate in the south-east sector.

## New buildings: 32 authored exterior models

`tools/wa_town.py` is a new renderer for the game's "lifted roof" projection
(screen = (x, y − z)). It works with textured faces: planks, logs, brick, plaster, concrete
panels, corrugated sheet, slate, clay tiles, standing-seam tin, shingles, tar and glass.
Every tile and board gets its own colour jitter. Roofs darken toward the eaves, walls get
ground grime, and there are streaks, moss and rust. Windows are built from frames, sky
reflections, sills, carved blue window surrounds (наличники), shutters and bars.

`tools/wa_buildings.py` defines 8 models per faction on that renderer:

| Faction | Models |
|---|---|
| Перрон | barrack, log izba, brick railway station with a clock tower, market hall with awnings, canteen, barn warehouse, radio house, bathhouse |
| Рубеж | 2-storey HQ with flag, sandbags and roof mast, barracks, Quonset hangar, guardhouse with an observation cupola, garage boxes, earth-covered armory, med point, comms building |
| Механики | steel hangar with a hazard-striped gate, sawtooth-roof workshop, boiler house with a tall chimney, stacked container housing, artel office with a water tank and solar panels, garage row, fuel office, electro shop |
| Лазарет | 2-storey hospital with red-cross roof, ward pavilion, pharmacy, glass-roof lab, isolation block, staff residence with balconies, laundry, sanitary checkpoint |

Each model is split at the top of the south wall into a **roof layer** and a **facade
layer**, packed into `settlement_buildings_<faction>_v1.png`. The generator writes
`world/settlement_building_models.gd` with footprint, facade height, roof rise, door
position, atlas regions and sign board.

In game, `_create_building()` keeps everything that is gameplay: interior, walls, collision,
door, the roof fading when the player is inside, and the facade depth switch. When a building
carries a `settlement_model`, it swaps in the model's facade and roof layers. It also adds a
faction door leaf (`settlement_door_leaves_v1.png`) that still swings with the door, and puts
the sign text on the model's sign board. The "behind" fade area grows by the roof rise, so
tall roofs, masts and chimneys become transparent when the player walks behind them.

## Survival atmosphere pass

The towns were too clean for a post-collapse survival game. They now share the worn look of
the rest of the world.

- **Buildings (every model, generated):**
  - Windows: broken panes, boarded windows, plywood-covered windows, sandbagged windows
    (Рубеж), windows taped with a cross (Лазарет), and stove pipes out of windows with soot
    above them.
  - Walls: plaster fallen off down to the brick, corrugated and plywood patches, graffiti,
    scorch marks, rust and damp streaks, and mud splashed up from the ground.
  - Roofs: tarps weighed down with tyres, holes with broken rafters, rain barrels, and
    autumn leaves.
- **Ground:** `tools/wa_settlement_ground.py` generates 12 seamless materials (cracked
  asphalt with potholes, silted cobbles, rutted dirt road, broken concrete slabs, pavers,
  pavement, overgrown and dry grass, dirt yard, gravel, oil-stained concrete). They are
  world-anchored, so streets continue without seams across sectors.
- **Clutter:** potholes, manholes, cracks and litter on the streets. Leaves and weeds drift
  against kerbs and fences, and bushes grow in the yards. Pavements carry bags, barrels and
  cans.
- **New survival structures** (`settlement_props_v1.png`): shanty, tarp shelter, scrap
  barricade, tyre wall, burnt car, graves, warning sign, rubble pile, dead tree, fire pit,
  rain tank, junk pile.
  - Each faction scatters its own mix of them in its yards.
  - There is a shanty yard in Перрон and Механики, a barricade yard in Рубеж, and a
    cemetery in Лазарет.
  - Warning signs stand at the Рубеж and Лазарет gates.

## Other visual work

- `settlement_props_v1.png`: 36 yard structures (stalls, water tower, tents, BTR, cranes,
  wind turbines, decon frame, incinerator, and more). `settlement_walls_v1.png`: faction walls
  and gate posts.
- Night: fire barrels, the field kitchen, the forge, the incinerator, stall lanterns,
  searchlights and garlands use the existing practical lights.
- Settlement NPCs now draw above set pieces and building shadows. Sector names sit on the
  street corner instead of behind a facade.

## Safety rules kept

- Buildings stand fully inside their block, on its street line.
- Every piece passes a placement check: no building footprint, no door swing, no NPC circle.
- The sector cross-lanes, every gate opening and every NPC stay physically free.
- No containers, loot or persistent keys were added.

## QA

- `tests/test_settlement_layout_122.gd` (674 checks) covers lanes, gates and NPC clearance,
  placement of every planned piece, and that every settlement building has an authored model
  and sits on its street line. It also requires at least 20 buildings and 6 distinct models
  per settlement, plus each faction's signature structures.
- `tests/qa_settlement_capture.gd` renders every sector, whole-town overviews and
  gameplay-zoom close-ups (day/night):
  `xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_settlement_capture.gd -- --qa-output=<dir> [--qa-overview|--qa-closeup] [--qa-night] [--qa-only=<faction>]`
- Art is reproducible: `python3 tools/wa_buildings.py .` and `python3 tools/wa_settlement.py .`
  (or `tools/build_world_art.py`).

Target engine: Godot 4.7.2 Stable.
