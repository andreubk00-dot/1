extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const BuildingCatalog = preload("res://world/building_catalog.gd")
const SaveStore = preload("res://world/save_store.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize():
    call_deferred("run")

func _rect(spec:Dictionary) -> Rect2:
    var p:Vector2 = spec.get("pos",Vector2.ZERO)
    var s:Vector2 = spec.get("size",Vector2.ZERO)
    return Rect2(p - s * 0.5,s)

func _container_keys_for_cell(anchor:Vector2i,off:Vector2i,cell:Dictionary) -> Array:
    var coord = anchor + off
    var out = []
    for b in cell.get("buildings",[]):
        var cid = str(b.get("container_id",""))
        if cid != "": out.append("%d:%d:container:%s" % [coord.x,coord.y,cid])
    for c in cell.get("loose_containers",[]):
        var cid = str(c.get("id",""))
        if cid != "": out.append("%d:%d:container:%s" % [coord.x,coord.y,cid])
    return out

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var id = "regional_clinical_complex_4"
    var anchor = Vector2i(-9,1)
    var poi = RegionCatalog.poi_by_id(id)
    check(not poi.is_empty(), "clinical complex missing from active POIS")
    check(str(poi.get("kind","")) == "medical_endgame_dungeon", "clinical kind mismatch")
    check(poi.get("coord",Vector2i.ZERO) == anchor, "clinical anchor mismatch")
    check(int(poi.get("risk",0)) == 5 and bool(poi.get("high_risk",false)), "clinical risk identity mismatch")
    check(int(poi.get("dungeon_tier",0)) == 2, "clinical dungeon tier mismatch")
    check(poi.get("hard_requirements",["bad"]).is_empty(), "clinical complex violates no-self-key")
    check(str(poi.get("spatial_identity","")) == "open_medical_campus", "clinical spatial identity mismatch")
    check(str(poi.get("loot","")) == "clinical_core", "clinical loot identity mismatch")
    check(str(poi.get("farm_profile","")) == "clinical_core" and int(poi.get("refresh_days",0)) == 12, "clinical operation-5 farming metadata mismatch")
    check(game._target_farm_profile(poi) == "clinical_core" and game._target_farm_refresh_days(poi) == 12, "clinical target farming integration mismatch")

    var compound = PoiCatalog.compound(id)
    var fp = PoiCatalog.footprint(id)
    check(fp.size() == 6, "clinical complex must span six sectors")
    check(compound.get("entry_offset",Vector2i(-99,-99)) == Vector2i(0,0), "primary entry offset mismatch")
    check(compound.get("exit_offset",Vector2i(-99,-99)) == Vector2i(2,0), "evacuation exit offset mismatch")
    check(compound.get("core_offset",Vector2i(-99,-99)) == Vector2i(2,1), "core offset mismatch")
    var flow = compound.get("encounter_flow",[])
    check(flow.size() == 6 and flow[0] == Vector2i(0,0) and flow[flow.size() - 1] == Vector2i(2,1), "encounter flow endpoints mismatch")

    # Layout QA: no POI overlaps, all authored building footprints stay in the
    # chunk and do not overlap each other, container ids remain deterministic.
    var occupied = {}
    for rec in RegionCatalog.POIS:
        var rid = str(rec.get("id",""))
        var ra:Vector2i = rec.get("coord",Vector2i.ZERO)
        for off in rec.get("footprint",[Vector2i.ZERO]):
            var key = "%d:%d" % [(ra+off).x,(ra+off).y]
            check(not occupied.has(key), "active POI overlap at " + key)
            occupied[key] = rid

    var stages = {}
    var profiles = {"clinical_perimeter":0,"clinical_interior":0,"clinical_core":0}
    var total_enemies = 0
    var all_container_keys = {}
    var entry_access = 0
    var exit_access = 0
    var core_loot_count = 0
    for off in fp:
        var cell = PoiCatalog.cell(id,off)
        check(not cell.is_empty(), "missing clinical cell " + str(off))
        check(str(cell.get("ground","")).begins_with("hospital_"), "cell lacks hospital ground language " + str(off))
        var stage = int(cell.get("flow_stage",-1))
        check(stage >= 0 and stage <= 3, "invalid flow stage " + str(off))
        stages[stage] = int(stages.get(stage,0)) + 1
        var ep = str(cell.get("enemy_profile",""))
        check(profiles.has(ep), "invalid clinical encounter profile " + ep)
        if profiles.has(ep): profiles[ep] += 1
        var count = int(cell.get("enemy_count",0))
        check(count >= 7, "clinical sector pressure too low " + str(off))
        total_enemies += count

        var rects = []
        var local_ids = {}
        for b in cell.get("buildings",[]):
            var br = _rect(b)
            check(br.position.x >= 0 and br.position.y >= 0 and br.end.x <= game.CHUNK_SIZE and br.end.y <= game.CHUNK_SIZE, "building leaves chunk bounds " + str(off))
            for prior in rects:
                check(not br.grow(-6.0).intersects(prior.grow(-6.0)), "building overlap in clinical cell " + str(off))
            rects.append(br)
            var archetype = str(b.get("archetype",""))
            check(not BuildingCatalog.by_id(archetype).is_empty(), "unknown clinical building archetype " + archetype)
            var cid = str(b.get("container_id",""))
            check(cid != "" and not local_ids.has(cid), "building container id missing/duplicate " + str(off))
            local_ids[cid] = true
            var lp = str(b.get("loot",""))
            check(game.loot_tables.has(lp), "unknown clinical building loot profile " + lp)
            check(game._loot_profile_risk(lp) <= 5, "clinical building loot exceeds risk 5")
            if lp == "clinical_core": core_loot_count += 1
        for c in cell.get("loose_containers",[]):
            var cid = str(c.get("id",""))
            check(cid != "" and not local_ids.has(cid), "loose container id collision " + str(off))
            local_ids[cid] = true
            var lp = str(c.get("loot",""))
            check(game.loot_tables.has(lp), "unknown clinical loose loot profile " + lp)
            check(game._loot_profile_risk(lp) <= 5, "clinical loose loot exceeds risk 5")
            if lp == "clinical_core": core_loot_count += 1
        for key in _container_keys_for_cell(anchor,off,cell):
            check(not all_container_keys.has(key), "duplicate persistent clinical container key " + str(key))
            all_container_keys[key] = true
        check(cell.get("fences",[]).size() >= 2, "clinical sector lacks obstacle/chokepoint fencing " + str(off))
        check(cell.get("buildings",[]).size() + cell.get("props",[]).size() + cell.get("fences",[]).size() >= 8, "clinical sector obstacle density too low " + str(off))
        for access in cell.get("access_points",[]):
            var kind = str(access.get("kind",""))
            if kind == "entry": entry_access += 1
            if kind == "exit": exit_access += 1
            var apos:Vector2 = access.get("pos",Vector2.ZERO)
            check(apos.x >= 32 and apos.x <= game.CHUNK_SIZE-32 and apos.y >= 32 and apos.y <= game.CHUNK_SIZE-32, "access marker outside safe bounds")

    check(stages.has(0) and stages.has(1) and stages.has(2) and stages.has(3), "clinical flow does not escalate through four stages")
    check(profiles["clinical_perimeter"] == 2, "clinical campus should have two recoverable perimeter sectors")
    check(profiles["clinical_interior"] == 3, "clinical campus should have three interior sectors")
    check(profiles["clinical_core"] == 1, "clinical campus must have one core sector")
    check(total_enemies >= 54, "clinical total encounter pressure too low")
    check(entry_access == 1 and exit_access == 1, "clinical entry/exit count mismatch")
    check(core_loot_count >= 3, "clinical core does not concentrate surgical rewards")

    var entry_cell = PoiCatalog.cell(id,Vector2i(0,0))
    var exit_cell = PoiCatalog.cell(id,Vector2i(2,0))
    var core_cell = PoiCatalog.cell(id,Vector2i(2,1))
    check(str(entry_cell.get("enemy_profile","")) == "clinical_perimeter", "entry must use recoverable perimeter profile")
    check(str(exit_cell.get("enemy_profile","")) == "clinical_perimeter", "exit must remain a recoverable perimeter sector")
    check(str(core_cell.get("enemy_profile","")) == "clinical_core", "deep surgical sector must use core profile")
    check(int(core_cell.get("enemy_count",0)) > int(entry_cell.get("enemy_count",0)), "encounter pressure does not escalate to core")
    for b in entry_cell.get("buildings", []):
        check(str(b.get("loot", "")) != "clinical_core", "clinical core loot leaks to entry")
    for c in entry_cell.get("loose_containers", []):
        check(str(c.get("loot", "")) != "clinical_core", "clinical core loot leaks to entry loose cache")

    # Loot identity is surgical/trauma focused and deliberately not a weapon source.
    check(game.loot_tables.has("clinical_core") and game._loot_profile_risk("clinical_core") == 5, "clinical core profile missing/risk mismatch")
    var clinical_ids = {}
    for rec in game.loot_tables.get("clinical_core", []):
        clinical_ids[str(rec.get("id", ""))] = float(rec.get("chance", 0.0))
    check(float(clinical_ids.get("trauma_kit",0.0)) > 0.80, "clinical core must strongly favor trauma care")
    check(float(clinical_ids.get("sterile_bandage",0.0)) >= 1.0, "clinical core must guarantee sterile supplies")
    for weapon in game.FIREARM_IDS:
        check(not clinical_ids.has(weapon), "clinical loot identity leaked firearm " + str(weapon))

    # Production build and encounter application for every sector.
    for off in fp:
        var coord = anchor + off
        var chunk = Node2D.new()
        chunk.position = Vector2(coord.x * game.CHUNK_SIZE,coord.y * game.CHUNK_SIZE)
        game.add_child(chunk)
        var profile = game._chunk_profile(coord)
        check(str(profile.get("poi_id","")) == id, "production chunk lost clinical POI identity " + str(coord))
        check(int(profile.get("risk",0)) == 5, "production chunk lost clinical risk 5 " + str(coord))
        game._build_procedural_chunk(chunk,coord)
        check(bool(chunk.get_meta("poi_authored",false)), "production clinical chunk not authored " + str(coord))
        check(int(chunk.get_meta("poi_flow_stage",-1)) == int(PoiCatalog.cell(id,off).get("flow_stage",-2)), "flow stage metadata mismatch " + str(coord))
        var infected = 0
        for child in chunk.get_children():
            if child.has_meta("infected_kind"): infected += 1
        check(infected == int(PoiCatalog.cell(id,off).get("enemy_count",0)), "production enemy count mismatch " + str(coord))
        chunk.queue_free()

    # Clinical encounter profiles use the existing infected families but produce
    # a distinct runner-heavy pressure curve without introducing 1.21 content early.
    var mix_chunk = Node2D.new()
    game.add_child(mix_chunk)
    game._spawn_chunk_enemies(mix_chunk,Vector2i(-7,2),40,120003,"clinical_core")
    var mix = {"normal":0,"runner":0,"brute":0}
    for n in mix_chunk.get_children():
        if n.has_meta("infected_kind"):
            var k = str(n.get_meta("infected_kind","normal"))
            mix[k] = int(mix.get(k,0)) + 1
    check(int(mix["runner"]) > int(mix["brute"]), "clinical core should emphasize mobile pressure over brute count")
    check(int(mix["runner"]) > 0 and int(mix["brute"]) > 0, "clinical core deterministic mix lacks existing threat roles")
    mix_chunk.queue_free()

    # Runtime persistence: deterministic container keys and defeated spawn keys
    # survive unload/rebuild, then round-trip through SaveStore without schema changes.
    var core_coord = anchor + Vector2i(2,1)
    var core_chunk = Node2D.new()
    core_chunk.position = Vector2(core_coord.x * game.CHUNK_SIZE,core_coord.y * game.CHUNK_SIZE)
    game.add_child(core_chunk)
    game._build_procedural_chunk(core_chunk,core_coord)
    var core_keys = _container_keys_for_cell(anchor,Vector2i(2,1),core_cell)
    check(core_keys.size() == 4, "unexpected clinical core container count")
    for key in core_keys:
        check(game.container_states.has(key), "clinical persistent container state missing " + str(key))
    var preserved_key = str(core_keys[0])
    game.container_states[preserved_key]["items"] = []
    var defeated_key = "%d:%d:%d" % [core_coord.x,core_coord.y,0]
    game.defeated[defeated_key] = true
    core_chunk.queue_free()
    await process_frame
    var rebuilt = Node2D.new()
    rebuilt.position = Vector2(core_coord.x * game.CHUNK_SIZE,core_coord.y * game.CHUNK_SIZE)
    game.add_child(rebuilt)
    game._build_procedural_chunk(rebuilt,core_coord)
    check(game.container_states.has(preserved_key) and game.container_states[preserved_key].get("items",[1]).is_empty(), "clinical looted container regenerated after chunk rebuild")
    var rebuilt_infected = 0
    for n in rebuilt.get_children():
        if n.has_meta("infected_kind"): rebuilt_infected += 1
    check(rebuilt_infected == int(core_cell.get("enemy_count",0)) - 1, "defeated clinical infected respawned after chunk rebuild")
    rebuilt.queue_free()

    var save_path = "user://clinical_complex_dev2_persistence.json"
    for suffix in ["",".bak",".tmp"]:
        if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
    var payload = {
        "inventory_entries":[],"dropped_items":[],"base_objects":[],
        "container_states":game.container_states,"weapon_mags":{},"weapon_mods":{},"weapon_condition":{},
        "equipment":{},"door_states":{},"picked_world_items":{},"defeated":game.defeated,
        "discovered_pois":{id:true}
    }
    check(SaveStore.write_save(save_path,payload), "clinical persistence SaveStore write failed")
    var loaded = SaveStore.read_save(save_path)
    check(not loaded.is_empty(), "clinical persistence SaveStore read failed")
    check(loaded.get("container_states",{}).has(preserved_key), "clinical container key lost on disk round-trip")
    check(loaded.get("defeated",{}).has(defeated_key), "clinical defeated key lost on disk round-trip")
    for suffix in ["",".bak",".tmp"]:
        if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))

    # Map remains discovery-first: danger may be shown only after discovery; no
    # core loot or flow solution is exposed by the region map.
    game.discovered_chunks[game._zone_chunk_key(anchor)] = true
    game.discovered_pois[id] = true
    var tip = game._region_map_cell_tooltip(anchor)
    check(tip.find("ОПАСНОСТЬ 5/5") >= 0, "clinical discovered map tooltip lacks risk")
    check(tip.find("clinical_core") < 0 and tip.find("ХИРУРГИЧЕСКИЙ РЕЗЕРВ") < 0 and tip.find("ЭВАКУАЦИОННЫЙ ВЫЕЗД") < 0, "clinical map reveals dungeon solution or reward")

    game.free()
    print("CLINICAL COMPLEX ENDGAME: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
