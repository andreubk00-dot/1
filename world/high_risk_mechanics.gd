extends RefCounted

# OSTATOK 1.23.0-dev6 — mechanical state for authored High Risk sites.
# Visual identity and authored geometry live in the existing catalogues. This layer
# only owns access cycles, local incidents, depleted/reoccupied state and anti-farm
# tuning. It deliberately uses no self-key requirements: access is earned by clearing
# the upper secure floor and performing an emergency override on the existing stair.

const SITE_IDS = [
    "quarantine_center_12",
    "reserve_arsenal_bastion",
    "regional_clinical_complex_4",
    "underground_object_vector"
]

const SITES = {
    "quarantine_center_12":{
        "core_offset":Vector2i(2,1),
        "core_profile":"quarantine_core",
        "strategic_item":"old_checkpoint_documents",
        "access_label":"АВАРИЙНЫЙ ШЛЮЗ СТЕРИЛЬНОГО СЕКТОРА",
        "access_news":"В карантинном центре №12 вскрыт аварийный доступ к стерильному резерву.",
        "incident_offset":Vector2i(1,1),
        "incident_profile":"high_core",
        "incident_count":3,
        "incident_label":"НАРУШЕНИЕ ГЕРМЕТИЧНОСТИ",
        "incident_news":"В красной зоне карантинного центра снова слышны заражённые: гермоконтур не удержал давление.",
        "reoccupation_ratio":0.58
    },
    "reserve_arsenal_bastion":{
        "core_offset":Vector2i(2,1),
        "core_profile":"arsenal_core",
        "strategic_item":"military_radio_station",
        "access_label":"АВАРИЙНЫЙ ДОПУСК К ВНУТРЕННЕМУ ХРАНИЛИЩУ",
        "access_news":"В «Бастионе» снята блокировка внутреннего оружейного хранилища.",
        "incident_offset":Vector2i(1,1),
        "incident_profile":"high_core",
        "incident_count":4,
        "incident_label":"ШУМ В КОМАНДНОМ ДВОРЕ",
        "incident_news":"Из командного двора «Бастиона» снова идёт шум. Похоже, заражённые стянулись к внутреннему периметру.",
        "reoccupation_ratio":0.66
    },
    "regional_clinical_complex_4":{
        "core_offset":Vector2i(2,1),
        "core_profile":"clinical_core",
        "strategic_item":"laboratory_analyzer",
        "access_label":"АВАРИЙНЫЙ ДОПУСК В ХИРУРГИЧЕСКИЙ БЛОК",
        "access_news":"В клиническом комплексе №4 восстановлен аварийный доступ к хирургическому резерву.",
        "incident_offset":Vector2i(1,1),
        "incident_profile":"clinical_core",
        "incident_count":4,
        "incident_label":"ТРЕВОГА В ИЗОЛЯЦИИ",
        "incident_news":"В изоляционном корпусе клинического комплекса сработала старая тревога; заражённые снова стягиваются к переходу.",
        "reoccupation_ratio":0.60
    },
    "underground_object_vector":{
        "core_offset":Vector2i(1,2),
        "core_profile":"vector_core",
        "strategic_item":"generator_control_unit",
        "access_label":"РУЧНОЙ OVERRIDE КОМАНДНО-ИНЖЕНЕРНОГО ЯДРА",
        "access_news":"На объекте «Вектор» вручную снята блокировка глубокого инженерного ядра.",
        "incident_offset":Vector2i(1,1),
        "incident_profile":"vector_core",
        "incident_count":4,
        "incident_label":"АВАРИЙНЫЙ СИГНАЛ В КОМАНДНОМ СЕКТОРЕ",
        "incident_news":"В глубине «Вектора» снова поднялся аварийный сигнал. Шум вытянул заражённых к командному сектору.",
        "reoccupation_ratio":0.70
    }
}

static func has(poi_id:String) -> bool:
    return SITES.has(poi_id)

static func site(poi_id:String) -> Dictionary:
    return SITES.get(poi_id,{}).duplicate(true)

static func default_site_state() -> Dictionary:
    return {
        "access_cycle":-1,
        "access_day":0,
        "incident_announced_cycle":-1,
        "incident_resolved_cycle":-1,
        "depleted_cycle":-1,
        "depleted_day":0,
        "reoccupied_cycle":-1,
        "reoccupied_day":0,
        "strategic_spawned":false
    }

static func default_state() -> Dictionary:
    var out = {}
    for poi_id in SITE_IDS:
        out[poi_id] = default_site_state()
    return out

static func sanitize_state(raw) -> Dictionary:
    var clean = default_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    for poi_id in SITE_IDS:
        var source = raw.get(poi_id,{})
        if typeof(source) != TYPE_DICTIONARY:
            continue
        clean[poi_id] = {
            "access_cycle":max(-1,int(source.get("access_cycle",-1))),
            "access_day":max(0,int(source.get("access_day",0))),
            "incident_announced_cycle":max(-1,int(source.get("incident_announced_cycle",-1))),
            "incident_resolved_cycle":max(-1,int(source.get("incident_resolved_cycle",-1))),
            "depleted_cycle":max(-1,int(source.get("depleted_cycle",-1))),
            "depleted_day":max(0,int(source.get("depleted_day",0))),
            "reoccupied_cycle":max(-1,int(source.get("reoccupied_cycle",-1))),
            "reoccupied_day":max(0,int(source.get("reoccupied_day",0))),
            "strategic_spawned":bool(source.get("strategic_spawned",false))
        }
    return clean

