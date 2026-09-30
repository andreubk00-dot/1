extends SceneTree
const Main = preload("res://main_script_mod.gd")

var failures := 0
var checks := 0

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

func _find_offer(game,faction_id:String,template_id:String) -> Dictionary:
    for row in game.ContractSystem.offers_for_faction(game.faction_state,faction_id,game.world_day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.world_day = 4
    game.FactionEconomy.add_reputation(game.faction_state,"rubezh",100)
    game.ContractSystem.ensure_state(game.faction_state,game.world_day)

    # Complete one route contract so a persistent world effect exists.
    var route_offer = _find_offer(game,"rubezh","rubezh_east_checkpoint")
    check(not route_offer.is_empty(),"route fixture offer missing")
    var accepted_route = game.ContractSystem.accept(game.faction_state,str(route_offer.get("id","")),game.world_day)
    check(bool(accepted_route.get("ok",false)),"route fixture acceptance failed")
    game.discovered_pois["military_checkpoint"] = true
    var route_contract = accepted_route.get("contract",{})
    check(game.ContractSystem.can_complete(route_contract,{},game.discovered_pois),"route fixture should be completable")
    var finished = game.ContractSystem.complete(game.faction_state,str(route_contract.get("id","")),game.world_day)
    check(bool(finished.get("ok",false)),"route fixture completion failed")

    # Leave a Perron delivery contract active to verify lifecycle persistence too.
    var perron_offer = _find_offer(game,"perron","perron_food_reserve")
    check(not perron_offer.is_empty(),"active contract fixture offer missing")
    var accepted_perron = game.ContractSystem.accept(game.faction_state,str(perron_offer.get("id","")),game.world_day)
    check(bool(accepted_perron.get("ok",false)),"active contract fixture acceptance failed")
    var active_id = str(accepted_perron.get("contract",{}).get("id",""))

    game._save_state()
    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    loaded.ContractSystem.ensure_state(loaded.faction_state,loaded.world_day)

    check(str(loaded.faction_state.get("world_routes",{}).get("route_rubezh_east",{}).get("state","")) == "open","production save/load lost opened world route")
    check(loaded.faction_state.get("contracts",{}).get("active",{}).has(active_id),"production save/load lost active contract")
    check(loaded.faction_state.get("contract_history",[]).size() >= 1,"production save/load lost contract history")
    check(int(loaded.faction_state.get("factions",{}).get("rubezh",{}).get("completed_contracts",0)) >= 1,"production save/load lost faction contract counter")

    loaded.free()
    game.queue_free()
    await process_frame
    await process_frame
    print("CONTRACT SAVE RUNTIME 1.22-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
