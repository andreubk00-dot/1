extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")

# OSTATOK 1.23.0-dev6 — strategic settlement infrastructure and bulk resource sinks.
# These are NOT the unapproved global ending projects. They are local settlement
# upgrades that turn one-off High Risk finds and accumulated faction stock into a
# long-term reason to keep the logistics loop alive.
const RESOURCE_KEYS = ["food","medicine","technical","security"]
const RESERVE_FLOOR = 45.0
const COMMIT_BATCH = 12.0
const MIN_REPUTATION = 75

const PROJECTS = {
    "perron":{
        "id":"perron_dispatch_warehouse",
        "title":"ДИСПЕТЧЕРСКИЙ СКЛАДСКОЙ КОНТУР",
        "description":"Перрон хочет свести склады, кухню и пропуск грузов в один учётный контур. Проект потребует старой документации КПП и большого запаса, который можно выделить только сверх аварийного резерва поселения.",
        "strategic_item":"old_checkpoint_documents",
        "strategic_label":"Документы старого КПП",
        "source_hint":"Искать стоит в закрытых резервах старых карантинных объектов.",
        "resource_targets":{"food":34.0,"medicine":0.0,"technical":18.0,"security":8.0},
        "daily_resources":{"food":0.18,"technical":0.05},
        "restock_categories":["food","water","household"],
        "restock_factor":1.06,
        "completion_reputation":8,
        "completion_news":"Перрон завершил складской диспетчерский контур: запасы теперь распределяются между кухней и складами без ручной переброски."
    },
    "rubezh":{
        "id":"rubezh_long_range_radio",
        "title":"РАДИОСЕТЬ ДАЛЬНИХ ПОСТОВ",
        "description":"Рубеж собирает устойчивую сеть для дальних патрулей. Нужна военная радиостанция и значительный запас боеприпасов, техники и медицины, выделенный из гарнизонных складов.",
        "strategic_item":"military_radio_station",
        "strategic_label":"Военная радиостанция",
        "source_hint":"Такие станции могли сохраниться только во внутренних военных хранилищах.",
        "resource_targets":{"food":0.0,"medicine":8.0,"technical":22.0,"security":34.0},
        "daily_resources":{"security":0.20,"technical":0.04},
        "restock_categories":["ammo","weapon","armor"],
        "restock_factor":1.06,
        "completion_reputation":8,
        "completion_news":"Рубеж поднял радиосеть дальних постов. Патрули теперь реже теряют связь и точнее расходуют гарнизонные резервы."
    },
    "mechanics":{
        "id":"mechanics_backup_grid",
        "title":"РЕЗЕРВНАЯ ЭНЕРГЕТИЧЕСКАЯ ЛИНИЯ",
        "description":"Артель хочет связать мастерские и топливный двор общей резервной линией. Для запуска нужен промышленный блок управления и большой технический запас со складов.",
        "strategic_item":"generator_control_unit",
        "strategic_label":"Блок управления генератором",
        "source_hint":"Подходящий контроллер стоит искать в глубоком инженерном объекте, а не в обычной мастерской.",
        "resource_targets":{"food":10.0,"medicine":0.0,"technical":38.0,"security":12.0},
        "daily_resources":{"technical":0.22,"food":0.03},
        "restock_categories":["parts","tools","electronics","technical","fuel"],
        "restock_factor":1.06,
        "completion_reputation":8,
        "completion_news":"Механики ввели резервную энергетическую линию. Мастерские и топливный двор теперь меньше зависят от одного генератора."
    },
    "lazaret":{
        "id":"lazaret_diagnostic_loop",
        "title":"ДИАГНОСТИЧЕСКИЙ КОНТУР",
        "description":"Лазарет собирает автономный диагностический контур для сложных случаев. Нужен лабораторный анализатор и крупный запас медикаментов, расходников и технических компонентов.",
        "strategic_item":"laboratory_analyzer",
        "strategic_label":"Лабораторный анализатор",
        "source_hint":"Рабочий анализатор вероятнее всего сохранился в закрытом медицинском комплексе.",
        "resource_targets":{"food":12.0,"medicine":36.0,"technical":18.0,"security":0.0},
        "daily_resources":{"medicine":0.22,"technical":0.04},
        "restock_categories":["medicine","medical","chemicals"],
        "restock_factor":1.06,
        "completion_reputation":8,
        "completion_news":"Лазарет запустил диагностический контур. Часть сложных случаев теперь разбирают на месте, не расходуя аварийный медицинский резерв вслепую."
    }
}

