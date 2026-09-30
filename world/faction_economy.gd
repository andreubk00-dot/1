extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")

const RESOURCE_KEYS = ["food","medicine","technical","security"]
const DEFAULT_RESOURCE = 55.0
const MAX_RESOURCE = 100.0

static func default_state() -> Dictionary:
    var factions = {}
    for faction_id in FactionCatalog.ids():
        var bias = FactionCatalog.faction(faction_id).get("resource_bias",{})
        var resources = {}
        for key in RESOURCE_KEYS:
            resources[key] = clamp(DEFAULT_RESOURCE * float(bias.get(key,1.0)),15.0,MAX_RESOURCE)
        factions[faction_id] = {
            "reputation":0,
            "resources":resources,
            "last_supply_day":1,
            "market_pressure":{},
            "completed_contracts":0
        }
    return {
        "currency_tickets":0,
        "factions":factions,
        "traders":TraderCatalog.default_trader_states(1),
        "world_routes":{},
        "contract_history":[],
        "contracts":{"offers":{},"active":{},"last_refresh_day":{},"serial":0}
    }

static func sanitize_state(raw) -> Dictionary:
    var state = default_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return state
    state["currency_tickets"] = max(0,int(raw.get("currency_tickets",0)))
    var incoming = raw.get("factions",{})
    if typeof(incoming) == TYPE_DICTIONARY:
        for faction_id in FactionCatalog.ids():
            var src = incoming.get(faction_id,{})
            if typeof(src) != TYPE_DICTIONARY:
                continue
            var dst = state["factions"][faction_id]
            dst["reputation"] = clamp(int(src.get("reputation",0)),-100,250)
            dst["last_supply_day"] = max(1,int(src.get("last_supply_day",1)))
            dst["completed_contracts"] = max(0,int(src.get("completed_contracts",0)))
            var src_resources = src.get("resources",{})
            if typeof(src_resources) == TYPE_DICTIONARY:
                for key in RESOURCE_KEYS:
                    dst["resources"][key] = clamp(float(src_resources.get(key,dst["resources"][key])),0.0,MAX_RESOURCE)
            var pressure = src.get("market_pressure",{})
            dst["market_pressure"] = pressure.duplicate(true) if typeof(pressure) == TYPE_DICTIONARY else {}
            state["factions"][faction_id] = dst
    state["traders"] = TraderCatalog.sanitize_trader_states(raw.get("traders",{}),1)
    var routes = raw.get("world_routes",{})
    state["world_routes"] = routes.duplicate(true) if typeof(routes) == TYPE_DICTIONARY else {}
    var history = raw.get("contract_history",[])
    state["contract_history"] = history.duplicate(true) if typeof(history) == TYPE_ARRAY else []
    var contracts = raw.get("contracts",{})
    state["contracts"] = contracts.duplicate(true) if typeof(contracts) == TYPE_DICTIONARY else {"offers":{},"active":{},"last_refresh_day":{},"serial":0}
    return state

static func reputation(state:Dictionary,faction_id:String) -> int:
    return int(state.get("factions",{}).get(faction_id,{}).get("reputation",0))

static func reputation_tier(state:Dictionary,faction_id:String) -> Dictionary:
    return FactionCatalog.reputation_tier(reputation(state,faction_id))

static func add_reputation(state:Dictionary,faction_id:String,amount:int) -> int:
    if not state.get("factions",{}).has(faction_id):
        return 0
    var record = state["factions"][faction_id]
    record["reputation"] = clamp(int(record.get("reputation",0)) + amount,-100,250)
    state["factions"][faction_id] = record
    return int(record["reputation"])

static func add_tickets(state:Dictionary,amount:int) -> int:
    state["currency_tickets"] = max(0,int(state.get("currency_tickets",0)) + amount)
    return int(state["currency_tickets"])

static func adjust_resource(state:Dictionary,faction_id:String,resource_id:String,amount:float) -> float:
    if resource_id not in RESOURCE_KEYS or not state.get("factions",{}).has(faction_id):
        return 0.0
    var record = state["factions"][faction_id]
    var resources = record.get("resources",{})
    resources[resource_id] = clamp(float(resources.get(resource_id,DEFAULT_RESOURCE)) + amount,0.0,MAX_RESOURCE)
    record["resources"] = resources
    state["factions"][faction_id] = record
    return float(resources[resource_id])

