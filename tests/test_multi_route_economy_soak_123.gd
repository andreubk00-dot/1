extends SceneTree

const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const FactionRelations = preload("res://world/faction_relations.gd")
const SettlementProjects = preload("res://world/settlement_projects.gd")
const SettlementCrisis = preload("res://world/settlement_crisis.gd")
const SupplyEventSystem = preload("res://world/supply_event_system.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const ContractSystem = preload("res://world/contract_system.gd")
const TradingMarket = preload("res://world/trading_market.gd")

const HORIZONS = [30,60,180,365]
const PROFILE = {
    "perron":{"resource":"food","trader":"perron_canteen","item":"grain"},
    "rubezh":{"resource":"security","trader":"rubezh_armorer","item":"ammo_9x18"},
    "mechanics":{"resource":"technical","trader":"mechanics_parts","item":"scrap"},
    "lazaret":{"resource":"medicine","trader":"lazaret_supplier","item":"bandage"}
}

var checks := 0
var failures := 0

func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)

func _initialize() -> void:
    call_deferred("run")

func _open_route_from_template(state:Dictionary,template_id:String,opened_day:int = 1) -> void:
    var route = ContractCatalog.template(template_id).get("reward",{}).get("route",{}).duplicate(true)
    if route.is_empty():
        return
    route["state"] = "open"
    route["opened_day"] = opened_day
    route["source_contract"] = template_id
    state["world_routes"][str(route.get("id",""))] = route

func _open_all_routes(state:Dictionary) -> void:
    for template_id in ["perron_zarya_route","lazaret_hospital_route","rubezh_police_route","mechanics_rail_depot"]:
        _open_route_from_template(state,template_id)

func _open_final_endgame_routes(state:Dictionary) -> void:
    # Real chain completion also opens the final contract route. Keep this stronger scenario
    # separate from the requested "starter routes + endgame effects" case so both are covered.
    for faction_id in FactionCatalog.ids():
        var templates = FactionEndgame.chain(str(faction_id)).get("templates",[])
        if templates.is_empty():
            continue
        _open_route_from_template(state,str(templates[templates.size() - 1]))

func _activate_projects(state:Dictionary) -> void:
    SettlementProjects.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var spec = SettlementProjects.project(str(faction_id))
        var rec = SettlementProjects.default_record()
        rec["strategic_installed"] = true
        rec["installed_day"] = 1
        rec["resources"] = spec.get("resource_targets",{}).duplicate(true)
        rec["completed"] = true
        rec["completed_day"] = 1
        state["settlement_projects"]["records"][str(faction_id)] = rec
    SettlementProjects.ensure_state(state)

func _activate_endgame(state:Dictionary) -> void:
    FactionEndgame.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var spec = FactionEndgame.chain(str(faction_id))
        var templates = spec.get("templates",[])
        state["faction_endgame"]["chains"][str(faction_id)] = {
            "progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":1
        }
        state["faction_endgame"]["effects"][str(spec.get("effect",""))] = true
    FactionEndgame.ensure_state(state)
    # Final chain outcomes also change inter-faction relations. Those relations feed back into
    # shared-route efficiency, so reproduce them in soak instead of testing effect flags alone.
    for faction_id in FactionCatalog.ids():
        var fid = str(faction_id)
        var effect = FactionEndgame.effect_for_faction(state,fid)
        var relations = effect.get("relations",{})
        if typeof(relations) == TYPE_DICTIONARY:
            for other_id in relations.keys():
                FactionRelations.adjust_relation(state,fid,str(other_id),int(relations[other_id]),1,"dev16_soak_endgame")

func _state(projects:bool,endgame:bool,final_endgame_routes:bool = false) -> Dictionary:
    var state = FactionEconomy.default_state()
    _open_all_routes(state)
    if projects:
        _activate_projects(state)
    if endgame:
        _activate_endgame(state)
    if final_endgame_routes:
        _open_final_endgame_routes(state)
    for faction_id in FactionCatalog.ids():
        state["factions"][str(faction_id)]["reputation"] = 250
    state["currency_tickets"] = 200000
    return state

