extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")

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
    # 54% baseline preserves a specialist premium while keeping the spread non-inverting even at
    # trusted reputation + fully supplied settlements (the cheapest possible buy price).
    return max(1,int(floor(TraderCatalog.base_value(item_id) * 0.54 * FactionEconomy.sell_multiplier(state,faction_id,item_id))))

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

static func _apply_supply_effect(state:Dictionary,faction_id:String,item_id:String,quantity:int) -> void:
    var category = FactionCatalog.item_category(item_id)
    var qty = max(0,quantity)
    if category in ["food","water","household"]:
        FactionEconomy.adjust_resource(state,faction_id,"food",0.14 * qty)
    elif category in ["medicine","medical","chemicals"]:
        FactionEconomy.adjust_resource(state,faction_id,"medicine",0.18 * qty)
    elif category in ["parts","tools","electronics","technical","fuel"]:
        FactionEconomy.adjust_resource(state,faction_id,"technical",0.16 * qty)
    elif category in ["ammo","weapon","armor"]:
        FactionEconomy.adjust_resource(state,faction_id,"security",0.10 * qty)

static func apply_purchase(state:Dictionary,trader_id:String,item_id:String,quantity:int,total:int) -> bool:
    ensure_state(state,1)
    var traders = state["traders"]
    if not traders.has(trader_id):
        return false
    var record = traders[trader_id]
    var current_stock = max(0,int(record.get("stock",{}).get(item_id,0)))
    if current_stock < quantity or int(state.get("currency_tickets",0)) < total:
        return false
    record["stock"][item_id] = current_stock - quantity
    record["ticket_reserve"] = clamp(int(record.get("ticket_reserve",0)) + total,0,5000)
    traders[trader_id] = record
    state["traders"] = traders
    FactionEconomy.add_tickets(state,-total)
    return true

static func apply_sale(state:Dictionary,trader_id:String,item_id:String,quantity:int,total:int) -> bool:
    ensure_state(state,1)
    var data = TraderCatalog.trader(trader_id)
    if data.is_empty() or not TraderCatalog.accepts_item(trader_id,item_id):
        return false
    var traders = state["traders"]
    var record = traders[trader_id]
    if int(record.get("ticket_reserve",0)) < total:
        return false
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
    var data = TraderCatalog.trader(trader_id)
    if data.is_empty() or stock(state,trader_id,buy_item) < buy_qty:
        return false
    var traders = state["traders"]
    var record = traders[trader_id]
    if ticket_delta > 0 and int(state.get("currency_tickets",0)) < ticket_delta:
        return false
    if ticket_delta < 0 and int(record.get("ticket_reserve",0)) < -ticket_delta:
        return false
    record["stock"][buy_item] = max(0,int(record["stock"].get(buy_item,0)) - buy_qty)
    record["stock"][sell_item] = max(0,int(record["stock"].get(sell_item,0))) + sell_qty
    record["ticket_reserve"] = clamp(int(record.get("ticket_reserve",0)) + ticket_delta,0,5000)
    traders[trader_id] = record
    state["traders"] = traders
    FactionEconomy.add_tickets(state,-ticket_delta)
    var faction_id = str(data.get("faction",""))
    FactionEconomy.record_sale(state,faction_id,sell_item,sell_qty)
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
    var resource_key = _resource_key_for_faction(faction_id)
    var resource = float(state.get("factions",{}).get(faction_id,{}).get("resources",{}).get(resource_key,50.0))
    var supply_mult = 0.45 + clamp(resource / 100.0,0.0,1.0) * 0.75
    for spec in data.get("stock",[]):
        var item_id = str(spec.get("id",""))
        var base_qty = max(1,int(spec.get("qty",1)))
        var target = max(1,int(round(base_qty * supply_mult)))
        record["stock"][item_id] = max(int(record["stock"].get(item_id,0)),target)
    var reserve_target = int(round(float(data.get("ticket_reserve",300)) * (0.55 + 0.45 * clamp(resource / 100.0,0.0,1.0))))
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
