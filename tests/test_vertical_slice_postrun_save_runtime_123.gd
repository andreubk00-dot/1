extends SceneTree
const Main = preload("res://main_script_mod.gd")
var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func run() -> void:
    var qa_root = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    check(qa_root != "","post-run save test requires isolated OSTATOK_QA_SAVE_ROOT")
    if qa_root == "": quit(1); return
    var game = Main.new()
    root.add_child(game)
    await process_frame; await process_frame
    var rec = game.VerticalSlice.default_state()
    rec["initialized"] = true
    rec["visited_settlement"] = true
    rec["met_doctor"] = true
    rec["supply_resolved"] = true
    rec["supply_outcome"] = "recovered"
    rec["clinical_discovered"] = true
    rec["clinical_cargo_secured"] = true
    rec["crisis_contract_completed"] = true
    rec["shortage_resolved"] = true
    rec["completed"] = true
    rec["completed_day"] = game.world_day
    rec["enabled"] = false
    game.faction_state["vertical_slice"] = rec
    game.faction_state["factions"]["lazaret"]["resources"]["medicine"] = 60.0
    check(game.VerticalSlice.mark_completion_feedback_issued(game.faction_state,game.world_day),"could not mark post-run feedback before save")
    check(game.VerticalSlice.mark_doctor_debrief_seen(game.faction_state,game.world_day),"could not mark debrief before save")
    game._save_state()
    var raw = Main.SaveStore.read_save(Main.SAVE_PATH)
    check(not raw.is_empty(),"production post-run save cannot be read")
    check(int(raw.get("save_version",0)) == 122,"post-run persistence changed save schema")
    var raw_rec = raw.get("faction_state",{}).get("vertical_slice",{})
    check(bool(raw_rec.get("completion_feedback_issued",false)),"production save lost post-run feedback idempotence")
    check(bool(raw_rec.get("doctor_debrief_seen",false)),"production save lost Mironova debrief idempotence")
    game.queue_free(); await process_frame

    var loaded = Main.new()
    loaded._load_data(); loaded._load_state()
    var loaded_rec = loaded.VerticalSlice.record(loaded.faction_state)
    check(bool(loaded_rec.get("completed",false)),"production load lost completed slice")
    check(bool(loaded_rec.get("completion_feedback_issued",false)),"production load makes post-run radio replayable")
    check(bool(loaded_rec.get("doctor_debrief_seen",false)),"production load makes Mironova trust reward replayable")
    check(not loaded.VerticalSlice.completion_feedback_ready(loaded.faction_state),"loaded completed save can replay post-run feedback")
    check(not loaded.VerticalSlice.doctor_debrief_ready(loaded.faction_state),"loaded completed save can replay debrief reward")
    loaded.free(); await process_frame

    # Same-schema dev10 migration: completion survives, new idempotence fields default
    # to false, and settlement resources stay byte-for-byte semantically unchanged.
    var legacy_state = raw.get("faction_state",{}).duplicate(true)
    legacy_state["vertical_slice"].erase("completion_feedback_issued")
    legacy_state["vertical_slice"].erase("completion_feedback_day")
    legacy_state["vertical_slice"].erase("doctor_debrief_seen")
    legacy_state["vertical_slice"].erase("doctor_debrief_day")
    var medicine_before = float(legacy_state["factions"]["lazaret"]["resources"]["medicine"])
    var migrated = Main.FactionEconomy.sanitize_state(legacy_state)
    var migrated_rec = Main.VerticalSlice.record(migrated)
    check(bool(migrated_rec.get("completed",false)),"dev10 migration lost completed slice")
    check(not bool(migrated_rec.get("completion_feedback_issued",true)),"dev10 migration invented post-run feedback history")
    check(not bool(migrated_rec.get("doctor_debrief_seen",true)),"dev10 migration invented Mironova debrief history")
    check(abs(float(migrated["factions"]["lazaret"]["resources"]["medicine"]) - medicine_before) < 0.001,"dev11 migration changed Lazaret economy")

    print("VERTICAL SLICE POST-RUN SAVE 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
