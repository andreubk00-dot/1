extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func _rect_for_building(spec:Dictionary) -> Rect2:
    var p:Vector2 = spec.get("pos",Vector2.ZERO)
    var s:Vector2 = spec.get("size",Vector2.ZERO)
    return Rect2(p - s * 0.5,s)

func _prime_target_site(game, poi:Dictionary, empty:bool):
    var profile = game._target_farm_profile(poi)
    for key in game._target_farm_expected_container_keys(poi):
        game.container_states[key] = {
            "name":"QA target cache",
            "loot_table":profile,
            "grid_w":game.CONTAINER_W,
            "grid_h":game.CONTAINER_H,
            "generated_day":game.world_day,
            "refresh_cycle":0,
            "poi_id":str(poi.get("id","")),
            "target_farm":true,
            "items":[] if empty else game._generate_loot(str(key),profile,game.CONTAINER_W,game.CONTAINER_H)
        }

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var farm_specs = {
        "district_hospital":{"profile":"medical_secure","days":5},
        "district_police":{"profile":"police_secure","days":6},
        "hunting_cordon":{"profile":"hunting_secure","days":6},
        "factory_7":{"profile":"industrial_secure","days":7},
        "military_checkpoint":{"profile":"military_secure","days":8},
        "quarantine_center_12":{"profile":"quarantine_core","days":10},
        "reserve_arsenal_bastion":{"profile":"arsenal_core","days":12},
        "regional_clinical_complex_4":{"profile":"clinical_core","days":12},
        "underground_object_vector":{"profile":"vector_core","days":14}
    }

    # Target farming must be explicit and limited to authored, specialized POIs.
    for poi_id in farm_specs.keys():
        var expected = farm_specs[poi_id]
        var poi = RegionCatalog.poi_by_id(poi_id)
        check(not poi.is_empty(), poi_id + " missing from RegionCatalog")
        check(game._target_farm_profile(poi) == expected["profile"], poi_id + " farm profile mismatch")
        check(game._target_farm_refresh_days(poi) == expected["days"], poi_id + " cooldown mismatch")
        var keys = game._target_farm_expected_container_keys(poi)
        check(not keys.is_empty(), poi_id + " has no target caches")
        var unique = {}
        for key in keys:
            check(not unique.has(key), poi_id + " duplicate target cache key " + str(key))
            unique[key] = true
            var parts = str(key).split(":")
            check(parts.size() >= 4 and parts[2] == "container", poi_id + " malformed target cache key " + str(key))
        check(unique.size() == keys.size(), poi_id + " target cache keys are not unique")

    for ordinary_id in ["central_clinic","garage_coop_sever","rail_depot","dacha_coop_zarya"]:
        var ordinary = RegionCatalog.poi_by_id(ordinary_id)
        check(game._target_farm_profile(ordinary) == "", ordinary_id + " accidentally became renewable target farm")
        check(game._target_farm_refresh_days(ordinary) == 0, ordinary_id + " ordinary POI has a cooldown")

    # Core dungeon farming must only refresh the deepest core pool, never intermediate caches.
    for pair in [["quarantine_center_12","quarantine_core"],["reserve_arsenal_bastion","arsenal_core"],["regional_clinical_complex_4","clinical_core"],["underground_object_vector","vector_core"]]:
        var poi_id = str(pair[0])
        var profile = str(pair[1])
        var poi = RegionCatalog.poi_by_id(poi_id)
        var expected_keys = game._target_farm_expected_container_keys(poi)
        var expected_lookup = {}
        for key in expected_keys:
            expected_lookup[str(key)] = true
        var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
        for off in PoiCatalog.footprint(poi_id):
            var cell = PoiCatalog.cell(poi_id,off)
            var coord = anchor + off
            for b in cell.get("buildings",[]):
                var cid = str(b.get("container_id",""))
                if cid == "":
                    continue
                var key = "%d:%d:container:%s" % [coord.x,coord.y,cid]
                check(expected_lookup.has(key) == (str(b.get("loot","")) == profile), poi_id + " building cache selection leaked outside core")
            for loose in cell.get("loose_containers",[]):
                var cid = str(loose.get("id",""))
                if cid == "":
                    continue
                var key = "%d:%d:container:%s" % [coord.x,coord.y,cid]
                check(expected_lookup.has(key) == (str(loose.get("loot","")) == profile), poi_id + " loose cache selection leaked outside core")

    # Site-level cooldown: partial looting must not start it, full clear must.
    var police = RegionCatalog.poi_by_id("district_police")
    var police_anchor:Vector2i = police.get("coord",Vector2i.ZERO)
    var police_fp = PoiCatalog.footprint("district_police")
    if police_fp.size() > 1:
        var other_coord:Vector2i = police_anchor + police_fp[1]
        var fake_loaded = Node2D.new()
        game.add_child(fake_loaded)
        game.loaded_chunks[other_coord] = fake_loaded
        check(game._target_farm_other_site_chunk_loaded(police,police_anchor),"target farm does not detect an already loaded neighbouring POI sector")
        game.loaded_chunks.erase(other_coord)
        fake_loaded.queue_free()
        check(not game._target_farm_other_site_chunk_loaded(police,police_anchor),"target farm cold-entry guard stays active after neighbouring sector unload")
    game.container_states = {}
    game.loot_refresh_sites = {}
    game.world_day = 20
    _prime_target_site(game,police,true)
    var police_keys = game._target_farm_expected_container_keys(police)
    check(not police_keys.is_empty(), "police target caches missing for runtime test")
    if not police_keys.is_empty():
        game.container_states[police_keys[0]]["items"] = [{"id":"bandage","qty":1,"x":0,"y":0}]
        game._target_farm_schedule_if_cleared("district_police")
        check(int(game._target_farm_site_state("district_police").get("ready_day",0)) == 0, "partial clear incorrectly started police cooldown")
        game.container_states[police_keys[0]]["items"] = []
        game._target_farm_note_container_change(police_keys[0],false)
        var scheduled = game._target_farm_site_state("district_police")
        check(int(scheduled.get("cleared_day",0)) == 20, "full clear did not record clear day")
        check(int(scheduled.get("ready_day",0)) == 26, "police target cooldown must be six days")
        game.world_day = 25
        check(not game._prepare_target_farm_site(police), "target site refreshed before cooldown")

        # Player storage safety: adding any item cancels pending refill and may never be overwritten.
        game.container_states[police_keys[0]]["items"] = [{"id":"water","qty":1,"x":0,"y":0}]
        game._target_farm_note_container_change(police_keys[0],true)
        check(int(game._target_farm_site_state("district_police").get("ready_day",0)) == 0, "deposit did not cancel target refresh")
        game.world_day = 40
        check(not game._prepare_target_farm_site(police), "player storage was overwritten by target refresh")
        check(str(game.container_states[police_keys[0]].get("items",[])[0].get("id","")) == "water", "player storage item changed")

        # Clear again, reach deadline and refresh. Local defeated records reset; unrelated kills remain.
        for key in police_keys:
            game.container_states[key]["items"] = []
        game._target_farm_schedule_if_cleared("district_police")
        var ready = int(game._target_farm_site_state("district_police").get("ready_day",0))
        check(ready == 46, "second police cooldown scheduled at wrong day")
        game.defeated = {
            "%d:%d:qa_enemy" % [police_anchor.x,police_anchor.y]:true,
            "99:99:qa_enemy":true
        }
        game.world_day = ready
        check(game._prepare_target_farm_site(police), "target site did not refresh at deadline")
        var refreshed = game._target_farm_site_state("district_police")
        check(int(refreshed.get("cycle",0)) == 1, "refresh cycle did not advance")
        check(int(refreshed.get("last_refresh_day",0)) == ready, "refresh day not recorded")
        check(int(refreshed.get("ready_day",-1)) == 0, "refresh timer not cleared after refill")
        var refreshed_nonempty = false
        for key in police_keys:
            var state = game.container_states[key]
            check(int(state.get("refresh_cycle",0)) == 1, "target cache cycle metadata not updated")
            check(int(state.get("generated_day",0)) == ready, "target cache generated day not updated")
            if not state.get("items",[]).is_empty():
                refreshed_nonempty = true
        check(refreshed_nonempty, "police refresh produced no useful target loot at all")
        check(not game.defeated.has("%d:%d:qa_enemy" % [police_anchor.x,police_anchor.y]), "POI defeated threat was not reset")
        check(game.defeated.has("99:99:qa_enemy"), "target refresh erased unrelated defeated state")

    # Refresh remains a world rule, not an explicit farming guide. Map copy must not
    # reveal target loot or exact cooldown; players learn return timing by experience.
    for poi_id in farm_specs.keys():
        var poi = RegionCatalog.poi_by_id(poi_id)
        var poi_coord:Vector2i = poi.get("coord",Vector2i.ZERO)
        game.discovered_chunks[game._zone_chunk_key(poi_coord)] = true
        game.discovered_pois[poi_id] = true
        var tip = game._region_map_cell_tooltip(poi_coord)
        check(tip.find("Целевая добыча") < 0, poi_id + " map tooltip reveals target-farm purpose")
        check(tip.find("восстанов") < 0 and tip.find("резерв готов") < 0, poi_id + " map tooltip reveals refresh state")

    # Layout safety: authored objects must not intersect each other. Authored compounds
    # intentionally replace the baked public road visually rather than moving old save geometry.
    for raw_poi_id in PoiCatalog.COMPOUNDS.keys():
        var poi_id = str(raw_poi_id)
        for off in PoiCatalog.footprint(poi_id):
            var cell = PoiCatalog.cell(poi_id,off)
            var rects = []
            for b in cell.get("buildings",[]):
                var rect = _rect_for_building(b)
                check(rect.size.x > 0.0 and rect.size.y > 0.0, poi_id + " invalid building size at " + str(off))
                check(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= game.CHUNK_SIZE and rect.end.y <= game.CHUNK_SIZE, poi_id + " building exceeds chunk bounds: " + str(b.get("id","")))
                rects.append({"id":str(b.get("id","")),"rect":rect})
            for i in range(rects.size()):
                for j in range(i + 1,rects.size()):
                    check(not rects[i]["rect"].intersects(rects[j]["rect"]), poi_id + " buildings overlap: " + rects[i]["id"] + " / " + rects[j]["id"])
            for prop in cell.get("props",[]):
                var p:Vector2 = prop.get("pos",Vector2.ZERO)
                for rec in rects:
                    check(not rec["rect"].grow(8.0).has_point(p), poi_id + " prop " + str(prop.get("kind","")) + " overlaps building " + rec["id"])
            for loose in cell.get("loose_containers",[]):
                var p:Vector2 = loose.get("pos",Vector2.ZERO)
                for rec in rects:
                    check(not rec["rect"].grow(4.0).has_point(p), poi_id + " loose cache " + str(loose.get("id","")) + " overlaps building " + rec["id"])

            var poi = RegionCatalog.poi_by_id(poi_id)
            var coord:Vector2i = poi.get("coord",Vector2i.ZERO) + off
            var chunk = Node2D.new()
            game.add_child(chunk)
            var profile = game._chunk_profile(coord)
            check(game._build_major_poi_chunk(chunk,coord,profile), poi_id + " production authored build failed at " + str(coord))
            check(bool(chunk.get_meta("poi_masks_public_road",false)), poi_id + " does not mask baked public road under compound at " + str(coord))
            check(bool(chunk.get_meta("poi_surface_opaque",false)), poi_id + " leaves public road graphics visible through authored surface at " + str(coord))
            chunk.queue_free()

    # Procedural buildings retain strict road/sidewalk separation.
    var sample_sizes = [Vector2(84,68),Vector2(160,110),Vector2(246,184)]
    var raw_centers = [Vector2(120,120),Vector2(650,120),Vector2(120,650),Vector2(650,650)]
    for raw_center in raw_centers:
        for raw_size in sample_sizes:
            var size = game._fit_procedural_building_size(raw_size)
            var center = game._fit_procedural_building_center(raw_center,size)
            var rect = Rect2(center - size*0.5,size)
            var crosses_vertical = rect.position.x < game.BUILDING_ROAD_MAX and rect.end.x > game.BUILDING_ROAD_MIN
            var crosses_horizontal = rect.position.y < game.BUILDING_ROAD_MAX and rect.end.y > game.BUILDING_ROAD_MIN
            check(not crosses_vertical and not crosses_horizontal, "procedural building fit crosses public road: " + str(rect))

    # Production parking smoke for representative dense compounds. Random world cars
    # must respect buildings and one another after all authored dressing is present.
    for coord in [Vector2i(2,0),Vector2i(3,3),Vector2i(4,5),Vector2i(-9,1),Vector2i(-7,2),Vector2i(7,-7),Vector2i(8,-5)]:
        var chunk = Node2D.new()
        chunk.position = Vector2(coord.x * game.CHUNK_SIZE,coord.y * game.CHUNK_SIZE)
        game.add_child(chunk)
        game._build_procedural_chunk(chunk,coord)
        var cars = []
        var buildings = []
        for child in chunk.get_children():
            if bool(child.get_meta("world_car",false)):
                cars.append(child)
            if child.has_meta("world_building"):
                buildings.append(child)
        for i in range(cars.size()):
            var car_rect = Rect2(cars[i].position - Vector2(40,24),Vector2(80,48))
            for j in range(i + 1,cars.size()):
                var other_rect = Rect2(cars[j].position - Vector2(40,24),Vector2(80,48))
                check(not car_rect.intersects(other_rect), "production cars overlap at " + str(coord))
            for building in buildings:
                var bsize = building.get_meta("building_size",Vector2.ZERO)
                var brect = Rect2(building.position - bsize*0.5,bsize).grow(10.0)
                check(not car_rect.intersects(brect), "production car overlaps building at " + str(coord))
        chunk.queue_free()

    game.free()
    print("TARGET FARMING / WORLD LAYOUT: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