static func ids() -> Array:
    return PROJECTS.keys()

static func project(faction_id:String) -> Dictionary:
    return PROJECTS.get(faction_id,{}).duplicate(true)

static func strategic_item_ids() -> Array:
    var out = []
    for faction_id in PROJECTS.keys():
        out.append(str(PROJECTS[faction_id].get("strategic_item","")))
    return out

static func faction_for_item(item_id:String) -> String:
    for faction_id in PROJECTS.keys():
        if str(PROJECTS[faction_id].get("strategic_item","")) == item_id:
            return str(faction_id)
    return ""

static func default_record() -> Dictionary:
    return {
        "strategic_installed":false,
        "installed_day":0,
        "resources":{"food":0.0,"medicine":0.0,"technical":0.0,"security":0.0},
        "total_committed":0.0,
        "completed":false,
        "completed_day":0
    }

static func default_state() -> Dictionary:
    var records = {}
    for faction_id in PROJECTS.keys():
        records[str(faction_id)] = default_record()
    return {"records":records}

static func sanitize_state(raw) -> Dictionary:
    var clean = default_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    var source_records = raw.get("records",raw)
    if typeof(source_records) != TYPE_DICTIONARY:
        return clean
    for faction_id in PROJECTS.keys():
        var source = source_records.get(faction_id,{})
        if typeof(source) != TYPE_DICTIONARY:
            continue
        var rec = clean["records"][faction_id]
        rec["strategic_installed"] = bool(source.get("strategic_installed",false))
        rec["installed_day"] = max(0,int(source.get("installed_day",0)))
        var progress = source.get("resources",{})
        var targets = PROJECTS[faction_id].get("resource_targets",{})
        if typeof(progress) == TYPE_DICTIONARY:
            for resource_id in RESOURCE_KEYS:
                rec["resources"][resource_id] = clamp(float(progress.get(resource_id,0.0)),0.0,float(targets.get(resource_id,0.0)))
        var total := 0.0
        for resource_id in RESOURCE_KEYS:
            total += float(rec["resources"].get(resource_id,0.0))
        rec["total_committed"] = total
        rec["completed_day"] = max(0,int(source.get("completed_day",0)))
        rec["completed"] = bool(source.get("completed",false)) and _requirements_met_record(str(faction_id),rec)
        if not rec["completed"]:
            rec["completed_day"] = 0
        clean["records"][faction_id] = rec
    return clean

static func ensure_state(state:Dictionary) -> void:
    state["settlement_projects"] = sanitize_state(state.get("settlement_projects",{}))

static func record(state:Dictionary,faction_id:String) -> Dictionary:
    ensure_state(state)
    return state["settlement_projects"].get("records",{}).get(faction_id,{}).duplicate(true)

static func _write_record(state:Dictionary,faction_id:String,rec:Dictionary) -> void:
    ensure_state(state)
    state["settlement_projects"]["records"][faction_id] = rec

static func _requirements_met_record(faction_id:String,rec:Dictionary) -> bool:
    if not PROJECTS.has(faction_id) or not bool(rec.get("strategic_installed",false)):
        return false
    var targets = PROJECTS[faction_id].get("resource_targets",{})
    var progress = rec.get("resources",{})
    if typeof(progress) != TYPE_DICTIONARY:
        return false
    for resource_id in RESOURCE_KEYS:
        if float(progress.get(resource_id,0.0)) + 0.001 < float(targets.get(resource_id,0.0)):
            return false
    return true