func _resource_rows(state:Dictionary) -> Dictionary:
    var out = {}
    for faction_id in FactionCatalog.ids():
        out[str(faction_id)] = state["factions"][str(faction_id)]["resources"].duplicate(true)
    return out

func _market_rows(state:Dictionary) -> Dictionary:
    var out = {}
    for faction_id in PROFILE.keys():
        var row:Dictionary = PROFILE[faction_id]
        var trader_id = str(row["trader"])
        var item_id = str(row["item"])
        out[str(faction_id)] = {
            "stock":TradingMarket.stock(state,trader_id,item_id),
            "buy":TradingMarket.buy_price(state,trader_id,item_id),
            "sell":TradingMarket.sell_price(state,trader_id,item_id)
        }
    return out

func _run_idle(label:String,projects:bool,endgame:bool,final_endgame_routes:bool = false) -> Dictionary:
    var state = _state(projects,endgame,final_endgame_routes)
    var days_at_100 = {}
    var crisis_days = {}
    var profile_stock_peak = {}
    var profile_stock_zero_days = {}
    var price_range = {}
    for faction_id in FactionCatalog.ids():
        days_at_100[str(faction_id)] = {"food":0,"medicine":0,"technical":0,"security":0}
        crisis_days[str(faction_id)] = 0
    for faction_id in PROFILE.keys():
        profile_stock_peak[str(faction_id)] = 0
        profile_stock_zero_days[str(faction_id)] = 0
        price_range[str(faction_id)] = {"min":999999,"max":0}
    var snapshots = {}
    for day in range(1,366):
        FactionEconomy.daily_tick(state)
        TradingMarket.restock_all(state,day)
        for faction_id in FactionCatalog.ids():
            var fid = str(faction_id)
            var resources = state["factions"][fid]["resources"]
            for resource_id in FactionEconomy.RESOURCE_KEYS:
                var value = float(resources[str(resource_id)])
                check(value >= -0.001 and value <= 100.001,label + " resource escaped 0..100")
                if value >= 99.999:
                    days_at_100[fid][str(resource_id)] += 1
            if SettlementCrisis.stage_rank(str(SettlementCrisis.faction_status(state,fid).get("stage","stable"))) >= SettlementCrisis.stage_rank("shortage"):
                crisis_days[fid] += 1
        for faction_id in PROFILE.keys():
            var row:Dictionary = PROFILE[faction_id]
            var trader_id = str(row["trader"])
            var item_id = str(row["item"])
            var stock = TradingMarket.stock(state,trader_id,item_id)
            var price = TradingMarket.buy_price(state,trader_id,item_id)
            profile_stock_peak[str(faction_id)] = max(int(profile_stock_peak[str(faction_id)]),stock)
            if stock <= 0:
                profile_stock_zero_days[str(faction_id)] += 1
            price_range[str(faction_id)]["min"] = min(int(price_range[str(faction_id)]["min"]),price)
            price_range[str(faction_id)]["max"] = max(int(price_range[str(faction_id)]["max"]),price)
        if day in HORIZONS:
            snapshots[day] = {"resources":_resource_rows(state),"market":_market_rows(state)}
    for faction_id in FactionCatalog.ids():
        var fid = str(faction_id)
        for resource_id in FactionEconomy.RESOURCE_KEYS:
            check(int(days_at_100[fid][str(resource_id)]) == 0,label + " " + fid + "/" + str(resource_id) + " still passively sits at 100")
    for faction_id in PROFILE.keys():
        check(int(profile_stock_peak[str(faction_id)]) < 100,label + " " + str(faction_id) + " profile stock grew without a finite bound")
        check(int(price_range[str(faction_id)]["min"]) >= 1 and int(price_range[str(faction_id)]["max"]) < 1000,label + " " + str(faction_id) + " prices escaped sane bounds")
    print("SOAK ",label," resources=",_resource_rows(state)," market=",_market_rows(state)," days_at_100=",days_at_100," crisis_days=",crisis_days," stock_peak=",profile_stock_peak," stock_zero_days=",profile_stock_zero_days," price_range=",price_range)
    return {
        "state":state,"snapshots":snapshots,"days_at_100":days_at_100,"crisis_days":crisis_days,
        "stock_peak":profile_stock_peak,"stock_zero_days":profile_stock_zero_days,"price_range":price_range
    }

