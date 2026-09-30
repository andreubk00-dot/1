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

func _initialize(): call_deferred("run")

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

    var id = "underground_object_vector"
    var anchor = Vector2i(7,-7)
    var poi = RegionCatalog.poi_by_id(id)
    check(not poi.is_empty(), "Vector missing from active POIS")
    check(str(poi.get("kind","")) == "underground_endgame_dungeon", "Vector kind mismatch")
    check(poi.get("coord",Vector2i.ZERO) == anchor, "Vector anchor mismatch")
    check(int(poi.get("risk",0)) == 5 and bool(poi.get("high_risk",false)), "Vector risk identity mismatch")
    check(int(poi.get("dungeon_tier",0)) == 2, "Vector dungeon tier mismatch")
    check(poi.get("hard_requirements",["bad"]).is_empty(), "Vector violates no-self-key")
    check(str(poi.get("spatial_identity","")) == "sealed_underground_node", "Vector spatial identity mismatch")
    check(str(poi.get("loot","")) == "vector_core", "Vector loot identity mismatch")
    check(str(poi.get("farm_profile","")) == "vector_core" and int(poi.get("refresh_days",0)) == 14, "Vector operation-5 farming metadata mismatch")
    check(game._target_farm_profile(poi) == "vector_core" and game._target_farm_refresh_days(poi) == 14, "Vector target farming integration mismatch")

    var compound = PoiCatalog.compound(id)
    var fp = PoiCatalog.footprint(id)
    check(fp.size() == 6, "Vector must span six sectors")
    check(compound.get("entry_offset",Vector2i(-99,-99)) == Vector2i(0,0), "Vector entry offset mismatch")
    check(compound.get("exit_offset",Vector2i(-99,-99)) == Vector2i(0,2), "Vector service exit offset mismatch")
    check(compound.get("core_offset",Vector2i(-99,-99)) == Vector2i(1,2), "Vector core offset mismatch")
    var flow = compound.get("encounter_flow",[])
    check(flow.size() == 6 and flow[0] == Vector2i(0,0) and flow[flow.size()-1] == Vector2i(1,2), "Vector encounter flow endpoints mismatch")

    # All active POIs remain disjoint after activating the reserved footprint.
    var occupied = {}
    for rec in RegionCatalog.POIS:
        var rid = str(rec.get("id",""))
        var ra:Vector2i = rec.get("coord",Vector2i.ZERO)
        for off in rec.get("footprint",[Vector2i.ZERO]):
            var key = "%d:%d" % [(ra+off).x,(ra+off).y]
            check(not occupied.has(key), "active POI overlap at " + key)
            occupied[key] = rid

    var stages = {}
    var profiles = {"vector_access":0,"vector_tunnels":0,"vector_core":0}
    var total_enemies = 0
    var all_container_keys = {}
    var entry_access = 0
    var exit_access = 0
    var core_loot_count = 0
    for off in fp:
        var cell = PoiCatalog.cell(id,off)
        check(not cell.is_empty(), "missing Vector cell " + str(off))
        check(str(cell.get("ground","")).begins_with("vector_"), "Vector cell lacks underground ground language " + str(off))
        var stage = int(cell.get("flow_stage",-1))
        check(stage >= 0 and stage <= 3, "invalid Vector flow stage " + str(off))
        stages[stage] = int(stages.get(stage,0)) + 1
        var ep = str(cell.get("enemy_profile",""))
        check(profiles.has(ep), "invalid Vector encounter profile " + ep)
        if profiles.has(ep): profiles[ep] += 1
        var count = int(cell.get("enemy_count",0))
        check(count >= 7, "Vector sector pressure too low " + str(off))
        total_enemies += count
        check(float(cell.get("tree_mult",1.0)) == 0.0 and float(cell.get("car_mult",1.0)) == 0.0, "underground sector leaked outdoor tree/car population " + str(off))

        var rects = []
        var local_ids = {}
        for b in cell.get("buildings",[]):
            var br = _rect(b)
            check(br.position.x >= 0 and br.position.y >= 0 and br.end.x <= game.CHUNK_SIZE and br.end.y <= game.CHUNK_SIZE, "Vector building leaves chunk bounds " + str(off))
            for prior in rects:
                check(not br.grow(-6.0).intersects(prior.grow(-6.0)), "Vector building overlap in cell " + str(off))
            rects.append(br)
            var archetype = str(b.get("archetype",""))
            check(not BuildingCatalog.by_id(archetype).is_empty(), "unknown Vector building archetype " + archetype)
            var cid = str(b.get("container_id",""))
            check(cid != "" and not local_ids.has(cid), "Vector building container id missing/duplicate " + str(off))
            local_ids[cid] = true
            var lp = str(b.get("loot",""))
            check(game.loot_tables.has(lp), "unknown Vector building loot profile " + lp)
            check(game._loot_profile_risk(lp) <= 5, "Vector building loot exceeds risk 5")
            if lp == "vector_core": core_loot_count += 1
        for c in cell.get("loose_containers",[]):
            var cid = str(c.get("id",""))
            check(cid != "" and not local_ids.has(cid), "Vector loose container id collision " + str(off))
            local_ids[cid] = true
            var lp = str(c.get("loot",""))
            check(game.loot_tables.has(lp), "unknown Vector loose loot profile " + lp)
            check(game._loot_profile_risk(lp) <= 5, "Vector loose loot exceeds risk 5")
            if lp == "vector_core": core_loot_count += 1
        for key in _container_keys_for_cell(anchor,off,cell):
            check(not all_container_keys.has(key), "duplicate persistent Vector container key " + str(key))
            all_container_keys[key] = true
        check(cell.get("fences",[]).size() >= 3, "Vector sector lacks corridor/chokepoint structure " + str(off))
        check(cell.get("buildings",[]).size() + cell.get("props",[]).size() + cell.get("fences",[]).size() >= 9, "Vector sector obstacle density too low " + str(off))
        for access in cell.get("access_points",[]):
            var kind = str(access.get("kind",""))
            if kind == "entry": entry_access += 1
            if kind == "exit": exit_access += 1
            var apos:Vector2 = access.get("pos",Vector2.ZERO)
            check(apos.x >= 32 and apos.x <= game.CHUNK_SIZE-32 and apos.y >= 32 and apos.y <= game.CHUNK_SIZE-32, "Vector access marker outside safe bounds")

    check(stages.has(0) and stages.has(1) and stages.has(2) and stages.has(3), "Vector flow does not escalate through four stages")
    check(profiles["vector_access"] == 2, "Vector must have two recoverable access/exfil sectors")
    check(profiles["vector_tunnels"] == 3, "Vector must have three tunnel-pressure sectors")
    check(profiles["vector_core"] == 1, "Vector must have one deep core sector")
    check(total_enemies >= 58, "Vector total encounter pressure too low")
    check(entry_access == 1 and exit_access == 1, "Vector entry/exit count mismatch")
    check(core_loot_count >= 3, "Vector core does not concentrate engineering rewards")

    var entry_cell = PoiCatalog.cell(id,Vector2i(0,0))
    var exit_cell = PoiCatalog.cell(id,Vector2i(0,2))
    var core_cell = PoiCatalog.cell(id,Vector2i(1,2))
    check(str(entry_cell.get("enemy_profile","")) == "vector_access", "Vector entry must use recoverable access profile")
    check(str(exit_cell.get("enemy_profile","")) == "vector_access", "Vector exit must use recoverable access profile")
    check(str(core_cell.get("enemy_profile","")) == "vector_core", "Vector deep sector must use core profile")
    check(int(core_cell.get("enemy_count",0)) > int(entry_cell.get("enemy_count",0)), "Vector pressure does not escalate to core")
    for b in entry_cell.get("buildings",[]): check(str(b.get("loot","")) != "vector_core", "Vector core loot leaks to entry")
    for c in entry_cell.get("loose_containers",[]): check(str(c.get("loot","")) != "vector_core", "Vector core loot leaks to entry loose cache")

    # Technical survival identity: autonomy/repair, not another gun cache.
    check(game.loot_tables.has("vector_core") and game._loot_profile_risk("vector_core") == 5, "Vector core loot profile missing/risk mismatch")
    var vector_ids = {}
    for rec in game.loot_tables.get("vector_core",[]): vector_ids[str(rec.get("id",""))] = float(rec.get("chance",0.0))
    check(float(vector_ids.get("repair_kit",0.0)) >= 1.0, "Vector core must guarantee repair supplies")
    check(float(vector_ids.get("water_filter",0.0)) >= 0.70, "Vector core must strongly favor water autonomy")
    check(float(vector_ids.get("flashlight",0.0)) >= 0.80, "Vector core must favor utility lighting")
    check(float(vector_ids.get("expedition_pack",0.0)) > 0.0, "Vector core lacks expedition utility reward")
    for weapon in game.FIREARM_IDS: check(not vector_ids.has(weapon), "Vector technical identity leaked firearm " + str(weapon))

    # Production build and authored threat application for every underground sector.
    for off in fp:
        var coord = anchor + off
        var chunk = Node2D.new()
        chunk.position = Vector2(coord.x * game.CHUNK_SIZE,coord.y * game.CHUNK_SIZE)
        game.add_child(chunk)
        var profile = game._chunk_profile(coord)
        check(str(profile.get("poi_id","")) == id, "production chunk lost Vector POI identity " + str(coord))
        check(int(profile.get("risk",0)) == 5, "production chunk lost Vector risk 5 " + str(coord))
        game._build_procedural_chunk(chunk,coord)
        check(bool(chunk.get_meta("poi_authored",false)), "production Vector chunk not authored " + str(coord))
        check(int(chunk.get_meta("poi_flow_stage",-1)) == int(PoiCatalog.cell(id,off).get("flow_stage",-2)), "Vector flow-stage metadata mismatch " + str(coord))
        var infected = 0
        for child in chunk.get_children():
            if child.has_meta("infected_kind"):
                infected += 1
                check(["normal","runner","brute","screamer","spitter","carrier"].has(str(child.get_meta("infected_kind",""))), "Vector spawned unknown infected archetype")
        check(infected == int(PoiCatalog.cell(id,off).get("enemy_count",0)), "production Vector enemy count mismatch " + str(coord))
        chunk.queue_free()

    # Tight Vector core is brute-heavy; clinical core remains runner-heavy.
    var vector_mix_chunk = Node2D.new(); game.add_child(vector_mix_chunk)
    game._spawn_chunk_enemies(vector_mix_chunk,Vector2i(8,-5),80,120004,"vector_core")
    var vmix = {"normal":0,"runner":0,"brute":0}
    for n in vector_mix_chunk.get_children():
        if n.has_meta("infected_kind"):
            var k = str(n.get_meta("infected_kind","normal")); vmix[k] = int(vmix.get(k,0)) + 1
    check(int(vmix["brute"]) > int(vmix["runner"]), "Vector core should emphasize slow heavy corridor pressure")
    check(int(vmix["runner"]) > 0 and int(vmix["brute"]) > 0, "Vector core deterministic mix lacks existing threat roles")
    vector_mix_chunk.queue_free()
    var clinical_mix_chunk = Node2D.new(); game.add_child(clinical_mix_chunk)
    game._spawn_chunk_enemies(clinical_mix_chunk,Vector2i(-7,2),80,120003,"clinical_core")
    var cmix = {"normal":0,"runner":0,"brute":0}
    for n in clinical_mix_chunk.get_children():
        if n.has_meta("infected_kind"):
            var k = str(n.get_meta("infected_kind","normal")); cmix[k] = int(cmix.get(k,0)) + 1
    check(int(cmix["runner"]) > int(cmix["brute"]), "clinical/vector threat identities no longer differ")
    clinical_mix_chunk.queue_free()

    # Persistence uses existing container and defeated keys; no save-schema change.
    var core_coord = anchor + Vector2i(1,2)
    var core_chunk = Node2D.new(); core_chunk.position = Vector2(core_coord.x * game.CHUNK_SIZE,core_coord.y * game.CHUNK_SIZE); game.add_child(core_chunk)
    game._build_procedural_chunk(core_chunk,core_coord)
    var core_keys = _container_keys_for_cell(anchor,Vector2i(1,2),core_cell)
    check(core_keys.size() == 4, "unexpected Vector core container count")
    for key in core_keys: check(game.container_states.has(key), "Vector persistent container state missing " + str(key))
    var preserved_key = str(core_keys[0]); game.container_states[preserved_key]["items"] = []
    var defeated_key = "%d:%d:%d" % [core_coord.x,core_coord.y,0]; game.defeated[defeated_key] = true
    core_chunk.queue_free(); await process_frame
    var rebuilt = Node2D.new(); rebuilt.position = Vector2(core_coord.x * game.CHUNK_SIZE,core_coord.y * game.CHUNK_SIZE); game.add_child(rebuilt)
    game._build_procedural_chunk(rebuilt,core_coord)
    check(game.container_states.has(preserved_key) and game.container_states[preserved_key].get("items",[1]).is_empty(), "Vector looted container regenerated after rebuild")
    var rebuilt_infected = 0
    for n in rebuilt.get_children():
        if n.has_meta("infected_kind"): rebuilt_infected += 1
    check(rebuilt_infected == int(core_cell.get("enemy_count",0)) - 1, "defeated Vector infected respawned after rebuild")
    rebuilt.queue_free()

    var save_path = "user://vector_dev3_persistence.json"
    for suffix in ["",".bak",".tmp"]:
        if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
    var payload = {"inventory_entries":[],"dropped_items":[],"base_objects":[],"container_states":game.container_states,"weapon_mags":{},"weapon_mods":{},"weapon_condition":{},"equipment":{},"door_states":{},"picked_world_items":{},"defeated":game.defeated,"discovered_pois":{id:true}}
    check(SaveStore.write_save(save_path,payload), "Vector persistence SaveStore write failed")
    var loaded = SaveStore.read_save(save_path)
    check(not loaded.is_empty(), "Vector persistence SaveStore read failed")
    check(loaded.get("container_states",{}).has(preserved_key), "Vector container key lost on disk round-trip")
    check(loaded.get("defeated",{}).has(defeated_key), "Vector defeated key lost on disk round-trip")
    for suffix in ["",".bak",".tmp"]:
        if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))

    # Discovery-first: map may report discovered risk, never core reward/route solution.
    game.discovered_chunks[game._zone_chunk_key(anchor)] = true
    game.discovered_pois[id] = true
    var tip = game._region_map_cell_tooltip(anchor)
    check(tip.find("ОПАСНОСТЬ 5/5") >= 0, "Vector discovered map tooltip lacks risk")
    check(tip.find("vector_core") < 0 and tip.find("ИНЖЕНЕРНОЕ ЯДРО") < 0 and tip.find("СЕРВИСНЫЙ ТОННЕЛЬ") < 0, "Vector map reveals dungeon solution or reward")

    game.free()
    print("VECTOR ENDGAME: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
