extends RefCounted
# dev71: six new world scenes (docs/SCENES_DEV71.md). They roll only in sectors
# where none of the five old encounter scenes stands - EncounterCatalog.event_for
# is never consulted for its own choice here, so every old scene keeps its
# place - and use their own hash.

const EncounterCatalog = preload("res://world/encounter_catalog.gd")
const StoryEther = preload("res://world/story_ether.gd")

const SCENES = {
    "trapped_survivor": {
        "weight":20,
        "label":"ВЫЖИВШИЙ В МАШИНЕ",
        "zones":["residential","commercial","rural"],
        "min_risk":2, "max_risk":3,
        "placement":"road", "footprint":Vector2(150,96),
        "enemy_count":3
    },
    "bait_ambush": {
        "weight":10,
        "label":"ЗАСАДА",
        "zones":["residential","commercial","industrial","woodland"],
        "min_risk":2, "max_risk":4,
        "placement":"road", "footprint":Vector2(140,90),
        "loot":"garage", "loot_by_zone":{"industrial":"industrial","woodland":"forest_cache"},
        "enemy_count":0
    },
    "abandoned_checkpoint": {
        "weight":10,
        "label":"БРОШЕННЫЙ БЛОКПОСТ",
        "zones":["industrial","military","woodland"],
        "min_risk":3, "max_risk":5,
        "placement":"road", "footprint":Vector2(170,100),
        "loot":"police", "loot_by_zone":{"military":"military"},
        "enemy_count":3
    },
    "pharmacy_van": {
        "weight":16,
        "label":"АПТЕЧНЫЙ ФУРГОН",
        "zones":["residential","commercial","rural"],
        "min_risk":2, "max_risk":4,
        "placement":"road", "footprint":Vector2(150,96),
        "loot":"pharmacy",
        "enemy_count":3
    },
    "living_camp": {
        "weight":12,
        "label":"ЖИВОЙ ЛАГЕРЬ",
        "zones":["rural","woodland"],
        "min_risk":1, "max_risk":3,
        # by the forest road: in the woods a plot is solid trees
        "placement":"road", "footprint":Vector2(140,110),
        "enemy_count":0
    },
    "burn_pit": {
        "weight":14,
        "label":"КОСТРИЩЕ",
        "zones":["residential","commercial","rural"],
        "min_risk":2, "max_risk":4,
        "placement":"plot", "footprint":Vector2(130,96),
        "enemy_count":2
    }
}

# per mille of eligible sectors that hold a scene, by risk
const THRESHOLD = {1:30, 2:85, 3:42, 4:36, 5:60}
# picked once by a scan of the region for the most even spread (8-9 of each
# of the six over its ~50 scene sectors); changing it moves every new scene
const CHOICE_SALT = 1585

# the person in the car: who, and what they carry
const SURVIVORS = [
    {"who":"Женщина в «Жигулях»", "line":"Третьи сутки сижу. Они кругами ходили, стучали... Ты их убрал? Я дойду до %s. Вот, возьми — больше у меня ничего нет."},
    {"who":"Старик за рулём", "line":"Ехал к сыну, бензин кончился прямо тут. Спасибо, сынок. Пойду к %s пешком. Возьми, пригодится."},
    {"who":"Парень в «Москвиче»", "line":"Я уж думал — всё. Слушай, я к %s, там вроде принимают. На, это тебе."},
]
const SURVIVOR_GIFTS = [
    [{"id":"bandage","qty":2},{"id":"canned_meat","qty":1}],
    [{"id":"ammo_9x18","qty":8},{"id":"water","qty":1}],
    [{"id":"painkillers","qty":1},{"id":"canned_meat","qty":1}],
]
const SURVIVOR_BAG_EXTRA = [{"id":"antiseptic","qty":1},{"id":"ammo_9x18","qty":6}]

