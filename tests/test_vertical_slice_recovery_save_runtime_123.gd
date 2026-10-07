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
    check(qa_root != "","save recovery test requires isolated OSTATOK_QA_SAVE_ROOT")
    if qa_root == "": quit(1); return
    var main = Main.new()
    root.add_child(main)
    await process_frame; await process_frame
    var laz_coord = main.RegionCatalog.poi_by_id(main.VerticalSlice.SETTLEMENT_ID).get("coord",Vector2i(-8,-2))
    main._qa_move_to_world_chunk(laz_coord)
    main.VerticalSlice.mark_doctor_met(main.faction_state,main.world_day)
    var rec = main.faction_state["vertical_slice"]
    rec["supply_seen"] = true
    rec["supply_resolved"] = true
    rec["supply_outcome"] = "recovered"
    main.faction_state["vertical_slice"] = rec
    var marked = main.VerticalSlice.mark_clinical_incapacitation(main.faction_state,main.world_day,3,{})
    check(not marked.is_empty(),"could not create recovery state before save")
    check(main.VerticalSlice.mark_clinical_recovery_aid_issued(main.faction_state,main.world_day),"could not mark recovery aid before save")
    main._save_state()
    var raw = Main.SaveStore.read_save(Main.SAVE_PATH)
    check(not raw.is_empty(),"production recovery save cannot be read")
    var raw_rec = raw.get("faction_state",{}).get("vertical_slice",{})
    check(int(raw_rec.get("clinical_incapacitations",0)) == 1,"production save lost clinical failure count")
    check(bool(raw_rec.get("recovery_pending",false)),"production save lost regroup flag")
    check(bool(raw_rec.get("recovery_aid_issued",false)),"production save lost one-time aid flag")
    check(int(raw_rec.get("last_incapacitation_floor",0)) == 3,"production save lost failed floor")
    main.queue_free(); await process_frame

    var loaded = Main.new()
    root.add_child(loaded)
    await process_frame; await process_frame
    check(loaded.has_meta("loaded_save"),"production load did not recognize recovery save")
    var loaded_rec = loaded.VerticalSlice.record(loaded.faction_state)
    check(int(loaded_rec.get("clinical_incapacitations",0)) == 1,"production load lost clinical failure count")
    check(bool(loaded_rec.get("recovery_pending",false)),"production load lost regroup flag")
    check(bool(loaded_rec.get("recovery_aid_issued",false)),"production load lost one-time aid flag")
    check(not loaded.VerticalSlice.clinical_recovery_aid_ready(loaded.faction_state),"production reload makes one-time aid claimable again")
    loaded.queue_free(); await process_frame

    # Same schema 122 migration from dev8: no new recovery flags are invented.
    raw["faction_state"]["vertical_slice"].erase("clinical_incapacitations")
    raw["faction_state"]["vertical_slice"].erase("last_incapacitation_day")
    raw["faction_state"]["vertical_slice"].erase("last_incapacitation_floor")
    raw["faction_state"]["vertical_slice"].erase("recovery_pending")
    raw["faction_state"]["vertical_slice"].erase("recovery_aid_issued")
    raw["faction_state"]["vertical_slice"].erase("recovery_aid_day")
    check(Main.SaveStore.write_save(Main.SAVE_PATH,raw),"could not write dev8-style recovery migration fixture")
    var legacy = Main.new()
    root.add_child(legacy)
    await process_frame; await process_frame
    loaded_rec = legacy.VerticalSlice.record(legacy.faction_state)
    check(int(loaded_rec.get("clinical_incapacitations",-1)) == 0,"dev8 migration invented failed clinic runs")
    check(not bool(loaded_rec.get("recovery_pending",true)),"dev8 migration invented regroup state")
    check(not bool(loaded_rec.get("recovery_aid_issued",true)),"dev8 migration invented consumed aid")
    legacy.queue_free(); await process_frame

    print("VERTICAL SLICE RECOVERY SAVE 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
