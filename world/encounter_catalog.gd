extends RefCounted

# OSTATOK 1.15 — deterministic open-world encounter catalog.
# Encounters are intentionally finite story scenes, not renewable loot farms.
# Their visual setup is rebuilt deterministically, while containers and infected
# use the existing persistence keys in main_script_mod.gd.

const EVENT_LAYOUT_VERSION = 1

const EVENTS = {
    "abandoned_camp": {
        "label":"БРОШЕННЫЙ ЛАГЕРЬ",
        "zones":["rural","woodland"],
        "min_risk":2,
        "max_risk":3,
        "placement":"plot",
        "footprint":Vector2(142,104),
        "loot_by_zone":{"rural":"rural","woodland":"forest_cache"},
        "enemy_count":2
    },
    "failed_evacuation": {
        "label":"СОРВАННАЯ ЭВАКУАЦИЯ",
        "zones":["residential","commercial"],
        "min_risk":2,
        "max_risk":3,
        "placement":"road",
        "footprint":Vector2(148,92),
        "loot":"pharmacy",
        "enemy_count":3
    },
    "repair_breakdown": {
        "label":"БРОШЕННАЯ РЕМБРИГАДА",
        "zones":["residential","commercial","industrial"],
        "min_risk":2,
        "max_risk":4,
        "placement":"road",
        "footprint":Vector2(154,96),
        "loot_by_zone":{"residential":"garage","commercial":"garage","industrial":"industrial"},
        "enemy_count":2
    },
    "looted_convoy": {
        "label":"РАЗГРОМЛЕННАЯ КОЛОННА",
        "zones":["industrial","military"],
        "min_risk":4,
        "max_risk":5,
        "placement":"road",
        "footprint":Vector2(176,108),
        "loot_by_zone":{"industrial":"industrial","military":"military"},
        "enemy_count":4
    },
    "feeding_site": {
        "label":"МЕСТО НЕДАВНЕЙ СХВАТКИ",
        "zones":["residential","commercial","industrial","military","rural"],
        "min_risk":2,
        "max_risk":5,
        "placement":"road",
        "footprint":Vector2(128,86),
        "loot":"",
        "enemy_count":4
    }
}

static func _hash(coord:Vector2i,salt:int = 0) -> int:
    return abs(coord.x * 92821 + coord.y * 68917 + coord.x * coord.y * 313 + salt * 7919 + 91573)

static func event_for(coord:Vector2i,zone:String,risk:int,poi_id:String = "") -> Dictionary:
    if poi_id != "":
        return {}
    if max(abs(coord.x),abs(coord.y)) <= 1:
        return {}
    var threshold = {1:0,2:58,3:76,4:92,5:108}.get(clamp(risk,1,5),58)
    if _hash(coord,11) % 1000 >= int(threshold):
        return {}
    var candidates:Array = []
    for event_id in EVENTS.keys():
        var spec:Dictionary = EVENTS[event_id]
        if not zone in spec.get("zones",[]):
            continue
        if risk < int(spec.get("min_risk",1)) or risk > int(spec.get("max_risk",5)):
            continue
        candidates.append(str(event_id))
    if candidates.is_empty():
        return {}
    candidates.sort()
    var chosen = candidates[_hash(coord,29) % candidates.size()]
    var out:Dictionary = EVENTS[chosen].duplicate(true)
    out["id"] = chosen
    return out

static func loot_profile(event:Dictionary,zone:String) -> String:
    if event.is_empty():
        return ""
    var by_zone = event.get("loot_by_zone",{})
    if typeof(by_zone) == TYPE_DICTIONARY and by_zone.has(zone):
        return str(by_zone[zone])
    return str(event.get("loot",""))
