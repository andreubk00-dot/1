extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionRelations = preload("res://world/faction_relations.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const SettlementCrisis = preload("res://world/settlement_crisis.gd")

# OSTATOK 1.22-dev6 — abstract caravan/supply incidents.
# Nothing moves through the world. A shipment is simulated in faction_state and,
# on failure, materialises as one temporary authored road event for a few days.
const EVENT_INTERVAL_MIN = 3
const EVENT_INTERVAL_MAX = 6
const EVENT_LIFETIME_DAYS = 3
const HISTORY_LIMIT = 48

const FACTION_CARGO = {
    "perron":{"resource":"food","label":"продовольствие","loot":"residential"},
    "rubezh":{"resource":"security","label":"боеприпасы и снаряжение","loot":"military"},
    "mechanics":{"resource":"technical","label":"детали и инструмент","loot":"industrial"},
    "lazaret":{"resource":"medicine","label":"медикаменты","loot":"pharmacy"}
}

const ROAD_OFFSETS = [
    Vector2i(-3,0),Vector2i(3,0),Vector2i(0,-3),Vector2i(0,3),
    Vector2i(-2,-2),Vector2i(2,-2),Vector2i(-2,2),Vector2i(2,2),
    Vector2i(-4,1),Vector2i(4,-1),Vector2i(-1,-4),Vector2i(1,4)
]

static func _hash(a:int,b:int = 0,c:int = 0) -> int:
    return absi(a * 92821 + b * 68917 + c * 31337 + 91573)

static func default_state(world_day:int = 1) -> Dictionary:
    var start = max(1,world_day)
    return {
        "active":{},
        "history":[],
        "serial":0,
        "next_event_day":start + _interval_for(start,0)
    }

static func _interval_for(day:int,serial:int) -> int:
    return EVENT_INTERVAL_MIN + (_hash(day,serial,17) % (EVENT_INTERVAL_MAX - EVENT_INTERVAL_MIN + 1))

static func ensure_state(state:Dictionary,world_day:int = 1) -> void:
    var clean = default_state(world_day)
    var raw = state.get("supply_events",{})
    if typeof(raw) == TYPE_DICTIONARY:
        clean["serial"] = max(0,int(raw.get("serial",0)))
        clean["next_event_day"] = max(1,int(raw.get("next_event_day",clean["next_event_day"])))
        var history = raw.get("history",[])
        if typeof(history) == TYPE_ARRAY:
            clean["history"] = history.duplicate(true)
            while clean["history"].size() > HISTORY_LIMIT:
                clean["history"].remove_at(0)
        var active = raw.get("active",{})
        if typeof(active) == TYPE_DICTIONARY and not active.is_empty():
            var sanitized = _sanitize_event(active)
            if not sanitized.is_empty():
                clean["active"] = sanitized
    state["supply_events"] = clean

static func _sanitize_event(raw:Dictionary) -> Dictionary:
    var faction_id = str(raw.get("faction",""))
    if FactionCatalog.faction(faction_id).is_empty():
        return {}
    var coord_raw = raw.get("coord",[])
    if typeof(coord_raw) != TYPE_ARRAY or coord_raw.size() < 2:
        return {}
    var coord = Vector2i(int(coord_raw[0]),int(coord_raw[1]))
    if absi(coord.x) > 100000 or absi(coord.y) > 100000:
        return {}
    var cargo = FACTION_CARGO.get(faction_id,{})
    var created = max(1,int(raw.get("created_day",1)))
    var expires = max(created + 1,int(raw.get("expires_day",created + EVENT_LIFETIME_DAYS)))
    return {
        "id":str(raw.get("id","supply_%d" % created)),
        "faction":faction_id,
        "coord":[coord.x,coord.y],
        "created_day":created,
        "expires_day":expires,
        "stage":str(raw.get("stage","distress")),
        "cargo_resource":str(raw.get("cargo_resource",cargo.get("resource","food"))),
        "cargo_label":str(raw.get("cargo_label",cargo.get("label","припасы"))),
        "loot_profile":str(raw.get("loot_profile",cargo.get("loot","residential"))),
        "severity":clampi(int(raw.get("severity",1)),1,3)
    }

static func active_event(state:Dictionary,world_day:int = 1) -> Dictionary:
    ensure_state(state,world_day)
    var active = state["supply_events"].get("active",{})
    if typeof(active) != TYPE_DICTIONARY or active.is_empty():
        return {}
    var out = active.duplicate(true)
    out["stage"] = stage_for(out,world_day)
    return out

static func active_coord(state:Dictionary,world_day:int = 1) -> Vector2i:
    var event = active_event(state,world_day)
    if event.is_empty():
        return Vector2i(999999,999999)
    var raw = event.get("coord",[])
    return Vector2i(int(raw[0]),int(raw[1]))

static func stage_for(event:Dictionary,world_day:int) -> String:
    var age = max(0,world_day - int(event.get("created_day",world_day)))
    if age <= 0:
        return "distress"
    if age == 1:
        return "overrun"
    return "looted"

static func stage_label(stage:String) -> String:
    match stage:
        "distress": return "РЕЙС ПРОСИТ ПОМОЩИ"
        "overrun": return "СВЯЗЬ С РЕЙСОМ ПОТЕРЯНА"
        "looted": return "МЕСТО РАЗГРОМА РЕЙСА"
    return "ПРОПАВШИЙ РЕЙС"

static func marker_label(state:Dictionary,world_day:int) -> String:
    var event = active_event(state,world_day)
    if event.is_empty():
        return ""
    var faction = FactionCatalog.faction(str(event.get("faction","")))
    var short_name = str(faction.get("short_name",event.get("faction","")))
    var stage = str(event.get("stage","distress"))
    if stage == "distress":
        return "SOS • %s" % short_name
    if stage == "overrun":
        return "НЕТ СВЯЗИ • %s" % short_name
    return "РАЗГРОМ • %s" % short_name

static func detail_text(state:Dictionary,world_day:int) -> String:
    var event = active_event(state,world_day)
    if event.is_empty():
        return ""
    var faction = FactionCatalog.faction(str(event.get("faction","")))
    var name = str(faction.get("short_name",event.get("faction","")))
    var stage = str(event.get("stage","distress"))
    match stage:
        "distress":
            return "%s: караван с грузом «%s» передал аварийный сигнал. Охрана ещё может быть жива." % [name,str(event.get("cargo_label","припасы"))]
        "overrun":
            return "%s: связь потеряна. На маршруте слышали стрельбу; часть груза ещё можно вернуть." % name
        _:
            return "%s: рейс разгромлен. Следы быстро остывают, большая часть груза уже потеряна." % name

static func _faction_need_score(state:Dictionary,faction_id:String,seed:int) -> float:
    var cargo = FACTION_CARGO.get(faction_id,{})
    var resource_id = str(cargo.get("resource","food"))
    var rec = state.get("factions",{}).get(faction_id,{})
    var resources = rec.get("resources",{})
    var target = float(resources.get(resource_id,50.0))
    var security = float(resources.get("security",50.0))
    var relation_stress = 0.0
    for other in FactionCatalog.ids():
        if str(other) == faction_id:
            continue
        relation_stress += max(0.0,-float(FactionRelations.relation(state,faction_id,str(other)))) * 0.18
    var jitter = float(_hash(seed,faction_id.hash(),31) % 31)
    return (100.0 - target) * 2.2 + (100.0 - security) * 0.8 + relation_stress + jitter

static func _choose_faction(state:Dictionary,day:int,serial:int) -> String:
    var best = ""
    var best_score = -INF
    for faction_id in FactionCatalog.ids():
        var fid = str(faction_id)
        var score = _faction_need_score(state,fid,_hash(day,serial,11))
        if score > best_score:
            best_score = score
            best = fid
    return best

static func _choose_coord(faction_id:String,day:int,serial:int,blocked:Array = []) -> Vector2i:
    var faction = FactionCatalog.faction(faction_id)
    var settlement_id = str(faction.get("settlement_id",""))
    var poi = RegionCatalog.poi_by_id(settlement_id)
    var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
    var start = _hash(day,serial,faction_id.hash()) % ROAD_OFFSETS.size()
    for step in range(ROAD_OFFSETS.size()):
        var coord = anchor + ROAD_OFFSETS[(start + step) % ROAD_OFFSETS.size()]
        if max(absi(coord.x),absi(coord.y)) <= 1:
            continue
        if coord in blocked:
            continue
        if not RegionCatalog.poi_for_chunk(coord).is_empty():
            continue
        return coord
    return anchor + Vector2i(0,4)

static func _event_severity(state:Dictionary,faction_id:String,day:int,serial:int) -> int:
    var resources = state.get("factions",{}).get(faction_id,{}).get("resources",{})
    var security = float(resources.get("security",50.0))
    var base = 1
    if security < 55.0:
        base = 2
    if security < 28.0:
        base = 3
    if (_hash(day,serial,73) % 100) < 18:
        base = mini(3,base + 1)
    return base

static func _create_event(state:Dictionary,world_day:int,blocked:Array = []) -> Dictionary:
    var event_state = state["supply_events"]
    var serial = int(event_state.get("serial",0)) + 1
    var faction_id = _choose_faction(state,world_day,serial)
    if faction_id == "":
        return {}
    var coord = _choose_coord(faction_id,world_day,serial,blocked)
    var cargo = FACTION_CARGO.get(faction_id,{})
    var event = {
        "id":"supply_%d_%d" % [world_day,serial],
        "faction":faction_id,
        "coord":[coord.x,coord.y],
        "created_day":world_day,
        "expires_day":world_day + EVENT_LIFETIME_DAYS,
        "stage":"distress",
        "cargo_resource":str(cargo.get("resource","food")),
        "cargo_label":str(cargo.get("label","припасы")),
        "loot_profile":str(cargo.get("loot","residential")),
        "severity":_event_severity(state,faction_id,world_day,serial)
    }
    event_state["serial"] = serial
    event_state["active"] = event
    state["supply_events"] = event_state
    return event.duplicate(true)

static func _append_history(state:Dictionary,event:Dictionary,outcome:String,world_day:int) -> void:
    var event_state = state["supply_events"]
    var history = event_state.get("history",[])
    if typeof(history) != TYPE_ARRAY:
        history = []
    history.append({
        "id":str(event.get("id","")),"faction":str(event.get("faction","")),
        "created_day":int(event.get("created_day",world_day)),"closed_day":world_day,
        "outcome":outcome,"stage":stage_for(event,world_day),
        "cargo_resource":str(event.get("cargo_resource",""))
    })
    while history.size() > HISTORY_LIMIT:
        history.remove_at(0)
    event_state["history"] = history
    state["supply_events"] = event_state

static func _schedule_next(state:Dictionary,world_day:int) -> void:
    var event_state = state["supply_events"]
    var base_interval = _interval_for(world_day,int(event_state.get("serial",0)))
    var interval = maxi(2,base_interval + SettlementCrisis.incident_interval_delta(state))
    event_state["next_event_day"] = world_day + interval
    state["supply_events"] = event_state

static func daily_tick(state:Dictionary,world_day:int,blocked:Array = []) -> Dictionary:
    ensure_state(state,world_day)
    var event_state = state["supply_events"]
    var active = event_state.get("active",{})
    if typeof(active) == TYPE_DICTIONARY and not active.is_empty():
        var old_stage = str(active.get("stage","distress"))
        if world_day >= int(active.get("expires_day",world_day + 1)):
            var faction_id = str(active.get("faction",""))
            var resource_id = str(active.get("cargo_resource","food"))
            var severity = clampi(int(active.get("severity",1)),1,3)
            if state.get("factions",{}).has(faction_id):
                var rec = state["factions"][faction_id]
                var resources = rec.get("resources",{})
                resources[resource_id] = max(0.0,float(resources.get(resource_id,0.0)) - (2.0 + severity * 1.5))
                resources["security"] = max(0.0,float(resources.get("security",0.0)) - (1.0 + severity * 0.75))
                rec["resources"] = resources
                state["factions"][faction_id] = rec
            _append_history(state,active,"lost",world_day)
            event_state = state["supply_events"]
            event_state["active"] = {}
            state["supply_events"] = event_state
            _schedule_next(state,world_day)
            return {"expired":true,"event":active.duplicate(true),"message":"Рейс потерян. Снабжение поселения ухудшилось."}
        var new_stage = stage_for(active,world_day)
        if new_stage != old_stage:
            active["stage"] = new_stage
            event_state["active"] = active
            state["supply_events"] = event_state
            return {"stage_changed":true,"event":active.duplicate(true)}
        return {}
    if world_day >= int(event_state.get("next_event_day",world_day + EVENT_INTERVAL_MIN)):
        var created = _create_event(state,world_day,blocked)
        if not created.is_empty():
            return {"created":true,"event":created,"message":detail_text(state,world_day)}
        _schedule_next(state,world_day)
    return {}

static func runtime_event_for_chunk(state:Dictionary,coord:Vector2i,world_day:int) -> Dictionary:
    var active = active_event(state,world_day)
    if active.is_empty():
        return {}
    var raw = active.get("coord",[])
    var event_coord = Vector2i(int(raw[0]),int(raw[1]))
    if event_coord != coord:
        return {}
    var stage = str(active.get("stage","distress"))
    var severity = clampi(int(active.get("severity",1)),1,3)
    var enemy_count = {"distress":3,"overrun":4,"looted":2}.get(stage,3) + severity - 1
    return {
        "id":"supply_convoy",
        "dynamic_event_id":str(active.get("id","")),
        "label":stage_label(stage),
        "placement":"road",
        "footprint":Vector2(220,132),
        "enemy_count":enemy_count,
        "supply_event":true,
        "stage":stage,
        "faction":str(active.get("faction","")),
        "cargo_resource":str(active.get("cargo_resource","food")),
        "cargo_label":str(active.get("cargo_label","припасы")),
        "loot_profile":str(active.get("loot_profile","residential")),
        "severity":severity
    }

static func can_resolve(state:Dictionary,event_id:String,world_day:int) -> bool:
    var active = active_event(state,world_day)
    return not active.is_empty() and str(active.get("id","")) == event_id

static func resolve_success(state:Dictionary,event_id:String,world_day:int) -> Dictionary:
    ensure_state(state,world_day)
    var active = active_event(state,world_day)
    if active.is_empty() or str(active.get("id","")) != event_id:
        return {"ok":false,"reason":"Событие уже завершено."}
    var faction_id = str(active.get("faction",""))
    var resource_id = str(active.get("cargo_resource","food"))
    var stage = str(active.get("stage","distress"))
    var stage_factor = {"distress":1.0,"overrun":0.62,"looted":0.28}.get(stage,0.28)
    var severity = clampi(int(active.get("severity",1)),1,3)
    var resource_gain = (10.0 + severity * 2.0) * stage_factor
    var security_gain = 3.5 * stage_factor
    var reputation_gain = int(round({"distress":8.0,"overrun":5.0,"looted":2.0}.get(stage,2.0)))
    var tickets = int(round({"distress":28.0,"overrun":18.0,"looted":8.0}.get(stage,8.0)))
    if state.get("factions",{}).has(faction_id):
        var rec = state["factions"][faction_id]
        var resources = rec.get("resources",{})
        resources[resource_id] = min(100.0,float(resources.get(resource_id,0.0)) + resource_gain)
        resources["security"] = min(100.0,float(resources.get("security",0.0)) + security_gain)
        rec["resources"] = resources
        rec["reputation"] = clampi(int(rec.get("reputation",0)) + reputation_gain,-100,250)
        state["factions"][faction_id] = rec
    state["currency_tickets"] = max(0,int(state.get("currency_tickets",0)) + tickets)
    _append_history(state,active,"recovered",world_day)
    var event_state = state["supply_events"]
    event_state["active"] = {}
    state["supply_events"] = event_state
    _schedule_next(state,world_day)
    return {
        "ok":true,"faction":faction_id,"resource":resource_id,"resource_gain":resource_gain,
        "security_gain":security_gain,"reputation":reputation_gain,"tickets":tickets,"stage":stage,
        "event":active.duplicate(true)
    }
