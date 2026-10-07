extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")

# 1.23-dev3 — persistent state for the authored named settlement NPC roster.
# Status changes are explicit system events, never daily RNG. That keeps loss rare
# and meaningful while allowing contracts/events to opt into consequences later.
const VALID_STATUSES = ["alive","wounded","missing","dead"]
const HISTORY_LIMIT = 12
const HISTORY_TEXT_LIMIT = 160
const ATTITUDE_MIN = -100
const ATTITUDE_MAX = 100

static func _canonical_roster() -> Dictionary:
    var roster = {}
    for faction_id in FactionCatalog.ids():
        var faction = FactionCatalog.faction(str(faction_id))
        for raw in faction.get("npc_roster",[]):
            if typeof(raw) != TYPE_DICTIONARY:
                continue
            var npc_id = str(raw.get("id",""))
            if npc_id == "":
                continue
            roster[npc_id] = {
                "id":npc_id,
                "name":str(raw.get("name",npc_id)),
                "role":str(raw.get("role","житель поселения")),
                "faction_id":str(faction_id)
            }
    return roster

static func ids() -> Array:
    return _canonical_roster().keys()

static func canonical(npc_id:String) -> Dictionary:
    return _canonical_roster().get(npc_id,{}).duplicate(true)

static func default_record(npc_id:String,world_day:int = 1) -> Dictionary:
    var base = canonical(npc_id)
    if base.is_empty():
        return {}
    base["status"] = "alive"
    base["status_since_day"] = max(1,world_day)
    base["attitude"] = 0
    base["interaction_count"] = 0
    base["last_interaction_day"] = 0
    base["history"] = []
    return base

static func default_state(world_day:int = 1) -> Dictionary:
    var records = {}
    for npc_id in ids():
        records[str(npc_id)] = default_record(str(npc_id),world_day)
    return {"records":records}

static func _clean_history(raw) -> Array:
    var clean = []
    if typeof(raw) != TYPE_ARRAY:
        return clean
    for row in raw:
        if typeof(row) != TYPE_DICTIONARY:
            continue
        var text = str(row.get("text","")).replace("\n"," ").replace("\r"," ").strip_edges().left(HISTORY_TEXT_LIMIT)
        var kind = str(row.get("kind","interaction")).strip_edges().left(32)
        if text == "":
            continue
        clean.append({
            "day":max(1,int(row.get("day",1))),
            "kind":kind if kind != "" else "interaction",
            "text":text
        })
    while clean.size() > HISTORY_LIMIT:
        clean.remove_at(0)
    return clean

static func sanitize_state(raw,world_day:int = 1) -> Dictionary:
    var clean = default_state(world_day)
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    var incoming = raw.get("records",raw)
    if typeof(incoming) != TYPE_DICTIONARY:
        return clean
    for npc_id in clean["records"].keys():
        var src = incoming.get(npc_id,{})
        if typeof(src) != TYPE_DICTIONARY:
            continue
        var dst = clean["records"][npc_id]
        var status = str(src.get("status","alive"))
        if status not in VALID_STATUSES:
            status = "alive"
        dst["status"] = status
        dst["status_since_day"] = max(1,int(src.get("status_since_day",world_day)))
        dst["attitude"] = clamp(int(src.get("attitude",0)),ATTITUDE_MIN,ATTITUDE_MAX)
        dst["interaction_count"] = max(0,int(src.get("interaction_count",0)))
        dst["last_interaction_day"] = max(0,int(src.get("last_interaction_day",0)))
        dst["history"] = _clean_history(src.get("history",[]))
        clean["records"][npc_id] = dst
    return clean

static func ensure_state(state:Dictionary,world_day:int = 1) -> void:
    state["named_npcs"] = sanitize_state(state.get("named_npcs",{}),world_day)

static func record(state:Dictionary,npc_id:String,world_day:int = 1) -> Dictionary:
    ensure_state(state,world_day)
    return state["named_npcs"].get("records",{}).get(npc_id,{}).duplicate(true)

static func status(state:Dictionary,npc_id:String,world_day:int = 1) -> String:
    return str(record(state,npc_id,world_day).get("status","alive"))

static func is_present(state:Dictionary,npc_id:String,world_day:int = 1) -> bool:
    return status(state,npc_id,world_day) in ["alive","wounded"]

