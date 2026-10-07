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

func _complete_project(game,faction_id:String,day:int) -> void:
    game.SettlementProjects.ensure_state(game.faction_state)
    var spec = game.SettlementProjects.project(faction_id)
    var rec = game.SettlementProjects.default_record()
    rec["strategic_installed"] = true
    rec["installed_day"] = max(1,day - 3)
    rec["resources"] = spec.get("resource_targets",{}).duplicate(true)
    var total := 0.0
    for resource_id in game.SettlementProjects.RESOURCE_KEYS:
        total += float(rec["resources"].get(resource_id,0.0))
    rec["total_committed"] = total
    rec["completed"] = true
    rec["completed_day"] = day
    game.faction_state["settlement_projects"]["records"][faction_id] = rec

func _finalize_chain(game,faction_id:String,day:int) -> void:
    game.FactionEndgame.ensure_state(game.faction_state)
    var spec = game.FactionEndgame.chain(faction_id)
    var templates = spec.get("templates",[]).duplicate(true)
    game.faction_state["faction_endgame"]["chains"][faction_id] = {
        "progress":templates.size(),
        "completed":templates,
        "finalized":true,
        "final_day":day
    }
    game.faction_state["faction_endgame"]["effects"][str(spec.get("effect",""))] = true
    game.faction_state["faction_endgame"]["history"].append({"day":day,"faction":faction_id,"event":"qa_finalized"})

func _complete_regional_endgame(game) -> void:
    var hardship = {}
    var minima = {}
    var faction_rows = {}
    for raw_faction_id in game.FactionCatalog.ids():
        var faction_id = str(raw_faction_id)
        hardship[faction_id] = 2
        minima[faction_id] = {"food":62.0,"medicine":61.0,"technical":60.0,"security":63.0}
        faction_rows[faction_id] = {
            "category":"secure",
            "final_worst":70.0,
            "min_seen":60.0,
            "hardship_days":2,
            "supply_recovered":1,
            "supply_lost":0
        }
    game.faction_state["regional_endgame"] = {
        "phase":"season_complete",
        "started_day":70,
        "ends_day":91,
        "last_tick_day":91,
        "completion_day":91,
        "pressure_applied_day":91,
        "checkpoints":[7,14],
        "hardship_days":hardship,
        "resource_minima":minima,
        "outcome":{"id":"cohesive","resolved_day":91,"factions":faction_rows},
        "history":[{"day":70,"event":"started"},{"day":91,"event":"completed"}]
    }

func _assert_loaded(game,label:String) -> void:
    check(str(game.faction_state.get("world_routes",{}).get("route_mechanics_depot",{}).get("state","")) == "open",label + " lost opened route")
    check(game.SettlementProjects.is_completed(game.faction_state,"mechanics"),label + " lost completed settlement project")
    check(int(game.SettlementProjects.record(game.faction_state,"mechanics").get("completed_day",0)) == 40,label + " changed project completion day")
    check(game.FactionEndgame.is_finalized(game.faction_state,"mechanics"),label + " lost finalized faction endgame")
    check(game.FactionEndgame.faction_effect_active(game.faction_state,"mechanics"),label + " lost permanent faction effect")
    check(game.WorldChronicle.story_seen(game.faction_state,"qa_132_composite_story"),label + " lost chronicle story_seen")
    check(game.FactionNpcState.status(game.faction_state,"mechanics_electrician",game.world_day) == "wounded",label + " lost named NPC status")
    check(game.RegionalEndgame.is_complete(game.faction_state),label + " lost completed regional endgame")
    check(str(game.faction_state.get("regional_endgame",{}).get("outcome",{}).get("id","")) == "cohesive",label + " lost frozen regional outcome")
    check(game.HighRiskMechanics.access_unlocked(game.high_risk_state,"underground_object_vector",2),label + " lost High Risk deep access")
    check(game.HighRiskMechanics.strategic_spawned(game.high_risk_state,"underground_object_vector"),label + " lost High Risk strategic-spawn flag")
    check(game.discovered_chunks.has("4:5"),label + " lost discovered chunk")
    check(game.discovered_pois.has("reserve_arsenal_bastion"),label + " lost discovered POI")

