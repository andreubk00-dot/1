extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")

const OFFER_SLOTS_PER_FACTION = 2
const OFFER_LIFETIME_DAYS = 3
const HISTORY_COOLDOWN_DAYS = 5
const MAX_ACTIVE = 4
const MAX_HISTORY = 64

static func default_contract_state() -> Dictionary:
    return {"offers":{},"active":{},"last_refresh_day":{},"serial":0}

static func sanitize_contract_state(raw) -> Dictionary:
    var clean = default_contract_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    clean["serial"] = max(0,int(raw.get("serial",0)))
    var active = raw.get("active",{})
    if typeof(active) == TYPE_DICTIONARY:
        for raw_id in active.keys():
            var instance = _sanitize_instance(active[raw_id])
            if not instance.is_empty():
                clean["active"][str(instance.get("id",raw_id))] = instance
    var offers = raw.get("offers",{})
    if typeof(offers) == TYPE_DICTIONARY:
        for faction_id in FactionCatalog.ids():
            var rows = offers.get(faction_id,[])
            if typeof(rows) != TYPE_ARRAY:
                continue
            var kept = []
            for raw_instance in rows:
                var instance = _sanitize_instance(raw_instance)
                if not instance.is_empty() and str(instance.get("faction","")) == faction_id:
                    kept.append(instance)
            clean["offers"][faction_id] = kept
    var refresh = raw.get("last_refresh_day",{})
    if typeof(refresh) == TYPE_DICTIONARY:
        for faction_id in FactionCatalog.ids():
            clean["last_refresh_day"][faction_id] = max(0,int(refresh.get(faction_id,0)))
    return clean

static func _sanitize_instance(raw) -> Dictionary:
    if typeof(raw) != TYPE_DICTIONARY:
        return {}
    var template_id = str(raw.get("template_id",""))
    var template = ContractCatalog.template(template_id)
    if template.is_empty():
        return {}
    var instance = template.duplicate(true)
    instance["id"] = str(raw.get("id",template_id))
    instance["created_day"] = max(1,int(raw.get("created_day",1)))
    instance["offer_expires_day"] = max(instance["created_day"],int(raw.get("offer_expires_day",instance["created_day"] + OFFER_LIFETIME_DAYS)))
    instance["accepted_day"] = max(0,int(raw.get("accepted_day",0)))
    return instance

static func ensure_state(state:Dictionary,world_day:int) -> void:
    state["contracts"] = sanitize_contract_state(state.get("contracts",{}))
    refresh_offers(state,world_day,false)

static func _history_recent(state:Dictionary,template_id:String,world_day:int) -> bool:
    var history = state.get("contract_history",[])
    if typeof(history) != TYPE_ARRAY:
        return false
    for row in history:
        if typeof(row) != TYPE_DICTIONARY:
            continue
        if str(row.get("template_id","")) != template_id:
            continue
        if world_day - int(row.get("day",0)) < HISTORY_COOLDOWN_DAYS:
            return true
    return false

static func _template_active(state:Dictionary,template_id:String) -> bool:
    var active = state.get("contracts",{}).get("active",{})
    if typeof(active) != TYPE_DICTIONARY:
        return false
    for row in active.values():
        if str(row.get("template_id","")) == template_id:
            return true
    return false

static func _candidate_score(state:Dictionary,faction_id:String,template:Dictionary) -> float:
    var need_key = str(template.get("need_key","technical"))
    var resource = float(state.get("factions",{}).get(faction_id,{}).get("resources",{}).get(need_key,50.0))
    # Lower settlement resource = higher priority. Authored order is used as a stable tie break.
    return 100.0 - resource

static func _sorted_candidates(state:Dictionary,faction_id:String,world_day:int) -> Array:
    var rep = FactionEconomy.reputation(state,faction_id)
    var candidates = []
    for template in ContractCatalog.templates_for_faction(faction_id):
        var template_id = str(template.get("template_id",""))
        if rep < int(template.get("min_rep",0)):
            continue
        if _template_active(state,template_id) or _history_recent(state,template_id,world_day):
            continue
        var route = template.get("reward",{}).get("route",{})
        if typeof(route) == TYPE_DICTIONARY and not route.is_empty():
            var route_id = str(route.get("id",""))
            if route_id != "" and str(state.get("world_routes",{}).get(route_id,{}).get("state","")) == "open":
                continue
        var entry = template.duplicate(true)
        entry["priority_score"] = _candidate_score(state,faction_id,template)
        candidates.append(entry)
    candidates.sort_custom(func(a,b):
        var sa = float(a.get("priority_score",0.0))
        var sb = float(b.get("priority_score",0.0))
        if abs(sa - sb) > 0.001:
            return sa > sb
        return str(a.get("template_id","")) < str(b.get("template_id",""))
    )
    return candidates

