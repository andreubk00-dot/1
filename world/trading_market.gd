extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")
const SettlementCrisis = preload("res://world/settlement_crisis.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")

# Stateless transaction math. Inventory mutation stays in main_script_mod.gd so the
# existing grid/instance invariants remain the single source of truth.

static func ensure_state(state:Dictionary,world_day:int = 1) -> void:
    var current = state.get("traders",{})
    state["traders"] = TraderCatalog.sanitize_trader_states(current,world_day)

static func stock(state:Dictionary,trader_id:String,item_id:String) -> int:
    return max(0,int(state.get("traders",{}).get(trader_id,{}).get("stock",{}).get(item_id,0)))

static func reserve(state:Dictionary,trader_id:String) -> int:
    return max(0,int(state.get("traders",{}).get(trader_id,{}).get("ticket_reserve",0)))

static func item_unlocked(state:Dictionary,trader_id:String,item_id:String) -> bool:
    var data = TraderCatalog.trader(trader_id)
    if data.is_empty():
        return false
    var rep = FactionEconomy.reputation(state,str(data.get("faction","")))
    return rep >= TraderCatalog.required_rep(trader_id,item_id)

static func buy_price(state:Dictionary,trader_id:String,item_id:String) -> int:
    var data = TraderCatalog.trader(trader_id)
    if data.is_empty():
        return 0
    var faction_id = str(data.get("faction",""))
    var base = TraderCatalog.base_value(item_id)
    return max(1,int(ceil(base * FactionEconomy.buy_multiplier(state,faction_id,item_id))))

static func sell_price(state:Dictionary,trader_id:String,item_id:String) -> int:
    var data = TraderCatalog.trader(trader_id)
    if data.is_empty() or not TraderCatalog.accepts_item(trader_id,item_id):
        return 0
    var faction_id = str(data.get("faction",""))
    # Keep a hard spread cap after all scarcity/reputation modifiers. Crisis demand can make a
    # settlement pay more for needed goods, but never enough for a buy->sell arbitrage loop.
    var raw = max(1,int(floor(TraderCatalog.base_value(item_id) * 0.54 * FactionEconomy.sell_multiplier(state,faction_id,item_id))))
    var retail = buy_price(state,trader_id,item_id)
    return mini(raw,max(1,int(floor(retail * 0.80))))

static func buy_quote(state:Dictionary,trader_id:String,item_id:String,quantity:int = 1) -> Dictionary:
    var qty = max(1,quantity)
    if TraderCatalog.trader(trader_id).is_empty():
        return {"ok":false,"reason":"Торговец недоступен"}
    if stock(state,trader_id,item_id) < qty:
        return {"ok":false,"reason":"Нет нужного количества в запасе"}
    if not item_unlocked(state,trader_id,item_id):
        return {"ok":false,"reason":"Недостаточная репутация"}
    var unit = buy_price(state,trader_id,item_id)
    var total = unit * qty
    if int(state.get("currency_tickets",0)) < total:
        return {"ok":false,"reason":"Недостаточно расчётных талонов","unit":unit,"total":total}
    return {"ok":true,"unit":unit,"total":total,"quantity":qty}

static func sell_quote(state:Dictionary,trader_id:String,item_id:String,quantity:int = 1) -> Dictionary:
    var qty = max(1,quantity)
    if not TraderCatalog.accepts_item(trader_id,item_id):
        return {"ok":false,"reason":"Этот торговец не принимает такой товар"}
    var unit = sell_price(state,trader_id,item_id)
    var total = unit * qty
    if reserve(state,trader_id) < total:
        return {"ok":false,"reason":"У торговца не хватает талонов","unit":unit,"total":total}
    return {"ok":true,"unit":unit,"total":total,"quantity":qty}

static func _resource_effect(state:Dictionary,faction_id:String,item_id:String,quantity:int,direction:float) -> void:
    var category = FactionCatalog.item_category(item_id)
    var qty = max(0,quantity)
    if qty <= 0:
        return
    var resource_id = ""
    var per_unit = 0.0
    if category in ["food","water","household"]:
        resource_id = "food"
        per_unit = 0.14
    elif category in ["medicine","medical","chemicals"]:
        resource_id = "medicine"
        per_unit = 0.18
    elif category in ["parts","tools","electronics","technical","fuel"]:
        resource_id = "technical"
        per_unit = 0.16
    elif category in ["ammo","weapon","armor"]:
        resource_id = "security"
        per_unit = 0.10
    if resource_id != "":
        FactionEconomy.adjust_resource(state,faction_id,resource_id,per_unit * qty * direction)

