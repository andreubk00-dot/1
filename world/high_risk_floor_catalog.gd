extends RefCounted

# OSTATOK 1.21.0 — authored vertical layers for high-risk landmarks.
# These are real gameplay floors, not decorative storey counts. Each layer lives
# in a deterministic virtual interior space and keeps stable container/enemy ids.

const FLOORSETS = {
    "quarantine_center_12": {
        "entry_offset":Vector2i(1,0),
        "entry_pos":Vector2(384,206),
        "entry_label":"ЛЕСТНИЦА • ИЗОЛЯЦИОННЫЙ БЛОК",
        "floors":{
            2:{
                "label":"2 ЭТАЖ • ИЗОЛЯТОРЫ И НАБЛЮДЕНИЕ",
                "layout":"quarantine_isolation",
                "theme":"quarantine",
                "size":Vector2(1320,900),
                "enemy_profile":"high_interior",
                "enemy_count":10,
                "containers":[
                    {"id":"floor2_med_station","pos":Vector2(-360,-178),"loot":"medical_secure","name":"Пост наблюдения"},
                    {"id":"floor2_decon_store","pos":Vector2(350,172),"loot":"pharmacy","name":"Запас санпропускника"}
                ]
            },
            3:{
                "label":"3 ЭТАЖ • ЛАБОРАТОРИИ КРАСНОЙ ЗОНЫ",
                "layout":"quarantine_labs",
                "theme":"quarantine_red",
                "size":Vector2(1220,820),
                "enemy_profile":"high_core",
                "enemy_count":12,
                "containers":[
                    {"id":"floor3_lab_store","pos":Vector2(-318,-148),"loot":"medical_secure","name":"Лабораторный шкаф"},
                    {"id":"floor3_control_store","pos":Vector2(322,150),"loot":"industrial_secure","name":"Аварийный шкаф автоматики"}
                ]
            }
        }
    },
    "reserve_arsenal_bastion": {
        "entry_offset":Vector2i(2,0),
        "entry_pos":Vector2(384,208),
        "entry_label":"ЛЕСТНИЦА • ГЛАВНЫЙ АНГАР",
        "floors":{
            2:{
                "label":"2 ЭТАЖ • ГАЛЕРЕИ АНГАРА",
                "layout":"bastion_mezzanine",
                "theme":"military",
                "size":Vector2(1480,940),
                "enemy_profile":"high_interior",
                "enemy_count":10,
                "containers":[
                    {"id":"floor2_armory_locker","pos":Vector2(-400,-164),"loot":"military","name":"Шкаф караула галереи"},
                    {"id":"floor2_maintenance","pos":Vector2(390,170),"loot":"garage","name":"Комплект обслуживания подъёмников"}
                ]
            },
            3:{
                "label":"3 ЭТАЖ • КОМЕНДАТУРА И СВЯЗЬ",
                "layout":"bastion_command",
                "theme":"military_command",
                "size":Vector2(1240,820),
                "enemy_profile":"high_core",
                "enemy_count":12,
                "containers":[
                    {"id":"floor3_command_locker","pos":Vector2(-286,-142),"loot":"military_secure","name":"Шкаф комендатуры"},
                    {"id":"floor3_signal_store","pos":Vector2(284,140),"loot":"military","name":"Резерв узла связи"}
                ]
            }
        }
    },
    "regional_clinical_complex_4": {
        "entry_offset":Vector2i(0,0),
        "entry_pos":Vector2(384,214),
        "entry_label":"ЛЕСТНИЧНЫЙ ХОЛЛ • ГЛАВНЫЙ КОРПУС",
        "floors":{
            2:{
                "label":"2 ЭТАЖ • ПАЛАТЫ И ИНТЕНСИВНАЯ ТЕРАПИЯ",
                "layout":"clinical_wards",
                "theme":"medical",
                "size":Vector2(1460,960),
                "enemy_profile":"clinical_interior",
                "enemy_count":10,
                "containers":[
                    {"id":"floor2_nurse_station","pos":Vector2(-396,-182),"loot":"pharmacy","name":"Пост старшей медсестры"},
                    {"id":"floor2_icu_store","pos":Vector2(398,182),"loot":"medical_secure","name":"Запас интенсивной терапии"}
                ]
            },
            3:{
                "label":"3 ЭТАЖ • ХИРУРГИЯ И ЛАБОРАТОРИИ",
                "layout":"clinical_surgery",
                "theme":"medical_surgical",
                "size":Vector2(1340,880),
                "enemy_profile":"clinical_core",
                "enemy_count":12,
                "containers":[
                    {"id":"floor3_surgery_store","pos":Vector2(-344,-150),"loot":"medical_secure","name":"Стерильный хирургический шкаф"},
                    {"id":"floor3_lab_store","pos":Vector2(342,150),"loot":"medical_secure","name":"Лабораторный резерв"}
                ]
            }
        }
    },
    "underground_object_vector": {
        "entry_offset":Vector2i(0,0),
        "entry_pos":Vector2(384,214),
        "entry_label":"ШАХТА ДОСТУПА • СПУСК",
        "floors":{
            2:{
                "label":"ГЛУБИНА -2 • ТЕХНИЧЕСКИЙ ЯРУС",
                "layout":"vector_engineering",
                "theme":"vector",
                "size":Vector2(1320,880),
                "enemy_profile":"vector_tunnels",
                "enemy_count":10,
                "containers":[
                    {"id":"floor2_power_store","pos":Vector2(-372,-172),"loot":"industrial_secure","name":"Комплект энергослужбы"},
                    {"id":"floor2_filter_store","pos":Vector2(372,172),"loot":"industrial_secure","name":"Фильтры и расходники"}
                ]
            },
            3:{
                "label":"ГЛУБИНА -3 • КОМАНДНО-ИНЖЕНЕРНОЕ ЯДРО",
                "layout":"vector_deep_core",
                "theme":"vector_core",
                "size":Vector2(1200,820),
                "enemy_profile":"vector_core",
                "enemy_count":12,
                "containers":[
                    {"id":"floor3_engineering_store","pos":Vector2(-322,-146),"loot":"industrial_secure","name":"Резерв инженерной смены"},
                    {"id":"floor3_command_store","pos":Vector2(318,148),"loot":"military_secure","name":"Аварийный шкаф управления"}
                ]
            }
        }
    }
}

static func has_poi(poi_id:String) -> bool:
    return FLOORSETS.has(poi_id)

static func floor_set(poi_id:String) -> Dictionary:
    return FLOORSETS.get(poi_id,{}).duplicate(true)

static func floors(poi_id:String) -> Array:
    var fs = FLOORSETS.get(poi_id,{})
    var result = []
    for raw in fs.get("floors",{}).keys():
        result.append(int(raw))
    result.sort()
    return result

static func floor(poi_id:String,index:int) -> Dictionary:
    var fs = FLOORSETS.get(poi_id,{})
    return fs.get("floors",{}).get(int(index),{}).duplicate(true)

static func ground_entry(poi_id:String,cell_offset:Vector2i) -> Dictionary:
    var fs = FLOORSETS.get(poi_id,{})
    if fs.is_empty() or fs.get("entry_offset",Vector2i(999,999)) != cell_offset:
        return {}
    return {
        "pos":fs.get("entry_pos",Vector2(384,384)),
        "label":str(fs.get("entry_label","ЛЕСТНИЦА")),
        "target_floor":2
    }

static func max_floor(poi_id:String) -> int:
    var list = floors(poi_id)
    return int(list[-1]) if not list.is_empty() else 1