func _run_failures() -> Dictionary:
    var state = _state(true,true,true)
    var crisis_days = {}
    for faction_id in FactionCatalog.ids():
        crisis_days[str(faction_id)] = 0
    for day in range(1,366):
        FactionEconomy.daily_tick(state)
        SupplyEventSystem.daily_tick(state,day)
        TradingMarket.restock_all(state,day)
        for faction_id in FactionCatalog.ids():
            var fid = str(faction_id)
            if SettlementCrisis.stage_rank(str(SettlementCrisis.faction_status(state,fid).get("stage","stable"))) >= SettlementCrisis.stage_rank("shortage"):
                crisis_days[fid] += 1
    var lost = 0
    for row in state.get("supply_events",{}).get("history",[]):
        if str(row.get("outcome","")) == "lost":
            lost += 1
    var total_crisis_days = 0
    for faction_id in crisis_days.keys():
        total_crisis_days += int(crisis_days[faction_id])
    check(lost > 0,"365-day failure soak produced no expired supply events")
    check(total_crisis_days > 0,"supply failures never produced a shortage/crisis day")
    print("SOAK failures lost_events=",lost," crisis_days=",crisis_days," resources=",_resource_rows(state)," market=",_market_rows(state))
    return state

func _offer_with_template(state:Dictionary,faction_id:String,template_id:String,day:int) -> Dictionary:
    for row in ContractSystem.offers_for_faction(state,faction_id,day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}

func _run_failure_recovery_guards() -> void:
    # A lost shipment remains a real negative shock, and recovering the next one stays outside
    # the passive ceiling. Use an explicit event to keep the test deterministic.
    var supply = _state(true,true,true)
    SupplyEventSystem.ensure_state(supply,1)
    supply["factions"]["mechanics"]["resources"]["technical"] = 30.0
    supply["factions"]["mechanics"]["resources"]["security"] = 30.0
    supply["supply_events"]["active"] = {
        "id":"dev16_loss","faction":"mechanics","coord":[5,5],"created_day":1,"expires_day":4,
        "stage":"distress","cargo_resource":"technical","cargo_label":"детали и инструмент","loot_profile":"industrial","severity":3
    }
    var before_loss = float(supply["factions"]["mechanics"]["resources"]["technical"])
    var expired = SupplyEventSystem.daily_tick(supply,4,[])
    var after_loss = float(supply["factions"]["mechanics"]["resources"]["technical"])
    check(bool(expired.get("expired",false)),"deterministic supply failure did not expire")
    check(after_loss < before_loss,"supply failure no longer damages faction resource")
    supply["supply_events"]["active"] = {
        "id":"dev16_recovery","faction":"mechanics","coord":[5,5],"created_day":5,"expires_day":8,
        "stage":"distress","cargo_resource":"technical","cargo_label":"детали и инструмент","loot_profile":"industrial","severity":3
    }
    var recovered = SupplyEventSystem.resolve_success(supply,"dev16_recovery",5)
    var after_recovery = float(supply["factions"]["mechanics"]["resources"]["technical"])
    check(bool(recovered.get("ok",false)),"supply recovery after a loss failed")
    check(after_recovery > after_loss + 15.9,"supply recovery was diminished by the passive logistics guardrail")

    # Crisis contract recovery is also direct gameplay recovery, not passive logistics.
    var crisis = _state(true,true,true)
    crisis["factions"]["mechanics"]["resources"]["technical"] = 14.0
    crisis["factions"]["mechanics"]["resources"]["food"] = 90.0
    crisis["factions"]["mechanics"]["resources"]["medicine"] = 90.0
    crisis["factions"]["mechanics"]["resources"]["security"] = 90.0
    ContractSystem.ensure_state(crisis,10)
    ContractSystem.refresh_offers(crisis,10,true)
    var offer = _offer_with_template(crisis,"mechanics","crisis_mechanics_technical",10)
    check(not offer.is_empty(),"technical crisis no longer produces its recovery contract")
    if not offer.is_empty():
        var accepted = ContractSystem.accept(crisis,str(offer.get("id","")),10)
        check(bool(accepted.get("ok",false)),"technical crisis recovery contract cannot be accepted")
        if bool(accepted.get("ok",false)):
            var active = ContractSystem.active_for_faction(crisis,"mechanics")
            check(active.size() == 1,"accepted crisis recovery contract missing from active state")
            if active.size() == 1:
                var before_contract = float(crisis["factions"]["mechanics"]["resources"]["technical"])
                var completed = ContractSystem.complete(crisis,str(active[0].get("id","")),10)
                var after_contract = float(crisis["factions"]["mechanics"]["resources"]["technical"])
                check(bool(completed.get("ok",false)),"crisis recovery contract completion failed")
                check(abs((after_contract - before_contract) - 18.0) < 0.001,"crisis recovery reward was diminished by passive logistics guardrail")

