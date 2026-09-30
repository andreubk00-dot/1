extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const BuildingCatalog = preload("res://world/building_catalog.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func run():
    var ids = {}
    var occupied = {}
    for poi in RegionCatalog.POIS:
        var id = str(poi.get("id", ""))
        check(id != "" and not ids.has(id), "POI ids must be unique: " + id)
        ids[id] = true
        var anchor: Vector2i = poi.get("coord", Vector2i(9999,9999))
        for offset in poi.get("footprint", [Vector2i.ZERO]):
            var c = anchor + offset
            var key = "%d:%d" % [c.x,c.y]
            check(not occupied.has(key), "POI footprints overlap at " + key)
            occupied[key] = id
            check(str(RegionCatalog.poi_for_chunk(c).get("id", "")) == id, "POI lookup mismatch at " + key)
    check(ids.has("district_hospital"), "district hospital missing")
    check(ids.has("district_police"), "district police missing")
    check(ids.has("hunting_cordon"), "hunting cordon missing")

    var expectations = {
        "district_hospital":{"anchor":Vector2i(2,0),"district":"market_east","loot":"pharmacy","kind":"hospital_complex"},
        "district_police":{"anchor":Vector2i(-3,-1),"district":"panel_west","loot":"police","kind":"police_station"},
        "hunting_cordon":{"anchor":Vector2i(0,-3),"district":"north_woodland","loot":"forest_cache","kind":"hunting_cordon"}
    }
    for id in expectations:
        var exp = expectations[id]
        var poi = RegionCatalog.poi_for_chunk(exp["anchor"])
        check(str(poi.get("district","")) == exp["district"], id + " district mismatch")
        check(str(poi.get("loot","")) == exp["loot"], id + " loot mismatch")
        check(str(poi.get("kind","")) == exp["kind"], id + " kind mismatch")
        check(PoiCatalog.has_compound(id), id + " compound missing")
        var footprint = PoiCatalog.footprint(id)
        check(footprint.size() == poi.get("footprint",[]).size(), id + " footprint mismatch")
        for offset in footprint:
            var cell = PoiCatalog.cell(id, offset)
            check(not cell.is_empty(), id + " has empty authored cell")
            var seen_container_ids = {}
            for spec in cell.get("buildings",[]):
                var cid = str(spec.get("container_id",""))
                check(cid != "" and not seen_container_ids.has(cid), id + " building container ids must be stable/unique per cell")
                seen_container_ids[cid] = true
                check(not BuildingCatalog.by_id(str(spec.get("archetype",""))).is_empty(), id + " references missing archetype")
            for loose in cell.get("loose_containers",[]):
                var cid = str(loose.get("id",""))
                check(cid != "" and not seen_container_ids.has(cid), id + " loose container id collides")
                seen_container_ids[cid] = true

    var game = Harness.new()
    root.add_child(game)
    check(game.loot_tables.has("police"), "police loot table missing")
    var police = game.loot_tables.get("police",[])
    var police_ids = {}
    for entry in police:
        police_ids[str(entry.get("id",""))] = float(entry.get("chance",0.0))
    check(police_ids.has("ammo_9x18") and police_ids.has("police_vest"), "police pool lacks thematic supplies")
    check(not police_ids.has("akm") and not police_ids.has("ammo_762"), "medium-risk police pool must not duplicate military AK loot")
    check(float(police_ids.get("makarov",0.0)) <= 0.10 and float(police_ids.get("shotgun",0.0)) <= 0.05, "police firearms are too common for risk 3")

    game._create_region_map_ui()
    game.current_chunk = Vector2i.ZERO
    game.discovered_chunks = {"0:0":true}
    game.discovered_pois = {}
    var snap = game._region_map_snapshot()
    check(snap["pois"].is_empty(), "new POIs leak onto unexplored map")
    game.discovered_pois["district_hospital"] = true
    game.discovered_pois["district_police"] = true
    game.discovered_pois["hunting_cordon"] = true
    snap = game._region_map_snapshot()
    var mapped = {}
    for rec in snap["pois"]:
        mapped[rec["coord"]] = true
    check(mapped.has(Vector2i(2,0)) and mapped.has(Vector2i(-3,-1)) and mapped.has(Vector2i(0,-3)), "discovered new POIs missing from field map")

    # Production generation smoke: authored compound path must build without fallback.
    for coord in [Vector2i(2,0), Vector2i(-3,-1), Vector2i(0,-3)]:
        var chunk = Node2D.new()
        game.add_child(chunk)
        var profile = game._chunk_profile(coord)
        check(game._build_major_poi_chunk(chunk, coord, profile), "major POI builder rejected " + str(coord))
        check(chunk.get_child_count() > 0, "major POI builder created empty chunk at " + str(coord))
        chunk.queue_free()
    game.free()
    print("WORLD CONTENT POI: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
