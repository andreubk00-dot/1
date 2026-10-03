extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionRelations = preload("res://world/faction_relations.gd")

# OSTATOK 1.22-dev8 — persistent late-game faction chains.
# This layer deliberately reuses the existing contract/economy systems. It stores only
# progression and permanent world effects; no moving faction simulation is introduced.
const HISTORY_LIMIT = 64
const RESOURCE_KEYS = ["food","medicine","technical","security"]

const CHAINS = {
    "perron":{
        "id":"perron_network","name":"ГРАЖДАНСКАЯ СЕТЬ",
        "templates":["perron_endgame_common_warehouse","perron_endgame_motor_pool","perron_endgame_civilian_exchange"],
        "effect":"perron_exchange","effect_name":"ОБЩИЙ ОБМЕННЫЙ ФОНД"
    },
    "rubezh":{
        "id":"rubezh_network","name":"СЕТЬ ПАТРУЛЬНЫХ ПОСТОВ",
        "templates":["rubezh_endgame_bastion","rubezh_endgame_perimeter_supply","rubezh_endgame_patrol_grid"],
        "effect":"rubezh_patrol_grid","effect_name":"ПАТРУЛЬНАЯ СЕТЬ"
    },
    "mechanics":{
        "id":"mechanics_network","name":"РЕМОНТНЫЙ КОНТУР",
        "templates":["mechanics_endgame_sever","mechanics_endgame_vector","mechanics_endgame_repair_network"],
        "effect":"mechanics_repair_network","effect_name":"РЕМОНТНЫЙ КОНТУР"
    },
    "lazaret":{
        "id":"lazaret_network","name":"МЕДИЦИНСКАЯ СЕТЬ",
        "templates":["lazaret_endgame_clinical_complex","lazaret_endgame_sterile_reserve","lazaret_endgame_medical_network"],
        "effect":"lazaret_medical_network","effect_name":"МЕДИЦИНСКИЙ РЕЗЕРВ"
    }
}

const EFFECTS = {
    "perron_exchange":{
        "faction":"perron","name":"ОБЩИЙ ОБМЕННЫЙ ФОНД",
        "daily_resources":{"food":0.45,"security":0.10},
        "market_categories":["food","water","household"],"buy_factor":0.96,"sell_factor":1.03,"restock_factor":1.20,
        "reserve_bonus":{"emergency_ration":2,"water":4},
        "relations":{"lazaret":12,"rubezh":-6}
    },
    "rubezh_patrol_grid":{
        "faction":"rubezh","name":"ПАТРУЛЬНАЯ СЕТЬ",
        "daily_resources":{"security":0.45,"technical":0.10},
        "market_categories":["ammo","weapon","armor","security"],"buy_factor":0.96,"sell_factor":1.03,"restock_factor":1.20,
        "reserve_bonus":{"ammo_762":8,"ammo_545":8,"military_vest":1},
        "relations":{"mechanics":10,"perron":-6}
    },
    "mechanics_repair_network":{
        "faction":"mechanics","name":"РЕМОНТНЫЙ КОНТУР",
        "daily_resources":{"technical":0.50,"security":0.08},
        "market_categories":["parts","tools","electronics","technical","fuel"],"buy_factor":0.96,"sell_factor":1.03,"restock_factor":1.25,
        "reserve_bonus":{"water_filter":2,"akm_extmag":1,"suppressor":1},
        "relations":{"rubezh":10,"perron":-5}
    },
    "lazaret_medical_network":{
        "faction":"lazaret","name":"МЕДИЦИНСКИЙ РЕЗЕРВ",
        "daily_resources":{"medicine":0.50,"food":0.08},
        "market_categories":["medicine","medical","chemicals"],"buy_factor":0.96,"sell_factor":1.03,"restock_factor":1.25,
        "reserve_bonus":{"trauma_kit":1,"antibiotics":2},
        "relations":{"perron":12,"rubezh":-8}
    }
}

