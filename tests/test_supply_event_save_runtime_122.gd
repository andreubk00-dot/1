extends SceneTree
const Main = preload("res://main_script_mod.gd")

var failures := 0
var checks := 0

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

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.world_day = 11
    game.SupplyEventSystem.ensure_state(game.faction_state,game.world_day)
    game.faction_state["supply_events"]["next_event_day"] = 11
    var created = game.SupplyEventSystem.daily_tick(game.faction_state,11,game._supply_event_blocked_chunks())
    var event = created.get("event",{})
    check(not event.is_empty(),"active supply incident missing before save")
    var event_id = str(event.get("id",""))
    var coord = game.SupplyEventSystem.active_coord(game.faction_state,11)
    game._save_state()

    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    loaded.SupplyEventSystem.ensure_state(loaded.faction_state,loaded.world_day)
    var restored = loaded.SupplyEventSystem.active_event(loaded.faction_state,loaded.world_day)
    check(str(restored.get("id","")) == event_id,"production save/load lost active supply incident")
    check(loaded.SupplyEventSystem.active_coord(loaded.faction_state,loaded.world_day) == coord,"production save/load lost incident coordinate")
    check(int(restored.get("expires_day",0)) == int(event.get("expires_day",0)),"production save/load changed incident expiry")
    check(str(restored.get("faction","")) == str(event.get("faction","")),"production save/load changed incident faction")

    # Advance one day after load: state must age, not duplicate a second event.
    var aged = loaded.SupplyEventSystem.daily_tick(loaded.faction_state,12,loaded._supply_event_blocked_chunks())
    check(bool(aged.get("stage_changed",false)),"restored incident did not age after load")
    check(str(loaded.SupplyEventSystem.active_event(loaded.faction_state,12).get("stage","")) == "overrun","restored incident age mismatch")
    check(int(loaded.faction_state["supply_events"].get("serial",0)) == int(game.faction_state["supply_events"].get("serial",0)),"save/load duplicated incident serial")

    loaded.free()
    game.queue_free()
    await process_frame
    await process_frame
    print("SUPPLY EVENT SAVE RUNTIME 1.22-dev6: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
