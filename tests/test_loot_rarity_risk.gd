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

func _ids(table:Array) -> Dictionary:
    var out = {}
    for rec in table:
        out[str(rec.get("id",""))] = float(rec.get("chance",0.0))
    return out

func _build_and_state(game, coord:Vector2i) -> Dictionary:
    var chunk = Node2D.new()
    game.add_child(chunk)
    var profile = game._chunk_profile(coord)
    check(game._build_major_poi_chunk(chunk,coord,profile), "major POI did not build at " + str(coord))
    return {"chunk":chunk,"profile":profile}

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    # Rarity is catalogue metadata, not an instance-stat modifier.
    check(game.RARITY_INFO.size() == 5, "rarity class count changed")
    check(game.RARITY_INFO.has("common") and game.RARITY_INFO.has("scarce") and game.RARITY_INFO.has("rare") and game.RARITY_INFO.has("specialized") and game.RARITY_INFO.has("unique"), "rarity classes incomplete")
    for id in game.item_defs.keys():
        var item = game.item_defs[id]
        var rarity = str(item.get("rarity",""))
        check(game.RARITY_INFO.has(rarity), "item missing valid rarity: " + str(id))
        check(int(item.get("min_loot_risk",0)) >= 1 and int(item.get("min_loot_risk",0)) <= 5, "invalid loot risk: " + str(id))
        check(not item.has("source_hint"), "item should not expose source hint metadata: " + str(id))

    # Meaningful progression examples: no hidden damage multipliers are involved.
    check(game._item_rarity_key("bandage") == "common", "bandage should stay common")
    check(game._item_rarity_key("shotgun") == "scarce", "basic shotgun should be scarce, not endgame")
    check(game._item_rarity_key("makarov") == "rare", "Makarov rarity mismatch")
    check(game._item_rarity_key("sks") == "rare", "SKS rarity mismatch")
    check(game._item_rarity_key("akm") == "specialized", "AKM must be specialized")
    check(game._item_rarity_key("military_vest") == "specialized", "military vest must be specialized")
    check(game._item_min_loot_risk("akm") == 5, "AKM must require military-risk loot")
    check(game._item_min_loot_risk("military_vest") == 5, "military vest must require risk 5 loot")
    check(game._item_min_loot_risk("expedition_pack") == 5, "expedition pack must require risk 5 loot")
    check(game._item_min_loot_risk("trauma_kit") == 3, "trauma kit risk mismatch")
    check(game._item_rarity_label("akm").find("СПЕЦ") >= 0, "rarity label not exposed")

    # Every production loot profile must respect the minimum risk of every item it can roll.
    for profile in game.LOOT_PROFILE_RISK.keys():
        check(game.loot_tables.has(profile), "risk profile has no loot table: " + str(profile))
        var profile_risk = int(game.LOOT_PROFILE_RISK[profile])
        for rec in game.loot_tables.get(profile,[]):
            var id = str(rec.get("id",""))
            check(game.item_defs.has(id), "unknown item in loot table " + str(profile) + ": " + id)
            if game.item_defs.has(id):
                check(game._item_min_loot_risk(id) <= profile_risk, "loot risk leak: %s in %s" % [id,profile])

    var pharmacy = _ids(game.loot_tables.get("pharmacy",[]))
    var med_secure = _ids(game.loot_tables.get("medical_secure",[]))
    var police = _ids(game.loot_tables.get("police",[]))
    var police_secure = _ids(game.loot_tables.get("police_secure",[]))
    var rural = _ids(game.loot_tables.get("rural",[]))
    var forest = _ids(game.loot_tables.get("forest_cache",[]))
    var hunting = _ids(game.loot_tables.get("hunting_secure",[]))
    var military = _ids(game.loot_tables.get("military",[]))
    var military_secure = _ids(game.loot_tables.get("military_secure",[]))

    # Targeted sources: advanced items no longer leak from generic low-risk scavenging.
    check(not pharmacy.has("trauma_kit") and med_secure.has("trauma_kit"), "trauma kit not moved to medical reserve")
    check(not pharmacy.has("antibiotics") and med_secure.has("antibiotics"), "antibiotics not concentrated in medical reserve")
    check(not police.has("ballistic_helmet") and police_secure.has("ballistic_helmet"), "ballistic helmet not moved to police secure loot")
    check(not rural.has("toz34") and not forest.has("toz34") and hunting.has("toz34"), "TOZ should target hunting secure loot")
    check(not rural.has("sks") and not forest.has("sks") and hunting.has("sks"), "SKS should not leak from generic countryside")
    check(not rural.has("expedition_pack"), "expedition pack still leaks into rural loot")
    check(not military.has("military_vest") and military_secure.has("military_vest"), "military vest not gated to secure military loot")
    check(not military.has("expedition_pack") and military_secure.has("expedition_pack"), "expedition pack not gated to secure military loot")
    check(military.has("akm") and military_secure.has("akm"), "AKM lost its military source")
    check(float(military_secure.get("akm",0.0)) > float(military.get("akm",0.0)), "secure military cache should improve AKM odds")

    # Authored POIs must point to the intended secure source and police must never inherit military loot from checkpoint archetype.
    var police_a = PoiCatalog.cell("district_police",Vector2i(0,0))
    var police_b = PoiCatalog.cell("district_police",Vector2i(1,0))
    check(str(police_a.get("buildings",[])[0].get("loot","")) == "police", "police HQ inherited checkpoint military loot")
    check(str(police_b.get("buildings",[])[2].get("loot","")) == "police", "police post inherited checkpoint military loot")
    check(str(police_b.get("loose_containers",[])[0].get("loot","")) == "police_secure", "sealed police cache not secure")
    var hospital_b = PoiCatalog.cell("district_hospital",Vector2i(1,0))
    check(str(hospital_b.get("loose_containers",[])[0].get("loot","")) == "medical_secure", "hospital reserve not secure")
    var hunt_a = PoiCatalog.cell("hunting_cordon",Vector2i(0,0))
    var hunt_b = PoiCatalog.cell("hunting_cordon",Vector2i(1,0))
    check(str(hunt_a.get("buildings",[])[1].get("loot","")) == "hunting_secure", "hunting gear shed not targeted")
    check(str(hunt_b.get("loose_containers",[])[0].get("loot","")) == "hunting_secure", "ranger cache not targeted")
    var military_b = PoiCatalog.cell("military_checkpoint",Vector2i(1,0))
    check(str(military_b.get("buildings",[])[0].get("loot","")) == "military_secure", "military warehouse not secure")
    check(str(military_b.get("loose_containers",[])[0].get("loot","")) == "military_secure", "sealed military crate not secure")

    # Production builder writes the intended loot profile into fresh container state.
    var builds = [
        {"coord":Vector2i(-2,-1),"cache":"cache_3","expected":"police_secure"},
        {"coord":Vector2i(3,0),"cache":"cache_3","expected":"medical_secure"},
        {"coord":Vector2i(1,-3),"cache":"cache_3","expected":"hunting_secure"},
        {"coord":Vector2i(5,-3),"cache":"cache_3","expected":"military_secure"}
    ]
    for spec in builds:
        var built = _build_and_state(game,spec["coord"])
        var key = "%d:%d:container:%s" % [spec["coord"].x,spec["coord"].y,spec["cache"]]
        check(game.container_states.has(key), "production container missing: " + key)
        if game.container_states.has(key):
            check(str(game.container_states[key].get("loot_table","")) == spec["expected"], "production loot profile mismatch: " + key)
        built["chunk"].queue_free()

    # Known map POIs may communicate danger, but must not reveal loot routing.
    game.discovered_chunks[game._zone_chunk_key(Vector2i(4,-3))] = true
    game.discovered_pois["military_checkpoint"] = true
    var tip = game._region_map_cell_tooltip(Vector2i(4,-3))
    check(tip.find("ОПАСНОСТЬ 5/5") >= 0, "map tooltip missing POI risk")
    check(tip.find("ВОЕННЫЕ ЗАПАСЫ") < 0 and tip.find("профиль") < 0, "map tooltip reveals loot profile")

    # Permanent QA crate still contains every item, independent of rarity gating.
    var qa_entries = game._generate_loot("qa:rarity:all","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var qa_ids = {}
    for rec in qa_entries:
        qa_ids[str(rec.get("id",""))] = true
    check(qa_ids.size() == game.item_defs.size(), "QA crate no longer contains complete catalogue")
    for id in game.item_defs.keys():
        check(qa_ids.has(str(id)), "QA crate missing item after rarity stage: " + str(id))

    game.free()
    print("LOOT RARITY & RISK: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
