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

func _find_offer(state:Dictionary,day:int) -> Dictionary:
    for row in ContractSystem.offers_for_faction(state,"lazaret",day):
        if str(row.get("template_id","")) == VerticalSlice.CRISIS_TEMPLATE_ID:
            return row
    return {}

func run() -> void:
    var state = FactionEconomy.default_state()
    check(VerticalSlice.setup_new_game(state,1),"post-run fixture could not start fresh slice")
    SupplyEventSystem.ensure_state(state,1)
    ContractSystem.ensure_state(state,1)
    VerticalSlice.mark_doctor_met(state,1)
    var offer = _find_offer(state,1)
    check(not offer.is_empty(),"post-run fixture lacks real crisis offer")
    var accepted = ContractSystem.accept(state,str(offer.get("id","")),1)
    check(bool(accepted.get("ok",false)),"post-run fixture could not accept crisis contract")

    # Model the real recovered first convoy. The resource gain plus contract reward
    # makes the settlement improvement systemic rather than a decorative flag.
    state["supply_events"]["active"] = {}
    state["supply_events"]["history"] = [{"id":"dev11_supply","faction":"lazaret","created_day":2,"closed_day":2,"outcome":"recovered","stage":"distress"}]
    FactionEconomy.adjust_resource(state,"lazaret","medicine",14.0)
    var cargo = {"sterile_bandage":4,"painkillers":3}
    var before_turnin = VerticalSlice.refresh_progress(state,2,true,true,cargo)
    check(bool(before_turnin.get("clinical_cargo_secured",false)),"real medical cargo was not secured before turn-in")
    check(not bool(before_turnin.get("completed",false)),"slice completed before real crisis delivery")

    var active_id = str(accepted.get("contract",{}).get("id",""))
    var result = ContractSystem.complete(state,active_id,2)
    check(bool(result.get("ok",false)),"real crisis contract could not complete")
    # Critical dev11 regression: the UI has already removed the delivered items at
    # this point. Completion must remain valid with an empty backpack.
    var post = VerticalSlice.refresh_progress(state,2,true,true,{})
    check(bool(post.get("crisis_contract_completed",false)),"post-turn-in state forgot completed crisis contract")
    check(bool(post.get("clinical_cargo_secured",false)),"post-turn-in state forgot already delivered medical cargo")
    check(bool(post.get("shortage_resolved",false)),"real resource recovery did not clear shortage")
    check(bool(post.get("completed",false)) and not bool(post.get("enabled",true)),"post-run slice did not close after real UI-style turn-in")
    check(SettlementCrisis.stage_rank(SettlementCrisis.resource_stage(state,"lazaret","medicine")) < SettlementCrisis.stage_rank("shortage"),"post-run fixture did not visibly improve Lazaret medicine stage")

    var medicine_before = SettlementCrisis.resource_value(state,"lazaret","medicine")
    check(VerticalSlice.completion_feedback_ready(state),"completed slice did not expose one-time post-run feedback")
    check(VerticalSlice.mark_completion_feedback_issued(state,2),"could not mark post-run feedback issued")
    check(not VerticalSlice.mark_completion_feedback_issued(state,2),"post-run feedback can be issued twice")
    check(abs(SettlementCrisis.resource_value(state,"lazaret","medicine") - medicine_before) < 0.001,"feedback marker changed settlement economy")
    var recovery = VerticalSlice.settlement_recovery_summary(state)
    check(str(recovery.get("stage","")) in ["stable","strain"],"post-run recovery summary reports unresolved shortage")
    check(str(recovery.get("note","")) != "","post-run recovery summary has no player-facing consequence text")

    var before_debrief = VerticalSlice.objective(state,2,true,true,{})
    check(str(before_debrief.get("title","")) == "ПЕРВЫЙ ЦИКЛ ЗАВЕРШЁН","completion HUD does not bridge into post-run debrief")
    check(VerticalSlice.marker_target(state,2,true,true,{}).is_empty(),"completed slice still pins an authored route on the map")
    check(VerticalSlice.doctor_debrief_ready(state),"Mironova debrief not available after completion")
    check(VerticalSlice.mark_doctor_debrief_seen(state,2),"could not mark Mironova debrief seen")
    check(not VerticalSlice.mark_doctor_debrief_seen(state,2),"Mironova debrief can be rewarded twice")
    var after_debrief = VerticalSlice.objective(state,2,true,true,{})
    check(str(after_debrief.get("title","")) == "СВОБОДНЫЙ МАРШРУТ","debrief does not hand HUD back to free-play framing")
    check(VerticalSlice.objective(state,4,true,true,{}).is_empty(),"post-run handoff overstays its short HUD window")
    check(abs(SettlementCrisis.resource_value(state,"lazaret","medicine") - medicine_before) < 0.001,"debrief marker changed settlement economy")

    # Same-schema migration: a completed dev10 record gets new idempotence flags but
    # no resource changes and no replayed contract/supply rewards.
    var legacy = state.duplicate(true)
    legacy["vertical_slice"].erase("completion_feedback_issued")
    legacy["vertical_slice"].erase("completion_feedback_day")
    legacy["vertical_slice"].erase("doctor_debrief_seen")
    legacy["vertical_slice"].erase("doctor_debrief_day")
    var legacy_medicine = SettlementCrisis.resource_value(legacy,"lazaret","medicine")
    var migrated = FactionEconomy.sanitize_state(legacy)
    var migrated_rec = VerticalSlice.record(migrated)
    check(bool(migrated_rec.get("completed",false)),"dev10 completed slice lost completion during dev11 migration")
    check(not bool(migrated_rec.get("completion_feedback_issued",true)),"dev10 migration invented issued post-run feedback")
    check(not bool(migrated_rec.get("doctor_debrief_seen",true)),"dev10 migration invented Mironova debrief")
    check(abs(SettlementCrisis.resource_value(migrated,"lazaret","medicine") - legacy_medicine) < 0.001,"dev11 migration rewrote completed settlement economy")
    migrated["factions"]["lazaret"]["resources"]["medicine"] = 24.0
    var stale_summary = VerticalSlice.settlement_recovery_summary(migrated)
    check(str(stale_summary.get("stage","")) == "shortage","post-run summary lost current shortage state")
    check(str(stale_summary.get("note","")).find("снова") >= 0,"post-run summary falsely claims old completed save is still recovered")

    print("VERTICAL SLICE POST-RUN 1.23-dev11: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
