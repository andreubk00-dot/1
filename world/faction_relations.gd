extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")

# OSTATOK 1.22-dev5 — persistent inter-faction relations and player-driven decisions.
# Reputation answers "how this faction treats the player". Relations answer
# "how two factions currently treat each other" and are deliberately separate.
const RELATION_MIN = -100
const RELATION_MAX = 100
const HISTORY_LIMIT = 64

const RELATION_TIERS = [
    {"id":"hostile","name":"ВРАЖДА","max":-50},
    {"id":"tense","name":"НАПРЯЖЕНИЕ","max":-15},
    {"id":"neutral","name":"НЕЙТРАЛЬНО","max":14},
    {"id":"cooperative","name":"СОТРУДНИЧЕСТВО","max":49},
    {"id":"allied","name":"СОЮЗ","max":100}
]

static func pair_key(a:String,b:String) -> String:
    if a <= b:
        return "%s|%s" % [a,b]
    return "%s|%s" % [b,a]

static func default_relations() -> Dictionary:
    var out = {}
    var ids = FactionCatalog.ids()
    for i in range(ids.size()):
        for j in range(i + 1,ids.size()):
            out[pair_key(str(ids[i]),str(ids[j]))] = 0
    return out

static func default_world_influence() -> Dictionary:
    return {"decisions":{},"relation_history":[]}

static func ensure_state(state:Dictionary) -> void:
    var clean_relations = default_relations()
    var incoming_relations = state.get("relations",{})
    if typeof(incoming_relations) == TYPE_DICTIONARY:
        for key in clean_relations.keys():
            clean_relations[key] = clamp(int(incoming_relations.get(key,0)),RELATION_MIN,RELATION_MAX)
    state["relations"] = clean_relations

    var influence = default_world_influence()
    var incoming_influence = state.get("world_influence",{})
    if typeof(incoming_influence) == TYPE_DICTIONARY:
        var decisions = incoming_influence.get("decisions",{})
        if typeof(decisions) == TYPE_DICTIONARY:
            influence["decisions"] = decisions.duplicate(true)
        var history = incoming_influence.get("relation_history",[])
        if typeof(history) == TYPE_ARRAY:
            influence["relation_history"] = history.duplicate(true)
            while influence["relation_history"].size() > HISTORY_LIMIT:
                influence["relation_history"].remove_at(0)
    state["world_influence"] = influence

static func relation(state:Dictionary,a:String,b:String) -> int:
    if a == b:
        return RELATION_MAX
    ensure_state(state)
    return int(state["relations"].get(pair_key(a,b),0))

static func relation_tier(value:int) -> Dictionary:
    var v = clamp(value,RELATION_MIN,RELATION_MAX)
    for tier in RELATION_TIERS:
        if v <= int(tier.get("max",100)):
            return tier.duplicate(true)
    return RELATION_TIERS[-1].duplicate(true)

static func relation_tier_for(state:Dictionary,a:String,b:String) -> Dictionary:
    return relation_tier(relation(state,a,b))

static func adjust_relation(state:Dictionary,a:String,b:String,amount:int,world_day:int = 0,reason:String = "") -> int:
    if a == b or FactionCatalog.faction(a).is_empty() or FactionCatalog.faction(b).is_empty():
        return 0
    ensure_state(state)
    var key = pair_key(a,b)
    var before = int(state["relations"].get(key,0))
    var after = clamp(before + amount,RELATION_MIN,RELATION_MAX)
    state["relations"][key] = after
    if amount != 0:
        var history = state["world_influence"].get("relation_history",[])
        history.append({
            "day":max(0,world_day),"a":a,"b":b,"delta":after - before,"value":after,"reason":reason
        })
        while history.size() > HISTORY_LIMIT:
            history.remove_at(0)
        state["world_influence"]["relation_history"] = history
    return after

static func decision(state:Dictionary,conflict_id:String) -> Dictionary:
    ensure_state(state)
    var decisions = state["world_influence"].get("decisions",{})
    if typeof(decisions) != TYPE_DICTIONARY:
        return {}
    var row = decisions.get(conflict_id,{})
    return row.duplicate(true) if typeof(row) == TYPE_DICTIONARY else {}

static func conflict_resolved(state:Dictionary,conflict_id:String) -> bool:
    return conflict_id != "" and not decision(state,conflict_id).is_empty()

