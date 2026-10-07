extends SceneTree
var checks := 0
var failures := 0
var main
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _total_minutes(day:int,minutes:float) -> float:
    return float(day - 1) * 1440.0 + minutes

func _find_crisis_offer(day:int) -> Dictionary:
    for row in main.ContractSystem.offers_for_faction(main.faction_state,"lazaret",day):
        if str(row.get("template_id","")) == main.VerticalSlice.CRISIS_TEMPLATE_ID:
            return row
    return {}

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null:
        quit(1); return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame; await process_frame
    check(main.VerticalSlice.active(main.faction_state),"fresh main scene did not start vertical slice")

    var laz_coord = main.RegionCatalog.poi_by_id(main.VerticalSlice.SETTLEMENT_ID).get("coord",Vector2i.ZERO)
    var clinic_coord = main.RegionCatalog.poi_by_id(main.VerticalSlice.HIGH_RISK_POI_ID).get("coord",Vector2i.ZERO)
    main._qa_move_to_world_chunk(laz_coord)
    main.VerticalSlice.mark_doctor_met(main.faction_state,main.world_day)
    main.ContractSystem.refresh_offers(main.faction_state,main.world_day,true)
    var offer = _find_crisis_offer(main.world_day)
    check(not offer.is_empty(),"recovery fixture lacks emergency medicine order")
    var accepted = main.ContractSystem.accept(main.faction_state,str(offer.get("id","")),main.world_day)
    check(bool(accepted.get("ok",false)),"recovery fixture could not accept emergency order")

    main.world_day += 1
    var tick = main.SupplyEventSystem.daily_tick(main.faction_state,main.world_day,[])
    check(bool(tick.get("created",false)),"recovery fixture did not create first supply incident")
    var event = main.SupplyEventSystem.active_event(main.faction_state,main.world_day)
    var supply = main.SupplyEventSystem.resolve_success(main.faction_state,str(event.get("id","")),main.world_day)
    check(bool(supply.get("ok",false)),"recovery fixture could not resolve first supply incident")
    main._vertical_slice_refresh()
    main._vertical_slice_issue_field_reserve()
    check(bool(main.VerticalSlice.record(main.faction_state).get("supply_resolved",false)),"runtime fixture did not freeze first supply outcome")

    main._qa_move_to_world_chunk(clinic_coord)
    await process_frame
    check(main._vertical_slice_in_clinical_complex(),"surface clinical POI is not recognized as rescue context")
    var ammo_before = main._inventory_count("ammo_9x18")
    var bandage_before = main._inventory_count("bandage")
    var water_before = main._inventory_count("water")
    var time_before = _total_minutes(main.world_day,main.world_minutes)
    main.health = 0.0
    main._respawn_player()
    await process_frame
    var rec = main.VerticalSlice.record(main.faction_state)
    check(main.current_chunk == laz_coord,"clinical incapacitation did not evacuate player to Lazaret")
    check(int(rec.get("clinical_incapacitations",0)) == 1,"first runtime clinical incapacitation not recorded")
    check(bool(rec.get("recovery_pending",false)),"first runtime clinical incapacitation lacks regroup state")
    check(bool(rec.get("recovery_aid_issued",false)),"first runtime clinical incapacitation did not issue recovery aid")
    check(main._inventory_count("ammo_9x18") == ammo_before + 8,"recovery aid ammo amount mismatch")
    check(main._inventory_count("bandage") == bandage_before + 1,"recovery aid bandage amount mismatch")
    check(main._inventory_count("water") == water_before + 1,"recovery aid water amount mismatch")
    check(abs(_total_minutes(main.world_day,main.world_minutes) - time_before - 360.0) < 1.5,"clinical evacuation did not cost exactly six game hours")
    check(abs(main.health - 78.0) < 0.01 and abs(main.fatigue - 42.0) < 0.01,"clinical evacuation incorrectly restores perfect condition")
    check(abs(float(main.body_condition.get("torso",0.0)) - 82.0) < 0.01,"clinical evacuation body recovery mismatch")
    var obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "ПЕРЕПРОВЕРИТЬ СНАРЯЖЕНИЕ","runtime HUD does not surface regroup step after evacuation")
    var marker = main.VerticalSlice.marker_target(main.faction_state,main.world_day,true,true,main._vertical_slice_inventory_counts())
    check(str(marker.get("poi_id","")) == main.VerticalSlice.HIGH_RISK_POI_ID and str(marker.get("label","")) .find("ПОВТОР") >= 0,"runtime retry marker does not point to clinic")

    # Leaving Lazaret explicitly starts the retry and clears only the temporary regroup flag.
    main._qa_move_to_world_chunk(clinic_coord)
    await process_frame
    obj = main._hud_survival_objective()
    rec = main.VerticalSlice.record(main.faction_state)
    check(not bool(rec.get("recovery_pending",true)),"runtime retry did not clear regroup flag after leaving Lazaret")
    check(str(obj.get("title","")) == "ДОБЫТЬ МЕДИЦИНСКИЙ РЕЗЕРВ","runtime retry did not return to cargo objective")

    # A second failure from a real upper High Risk floor is rescued but cannot farm aid.
    main._qa_move_to_high_risk(main.VerticalSlice.HIGH_RISK_POI_ID,2,false)
    await process_frame
    check(main._high_risk_floor_active() and main.high_risk_floor_poi_id == main.VerticalSlice.HIGH_RISK_POI_ID,"runtime could not enter clinical floor 2")
    ammo_before = main._inventory_count("ammo_9x18")
    bandage_before = main._inventory_count("bandage")
    water_before = main._inventory_count("water")
    time_before = _total_minutes(main.world_day,main.world_minutes)
    main.health = 0.0
    main._respawn_player()
    await process_frame
    rec = main.VerticalSlice.record(main.faction_state)
    check(main.current_chunk == laz_coord and not main._high_risk_floor_active(),"floor-2 incapacitation did not leave interior and evacuate to Lazaret")
    check(int(rec.get("clinical_incapacitations",0)) == 2 and int(rec.get("last_incapacitation_floor",0)) == 2,"second floor incapacitation history mismatch")
    check(main._inventory_count("ammo_9x18") == ammo_before and main._inventory_count("bandage") == bandage_before and main._inventory_count("water") == water_before,"second failure duplicated one-time recovery aid")
    check(abs(_total_minutes(main.world_day,main.world_minutes) - time_before - 360.0) < 1.5,"second clinical evacuation did not cost six hours")
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "ПЕРЕПРОВЕРИТЬ СНАРЯЖЕНИЕ" and str(obj.get("sub","")) .find("больше не пополняется") >= 0,"second-failure HUD does not explain no-repeat aid")

    # Secured cargo survives incapacitation. Rescue returns to Lazaret and asks for turn-in,
    # not another clinic retry or the nonsensical 'return to Lazaret' while already there.
    main._qa_move_to_world_chunk(clinic_coord)
    main._grid_add(main.inventory_entries,"sterile_bandage",4,main.INV_W,main.INV_H)
    main._grid_add(main.inventory_entries,"painkillers",3,main.INV_W,main.INV_H)
    var sterile_before = main._inventory_count("sterile_bandage")
    var pain_before = main._inventory_count("painkillers")
    main.health = 0.0
    main._respawn_player()
    await process_frame
    rec = main.VerticalSlice.record(main.faction_state)
    check(bool(rec.get("clinical_cargo_secured",false)),"death with complete medical order forgot cargo milestone")
    check(not bool(rec.get("recovery_pending",true)),"death with complete medical order incorrectly requests retry")
    check(main._inventory_count("sterile_bandage") == sterile_before and main._inventory_count("painkillers") == pain_before,"clinical rescue destroyed secured contract cargo")
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "СДАТЬ АВАРИЙНЫЙ ЗАКАЗ","rescued player with cargo is told to return to Lazaret instead of turn in order")

    # Outside the clinical complex, legacy respawn behavior is untouched.
    var failures_before = int(rec.get("clinical_incapacitations",0))
    var day_before = main.world_day
    var minute_before = main.world_minutes
    main._qa_move_to_world_chunk(Vector2i(0,0))
    main.health = 0.0
    main._respawn_player()
    await process_frame
    rec = main.VerticalSlice.record(main.faction_state)
    check(int(rec.get("clinical_incapacitations",0)) == failures_before,"non-clinical death polluted slice failure history")
    check(main.world_day == day_before and abs(main.world_minutes - minute_before) < 1.5,"non-clinical legacy respawn unexpectedly gained six-hour penalty")
    check(main.current_chunk == Vector2i(0,0),"non-clinical legacy respawn no longer returns to generic start chunk")

    main.queue_free()
    await process_frame
    print("VERTICAL SLICE RECOVERY RUNTIME 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
