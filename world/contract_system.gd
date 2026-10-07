extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const FactionRelations = preload("res://world/faction_relations.gd")
const SettlementCrisis = preload("res://world/settlement_crisis.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const FactionNpcState = preload("res://world/faction_npc_state.gd")

const OFFER_SLOTS_PER_FACTION = 2
const OFFER_LIFETIME_DAYS = 3
const HISTORY_COOLDOWN_DAYS = 5
const MAX_ACTIVE = 4
const MAX_HISTORY = 64

static func default_contract_state() -> Dictionary:
    return {
        "offers":{},"personal_offers":{},"active":{},
        "last_refresh_day":{},"personal_last_refresh_day":{},"serial":0
    }

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
    var personal_offers = raw.get("personal_offers",{})
    if typeof(personal_offers) == TYPE_DICTIONARY:
        for npc_id in ContractCatalog.personal_board_npcs():
            var rows = personal_offers.get(npc_id,[])
            if typeof(rows) != TYPE_ARRAY:
                continue
            var kept = []
            for raw_instance in rows:
                var instance = _sanitize_instance(raw_instance)
                if not instance.is_empty() and str(instance.get("owner_npc_id","")) == npc_id:
                    kept.append(instance)
            clean["personal_offers"][npc_id] = kept
    var refresh = raw.get("last_refresh_day",{})
    if typeof(refresh) == TYPE_DICTIONARY:
        for faction_id in FactionCatalog.ids():
            clean["last_refresh_day"][faction_id] = max(0,int(refresh.get(faction_id,0)))
    var personal_refresh = raw.get("personal_last_refresh_day",{})
    if typeof(personal_refresh) == TYPE_DICTIONARY:
        for npc_id in ContractCatalog.personal_board_npcs():
            clean["personal_last_refresh_day"][npc_id] = max(0,int(personal_refresh.get(npc_id,0)))
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
    instance["deadline_day"] = max(0,int(raw.get("deadline_day",0)))
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

static func _history_has_status(state:Dictionary,template_id:String,status:String) -> bool:
    var history = state.get("contract_history",[])
    if typeof(history) != TYPE_ARRAY:
        return false
    for row in history:
        if typeof(row) != TYPE_DICTIONARY:
            continue
        if str(row.get("template_id","")) == template_id and str(row.get("status","")) == status:
            return true
    return false

static func _personal_template_available(state:Dictionary,template:Dictionary,world_day:int) -> bool:
    var template_id = str(template.get("template_id",""))
    var owner_npc_id = str(template.get("owner_npc_id",""))
    if template_id == "" or owner_npc_id == "":
        return false
    if not FactionNpcState.service_available(state,owner_npc_id,world_day):
        return false
    # Authored personal stages are one-shot once completed. Failure/abandon can be
    # retried after the normal history cooldown, so a deadline hurts without soft-locking a chain.
    if _history_has_status(state,template_id,"completed"):
        return false
    var required = template.get("requires_completed",[])
    if typeof(required) == TYPE_ARRAY:
        for raw_required in required:
            if not _history_has_status(state,str(raw_required),"completed"):
                return false
    return true

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
    # Lower settlement resource = higher priority. Emergency contracts jump to the front
    # only while their actual resource is in shortage/crisis.
    var score = 100.0 - resource + float(template.get("priority_bonus",0.0))
    if bool(template.get("crisis_only",false)):
        score += SettlementCrisis.crisis_priority_bonus(state,faction_id,need_key)
    return score

static func _sorted_candidates(state:Dictionary,faction_id:String,world_day:int) -> Array:
    var rep = FactionEconomy.reputation(state,faction_id)
    var candidates = []
    for template in ContractCatalog.templates_for_faction(faction_id):
        var template_id = str(template.get("template_id",""))
        if rep < int(template.get("min_rep",0)):
            continue
        if bool(template.get("crisis_only",false)) and not SettlementCrisis.crisis_contract_available(state,faction_id,str(template.get("need_key","technical"))):
            continue
        if not FactionEndgame.template_available(state,template):
            continue
        var conflict = template.get("conflict",{})
        if typeof(conflict) == TYPE_DICTIONARY and not conflict.is_empty():
            var conflict_id = str(conflict.get("id",""))
            if conflict_id != "" and FactionRelations.conflict_resolved(state,conflict_id):
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

static func _sorted_personal_candidates(state:Dictionary,npc_id:String,world_day:int) -> Array:
    var faction_id = ContractCatalog.board_faction(npc_id)
    if faction_id == "":
        return []
    var rep = FactionEconomy.reputation(state,faction_id)
    var candidates = []
    for template in ContractCatalog.personal_templates_for_npc(npc_id):
        var template_id = str(template.get("template_id",""))
        if rep < int(template.get("min_rep",0)):
            continue
        if not _personal_template_available(state,template,world_day):
            continue
        if _template_active(state,template_id) or _history_recent(state,template_id,world_day):
            continue
        var route = template.get("reward",{}).get("route",{})
        if typeof(route) == TYPE_DICTIONARY and not route.is_empty():
            var route_id = str(route.get("id",""))
            if route_id != "" and str(state.get("world_routes",{}).get(route_id,{}).get("state","")) == "open":
                continue
        candidates.append(template.duplicate(true))
    candidates.sort_custom(func(a,b):
        var sa = int(a.get("chain_step",0))
        var sb = int(b.get("chain_step",0))
        if sa != sb:
            return sa < sb
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
    var offer_days = max(1,int(template.get("offer_lifetime_days",OFFER_LIFETIME_DAYS)))
    instance["offer_expires_day"] = max(1,world_day) + offer_days
    instance["accepted_day"] = 0
    instance["deadline_day"] = 0
    return instance

static func refresh_offers(state:Dictionary,world_day:int,force:bool = false) -> void:
    if not state.has("contracts") or typeof(state.get("contracts")) != TYPE_DICTIONARY:
        state["contracts"] = default_contract_state()
    var contracts = state["contracts"]
    if not contracts.has("offers") or typeof(contracts["offers"]) != TYPE_DICTIONARY:
        contracts["offers"] = {}
    if not contracts.has("last_refresh_day") or typeof(contracts["last_refresh_day"]) != TYPE_DICTIONARY:
        contracts["last_refresh_day"] = {}
    if not contracts.has("personal_offers") or typeof(contracts["personal_offers"]) != TYPE_DICTIONARY:
        contracts["personal_offers"] = {}
    if not contracts.has("personal_last_refresh_day") or typeof(contracts["personal_last_refresh_day"]) != TYPE_DICTIONARY:
        contracts["personal_last_refresh_day"] = {}
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
    refresh_personal_offers(state,world_day,force)

static func refresh_personal_offers(state:Dictionary,world_day:int,force:bool = false) -> void:
    var contracts = state.get("contracts",{})
    if typeof(contracts) != TYPE_DICTIONARY:
        contracts = default_contract_state()
    if typeof(contracts.get("personal_offers",{})) != TYPE_DICTIONARY:
        contracts["personal_offers"] = {}
    if typeof(contracts.get("personal_last_refresh_day",{})) != TYPE_DICTIONARY:
        contracts["personal_last_refresh_day"] = {}
    state["contracts"] = contracts
    for npc_id in ContractCatalog.personal_board_npcs():
        if not FactionNpcState.service_available(state,npc_id,world_day):
            state["contracts"]["personal_offers"][npc_id] = []
            state["contracts"]["personal_last_refresh_day"][npc_id] = max(1,world_day)
            continue
        var current = state["contracts"]["personal_offers"].get(npc_id,[])
        if typeof(current) != TYPE_ARRAY:
            current = []
        var kept = []
        for row in current:
            if typeof(row) != TYPE_DICTIONARY:
                continue
            var template = ContractCatalog.template(str(row.get("template_id","")))
            if force:
                continue
            if world_day > int(row.get("offer_expires_day",0)):
                _append_history(state,row,world_day,"offer_expired")
                continue
            if template.is_empty() or not _personal_template_available(state,template,world_day):
                continue
            if _template_active(state,str(row.get("template_id",""))):
                continue
            kept.append(row)
        if kept.is_empty():
            var candidates = _sorted_personal_candidates(state,npc_id,world_day)
            if not candidates.is_empty():
                kept.append(_new_instance(state,candidates[0],world_day))
        state["contracts"]["personal_offers"][npc_id] = kept
        state["contracts"]["personal_last_refresh_day"][npc_id] = max(1,world_day)

static func offers_for_faction(state:Dictionary,faction_id:String,world_day:int) -> Array:
    ensure_state(state,world_day)
    return state["contracts"]["offers"].get(faction_id,[]).duplicate(true)

static func offers_for_npc(state:Dictionary,npc_id:String,world_day:int) -> Array:
    ensure_state(state,world_day)
    return state["contracts"].get("personal_offers",{}).get(npc_id,[]).duplicate(true)

static func offers_for_board(state:Dictionary,faction_id:String,npc_id:String,world_day:int) -> Array:
    if ContractCatalog.is_personal_board(npc_id):
        return offers_for_npc(state,npc_id,world_day)
    return offers_for_faction(state,faction_id,world_day)

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

static func active_for_npc(state:Dictionary,npc_id:String) -> Array:
    var out = []
    var active = state.get("contracts",{}).get("active",{})
    if typeof(active) != TYPE_DICTIONARY:
        return out
    for row in active.values():
        if str(row.get("owner_npc_id","")) == npc_id:
            out.append(row.duplicate(true))
    out.sort_custom(func(a,b): return int(a.get("accepted_day",0)) < int(b.get("accepted_day",0)))
    return out

static func active_for_board(state:Dictionary,faction_id:String,npc_id:String) -> Array:
    if ContractCatalog.is_personal_board(npc_id):
        return active_for_npc(state,npc_id)
    var out = []
    for row in active_for_faction(state,faction_id):
        if str(row.get("owner_npc_id","")) == "":
            out.append(row)
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
    var personal_offers = state.get("contracts",{}).get("personal_offers",{})
    if typeof(personal_offers) == TYPE_DICTIONARY:
        for rows in personal_offers.values():
            if typeof(rows) != TYPE_ARRAY:
                continue
            for row in rows:
                if str(row.get("id","")) == contract_id:
                    return row.duplicate(true)
    return {}

static func _conflict_id(contract:Dictionary) -> String:
    var conflict = contract.get("conflict",{})
    if typeof(conflict) != TYPE_DICTIONARY:
        return ""
    return str(conflict.get("id",""))

static func _remove_conflict_offers(state:Dictionary,conflict_id:String) -> void:
    if conflict_id == "":
        return
    var offers = state.get("contracts",{}).get("offers",{})
    if typeof(offers) != TYPE_DICTIONARY:
        return
    for faction_id in offers.keys():
        var rows = offers.get(faction_id,[])
        if typeof(rows) != TYPE_ARRAY:
            continue
        var kept = []
        for row in rows:
            if typeof(row) == TYPE_DICTIONARY and _conflict_id(row) == conflict_id:
                continue
            kept.append(row)
        offers[faction_id] = kept
    state["contracts"]["offers"] = offers

static func _penalty_summary(penalty:Dictionary) -> String:
    if typeof(penalty) != TYPE_DICTIONARY or penalty.is_empty():
        return "без системного штрафа"
    var parts = []
    var rep = int(penalty.get("reputation",0))
    if rep != 0:
        parts.append("%+d реп." % rep)
    var attitude = int(penalty.get("attitude",0))
    if attitude != 0:
        parts.append("%+d личное отношение" % attitude)
    var resources = penalty.get("resources",{})
    if typeof(resources) == TYPE_DICTIONARY:
        for raw_resource in resources.keys():
            var delta = float(resources[raw_resource])
            if abs(delta) > 0.001:
                parts.append("%+d %s" % [int(round(delta)),str(raw_resource)])
    return ", ".join(parts) if not parts.is_empty() else "без системного штрафа"

static func consequence_text(state:Dictionary,contract:Dictionary) -> String:
    var parts = []
    var conflict = FactionRelations.conflict_warning(state,contract)
    if conflict != "":
        parts.append(conflict)
    var endgame = FactionEndgame.warning(state,contract)
    if endgame != "":
        parts.append(endgame)
    if str(contract.get("owner_npc_id","")) != "":
        var deadline_day = int(contract.get("deadline_day",0))
        var lifetime = int(contract.get("active_lifetime_days",0))
        if deadline_day > 0:
            parts.append("ЛИЧНЫЙ СРОК: выполнить до конца дня %d. Просрочка: %s." % [deadline_day,_penalty_summary(contract.get("failure_penalty",{}))])
        elif lifetime > 0:
            parts.append("ЛИЧНЫЙ СРОК: %d дн. после принятия. Просрочка: %s." % [lifetime,_penalty_summary(contract.get("failure_penalty",{}))])
        var abandon_penalty = contract.get("abandon_penalty",{})
        if typeof(abandon_penalty) == TYPE_DICTIONARY and not abandon_penalty.is_empty():
            parts.append("ОТКАЗ ПОСЛЕ ПРИНЯТИЯ: %s." % _penalty_summary(abandon_penalty))
    return "\n".join(parts)

static func _apply_penalty(state:Dictionary,contract:Dictionary,penalty_key:String,world_day:int,history_kind:String) -> Dictionary:
    var penalty = contract.get(penalty_key,{})
    if typeof(penalty) != TYPE_DICTIONARY:
        penalty = {}
    var faction_id = str(contract.get("faction",""))
    var rep_delta = int(penalty.get("reputation",0))
    if rep_delta != 0:
        FactionEconomy.add_reputation(state,faction_id,rep_delta)
    var resource_deltas = {}
    var resources = penalty.get("resources",{})
    if typeof(resources) == TYPE_DICTIONARY:
        for raw_resource in resources.keys():
            var resource_id = str(raw_resource)
            var delta = float(resources[raw_resource])
            if abs(delta) <= 0.001:
                continue
            FactionEconomy.adjust_resource(state,faction_id,resource_id,delta)
            resource_deltas[resource_id] = delta
    var attitude_delta = int(penalty.get("attitude",0))
    var owner_npc_id = str(contract.get("owner_npc_id",""))
    if owner_npc_id != "":
        var action = "Отказ от личного поручения" if history_kind == "abandoned" else "Личное поручение просрочено"
        FactionNpcState.record_interaction(state,owner_npc_id,world_day,"personal_contract_" + history_kind,"%s «%s»." % [action,str(contract.get("title","КОНТРАКТ"))],attitude_delta)
    return {"reputation_delta":rep_delta,"attitude_delta":attitude_delta,"resource_deltas":resource_deltas}

static func _accept_instance(state:Dictionary,row:Dictionary,contract_id:String,world_day:int,source_key:String,source_id:String,index:int) -> Dictionary:
    var active = state["contracts"]["active"]
    var faction_id = str(row.get("faction",""))
    for existing in active.values():
        if str(existing.get("faction","")) == faction_id:
            return {"ok":false,"reason":"У этой фракции уже есть активный контракт."}
    var conflict_id = _conflict_id(row)
    if conflict_id != "":
        if FactionRelations.conflict_resolved(state,conflict_id):
            return {"ok":false,"reason":"Этот спор между фракциями уже решён."}
        for existing in active.values():
            if _conflict_id(existing) == conflict_id:
                return {"ok":false,"reason":"Уже принят противоположный контракт по этому спору. Сначала откажитесь от него."}
    var owner_npc_id = str(row.get("owner_npc_id",""))
    if owner_npc_id != "" and not FactionNpcState.service_available(state,owner_npc_id,world_day):
        return {"ok":false,"reason":"Автор поручения сейчас недоступен."}
    row["accepted_day"] = max(1,world_day)
    var lifetime = max(0,int(row.get("active_lifetime_days",0)))
    row["deadline_day"] = max(1,world_day) + lifetime if lifetime > 0 else 0
    active[contract_id] = row
    var source = state["contracts"].get(source_key,{})
    var rows = source.get(source_id,[])
    if typeof(rows) == TYPE_ARRAY and index >= 0 and index < rows.size():
        rows.remove_at(index)
        source[source_id] = rows
        state["contracts"][source_key] = source
    state["contracts"]["active"] = active
    if owner_npc_id != "":
        FactionNpcState.record_interaction(state,owner_npc_id,world_day,"personal_contract_accept","Принято личное поручение «%s»." % str(row.get("title","КОНТРАКТ")),1)
    return {"ok":true,"contract":row.duplicate(true)}

static func accept(state:Dictionary,contract_id:String,world_day:int) -> Dictionary:
    ensure_state(state,world_day)
    var active = state["contracts"]["active"]
    if active.size() >= MAX_ACTIVE:
        return {"ok":false,"reason":"Одновременно можно вести не больше четырёх контрактов."}
    for faction_id in FactionCatalog.ids():
        var rows = state["contracts"]["offers"].get(faction_id,[])
        for i in range(rows.size()):
            var row = rows[i]
            if str(row.get("id","")) == contract_id:
                return _accept_instance(state,row,contract_id,world_day,"offers",faction_id,i)
    for npc_id in ContractCatalog.personal_board_npcs():
        var rows = state["contracts"].get("personal_offers",{}).get(npc_id,[])
        for i in range(rows.size()):
            var row = rows[i]
            if str(row.get("id","")) == contract_id:
                return _accept_instance(state,row,contract_id,world_day,"personal_offers",npc_id,i)
    return {"ok":false,"reason":"Предложение больше недоступно."}

static func abandon_with_result(state:Dictionary,contract_id:String,world_day:int) -> Dictionary:
    var active = state.get("contracts",{}).get("active",{})
    if typeof(active) != TYPE_DICTIONARY or not active.has(contract_id):
        return {"ok":false,"reason":"Контракт уже недоступен."}
    var row = active[contract_id]
    active.erase(contract_id)
    state["contracts"]["active"] = active
    var penalty_result = {}
    if str(row.get("owner_npc_id","")) != "":
        penalty_result = _apply_penalty(state,row,"abandon_penalty",world_day,"abandoned")
    _append_history(state,row,world_day,"abandoned")
    return {"ok":true,"contract":row.duplicate(true),"penalty":penalty_result}

static func abandon(state:Dictionary,contract_id:String,world_day:int) -> bool:
    return bool(abandon_with_result(state,contract_id,world_day).get("ok",false))

static func daily_tick(state:Dictionary,world_day:int) -> Array:
    # Timed personal contracts fail only on an actual world-day rollover. Merely opening
    # a board or loading a save never advances a deadline. This keeps save/load deterministic.
    state["contracts"] = sanitize_contract_state(state.get("contracts",{}))
    var events = []
    var active = state["contracts"].get("active",{})
    if typeof(active) != TYPE_DICTIONARY:
        active = {}
    for raw_id in active.keys().duplicate():
        var contract_id = str(raw_id)
        var row = active.get(contract_id,{})
        if typeof(row) != TYPE_DICTIONARY:
            continue
        var owner_npc_id = str(row.get("owner_npc_id",""))
        if owner_npc_id == "":
            continue
        if not FactionNpcState.service_available(state,owner_npc_id,world_day):
            active.erase(contract_id)
            state["contracts"]["active"] = active
            _append_history(state,row,world_day,"cancelled_owner_unavailable")
            events.append({"status":"cancelled","reason":"owner_unavailable","contract":row.duplicate(true),"penalty":{}})
            continue
        var deadline_day = int(row.get("deadline_day",0))
        if deadline_day <= 0 or world_day <= deadline_day:
            continue
        active.erase(contract_id)
        state["contracts"]["active"] = active
        var penalty_result = _apply_penalty(state,row,"failure_penalty",world_day,"failed")
        _append_history(state,row,world_day,"failed")
        events.append({"status":"failed","reason":"deadline","contract":row.duplicate(true),"penalty":penalty_result})
    state["contracts"]["active"] = active
    refresh_offers(state,world_day,false)
    return events

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
        "owner_npc_id":str(contract.get("owner_npc_id","")),
        "chain_id":str(contract.get("chain_id","")),
        "chain_step":int(contract.get("chain_step",0)),
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
    var conflict_outcome = FactionRelations.apply_contract_outcome(state,contract,world_day)
    if not conflict_outcome.is_empty():
        _remove_conflict_offers(state,str(conflict_outcome.get("id","")))
    var endgame_outcome = FactionEndgame.apply_contract_outcome(state,contract,world_day)
    active.erase(contract_id)
    state["contracts"]["active"] = active
    _append_history(state,contract,world_day,"completed")
    var owner_npc_id = str(contract.get("owner_npc_id",""))
    if owner_npc_id != "":
        var attitude_reward = int(contract.get("npc_attitude_reward",6))
        FactionNpcState.record_interaction(state,owner_npc_id,world_day,"personal_contract_complete","Выполнено личное поручение «%s»." % str(contract.get("title","КОНТРАКТ")),attitude_reward)
    var affected_factions = [faction_id]
    if not conflict_outcome.is_empty():
        var loser = str(conflict_outcome.get("loser",""))
        if loser != "" and loser not in affected_factions:
            affected_factions.append(loser)
    return {
        "ok":true,"tickets":int(reward.get("tickets",0)),"reputation":int(reward.get("reputation",0)),
        "opened_route":opened_route,"faction":faction_id,"title":str(contract.get("title","КОНТРАКТ")),
        "owner_npc_id":str(contract.get("owner_npc_id","")),"chain_id":str(contract.get("chain_id","")),
        "chain_step":int(contract.get("chain_step",0)),"personal":str(contract.get("owner_npc_id","")) != "",
        "conflict_outcome":conflict_outcome,"endgame_outcome":endgame_outcome,"affected_factions":affected_factions
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