static func _adjust_player_reputation(state:Dictionary,faction_id:String,amount:int) -> int:
    if not state.get("factions",{}).has(faction_id):
        return 0
    var record = state["factions"][faction_id]
    record["reputation"] = clamp(int(record.get("reputation",0)) + amount,-100,250)
    state["factions"][faction_id] = record
    return int(record["reputation"])

static func _adjust_resource(state:Dictionary,faction_id:String,resource_id:String,amount:float) -> float:
    if not state.get("factions",{}).has(faction_id):
        return 0.0
    if resource_id not in ["food","medicine","technical","security"]:
        return 0.0
    var record = state["factions"][faction_id]
    var resources = record.get("resources",{})
    resources[resource_id] = clamp(float(resources.get(resource_id,0.0)) + amount,0.0,100.0)
    record["resources"] = resources
    state["factions"][faction_id] = record
    return float(resources[resource_id])

static func apply_contract_outcome(state:Dictionary,contract:Dictionary,world_day:int) -> Dictionary:
    var conflict = contract.get("conflict",{})
    if typeof(conflict) != TYPE_DICTIONARY or conflict.is_empty():
        return {}
    ensure_state(state)
    var conflict_id = str(conflict.get("id",""))
    if conflict_id == "" or conflict_resolved(state,conflict_id):
        return {}
    var winner = str(contract.get("faction",""))
    var loser = str(conflict.get("opposes",""))
    if FactionCatalog.faction(winner).is_empty() or FactionCatalog.faction(loser).is_empty() or winner == loser:
        return {}

    var loser_rep_delta = int(conflict.get("loser_reputation",0))
    var relation_delta = int(conflict.get("relation_delta",0))
    var loser_rep = _adjust_player_reputation(state,loser,loser_rep_delta)
    var relation_value = adjust_relation(state,winner,loser,relation_delta,world_day,conflict_id)

    var resource_effects = conflict.get("resource_effects",{})
    if typeof(resource_effects) == TYPE_DICTIONARY:
        for faction_id in resource_effects.keys():
            var effects = resource_effects[faction_id]
            if typeof(effects) != TYPE_DICTIONARY:
                continue
            for resource_id in effects.keys():
                _adjust_resource(state,str(faction_id),str(resource_id),float(effects[resource_id]))

    var row = {
        "id":conflict_id,
        "day":max(1,world_day),
        "winner":winner,
        "loser":loser,
        "choice":str(conflict.get("choice",str(contract.get("template_id","")))),
        "source_contract":str(contract.get("template_id","")),
        "relation_delta":relation_delta,
        "loser_reputation_delta":loser_rep_delta
    }
    state["world_influence"]["decisions"][conflict_id] = row
    return {
        "id":conflict_id,"winner":winner,"loser":loser,
        "relation":relation_value,"relation_delta":relation_delta,
        "loser_reputation":loser_rep,"loser_reputation_delta":loser_rep_delta,
        "choice":str(row["choice"])
    }

static func shared_route_factor(state:Dictionary,beneficiaries:Array) -> float:
    if beneficiaries.size() < 2:
        return 1.0
    var total = 0.0
    var pairs = 0
    for i in range(beneficiaries.size()):
        for j in range(i + 1,beneficiaries.size()):
            var a = str(beneficiaries[i])
            var b = str(beneficiaries[j])
            if a == b or FactionCatalog.faction(a).is_empty() or FactionCatalog.faction(b).is_empty():
                continue
            total += float(relation(state,a,b))
            pairs += 1
    if pairs <= 0:
        return 1.0
    var average = total / float(pairs)
    return clamp(1.0 + average / 200.0,0.85,1.10)

static func conflict_warning(state:Dictionary,contract:Dictionary) -> String:
    var conflict = contract.get("conflict",{})
    if typeof(conflict) != TYPE_DICTIONARY or conflict.is_empty():
        return ""
    var conflict_id = str(conflict.get("id",""))
    var existing = decision(state,conflict_id)
    if not existing.is_empty():
        var winner_name = str(FactionCatalog.faction(str(existing.get("winner",""))).get("short_name",existing.get("winner","")))
        return "РЕШЕНИЕ УЖЕ ПРИНЯТО: %s." % winner_name
    var opponent = str(conflict.get("opposes",""))
    var opponent_name = str(FactionCatalog.faction(opponent).get("short_name",opponent)).to_upper()
    var rep_delta = int(conflict.get("loser_reputation",0))
    return "КОНФЛИКТ ИНТЕРЕСОВ: выполнение закрепит этот выбор и закроет альтернативу %s. Репутация у них: %s%d." % [opponent_name,"+" if rep_delta >= 0 else "",rep_delta]