func _run_active_buying() -> Dictionary:
    var state = _state(true,true,true)
    var purchases = 0
    var price_min = 999999
    var price_max = 0
    var stock_peak = {}
    var stock_zero_days = {}
    for faction_id in PROFILE.keys():
        stock_peak[str(faction_id)] = 0
        stock_zero_days[str(faction_id)] = 0
    for day in range(1,366):
        FactionEconomy.daily_tick(state)
        TradingMarket.restock_all(state,day)
        for faction_id in PROFILE.keys():
            var row:Dictionary = PROFILE[faction_id]
            var trader_id = str(row["trader"])
            var item_id = str(row["item"])
            var available = TradingMarket.stock(state,trader_id,item_id)
            stock_peak[str(faction_id)] = max(int(stock_peak[str(faction_id)]),available)
            if available <= 0:
                stock_zero_days[str(faction_id)] += 1
                continue
            var qty = min(2,available)
            var price = TradingMarket.buy_price(state,trader_id,item_id)
            price_min = min(price_min,price)
            price_max = max(price_max,price)
            var quote = TradingMarket.buy_quote(state,trader_id,item_id,qty)
            if bool(quote.get("ok",false)) and TradingMarket.apply_purchase(state,trader_id,item_id,qty,int(quote.get("total",0))):
                purchases += qty
    check(purchases > 500,"active-buying soak did not exercise enough real trader purchases")
    check(price_min >= 1 and price_max < 1000,"active-buying prices escaped sane integer range")
    for faction_id in PROFILE.keys():
        var row:Dictionary = PROFILE[faction_id]
        check(TradingMarket.stock(state,str(row["trader"]),str(row["item"])) < 100,"profile trader stock accumulated without bound under active buying")
    print("SOAK active_buying purchases=",purchases," price_range=",price_min,"..",price_max," stock_peak=",stock_peak," stock_zero_days=",stock_zero_days," resources=",_resource_rows(state)," market=",_market_rows(state))
    return state