static func service_available(state:Dictionary,npc_id:String,world_day:int = 1) -> bool:
    # Wounded characters remain present and can still perform their current services;
    # missing/dead characters physically disappear, so their trader/board service goes too.
    return is_present(state,npc_id,world_day)

static func status_label(value:String) -> String:
    match value:
        "wounded": return "РАНЕН"
        "missing": return "ПРОПАЛ"
        "dead": return "ПОГИБ"
    return "В ПОРЯДКЕ"

static func attitude_score(state:Dictionary,npc_id:String,faction_reputation:int = 0,world_day:int = 1) -> int:
    var personal = int(record(state,npc_id,world_day).get("attitude",0))
    # Faction trust colors first impressions, but personal history remains meaningful.
    var reputation_component = int(round(clamp(float(faction_reputation),-100.0,250.0) * 0.28))
    return clamp(personal + reputation_component,ATTITUDE_MIN,ATTITUDE_MAX)

static func attitude_label(score:int) -> String:
    if score <= -50:
        return "ВРАЖДЕБНО"
    if score <= -15:
        return "НАСТОРОЖЕННО"
    if score < 25:
        return "НЕЙТРАЛЬНО"
    if score < 60:
        return "РАСПОЛОЖЕН"
    return "ДОВЕРЯЕТ"

static func record_interaction(state:Dictionary,npc_id:String,world_day:int,kind:String,text:String,attitude_delta:int = 0) -> Dictionary:
    ensure_state(state,world_day)
    var records = state["named_npcs"].get("records",{})
    if not records.has(npc_id):
        return {}
    var rec = records[npc_id]
    rec["interaction_count"] = max(0,int(rec.get("interaction_count",0))) + 1
    rec["last_interaction_day"] = max(1,world_day)
    rec["attitude"] = clamp(int(rec.get("attitude",0)) + attitude_delta,ATTITUDE_MIN,ATTITUDE_MAX)
    var clean_text = str(text).replace("\n"," ").replace("\r"," ").strip_edges().left(HISTORY_TEXT_LIMIT)
    if clean_text != "":
        var history = rec.get("history",[])
        if typeof(history) != TYPE_ARRAY:
            history = []
        history.append({"day":max(1,world_day),"kind":str(kind).left(32),"text":clean_text})
        while history.size() > HISTORY_LIMIT:
            history.remove_at(0)
        rec["history"] = history
    records[npc_id] = rec
    state["named_npcs"]["records"] = records
    return rec.duplicate(true)

static func set_status(state:Dictionary,npc_id:String,new_status:String,world_day:int,reason:String = "") -> Dictionary:
    ensure_state(state,world_day)
    if new_status not in VALID_STATUSES:
        return {"ok":false,"reason":"invalid_status"}
    var records = state["named_npcs"].get("records",{})
    if not records.has(npc_id):
        return {"ok":false,"reason":"unknown_npc"}
    var rec = records[npc_id]
    var old_status = str(rec.get("status","alive"))
    if old_status == new_status:
        return {"ok":true,"changed":false,"old_status":old_status,"new_status":new_status,"record":rec.duplicate(true)}
    rec["status"] = new_status
    rec["status_since_day"] = max(1,world_day)
    var note = reason.strip_edges()
    if note == "":
        note = "Статус изменён: %s" % status_label(new_status).to_lower()
    var history = rec.get("history",[])
    if typeof(history) != TYPE_ARRAY:
        history = []
    history.append({"day":max(1,world_day),"kind":"status","text":note.replace("\n"," ").replace("\r"," ").strip_edges().left(HISTORY_TEXT_LIMIT)})
    while history.size() > HISTORY_LIMIT:
        history.remove_at(0)
    rec["history"] = history
    records[npc_id] = rec
    state["named_npcs"]["records"] = records
    return {"ok":true,"changed":true,"old_status":old_status,"new_status":new_status,"record":rec.duplicate(true)}

static func history(state:Dictionary,npc_id:String,world_day:int = 1) -> Array:
    return record(state,npc_id,world_day).get("history",[]).duplicate(true)

static func last_history(state:Dictionary,npc_id:String,world_day:int = 1) -> Dictionary:
    var rows = history(state,npc_id,world_day)
    if rows.is_empty():
        return {}
    return rows[-1].duplicate(true)
