extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")

# OSTATOK 1.22-dev2 — authored traders and shared ticket economy.
# Prices are deliberately expressed in small integer "расчётные талоны" so loot
# remains readable at a glance and no faction introduces a second currency.
const REP_MIN = {"outsider":-9999,"known":25,"reliable":75,"trusted":150}

const BASE_VALUES = {
    "bandage":6,"water":4,"canned_meat":8,"scrap":4,"cloth":3,"tape":5,
    "repair_kit":28,"water_filter":20,
    "ammo_9x18":2,"ammo_12g":3,"ammo_762":3,"ammo_762x25":2,"ammo_545":3,"ammo_762x54r":4,
    "makarov":80,"tt33":92,"shotgun":135,"toz34":155,"sks":175,"akm":245,"pps43":165,"izh81":150,"aks74u":235,"mosin":190,
    "combat_knife":22,"steel_pipe":10,"fire_axe":32,
    "cap":5,"light_jacket":24,"police_vest":95,"field_backpack":58,"flashlight":24,"wool_hat":7,
    "ballistic_helmet":125,"rain_jacket":48,"insulated_parka":62,"storm_poncho":54,"bedroll":44,
    "canteen":18,"water_canister":34,"field_rig":72,"assault_rig":128,"military_vest":190,
    "hiking_backpack":92,"expedition_pack":155,"trauma_kit":42,"emergency_ration":14,
    "makarov_extmag":36,"shotgun_exttube":42,"akm_extmag":60,"muzzle_brake":48,"suppressor":72,
    "sterile_bandage":10,"antiseptic":18,"painkillers":14,"antibiotics":26,
    "firewood":3,"dirty_water":1,"grain":5,"herbs":4,"hot_meal":10,"herbal_tea":8
}