static func _new_instance(state:Dictionary,template:Dictionary,world_day:int) -> Dictionary:
    var contracts = state["contracts"]
    contracts["serial"] = int(contracts.get("serial",0)) + 1
    state["contracts"] = contracts
    var instance = template.duplicate(true)
    instance.erase("priority_score")
    instance["id"] = "%s:%d:%d" % [str(template.get("template_id","contract")),world_day,int(contracts["serial"])]
    instance["created_day"] = max(1,world_day)
    instance["offer_expires_day"] = max(1,world_day) + OFFER_LIFETIME_DAYS
    instance["accepted_day"] = 0
    return instance

static func refresh_offers(state:Dictionary,world_day:int,force:bool = false) -> void:
    if not state.has("contracts") or typeof(state.get("contracts")) != TYPE_DICTIONARY:
        state["contracts"] = default_contract_state()
    var contracts = state["contracts"]
    if not contracts.has("offers") or typeof(contracts["offers"]) != TYPE_DICTIONARY:
        contracts["offers"] = {}
    if not contracts.has("last_refresh_day") or typeof(contracts["last_refresh_day"]) != TYPE_DICTIONARY:
        contracts["last_refresh_day"] = {}
    state["contracts"] = contracts

    for faction_id in FactionCatalog.ids():
        var current = state["contracts"]["offers"].get(faction_id,[])
        if typeof(current) != TYPE_ARRAY:
            current = []
        var kept = []
        for row in current:
            if typeof(row) != TYPE_DICTIONARY:
                continue
            if force or world_day > int(row.get("offer_expires_day",0)):
                continue
            if _template_active(state,str(row.get("template_id",""))):
                continue
            kept.append(row)
        var candidates = _sorted_candidates(state,faction_id,world_day)
        var offered_templates = []
        for row in kept:
            offered_templates.append(str(row.get("template_id","")))
        for template in candidates:
            if kept.size() >= OFFER_SLOTS_PER_FACTION:
                break
            var template_id = str(template.get("template_id",""))
            if template_id in offered_templates:
                continue
            kept.append(_new_instance(state,template,world_day))
            offered_templates.append(template_id)
        state["contracts"]["offers"][faction_id] = kept
        state["contracts"]["last_refresh_day"][faction_id] = max(1,world_day)

static func offers_for_faction(state:Dictionary,faction_id:String,world_day:int) -> Array:
    ensure_state(state,world_day)
    return state["contracts"]["offers"].get(faction_id,[]).duplicate(true)

static func active_for_faction(state:Dictionary,faction_id:String) -> Array:
    var out = []
    var active = state.get("contracts",{}).get("active",{})
    if typeof(active) != TYPE_DICTIONARY:
        return out
    for row in active.values():
        if str(row.get("faction","")) == faction_id:
            out.append(row.duplicate(true))
    out.sort_custom(func(a,b): return int(a.get("accepted_day",0)) < int(b.get("accepted_day",0)))
    return out

static func contract_by_id(state:Dictionary,contract_id:String) -> Dictionary:
    var active = state.get("contracts",{}).get("active",{})
    if typeof(active) == TYPE_DICTIONARY and active.has(contract_id):
        return active[contract_id].duplicate(true)
    var offers = state.get("contracts",{}).get("offers",{})
    if typeof(offers) == TYPE_DICTIONARY:
        for rows in offers.values():
            if typeof(rows) != TYPE_ARRAY:
                continue
            for row in rows:
                if str(row.get("id","")) == contract_id:
                    return row.duplicate(true)
    return {}

static func accept(state:Dictionary,contract_id:String,world_day:int) -> Dictionary:
    ensure_state(state,world_day)
    var active = state["contracts"]["active"]
    if active.size() >= MAX_ACTIVE:
        return {"ok":false,"reason":"Одновременно можно вести не больше четырёх контрактов."}
    for faction_id in FactionCatalog.ids():
        var rows = state["contracts"]["offers"].get(faction_id,[])
        for i in range(rows.size()):
            var row = rows[i]
            if str(row.get("id","")) != contract_id:
                continue
            for existing in active.values():
                if str(existing.get("faction","")) == faction_id:
                    return {"ok":false,"reason":"У этой фракции уже есть активный контракт."}
            row["accepted_day"] = max(1,world_day)
            active[contract_id] = row
            rows.remove_at(i)
            state["contracts"]["offers"][faction_id] = rows
            state["contracts"]["active"] = active
            return {"ok":true,"contract":row.duplicate(true)}
    return {"ok":false,"reason":"Предложение больше недоступно."}

static func abandon(state:Dictionary,contract_id:String,world_day:int) -> bool:
    var active = state.get("contracts",{}).get("active",{})
    if typeof(active) != TYPE_DICTIONARY or not active.has(contract_id):
        return false
    var row = active[contract_id]
    active.erase(contract_id)
    state["contracts"]["active"] = active
    _append_history(state,row,world_day,"abandoned")
    return true

static func _inventory_count(inventory_counts:Dictionary,item_id:String) -> int:
    return max(0,int(inventory_counts.get(item_id,0)))

