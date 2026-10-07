extends RefCounted

# OSTATOK 1.23.0-dev15 — consequences of the four starter sandbox routes.
# The permanent state remains the existing world_routes dictionary. This module derives
# market/NPC/radio consequences from open routes instead of introducing another save block.
const ROUTES = {
    "route_perron_zarya":{
        "faction":"perron",
        "label":"СНТ «Заря»",
        "categories":["food","water","household"],
        "restock_factor":1.12,
        "opening_stock":[
            {"trader":"perron_canteen","item":"grain","qty":4},
            {"trader":"perron_canteen","item":"water","qty":4},
            {"trader":"perron_general","item":"canned_meat","qty":3}
        ],
        "npc_note":"Дорога к «Заре» работает: кухня и рынок получают провизию стабильнее. За оружием всё равно лучше идти к Рубежу.",
        "news":"ПЕРРОН сообщает: дорога к СНТ «Заря» вошла в постоянное снабжение. На кухню и рынок снова идут продукты, вода и хозяйственные запасы."
    },
    "route_lazaret_hospital":{
        "faction":"lazaret",
        "label":"районная больница",
        "categories":["medicine","medical","chemicals"],
        "restock_factor":1.12,
        "opening_stock":[
            {"trader":"lazaret_supplier","item":"sterile_bandage","qty":2},
            {"trader":"lazaret_supplier","item":"antiseptic","qty":1},
            {"trader":"lazaret_medic","item":"bandage","qty":4}
        ],
        "npc_note":"Маршрут к районной больнице работает: перевязочные материалы приходят стабильнее. За инструментом всё равно сильнее Механики.",
        "news":"ЛАЗАРЕТ сообщает: районная больница подключена к постоянному снабжению. Перевязочные материалы и лекарства теперь приходят стабильнее."
    },
    "route_rubezh_police":{
        "faction":"rubezh",
        "label":"районный отдел полиции",
        "categories":["ammo","armor"],
        "restock_factor":1.10,
        "opening_stock":[
            {"trader":"rubezh_armorer","item":"ammo_9x18","qty":8},
            {"trader":"rubezh_armorer","item":"ammo_12g","qty":4},
            {"trader":"rubezh_quartermaster","item":"bandage","qty":2}
        ],
        "npc_note":"Полицейский маршрут работает: боезапас и защита приходят ровнее. За серьёзным ремонтом всё равно едут к Механикам.",
        "news":"РУБЕЖ сообщает: районный отдел полиции включён в постоянную патрульную логистику. Боезапас и защитное снаряжение пополняются стабильнее."
    },
    "route_mechanics_depot":{
        "faction":"mechanics",
        "label":"железнодорожное депо",
        "categories":["parts","tools","electronics","technical","fuel"],
        "restock_factor":1.12,
        "opening_stock":[
            {"trader":"mechanics_parts","item":"scrap","qty":6},
            {"trader":"mechanics_parts","item":"tape","qty":2},
            {"trader":"mechanics_parts","item":"repair_kit","qty":1}
        ],
        "npc_note":"Депо работает на артель: металл и ремонтный расходник идут стабильнее. Медицину по-прежнему надёжнее искать через Лазарет.",
        "news":"МЕХАНИКИ сообщают: железнодорожное депо снова работает на артель. Металл, инструмент и ремонтные детали идут в мастерские стабильнее."
    }
}

static func route(route_id:String) -> Dictionary:
    return ROUTES.get(route_id,{}).duplicate(true)

static func route_for_faction(faction_id:String) -> String:
    for raw_route_id in ROUTES.keys():
        var route_id = str(raw_route_id)
        if str(ROUTES[route_id].get("faction","")) == faction_id:
            return route_id
    return ""

static func is_open(state:Dictionary,route_id:String) -> bool:
    if not ROUTES.has(route_id):
        return false
    return str(state.get("world_routes",{}).get(route_id,{}).get("state","")) == "open"

static func open_for_faction(state:Dictionary,faction_id:String) -> String:
    var route_id = route_for_faction(faction_id)
    return route_id if route_id != "" and is_open(state,route_id) else ""

static func restock_factor(state:Dictionary,faction_id:String,item_id:String,item_category:String) -> float:
    var route_id = open_for_faction(state,faction_id)
    if route_id == "":
        return 1.0
    var spec = ROUTES[route_id]
    if item_category not in spec.get("categories",[]):
        return 1.0
    return clamp(float(spec.get("restock_factor",1.0)),1.0,1.20)

static func apply_opening_stock(state:Dictionary,route_id:String) -> Dictionary:
    # Called from the successful contract-completion path. The marker lives inside the
    # existing route record, so save schema 122 remains unchanged and repeated UI calls
    # cannot duplicate the opening package. Existing dev14 saves intentionally do not
    # receive this one-time package merely because they were loaded.
    if not ROUTES.has(route_id) or not is_open(state,route_id):
        return {"applied":false,"added":0}
    var routes = state.get("world_routes",{})
    var route_record = routes.get(route_id,{})
    if typeof(route_record) != TYPE_DICTIONARY or bool(route_record.get("opening_stock_applied",false)):
        return {"applied":false,"added":0}
    var traders = state.get("traders",{})
    if typeof(traders) != TYPE_DICTIONARY:
        return {"applied":false,"added":0}
    var added = 0
    for row in ROUTES[route_id].get("opening_stock",[]):
        if typeof(row) != TYPE_DICTIONARY:
            continue
        var trader_id = str(row.get("trader",""))
        var item_id = str(row.get("item",""))
        var qty = max(0,int(row.get("qty",0)))
        if trader_id == "" or item_id == "" or qty <= 0 or not traders.has(trader_id):
            continue
        var trader = traders[trader_id]
        var stock = trader.get("stock",{})
        if typeof(stock) != TYPE_DICTIONARY:
            stock = {}
        stock[item_id] = max(0,int(stock.get(item_id,0))) + qty
        trader["stock"] = stock
        traders[trader_id] = trader
        added += qty
    state["traders"] = traders
    route_record["opening_stock_applied"] = true
    routes[route_id] = route_record
    state["world_routes"] = routes
    return {"applied":added > 0,"added":added}

static func npc_note(state:Dictionary,faction_id:String) -> String:
    var route_id = open_for_faction(state,faction_id)
    if route_id == "":
        return ""
    return str(ROUTES[route_id].get("npc_note",""))

static func news_text(route_id:String) -> String:
    if not ROUTES.has(route_id):
        return ""
    return str(ROUTES[route_id].get("news",""))

static func summary(state:Dictionary,faction_id:String) -> String:
    var route_id = open_for_faction(state,faction_id)
    if route_id == "":
        return ""
    return "маршрут: %s" % str(ROUTES[route_id].get("label",route_id))