static func ensure_state(state:Dictionary) -> void:
    var clean = sanitize_state(state)
    state.clear()
    for poi_id in clean.keys():
        state[poi_id] = clean[poi_id]

static func record(state:Dictionary,poi_id:String) -> Dictionary:
    if not has(poi_id):
        return {}
    if not state.has(poi_id) or typeof(state.get(poi_id,{})) != TYPE_DICTIONARY:
        state[poi_id] = default_site_state()
    return state[poi_id]


static func strategic_item(poi_id:String) -> String:
    return str(SITES.get(poi_id,{}).get("strategic_item",""))

static func strategic_spawned(state:Dictionary,poi_id:String) -> bool:
    if not has(poi_id):
        return true
    return bool(record(state,poi_id).get("strategic_spawned",false))

static func mark_strategic_spawned(state:Dictionary,poi_id:String) -> bool:
    if not has(poi_id):
        return false
    var rec = record(state,poi_id)
    if bool(rec.get("strategic_spawned",false)):
        return false
    rec["strategic_spawned"] = true
    state[poi_id] = rec
    return true

static func access_unlocked(state:Dictionary,poi_id:String,cycle:int) -> bool:
    if not has(poi_id):
        return true
    var rec = record(state,poi_id)
    return int(rec.get("access_cycle",-1)) == max(0,cycle)

static func unlock_access(state:Dictionary,poi_id:String,cycle:int,day:int) -> bool:
    if not has(poi_id):
        return false
    var rec = record(state,poi_id)
    var safe_cycle = max(0,cycle)
    if int(rec.get("access_cycle",-1)) == safe_cycle:
        return false
    rec["access_cycle"] = safe_cycle
    rec["access_day"] = max(1,day)
    state[poi_id] = rec
    return true

static func mark_incident_announced(state:Dictionary,poi_id:String,cycle:int) -> bool:
    if not has(poi_id):
        return false
    var rec = record(state,poi_id)
    var safe_cycle = max(0,cycle)
    if int(rec.get("incident_announced_cycle",-1)) == safe_cycle:
        return false
    rec["incident_announced_cycle"] = safe_cycle
    state[poi_id] = rec
    return true

static func mark_incident_resolved(state:Dictionary,poi_id:String,cycle:int) -> bool:
    if not has(poi_id):
        return false
    var rec = record(state,poi_id)
    var safe_cycle = max(0,cycle)
    if int(rec.get("incident_resolved_cycle",-1)) == safe_cycle:
        return false
    rec["incident_resolved_cycle"] = safe_cycle
    state[poi_id] = rec
    return true

static func incident_resolved(state:Dictionary,poi_id:String,cycle:int) -> bool:
    if not has(poi_id):
        return true
    return int(record(state,poi_id).get("incident_resolved_cycle",-1)) == max(0,cycle)

static func mark_depleted(state:Dictionary,poi_id:String,cycle:int,day:int) -> bool:
    if not has(poi_id):
        return false
    var rec = record(state,poi_id)
    var safe_cycle = max(0,cycle)
    if int(rec.get("depleted_cycle",-1)) == safe_cycle:
        return false
    rec["depleted_cycle"] = safe_cycle
    rec["depleted_day"] = max(1,day)
    state[poi_id] = rec
    return true

static func mark_reoccupied(state:Dictionary,poi_id:String,cycle:int,day:int) -> bool:
    if not has(poi_id):
        return false
    var rec = record(state,poi_id)
    var safe_cycle = max(0,cycle)
    if int(rec.get("reoccupied_cycle",-1)) == safe_cycle:
        return false
    rec["reoccupied_cycle"] = safe_cycle
    rec["reoccupied_day"] = max(1,day)
    state[poi_id] = rec
    return true

static func incident_spawn_id(index:int) -> int:
    return 5000 + max(0,index)

static func recovery_keep_chance(rarity:String,cycle:int) -> float:
    # Initial authored caches are untouched. Recovered caches become salvage rather
    # than a renewable source of top-tier trade stock. Specialized/unique items do
    # not replenish; rare items become increasingly uncommon on later revisits.
    if cycle <= 0:
        return 1.0
    match rarity:
        "unique", "specialized": return 0.0
        "rare": return 0.55 if cycle == 1 else 0.30
        "scarce": return 0.78 if cycle == 1 else 0.58
    return 0.88 if cycle == 1 else 0.72

static func recovery_qty_multiplier(cycle:int) -> float:
    if cycle <= 0:
        return 1.0
    return 0.72 if cycle == 1 else 0.55

static func reoccupation_ratio(poi_id:String) -> float:
    return clamp(float(SITES.get(poi_id,{}).get("reoccupation_ratio",0.62)),0.35,0.85)

static func status_label(access_open:bool,remaining_threats:int,ready_day:int,world_day:int) -> String:
    if ready_day > world_day:
        return "ИСТОЩЁН • ВОССТАНОВЛЕНИЕ"
    if ready_day > 0 and world_day >= ready_day:
        return "УГРОЗА ВОЗВРАЩАЕТСЯ"
    if remaining_threats <= 0:
        return "ЗАЧИЩЕН"
    if access_open:
        return "ВНУТРЕННИЙ ДОСТУП ВСКРЫТ"
    return "АКТИВНАЯ УГРОЗА"
