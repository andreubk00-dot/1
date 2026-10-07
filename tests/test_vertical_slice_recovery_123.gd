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
    var defaults = VerticalSlice.default_state()
    check(int(defaults.get("clinical_incapacitations",-1)) == 0,"default clinical incapacitation count is not zero")
    check(not bool(defaults.get("recovery_pending",true)),"default recovery pending is true")
    check(not bool(defaults.get("recovery_aid_issued",true)),"default recovery aid is already issued")

    var malformed = VerticalSlice.sanitize_state({
        "enabled":true,"initialized":true,"clinical_incapacitations":999,
        "last_incapacitation_day":-4,"last_incapacitation_floor":77,
        "recovery_pending":true,"recovery_aid_issued":true,"recovery_aid_day":-3
    })
    check(int(malformed["clinical_incapacitations"]) == 99,"incapacitation count sanitize cap failed")
    check(int(malformed["last_incapacitation_day"]) == 0,"negative incapacitation day survived sanitize")
    check(int(malformed["last_incapacitation_floor"]) == 9,"incapacitation floor sanitize cap failed")
    check(int(malformed["recovery_aid_day"]) == 0,"negative recovery aid day survived sanitize")

    var too_early = FactionEconomy.default_state()
    VerticalSlice.setup_new_game(too_early,1)
    var rejected = VerticalSlice.mark_clinical_incapacitation(too_early,1,1,{})
    check(rejected.is_empty(),"clinical rescue activated before doctor/supply milestones")

    var state = _prepared_state()
    check(VerticalSlice.active(state),"prepared recovery fixture is not active")
    check(bool(VerticalSlice.record(state).get("supply_resolved",false)),"prepared recovery fixture lacks resolved first supply")
    check(VerticalSlice.crisis_contract_active(state),"prepared recovery fixture lacks active emergency contract")

    var first = VerticalSlice.mark_clinical_incapacitation(state,2,2,{})
    check(not first.is_empty(),"first clinical incapacitation was rejected")
    check(int(first.get("count",0)) == 1,"first clinical incapacitation count mismatch")
    check(bool(first.get("recovery_pending",false)),"first failed run did not enter regroup state")
    check(bool(first.get("aid_ready",false)),"first failed run did not unlock one-time recovery aid")
    var rec = VerticalSlice.record(state)
    check(bool(rec.get("clinical_discovered",false)),"failed clinic run did not record clinical discovery")
    check(int(rec.get("last_incapacitation_floor",0)) == 2,"failed clinic floor was not persisted")
    check(int(rec.get("last_incapacitation_day",0)) == 2,"failed clinic day was not persisted")
    check(VerticalSlice.clinical_recovery_aid_ready(state),"one-time recovery aid not ready after first failure")
    check(VerticalSlice.mark_clinical_recovery_aid_issued(state,2),"one-time recovery aid could not be marked issued")
    check(not VerticalSlice.clinical_recovery_aid_ready(state),"one-time recovery aid remains claimable")
    check(not VerticalSlice.mark_clinical_recovery_aid_issued(state,2),"one-time recovery aid can be marked twice")

    var regroup = VerticalSlice.objective(state,2,true,true,{})
    check(str(regroup.get("title","")) == "ПЕРЕПРОВЕРИТЬ СНАРЯЖЕНИЕ","Lazaret regroup objective missing after failed clinic run")
    check(str(regroup.get("sub","")) .find("6 ч") >= 0,"regroup objective does not explain evacuation time cost")
    var retry_marker = VerticalSlice.marker_target(state,2,true,true,{})
    check(str(retry_marker.get("poi_id","")) == VerticalSlice.HIGH_RISK_POI_ID,"regroup marker does not point back to clinic")
    check(str(retry_marker.get("label","")) .find("ПОВТОР") >= 0,"regroup marker lacks retry identity")

    VerticalSlice.refresh_progress(state,2,false,true,{})
    rec = VerticalSlice.record(state)
    check(not bool(rec.get("recovery_pending",true)),"leaving Lazaret did not clear temporary regroup state")
    var retry_objective = VerticalSlice.objective(state,2,false,true,{})
    check(str(retry_objective.get("title","")) == "ДОБЫТЬ МЕДИЦИНСКИЙ РЕЗЕРВ","retry did not return to clinical cargo objective")

    var second = VerticalSlice.mark_clinical_incapacitation(state,3,3,{})
    check(int(second.get("count",0)) == 2,"second clinical incapacitation count mismatch")
    check(bool(second.get("recovery_pending",false)),"second failed run did not re-enter regroup state")
    check(not bool(second.get("aid_ready",true)),"second failed run incorrectly grants another recovery aid")
    regroup = VerticalSlice.objective(state,3,true,true,{})
    check(str(regroup.get("sub","")) .find("помощь больше не пополняется") >= 0,"second failure does not explain no-repeat aid rule")

    # Cargo already secured: evacuation can still happen, but no regroup gate or extra aid.
    VerticalSlice.refresh_progress(state,3,false,true,{"sterile_bandage":4,"painkillers":3})
    var cargo_death = VerticalSlice.mark_clinical_incapacitation(state,3,3,{"sterile_bandage":4,"painkillers":3})
    check(bool(cargo_death.get("cargo_secured",false)),"clinical death with full order forgot secured cargo")
    check(not bool(cargo_death.get("recovery_pending",true)),"secured cargo incorrectly enters retry regroup")
    check(not bool(cargo_death.get("aid_ready",true)),"secured cargo death incorrectly grants recovery aid")
    var submit = VerticalSlice.objective(state,3,true,true,{"sterile_bandage":4,"painkillers":3})
    check(str(submit.get("title","")) == "СДАТЬ АВАРИЙНЫЙ ЗАКАЗ","cargo at Lazaret still tells player to return to Lazaret")

    # Old dev8-style records sanitize with recovery fields disabled and never gain aid.
    var legacy_raw = VerticalSlice.default_state()
    for key in ["clinical_incapacitations","last_incapacitation_day","last_incapacitation_floor","recovery_pending","recovery_aid_issued","recovery_aid_day"]:
        legacy_raw.erase(key)
    legacy_raw["enabled"] = true
    legacy_raw["initialized"] = true
    var legacy = VerticalSlice.sanitize_state(legacy_raw)
    check(int(legacy.get("clinical_incapacitations",-1)) == 0,"dev8 slice migration invented incapacitations")
    check(not bool(legacy.get("recovery_pending",true)),"dev8 slice migration invented recovery pending")
    check(not bool(legacy.get("recovery_aid_issued",true)),"dev8 slice migration invented issued aid")

    print("VERTICAL SLICE RECOVERY 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
