extends SceneTree
const Main = preload("res://main_script_mod.gd")
const Store = preload("res://world/save_store.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")

func _clear_live_save() -> void:
    for suffix in ["",".bak",".tmp"]:
        var path = Main.SAVE_PATH + suffix
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
        elif DirAccess.dir_exists_absolute(path):
            DirAccess.remove_absolute(path)

func _payload(version:int) -> Dictionary:
    return {
        "save_version":version,
        "inventory_entries":[],
        "dropped_items":[],
        "base_objects":[],
        "container_states":{},
        "weapon_mags":{},
        "weapon_mods":{},
        "weapon_condition":{},
        "equipment":{},
        "door_states":{},
        "picked_world_items":{},
        "defeated":{},
        "world_day":17,
        "discovered_chunks":{},
        "discovered_pois":{},
        "faction_state":{}
    }

func _base_at(coord:Vector2i,id_value:int = 1) -> Dictionary:
    return {
        "id":id_value,
        "kind":"cot",
        "x":float(coord.x * Main.CHUNK_SIZE) + Main.CHUNK_SIZE * 0.5,
        "y":float(coord.y * Main.CHUNK_SIZE) + Main.CHUNK_SIZE * 0.5,
        "rot":0.0
    }

func _load_fixture(payload:Dictionary):
    _clear_live_save()
    check(Store.write_save(Main.SAVE_PATH,payload),"fixture v%s failed to write" % str(payload.get("save_version","?")))
    var game = Main.new()
    root.add_child(game)
    game.set_process(false)
    await process_frame
    await process_frame
    check(game.has_meta("loaded_save"),"fixture v%s was not recognized as a save" % str(payload.get("save_version","?")))
    return game

func _dispose(game) -> void:
    if is_instance_valid(game):
        game._qa_clear_infected()
        await physics_frame
        game.free()
        await process_frame
    _clear_live_save()

