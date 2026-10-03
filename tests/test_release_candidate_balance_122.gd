extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const SupplyEventSystem = preload("res://world/supply_event_system.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")
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

func _all_resources_in_bounds(state:Dictionary,min_value:float = 0.0) -> void:
    for faction_id in FactionCatalog.ids():
        for resource_id in FactionEconomy.RESOURCE_KEYS:
            var value = float(state["factions"][faction_id]["resources"].get(resource_id,-999.0))
            check(is_finite(value),"%s/%s resource became non-finite" % [faction_id,resource_id])
            check(value >= min_value - 0.001,"%s/%s resource fell below long-run floor: %.2f" % [faction_id,resource_id,value])
            check(value <= FactionEconomy.MAX_RESOURCE + 0.001,"%s/%s resource exceeded cap: %.2f" % [faction_id,resource_id,value])

func _simulate(days:int,rescue_incidents:bool) -> Dictionary:
    var state = FactionEconomy.default_state()
    for day in range(2,days + 1):
        FactionEconomy.daily_tick(state)
        SupplyEventSystem.daily_tick(state,day,[])
        if rescue_incidents:
            var event = SupplyEventSystem.active_event(state,day)
            if not event.is_empty():
                var result = SupplyEventSystem.resolve_success(state,str(event.get("id","")),day)
                check(bool(result.get("ok",false)),"rescue-mode incident failed to resolve on day %d" % day)
        TradingMarket.restock_all(state,day)
    return state

func _activate_all_endgame_and_routes(state:Dictionary) -> void:
    FactionEndgame.ensure_state(state)
    for faction_id in FactionEndgame.CHAINS.keys():
        var meta = FactionEndgame.CHAINS[faction_id]
        var row = state["faction_endgame"]["chains"][faction_id]
        row["progress"] = meta.get("templates",[]).size()
        row["completed"] = meta.get("templates",[]).duplicate()
        row["finalized"] = true
        row["final_day"] = 1
        state["faction_endgame"]["chains"][faction_id] = row
        state["faction_endgame"]["effects"][str(meta.get("effect",""))] = true
    for template in ContractCatalog.TEMPLATES.values():
        var route = template.get("reward",{}).get("route",{})
        if typeof(route) != TYPE_DICTIONARY or route.is_empty():
            continue
        var route_id = str(route.get("id",""))
        if route_id == "":
            continue
        var opened = route.duplicate(true)
        opened["state"] = "open"
        opened["opened_day"] = 1
        state["world_routes"][route_id] = opened