func run() -> void:
    _clear_live_save()
    var game = Main.new()
    root.add_child(game)
    game.set_process(false)
    await process_frame
    await process_frame

    game.world_day = 96
    game.faction_state = game.FactionEconomy.default_state()
    game.faction_state["currency_tickets"] = 123
    game.faction_state["world_routes"]["route_mechanics_depot"] = {
        "id":"route_mechanics_depot","state":"open","opened_day":18,"source_contract":"mechanics_rail_depot"
    }
    game.faction_state["factions"]["mechanics"]["reputation"] = 104
    _complete_project(game,"mechanics",40)
    _finalize_chain(game,"mechanics",55)
    game.WorldChronicle.append_story(game.faction_state,64,540,"qa_132_composite_story","СЛЕД","Проверка совместного schema-122 roundtrip.")
    var npc_change = game.FactionNpcState.set_status(game.faction_state,"mechanics_electrician","wounded",65,"qa save matrix")
    check(bool(npc_change.get("ok",false)),"fixture failed to set named NPC status")
    _complete_regional_endgame(game)

    game.high_risk_state = game.HighRiskMechanics.default_state()
    check(game.HighRiskMechanics.unlock_access(game.high_risk_state,"underground_object_vector",2,80),"fixture failed High Risk access unlock")
    check(game.HighRiskMechanics.mark_strategic_spawned(game.high_risk_state,"underground_object_vector"),"fixture failed High Risk strategic-spawn mark")
    game.discovered_chunks = {"0:0":true,"4:5":true}
    game.discovered_pois = {"reserve_arsenal_bastion":true}

    game._save_state()
    await process_frame
    var raw = Store.read_save(Main.SAVE_PATH)
    check(int(raw.get("save_version",0)) == 122,"composite production save changed schema")
    check(typeof(raw.get("faction_state",null)) == TYPE_DICTIONARY,"composite save lost faction_state dictionary")
    check(typeof(raw.get("high_risk_state",null)) == TYPE_DICTIONARY,"composite save lost high_risk_state dictionary")
    check(not raw.has("audio_state"),"transient audio state leaked into production save")
    check(not raw.has("idle_variant"),"transient animation state leaked into production save")

    game._qa_clear_infected()
    await physics_frame
    game.free()
    await process_frame

    var loaded = Main.new()
    root.add_child(loaded)
    loaded.set_process(false)
    await process_frame
    await process_frame
    check(loaded.has_meta("loaded_save"),"composite save was not loaded")
    check(loaded.world_day == 96,"first load changed world day")
    check(int(loaded.faction_state.get("currency_tickets",0)) == 123,"first load changed faction currency")
    _assert_loaded(loaded,"first load")

    loaded._save_state()
    await process_frame
    loaded._qa_clear_infected()
    await physics_frame
    loaded.free()
    await process_frame

    var again = Main.new()
    root.add_child(again)
    again.set_process(false)
    await process_frame
    await process_frame
    check(again.has_meta("loaded_save"),"second composite load was not recognized")
    check(again.world_day == 96,"second load changed world day")
    check(int(again.faction_state.get("currency_tickets",0)) == 123,"second load changed faction currency")
    _assert_loaded(again,"second load")
    check(again.faction_state.get("faction_endgame",{}).get("history",[]).size() == 1,"second load duplicated faction-endgame history")
    check(again.faction_state.get("world_chronicle",{}).get("story_seen",[]).count("qa_132_composite_story") == 1,"second load duplicated chronicle story id")

    again._qa_clear_infected()
    await physics_frame
    again.free()
    await process_frame
    _clear_live_save()
    print("SAVE CURRENT SCHEMA MATRIX 1.32: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