func run() -> void:
    # 0.82 boundary: only pre-82 discovered chunks preserve the old zone identity.
    var old_coord = Vector2i(5,-4)
    var old_key = "%d:%d" % [old_coord.x,old_coord.y]
    var p81 = _payload(81)
    p81["discovered_chunks"] = {old_key:true}
    var g = await _load_fixture(p81)
    check(g.legacy_chunk_zones.has(old_key),"v81 discovered chunk did not preserve legacy zone")
    check(str(g.legacy_chunk_zones.get(old_key,"")) == str(g._legacy_chunk_zone(old_coord)),"v81 preserved wrong legacy zone")
    await _dispose(g)

    var p82 = _payload(82)
    p82["discovered_chunks"] = {old_key:true}
    g = await _load_fixture(p82)
    check(not g.legacy_chunk_zones.has(old_key),"v82 incorrectly re-applied pre-82 legacy zone migration")
    await _dispose(g)

    # 0.84 boundary: pre-84 player bases preserve their procedural building footprint.
    var ordinary = Vector2i(6,-6)
    check(Main.RegionCatalog.poi_for_chunk(ordinary).is_empty(),"QA ordinary migration chunk unexpectedly became authored POI")
    var ordinary_key = "%d:%d" % [ordinary.x,ordinary.y]
    var p83 = _payload(83)
    p83["base_objects"] = [_base_at(ordinary,83)]
    g = await _load_fixture(p83)
    check(g.legacy_building_layout_chunks.has(ordinary_key),"v83 base chunk did not preserve old building layout")
    await _dispose(g)

    var p84 = _payload(84)
    p84["base_objects"] = [_base_at(ordinary,84)]
    g = await _load_fixture(p84)
    check(not g.legacy_building_layout_chunks.has(ordinary_key),"v84 ordinary base incorrectly re-applied pre-84 migration")
    await _dispose(g)

    # 0.85 boundary: a 0.84 base inside a new authored compound preserves only that chunk.
    var compound = Vector2i(-2,1) # GSK Sever anchor.
    check(not Main.RegionCatalog.poi_for_chunk(compound).is_empty(),"QA compound migration chunk lost authored POI")
    var compound_poi = Main.RegionCatalog.poi_for_chunk(compound)
    check(Main.PoiCatalog.has_compound(str(compound_poi.get("id",""))),"QA migration POI is not an authored compound")
    var compound_key = "%d:%d" % [compound.x,compound.y]
    p84 = _payload(84)
    p84["base_objects"] = [_base_at(compound,184)]
    g = await _load_fixture(p84)
    check(g.legacy_building_layout_chunks.has(compound_key),"v84 authored-POI base did not preserve pre-85 geometry")
    await _dispose(g)

    var p85 = _payload(85)
    p85["base_objects"] = [_base_at(compound,185)]
    g = await _load_fixture(p85)
    check(not g.legacy_building_layout_chunks.has(compound_key),"v85 incorrectly re-applied authored-POI migration")
    await _dispose(g)

    # Weapon-instance migration: a pre-99 legacy shared firearm state must survive as one concrete instance.
    var p98 = _payload(98)
    p98["inventory_entries"] = [{"id":"makarov","qty":1,"x":0,"y":0,"instance_id":"qa_makarov_98"}]
    p98["current_weapon_id"] = "makarov"
    p98["current_weapon_instance_id"] = "qa_makarov_98"
    p98["weapon_mags"] = {"makarov":5}
    p98["weapon_condition"] = {"makarov":42.0}
    p98["weapon_mods"] = {"makarov":{"magazine":"","muzzle":""}}
    g = await _load_fixture(p98)
    check(g.weapon_instance_states.has("qa_makarov_98"),"v98 legacy firearm did not receive instance state")
    var migrated = g.weapon_instance_states.get("qa_makarov_98",{})
    check(int(migrated.get("mag",-1)) == 5,"v98 legacy magazine rounds changed during instance migration")
    check(abs(float(migrated.get("condition",-1.0)) - 42.0) < 0.01,"v98 legacy weapon condition changed during instance migration")
    await _dispose(g)

    # Version 99 with an empty instance-state map is still deliberately migrated conservatively.
    var p99 = _payload(99)
    p99["inventory_entries"] = [{"id":"makarov","qty":1,"x":0,"y":0,"instance_id":"qa_makarov_99"}]
    p99["current_weapon_id"] = "makarov"
    p99["current_weapon_instance_id"] = "qa_makarov_99"
    p99["weapon_mags"] = {"makarov":4}
    p99["weapon_condition"] = {"makarov":67.0}
    p99["weapon_mods"] = {"makarov":{"magazine":"","muzzle":""}}
    p99["weapon_instance_states"] = {}
    g = await _load_fixture(p99)
    check(g.weapon_instance_states.has("qa_makarov_99"),"v99 empty instance-state map was not recovered")
    migrated = g.weapon_instance_states.get("qa_makarov_99",{})
    check(int(migrated.get("mag",-1)) == 4,"v99 empty-state recovery lost legacy magazine rounds")
    check(abs(float(migrated.get("condition",-1.0)) - 67.0) < 0.01,"v99 empty-state recovery lost weapon condition")
    await _dispose(g)

    # A current-schema save missing modern nested faction state must get defaults, never free progress.
    var p122 = _payload(122)
    g = await _load_fixture(p122)
    check(g.faction_state.has("supply_events"),"v122 missing supply-events state was not defaulted")
    check(g.faction_state.has("faction_endgame"),"v122 missing faction-endgame state was not defaulted")
    check(g.faction_state.has("regional_endgame"),"v122 missing regional-endgame state was not defaulted")
    check(g.faction_state.has("world_chronicle"),"v122 missing chronicle state was not defaulted")
    check(g.FactionEndgame.progress(g.faction_state,"perron") == 0,"v122 sparse save received free faction-endgame progress")
    check(str(g.faction_state.get("regional_endgame",{}).get("state","dormant")) == "dormant","v122 sparse save received active regional endgame")
    g._save_state()
    await process_frame
    var rewritten = Store.read_save(Main.SAVE_PATH)
    check(int(rewritten.get("save_version",0)) == 122,"production rewrite changed save schema away from 122")
    check(rewritten.get("inventory_entries",[]).is_empty(),"production rewrite granted items to sparse saved pack")
    await _dispose(g)

    print("SAVE MIGRATION BOUNDARIES 1.32: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