func run() -> void:
    # Long-run unattended world: settlements may be in shortage, but must not mathematically die at zero.
    var ignored = _simulate(180,false)
    _all_resources_in_bounds(ignored,10.0)
    var ignored_history = ignored.get("supply_events",{}).get("history",[])
    check(ignored_history.size() >= 15,"180-day unattended world produced implausibly few supply incidents")
    check(ignored_history.size() <= SupplyEventSystem.HISTORY_LIMIT,"supply-event history exceeded its persistence cap")
    check(int(ignored.get("currency_tickets",-1)) == 0,"unattended world must not mint player tickets")

    # A player who answers every SOS should materially stabilize each faction's profile resource,
    # but unrelated resources still require trade/contracts and cannot be auto-solved by caravan events.
    var rescued = _simulate(180,true)
    _all_resources_in_bounds(rescued,10.0)
    check(float(rescued["factions"]["perron"]["resources"]["food"]) >= 70.0,"repeated Perron rescues should protect food supply")
    check(float(rescued["factions"]["rubezh"]["resources"]["security"]) >= 70.0,"repeated Rubezh rescues should protect security")
    check(float(rescued["factions"]["mechanics"]["resources"]["technical"]) >= 70.0,"repeated Mechanics rescues should protect technical supply")
    check(float(rescued["factions"]["lazaret"]["resources"]["medicine"]) >= 70.0,"repeated Lazaret rescues should protect medicine")
    check(float(rescued["factions"]["perron"]["resources"]["medicine"]) < 40.0,"convoy rescues must not solve unrelated Perron medicine")
    check(int(rescued.get("currency_tickets",0)) > 0 and int(rescued.get("currency_tickets",0)) < 2500,"180-day SOS reward flow is outside RC envelope")

    # Fully developed infrastructure can become healthy, but all resource math must remain capped.
    var developed = FactionEconomy.default_state()
    _activate_all_endgame_and_routes(developed)
    for day in range(2,366):
        FactionEconomy.daily_tick(developed)
    _all_resources_in_bounds(developed,10.0)

    # Price/spread sweep across reputation and crisis levels. Same-market buy/sell can never invert.
    var resource_levels = [0.0,12.0,25.0,45.0,70.0,100.0]
    var rep_levels = [-100,0,25,75,150,250]
    for trader_id in TraderCatalog.ids():
        var trader = TraderCatalog.trader(str(trader_id))
        var faction_id = str(trader.get("faction",""))
        for resource_value in resource_levels:
            for rep in rep_levels:
                var state = FactionEconomy.default_state()
                state["factions"][faction_id]["reputation"] = rep
                for resource_id in FactionEconomy.RESOURCE_KEYS:
                    state["factions"][faction_id]["resources"][resource_id] = resource_value
                for spec in trader.get("stock",[]):
                    var item_id = str(spec.get("id",""))
                    var buy = TradingMarket.buy_price(state,str(trader_id),item_id)
                    var sell = TradingMarket.sell_price(state,str(trader_id),item_id)
                    check(buy >= 1,"%s/%s buy price became non-positive" % [trader_id,item_id])
                    check(sell >= 1,"%s/%s sell price became non-positive" % [trader_id,item_id])
                    check(sell <= int(floor(buy * 0.80)),"%s/%s same-market spread inverted at rep=%d resource=%.0f" % [trader_id,item_id,rep,resource_value])

    # Exact transaction validation: stale/tampered totals are rejected rather than trusted.
    var tx = FactionEconomy.default_state()
    FactionEconomy.add_tickets(tx,1000)
    var q = TradingMarket.buy_quote(tx,"perron_general","water",1)
    check(bool(q.get("ok",false)),"RC purchase quote missing")
    check(not TradingMarket.apply_purchase(tx,"perron_general","water",1,max(0,int(q.get("total",0)) - 1)),"underpriced purchase was accepted")
    check(not TradingMarket.apply_purchase(tx,"perron_general","water",0,int(q.get("total",0))),"zero-quantity purchase was accepted")

    # Buying local stock consumes abstract supply; returning the same unit restores it exactly.
    var cycle = FactionEconomy.default_state()
    FactionEconomy.add_tickets(cycle,1000)
    var food_before = float(cycle["factions"]["perron"]["resources"]["food"])
    var tickets_before = int(cycle.get("currency_tickets",0))
    var buy_q = TradingMarket.buy_quote(cycle,"perron_general","water",1)
    check(TradingMarket.apply_purchase(cycle,"perron_general","water",1,int(buy_q.get("total",0))),"valid RC purchase failed")
    var food_after_buy = float(cycle["factions"]["perron"]["resources"]["food"])
    check(food_after_buy < food_before,"buying finite settlement stock must consume matching abstract supply")
    var sell_q = TradingMarket.sell_quote(cycle,"perron_general","water",1)
    check(TradingMarket.apply_sale(cycle,"perron_general","water",1,int(sell_q.get("total",0))),"valid RC sale failed")
    var food_after_roundtrip = float(cycle["factions"]["perron"]["resources"]["food"])
    check(abs(food_after_roundtrip - food_before) < 0.001,"buy/sell roundtrip inflated settlement resources")
    check(int(cycle.get("currency_tickets",0)) < tickets_before,"buy/sell roundtrip must cost tickets rather than mint them")
    check(not TradingMarket.apply_sale(cycle,"perron_general","water",1,int(sell_q.get("total",0)) + 1),"tampered sale total was accepted")

    var barter_state = FactionEconomy.default_state()
    FactionEconomy.add_tickets(barter_state,500)
    var barter = TradingMarket.barter_quote(barter_state,"perron_general","water",1,"canned_meat",1)
    check(bool(barter.get("ok",false)),"RC barter quote missing")
    check(not TradingMarket.apply_barter(barter_state,"perron_general","water",1,"canned_meat",1,int(barter.get("ticket_delta",0)) + 1),"tampered barter delta was accepted")
    check(not TradingMarket.apply_barter(barter_state,"perron_general","water",1,"water",1,0),"same-item barter was accepted by economy API")

    check(str(ProjectSettings.get_setting("application/config/version","")) == "1.22.0","project version must be 1.22.0 Stable")
    print("RELEASE CANDIDATE BALANCE 1.22-dev9: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