static func _apply_supply_effect(state:Dictionary,faction_id:String,item_id:String,quantity:int) -> void:
    _resource_effect(state,faction_id,item_id,quantity,1.0)

static func _apply_demand_effect(state:Dictionary,faction_id:String,item_id:String,quantity:int) -> void:
    # Buying finite stock from a settlement consumes a small amount of the matching abstract
    # resource. Selling the same goods back restores the same amount, closing the old
    # buy->sell->resource-inflation exploit while preserving legitimate inter-settlement trade.
    _resource_effect(state,faction_id,item_id,quantity,-1.0)

static func apply_purchase(state:Dictionary,trader_id:String,item_id:String,quantity:int,total:int) -> bool:
    ensure_state(state,1)
    if quantity <= 0:
        return false
    var data = TraderCatalog.trader(trader_id)
    if data.is_empty():
        return false
    var quote = buy_quote(state,trader_id,item_id,quantity)
    if not bool(quote.get("ok",false)) or int(quote.get("total",-1)) != total:
        return false
    var traders = state["traders"]
    if not traders.has(trader_id):
        return false
    var record = traders[trader_id]
    var current_stock = max(0,int(record.get("stock",{}).get(item_id,0)))
    record["stock"][item_id] = current_stock - quantity
    record["ticket_reserve"] = clamp(int(record.get("ticket_reserve",0)) + total,0,5000)
    traders[trader_id] = record
    state["traders"] = traders
    FactionEconomy.add_tickets(state,-total)
    _apply_demand_effect(state,str(data.get("faction","")),item_id,quantity)
    return true

static func apply_sale(state:Dictionary,trader_id:String,item_id:String,quantity:int,total:int) -> bool:
    ensure_state(state,1)
    if quantity <= 0:
        return false
    var data = TraderCatalog.trader(trader_id)
    if data.is_empty() or not TraderCatalog.accepts_item(trader_id,item_id):
        return false
    var quote = sell_quote(state,trader_id,item_id,quantity)
    if not bool(quote.get("ok",false)) or int(quote.get("total",-1)) != total:
        return false
    var traders = state["traders"]
    var record = traders[trader_id]
    record["ticket_reserve"] = max(0,int(record.get("ticket_reserve",0)) - total)
    record["stock"][item_id] = max(0,int(record.get("stock",{}).get(item_id,0))) + quantity
    traders[trader_id] = record
    state["traders"] = traders
    FactionEconomy.add_tickets(state,total)
    var faction_id = str(data.get("faction",""))
    FactionEconomy.record_sale(state,faction_id,item_id,quantity)
    _apply_supply_effect(state,faction_id,item_id,quantity)
    return true

static func barter_quote(state:Dictionary,trader_id:String,buy_item:String,buy_qty:int,sell_item:String,sell_qty:int) -> Dictionary:
    var bq = buy_quote(state,trader_id,buy_item,max(1,buy_qty))
    # A barter quote must not require the player to already own the full ticket price.
    if not bq.get("ok",false) and str(bq.get("reason","")) != "Недостаточно расчётных талонов":
        return {"ok":false,"reason":str(bq.get("reason","Обмен невозможен"))}
    if not TraderCatalog.accepts_item(trader_id,sell_item):
        return {"ok":false,"reason":"Этот товар не подходит для бартера"}
    var buy_total = buy_price(state,trader_id,buy_item) * max(1,buy_qty)
    var offer_total = sell_price(state,trader_id,sell_item) * max(1,sell_qty)
    var delta = buy_total - offer_total # >0 player pays; <0 trader gives change.
    if delta > int(state.get("currency_tickets",0)):
        return {"ok":false,"reason":"Не хватает талонов для доплаты","buy_total":buy_total,"offer_total":offer_total,"ticket_delta":delta}
    if delta < 0 and reserve(state,trader_id) < -delta:
        return {"ok":false,"reason":"У торговца нет талонов для сдачи","buy_total":buy_total,"offer_total":offer_total,"ticket_delta":delta}
    return {"ok":true,"buy_total":buy_total,"offer_total":offer_total,"ticket_delta":delta}

