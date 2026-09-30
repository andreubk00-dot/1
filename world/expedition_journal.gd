extends RefCounted

# Serializable domain data only. No nodes, input, rewards or inventory mutations.
# Inventory/damage authority can later call these functions on the server.
const VITALS = ["health","hunger","thirst","fatigue","wetness","body_temperature","pain","wound_infection","wound_contamination"]

static func empty_state() -> Dictionary:
    return {"schema":2,"home":{},"departure":{},"departed":false,"returning":false,"last_report":{},"supply_preset":0}

static func number(value,fallback = 0.0) -> float:
    if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)):
        return float(value)
    return fallback

static func numeric_map(value,whole = false) -> Dictionary:
    var result = {}
    if typeof(value) != TYPE_DICTIONARY:
        return result
    for key in value:
        if typeof(key) != TYPE_STRING or str(key).length() > 80:
            continue
        var amount = clamp(number(value[key]),0.0,1000000.0)
        if whole:
            if amount >= 1.0:
                result[key] = int(amount)
        else:
            result[key] = amount
    return result

static func home(value) -> Dictionary:
    if typeof(value) != TYPE_DICTIONARY:
        return {}
    var key = str(value.get("key",""))
    var coord = value.get("chunk",[])
    var position = value.get("position",[])
    if key == "" or key.length() > 160 or typeof(coord) != TYPE_ARRAY or coord.size() != 2 or typeof(position) != TYPE_ARRAY or position.size() != 2:
        return {}
    for v in coord + position:
        if number(v,INF) == INF or abs(number(v)) >= 100000000.0:
            return {}
    var bounds = value.get("bounds",[])
    var valid_bounds = typeof(bounds) == TYPE_ARRAY and bounds.size() == 4
    if valid_bounds:
        for v in bounds:
            if number(v,INF) == INF or abs(number(v)) >= 100000000.0:
                valid_bounds = false
        if valid_bounds:
            valid_bounds = number(bounds[2]) > 0.0 and number(bounds[3]) > 0.0 and number(bounds[2]) <= 768.0 and number(bounds[3]) <= 768.0
    return {"key":key,"name":str(value.get("name","Убежище")).left(100),
        "chunk":[int(coord[0]),int(coord[1])],"position":[float(position[0]),float(position[1])],
        "bounds":bounds.duplicate() if valid_bounds else []}

static func snapshot(value) -> Dictionary:
    if typeof(value) != TYPE_DICTIONARY or not value.has("items") or typeof(value["items"]) != TYPE_DICTIONARY:
        return {}
    var vital_map = numeric_map(value.get("vitals",{}))
    var valid_vitals = {}
    for key in VITALS:
        if vital_map.has(key):
            valid_vitals[key] = vital_map[key]
    return {"items":numeric_map(value["items"],true),"vitals":valid_vitals,"body":numeric_map(value.get("body",{})),
        "weapons":numeric_map(value.get("weapons",{})),"bleeding":bool(value.get("bleeding",false))}

static func normalize(value) -> Dictionary:
    var state = empty_state()
    if typeof(value) != TYPE_DICTIONARY:
        return state
    state["home"] = home(value.get("home",{}))
    state["departure"] = snapshot(value.get("departure",{}))
    state["departed"] = bool(value.get("departed",false))
    state["returning"] = bool(value.get("returning",false))
    state["supply_preset"] = int(clamp(number(value.get("supply_preset",0)),0.0,2.0))
    var report = value.get("last_report",{})
    if typeof(report) == TYPE_DICTIONARY and str(report.get("status","")) in ["returned","cancelled","incapacitated"]:
        state["last_report"] = {
            "status":str(report["status"]),"target":str(report.get("target","")).left(120),
            "reached":bool(report.get("reached",false)),
            "elapsed":int(clamp(number(report.get("elapsed",0)),0.0,100000000.0)),
            "end_day":int(max(1.0,number(report.get("end_day",1)))),
            "end_minutes":clamp(number(report.get("end_minutes",0)),0.0,1439.99),
            "before":snapshot(report.get("before",{})),"after":snapshot(report.get("after",{}))
        }
    return state

static func item_delta(before,after) -> Dictionary:
    var gains = {}
    var losses = {}
    if before.is_empty() or after.is_empty():
        return {"gains":gains,"losses":losses}
    var first = before.get("items",{})
    var last = after.get("items",{})
    var keys = first.keys()
    for key in last:
        if not key in keys:
            keys.append(key)
    keys.sort()
    for key in keys:
        var delta = int(last.get(key,0)) - int(first.get(key,0))
        if delta > 0:
            gains[key] = delta
        elif delta < 0:
            losses[key] = -delta
    return {"gains":gains,"losses":losses}

static func report(status,target,reached,start_day,start_minutes,end_day,end_minutes,before,after) -> Dictionary:
    return {"status":status,"target":target,"reached":reached,
        "elapsed":int(max(0.0,(end_day-start_day)*1440.0 + end_minutes-start_minutes)),
        "end_day":end_day,"end_minutes":end_minutes,
        "before":snapshot(before),"after":snapshot(after)}
