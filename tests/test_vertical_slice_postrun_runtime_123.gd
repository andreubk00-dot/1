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

func _find_row(source:String,template_id:String = "") -> int:
    for i in range(main.contract_list.item_count):
        var meta = main.contract_list.get_item_metadata(i)
        if typeof(meta) != TYPE_DICTIONARY or str(meta.get("source","")) != source:
            continue
        var contract_id = str(meta.get("id",""))
        var row = main.ContractSystem.contract_by_id(main.faction_state,contract_id)
        if template_id == "" or str(row.get("template_id","")) == template_id:
            return i
    return -1

func _chronicle_count_with(fragment:String) -> int:
    var count = 0
    for row in main.WorldChronicle.entries(main.faction_state,64,false):
        if str(row.get("text","")) .find(fragment) >= 0:
            count += 1
    return count

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null: quit(1); return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame; await process_frame

    # Own the fixture rather than inherit any QA save.
    main.faction_state = main.FactionEconomy.default_state()
    main.VerticalSlice.setup_new_game(main.faction_state,1)
    main.SupplyEventSystem.ensure_state(main.faction_state,1)
    main.ContractSystem.ensure_state(main.faction_state,1)
    main.world_day = 2
    main.VerticalSlice.mark_doctor_met(main.faction_state,1)
    var offer = {}
    for row in main.ContractSystem.offers_for_faction(main.faction_state,"lazaret",1):
        if str(row.get("template_id","")) == main.VerticalSlice.CRISIS_TEMPLATE_ID:
            offer = row; break
    check(not offer.is_empty(),"runtime post-run fixture lacks crisis offer")
    var accepted = main.ContractSystem.accept(main.faction_state,str(offer.get("id","")),1)
    check(bool(accepted.get("ok",false)),"runtime post-run fixture could not accept crisis offer")
    main.faction_state["supply_events"]["active"] = {}
    main.faction_state["supply_events"]["history"] = [{"id":"dev11_supply","faction":"lazaret","created_day":2,"closed_day":2,"outcome":"recovered","stage":"distress"}]
    main.FactionEconomy.adjust_resource(main.faction_state,"lazaret","medicine",14.0)

    var laz_coord = main.RegionCatalog.poi_by_id(main.VerticalSlice.SETTLEMENT_ID).get("coord",Vector2i(-8,-2))
    main.current_chunk = laz_coord
    main.discovered_pois[main.VerticalSlice.HIGH_RISK_POI_ID] = true
    main._grid_add(main.inventory_entries,"sterile_bandage",4,main.INV_W,main.INV_H)
    main._grid_add(main.inventory_entries,"painkillers",3,main.INV_W,main.INV_H)
    var pre = main._vertical_slice_refresh()
    check(bool(pre.get("clinical_cargo_secured",false)),"runtime did not secure real medical cargo before board turn-in")
    var sterile_before = main._inventory_count("sterile_bandage")
    var pain_before = main._inventory_count("painkillers")

    main._open_contract_board("lazaret","Доктор Миронова","lazaret_doctor")
    await process_frame
    check(main.contract_open,"Mironova board did not open for real post-run turn-in")
    var active_row = _find_row("active",main.VerticalSlice.CRISIS_TEMPLATE_ID)
    check(active_row >= 0,"real crisis contract is not selectable as active row")
    if active_row >= 0:
        main._contract_selected(active_row)
        check(bool(main._contract_complete_selected()),"real UI crisis turn-in failed")
    check(main._inventory_count("sterile_bandage") == sterile_before - 4,"real UI turn-in did not remove sterile bandages")
    check(main._inventory_count("painkillers") == pain_before - 3,"real UI turn-in did not remove painkillers")
    var rec = main.VerticalSlice.record(main.faction_state)
    check(bool(rec.get("completed",false)),"real UI turn-in failed to complete vertical slice after consuming cargo")
    check(bool(rec.get("clinical_cargo_secured",false)),"real UI turn-in forgot delivered cargo after inventory removal")
    check(bool(rec.get("completion_feedback_issued",false)),"post-run world feedback was not marked idempotent")
    check(main.SettlementCrisis.stage_rank(main.SettlementCrisis.resource_stage(main.faction_state,"lazaret","medicine")) < main.SettlementCrisis.stage_rank("shortage"),"real UI turn-in did not visibly improve Lazaret medicine state")
    var news_count = _chronicle_count_with("Дальнейшие вылазки снова выбирает сам сталкер")
    check(news_count == 1,"post-run recovery chronicle was not emitted exactly once")
    main._vertical_slice_refresh()
    check(_chronicle_count_with("Дальнейшие вылазки снова выбирает сам сталкер") == news_count,"post-run recovery chronicle duplicated on refresh")
    var obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "ПЕРВЫЙ ЦИКЛ ЗАВЕРШЁН","runtime completion HUD does not offer short debrief handoff")
    check(main.VerticalSlice.marker_target(main.faction_state,main.world_day,true,true,{}).is_empty(),"runtime completed slice still exposes a system route marker")

    var doctor = Node2D.new()
    doctor.set_meta("npc_id","lazaret_doctor")
    doctor.set_meta("faction_id","lazaret")
    doctor.set_meta("display_name","Доктор Миронова")
    doctor.set_meta("npc_role","старший врач")
    main.add_child(doctor)
    var attitude_before = int(main.FactionNpcState.record(main.faction_state,"lazaret_doctor",main.world_day).get("attitude",0))
    main._talk_faction_npc(doctor)
    rec = main.VerticalSlice.record(main.faction_state)
    var attitude_after = int(main.FactionNpcState.record(main.faction_state,"lazaret_doctor",main.world_day).get("attitude",0))
    check(bool(rec.get("doctor_debrief_seen",false)),"Mironova talk did not consume one-time debrief")
    check(attitude_after == attitude_before + 6,"Mironova debrief did not grant exactly one personal trust reward")
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "ЗАКРЕПИТЬ ДОМ","dev12 free-play handoff does not explain route planning requirement when no home exists")
    main.expedition_journal["home"] = {"key":"dev12-home","name":"УБЕЖИЩЕ","chunk":[main.current_chunk.x,main.current_chunk.y],"position":[0.0,0.0]}
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "СВОБОДНЫЙ МАРШРУТ","Mironova debrief lost free-play framing once a home exists")
    main._talk_faction_npc(doctor)
    var attitude_second = int(main.FactionNpcState.record(main.faction_state,"lazaret_doctor",main.world_day).get("attitude",0))
    check(attitude_second == attitude_after,"repeated Mironova talk farmed post-run trust reward")

    main._close_contract_board()
    doctor.queue_free(); main.queue_free()
    await process_frame; await process_frame
    print("VERTICAL SLICE POST-RUN RUNTIME 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