static func apply_barter(state:Dictionary,trader_id:String,buy_item:String,buy_qty:int,sell_item:String,sell_qty:int,ticket_delta:int) -> bool:
    ensure_state(state,1)
    if buy_qty <= 0 or sell_qty <= 0 or buy_item == sell_item:
        return false
    var data = TraderCatalog.trader(trader_id)
    if data.is_empty():
        return false
    var quote = barter_quote(state,trader_id,buy_item,buy_qty,sell_item,sell_qty)
    if not bool(quote.get("ok",false)) or int(quote.get("ticket_delta",999999)) != ticket_delta:
        return false
    var traders = state["traders"]
    var record = traders[trader_id]
    record["stock"][buy_item] = max(0,int(record["stock"].get(buy_item,0)) - buy_qty)
    record["stock"][sell_item] = max(0,int(record["stock"].get(sell_item,0))) + sell_qty
    record["ticket_reserve"] = clamp(int(record.get("ticket_reserve",0)) + ticket_delta,0,5000)
    traders[trader_id] = record
    state["traders"] = traders
    FactionEconomy.add_tickets(state,-ticket_delta)
    var faction_id = str(data.get("faction",""))
    FactionEconomy.record_sale(state,faction_id,sell_item,sell_qty)
    _apply_demand_effect(state,faction_id,buy_item,buy_qty)
    _apply_supply_effect(state,faction_id,sell_item,sell_qty)
    return true

static func _resource_key_for_faction(faction_id:String) -> String:
    match faction_id:
        "perron": return "food"
        "rubezh": return "security"
        "mechanics": return "technical"
        "lazaret": return "medicine"
    return "technical"

static func restock(state:Dictionary,trader_id:String,world_day:int,force:bool = false) -> bool:
    ensure_state(state,world_day)
    var data = TraderCatalog.trader(trader_id)
    if data.is_empty():
        return false
    var traders = state["traders"]
    var record = traders[trader_id]
    var due = int(record.get("last_restock_day",1)) + max(1,int(data.get("restock_days",2)))
    if not force and world_day < due:
        return false
    var faction_id = str(data.get("faction",""))
    var condition = FactionEconomy.settlement_condition(state,faction_id)
    for spec in data.get("stock",[]):
        var item_id = str(spec.get("id",""))
        var base_qty = max(1,int(spec.get("qty",1)))
        var resource_id = SettlementCrisis.resource_for_item(item_id)
        var resource = condition if resource_id == "" else SettlementCrisis.resource_value(state,faction_id,resource_id)
        var supply_mult = (0.45 + clamp(resource / 100.0,0.0,1.0) * 0.75) * SettlementCrisis.restock_factor(state,faction_id,item_id) * FactionEndgame.restock_factor(state,faction_id,item_id)
        var required_rep = TraderCatalog.required_rep(trader_id,item_id)
        var target = 0
        if SettlementCrisis.allows_restock(state,faction_id,item_id,required_rep):
            target = max(1,int(round(base_qty * supply_mult))) + FactionEndgame.reserve_bonus(state,faction_id,item_id)
        # Never delete stock already visible to the player; crisis only suppresses future replenishment.
        record["stock"][item_id] = max(int(record["stock"].get(item_id,0)),target)
    var reserve_target = int(round(float(data.get("ticket_reserve",300)) * (0.50 + 0.50 * clamp(condition / 100.0,0.0,1.0))))
    record["ticket_reserve"] = max(int(record.get("ticket_reserve",0)),reserve_target)
    record["last_restock_day"] = max(1,world_day)
    traders[trader_id] = record
    state["traders"] = traders
    if state.get("factions",{}).has(faction_id):
        state["factions"][faction_id]["last_supply_day"] = max(1,world_day)
    return true

static func restock_all(state:Dictionary,world_day:int) -> int:
    var changed = 0
    for trader_id in TraderCatalog.ids():
        if restock(state,str(trader_id),world_day,false):
            changed += 1
    return changed