static func default_state() -> Dictionary:
    var chains = {}
    for faction_id in CHAINS.keys():
        chains[faction_id] = {"progress":0,"completed":[],"finalized":false,"final_day":0}
    return {"chains":chains,"effects":{},"history":[]}

static func sanitize_state(raw) -> Dictionary:
    var clean = default_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    var incoming_chains = raw.get("chains",{})
    if typeof(incoming_chains) == TYPE_DICTIONARY:
        for faction_id in CHAINS.keys():
            var src = incoming_chains.get(faction_id,{})
            if typeof(src) != TYPE_DICTIONARY:
                continue
            var dst = clean["chains"][faction_id]
            var max_steps = CHAINS[faction_id].get("templates",[]).size()
            dst["progress"] = clamp(int(src.get("progress",0)),0,max_steps)
            var completed = src.get("completed",[])
            if typeof(completed) == TYPE_ARRAY:
                var safe_completed = []
                for template_id in completed:
                    if str(template_id) in CHAINS[faction_id].get("templates",[]) and str(template_id) not in safe_completed:
                        safe_completed.append(str(template_id))
                dst["completed"] = safe_completed
            dst["finalized"] = bool(src.get("finalized",false)) or int(dst["progress"]) >= max_steps
            dst["final_day"] = max(0,int(src.get("final_day",0)))
            clean["chains"][faction_id] = dst
    var effects = raw.get("effects",{})
    if typeof(effects) == TYPE_DICTIONARY:
        for effect_id in EFFECTS.keys():
            if bool(effects.get(effect_id,false)):
                clean["effects"][effect_id] = true
    # Reconstruct final effects from chain completion for forward/backward robustness.
    for faction_id in CHAINS.keys():
        if bool(clean["chains"][faction_id].get("finalized",false)):
            clean["effects"][str(CHAINS[faction_id].get("effect",""))] = true
    var history = raw.get("history",[])
    if typeof(history) == TYPE_ARRAY:
        clean["history"] = history.duplicate(true)
        while clean["history"].size() > HISTORY_LIMIT:
            clean["history"].remove_at(0)
    return clean

static func ensure_state(state:Dictionary) -> void:
    state["faction_endgame"] = sanitize_state(state.get("faction_endgame",{}))

static func chain(faction_id:String) -> Dictionary:
    return CHAINS.get(faction_id,{}).duplicate(true)

static func chain_state(state:Dictionary,faction_id:String) -> Dictionary:
    ensure_state(state)
    var row = state["faction_endgame"].get("chains",{}).get(faction_id,{})
    return row.duplicate(true) if typeof(row) == TYPE_DICTIONARY else {}

static func progress(state:Dictionary,faction_id:String) -> int:
    return int(chain_state(state,faction_id).get("progress",0))

static func is_finalized(state:Dictionary,faction_id:String) -> bool:
    return bool(chain_state(state,faction_id).get("finalized",false))

static func effect_active(state:Dictionary,effect_id:String) -> bool:
    ensure_state(state)
    return bool(state["faction_endgame"].get("effects",{}).get(effect_id,false))

static func faction_effect_active(state:Dictionary,faction_id:String) -> bool:
    var data = CHAINS.get(faction_id,{})
    return not data.is_empty() and effect_active(state,str(data.get("effect","")))

static func _resource_value(state:Dictionary,faction_id:String,resource_id:String) -> float:
    return float(state.get("factions",{}).get(faction_id,{}).get("resources",{}).get(resource_id,0.0))

