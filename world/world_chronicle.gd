extends RefCounted

# 1.23-dev2 — persistent world chronicle fed by existing simulation systems.
# This is deliberately not a quest generator: it only records consequences that
# already happened in faction economy, supply incidents, relations and projects.
const HISTORY_LIMIT = 64
const TEXT_LIMIT = 220
const VALID_KINDS = ["supply","danger","shortage","recovery","relations","route","project","npc","world","story"]
const STORY_SEEN_LIMIT = 96
const STORY_ID_LIMIT = 80

static func default_state() -> Dictionary:
    return {"serial":0,"last_read_serial":0,"history":[],"story_seen":[]}

static func _clean_text(value) -> String:
    return str(value).replace("\n"," ").replace("\r"," ").strip_edges().left(TEXT_LIMIT)

static func sanitize_state(raw) -> Dictionary:
    var clean = default_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    var history = raw.get("history",[])
    var max_serial = 0
    if typeof(history) == TYPE_ARRAY:
        for row in history:
            if typeof(row) != TYPE_DICTIONARY:
                continue
            var text = _clean_text(row.get("text",""))
            if text == "":
                continue
            var serial = max(1,int(row.get("serial",max_serial + 1)))
            max_serial = max(max_serial,serial)
            var kind = str(row.get("kind","world"))
            if kind not in VALID_KINDS:
                kind = "world"
            clean["history"].append({
                "serial":serial,
                "day":max(1,int(row.get("day",1))),
                "minute":clamp(int(row.get("minute",0)),0,1439),
                "kind":kind,
                "faction":str(row.get("faction","")).left(40),
                "text":text
            })
    while clean["history"].size() > HISTORY_LIMIT:
        clean["history"].remove_at(0)
    clean["serial"] = max(max_serial,max(0,int(raw.get("serial",max_serial))))
    clean["last_read_serial"] = clamp(int(raw.get("last_read_serial",0)),0,int(clean["serial"]))
    var raw_seen = raw.get("story_seen",[])
    if typeof(raw_seen) == TYPE_ARRAY:
        var unique = {}
        for raw_id in raw_seen:
            var story_id = str(raw_id).strip_edges().left(STORY_ID_LIMIT)
            if story_id == "" or unique.has(story_id):
                continue
            unique[story_id] = true
            clean["story_seen"].append(story_id)
    while clean["story_seen"].size() > STORY_SEEN_LIMIT:
        clean["story_seen"].remove_at(0)
    return clean

static func ensure_state(state:Dictionary) -> void:
    state["world_chronicle"] = sanitize_state(state.get("world_chronicle",{}))

static func append(state:Dictionary,world_day:int,world_minute:int,kind:String,faction_id:String,text:String) -> Dictionary:
    ensure_state(state)
    var clean_text = _clean_text(text)
    if clean_text == "":
        return {}
    var safe_kind = kind if kind in VALID_KINDS else "world"
    var chronicle = state["world_chronicle"]
    var history = chronicle.get("history",[])
    if not history.is_empty():
        var last = history[-1]
        if int(last.get("day",0)) == max(1,world_day) and str(last.get("kind","")) == safe_kind and str(last.get("faction","")) == faction_id and str(last.get("text","")) == clean_text:
            return last.duplicate(true)
    chronicle["serial"] = int(chronicle.get("serial",0)) + 1
    var entry = {
        "serial":int(chronicle["serial"]),
        "day":max(1,world_day),
        "minute":clamp(world_minute,0,1439),
        "kind":safe_kind,
        "faction":faction_id.left(40),
        "text":clean_text
    }
    history.append(entry)
    while history.size() > HISTORY_LIMIT:
        history.remove_at(0)
    chronicle["history"] = history
    state["world_chronicle"] = chronicle
    return entry.duplicate(true)

static func story_seen(state:Dictionary,story_id:String) -> bool:
    ensure_state(state)
    var safe_id = story_id.strip_edges().left(STORY_ID_LIMIT)
    return safe_id != "" and safe_id in state["world_chronicle"].get("story_seen",[])

static func append_story(state:Dictionary,world_day:int,world_minute:int,story_id:String,title:String,text:String) -> Dictionary:
    ensure_state(state)
    var safe_id = story_id.strip_edges().left(STORY_ID_LIMIT)
    if safe_id == "":
        return {}
    if story_seen(state,safe_id):
        return {"new":false,"story_id":safe_id}
    var clean_title = _clean_text(title)
    var clean_body = _clean_text(text)
    var combined = clean_body if clean_title == "" else "%s — %s" % [clean_title,clean_body]
    var entry = append(state,world_day,world_minute,"story","",combined)
    if entry.is_empty():
        return entry
    var chronicle = state["world_chronicle"]
    var seen:Array = chronicle.get("story_seen",[])
    seen.append(safe_id)
    while seen.size() > STORY_SEEN_LIMIT:
        seen.remove_at(0)
    chronicle["story_seen"] = seen
    state["world_chronicle"] = chronicle
    var out = entry.duplicate(true)
    out["new"] = true
    out["story_id"] = safe_id
    return out

static func entries(state:Dictionary,limit:int = 32,newest_first:bool = true) -> Array:
    ensure_state(state)
    var history = state["world_chronicle"].get("history",[])
    var out = []
    var count = min(max(0,limit),history.size())
    if newest_first:
        for i in range(history.size() - 1,history.size() - count - 1,-1):
            out.append(history[i].duplicate(true))
    else:
        for i in range(max(0,history.size() - count),history.size()):
            out.append(history[i].duplicate(true))
    return out

static func unread_count(state:Dictionary) -> int:
    ensure_state(state)
    var chronicle = state["world_chronicle"]
    return max(0,int(chronicle.get("serial",0)) - int(chronicle.get("last_read_serial",0)))

static func mark_read(state:Dictionary) -> void:
    ensure_state(state)
    state["world_chronicle"]["last_read_serial"] = int(state["world_chronicle"].get("serial",0))

static func time_text(minute:int) -> String:
    var safe_minute = clamp(minute,0,1439)
    return "%02d:%02d" % [int(safe_minute / 60),safe_minute % 60]

static func entry_text(entry:Dictionary) -> String:
    return "ДЕНЬ %d  %s  •  %s" % [
        max(1,int(entry.get("day",1))),
        time_text(int(entry.get("minute",0))),
        str(entry.get("text",""))
    ]