static func satisfied_requirement_index(contract:Dictionary,inventory_counts:Dictionary) -> int:
    if str(contract.get("kind","")) != "delivery":
        return -1
    var alternatives = contract.get("requirements",[])
    if typeof(alternatives) != TYPE_ARRAY:
        return -1
    for i in range(alternatives.size()):
        var option = alternatives[i]
        if typeof(option) != TYPE_ARRAY:
            continue
        var ok = true
        for req in option:
            if _inventory_count(inventory_counts,str(req.get("id",""))) < int(req.get("qty",0)):
                ok = false
                break
        if ok:
            return i
    return -1

static func requirements_for_completion(contract:Dictionary,inventory_counts:Dictionary) -> Array:
    var index = satisfied_requirement_index(contract,inventory_counts)
    if index < 0:
        return []
    return contract.get("requirements",[])[index].duplicate(true)

static func can_complete(contract:Dictionary,inventory_counts:Dictionary,discovered_pois:Dictionary) -> bool:
    var kind = str(contract.get("kind",""))
    if kind == "delivery":
        return satisfied_requirement_index(contract,inventory_counts) >= 0
    if kind == "discover_poi":
        return bool(discovered_pois.get(str(contract.get("poi_id","")),false))
    return false

static func _append_history(state:Dictionary,contract:Dictionary,world_day:int,status:String) -> void:
    var history = state.get("contract_history",[])
    if typeof(history) != TYPE_ARRAY:
        history = []
    history.append({
        "template_id":str(contract.get("template_id","")),
        "contract_id":str(contract.get("id","")),
        "faction":str(contract.get("faction","")),
        "day":max(1,world_day),
        "status":status
    })
    while history.size() > MAX_HISTORY:
        history.remove_at(0)
    state["contract_history"] = history

static func complete(state:Dictionary,contract_id:String,world_day:int) -> Dictionary:
    var active = state.get("contracts",{}).get("active",{})
    if typeof(active) != TYPE_DICTIONARY or not active.has(contract_id):
        return {"ok":false,"reason":"Контракт не активен."}
    var contract = active[contract_id]
    var faction_id = str(contract.get("faction",""))
    var reward = contract.get("reward",{})
    FactionEconomy.add_tickets(state,int(reward.get("tickets",0)))
    FactionEconomy.add_reputation(state,faction_id,int(reward.get("reputation",0)))
    var resources = reward.get("resources",{})
    if typeof(resources) == TYPE_DICTIONARY:
        for resource_id in resources.keys():
            FactionEconomy.adjust_resource(state,faction_id,str(resource_id),float(resources[resource_id]))
    var route = reward.get("route",{})
    var opened_route = ""
    if typeof(route) == TYPE_DICTIONARY and not route.is_empty():
        opened_route = str(route.get("id",""))
        if opened_route != "":
            var route_record = route.duplicate(true)
            route_record["state"] = "open"
            route_record["opened_day"] = max(1,world_day)
            route_record["source_contract"] = str(contract.get("template_id",""))
            state["world_routes"][opened_route] = route_record
    if state.get("factions",{}).has(faction_id):
        state["factions"][faction_id]["completed_contracts"] = int(state["factions"][faction_id].get("completed_contracts",0)) + 1
    active.erase(contract_id)
    state["contracts"]["active"] = active
    _append_history(state,contract,world_day,"completed")
    return {
        "ok":true,"tickets":int(reward.get("tickets",0)),"reputation":int(reward.get("reputation",0)),
        "opened_route":opened_route,"faction":faction_id,"title":str(contract.get("title","КОНТРАКТ"))
    }

static func requirement_text(contract:Dictionary,item_names:Dictionary = {}) -> String:
    var kind = str(contract.get("kind",""))
    if kind == "discover_poi":
        return "Разведка: %s" % str(contract.get("hint","Найти указанный объект."))
    var alternatives = contract.get("requirements",[])
    var option_texts = []
    if typeof(alternatives) == TYPE_ARRAY:
        for option in alternatives:
            if typeof(option) != TYPE_ARRAY:
                continue
            var parts = []
            for req in option:
                var item_id = str(req.get("id",""))
                parts.append("%s ×%d" % [str(item_names.get(item_id,item_id)),int(req.get("qty",0))])
            option_texts.append(" + ".join(parts))
    return " ИЛИ ".join(option_texts)

static func progress_text(contract:Dictionary,inventory_counts:Dictionary,discovered_pois:Dictionary,item_names:Dictionary = {}) -> String:
    var kind = str(contract.get("kind",""))
    if kind == "discover_poi":
        var known = bool(discovered_pois.get(str(contract.get("poi_id","")),false))
        return "ГОТОВО К СДАЧЕ" if known else "Объект ещё не разведан"
    var alternatives = contract.get("requirements",[])
    var option_texts = []
    if typeof(alternatives) == TYPE_ARRAY:
        for option in alternatives:
            if typeof(option) != TYPE_ARRAY:
                continue
            var parts = []
            for req in option:
                var item_id = str(req.get("id",""))
                var need = int(req.get("qty",0))
                var have = _inventory_count(inventory_counts,item_id)
                parts.append("%s %d/%d" % [str(item_names.get(item_id,item_id)),min(have,need),need])
            option_texts.append(" + ".join(parts))
    return "  ИЛИ  ".join(option_texts)
