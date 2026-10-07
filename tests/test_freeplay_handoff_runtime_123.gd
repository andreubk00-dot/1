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

func _completed_slice_state() -> Dictionary:
    var rec = main.VerticalSlice.default_state()
    rec["initialized"] = true
    rec["completed"] = true
    rec["enabled"] = false
    rec["completed_day"] = 2
    rec["completion_feedback_issued"] = true
    rec["doctor_debrief_seen"] = true
    rec["doctor_debrief_day"] = 2
    return rec

func _find_offer(template_id:String) -> Dictionary:
    for row in main.ContractSystem.offers_for_faction(main.faction_state,"lazaret",main.world_day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null: quit(1); return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame; await process_frame

    main.faction_state = main.FactionEconomy.default_state()
    main.faction_state["vertical_slice"] = _completed_slice_state()
    main.world_day = 2
    main.expedition_journal = main.ExpeditionJournal.empty_state()
    main.expedition_active = false
    main.home_navigation_active = false
    main.discovered_pois.clear()

    var obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "ЗАКРЕПИТЬ ДОМ","completed slice without home has no useful sandbox handoff")
    check(str(obj.get("sub","")) .find("исследовать") >= 0,"home handoff wrongly implies exploration is blocked")

    main.region_map_selected_chunk = main.current_chunk + Vector2i(1,0)
    main._refresh_region_map_ui()
    check(main.region_map_plan_button.disabled,"map planning should remain disabled before a home is anchored")
    check(str(main.region_map_plan_button.tooltip_text).find("закреплённого дома") >= 0,"disabled map planning gives the wrong reason")
    check(str(main.region_map_active_label.text).find("Исследовать мир можно") >= 0,"map does not explain that free exploration still works")

    main.FactionEconomy.add_reputation(main.faction_state,"lazaret",16)
    main.ContractSystem.refresh_offers(main.faction_state,main.world_day,true)
    var offer = _find_offer("lazaret_hospital_route")
    check(not offer.is_empty(),"successful-slice reputation does not expose district hospital reconnaissance")
    var accepted = main.ContractSystem.accept(main.faction_state,str(offer.get("id","")),main.world_day)
    check(bool(accepted.get("ok",false)),"district hospital reconnaissance could not be accepted")
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "РАЙОННАЯ БОЛЬНИЦА","accepted sandbox contract does not return to HUD")
    check(str(obj.get("sub","")) .find("не разведан") >= 0,"HUD does not show real contract progress")

    main.discovered_pois["district_hospital"] = true
    obj = main._hud_survival_objective()
    check(str(obj.get("sub","")) .find("ГОТОВО К СДАЧЕ") >= 0,"HUD contract progress does not react to real POI discovery")

    # No authored map pin is introduced by the free-play handoff.
    var snap = main._region_map_snapshot()
    var has_handoff_pin = false
    for marker in snap.get("markers",[]):
        if typeof(marker) == TYPE_DICTIONARY and str(marker.get("label","")) .find("РАЙОННАЯ БОЛЬНИЦА") >= 0 and bool(marker.get("system",false)):
            has_handoff_pin = true
    check(not has_handoff_pin,"sandbox contract created an authored system map pin")

    # Once no contract is active and a home exists, the short dev11 free-play message
    # is allowed to surface again. We only need a non-empty home identity for _has_home.
    main.faction_state["contracts"]["active"] = {}
    main.expedition_journal["home"] = {"key":"test-home","name":"УБЕЖИЩЕ","chunk":[main.current_chunk.x,main.current_chunk.y],"position":[0.0,0.0]}
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "СВОБОДНЫЙ МАРШРУТ","home-ready sandbox handoff lost dev11 free-play acknowledgement")

    main.queue_free()
    await process_frame; await process_frame
    print("FREE-PLAY HANDOFF RUNTIME 1.23-dev12: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
