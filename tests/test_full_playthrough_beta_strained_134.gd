extends SceneTree
const Main = preload("res://main_script_mod.gd")
const Store = preload("res://world/save_store.gd")

var checks := 0
var failures := 0

const STARTER_AID = {
    "perron":"perron_food_reserve",
    "rubezh":"rubezh_ammo_reserve",
    "mechanics":"mechanics_pump_repair",
    "lazaret":"lazaret_dressing_supply"
}
const STARTER_ROUTE = {
    "perron":"perron_zarya_route",
    "rubezh":"rubezh_police_route",
    "mechanics":"mechanics_rail_depot",
    "lazaret":"lazaret_hospital_route"
}

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")

func _clear_save() -> void:
    for suffix in ["",".bak",".tmp"]:
        var path = Main.SAVE_PATH + suffix
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)

func _counts_for(contract:Dictionary) -> Dictionary:
    var out = {}
    var options = contract.get("requirements",[])
    if typeof(options) != TYPE_ARRAY or options.is_empty() or typeof(options[0]) != TYPE_ARRAY:
        return out
    for req in options[0]:
        if typeof(req) == TYPE_DICTIONARY:
            out[str(req.get("id",""))] = int(req.get("qty",0))
    return out

func _activate_template(game,template_id:String,day:int) -> Dictionary:
    game.ContractSystem.ensure_state(game.faction_state,day)
    var template = game.ContractCatalog.template(template_id)
    check(not template.is_empty(),"missing contract template: " + template_id)
    if template.is_empty():
        return {}
    var min_rep = int(template.get("min_rep",0))
    var faction_id = str(template.get("faction",""))
    check(game.FactionEconomy.reputation(game.faction_state,faction_id) >= min_rep,"reputation gate not met for " + template_id)
    var instance = game.ContractSystem._new_instance(game.faction_state,template,day)
    game.faction_state["contracts"]["active"][str(instance.get("id",""))] = instance
    return instance

func _complete_template(game,template_id:String,day:int) -> Dictionary:
    var contract = _activate_template(game,template_id,day)
    if contract.is_empty():
        return {}
    var kind = str(contract.get("kind",""))
    var counts = _counts_for(contract)
    if kind == "discover_poi":
        var poi_id = str(contract.get("poi_id",""))
        check(poi_id != "","discover contract has no poi_id: " + template_id)
        game.discovered_pois[poi_id] = true
    check(game.ContractSystem.can_complete(contract,counts,game.discovered_pois),"completion gate failed for " + template_id)
    var result = game.ContractSystem.complete(game.faction_state,str(contract.get("id","")),day)
    check(bool(result.get("ok",false)),"contract completion failed for " + template_id)
    return result

func _top_up_settlements(game,value:float = 100.0) -> void:
    for raw_faction_id in game.FactionCatalog.ids():
        var faction_id = str(raw_faction_id)
        for resource_id in game.FactionEconomy.RESOURCE_KEYS:
            game.faction_state["factions"][faction_id]["resources"][str(resource_id)] = value

func _complete_project(game,faction_id:String,day:int) -> void:
    game.faction_state["factions"][faction_id]["reputation"] = max(150,int(game.faction_state["factions"][faction_id].get("reputation",0)))
    _top_up_settlements(game,100.0)
    var spec = game.SettlementProjects.project(faction_id)
    var install = game.SettlementProjects.install_strategic_item(game.faction_state,faction_id,str(spec.get("strategic_item","")),day)
    check(bool(install.get("ok",false)),"strategic project install failed for " + faction_id)
    var guard = 0
    while not game.SettlementProjects.is_completed(game.faction_state,faction_id) and guard < 20:
        var commit = game.SettlementProjects.commit_resources(game.faction_state,faction_id,day + guard,game.SettlementProjects.COMMIT_BATCH)
        check(bool(commit.get("ok",false)),"project resource commit stalled for " + faction_id)
        if not bool(commit.get("ok",false)):
            break
        guard += 1
    check(game.SettlementProjects.is_completed(game.faction_state,faction_id),"project never completed for " + faction_id)

func _complete_faction_chain(game,faction_id:String,start_day:int) -> int:
    game.faction_state["factions"][faction_id]["reputation"] = 180
    var day = start_day
    var chain = game.FactionEndgame.chain(faction_id)
    for raw_template_id in chain.get("templates",[]):
        var template_id = str(raw_template_id)
        _top_up_settlements(game,100.0)
        var template = game.ContractCatalog.template(template_id)
        check(game.FactionEndgame.template_available(game.faction_state,template),"endgame gate unavailable for " + template_id)
        var result = _complete_template(game,template_id,day)
        check(not result.get("endgame_outcome",{}).is_empty(),"endgame outcome missing for " + template_id)
        day += 1
    check(game.FactionEndgame.is_finalized(game.faction_state,faction_id),"faction chain not finalized: " + faction_id)
    return day