static func is_completed(state:Dictionary,faction_id:String) -> bool:
    return bool(record(state,faction_id).get("completed",false))

static func has_access(state:Dictionary,faction_id:String) -> bool:
    return int(state.get("factions",{}).get(faction_id,{}).get("reputation",0)) >= MIN_REPUTATION

static func install_strategic_item(state:Dictionary,faction_id:String,item_id:String,world_day:int) -> Dictionary:
    if not PROJECTS.has(faction_id):
        return {"ok":false,"reason":"unknown_project"}
    if not has_access(state,faction_id):
        return {"ok":false,"reason":"reputation","required":MIN_REPUTATION}
    var spec = PROJECTS[faction_id]
    if str(spec.get("strategic_item","")) != item_id:
        return {"ok":false,"reason":"wrong_item"}
    var rec = record(state,faction_id)
    if bool(rec.get("completed",false)):
        return {"ok":false,"reason":"completed"}
    if bool(rec.get("strategic_installed",false)):
        return {"ok":false,"reason":"already_installed"}
    rec["strategic_installed"] = true
    rec["installed_day"] = max(1,world_day)
    var completed_now = _finish_if_ready(state,faction_id,rec,world_day)
    if not completed_now:
        _write_record(state,faction_id,rec)
    return {"ok":true,"completed_now":completed_now,"record":record(state,faction_id)}

static func commit_resources(state:Dictionary,faction_id:String,world_day:int,batch:float = COMMIT_BATCH) -> Dictionary:
    if not PROJECTS.has(faction_id):
        return {"ok":false,"reason":"unknown_project","committed":{}}
    if not has_access(state,faction_id):
        return {"ok":false,"reason":"reputation","required":MIN_REPUTATION,"committed":{}}
    var rec = record(state,faction_id)
    if bool(rec.get("completed",false)):
        return {"ok":false,"reason":"completed","committed":{}}
    var faction_rec = state.get("factions",{}).get(faction_id,{})
    if typeof(faction_rec) != TYPE_DICTIONARY:
        return {"ok":false,"reason":"missing_faction","committed":{}}
    var stock = faction_rec.get("resources",{})
    if typeof(stock) != TYPE_DICTIONARY:
        return {"ok":false,"reason":"missing_resources","committed":{}}
    var targets = PROJECTS[faction_id].get("resource_targets",{})
    var progress = rec.get("resources",{})
    var remaining_batch = max(0.0,batch)
    var committed = {}
    for resource_id in RESOURCE_KEYS:
        if remaining_batch <= 0.001:
            break
        var target = float(targets.get(resource_id,0.0))
        var current_progress = float(progress.get(resource_id,0.0))
        var needed = max(0.0,target - current_progress)
        if needed <= 0.001:
            continue
        var current_stock = float(stock.get(resource_id,0.0))
        var available = max(0.0,current_stock - RESERVE_FLOOR)
        var take = min(needed,min(available,remaining_batch))
        if take <= 0.001:
            continue
        stock[resource_id] = current_stock - take
        progress[resource_id] = current_progress + take
        committed[resource_id] = take
        remaining_batch -= take
    if committed.is_empty():
        return {"ok":false,"reason":"reserve_floor","committed":{},"reserve_floor":RESERVE_FLOOR}
    faction_rec["resources"] = stock
    state["factions"][faction_id] = faction_rec
    rec["resources"] = progress
    var total := 0.0
    for resource_id in RESOURCE_KEYS:
        total += float(progress.get(resource_id,0.0))
    rec["total_committed"] = total
    var completed_now = _finish_if_ready(state,faction_id,rec,world_day)
    if not completed_now:
        _write_record(state,faction_id,rec)
    return {"ok":true,"committed":committed,"completed_now":completed_now,"record":record(state,faction_id)}

