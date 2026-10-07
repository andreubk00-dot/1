extends RefCounted

# OSTATOK 1.25-dev1 — sparse authored environmental story traces layered onto
# deterministic finite encounters inside the current region map. These are not
# quests: no rewards, objectives, route unlocks or map arrows are encoded here.

const CLUES = {
    "1,-2": {
        "event_id":"abandoned_camp",
        "id":"north_camp_rain_log",
        "title":"Промокший листок","prompt":"ЛИСТОК",
        "text":"«Воду ещё собирает бочка. Если ночью снова пойдёт дождь, утром уходим. На дороге слишком много шума.»",
        "prop_kind":"paper_stack","pos":Vector2(22,-38),"scale":0.40
    },
    "6,-2": {
        "event_id":"abandoned_camp",
        "id":"outer_camp_watch_note",
        "title":"Обрывок дежурства","prompt":"ЛИСТОК",
        "text":"«Смена Пашки до рассвета. Костёр после полуночи не разжигать. Дважды слышали моторы, но никто не остановился.»",
        "prop_kind":"newspapers","pos":Vector2(-28,-38),"scale":0.38
    },
    "3,-6": {
        "event_id":"repair_breakdown",
        "id":"repair_oil_log",
        "title":"Масляный журнал","prompt":"ЖУРНАЛ",
        "text":"«Генератор держится на перемычке. Новых предохранителей нет. Снимали детали с двух машин и всё равно не хватило.»",
        "prop_kind":"paper_stack","pos":Vector2(-30,-42),"scale":0.40
    },
    "-5,1": {
        "event_id":"looted_convoy",
        "id":"west_convoy_manifest",
        "title":"Оборванная накладная","prompt":"НАКЛАДНАЯ",
        "text":"«Ящики: фильтры, кабель, сухпай. Получатель не указан. В графе маршрута — только печать старого склада.»",
        "prop_kind":"paper_stack","pos":Vector2(-76,-46),"scale":0.40
    },
    "2,5": {
        "event_id":"looted_convoy",
        "id":"belt_convoy_driver_note",
        "title":"Запись водителя","prompt":"ЗАПИСКА",
        "text":"«На восточном объезде снова стреляли. В колонне спорят, кто должен идти первым. До темноты уже не успеем.»",
        "prop_kind":"newspapers","pos":Vector2(72,-46),"scale":0.38
    },
    "3,1": {
        "event_id":"feeding_site",
        "id":"industrial_fight_warning",
        "title":"Предупреждение на картоне","prompt":"ЗАПИСКА",
        "text":"«Не подходить к остановке. Они возвращаются на запах и шум. Мы ушли через дворы, пока было тихо.»",
        "prop_kind":"paper_stack","pos":Vector2(28,-38),"scale":0.38
    },
    "-5,4": {
        "event_id":"feeding_site",
        "id":"dacha_fight_note",
        "title":"Смятая записка","prompt":"ЗАПИСКА",
        "text":"«Сначала было трое. Потом из-за заборов вышли ещё. Саша отвёл их к дороге, остальные ушли через сады.»",
        "prop_kind":"newspapers","pos":Vector2(-28,-38),"scale":0.38
    },
    "-6,5": {
        "event_id":"feeding_site",
        "id":"rural_last_calendar",
        "title":"Клочок календаря","prompt":"ЛИСТОК",
        "text":"«Соседи не вернулись к ужину. Утром нашли следы у дороги. После этого калитку больше не открывали на стук.»",
        "prop_kind":"paper_stack","pos":Vector2(0,38),"scale":0.38
    }
}

static func coord_key(coord:Vector2i) -> String:
    return "%d,%d" % [coord.x,coord.y]

static func clue_for(coord:Vector2i,event_id:String) -> Dictionary:
    var key = coord_key(coord)
    if not CLUES.has(key):
        return {}
    var clue:Dictionary = CLUES[key]
    if str(clue.get("event_id","")) != event_id:
        return {}
    return clue.duplicate(true)

static func ids() -> Array:
    var out:Array = []
    for clue in CLUES.values():
        out.append(str(clue.get("id","")))
    return out