const TRADERS = {
    "perron_general":{
        "name":"Миша Рыжий","npc_id":"perron_trader","faction":"perron","settlement_id":"settlement_perron",
        "role":"хозяйственный рынок","restock_days":2,"ticket_reserve":420,
        "accepted_categories":["food","water","household","medicine","tools","technical","electronics","parts"],
        "stock":[
            {"id":"water","qty":18,"tier":"outsider"},{"id":"canned_meat","qty":12,"tier":"outsider"},
            {"id":"bandage","qty":8,"tier":"outsider"},{"id":"cloth","qty":12,"tier":"outsider"},
            {"id":"tape","qty":8,"tier":"outsider"},{"id":"flashlight","qty":2,"tier":"known"},
            {"id":"field_backpack","qty":2,"tier":"known"},{"id":"canteen","qty":3,"tier":"outsider"},
            {"id":"hiking_backpack","qty":1,"tier":"reliable"},{"id":"bedroll","qty":2,"tier":"known"}
        ]
    },
    "perron_canteen":{
        "name":"Тётя Галя","npc_id":"perron_cook","faction":"perron","settlement_id":"settlement_perron",
        "role":"кухня и провизия","restock_days":1,"ticket_reserve":260,
        "accepted_categories":["food","water","household"],
        "stock":[
            {"id":"water","qty":24,"tier":"outsider"},{"id":"canned_meat","qty":14,"tier":"outsider"},
            {"id":"grain","qty":18,"tier":"outsider"},{"id":"hot_meal","qty":10,"tier":"outsider"},
            {"id":"herbal_tea","qty":8,"tier":"outsider"},{"id":"emergency_ration","qty":4,"tier":"known"},
            {"id":"firewood","qty":12,"tier":"outsider"}
        ]
    },
    "rubezh_armorer":{
        "name":"Борис «Шплинт»","npc_id":"rubezh_armorer","faction":"rubezh","settlement_id":"settlement_rubezh",
        "role":"оружейник","restock_days":3,"ticket_reserve":700,
        "accepted_categories":["ammo","weapon","armor","parts","tools"],
        "stock":[
            {"id":"ammo_9x18","qty":40,"tier":"outsider"},{"id":"ammo_762x25","qty":30,"tier":"known"},
            {"id":"ammo_12g","qty":24,"tier":"known"},{"id":"ammo_762","qty":24,"tier":"reliable"},
            {"id":"ammo_545","qty":24,"tier":"reliable"},{"id":"ammo_762x54r","qty":18,"tier":"reliable"},
            {"id":"makarov","qty":1,"tier":"known"},{"id":"tt33","qty":1,"tier":"known"},
            {"id":"shotgun","qty":1,"tier":"reliable"},{"id":"sks","qty":1,"tier":"reliable"},
            {"id":"akm","qty":1,"tier":"trusted"},{"id":"aks74u","qty":1,"tier":"trusted"},
            {"id":"muzzle_brake","qty":1,"tier":"reliable"},{"id":"makarov_extmag","qty":2,"tier":"reliable"}
        ]
    },
    "rubezh_quartermaster":{
        "name":"Старшина Лебедев","npc_id":"rubezh_quartermaster","faction":"rubezh","settlement_id":"settlement_rubezh",
        "role":"снабжение гарнизона","restock_days":3,"ticket_reserve":620,
        "accepted_categories":["ammo","armor","technical","tools","electronics","parts","medicine"],
        "stock":[
            {"id":"bandage","qty":10,"tier":"outsider"},{"id":"repair_kit","qty":4,"tier":"known"},
            {"id":"police_vest","qty":2,"tier":"known"},{"id":"field_rig","qty":2,"tier":"known"},
            {"id":"ballistic_helmet","qty":1,"tier":"reliable"},{"id":"assault_rig","qty":1,"tier":"reliable"},
            {"id":"military_vest","qty":1,"tier":"trusted"},{"id":"expedition_pack","qty":1,"tier":"trusted"}
        ]
    },
    "mechanics_parts":{
        "name":"Рита","npc_id":"mechanics_trader","faction":"mechanics","settlement_id":"settlement_mechanics",
        "role":"приёмка деталей","restock_days":2,"ticket_reserve":650,
        "accepted_categories":["parts","tools","electronics","technical","fuel","armor"],
        "stock":[
            {"id":"scrap","qty":24,"tier":"outsider"},{"id":"tape","qty":14,"tier":"outsider"},
            {"id":"repair_kit","qty":6,"tier":"known"},{"id":"water_filter","qty":6,"tier":"known"},
            {"id":"flashlight","qty":4,"tier":"outsider"},{"id":"water_canister","qty":3,"tier":"known"},
            {"id":"makarov_extmag","qty":2,"tier":"reliable"},{"id":"shotgun_exttube","qty":2,"tier":"reliable"},
            {"id":"akm_extmag","qty":1,"tier":"trusted"},{"id":"muzzle_brake","qty":2,"tier":"reliable"}
        ]
    },
    "mechanics_master":{
        "name":"Саныч","npc_id":"mechanics_master","faction":"mechanics","settlement_id":"settlement_mechanics",
        "role":"экспедиционное оснащение","restock_days":3,"ticket_reserve":720,
        "accepted_categories":["parts","tools","electronics","technical","armor"],
        "stock":[
            {"id":"field_backpack","qty":2,"tier":"outsider"},{"id":"hiking_backpack","qty":2,"tier":"known"},
            {"id":"field_rig","qty":2,"tier":"known"},{"id":"bedroll","qty":2,"tier":"known"},
            {"id":"rain_jacket","qty":2,"tier":"known"},{"id":"storm_poncho","qty":1,"tier":"reliable"},
            {"id":"expedition_pack","qty":1,"tier":"reliable"},{"id":"assault_rig","qty":1,"tier":"trusted"},
            {"id":"suppressor","qty":1,"tier":"trusted"}
        ]
    },
    "lazaret_supplier":{
        "name":"Тимур","npc_id":"lazaret_supplier","faction":"lazaret","settlement_id":"settlement_lazaret",
        "role":"медицинское снабжение","restock_days":2,"ticket_reserve":560,
        "accepted_categories":["medicine","medical","chemicals","water"],
        "stock":[
            {"id":"bandage","qty":16,"tier":"outsider"},{"id":"sterile_bandage","qty":10,"tier":"known"},
            {"id":"antiseptic","qty":8,"tier":"known"},{"id":"painkillers","qty":8,"tier":"known"},
            {"id":"antibiotics","qty":5,"tier":"reliable"},{"id":"trauma_kit","qty":2,"tier":"reliable"},
            {"id":"water","qty":12,"tier":"outsider"}
        ]
    },
    "lazaret_medic":{
        "name":"Лида","npc_id":"lazaret_nurse","faction":"lazaret","settlement_id":"settlement_lazaret",
        "role":"фельдшерский стол","restock_days":2,"ticket_reserve":360,
        "accepted_categories":["medicine","medical","food","water"],
        "stock":[
            {"id":"bandage","qty":12,"tier":"outsider"},{"id":"sterile_bandage","qty":6,"tier":"known"},
            {"id":"antiseptic","qty":5,"tier":"known"},{"id":"painkillers","qty":5,"tier":"known"},
            {"id":"herbal_tea","qty":6,"tier":"outsider"},{"id":"water","qty":10,"tier":"outsider"}
        ]
    }
}

