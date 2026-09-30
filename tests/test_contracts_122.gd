extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const ContractSystem = preload("res://world/contract_system.gd")

var failures := 0
var checks := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _offer_with_template(state:Dictionary,faction_id:String,template_id:String,day:int) -> Dictionary:
    for row in ContractSystem.offers_for_faction(state,faction_id,day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}

func run() -> void:
    # Every faction has a physical responsible NPC and authored contracts.
    for npc_id in ["perron_steward","rubezh_dispatch","mechanics_electrician","lazaret_doctor"]:
        var board = ContractCatalog.board_for_npc(npc_id)
        check(not board.is_empty(),npc_id + " must own a contract board")
        check(not FactionCatalog.faction(str(board.get("faction",""))).is_empty(),npc_id + " board faction invalid")
    for faction_id in FactionCatalog.ids():
        check(ContractCatalog.templates_for_faction(faction_id).size() >= 3,faction_id + " needs at least three authored contract templates")

    var state = FactionEconomy.default_state()
    ContractSystem.ensure_state(state,1)
    check(state.has("contracts"),"contract state must live inside faction_state")
    for faction_id in FactionCatalog.ids():
        var offers = ContractSystem.offers_for_faction(state,faction_id,1)
        check(offers.size() >= 1,faction_id + " outsider must receive a basic contract")
        for offer in offers:
            check(int(offer.get("min_rep",0)) <= 0,"outsider offer leaked a reputation-gated contract")

    # Needs drive priority: low food should make Perron's food contract the first offer.
    var needy = FactionEconomy.default_state()
    needy["factions"]["perron"]["resources"]["food"] = 4.0
    needy["factions"]["perron"]["resources"]["technical"] = 90.0
    needy["factions"]["perron"]["resources"]["security"] = 90.0
    ContractSystem.ensure_state(needy,1)
    var needy_offers = ContractSystem.offers_for_faction(needy,"perron",1)
    check(not needy_offers.is_empty(),"needy Perron got no offers")
    check(str(needy_offers[0].get("template_id","")) == "perron_food_reserve","lowest settlement resource must prioritize matching contract")

    # Delivery alternative: either canned food OR grain satisfies Perron's reserve contract.
    var food_offer = _offer_with_template(needy,"perron","perron_food_reserve",1)
    check(not food_offer.is_empty(),"Perron food offer missing")
    var accepted = ContractSystem.accept(needy,str(food_offer.get("id","")),1)
    check(bool(accepted.get("ok",false)),"delivery contract could not be accepted")
    var food_contract = accepted.get("contract",{})
    check(not ContractSystem.can_complete(food_contract,{"canned_meat":5},{}) ,"insufficient canned food must not complete")
    check(ContractSystem.can_complete(food_contract,{"canned_meat":6},{}),"first delivery alternative should complete")
    check(ContractSystem.can_complete(food_contract,{"grain":10},{}),"second delivery alternative should complete")
    var chosen = ContractSystem.requirements_for_completion(food_contract,{"grain":10})
    check(chosen.size() == 1 and str(chosen[0].get("id","")) == "grain","completion must consume the actually satisfied alternative")

    # One active contract per faction prevents stacking all same-faction jobs at once.
    FactionEconomy.add_reputation(needy,"perron",100)
    ContractSystem.refresh_offers(needy,2,true)
    var second_perron = ContractSystem.offers_for_faction(needy,"perron",2)
    if not second_perron.is_empty():
        var blocked = ContractSystem.accept(needy,str(second_perron[0].get("id","")),2)
        check(not bool(blocked.get("ok",false)),"second same-faction active contract must be blocked")
    else:
        check(false,"reliable Perron player should receive another offer for block test")

    # Completing the delivery pays tickets/rep/resources and persists history.
    var tickets_before = int(needy.get("currency_tickets",0))
    var rep_before = FactionEconomy.reputation(needy,"perron")
    var food_before = float(needy["factions"]["perron"]["resources"]["food"])
    var finish = ContractSystem.complete(needy,str(food_contract.get("id","")),2)
    check(bool(finish.get("ok",false)),"delivery completion mutation failed")
    check(int(needy.get("currency_tickets",0)) > tickets_before,"contract reward must pay calculation tickets")
    check(FactionEconomy.reputation(needy,"perron") > rep_before,"contract reward must increase faction reputation")
    check(float(needy["factions"]["perron"]["resources"]["food"]) > food_before,"delivery contract must improve settlement resource")
    check(int(needy["factions"]["perron"].get("completed_contracts",0)) == 1,"completed contract counter not updated")
    check(needy.get("contract_history",[]).size() >= 1,"contract completion must enter persistent history")

    # Reputation unlocks route contracts; discovery-first requires the POI to be known.
    var route_state = FactionEconomy.default_state()
    FactionEconomy.add_reputation(route_state,"rubezh",100)
    ContractSystem.ensure_state(route_state,1)
    var route_offer = _offer_with_template(route_state,"rubezh","rubezh_east_checkpoint",1)
    if route_offer.is_empty():
        ContractSystem.refresh_offers(route_state,1,true)
        route_offer = _offer_with_template(route_state,"rubezh","rubezh_east_checkpoint",1)
    check(not route_offer.is_empty(),"Rubezh east route offer missing for reliable player")
    var route_accept = ContractSystem.accept(route_state,str(route_offer.get("id","")),1)
    check(bool(route_accept.get("ok",false)),"route contract could not be accepted")
    var route_contract = route_accept.get("contract",{})
    check(not ContractSystem.can_complete(route_contract,{},{}),"undiscovered route target must not complete")
    check(ContractSystem.can_complete(route_contract,{}, {"military_checkpoint":true}),"discovered target must satisfy route contract")
    var sec_before = float(route_state["factions"]["rubezh"]["resources"]["security"])
    var route_finish = ContractSystem.complete(route_state,str(route_contract.get("id","")),2)
    check(bool(route_finish.get("ok",false)),"route contract completion failed")
    check(str(route_finish.get("opened_route","")) == "route_rubezh_east","route contract must expose persistent route id")
    check(str(route_state.get("world_routes",{}).get("route_rubezh_east",{}).get("state","")) == "open","world route state was not opened")
    check(float(route_state["factions"]["rubezh"]["resources"]["security"]) > sec_before,"route completion must immediately improve settlement security")

    # Open route applies ongoing daily benefits after normal resource decay.
    var mechanics_security_before = float(route_state["factions"]["mechanics"]["resources"]["security"])
    var rubezh_security_before = float(route_state["factions"]["rubezh"]["resources"]["security"])
    FactionEconomy.daily_tick(route_state)
    var mechanics_security_after = float(route_state["factions"]["mechanics"]["resources"]["security"])
    var rubezh_security_after = float(route_state["factions"]["rubezh"]["resources"]["security"])
    check(mechanics_security_after > mechanics_security_before - 0.35,"open route must offset part of Mechanics daily security decay")
    check(rubezh_security_after > rubezh_security_before - 0.35,"open route must offset part of Rubezh daily security decay")

    # Offer expiration refreshes, abandoned contracts enter history but do not cost reputation.
    var abandon_state = FactionEconomy.default_state()
    ContractSystem.ensure_state(abandon_state,1)
    var old_offer = ContractSystem.offers_for_faction(abandon_state,"lazaret",1)[0]
    var old_id = str(old_offer.get("id",""))
    var ab_accept = ContractSystem.accept(abandon_state,old_id,1)
    check(bool(ab_accept.get("ok",false)),"abandon fixture failed to accept")
    var rep_ab_before = FactionEconomy.reputation(abandon_state,"lazaret")
    check(ContractSystem.abandon(abandon_state,old_id,2),"active contract could not be abandoned")
    check(FactionEconomy.reputation(abandon_state,"lazaret") == rep_ab_before,"abandoning a contract must not silently penalize reputation")
    check(str(abandon_state["contract_history"][-1].get("status","")) == "abandoned","abandon history status missing")

    # Contract state survives JSON/FactionEconomy roundtrip and is sanitized by ContractSystem.
    var encoded = JSON.stringify(route_state)
    var decoded = JSON.parse_string(encoded)
    var roundtrip = FactionEconomy.sanitize_state(decoded)
    ContractSystem.ensure_state(roundtrip,3)
    check(str(roundtrip.get("world_routes",{}).get("route_rubezh_east",{}).get("state","")) == "open","opened route lost across save roundtrip")
    check(roundtrip.get("contract_history",[]).size() == route_state.get("contract_history",[]).size(),"contract history lost across save roundtrip")

    print("CONTRACTS 1.22-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
