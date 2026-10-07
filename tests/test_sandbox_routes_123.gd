extends SceneTree
const FactionEconomy = preload("res://world/faction_economy.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const ContractSystem = preload("res://world/contract_system.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _offer(state:Dictionary,faction_id:String,template_id:String,day:int) -> Dictionary:
    for row in ContractSystem.offers_for_faction(state,faction_id,day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}

func _has_offer(state:Dictionary,faction_id:String,template_id:String,day:int) -> bool:
    return not _offer(state,faction_id,template_id,day).is_empty()

func _complete_basic_and_unlock(faction_id:String,basic_id:String,recon_id:String,counts:Dictionary,expected_rep:int,day:int) -> Dictionary:
    var state = FactionEconomy.default_state()
    ContractSystem.refresh_offers(state,day,true)
    check(not _has_offer(state,faction_id,recon_id,day),faction_id + " starter recon leaked before first contribution")
    var basic = _offer(state,faction_id,basic_id,day)
    check(not basic.is_empty(),faction_id + " basic contract missing for outsider")
    var accepted = ContractSystem.accept(state,str(basic.get("id","")),day)
    check(bool(accepted.get("ok",false)),faction_id + " basic contract could not be accepted")
    var active = accepted.get("contract",{})
    check(ContractSystem.can_complete(active,counts,{}),faction_id + " basic fixture does not satisfy real requirements")
    var done = ContractSystem.complete(state,str(active.get("id","")),day)
    check(bool(done.get("ok",false)),faction_id + " basic contract did not complete")
    check(FactionEconomy.reputation(state,faction_id) == expected_rep,faction_id + " first contribution reputation no longer matches starter recon threshold")
    ContractSystem.refresh_offers(state,day,false)
    check(_has_offer(state,faction_id,recon_id,day),faction_id + " reconnaissance did not unlock immediately after first contribution")
    return state

func run() -> void:
    var expected = {
        "perron_zarya_route":8,
        "rubezh_police_route":9,
        "mechanics_rail_depot":9,
        "lazaret_hospital_route":10
    }
    for template_id in expected.keys():
        var row = ContractCatalog.template(template_id)
        check(not row.is_empty(),template_id + " missing")
        check(bool(row.get("starter_recon",false)),template_id + " is not marked as starter reconnaissance")
        check(str(row.get("kind","")) == "discover_poi",template_id + " starter route stopped being reconnaissance")
        check(int(row.get("min_rep",999)) == int(expected[template_id]),template_id + " starter reputation threshold drifted")
        check(str(row.get("poi_id","")) != "",template_id + " has no real POI target")
        check(not row.has("global_goal"),template_id + " invented a global goal")

    var perron = _complete_basic_and_unlock("perron","perron_food_reserve","perron_zarya_route",{"canned_meat":6},8,5)
    var rubezh = _complete_basic_and_unlock("rubezh","rubezh_ammo_reserve","rubezh_police_route",{"ammo_9x18":30},9,5)
    var mechanics = _complete_basic_and_unlock("mechanics","mechanics_pump_repair","mechanics_rail_depot",{"repair_kit":2},9,5)

    # Each unlocked reconnaissance remains a normal POI contract and opens a useful persistent route.
    for row in [
        [perron,"perron","perron_zarya_route","dacha_coop_zarya","route_perron_zarya"],
        [rubezh,"rubezh","rubezh_police_route","district_police","route_rubezh_police"],
        [mechanics,"mechanics","mechanics_rail_depot","rail_depot","route_mechanics_depot"]
    ]:
        var state:Dictionary = row[0]
        var faction_id:String = row[1]
        var template_id:String = row[2]
        var poi_id:String = row[3]
        var route_id:String = row[4]
        var offer = _offer(state,faction_id,template_id,5)
        var accepted = ContractSystem.accept(state,str(offer.get("id","")),5)
        check(bool(accepted.get("ok",false)),template_id + " could not be accepted")
        var contract = accepted.get("contract",{})
        check(not ContractSystem.can_complete(contract,{},{}),template_id + " completes without exploration")
        check(ContractSystem.can_complete(contract,{}, {poi_id:true}),template_id + " does not react to real POI discovery")
        var result = ContractSystem.complete(state,str(contract.get("id","")),6)
        check(bool(result.get("ok",false)),template_id + " could not be completed")
        check(str(result.get("opened_route","")) == route_id,template_id + " did not open its authored supply route")
        check(str(state.get("world_routes",{}).get(route_id,{}).get("state","")) == "open",template_id + " route state did not persist")
        ContractSystem.refresh_offers(state,6,false)
        check(not _has_offer(state,faction_id,template_id,6),template_id + " reappeared after route was opened")

    # The successful Lazaret slice naturally exposes the district hospital without another delivery grind.
    var lazaret = FactionEconomy.default_state()
    FactionEconomy.add_reputation(lazaret,"lazaret",16)
    ContractSystem.refresh_offers(lazaret,7,true)
    var hospital_offer = _offer(lazaret,"lazaret","lazaret_hospital_route",7)
    check(not hospital_offer.is_empty(),"successful Lazaret handoff has no district hospital reconnaissance")
    var hospital_accept = ContractSystem.accept(lazaret,str(hospital_offer.get("id","")),7)
    check(bool(hospital_accept.get("ok",false)),"district hospital reconnaissance could not be accepted")
    var hospital_done = ContractSystem.complete(lazaret,str(hospital_accept.get("contract",{}).get("id","")),8)
    check(bool(hospital_done.get("ok",false)),"district hospital reconnaissance could not complete")
    check(str(hospital_done.get("opened_route","")) == "route_lazaret_hospital","district hospital did not open its medicine route")
    var medicine_before = float(lazaret["factions"]["lazaret"]["resources"]["medicine"])
    FactionEconomy.daily_tick(lazaret)
    var medicine_after = float(lazaret["factions"]["lazaret"]["resources"]["medicine"])
    check(medicine_after > medicine_before - 0.35,"district hospital route does not materially offset daily medicine decay")

    # Switching factions is allowed: one real job per faction can coexist without a hidden storyline lock.
    var multi = FactionEconomy.default_state()
    FactionEconomy.add_reputation(multi,"perron",8)
    FactionEconomy.add_reputation(multi,"rubezh",9)
    FactionEconomy.add_reputation(multi,"mechanics",9)
    FactionEconomy.add_reputation(multi,"lazaret",10)
    ContractSystem.refresh_offers(multi,9,true)
    for pair in [["perron","perron_zarya_route"],["rubezh","rubezh_police_route"],["mechanics","mechanics_rail_depot"],["lazaret","lazaret_hospital_route"]]:
        var offer = _offer(multi,str(pair[0]),str(pair[1]),9)
        check(not offer.is_empty(),str(pair[1]) + " missing from multi-faction sandbox fixture")
        var accepted = ContractSystem.accept(multi,str(offer.get("id","")),9)
        check(bool(accepted.get("ok",false)),str(pair[1]) + " was blocked by another faction's active job")
    check(multi.get("contracts",{}).get("active",{}).size() == 4,"sandbox cannot hold one active contract from each faction")

    print("SANDBOX ROUTES 1.23-dev14 regression: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
