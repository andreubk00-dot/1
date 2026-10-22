extends RefCounted
# dev73: where the chained dogs are and what a dog is (docs/DOG_DEV73.md).
# Six yards, one in each sixth of the compass, three to six sectors out, in
# the quiet rural and residential edge of town: never in a sector an old or a
# new scene, a site or an «ЭФИР» note owns, so nothing else moves for them.

const EncounterCatalog = preload("res://world/encounter_catalog.gd")
const SceneCatalog = preload("res://world/scene_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

const NAMES = ["Найда", "Шарик", "Альма", "Джек", "Граф", "Пират"]
const SHE = {"Найда": true, "Альма": true}
const ZONES = ["rural", "residential"]
const RING_MIN = 3
const RING_MAX = 6
const SALT = 7307

const MAX_HP = 60.0
const FOOD_MINUTES = 2880.0     # a full belly lasts two days
const WATER_MINUTES = 1440.0    # water, one day
const LOW = 25.0                # below this it weakens
const FEED_BELOW = 70.0         # it takes food or water below this
const ASK_BELOW = 40.0          # and asks for it (the E prompt) below this
# what it eats: a tin, a ration, porridge; what it drinks: rain water first
const FOODS = ["canned_meat", "emergency_ration", "hot_meal"]
const DRINKS = ["dirty_water", "water"]
const BANDAGES = ["bandage", "sterile_bandage"]

const YARD = {
    "label":"ПЁС НА ЦЕПИ",
    "placement":"plot",
    "footprint":Vector2(64, 48),
}

static var _sites_cache = {}


static func key(coord:Vector2i) -> String:
    return "%d,%d" % [coord.x, coord.y]


static func sites() -> Dictionary:
    # "x,y" -> name; deterministic, worked out once
    if not _sites_cache.is_empty():
        return _sites_cache
    var out = {}
    for k in range(NAMES.size()):
        var best = Vector2i(999999, 999999)
        var best_h = -1
        for x in range(-RING_MAX, RING_MAX + 1):
            for y in range(-RING_MAX, RING_MAX + 1):
                var c = Vector2i(x, y)
                var ring = max(abs(x), abs(y))
                if ring < RING_MIN or ring > RING_MAX:
                    continue
                var wedge = int(floor(fposmod(atan2(float(y), float(x)), TAU) / (TAU / NAMES.size())))
                if wedge != k or not _yard_ok(c):
                    continue
                var h = SceneCatalog.mix(c, SALT)
                if best_h < 0 or h < best_h:
                    best_h = h
                    best = c
        if best_h >= 0:
            out[key(best)] = NAMES[k]
    _sites_cache = out
    return out


static func _yard_ok(c:Vector2i) -> bool:
    var profile = RegionCatalog.chunk_profile(c)
    var zone = str(profile.get("zone", ""))
    if not zone in ZONES:
        return false
    var poi_id = str(profile.get("poi_id", ""))
    if poi_id != "" or SceneCatalog._ether_chunk(c):
        return false
    var risk = int(profile.get("risk", 2))
    if not EncounterCatalog.event_for(c, zone, risk, poi_id).is_empty():
        return false
    if not SceneCatalog.scene_for(c, zone, risk, poi_id).is_empty():
        return false
    return true


static func site_name(coord:Vector2i) -> String:
    return str(sites().get(key(coord), ""))


static func she(dog_name:String) -> bool:
    return SHE.has(dog_name)


static func g(dog_name:String, male:String, female:String) -> String:
    # the word that agrees with the dog: «голодный» / «голодная»
    return female if she(dog_name) else male


static func sanitize(raw) -> Dictionary:
    var out = {"sites":{}, "dog":{}, "lost":[]}
    if typeof(raw) != TYPE_DICTIONARY:
        return out
    var s = raw.get("sites", {})
    if typeof(s) == TYPE_DICTIONARY:
        for k in s:
            if str(s[k]) in ["taken", "dead"]:
                out["sites"][str(k)] = str(s[k])
    var lost = raw.get("lost", [])
    if typeof(lost) == TYPE_ARRAY:
        for n in lost:
            out["lost"].append(str(n))
    var d = raw.get("dog", {})
    if typeof(d) == TYPE_DICTIONARY and str(d.get("name", "")) != "":
        out["dog"] = {
            "name":str(d["name"]),
            "site":str(d.get("site", "")),
            "hp":clamp(float(d.get("hp", MAX_HP)), 1.0, MAX_HP),
            "food":clamp(float(d.get("food", 60.0)), 0.0, 100.0),
            "water":clamp(float(d.get("water", 60.0)), 0.0, 100.0),
            "mode":str(d.get("mode", "follow")) if str(d.get("mode", "follow")) in ["follow", "wait"] else "follow",
            "trusted":bool(d.get("trusted", true)),
            "x":float(d.get("x", 0.0)),
            "y":float(d.get("y", 0.0)),
        }
    return out