func run() -> void:
    var routes_only = _run_idle("routes_only",false,false)
    var routes_projects = _run_idle("routes_projects",true,false)
    var routes_endgame = _run_idle("routes_endgame",false,true)
    var full = _run_idle("routes_projects_endgame",true,true)
    var fully_realized = _run_idle("routes_projects_endgame_final_routes",true,true,true)

    # Every requested horizon is captured for all four required passive configurations plus
    # the stronger real-completion case where the final endgame contracts opened their routes.
    for result in [routes_only,routes_projects,routes_endgame,full,fully_realized]:
        for horizon in HORIZONS:
            check(result["snapshots"].has(horizon),"missing requested soak horizon " + str(horizon))
            check(result["snapshots"][horizon].has("resources"),"horizon lacks resource metrics")
            check(result["snapshots"][horizon].has("market"),"horizon lacks trader stock/price metrics")

    for route_id in ["route_perron_civilian_exchange","route_rubezh_patrol_grid","route_mechanics_repair_network","route_lazaret_medical_network"]:
        check(fully_realized["state"]["world_routes"].has(route_id),"realized endgame soak omitted authored final route " + route_id)

    # Development still has a visible benefit, but not infinite top-off.
    check(float(full["state"]["factions"]["mechanics"]["resources"]["technical"]) > float(routes_only["state"]["factions"]["mechanics"]["resources"]["technical"]),"projects/endgame no longer improve Mechanics long-run technical reserve")
    check(float(full["state"]["factions"]["lazaret"]["resources"]["medicine"]) > float(routes_only["state"]["factions"]["lazaret"]["resources"]["medicine"]),"projects/endgame no longer improve Lazaret long-run medical reserve")
    check(float(full["state"]["factions"]["mechanics"]["resources"]["technical"]) <= FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING + 0.001,"full sandbox Mechanics exceeds passive ceiling")
    check(float(full["state"]["factions"]["lazaret"]["resources"]["medicine"]) <= FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING + 0.001,"full sandbox Lazaret exceeds passive ceiling")
    check(float(fully_realized["state"]["factions"]["mechanics"]["resources"]["technical"]) <= FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING + 0.001,"real endgame route stack exceeds passive ceiling")

    # Deficit must remain meaningful: a fully developed sandbox still has at least one non-stable
    # resource per faction after a year of pure waiting, while each faction's authored specialty
    # stays stronger than at least one of its non-profile reserves.
    for faction_id in FactionCatalog.ids():
        var fid = str(faction_id)
        var resources = fully_realized["state"]["factions"][fid]["resources"]
        var has_nonstable = false
        for resource_id in FactionEconomy.RESOURCE_KEYS:
            if float(resources[str(resource_id)]) < SettlementCrisis.STABLE_MIN:
                has_nonstable = true
        check(has_nonstable,fid + " lost all deficit pressure after 365 idle days")
        var profile_resource = str(PROFILE[fid]["resource"])
        var weaker_nonprofile = false
        for resource_id in FactionEconomy.RESOURCE_KEYS:
            if str(resource_id) != profile_resource and float(resources[str(resource_id)]) < float(resources[profile_resource]):
                weaker_nonprofile = true
        check(weaker_nonprofile,fid + " no longer shows a meaningful settlement specialization")

    _run_failures()
    _run_failure_recovery_guards()
    var bought = _run_active_buying()
    check(float(bought["factions"]["mechanics"]["resources"]["technical"]) < float(fully_realized["state"]["factions"]["mechanics"]["resources"]["technical"]),"real purchases do not consume Mechanics profile resource")
    check(float(bought["factions"]["lazaret"]["resources"]["medicine"]) < float(fully_realized["state"]["factions"]["lazaret"]["resources"]["medicine"]),"real purchases do not consume Lazaret profile resource")

    # Old dev15 state remains schema-derived: routes survive a JSON/sanitize migration and receive
    # the new runtime rule only on future ticks. No free dev15 route-opening stock is fabricated.
    var old = _state(false,false)
    old["factions"]["rubezh"]["resources"]["security"] = 100.0
    var migrated = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(old)))
    check(abs(float(migrated["factions"]["rubezh"]["resources"]["security"]) - 100.0) < 0.001,"dev15 migration rewrote saved resource values eagerly")
    check(not bool(migrated["world_routes"]["route_rubezh_police"].get("opening_stock_applied",false)),"dev15 migration fabricated one-shot route opening stock")
    FactionEconomy.daily_tick(migrated)
    check(float(migrated["factions"]["rubezh"]["resources"]["security"]) < 100.0,"migrated dev15 state did not receive dev16 runtime anti-saturation behavior")

    print("MULTI-ROUTE ECONOMY SOAK 1.23-dev16: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
