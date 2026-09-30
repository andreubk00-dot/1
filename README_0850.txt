OSTATOK 0.85.0 — REGION IDENTITY & MAJOR POIs

This pass turns the reserved region markers from 0.82 into authored, multi-chunk
places with stable physical identities.

Major authored compounds:
- GSK «Sever»: 2x2 chunk garage cooperative, repair yard, guard post, old bays.
- Promkombinat #7: 2x2 chunk factory with main shop, warehouses, ABK/checkpoint,
  power yard and repair areas.
- Rail Depot: 3 linked rail-corridor chunks with locomotive repair hall,
  administration/platform and freight warehouse yard.
- SNT «Zarya»: 2x2 dacha cooperative with unequal houses, sheds, gardens and plots.
- Military checkpoint «Vostok»: 2x2 chunk entry complex with checkpoint, stores,
  barracks yard, communications and motor pool.

Architecture foundation:
- new world/poi_catalog.gd keeps compound footprint + cell roles + authored buildings,
  props, loot containers and danger/environment multipliers in data instead of hardcoding
  each POI directly into the chunk generator;
- RegionCatalog POIs now have footprints and return cell_offset for every occupied chunk;
- main chunk generator detects authored POI cells and builds those instead of four generic
  procedural boxes;
- first cache_0..cache_3 ids are kept per chunk where possible so old container state is
  not discarded merely because a POI became authored;
- 0.84 saves with an existing player-built base inside a new compound preserve that
  chunk's previous building layout.

Gameplay/world identity:
- compounds use different building dimensions and roles per cell;
- unique concrete/service/platform/garden/parade-ground markings make linked chunks read
  as one facility;
- loot remains tied to the correct region identity (industrial / garage / rural / military);
- local enemy/tree/car multipliers reinforce the intended character of each POI.

QA target build: Godot 4.7.2.
