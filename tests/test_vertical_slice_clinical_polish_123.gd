extends SceneTree
const FactionEconomy = preload("res://world/faction_economy.gd")
const SupplyEventSystem = preload("res://world/supply_event_system.gd")
const ContractSystem = preload("res://world/contract_system.gd")
const VerticalSlice = preload("res://world/vertical_slice.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _crisis_offer(state:Dictionary,day:int) -> Dictionary:
    for row in ContractSystem.offers_for_faction(state,"lazaret",day):
        if str(row.get("template_id","")) == VerticalSlice.CRISIS_TEMPLATE_ID:
            return row
    return {}

func _prepared_state() -> Dictionary:
    var state = FactionEconomy.default_state()
    VerticalSlice.setup_new_game(state,1)
    SupplyEventSystem.ensure_state(state,1)
    ContractSystem.ensure_state(state,1)
    VerticalSlice.mark_doctor_met(state,1)
    var offer = _crisis_offer(state,1)
    if not offer.is_empty():
        ContractSystem.accept(state,str(offer.get("id","")),1)
    SupplyEventSystem.daily_tick(state,2,[])
    var event = SupplyEventSystem.active_event(state,2)
    if not event.is_empty():
        SupplyEventSystem.resolve_success(state,str(event.get("id","")),2)
    VerticalSlice.refresh_progress(state,2,true,false,{})
    return state

func run() -> void:
    var state = _prepared_state()
    check(VerticalSlice.clinical_first_run_balance_active(state),"prepared first clinical run is not balance-active")
    check(VerticalSlice.clinical_ground_enemy_count(state,Vector2i(0,0),7) == 5,"reception threat budget is not 5")
    check(VerticalSlice.clinical_ground_enemy_count(state,Vector2i(1,0),9) == 9,"side wing was incorrectly nerfed by onboarding")
    check(VerticalSlice.clinical_floor_enemy_count(state,2,10) == 7,"clinical floor 2 threat budget is not 7")
    check(VerticalSlice.clinical_floor_enemy_count(state,3,12) == 9,"clinical floor 3 threat budget is not 9")
    check(VerticalSlice.clinical_floor_enemy_count(state,4,12) == 12,"unknown floor should retain authored population")

    # A contract expiry/re-offer while the player is inside the clinic must not
    # re-expand an unloaded floor and effectively respawn invisible threats.
    var active_before = state.get("contracts",{}).get("active",[]).duplicate(true)
    state["contracts"]["active"] = []
    check(VerticalSlice.clinical_first_run_balance_active(state),"first-run balance vanished when crisis contract status changed mid-sortie")
    check(VerticalSlice.clinical_floor_enemy_count(state,2,10) == 7,"contract status change re-expanded floor 2 threat budget")
    state["contracts"]["active"] = active_before

    var low = VerticalSlice.clinical_readiness({"ammo_9x18":24,"bandage":2,"water":1})
    check(not bool(low.get("ready",true)),"starter 24-round loadout is incorrectly advertised as fully ready")
    check(int(low.get("ammo_target",0)) == 32 and int(low.get("treatment_target",0)) == 2 and int(low.get("water_target",0)) == 1,"readiness targets drifted")
    var ready = VerticalSlice.clinical_readiness({"ammo_9x18":32,"sterile_bandage":2,"water":1})
    check(bool(ready.get("ready",false)),"32 rounds + two dressings + water should satisfy advisory readiness")
    var text = VerticalSlice.clinical_readiness_text({"ammo_9x18":40,"bandage":4,"water":1})
    check(text.find("БК 40/32") >= 0 and text.find("лечение 4/2") >= 0 and text.find("вода 1/1") >= 0,"readiness text is not actionable")
    var obj = VerticalSlice.objective(state,2,false,false,{"ammo_9x18":40,"bandage":4,"water":1})
    check(str(obj.get("title","")) == "РАЗВЕДАТЬ КЛИНИЧЕСКИЙ КОМПЛЕКС №4","ready route lost clinic objective")
    check(str(obj.get("sub","")) .find("БК 40/32") >= 0,"clinic objective does not expose readiness summary")

    # Cargo readiness is intentionally current-state until the real order is turned in.
    # Consuming mission medicine must route the player back to loot, not to an impossible turn-in.
    var cargo_ready = {"sterile_bandage":4,"painkillers":3}
    var cargo_rec = VerticalSlice.refresh_progress(state,2,false,true,cargo_ready)
    check(bool(cargo_rec.get("clinical_cargo_secured",false)),"complete emergency-order cargo was not recognized")
    var cargo_spent = VerticalSlice.refresh_progress(state,2,false,true,{"sterile_bandage":3,"painkillers":2})
    check(not bool(cargo_spent.get("clinical_cargo_secured",true)),"spent mission medicine left a stale secured-cargo flag")
    check(str(VerticalSlice.objective(state,2,false,true,{"sterile_bandage":3,"painkillers":2}).get("title","")) == "ДОБЫТЬ МЕДИЦИНСКИЙ РЕЗЕРВ","spent mission medicine still routes to impossible turn-in")

    # Completion acknowledgement used to be unreachable because completion disables
    # the slice before objective() could show its final branch.
    var rec = state["vertical_slice"]
    rec["completed"] = true
    rec["enabled"] = false
    rec["completed_day"] = 5
    state["vertical_slice"] = rec
    check(not VerticalSlice.clinical_first_run_balance_active(state),"completed slice still receives first-run enemy reduction")
    check(VerticalSlice.clinical_ground_enemy_count(state,Vector2i(0,0),7) == 7,"completed slice did not restore full reception population")
    check(VerticalSlice.clinical_floor_enemy_count(state,2,10) == 10,"completed slice did not restore full floor-2 population")
    var done_now = VerticalSlice.objective(state,5,true,true,{})
    var done_next = VerticalSlice.objective(state,6,true,true,{})
    var done_later = VerticalSlice.objective(state,7,true,true,{})
    check(str(done_now.get("title","")) == "ПЕРВЫЙ ЦИКЛ ЗАВЕРШЁН","completion acknowledgement is still unreachable")
    check(str(done_next.get("title","")) == "ПЕРВЫЙ ЦИКЛ ЗАВЕРШЁН","completion acknowledgement disappears too quickly")
    check(done_later.is_empty(),"completion acknowledgement never clears")

    print("VERTICAL SLICE CLINICAL POLISH 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
