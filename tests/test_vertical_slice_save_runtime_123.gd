extends SceneTree
const Main = preload("res://main_script_mod.gd")
var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void:
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2); return
    call_deferred("run")

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame; await process_frame
    check(game.VerticalSlice.active(game.faction_state),"fresh runtime slice not active before save")
    game.VerticalSlice.mark_settlement_visited(game.faction_state)
    game.VerticalSlice.mark_doctor_met(game.faction_state,game.world_day)
    var event_state = game.faction_state.get("supply_events",{})
    event_state["history"] = [{"id":"qa_dev8_supply","faction":"lazaret","created_day":game.world_day,"closed_day":game.world_day,"outcome":"recovered","stage":"distress","cargo_resource":"medicine"}]
    event_state["active"] = {}
    game.faction_state["supply_events"] = event_state
    game.VerticalSlice.refresh_progress(game.faction_state,game.world_day,true,false,{})
    check(game.VerticalSlice.mark_field_reserve_issued(game.faction_state,game.world_day),"save fixture could not persist issued field reserve")
    game.discovered_pois[game.VerticalSlice.HIGH_RISK_POI_ID] = true
    game._grid_add(game.inventory_entries,"sterile_bandage",4,game.INV_W,game.INV_H)
    game._grid_add(game.inventory_entries,"painkillers",3,game.INV_W,game.INV_H)
    var before = game.VerticalSlice.refresh_progress(game.faction_state,game.world_day,true,true,game._vertical_slice_inventory_counts())
    check(bool(before.get("met_doctor",false)) and bool(before.get("clinical_cargo_secured",false)),"slice save fixture milestones not prepared")
    var saved_day = game.world_day
    game._save_state()
    var raw = game.SaveStore.read_save(game.SAVE_PATH)
    check(not raw.is_empty(),"production SaveStore could not read dev7 save")
    check(int(raw.get("save_version",0)) == 122,"vertical slice changed save schema instead of extending schema 122")
    var raw_slice = raw.get("faction_state",{}).get("vertical_slice",{})
    check(typeof(raw_slice) == TYPE_DICTIONARY,"vertical slice missing from production faction save")
    check(bool(raw_slice.get("met_doctor",false)),"production save lost named NPC milestone")
    check(bool(raw_slice.get("clinical_cargo_secured",false)),"production save lost High Risk cargo milestone")
    check(bool(raw_slice.get("field_reserve_issued",false)),"production save lost one-time field reserve milestone")
    game.queue_free(); await process_frame; await process_frame

    var loaded = Main.new()
    loaded._load_data(); loaded._load_state()
    var rec = loaded.VerticalSlice.record(loaded.faction_state)
    check(bool(rec.get("enabled",false)),"production load disabled unfinished vertical slice")
    check(bool(rec.get("visited_settlement",false)),"production load lost settlement milestone")
    check(bool(rec.get("met_doctor",false)),"production load lost Doctor Mironova milestone")
    check(bool(rec.get("clinical_discovered",false)) and bool(rec.get("clinical_cargo_secured",false)),"production load lost clinical sortie progress")
    check(bool(rec.get("field_reserve_issued",false)) and int(rec.get("field_reserve_day",0)) == saved_day,"production load lost field-reserve idempotence state")
    check(loaded.discovered_pois.has(loaded.VerticalSlice.HIGH_RISK_POI_ID),"production load lost clinical POI discovery")
    check(abs(float(loaded.faction_state["factions"]["lazaret"]["resources"]["medicine"]) - 26.0) < 0.01,"load unexpectedly reset/changed seeded shortage")

    # A legacy faction block gains only a disabled compatibility record; setup_new_game
    # is intentionally called only by _ready when no save was loaded.
    var legacy = loaded.FactionEconomy.default_state()
    legacy.erase("vertical_slice")
    legacy["factions"]["lazaret"]["resources"]["medicine"] = 64.0
    var migrated = loaded.FactionEconomy.sanitize_state(legacy)
    check(not loaded.VerticalSlice.active(migrated),"dev6 migration unexpectedly enables onboarding")
    check(abs(float(migrated["factions"]["lazaret"]["resources"]["medicine"]) - 64.0) < 0.01,"dev6 migration changed live settlement economy")
    loaded.free()
    await process_frame

    # Full _ready migration check: rewrite the valid dev7 save as a dev6-style save
    # (same schema 122, no vertical_slice key) and launch main normally. _load_state
    # must set loaded_save before fresh-game setup is considered.
    var legacy_raw = raw.duplicate(true)
    legacy_raw["faction_state"].erase("vertical_slice")
    legacy_raw["faction_state"]["factions"]["lazaret"]["resources"]["medicine"] = 64.0
    check(Main.SaveStore.write_save(Main.SAVE_PATH,legacy_raw),"could not write dev6-style schema 122 migration fixture")
    var legacy_main = Main.new()
    root.add_child(legacy_main)
    await process_frame; await process_frame
    check(legacy_main.has_meta("loaded_save"),"full _ready did not recognize existing save")
    check(not legacy_main.VerticalSlice.active(legacy_main.faction_state),"full _ready wrongly activated fresh slice on old save")
    check(abs(float(legacy_main.faction_state["factions"]["lazaret"]["resources"]["medicine"]) - 64.0) < 0.01,"full _ready rewrote old save Lazaret economy")
    legacy_main.queue_free()
    await process_frame
    print("VERTICAL SLICE SAVE RUNTIME 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