const BAIT_CLUE = {
    "title":"Окурки",
    "text":"Пять окурков в одной ямке, ещё пахнут. Кто-то лежал здесь и долго смотрел на дорогу.",
    "prompt":"ОКУРКИ", "prop_kind":"scattered_bottles", "scale":0.32
}
const CHECKPOINT_NOTE = {
    "title":"Приказ по блокпосту",
    "text":"«Пропускать к пунктам сбора. Обратно — никого, до прибытия транспорта». Ниже ручкой: «Транспорта не будет. Ушли в ночь на четверг».",
    "prompt":"ПРИКАЗ", "prop_kind":"paper_stack", "scale":0.36
}
const PIT_NOTE = {
    "title":"Список у кострища",
    "text":"Фамилии в столбик, у каждой — «ждал». Последняя строчка другим почерком: «Ждать больше некого».",
    "prompt":"СПИСОК", "prop_kind":"paper_stack", "scale":0.36
}
const PIT_RADIO = {
    "": "Сквозь треск: «...эвакуация продолжается. Оставайтесь на местах. Ожидайте транспорт...» И снова, по кругу.",
    "truth": "Новый голос: «...эвакуации не будет. Не ждите. Идите к людям...» Ваш голос.",
    "silence": "Только шипение. Тот, кто здесь ждал, так и не узнал, что ждать было нечего.",
}


static func mix(coord:Vector2i, salt:int) -> int:
    # murmur3's finaliser over the coordinate: neighbouring sectors land far
    # apart, so a scene's share follows its weight, not the map's layout
    var h = ((coord.x * 73856093) ^ (coord.y * 19349663) ^ (salt * 83492791)) & 0xFFFFFFFF
    h ^= h >> 16
    h = (h * 0x85EBCA6B) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0xC2B2AE35) & 0xFFFFFFFF
    h ^= h >> 16
    return h


static func _ether_chunk(coord:Vector2i) -> bool:
    if StoryEther.NOTES.has("%d,%d" % [coord.x, coord.y]):
        return true
    return coord == StoryEther.COLUMN_NOTE["coord"]


static func scene_for(coord:Vector2i, zone:String, risk:int, poi_id:String = "") -> Dictionary:
    if poi_id != "":
        return {}
    if max(abs(coord.x), abs(coord.y)) <= 2 or _ether_chunk(coord):
        return {}
    # an old scene owns this sector: never stand beside or instead of it
    if not EncounterCatalog.event_for(coord, zone, risk, poi_id).is_empty():
        return {}
    if EncounterCatalog._hash(coord, 211) % 1000 >= int(THRESHOLD.get(clampi(risk, 1, 5), 45)):
        return {}
    var candidates:Array = []
    for id in SCENES.keys():
        var spec:Dictionary = SCENES[id]
        if not zone in spec.get("zones", []):
            continue
        if risk < int(spec.get("min_risk", 1)) or risk > int(spec.get("max_risk", 5)):
            continue
        candidates.append(str(id))
    if candidates.is_empty():
        return {}
    candidates.sort()
    # a well-mixed hash (the linear coordinate hash correlates with the map's
    # layout and favoured one scene); weights balance the zones' candidates
    var total = 0
    for id in candidates:
        total += int(SCENES[id].get("weight", 10))
    var roll = mix(coord, CHOICE_SALT) % max(1, total)
    var chosen = candidates[0]
    for id in candidates:
        roll -= int(SCENES[id].get("weight", 10))
        if roll < 0:
            chosen = id
            break
    var out:Dictionary = SCENES[chosen].duplicate(true)
    out["id"] = chosen
    out["scene"] = true
    return out


static func survivor(coord:Vector2i) -> Dictionary:
    return SURVIVORS[EncounterCatalog._hash(coord, 241) % SURVIVORS.size()]


static func survivor_gift(coord:Vector2i) -> Array:
    return SURVIVOR_GIFTS[EncounterCatalog._hash(coord, 251) % SURVIVOR_GIFTS.size()].duplicate(true)


static func pit_radio(choice:String) -> String:
    return str(PIT_RADIO.get(choice, PIT_RADIO[""]))
