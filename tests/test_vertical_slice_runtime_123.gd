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

func _has_marker(snapshot:Dictionary,label_part:String,coord:Vector2i) -> bool:
    for row in snapshot.get("markers",[]):
        if row.get("coord",Vector2i(999999,999999)) == coord and str(row.get("label","")) .find(label_part) >= 0:
            return true
    return false

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null:
        quit(1); return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame
    await process_frame
    check(main.VerticalSlice.active(main.faction_state),"fresh actual main scene did not start vertical slice")
    check(main.SettlementCrisis.resource_stage(main.faction_state,"lazaret","medicine") == "shortage","fresh runtime Lazaret is not in real medicine shortage")
    var obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "ДОБРАТЬСЯ ДО ЛАЗАРЕТА","HUD does not surface first-slice route")
    var laz_coord = main.RegionCatalog.poi_by_id(main.VerticalSlice.SETTLEMENT_ID).get("coord",Vector2i.ZERO)
    var clinic_coord = main.RegionCatalog.poi_by_id(main.VerticalSlice.HIGH_RISK_POI_ID).get("coord",Vector2i.ZERO)
    var snap = main._region_map_snapshot()
    check(_has_marker(snap,"ЛАЗАРЕТ",laz_coord),"field map lacks first-slice Lazaret system marker")
    main._open_region_map()
    await process_frame
    check(main.region_map_active_label.text.find("Полевой маршрут активен") >= 0,"fresh slice map still tells player to establish a home before following the system route")
    main._close_region_map()

    main._qa_move_to_world_chunk(laz_coord)
    await process_frame
    await process_frame
    check(main._vertical_slice_at_lazaret(),"runtime move did not recognize Lazaret settlement footprint")
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "НАЙТИ ДОКТОРА МИРОНОВУ","arrival HUD did not transition to named NPC")

    main._open_contract_board("lazaret","Доктор Миронова","lazaret_doctor")
    await process_frame
    check(main.contract_open,"Doctor Mironova board did not open")
    var rec = main.VerticalSlice.record(main.faction_state)
    check(bool(rec.get("met_doctor",false)),"opening Doctor board did not persist meeting milestone")
    check(int(main.faction_state.get("supply_events",{}).get("next_event_day",99)) <= main.world_day + 1,"Doctor meeting did not pull first supply event into slice")
    var crisis_offer = {}
    for row in main.ContractSystem.offers_for_faction(main.faction_state,"lazaret",main.world_day):
        if str(row.get("template_id","")) == main.VerticalSlice.CRISIS_TEMPLATE_ID:
            crisis_offer = row
            break
    check(not crisis_offer.is_empty(),"Doctor board lacks real crisis contract")
    main._close_contract_board()
    var accepted = main.ContractSystem.accept(main.faction_state,str(crisis_offer.get("id","")),main.world_day)
    check(bool(accepted.get("ok",false)),"runtime crisis contract acceptance failed")
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "ПОДГОТОВИТЬСЯ К РЕЙСУ","runtime route skips first supply-event preparation beat")
    snap = main._region_map_snapshot()
    check(not _has_marker(snap,"КЛИНИКА",clinic_coord),"field map prematurely reveals clinical route before first supply outcome")

    main.world_day += 1
    var supply_tick = main.SupplyEventSystem.daily_tick(main.faction_state,main.world_day,[])
    check(bool(supply_tick.get("created",false)),"runtime first supply event was not created inside pacing window")
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "ОТВЕТИТЬ НА SOS ЛАЗАРЕТА","runtime active supply event does not override preparation objective")
    var active_event = main.SupplyEventSystem.active_event(main.faction_state,main.world_day)
    var supply_result = main.SupplyEventSystem.resolve_success(main.faction_state,str(active_event.get("id","")),main.world_day)
    check(bool(supply_result.get("ok",false)),"runtime supply event could not be resolved for slice balance fixture")
    var ammo_before = main._inventory_count("ammo_9x18")
    var bandage_before = main._inventory_count("bandage")
    var reserve = main._vertical_slice_issue_field_reserve()
    check(int(reserve.get("ammo_9x18",0)) == 16 and int(reserve.get("bandage",0)) == 2,"recovered first supply event issued wrong field reserve")
    check(main._inventory_count("ammo_9x18") == ammo_before + 16 and main._inventory_count("bandage") == bandage_before + 2,"field reserve did not reach real player inventory")
    check(main._vertical_slice_issue_field_reserve().is_empty(),"runtime field reserve can be claimed twice")
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "РАЗВЕДАТЬ КЛИНИЧЕСКИЙ КОМПЛЕКС №4","resolved supply event does not transition HUD to High Risk sortie")
    snap = main._region_map_snapshot()
    check(_has_marker(snap,"КЛИНИКА",clinic_coord),"field map lacks clinical High Risk system marker after supply outcome")

    # Discovery plus guaranteed core medicine changes the goal to return, without
    # requiring a rare optional drop.
    main.discovered_pois[main.VerticalSlice.HIGH_RISK_POI_ID] = true
    main._grid_add(main.inventory_entries,"sterile_bandage",4,main.INV_W,main.INV_H)
    main._grid_add(main.inventory_entries,"painkillers",3,main.INV_W,main.INV_H)
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) == "СДАТЬ АВАРИЙНЫЙ ЗАКАЗ","secured clinical cargo at Lazaret does not route player to turn-in")
    snap = main._region_map_snapshot()
    check(_has_marker(snap,"ЛАЗАРЕТ",laz_coord),"return leg does not restore Lazaret system marker")

    # Existing loaded worlds stay untouched: simulate replacing current state with a
    # migrated dev6 state; the vertical-slice HUD/marker must disappear.
    var legacy = main.FactionEconomy.default_state()
    legacy.erase("vertical_slice")
    legacy["factions"]["lazaret"]["resources"]["medicine"] = 63.0
    main.faction_state = main.FactionEconomy.sanitize_state(legacy)
    check(not main.VerticalSlice.active(main.faction_state),"sanitized old runtime state unexpectedly activates onboarding")
    obj = main._hud_survival_objective()
    check(str(obj.get("title","")) != "ДОБРАТЬСЯ ДО ЛАЗАРЕТА","legacy state still receives fresh-game slice HUD")
    snap = main._region_map_snapshot()
    check(not _has_marker(snap,"ПОЛЕВОЙ МАРШРУТ",laz_coord) and not _has_marker(snap,"ПОЛЕВОЙ МАРШРУТ",clinic_coord),"legacy state receives fresh-game slice map marker")

    main.queue_free()
    await process_frame
    print("VERTICAL SLICE RUNTIME 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