static func _finish_if_ready(state:Dictionary,faction_id:String,rec:Dictionary,world_day:int) -> bool:
    if bool(rec.get("completed",false)) or not _requirements_met_record(faction_id,rec):
        return false
    rec["completed"] = true
    rec["completed_day"] = max(1,world_day)
    _write_record(state,faction_id,rec)
    var faction_rec = state.get("factions",{}).get(faction_id,{})
    if typeof(faction_rec) == TYPE_DICTIONARY:
        faction_rec["reputation"] = clamp(int(faction_rec.get("reputation",0)) + int(PROJECTS[faction_id].get("completion_reputation",0)),-100,250)
        state["factions"][faction_id] = faction_rec
    return true

static func apply_daily_effects(state:Dictionary) -> void:
    ensure_state(state)
    for faction_id in PROJECTS.keys():
        if not is_completed(state,str(faction_id)):
            continue
        var faction_rec = state.get("factions",{}).get(faction_id,{})
        if typeof(faction_rec) != TYPE_DICTIONARY:
            continue
        var resources = faction_rec.get("resources",{})
        if typeof(resources) != TYPE_DICTIONARY:
            continue
        for resource_id in PROJECTS[faction_id].get("daily_resources",{}).keys():
            resources[resource_id] = clamp(float(resources.get(resource_id,0.0)) + float(PROJECTS[faction_id]["daily_resources"][resource_id]),0.0,100.0)
        faction_rec["resources"] = resources
        state["factions"][faction_id] = faction_rec

static func restock_factor(state:Dictionary,faction_id:String,item_id:String) -> float:
    if not PROJECTS.has(faction_id) or not is_completed(state,faction_id):
        return 1.0
    var category = FactionCatalog.item_category(item_id)
    if category in PROJECTS[faction_id].get("restock_categories",[]):
        return float(PROJECTS[faction_id].get("restock_factor",1.0))
    return 1.0

static func progress_fraction(state:Dictionary,faction_id:String) -> float:
    if not PROJECTS.has(faction_id):
        return 0.0
    var rec = record(state,faction_id)
    var targets = PROJECTS[faction_id].get("resource_targets",{})
    var progress = rec.get("resources",{})
    var total_target := 1.0 # strategic item counts as one equal milestone.
    var total_done := 1.0 if bool(rec.get("strategic_installed",false)) else 0.0
    for resource_id in RESOURCE_KEYS:
        var target = float(targets.get(resource_id,0.0))
        if target <= 0.001:
            continue
        total_target += 1.0
        total_done += clamp(float(progress.get(resource_id,0.0)) / target,0.0,1.0)
    return clamp(total_done / total_target,0.0,1.0)

static func resource_label(resource_id:String) -> String:
    match resource_id:
        "food": return "продовольствие/вода"
        "medicine": return "медицина"
        "technical": return "детали/топливо"
        "security": return "боезапас/охрана"
    return resource_id

static func progress_text(state:Dictionary,faction_id:String) -> String:
    if not PROJECTS.has(faction_id):
        return ""
    var spec = PROJECTS[faction_id]
    var rec = record(state,faction_id)
    var lines = []
    lines.append("СТРАТЕГИЧЕСКИЙ УЗЕЛ: %s" % ("установлен" if bool(rec.get("strategic_installed",false)) else "не найден"))
    var targets = spec.get("resource_targets",{})
    var progress = rec.get("resources",{})
    for resource_id in RESOURCE_KEYS:
        var target = float(targets.get(resource_id,0.0))
        if target <= 0.001:
            continue
        lines.append("%s: %d/%d" % [resource_label(resource_id).to_upper(),int(round(float(progress.get(resource_id,0.0)))),int(round(target))])
    return "\n".join(lines)
