extends SceneTree
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionRelations = preload("res://world/faction_relations.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const ContractSystem = preload("res://world/contract_system.gd")
const TradingMarket = preload("res://world/trading_market.gd")

var checks := 0
var failures := 0

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

func _stable(state:Dictionary,faction_id:String,value:float = 80.0) -> void:
    for key in FactionEconomy.RESOURCE_KEYS:
        state["factions"][faction_id]["resources"][key] = value

func _complete_offer(state:Dictionary,faction_id:String,template_id:String,day:int) -> Dictionary:
    ContractSystem.refresh_offers(state,day,true)
    var offer = _offer(state,faction_id,template_id,day)
    if offer.is_empty():
        return {"ok":false,"reason":"offer missing"}
    var accepted = ContractSystem.accept(state,str(offer.get("id","")),day)
    if not bool(accepted.get("ok",false)):
        return accepted
    return ContractSystem.complete(state,str(offer.get("id","")),day)

func run() -> void:
    var expected = {
        "perron":["perron_endgame_common_warehouse","perron_endgame_motor_pool","perron_endgame_civilian_exchange"],
        "rubezh":["rubezh_endgame_bastion","rubezh_endgame_perimeter_supply","rubezh_endgame_patrol_grid"],
        "mechanics":["mechanics_endgame_sever","mechanics_endgame_vector","mechanics_endgame_repair_network"],
        "lazaret":["lazaret_endgame_clinical_complex","lazaret_endgame_sterile_reserve","lazaret_endgame_medical_network"]
    }
    for faction_id in expected.keys():
        var chain = FactionEndgame.chain(str(faction_id))
        check(not chain.is_empty(),str(faction_id) + " endgame chain missing")
        check(chain.get("templates",[]) == expected[faction_id],str(faction_id) + " chain order mismatch")
        for i in range(expected[faction_id].size()):
            var template_id = str(expected[faction_id][i])
            var template = ContractCatalog.template(template_id)
            check(not template.is_empty(),template_id + " template missing")
            check(int(template.get("min_rep",0)) >= 150,template_id + " must require trusted reputation")
            check(int(template.get("endgame",{}).get("step",0)) == i + 1,template_id + " step metadata mismatch")

    var state = FactionEconomy.default_state()
    check(state.has("faction_endgame"),"endgame state must exist in canonical faction state")
    _stable(state,"perron")
    ContractSystem.refresh_offers(state,1,true)
    check(_offer(state,"perron","perron_endgame_common_warehouse",1).is_empty(),"endgame chain must not appear below trusted reputation")

    FactionEconomy.add_reputation(state,"perron",200)
    ContractSystem.refresh_offers(state,2,true)
    check(not _offer(state,"perron","perron_endgame_common_warehouse",2).is_empty(),"Perron step 1 should appear for trusted player")
    check(_offer(state,"perron","perron_endgame_motor_pool",2).is_empty(),"step 2 must not appear before step 1")

    # A real crisis blocks strategic work and exposes the emergency delivery instead.
    var crisis = FactionEconomy.default_state()
    FactionEconomy.add_reputation(crisis,"perron",200)
    _stable(crisis,"perron")
    crisis["factions"]["perron"]["resources"]["food"] = 10.0
    ContractSystem.refresh_offers(crisis,2,true)
    check(_offer(crisis,"perron","perron_endgame_common_warehouse",2).is_empty(),"food crisis must block Perron strategic step")
    check(not _offer(crisis,"perron","crisis_perron_food",2).is_empty(),"food crisis must surface emergency contract")

    # Complete a whole chain through the production contract lifecycle.
    var step1 = _complete_offer(state,"perron","perron_endgame_common_warehouse",3)
    check(bool(step1.get("ok",false)),"Perron endgame step 1 completion failed")
    check(FactionEndgame.progress(state,"perron") == 1,"Perron progress must advance to 1")
    ContractSystem.refresh_offers(state,4,true)
    check(not _offer(state,"perron","perron_endgame_motor_pool",4).is_empty(),"Perron step 2 should unlock after step 1")
    var step2 = _complete_offer(state,"perron","perron_endgame_motor_pool",4)
    check(bool(step2.get("ok",false)),"Perron endgame step 2 completion failed")
    check(FactionEndgame.progress(state,"perron") == 2,"Perron progress must advance to 2")

    # Keep the final gate healthy, then compare market behavior before/after finalization.
    _stable(state,"perron",80.0)
    var before_final = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(state)))
    var buy_before = TradingMarket.buy_price(before_final,"perron_canteen","canned_meat")
    var sell_before = TradingMarket.sell_price(before_final,"perron_canteen","canned_meat")
    var relation_lazaret_before = FactionRelations.relation(state,"perron","lazaret")
    var relation_rubezh_before = FactionRelations.relation(state,"perron","rubezh")
    var final_result = _complete_offer(state,"perron","perron_endgame_civilian_exchange",5)
    check(bool(final_result.get("ok",false)),"Perron final completion failed")
    check(bool(final_result.get("endgame_outcome",{}).get("final",false)),"final contract must return final endgame outcome")
    check(FactionEndgame.is_finalized(state,"perron"),"Perron chain must become finalized")
    check(FactionEndgame.effect_active(state,"perron_exchange"),"Perron permanent effect missing")
    check(FactionRelations.relation(state,"perron","lazaret") == relation_lazaret_before + 12,"Perron final must improve Lazaret relations")
    check(FactionRelations.relation(state,"perron","rubezh") == relation_rubezh_before - 6,"Perron final must worsen Rubezh relations")
    check(TradingMarket.buy_price(state,"perron_canteen","canned_meat") <= buy_before,"final market infrastructure must not make focus goods more expensive")
    check(TradingMarket.sell_price(state,"perron_canteen","canned_meat") >= sell_before,"final market infrastructure must not reduce specialist purchase price")
    check("ФИНАЛ ЦЕПОЧКИ" in ContractSystem.consequence_text(before_final,ContractCatalog.template("perron_endgame_civilian_exchange")),"final warning must state irreversibility")

    # Permanent effect survives daily simulation and gives real resource support.
    var with_effect = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(state)))
    var without_effect = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(state)))
    without_effect["faction_endgame"] = FactionEndgame.default_state()
    _stable(with_effect,"perron",60.0)
    _stable(without_effect,"perron",60.0)
    FactionEconomy.daily_tick(with_effect)
    FactionEconomy.daily_tick(without_effect)
    check(float(with_effect["factions"]["perron"]["resources"]["food"]) > float(without_effect["factions"]["perron"]["resources"]["food"]),"Perron final must produce persistent daily food support")

    # Endgame reserve produces more specialist stock on the next restock.
    with_effect["traders"]["perron_canteen"]["stock"]["emergency_ration"] = 0
    without_effect["traders"]["perron_canteen"]["stock"]["emergency_ration"] = 0
    TradingMarket.restock(with_effect,"perron_canteen",8,true)
    TradingMarket.restock(without_effect,"perron_canteen",8,true)
    check(TradingMarket.stock(with_effect,"perron_canteen","emergency_ration") > TradingMarket.stock(without_effect,"perron_canteen","emergency_ration"),"Perron final reserve must improve rare ration restock")

    ContractSystem.refresh_offers(state,10,true)
    check(_offer(state,"perron","perron_endgame_common_warehouse",10).is_empty(),"completed endgame chain must never restart")
    check(_offer(state,"perron","perron_endgame_civilian_exchange",10).is_empty(),"final contract must never return")

    # All four final effects can be reached in-order and have distinct permanent identities.
    for faction_id in ["rubezh","mechanics","lazaret"]:
        var s = FactionEconomy.default_state()
        FactionEconomy.add_reputation(s,faction_id,220)
        _stable(s,faction_id,90.0)
        var templates:Array = expected[faction_id]
        for i in range(templates.size()):
            var template = ContractCatalog.template(str(templates[i]))
            var outcome = FactionEndgame.apply_contract_outcome(s,template,i + 1)
            check(not outcome.is_empty(),"direct ordered endgame progression failed for " + faction_id)
        check(FactionEndgame.is_finalized(s,faction_id),faction_id + " finalization missing")
        check(FactionEndgame.faction_effect_active(s,faction_id),faction_id + " permanent effect missing")

    # Save/sanitize roundtrip preserves progression, history and active effects.
    var roundtrip = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(state)))
    check(FactionEndgame.is_finalized(roundtrip,"perron"),"endgame finalization lost across save roundtrip")
    check(FactionEndgame.effect_active(roundtrip,"perron_exchange"),"endgame effect lost across save roundtrip")
    check(roundtrip.get("faction_endgame",{}).get("history",[]).size() >= 3,"endgame history lost across save roundtrip")
    check(str(ProjectSettings.get_setting("application/config/version","")) == "1.22.0","project version must be 1.22.0 Stable")

    print("FACTION ENDGAME 1.22-dev8: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
