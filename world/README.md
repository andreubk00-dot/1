# OSTATOK world foundation

The world layer is now split into three data catalogs:

- `region_catalog.gd` — **where** districts and named POIs exist in the macro region,
  including multi-chunk POI footprints and risk/loot identity.
- `building_catalog.gd` — **what kind of building** exists there: room/facade/roof/yard
  profile, size envelope and future gameplay hooks.
- `poi_catalog.gd` — **how a major place is composed physically** across several chunk
  cells: local role, authored buildings, yards, props, containers and danger/ecology
  multipliers.

0.85 keeps chunk coordinates and existing persistence keys but replaces the old
"reserved POI marker" approach with authored compounds for GSK Sever, Factory #7,
the Rail Depot, SNT Zarya and the Vostok military checkpoint.  Each complex spans
multiple connected chunks and each cell has a different purpose instead of repeating
four equal procedural boxes.

Save compatibility remains a hard rule.  A chunk containing an older player-built
base may keep the previous layout, while new/unmodified POI chunks use the authored
compound. `cache_0..cache_3` ids remain stable where possible.

Current development order:

World Foundation → Building & Location Variety → Existing Locations Polish →
Region Identity & Major POIs → Region Map & Expedition Foundation.

## 0.97 Shelter Defense & Breach
Ground-floor residential/clinic/military/rural windows can now be real persistent breach
points. Building south-wall collision is segmented around the authored door/window
openings; doors/windows keep integrity in `shelter_breach_states`, while player-built
barricades continue to use `base_objects`. Infected retain the existing memory/sound
state machine and only locally steer toward a visible weak point when a remembered
route is physically blocked.
