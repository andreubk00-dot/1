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

func _find_crisis_offer(day:int) -> Dictionary:
    for row in main.ContractSystem.offers_for_faction(main.faction_state,"lazaret",day):
        if str(row.get("template_id","")) == main.VerticalSlice.CRISIS_TEMPLATE_ID:
            return row
    return {}

func _floor_infected_count() -> int:
    if not is_instance_valid(main.high_risk_floor_root):
        return 0
    var count = 0
    for child in main.high_risk_floor_root.get_children():
        if bool(child.get_meta("is_enemy",false)):
            count += 1
    return count

func _transition_labels() -> Array:
    var out = []
    if not is_instance_valid(main.high_risk_floor_root):
        return out
    for node in main.high_risk_floor_root.get_children():
        if node.is_in_group("high_risk_floor_transitions"):
            out.append(str(node.get_meta("display_name","")))
    return out

func _prepare_route() -> void:
    var laz = main.RegionCatalog.poi_by_id(main.VerticalSlice.SETTLEMENT_ID).get("coord",Vector2i.ZERO)
    main._qa_move_to_world_chunk(laz)
    main.VerticalSlice.mark_doctor_met(main.faction_state,main.world_day)
    main.ContractSystem.refresh_offers(main.faction_state,main.world_day,true)
    var offer = _find_crisis_offer(main.world_day)
    if not offer.is_empty():
        main.ContractSystem.accept(main.faction_state,str(offer.get("id","")),main.world_day)
    main.world_day += 1
    main.SupplyEventSystem.daily_tick(main.faction_state,main.world_day,[])
    var event = main.SupplyEventSystem.active_event(main.faction_state,main.world_day)
    if not event.is_empty():
        main.SupplyEventSystem.resolve_success(main.faction_state,str(event.get("id","")),main.world_day)
    main._vertical_slice_refresh()
    main._vertical_slice_issue_field_reserve()

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null:
        quit(1); return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame; await process_frame
    _prepare_route()
    check(main.VerticalSlice.clinical_first_run_balance_active(main.faction_state),"runtime first-run clinic tuning not active")

    var poi_id = main.VerticalSlice.HIGH_RISK_POI_ID
    var clinic = main.RegionCatalog.poi_by_id(poi_id)
    var clinic_coord = clinic.get("coord",Vector2i.ZERO)
    var ground_pos = main._developer_poi_entry_position(clinic)
    main.player.global_position = ground_pos
    main._refresh_chunks(true)
    await process_frame; await process_frame
    var entry_chunk = main.loaded_chunks.get(clinic_coord,null)
    var entry_enemies = 0
    if is_instance_valid(entry_chunk):
        for child in entry_chunk.get_children():
            if bool(child.get_meta("is_enemy",false)):
                entry_enemies += 1
    check(entry_enemies == 5,"runtime clinical reception did not spawn tuned 5 infected")
    check(main._enter_high_risk_floor(poi_id,2,ground_pos,Vector2(999999,999999),1),"could not enter clinical floor 2")
    await process_frame
    check(_floor_infected_count() == 7,"runtime floor 2 did not spawn tuned 7 infected")
    var labels = _transition_labels()
    check(labels.has("ВЫХОД • ПРИЁМНОЕ ОТДЕЛЕНИЕ"),"floor 2 exit label does not clearly identify reception exit")
    check(labels.has("АВАРИЙНЫЙ ДОСТУП • 3 ЭТАЖ"),"floor 2 upper transition does not communicate emergency access")
    check(not main._high_risk_floor_threats_cleared(poi_id,2),"uncleared tuned floor reports clear")

    var anchor = main._high_risk_floor_anchor(poi_id)
    for i in range(7):
        main.defeated["%d:%d:%d" % [anchor.x,anchor.y,2200+i]] = true
    check(main._high_risk_floor_threats_cleared(poi_id,2),"7 defeated tuned enemies do not satisfy floor-clear gate")
    check(main._high_risk_unlock_access(poi_id,2),"tuned floor cannot unlock deep access")

    check(main._enter_high_risk_floor(poi_id,3,ground_pos,Vector2(999999,999999),2),"could not enter clinical floor 3")
    await process_frame
    check(_floor_infected_count() == 9,"runtime floor 3 did not spawn tuned 9 infected")
    labels = _transition_labels()
    check(labels.has("К ВЫХОДУ • 2 ЭТАЖ"),"floor 3 return transition is not readable as exit route")
    var reserve_key = "%d:%d:container:mf_%s_f3_floor3_surgery_store" % [anchor.x,anchor.y,poi_id]
    var reserve_state = main.container_states.get(reserve_key,{})
    var reserve_counts = {}
    for entry in reserve_state.get("items",[]):
        reserve_counts[str(entry.get("id",""))] = int(reserve_counts.get(str(entry.get("id","")),0)) + int(entry.get("qty",1))
    check(int(reserve_counts.get("sterile_bandage",0)) >= 4 and int(reserve_counts.get("painkillers",0)) >= 3,"deep surgical reserve does not guarantee one real emergency-order alternative")

    # After the slice is complete, future visits use the authored full population.
    var rec = main.VerticalSlice.record(main.faction_state)
    rec["completed"] = true
    rec["enabled"] = false
    rec["completed_day"] = main.world_day
    main.faction_state["vertical_slice"] = rec
    for i in range(10):
        main.defeated.erase("%d:%d:%d" % [anchor.x,anchor.y,2200+i])
    check(main._enter_high_risk_floor(poi_id,2,ground_pos,Vector2(999999,999999),3),"could not revisit clinical floor 2 after slice completion")
    await process_frame
    check(_floor_infected_count() == 10,"post-slice clinical floor did not restore authored 10 infected")

    main.queue_free()
    await process_frame
    print("VERTICAL SLICE CLINICAL POLISH RUNTIME 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
