extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionRelations = preload("res://world/faction_relations.gd")
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

func _offer(state:Dictionary,faction_id:String,template_id:String,day:int) -> Dictionary:
    for row in ContractSystem.offers_for_faction(state,faction_id,day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}

func run() -> void:
    var state = FactionEconomy.default_state()
    check(state.has("relations"),"relations must be stored in faction_state")
    check(state.has("world_influence"),"world influence must be stored in faction_state")
    for a in FactionCatalog.ids():
        for b in FactionCatalog.ids():
            if str(a) == str(b):
                continue
            check(FactionRelations.relation(state,str(a),str(b)) == 0,"new campaign faction relations must start neutral")

    check(str(FactionRelations.relation_tier(-60).get("id","")) == "hostile","hostile relation tier mismatch")
    check(str(FactionRelations.relation_tier(-20).get("id","")) == "tense","tense relation tier mismatch")
    check(str(FactionRelations.relation_tier(0).get("id","")) == "neutral","neutral relation tier mismatch")
    check(str(FactionRelations.relation_tier(30).get("id","")) == "cooperative","cooperative relation tier mismatch")
    check(str(FactionRelations.relation_tier(70).get("id","")) == "allied","allied relation tier mismatch")

    var adjusted = FactionRelations.adjust_relation(state,"perron","mechanics",22,2,"qa")
    check(adjusted == 22,"relation adjustment failed")
    check(FactionRelations.relation(state,"mechanics","perron") == 22,"relation must be symmetric")
    check(state["world_influence"].get("relation_history",[]).size() == 1,"relation history must persist")

    for template_id in ["perron_rail_allocation","mechanics_rail_allocation","rubezh_quarantine_policy","lazaret_quarantine_policy"]:
        var template = ContractCatalog.template(template_id)
        check(not template.is_empty(),template_id + " conflict contract missing")
        check(typeof(template.get("conflict",{})) == TYPE_DICTIONARY,template_id + " conflict metadata missing")
        check(str(template.get("conflict",{}).get("id","")) != "",template_id + " conflict id missing")
        check(int(template.get("min_rep",0)) >= 75,template_id + " must be a high-trust choice")

    # Two opposing offers can be visible before the player commits.
    var choice = FactionEconomy.default_state()
    FactionEconomy.add_reputation(choice,"perron",100)
    FactionEconomy.add_reputation(choice,"mechanics",100)
    choice["factions"]["perron"]["resources"]["food"] = 5.0
    choice["factions"]["mechanics"]["resources"]["technical"] = 5.0
    ContractSystem.ensure_state(choice,1)
    ContractSystem.refresh_offers(choice,1,true)
    var perron_offer = _offer(choice,"perron","perron_rail_allocation",1)
    var mechanics_offer = _offer(choice,"mechanics","mechanics_rail_allocation",1)
    check(not perron_offer.is_empty(),"Perron rail choice should be offered")
    check(not mechanics_offer.is_empty(),"Mechanics rail choice should be offered")
    check("КОНФЛИКТ ИНТЕРЕСОВ" in ContractSystem.consequence_text(choice,perron_offer),"choice warning must be explicit before acceptance")

    var perron_accept = ContractSystem.accept(choice,str(perron_offer.get("id","")),1)
    check(bool(perron_accept.get("ok",false)),"first side of conflict should be accepted")
    var blocked = ContractSystem.accept(choice,str(mechanics_offer.get("id","")),1)
    check(not bool(blocked.get("ok",false)),"opposing side must be blocked while first choice is active")
    check(ContractSystem.abandon(choice,str(perron_offer.get("id","")),1),"player must be able to reconsider before completion")
    check(FactionRelations.decision(choice,"rail_allocation").is_empty(),"abandoning must not resolve conflict")

    var mechanics_accept = ContractSystem.accept(choice,str(mechanics_offer.get("id","")),1)
    check(bool(mechanics_accept.get("ok",false)),"opposing choice should become available after abandon")
    var perron_rep_before = FactionEconomy.reputation(choice,"perron")
    var mechanics_rep_before = FactionEconomy.reputation(choice,"mechanics")
    var perron_food_before = float(choice["factions"]["perron"]["resources"]["food"])
    var mechanics_tech_before = float(choice["factions"]["mechanics"]["resources"]["technical"])
    var finished = ContractSystem.complete(choice,str(mechanics_offer.get("id","")),2)
    check(bool(finished.get("ok",false)),"conflict contract completion failed")
    var outcome = finished.get("conflict_outcome",{})
    check(not outcome.is_empty(),"completion must return faction consequence")
    check(str(outcome.get("winner","")) == "mechanics","wrong conflict winner")
    check(str(outcome.get("loser","")) == "perron","wrong conflict loser")
    check(FactionEconomy.reputation(choice,"mechanics") > mechanics_rep_before,"winner should receive normal contract reputation")
    check(FactionEconomy.reputation(choice,"perron") == perron_rep_before - 8,"opposed faction reputation penalty mismatch")
    check(FactionRelations.relation(choice,"perron","mechanics") == -18,"world relation consequence mismatch")
    check(float(choice["factions"]["mechanics"]["resources"]["technical"]) > mechanics_tech_before,"winner settlement should gain contested supply")
    check(float(choice["factions"]["perron"]["resources"]["food"]) < perron_food_before,"loser settlement should feel diverted supply")
    var decision = FactionRelations.decision(choice,"rail_allocation")
    check(str(decision.get("choice","")) == "industrial_priority","persistent world decision choice mismatch")
    check(int(decision.get("day",0)) == 2,"world decision day mismatch")

    ContractSystem.refresh_offers(choice,3,true)
    check(_offer(choice,"perron","perron_rail_allocation",3).is_empty(),"resolved Perron alternative must never return")
    check(_offer(choice,"mechanics","mechanics_rail_allocation",3).is_empty(),"resolved Mechanics alternative must never return")

    # Inter-faction relation now has an economic effect on shared supply routes.
    var cooperative = FactionEconomy.default_state()
    cooperative["factions"]["perron"]["resources"]["technical"] = 50.0
    cooperative["factions"]["mechanics"]["resources"]["technical"] = 50.0
    cooperative["world_routes"]["qa_shared"] = {"state":"open","beneficiaries":["perron","mechanics"],"daily_resources":{"technical":1.0}}
    FactionRelations.adjust_relation(cooperative,"perron","mechanics",40,1,"qa")
    var strained = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(cooperative)))
    FactionRelations.adjust_relation(strained,"perron","mechanics",-80,1,"qa") # +40 -> -40
    var coop_factor = FactionRelations.shared_route_factor(cooperative,["perron","mechanics"])
    var strained_factor = FactionRelations.shared_route_factor(strained,["perron","mechanics"])
    check(coop_factor > 1.0,"cooperative factions should improve shared-route efficiency")
    check(strained_factor < 1.0,"tense factions should reduce shared-route efficiency")
    FactionEconomy.daily_tick(cooperative)
    FactionEconomy.daily_tick(strained)
    check(float(cooperative["factions"]["perron"]["resources"]["technical"]) > float(strained["factions"]["perron"]["resources"]["technical"]),"relations must affect actual daily route supply")

    # New state survives the same JSON/save sanitization path as the rest of faction_state.
    var encoded = JSON.stringify(choice)
    var roundtrip = FactionEconomy.sanitize_state(JSON.parse_string(encoded))
    check(str(FactionRelations.decision(roundtrip,"rail_allocation").get("choice","")) == "industrial_priority","world decision lost across save roundtrip")
    check(FactionRelations.relation(roundtrip,"perron","mechanics") == -18,"relation value lost across save roundtrip")
    check(roundtrip["world_influence"].get("relation_history",[]).size() >= 1,"relation history lost across save roundtrip")

    print("FACTION RELATIONS 1.22-dev5: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