static func template_available(state:Dictionary,template:Dictionary) -> bool:
    var meta = template.get("endgame",{})
    if typeof(meta) != TYPE_DICTIONARY or meta.is_empty():
        return true
    var faction_id = str(template.get("faction",""))
    if faction_id == "" or not CHAINS.has(faction_id):
        return false
    ensure_state(state)
    var chain_row = state["faction_endgame"]["chains"].get(faction_id,{})
    if bool(chain_row.get("finalized",false)):
        return false
    var step = int(meta.get("step",0))
    if step <= 0 or int(chain_row.get("progress",0)) != step - 1:
        return false
    var required_resources = meta.get("required_resources",{})
    if typeof(required_resources) == TYPE_DICTIONARY:
        for resource_id in required_resources.keys():
            if str(resource_id) not in RESOURCE_KEYS:
                continue
            if _resource_value(state,faction_id,str(resource_id)) < float(required_resources[resource_id]):
                return false
    return true

static func _adjust_resource(state:Dictionary,faction_id:String,resource_id:String,amount:float) -> void:
    if not state.get("factions",{}).has(faction_id) or resource_id not in RESOURCE_KEYS:
        return
    var record = state["factions"][faction_id]
    var resources = record.get("resources",{})
    resources[resource_id] = clamp(float(resources.get(resource_id,0.0)) + amount,0.0,100.0)
    record["resources"] = resources
    state["factions"][faction_id] = record

static func apply_contract_outcome(state:Dictionary,contract:Dictionary,world_day:int) -> Dictionary:
    var meta = contract.get("endgame",{})
    if typeof(meta) != TYPE_DICTIONARY or meta.is_empty():
        return {}
    var faction_id = str(contract.get("faction",""))
    if faction_id == "" or not CHAINS.has(faction_id):
        return {}
    ensure_state(state)
    var row = state["faction_endgame"]["chains"][faction_id]
    var step = int(meta.get("step",0))
    if step <= 0 or int(row.get("progress",0)) != step - 1:
        return {}
    var template_id = str(contract.get("template_id",""))
    var completed = row.get("completed",[])
    if typeof(completed) != TYPE_ARRAY:
        completed = []
    if template_id not in completed:
        completed.append(template_id)
    row["completed"] = completed
    row["progress"] = step

    var result = {"faction":faction_id,"step":step,"chain":str(CHAINS[faction_id].get("id","")),"final":false,"effect":""}
    var max_steps = CHAINS[faction_id].get("templates",[]).size()
    if step >= max_steps:
        row["finalized"] = true
        row["final_day"] = max(1,world_day)
        var effect_id = str(CHAINS[faction_id].get("effect",""))
        state["faction_endgame"]["effects"][effect_id] = true
        result["final"] = true
        result["effect"] = effect_id
        var effect = EFFECTS.get(effect_id,{})
        var relations = effect.get("relations",{})
        if typeof(relations) == TYPE_DICTIONARY:
            for other_id in relations.keys():
                FactionRelations.adjust_relation(state,faction_id,str(other_id),int(relations[other_id]),world_day,"endgame:%s" % effect_id)
        # Finalization gives a small one-time stabilization on top of the contract reward.
        var daily = effect.get("daily_resources",{})
        if typeof(daily) == TYPE_DICTIONARY:
            for resource_id in daily.keys():
                _adjust_resource(state,faction_id,str(resource_id),float(daily[resource_id]) * 6.0)
    state["faction_endgame"]["chains"][faction_id] = row
    var history = state["faction_endgame"].get("history",[])
    history.append({"day":max(1,world_day),"faction":faction_id,"template_id":template_id,"step":step,"final":bool(result["final"]),"effect":str(result["effect"])})
    while history.size() > HISTORY_LIMIT:
        history.remove_at(0)
    state["faction_endgame"]["history"] = history
    return result

