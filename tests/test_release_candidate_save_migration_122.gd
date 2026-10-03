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

func run() -> void:
    _clear_live_save()
    var old_faction = Main.FactionEconomy.default_state()
    old_faction.erase("supply_events")
    old_faction.erase("faction_endgame")
    old_faction.erase("relations")
    old_faction.erase("world_influence")
    old_faction["currency_tickets"] = 321
    old_faction["factions"]["mechanics"]["reputation"] = 88
    old_faction["factions"]["mechanics"]["resources"]["technical"] = 41.5

    # Minimal valid pre-dev5/pre-dev6 style payload. Missing unrelated gameplay keys are
    # intentionally left to production defaults, exactly as an old save would be handled.
    var payload = {
        "save_version":121,
        "inventory_entries":[],"dropped_items":[],"base_objects":[],
        "container_states":{},"weapon_mags":{},"weapon_mods":{},"weapon_condition":{},
        "equipment":{},"door_states":{},"picked_world_items":{},"defeated":{},
        "world_day":47,
        "faction_state":old_faction
    }
    check(Store.write_save(Main.SAVE_PATH,payload),"legacy-style RC migration fixture failed to write")

    var game = Main.new()
    root.add_child(game)
    game.set_process(false)
    await process_frame
    await process_frame
    check(game.has_meta("loaded_save"),"production startup did not recognize legacy-style save")
    check(game.world_day == 47,"legacy world day changed during migration")
    check(int(game.faction_state.get("currency_tickets",0)) == 321,"legacy tickets changed during migration")
    check(int(game.faction_state["factions"]["mechanics"]["reputation"]) == 88,"legacy faction reputation changed during migration")
    check(abs(float(game.faction_state["factions"]["mechanics"]["resources"]["technical"]) - 41.5) < 0.001,"legacy resource value changed during migration")
    check(game.faction_state.has("relations") and game.faction_state.has("world_influence"),"dev5 relation state was not initialized")
    check(game.faction_state.has("supply_events"),"dev6 supply-event state was not initialized")
    check(game.faction_state.has("faction_endgame"),"dev8 endgame state was not initialized")
    check(game.FactionEndgame.progress(game.faction_state,"perron") == 0,"old save must not receive free endgame progress")
    var next_event = int(game.faction_state.get("supply_events",{}).get("next_event_day",0))
    check(next_event >= 50 and next_event <= 53,"old save scheduled an immediate/stale supply incident instead of 3-6 days from load day")

    game._save_state()
    await process_frame
    game.free()

    var loaded = Main.new()
    root.add_child(loaded)
    loaded.set_process(false)
    await process_frame
    await process_frame
    check(loaded.world_day == 47,"migrated save lost world day on second load")
    check(int(loaded.faction_state.get("currency_tickets",0)) == 321,"migrated save lost tickets on second load")
    check(int(loaded.faction_state["factions"]["mechanics"]["reputation"]) == 88,"migrated save lost reputation on second load")
    check(loaded.faction_state.has("supply_events") and loaded.faction_state.has("faction_endgame"),"migrated subsystem state did not persist")
    loaded._qa_clear_infected()
    await physics_frame
    loaded.free()
    _clear_live_save()
    print("RELEASE CANDIDATE SAVE MIGRATION 1.22-dev9: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
