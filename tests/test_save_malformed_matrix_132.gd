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

func _minimal(day:int = 31) -> Dictionary:
    return {
        "save_version":122,
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
        "world_day":day,
        "faction_state":{},
        "high_risk_state":{}
    }

func _clear(path:String) -> void:
    for suffix in ["",".bak",".tmp"]:
        var p = path + suffix
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(p)
        elif DirAccess.dir_exists_absolute(p):
            DirAccess.remove_absolute(p)

func _write_raw(path:String,payload) -> void:
    var f = FileAccess.open(path,FileAccess.WRITE)
    check(f != null,"raw corrupt fixture could not open")
    if f != null:
        f.store_string(JSON.stringify(payload))
        f.close()

func _seed_backup(path:String) -> void:
    _clear(path)
    check(Store.write_save(path,_minimal(31)),"backup seed generation 1 failed")
    check(Store.write_save(path,_minimal(32)),"backup seed generation 2 failed")
    check(int(Store.read_save(path + ".bak").get("world_day",0)) == 31,"backup seed does not contain previous valid generation")

func _assert_backup_recovery(path:String,corrupt:Dictionary,label:String) -> void:
    _write_raw(path,corrupt)
    var recovered = Store.read_save(path)
    check(int(recovered.get("world_day",0)) == 31,label + " did not recover valid backup")

func _clear_live_save() -> void:
    _clear(Main.SAVE_PATH)

func run() -> void:
    var path = "user://qa_132_malformed.json"
    _seed_backup(path)

    var bad = _minimal(99)
    bad["inventory_entries"] = {}
    _assert_backup_recovery(path,bad,"inventory type corruption")

    bad = _minimal(99)
    bad["container_states"] = {"c":{"items":[null]}}
    _assert_backup_recovery(path,bad,"nested container item corruption")

    bad = _minimal(99)
    bad["weapon_instance_states"] = {"iid":{"weapon_id":"makarov","mods":[]}}
    _assert_backup_recovery(path,bad,"weapon instance mods corruption")

    bad = _minimal(99)
    bad["faction_state"] = []
    _assert_backup_recovery(path,bad,"faction top-level type corruption")

    bad = _minimal(99)
    bad["high_risk_state"] = []
    _assert_backup_recovery(path,bad,"high-risk top-level type corruption")

    bad = _minimal(99)
    bad["door_states"] = []
    _assert_backup_recovery(path,bad,"door-state type corruption")

    # Missing optional modern fields remain a valid sparse save rather than forcing backup/new-game behavior.
    var sparse_path = "user://qa_132_sparse.json"
    _clear(sparse_path)
    var sparse = {
        "save_version":122,
        "inventory_entries":[],"dropped_items":[],"base_objects":[],
        "container_states":{},"weapon_mags":{},"weapon_mods":{},"weapon_condition":{},
        "equipment":{},"door_states":{},"picked_world_items":{},"defeated":{},
        "world_day":44
    }
    check(Store.write_save(sparse_path,sparse),"sparse current save failed to write")
    var sparse_read = Store.read_save(sparse_path)
    check(int(sparse_read.get("world_day",0)) == 44,"sparse current save was rejected")
    check(not sparse_read.has("faction_state"),"Store unexpectedly invented optional faction state")

    # Nested subsystem damage is repaired by production sanitizers, not rejected by SaveStore.
    _clear_live_save()
    var nested = _minimal(57)
    nested["faction_state"] = {
        "currency_tickets":-55,
        "factions":[],
        "contract_history":{},
        "contracts":[],
        "relations":[],
        "world_influence":"bad",
        "supply_events":[],
        "faction_endgame":[],
        "world_chronicle":[],
        "named_npcs":[],
        "settlement_projects":[],
        "vertical_slice":[],
        "regional_endgame":{
            "phase":"crisis_season",
            "started_day":0,
            "ends_day":999,
            "history":[{"day":-5,"event":"bad"},{"day":2,"event":"started"}]
        }
    }
    nested["high_risk_state"] = {
        "quarantine_center_12":[],
        "reserve_arsenal_bastion":{"access_cycle":-50,"access_day":-4,"strategic_spawned":true},
        "regional_clinical_complex_4":"bad",
        "underground_object_vector":42
    }
    check(Store.write_save(Main.SAVE_PATH,nested),"nested-corruption production fixture failed to write")
    var game = Main.new()
    root.add_child(game)
    game.set_process(false)
    await process_frame
    await process_frame
    check(game.has_meta("loaded_save"),"nested-corruption fixture was not loaded")
    check(game.world_day == 57,"nested sanitizer changed world day")
    check(int(game.faction_state.get("currency_tickets",-1)) == 0,"negative tickets were not sanitized")
    check(game.faction_state.get("factions",{}).size() == 4,"malformed faction map did not recover four factions")
    check(game.faction_state.get("contract_history",[]).is_empty(),"malformed contract history was not reset")
    check(game.faction_state.has("supply_events"),"malformed supply state was not recovered")
    check(game.faction_state.has("faction_endgame"),"malformed faction endgame was not recovered")
    check(game.faction_state.has("world_chronicle"),"malformed chronicle was not recovered")
    check(game.faction_state.has("named_npcs"),"malformed named-NPC state was not recovered")
    check(game.faction_state.has("settlement_projects"),"malformed project state was not recovered")
    check(game.faction_state.has("vertical_slice"),"malformed vertical-slice state was not recovered")
    var regional = game.faction_state.get("regional_endgame",{})
    check(str(regional.get("phase","")) == "dormant","invalid active regional endgame was not reset to dormant")
    check(int(regional.get("started_day",-1)) == 0 and int(regional.get("ends_day",-1)) == 0,"invalid regional endgame retained impossible dates")
    var high = game.high_risk_state
    check(high.size() == 4,"high-risk sanitizer did not restore four site records")
    check(int(high.get("reserve_arsenal_bastion",{}).get("access_cycle",999)) == -1,"high-risk negative access cycle was not clamped")
    check(int(high.get("reserve_arsenal_bastion",{}).get("access_day",999)) == 0,"high-risk negative access day was not clamped")
    check(bool(high.get("reserve_arsenal_bastion",{}).get("strategic_spawned",false)),"valid high-risk strategic-spawned flag was lost")

    game._save_state()
    await process_frame
    var rewritten = Store.read_save(Main.SAVE_PATH)
    check(int(rewritten.get("save_version",0)) == 122,"sanitized production save did not remain schema 122")
    check(typeof(rewritten.get("faction_state",null)) == TYPE_DICTIONARY,"sanitized faction state was not persisted as dictionary")
    check(typeof(rewritten.get("high_risk_state",null)) == TYPE_DICTIONARY,"sanitized high-risk state was not persisted as dictionary")
    game._qa_clear_infected()
    await physics_frame
    game.free()
    await process_frame

    _clear(path)
    _clear(sparse_path)
    _clear_live_save()
    print("SAVE MALFORMED MATRIX 1.32: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