func _dispose(game) -> void:
    if is_instance_valid(game):
        game._qa_clear_infected()
        await physics_frame
        game.free()
        await process_frame

func run() -> void:
    _clear_save()
    var game = Main.new()
    root.add_child(game)
    game.set_process(false)
    await process_frame
    await process_frame

    # Fresh start -> Lazaret vertical slice.
    check(game.VerticalSlice.active(game.faction_state),"fresh start did not activate vertical slice")
    check(game.SettlementCrisis.resource_stage(game.faction_state,"lazaret","medicine") == "shortage","fresh Lazaret is not in medicine shortage")
    check(game.VerticalSlice.mark_settlement_visited(game.faction_state),"Lazaret visit milestone failed")
    check(game.VerticalSlice.mark_doctor_met(game.faction_state,game.world_day),"Mironova meeting milestone failed")
    var crisis_offer = {}
    for row in game.ContractSystem.offers_for_faction(game.faction_state,"lazaret",game.world_day):
        if str(row.get("template_id","")) == game.VerticalSlice.CRISIS_TEMPLATE_ID:
            crisis_offer = row
            break
    check(not crisis_offer.is_empty(),"vertical slice crisis offer missing")
    var accepted = game.ContractSystem.accept(game.faction_state,str(crisis_offer.get("id","")),game.world_day)
    check(bool(accepted.get("ok",false)),"vertical slice crisis offer could not be accepted")

    var old_day = game.world_day
    game.world_day += 1
    var supply_tick = game.SupplyEventSystem.daily_tick(game.faction_state,game.world_day,[])
    check(bool(supply_tick.get("created",false)),"first supply incident did not spawn")
    var active_supply = game.SupplyEventSystem.active_event(game.faction_state,game.world_day)
    var supply_done = game.SupplyEventSystem.resolve_success(game.faction_state,str(active_supply.get("id","")),game.world_day)
    check(bool(supply_done.get("ok",false)),"first supply incident could not be recovered")
    game.discovered_pois[game.VerticalSlice.HIGH_RISK_POI_ID] = true
    var clinical_counts = {"sterile_bandage":4,"painkillers":3}
    var pre = game.VerticalSlice.refresh_progress(game.faction_state,game.world_day,true,true,clinical_counts)
    check(bool(pre.get("clinical_cargo_secured",false)),"clinical cargo milestone did not arm")
    var crisis_active_id = ""
    for contract_id in game.faction_state.get("contracts",{}).get("active",{}).keys():
        var row = game.faction_state["contracts"]["active"][contract_id]
        if str(row.get("template_id","")) == game.VerticalSlice.CRISIS_TEMPLATE_ID:
            crisis_active_id = str(contract_id)
            break
    check(crisis_active_id != "","accepted crisis contract disappeared before turn-in")
    var crisis_result = game.ContractSystem.complete(game.faction_state,crisis_active_id,game.world_day)
    check(bool(crisis_result.get("ok",false)),"vertical slice crisis contract completion failed")
    var finished_slice = game.VerticalSlice.refresh_progress(game.faction_state,game.world_day,true,true,{})
    check(bool(finished_slice.get("completed",false)),"vertical slice did not complete after real crisis history")
    check(not game.VerticalSlice.active(game.faction_state),"vertical slice remained active after completion")
    check(game.VerticalSlice.mark_doctor_debrief_seen(game.faction_state,game.world_day),"post-run Mironova debrief could not be consumed")

    # Early sandbox: one normal help + starter reconnaissance for every faction.
    var day = game.world_day + 1
    for raw_faction_id in ["perron","rubezh","mechanics","lazaret"]:
        var faction_id = str(raw_faction_id)
        var help = _complete_template(game,str(STARTER_AID[faction_id]),day)
        check(bool(help.get("ok",false)),"starter aid failed for " + faction_id)
        day += 1
        var route_result = _complete_template(game,str(STARTER_ROUTE[faction_id]),day)
        check(str(route_result.get("opened_route","")) != "","starter route did not open for " + faction_id)
        day += 1
    for route_id in game.RegionalStability.STARTER_ROUTE_IDS:
        check(str(game.faction_state.get("world_routes",{}).get(route_id,{}).get("state","")) == "open","starter route missing after sandbox phase: " + str(route_id))

    # QA acceleration of repetitive late-game grind: preserve gates, skip only repetition.
    _top_up_settlements(game,100.0)
    for raw_faction_id in game.FactionCatalog.ids():
        var faction_id = str(raw_faction_id)
        game.faction_state["factions"][faction_id]["reputation"] = 180
        _complete_project(game,faction_id,day)
        day += 8
    for raw_faction_id in game.FactionCatalog.ids():
        day = _complete_faction_chain(game,str(raw_faction_id),day)

    _top_up_settlements(game,55.0)
    game.SupplyEventSystem.ensure_state(game.faction_state,day)
    game.faction_state["supply_events"]["active"] = {}
    game.faction_state["supply_events"]["next_event_day"] = 999999
    var readiness = game.RegionalStability.report(game.faction_state,day)
    check(int(readiness.get("score",0)) == 100,"regional stability did not reach 100% after full infrastructure")
    check(bool(readiness.get("ready",false)),"regional stability 100% state cannot start final season")

    game.world_day = day
    var season_start = game.RegionalEndgame.start(game.faction_state,game.world_day)
    check(bool(season_start.get("ok",false)),"crisis season failed to start")
    check(game.RegionalEndgame.is_active(game.faction_state),"crisis season start did not persist")
    var start_day = game.world_day
    for i in range(1,game.RegionalEndgame.DURATION_DAYS + 1):
        var previous = game.world_day
        game.world_day += 1
        game._process_world_day_rollovers(previous,game.world_day)
        # Strained beta route: only two settlements receive direct checkpoint support.
        if i in [7,14]:
            for faction_id in ["perron","lazaret"]:
                for resource_id in game.FactionEconomy.RESOURCE_KEYS:
                    game.FactionEconomy.adjust_resource(game.faction_state,str(faction_id),str(resource_id),8.0)
    check(game.world_day == start_day + game.RegionalEndgame.DURATION_DAYS,"crisis season consumed wrong number of days")
    check(game.RegionalEndgame.is_complete(game.faction_state),"crisis season did not complete")
    var outcome = game.faction_state.get("regional_endgame",{}).get("outcome",{}).duplicate(true)
    check(game.RegionalEndgame.GLOBAL_OUTCOMES.has(str(outcome.get("id",""))),"crisis season produced invalid regional outcome")
    check(outcome.get("factions",{}).size() == 4,"regional outcome does not contain four faction snapshots")
    check(str(outcome.get("id","")) != "cohesive","strained route unexpectedly produced the fully cohesive ending")
    var non_secure := 0
    for faction_row in outcome.get("factions",{}).values():
        if typeof(faction_row) == TYPE_DICTIONARY and str(faction_row.get("category","critical")) != "secure":
            non_secure += 1
    check(non_secure >= 1,"strained route produced no stressed faction outcome")

    # Post-ending sandbox must stay live and outcome must remain frozen.
    # Production reload sanitizes nested schema-122 state. Compare against the same
    # canonical representation rather than raw pre-save numeric Variant types.
    var canonical_endgame = game.RegionalEndgame.sanitize_state(game.faction_state.get("regional_endgame",{}))
    var frozen = canonical_endgame.get("outcome",{}).duplicate(true)
    var pressure_day = int(game.faction_state.get("regional_endgame",{}).get("pressure_applied_day",0))
    for j in range(30):
        var previous = game.world_day
        game.world_day += 1
        game._process_world_day_rollovers(previous,game.world_day)
    check(game.faction_state.get("regional_endgame",{}).get("outcome",{}) == frozen,"post-ending sandbox recalculated frozen outcome")
    check(int(game.faction_state.get("regional_endgame",{}).get("pressure_applied_day",0)) == pressure_day,"post-ending sandbox continued crisis pressure")

    # Production disk roundtrip at the end of the full path.
    game._save_state()
    await process_frame
    var raw_save = Store.read_save(Main.SAVE_PATH)
    check(int(raw_save.get("save_version",0)) == 122,"full playthrough changed save schema")
    await _dispose(game)

    var loaded = Main.new()
    root.add_child(loaded)
    loaded.set_process(false)
    await process_frame
    await process_frame
    check(loaded.has_meta("loaded_save"),"end-of-playthrough save did not reload")
    check(loaded.RegionalEndgame.is_complete(loaded.faction_state),"reload lost completed regional endgame")
    var loaded_outcome = loaded.faction_state.get("regional_endgame",{}).get("outcome",{}).duplicate(true)
    check(JSON.stringify(loaded_outcome) == JSON.stringify(frozen),"reload changed frozen regional outcome")
    for raw_faction_id in loaded.FactionCatalog.ids():
        var faction_id = str(raw_faction_id)
        check(loaded.SettlementProjects.is_completed(loaded.faction_state,faction_id),"reload lost project: " + faction_id)
        check(loaded.FactionEndgame.is_finalized(loaded.faction_state,faction_id),"reload lost faction chain: " + faction_id)
    await _dispose(loaded)
    _clear_save()

    print("FULL PLAYTHROUGH BETA STRAINED 1.34: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