static func settlement_condition(state:Dictionary,faction_id:String) -> float:
    var resources = state.get("factions",{}).get(faction_id,{}).get("resources",{})
    if typeof(resources) != TYPE_DICTIONARY:
        return 0.0
    var total := 0.0
    for key in RESOURCE_KEYS:
        total += float(resources.get(key,0.0))
    return total / float(RESOURCE_KEYS.size())

static func sell_multiplier(state:Dictionary,faction_id:String,item_id:String) -> float:
    # Player selling to a specialist is rewarded; flooding one market gradually erodes price.
    var affinity = FactionCatalog.market_affinity(faction_id,item_id)
    var record = state.get("factions",{}).get(faction_id,{})
    var pressure = record.get("market_pressure",{})
    var flooded = clamp(float(pressure.get(item_id,0.0)),0.0,80.0)
    return clamp(affinity * (1.0 - flooded / 160.0),0.35,1.45)

static func buy_multiplier(state:Dictionary,faction_id:String,item_id:String) -> float:
    # Healthy settlement supply lowers prices; poor supply raises them. Reputation has only
    # a modest effect — access and assortment are the main reward, not MMO discount stacking.
    var condition = settlement_condition(state,faction_id)
    var scarcity = lerp(1.28,0.88,clamp(condition / 100.0,0.0,1.0))
    var rep = reputation(state,faction_id)
    var rep_factor = 1.0 - min(0.08,max(0,rep) / 1875.0)
    var affinity = FactionCatalog.market_affinity(faction_id,item_id)
    var specialist = 0.92 if affinity > 1.0 else (1.10 if affinity < 1.0 else 1.0)
    return clamp(scarcity * rep_factor * specialist,0.72,1.55)

static func record_sale(state:Dictionary,faction_id:String,item_id:String,quantity:int) -> void:
    if not state.get("factions",{}).has(faction_id):
        return
    var record = state["factions"][faction_id]
    var pressure = record.get("market_pressure",{})
    pressure[item_id] = clamp(float(pressure.get(item_id,0.0)) + max(0,quantity) * 1.5,0.0,80.0)
    record["market_pressure"] = pressure
    state["factions"][faction_id] = record

static func daily_tick(state:Dictionary) -> void:
    # Markets recover from saturation. Settlement resources decay slowly to create
    # supply demand without turning the game into constant maintenance.
    for faction_id in FactionCatalog.ids():
        var record = state["factions"][faction_id]
        var resources = record.get("resources",{})
        resources["food"] = max(0.0,float(resources.get("food",0.0)) - 1.4)
        resources["medicine"] = max(0.0,float(resources.get("medicine",0.0)) - 0.7)
        resources["technical"] = max(0.0,float(resources.get("technical",0.0)) - 0.5)
        resources["security"] = max(0.0,float(resources.get("security",0.0)) - 0.35)
        record["resources"] = resources
        var pressure = record.get("market_pressure",{})
        for item_id in pressure.keys():
            pressure[item_id] = max(0.0,float(pressure[item_id]) - 8.0)
            if pressure[item_id] <= 0.01:
                pressure.erase(item_id)
        record["market_pressure"] = pressure
        state["factions"][faction_id] = record

    # Open routes created by completed contracts provide a small persistent daily
    # logistics benefit. The bonus is intentionally weaker than direct player deliveries:
    # contracts improve the world but do not remove the need to scavenge and trade.
    var routes = state.get("world_routes",{})
    if typeof(routes) == TYPE_DICTIONARY:
        for route_id in routes.keys():
            var route = routes[route_id]
            if typeof(route) != TYPE_DICTIONARY or str(route.get("state","")) != "open":
                continue
            var bonuses = route.get("daily_resources",{})
            if typeof(bonuses) != TYPE_DICTIONARY:
                continue
            for raw_faction_id in route.get("beneficiaries",[]):
                var beneficiary = str(raw_faction_id)
                if not state.get("factions",{}).has(beneficiary):
                    continue
                for resource_id in bonuses.keys():
                    if str(resource_id) in RESOURCE_KEYS:
                        adjust_resource(state,beneficiary,str(resource_id),float(bonuses[resource_id]))
