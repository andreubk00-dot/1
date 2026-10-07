extends RefCounted

# OSTATOK 1.22-dev1 — faction foundation.
# Stable ids are deliberately separate from display names; save data and contracts use ids.
const REP_TIERS = [
    {"id":"outsider","name":"ЧУЖОЙ","min":-9999},
    {"id":"known","name":"ЗНАКОМЫЙ","min":25},
    {"id":"reliable","name":"НАДЁЖНЫЙ","min":75},
    {"id":"trusted","name":"ДОВЕРЕННЫЙ","min":150}
]

const FACTIONS = {
    "perron":{
        "name":"Община «Перрон»","short_name":"ПЕРРОН","settlement_id":"settlement_perron",
        "market_focus":["food","water","household"],
        "market_dislikes":["military"],
        "resource_bias":{"food":1.35,"medicine":0.85,"technical":0.80,"security":0.90},
        "services":["lodging","canteen","general_market","rumors"],
        "npc_roster":[
            {"id":"perron_steward","name":"Вера Андреевна","role":"старшая общины"},
            {"id":"perron_trader","name":"Миша Рыжий","role":"хозяйственный торговец"},
            {"id":"perron_cook","name":"Тётя Галя","role":"заведующая кухней"},
            {"id":"perron_radio","name":"Лёнька","role":"радист"}
        ]
    },
    "rubezh":{
        "name":"«Рубеж»","short_name":"РУБЕЖ","settlement_id":"settlement_rubezh",
        "market_focus":["ammo","weapon","armor","security"],
        "market_dislikes":["luxury","household"],
        "resource_bias":{"food":0.90,"medicine":0.95,"technical":1.05,"security":1.35},
        "services":["armorer","weapon_service","route_clearance","patrol_board"],
        "npc_roster":[
            {"id":"rubezh_commander","name":"Капитан Орлов","role":"начальник гарнизона"},
            {"id":"rubezh_armorer","name":"Борис «Шплинт»","role":"оружейник"},
            {"id":"rubezh_quartermaster","name":"Старшина Лебедев","role":"снабженец"},
            {"id":"rubezh_dispatch","name":"Ирина","role":"диспетчер патрулей"}
        ]
    },
    "mechanics":{
        "name":"Артель «Механики»","short_name":"МЕХАНИКИ","settlement_id":"settlement_mechanics",
        "market_focus":["tools","parts","electronics","fuel","technical"],
        "market_dislikes":["food","medicine"],
        "resource_bias":{"food":0.80,"medicine":0.75,"technical":1.45,"security":0.90},
        "services":["repair","filter_service","fabrication","expedition_gear"],
        "npc_roster":[
            {"id":"mechanics_master","name":"Саныч","role":"главный механик"},
            {"id":"mechanics_trader","name":"Рита","role":"приёмщица деталей"},
            {"id":"mechanics_electrician","name":"Гена","role":"электрик"},
            {"id":"mechanics_storekeeper","name":"Клык","role":"кладовщик"}
        ]
    },
    "lazaret":{
        "name":"«Лазарет»","short_name":"ЛАЗАРЕТ","settlement_id":"settlement_lazaret",
        "market_focus":["medicine","medical","chemicals"],
        "market_dislikes":["weapon","luxury"],
        "resource_bias":{"food":0.90,"medicine":1.50,"technical":0.90,"security":0.85},
        "services":["treatment","diagnostics","infection_care","medical_market"],
        "npc_roster":[
            {"id":"lazaret_doctor","name":"Доктор Миронова","role":"старший врач"},
            {"id":"lazaret_supplier","name":"Тимур","role":"снабженец"},
            {"id":"lazaret_nurse","name":"Лида","role":"фельдшер"},
            {"id":"lazaret_researcher","name":"Аркадий","role":"лаборант"}
        ]
    }
}

# Economy categories intentionally reference existing item ids. Unknown ids remain tradable
# as "general" goods, so future content does not require schema migrations.
const ITEM_CATEGORIES = {
    "bandage":"medicine","sterile_bandage":"medicine","antiseptic":"medicine","painkillers":"medicine","antibiotics":"medicine","trauma_kit":"medicine",
    "water":"water","dirty_water":"water","canteen":"household","water_canister":"technical",
    "canned_meat":"food","emergency_ration":"food","grain":"food","herbs":"food","hot_meal":"food","herbal_tea":"food",
    "scrap":"parts","cloth":"household","tape":"tools","repair_kit":"tools","water_filter":"technical","flashlight":"electronics","firewood":"household",
    "ammo_9x18":"ammo","ammo_762x25":"ammo","ammo_12g":"ammo","ammo_762":"ammo","ammo_545":"ammo","ammo_762x54r":"ammo",
    "makarov":"weapon","tt33":"weapon","pps43":"weapon","shotgun":"weapon","toz34":"weapon","izh81":"weapon","sks":"weapon","akm":"weapon","aks74u":"weapon","mosin":"weapon",
    "combat_knife":"weapon","steel_pipe":"weapon","fire_axe":"weapon",
    "police_vest":"armor","military_vest":"armor","ballistic_helmet":"armor","field_rig":"armor","assault_rig":"armor",
    "cap":"household","wool_hat":"household","light_jacket":"household","rain_jacket":"technical","insulated_parka":"technical","storm_poncho":"technical",
    "field_backpack":"technical","hiking_backpack":"technical","expedition_pack":"technical","bedroll":"technical",
    "makarov_extmag":"parts","shotgun_exttube":"parts","akm_extmag":"parts","muzzle_brake":"parts","suppressor":"parts",
    "old_checkpoint_documents":"strategic","military_radio_station":"strategic",
    "generator_control_unit":"strategic","laboratory_analyzer":"strategic"
}

static func faction(faction_id:String) -> Dictionary:
    return FACTIONS.get(faction_id,{}).duplicate(true)

static func ids() -> Array:
    return FACTIONS.keys()

static func reputation_tier(points:int) -> Dictionary:
    var result = REP_TIERS[0]
    for tier in REP_TIERS:
        if points >= int(tier.get("min",0)):
            result = tier
    return result.duplicate(true)

static func item_category(item_id:String) -> String:
    return str(ITEM_CATEGORIES.get(item_id,"general"))

static func market_affinity(faction_id:String,item_id:String) -> float:
    var data = FACTIONS.get(faction_id,{})
    var category = item_category(item_id)
    if category in data.get("market_focus",[]):
        return 1.30
    if category in data.get("market_dislikes",[]):
        return 0.62
    return 1.0