static func warning(state:Dictionary,contract:Dictionary) -> String:
    var meta = contract.get("endgame",{})
    if typeof(meta) != TYPE_DICTIONARY or meta.is_empty():
        return ""
    var faction_id = str(contract.get("faction",""))
    var data = CHAINS.get(faction_id,{})
    var step = int(meta.get("step",0))
    var max_steps = data.get("templates",[]).size()
    if step < max_steps:
        return "ЦЕПОЧКА %s: этап %d/%d. Следующий этап откроется после выполнения и стабилизации нужных ресурсов." % [str(data.get("name","ФРАКЦИИ")),step,max_steps]
    var effect_id = str(data.get("effect",""))
    var effect = EFFECTS.get(effect_id,{})
    var relation_parts = []
    var relations = effect.get("relations",{})
    if typeof(relations) == TYPE_DICTIONARY:
        for other_id in relations.keys():
            var short_name = str(FactionCatalog.faction(str(other_id)).get("short_name",other_id))
            var delta = int(relations[other_id])
            relation_parts.append("%s %s%d" % [short_name,"+" if delta >= 0 else "",delta])
    var relation_text = ""
    if not relation_parts.is_empty():
        relation_text = " Отношения: %s." % ", ".join(relation_parts)
    return "ФИНАЛ ЦЕПОЧКИ: выполнение необратимо закрепит эффект «%s».%s" % [str(effect.get("name",data.get("effect_name",""))),relation_text]

static func effect_for_faction(state:Dictionary,faction_id:String) -> Dictionary:
    var data = CHAINS.get(faction_id,{})
    if data.is_empty():
        return {}
    var effect_id = str(data.get("effect",""))
    if not effect_active(state,effect_id):
        return {}
    return EFFECTS.get(effect_id,{}).duplicate(true)

static func market_buy_factor(state:Dictionary,faction_id:String,item_id:String) -> float:
    var effect = effect_for_faction(state,faction_id)
    if effect.is_empty():
        return 1.0
    var category = FactionCatalog.item_category(item_id)
    if category in effect.get("market_categories",[]):
        return float(effect.get("buy_factor",1.0))
    return 1.0

static func market_sell_factor(state:Dictionary,faction_id:String,item_id:String) -> float:
    var effect = effect_for_faction(state,faction_id)
    if effect.is_empty():
        return 1.0
    var category = FactionCatalog.item_category(item_id)
    if category in effect.get("market_categories",[]):
        return float(effect.get("sell_factor",1.0))
    return 1.0

static func restock_factor(state:Dictionary,faction_id:String,item_id:String) -> float:
    var effect = effect_for_faction(state,faction_id)
    if effect.is_empty():
        return 1.0
    var category = FactionCatalog.item_category(item_id)
    if category in effect.get("market_categories",[]):
        return float(effect.get("restock_factor",1.0))
    return 1.0

static func reserve_bonus(state:Dictionary,faction_id:String,item_id:String) -> int:
    var effect = effect_for_faction(state,faction_id)
    if effect.is_empty():
        return 0
    return max(0,int(effect.get("reserve_bonus",{}).get(item_id,0)))

static func apply_daily_effects(state:Dictionary) -> void:
    ensure_state(state)
    for faction_id in CHAINS.keys():
        var effect = effect_for_faction(state,str(faction_id))
        if effect.is_empty():
            continue
        var bonuses = effect.get("daily_resources",{})
        if typeof(bonuses) != TYPE_DICTIONARY:
            continue
        for resource_id in bonuses.keys():
            _adjust_resource(state,str(faction_id),str(resource_id),float(bonuses[resource_id]))

static func summary(state:Dictionary,faction_id:String) -> String:
    if not CHAINS.has(faction_id):
        return ""
    var data = CHAINS[faction_id]
    var row = chain_state(state,faction_id)
    var max_steps = data.get("templates",[]).size()
    if bool(row.get("finalized",false)):
        return "%s: ЗАВЕРШЕНО • %s" % [str(data.get("name","ЦЕПОЧКА")),str(data.get("effect_name","ПОСТОЯННЫЙ ЭФФЕКТ"))]
    return "%s: %d/%d" % [str(data.get("name","ЦЕПОЧКА")),int(row.get("progress",0)),max_steps]