static func ids() -> Array:
    return TRADERS.keys()

static func trader(trader_id:String) -> Dictionary:
    return TRADERS.get(trader_id,{}).duplicate(true)

static func trader_for_npc(npc_id:String) -> String:
    for trader_id in TRADERS.keys():
        if str(TRADERS[trader_id].get("npc_id","")) == npc_id:
            return str(trader_id)
    return ""

static func traders_for_faction(faction_id:String) -> Array:
    var out = []
    for trader_id in TRADERS.keys():
        if str(TRADERS[trader_id].get("faction","")) == faction_id:
            out.append(str(trader_id))
    return out

static func base_value(item_id:String) -> int:
    return max(1,int(BASE_VALUES.get(item_id,2)))

static func required_rep(trader_id:String,item_id:String) -> int:
    var spec = stock_spec(trader_id,item_id)
    return int(REP_MIN.get(str(spec.get("tier","outsider")),-9999))

static func stock_spec(trader_id:String,item_id:String) -> Dictionary:
    var data = TRADERS.get(trader_id,{})
    for raw in data.get("stock",[]):
        if str(raw.get("id","")) == item_id:
            return raw.duplicate(true)
    return {}

static func accepts_item(trader_id:String,item_id:String) -> bool:
    var data = TRADERS.get(trader_id,{})
    if data.is_empty() or not BASE_VALUES.has(item_id):
        return false
    var category = FactionCatalog.item_category(item_id)
    return category in data.get("accepted_categories",[])

static func default_trader_states(day:int = 1) -> Dictionary:
    var result = {}
    for trader_id in TRADERS.keys():
        var data = TRADERS[trader_id]
        var stock = {}
        for raw in data.get("stock",[]):
            stock[str(raw.get("id",""))] = max(0,int(raw.get("qty",0)))
        result[trader_id] = {
            "stock":stock,
            "ticket_reserve":max(0,int(data.get("ticket_reserve",300))),
            "last_restock_day":max(1,day)
        }
    return result

static func sanitize_trader_states(raw,day:int = 1) -> Dictionary:
    var clean = default_trader_states(day)
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    for trader_id in TRADERS.keys():
        var src = raw.get(trader_id,{})
        if typeof(src) != TYPE_DICTIONARY:
            continue
        var dst = clean[trader_id]
        dst["ticket_reserve"] = clamp(int(src.get("ticket_reserve",dst["ticket_reserve"])),0,5000)
        dst["last_restock_day"] = max(1,int(src.get("last_restock_day",day)))
        var incoming_stock = src.get("stock",{})
        if typeof(incoming_stock) == TYPE_DICTIONARY:
            var stock = {}
            # Keep valid configured goods plus goods the player has sold into this market.
            for raw_id in incoming_stock.keys():
                var item_id = str(raw_id)
                if BASE_VALUES.has(item_id) and accepts_item(trader_id,item_id):
                    stock[item_id] = clamp(int(incoming_stock[raw_id]),0,999)
            for spec in TRADERS[trader_id].get("stock",[]):
                var configured_id = str(spec.get("id",""))
                if not stock.has(configured_id):
                    stock[configured_id] = 0
            dst["stock"] = stock
        clean[trader_id] = dst
    return clean
