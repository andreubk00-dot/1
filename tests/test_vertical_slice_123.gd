extends SceneTree
const FactionEconomy = preload("res://world/faction_economy.gd")
const ContractSystem = preload("res://world/contract_system.gd")
const SupplyEventSystem = preload("res://world/supply_event_system.gd")
const SettlementCrisis = preload("res://world/settlement_crisis.gd")
const VerticalSlice = preload("res://world/vertical_slice.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _find_offer(state:Dictionary,template_id:String,day:int) -> Dictionary:
    for row in ContractSystem.offers_for_faction(state,"lazaret",day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}

func run() -> void:
    var state = FactionEconomy.default_state()
    check(state.has("vertical_slice"),"canonical faction state lacks vertical-slice persistence block")
    check(not VerticalSlice.active(state),"vertical slice must be opt-in for new games, not all sanitized states")
    var old_default_medicine = float(state["factions"]["lazaret"]["resources"]["medicine"])
    check(VerticalSlice.setup_new_game(state,1),"fresh-game vertical slice did not initialize")
    check(VerticalSlice.active(state),"fresh-game vertical slice not active")
    check(abs(float(state["factions"]["lazaret"]["resources"]["medicine"]) - 26.0) < 0.01,"fresh-game Lazaret shortage not seeded at recoverable level")
    check(SettlementCrisis.resource_stage(state,"lazaret","medicine") == "shortage","seeded medicine level must be a real shortage")
    check(not VerticalSlice.setup_new_game(state,1),"vertical slice initialized twice")

    SupplyEventSystem.ensure_state(state,1)
    ContractSystem.ensure_state(state,1)
    var crisis_offer = _find_offer(state,VerticalSlice.CRISIS_TEMPLATE_ID,1)
    check(not crisis_offer.is_empty(),"real crisis contract missing from first Lazaret board")
    var start_objective = VerticalSlice.objective(state,1,false,false,{})
    check(str(start_objective.get("title","")) == "ДОБРАТЬСЯ ДО ЛАЗАРЕТА","first objective must route player to first settlement")
    var start_marker = VerticalSlice.marker_target(state,1,false,false,{})
    check(str(start_marker.get("poi_id","")) == VerticalSlice.SETTLEMENT_ID,"first map marker does not target Lazaret")

    check(VerticalSlice.mark_settlement_visited(state),"settlement visit milestone did not persist")
    check(str(VerticalSlice.objective(state,1,true,false,{}).get("title","")) == "НАЙТИ ДОКТОРА МИРОНОВУ","arrival must transition to named-NPC introduction")
    check(VerticalSlice.mark_doctor_met(state,1),"Doctor Mironova meeting did not persist")
    check(int(state["supply_events"].get("next_event_day",99)) <= 2,"first supply incident was not pulled into slice window")
    check(str(VerticalSlice.objective(state,1,true,false,{}).get("title","")) == "ВЗЯТЬ АВАРИЙНЫЙ ЗАКАЗ","doctor meeting must point to existing crisis contract")

    var accepted = ContractSystem.accept(state,str(crisis_offer.get("id","")),1)
    check(bool(accepted.get("ok",false)),"slice crisis contract could not be accepted")
    check(VerticalSlice.crisis_contract_active(state),"accepted crisis contract not recognized by slice")
    check(str(VerticalSlice.objective(state,1,true,false,{}).get("title","")) == "ПОДГОТОВИТЬСЯ К РЕЙСУ","accepted emergency order skips the first supply-event preparation beat")
    var waiting_marker = VerticalSlice.marker_target(state,1,true,false,{})
    check(str(waiting_marker.get("poi_id","")) == VerticalSlice.SETTLEMENT_ID,"pre-supply route prematurely points at the High Risk site")

    var supply_tick = SupplyEventSystem.daily_tick(state,2,[])
    check(bool(supply_tick.get("created",false)),"first scheduled supply incident was not created on day 2")
    var event = SupplyEventSystem.active_event(state,2)
    check(str(event.get("faction","")) == "lazaret","need scoring did not select medicine-starved Lazaret for first incident")
    check(str(event.get("cargo_resource","")) == "medicine","Lazaret first supply incident is not medical cargo")
    check(str(VerticalSlice.objective(state,2,false,false,{}).get("title","")) == "ОТВЕТИТЬ НА SOS ЛАЗАРЕТА","active supply incident must override route objective")
    check(VerticalSlice.marker_target(state,2,false,false,{}).is_empty(),"slice marker must not duplicate active supply SOS marker")
    var supply_result = SupplyEventSystem.resolve_success(state,str(event.get("id","")),2)
    check(bool(supply_result.get("ok",false)),"first supply event could not be recovered")
    var post_supply = VerticalSlice.refresh_progress(state,2,true,false,{})
    check(bool(post_supply.get("supply_resolved",false)) and str(post_supply.get("supply_outcome","")) == "recovered","recovered first supply event not reflected before High Risk leg")
    check(VerticalSlice.field_reserve_ready(state),"successful first supply event did not unlock one-time field reserve")
    check(VerticalSlice.mark_field_reserve_issued(state,2),"one-time field reserve could not be marked issued")
    check(not VerticalSlice.mark_field_reserve_issued(state,2),"one-time field reserve could be issued twice")
    var clinic_marker = VerticalSlice.marker_target(state,2,true,false,{})
    check(str(clinic_marker.get("poi_id","")) == VerticalSlice.HIGH_RISK_POI_ID,"resolved first supply event did not unlock clinical High Risk route")
    # Later Lazaret incidents belong to the living world, not the onboarding beat.
    # They must neither overwrite the first outcome nor hijack the clinic route.
    state["supply_events"]["active"] = {"id":"qa_later_lazaret","faction":"lazaret","created_day":6,"stage":"distress"}
    var later_objective = VerticalSlice.objective(state,6,false,false,{})
    check(str(later_objective.get("title","")) == "РАЗВЕДАТЬ КЛИНИЧЕСКИЙ КОМПЛЕКС №4","later Lazaret SOS hijacked an already-resolved first-supply route")
    check(str(VerticalSlice.marker_target(state,6,false,false,{}).get("poi_id","")) == VerticalSlice.HIGH_RISK_POI_ID,"later Lazaret SOS hid the already-unlocked clinic route")
    state["supply_events"]["active"] = {}

    # Do not send the player home after opening only one cache: the milestone is
    # the real crisis-order quantity, not merely seeing a valuable medicine item.
    var short_cargo = {"sterile_bandage":3,"painkillers":2}
    var short_progress = VerticalSlice.refresh_progress(state,2,false,true,short_cargo)
    check(not bool(short_progress.get("clinical_cargo_secured",false)),"slice marked incomplete medical order as secured cargo")
    # The clinical core guarantees the complete sterile/painkiller or
    # bandage+antiseptic delivery combination across its authored caches.
    var cargo = {"sterile_bandage":4,"painkillers":3}
    var progress = VerticalSlice.refresh_progress(state,2,false,true,cargo)
    check(bool(progress.get("clinical_discovered",false)),"clinical discovery milestone not recorded")
    check(bool(progress.get("clinical_cargo_secured",false)),"guaranteed clinical cargo threshold not recognized")
    check(str(VerticalSlice.objective(state,2,false,true,cargo).get("title","")) == "ВЕРНУТЬСЯ В ЛАЗАРЕТ","medical reserve must route player back to settlement")

    var active_id = str(accepted.get("contract",{}).get("id",""))
    var completed = ContractSystem.complete(state,active_id,2)
    check(bool(completed.get("ok",false)),"crisis contract completion failed")
    progress = VerticalSlice.refresh_progress(state,2,true,true,cargo)
    check(bool(progress.get("supply_resolved",false)),"supply recovery not reflected in slice state")
    check(str(progress.get("supply_outcome","")) == "recovered","supply outcome missing from slice history")
    check(bool(progress.get("crisis_contract_completed",false)),"contract completion not reflected in slice state")
    check(bool(progress.get("shortage_resolved",false)),"combined supply+contract rewards did not visibly resolve medicine shortage")
    check(bool(progress.get("completed",false)) and not bool(progress.get("enabled",true)),"vertical slice did not close after complete systemic loop")
    check(SettlementCrisis.stage_rank(SettlementCrisis.resource_stage(state,"lazaret","medicine")) < SettlementCrisis.stage_rank("shortage"),"Lazaret remained in shortage after completed loop")

    # Failure is allowed to have consequences: the slice can still be completed by
    # stabilizing the settlement afterwards; it does not force a perfect outcome.
    var failed_route = FactionEconomy.default_state()
    VerticalSlice.setup_new_game(failed_route,1)
    SupplyEventSystem.ensure_state(failed_route,1)
    ContractSystem.ensure_state(failed_route,1)
    VerticalSlice.mark_doctor_met(failed_route,1)
    SupplyEventSystem.daily_tick(failed_route,2,[])
    SupplyEventSystem.daily_tick(failed_route,5,[]) # expire/lost
    var lost = VerticalSlice.refresh_progress(failed_route,5,true,true,{"bandage":8,"antiseptic":2})
    check(bool(lost.get("supply_resolved",false)) and str(lost.get("supply_outcome","")) == "lost","ignored first supply incident must persist a lost consequence")
    check(not VerticalSlice.field_reserve_ready(failed_route),"lost first supply incident incorrectly grants recovered field reserve")
    failed_route["supply_events"]["history"].append({"id":"qa_later_recovery","faction":"lazaret","created_day":8,"closed_day":8,"outcome":"recovered","stage":"distress"})
    var frozen = VerticalSlice.refresh_progress(failed_route,8,true,true,{"bandage":8,"antiseptic":2})
    check(str(frozen.get("supply_outcome","")) == "lost","later recovered supply event rewrote the first lost outcome")
    check(not VerticalSlice.field_reserve_ready(failed_route),"later recovered event retroactively unlocked first-run reserve")

    # If the player prioritizes the SOS before accepting the emergency order, the
    # successful convoy may lift medicine out of shortage. The already-seen order
    # must remain on the real board long enough to prevent an onboarding soft-lock.
    var delayed_accept = FactionEconomy.default_state()
    VerticalSlice.setup_new_game(delayed_accept,1)
    SupplyEventSystem.ensure_state(delayed_accept,1)
    ContractSystem.ensure_state(delayed_accept,1)
    VerticalSlice.mark_doctor_met(delayed_accept,1)
    SupplyEventSystem.daily_tick(delayed_accept,2,[])
    var delayed_event = SupplyEventSystem.active_event(delayed_accept,2)
    check(not delayed_event.is_empty(),"delayed-accept fixture did not create first Lazaret supply event")
    check(bool(SupplyEventSystem.resolve_success(delayed_accept,str(delayed_event.get("id","")),2).get("ok",false)),"delayed-accept fixture could not recover supply event")
    VerticalSlice.refresh_progress(delayed_accept,2,true,false,{})
    check(SettlementCrisis.resource_stage(delayed_accept,"lazaret","medicine") != "shortage","fixture no longer proves convoy can lift the seeded shortage")
    ContractSystem.refresh_offers(delayed_accept,20,false)
    var pinned_offer = _find_offer(delayed_accept,VerticalSlice.CRISIS_TEMPLATE_ID,20)
    check(not pinned_offer.is_empty(),"first-run emergency order expired after convoy recovery and soft-locked the slice")
    check(int(pinned_offer.get("offer_expires_day",0)) >= 31,"first-run emergency order was not extended across the onboarding window")

    # Migration invariant: loading/sanitizing a pre-dev7 state never starts onboarding
    # and never rewrites that world's economy.
    var legacy = FactionEconomy.default_state()
    legacy.erase("vertical_slice")
    legacy["factions"]["lazaret"]["resources"]["medicine"] = 61.0
    var migrated = FactionEconomy.sanitize_state(legacy)
    check(migrated.has("vertical_slice") and not VerticalSlice.active(migrated),"old save migration unexpectedly enabled fresh-game slice")
    check(abs(float(migrated["factions"]["lazaret"]["resources"]["medicine"]) - 61.0) < 0.01,"old save migration rewrote Lazaret resources")
    check(old_default_medicine > 26.0,"test fixture no longer proves fresh-game-only shortage seeding")

    print("VERTICAL SLICE 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
