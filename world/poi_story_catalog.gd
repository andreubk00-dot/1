extends RefCounted

# OSTATOK 1.25-dev2 — sparse authored readable traces for ordinary compound POIs.
# These entries reuse the dev1 world-chronicle reader and contain no quest,
# reward, loot, enemy, route or persistence semantics.

const ENTRIES = {
    "garage_coop_sever|0,-1": {
        "poi_id":"garage_coop_sever","cell":Vector2i(0,-1),
        "id":"garage_sever_repair_order","title":"Наряд на ремонт","prompt":"НАРЯД",
        "text":"«Шестой бокс — не закрывать до вечера. Генератор опять глохнет под нагрузкой. Канистры у ремзоны не трогать — бензин оставили для сварки.»",
        "prop_kind":"paper_stack","pos":Vector2(384,420),"scale":0.40
    },
    "factory_7|0,1": {
        "poi_id":"factory_7","cell":Vector2i(0,1),
        "id":"factory_7_shift_sheet","title":"Сменный лист","prompt":"ВЕДОМОСТЬ",
        "text":"«Вторая смена не вышла. Проходную закрыть после 19:00. Архивные папки перенести из АБК, пока в энергосекторе снова не пропало питание.»",
        "prop_kind":"paper_stack","pos":Vector2(360,500),"scale":0.40
    },
    "rail_depot|0,0": {
        "poi_id":"rail_depot","cell":Vector2i(0,0),
        "id":"rail_depot_dispatch_log","title":"Лист диспетчера","prompt":"ВЕДОМОСТЬ",
        "text":"«Путь на восток занят пустыми платформами. Маневровый не запускать без осмотра кабеля. Последний состав так и не вернулся с промышленной ветки.»",
        "prop_kind":"newspapers","pos":Vector2(384,420),"scale":0.38
    },
    "dacha_coop_zarya|0,0": {
        "poi_id":"dacha_coop_zarya","cell":Vector2i(0,0),
        "id":"zarya_board_notice","title":"Лист правления СНТ","prompt":"ОБЪЯВЛЕНИЕ",
        "text":"«Воду из общей ёмкости брать только утром. После заката ворота не открывать. Кто идёт к дороге — отмечайтесь у дома №18.»",
        "prop_kind":"paper_stack","pos":Vector2(384,430),"scale":0.40
    },
    "district_hospital|0,0": {
        "poi_id":"district_hospital","cell":Vector2i(0,0),
        "id":"district_hospital_triage_sheet","title":"Лист приёмного отделения","prompt":"ЛИСТОК",
        "text":"«Перевязочные материалы считать вручную. Тяжёлых — в лечебный корпус, остальных держать у приёмного поста. Аптека выдаёт только по записи.»",
        "prop_kind":"paper_stack","pos":Vector2(384,420),"scale":0.40
    },
    "district_police|0,0": {
        "poi_id":"district_police","cell":Vector2i(0,0),
        "id":"district_police_duty_log","title":"Журнал дежурной части","prompt":"ЖУРНАЛ",
        "text":"«Связь с северным постом пропала после полуночи. Две машины не вернулись. Оружейную не вскрывать без старшего смены.»",
        "prop_kind":"newspapers","pos":Vector2(384,420),"scale":0.38
    },
    "hunting_cordon|0,0": {
        "poi_id":"hunting_cordon","cell":Vector2i(0,0),
        "id":"cordon_sosny_keeper_log","title":"Журнал кордона","prompt":"ЖУРНАЛ",
        "text":"«У просеки снова следы людей, но костров не видно. Соль и патроны оставил в сухом месте. Если вернусь поздно — дровяник не запирать.»",
        "prop_kind":"paper_stack","pos":Vector2(384,420),"scale":0.40
    },
    "military_checkpoint|0,0": {
        "poi_id":"military_checkpoint","cell":Vector2i(0,0),
        "id":"checkpoint_vostok_guard_order","title":"Приказ караулу","prompt":"ПРИКАЗ",
        "text":"«Шлагбаум держать закрытым. Гражданский транспорт разворачивать. Радио проверять каждый час; при потере связи отходить к складскому сектору.»",
        "prop_kind":"paper_stack","pos":Vector2(384,420),"scale":0.40
    }
}

static func cell_key(cell_offset:Vector2i) -> String:
    return "%d,%d" % [cell_offset.x,cell_offset.y]

static func entry_key(poi_id:String,cell_offset:Vector2i) -> String:
    return "%s|%s" % [poi_id,cell_key(cell_offset)]

static func clue_for(poi_id:String,cell_offset:Vector2i) -> Dictionary:
    var key = entry_key(poi_id,cell_offset)
    if not ENTRIES.has(key):
        return {}
    return ENTRIES[key].duplicate(true)

static func ids() -> Array:
    var out:Array = []
    for entry in ENTRIES.values():
        out.append(str(entry.get("id","")))
    return out
