extends RefCounted

# OSTATOK 1.25-dev3 — sparse readable traces for the four existing High Risk sites.
# Narrative only: no rewards, objectives, routes, cache hints, strategic-item hints,
# access flags or persistence fields live here. Seen-state reuses WorldChronicle.

const GROUND = {
    "regional_clinical_complex_4|0,1": {
        "poi_id":"regional_clinical_complex_4","cell":Vector2i(0,1),
        "id":"clinical_wards_transfer_sheet","title":"Лист перевода пациентов","prompt":"ЛИСТОК",
        "text":"«Палатный корпус переполнен. Кислород экономить до утра. Лифт не отвечает, тяжёлых переносим вручную через внутренний двор.»",
        "prop_kind":"paper_stack","pos":Vector2(384,430),"scale":0.40
    },
    "quarantine_center_12|0,0": {
        "poi_id":"quarantine_center_12","cell":Vector2i(0,0),
        "id":"quarantine_triage_protocol","title":"Лист наружного триажа","prompt":"ПРОТОКОЛ",
        "text":"«Красная метка — отдельно от очереди. После третьей тревоги новые машины больше не принимать. Связь с лабораторным блоком нестабильна.»",
        "prop_kind":"paper_stack","pos":Vector2(384,420),"scale":0.40
    },
    "reserve_arsenal_bastion|0,0": {
        "poi_id":"reserve_arsenal_bastion","cell":Vector2i(0,0),
        "id":"bastion_outer_guard_sheet","title":"Лист внешнего караула","prompt":"НАРЯД",
        "text":"«Смена у ворот — по двое. После обстрела техника остаётся на площадке. Радио держать на коротких сеансах, прожектор включать только по тревоге.»",
        "prop_kind":"newspapers","pos":Vector2(384,420),"scale":0.38
    },
    "underground_object_vector|0,0": {
        "poi_id":"underground_object_vector","cell":Vector2i(0,0),
        "id":"vector_access_shift_log","title":"Журнал входной смены","prompt":"ЖУРНАЛ",
        "text":"«Вентиляция снова проседает при запуске насосов. Верхний пост просит не держать гермошлюз открытым. Ночная смена вниз не спустилась.»",
        "prop_kind":"paper_stack","pos":Vector2(384,420),"scale":0.40
    }
}

const FLOORS = {
    "regional_clinical_complex_4|3": {
        "poi_id":"regional_clinical_complex_4","floor":3,
        "id":"clinical_surgery_last_board","title":"Запись операционной бригады","prompt":"ЗАПИСКА",
        "text":"«Стерильный коридор держали до последнего. Дежурная бригада ушла в реанимацию, когда свет начал гаснуть секциями. Возвращаться никто не обещал.»",
        "prop_kind":"paper_stack","pos":Vector2(-344,-70),"scale":0.40
    },
    "quarantine_center_12|3": {
        "poi_id":"quarantine_center_12","floor":3,
        "id":"quarantine_red_lab_note","title":"Лабораторная пометка","prompt":"ЗАПИСКА",
        "text":"«Образцы переносили между холодильной и лабораторией вручную. После аварии автоматика дверей путала статусы помещений. Журнал сверяли на бумаге.»",
        "prop_kind":"newspapers","pos":Vector2(-318,-70),"scale":0.38
    },
    "reserve_arsenal_bastion|3": {
        "poi_id":"reserve_arsenal_bastion","floor":3,
        "id":"bastion_command_signal_log","title":"Журнал узла связи","prompt":"ЖУРНАЛ",
        "text":"«Последний устойчивый сеанс — короткий, без подтверждения адресата. Командование приказало беречь аккумуляторы и не отвечать на незнакомые позывные.»",
        "prop_kind":"paper_stack","pos":Vector2(-360,-70),"scale":0.40
    },
    "underground_object_vector|3": {
        "poi_id":"underground_object_vector","floor":3,
        "id":"vector_core_engineer_note","title":"Запись инженерной смены","prompt":"ЖУРНАЛ",
        "text":"«Резервное питание держит только часть контура. Серверный зал перегревается, вентиляция работает рывками. Смену наверху предупредили, ответа не получили.»",
        "prop_kind":"paper_stack","pos":Vector2(-322,-70),"scale":0.40
    }
}

static func cell_key(cell_offset:Vector2i) -> String:
    return "%d,%d" % [cell_offset.x,cell_offset.y]

static func ground_key(poi_id:String,cell_offset:Vector2i) -> String:
    return "%s|%s" % [poi_id,cell_key(cell_offset)]

static func floor_key(poi_id:String,floor_index:int) -> String:
    return "%s|%d" % [poi_id,floor_index]

static func ground_clue(poi_id:String,cell_offset:Vector2i) -> Dictionary:
    var key = ground_key(poi_id,cell_offset)
    return GROUND.get(key,{}).duplicate(true)

static func floor_clue(poi_id:String,floor_index:int) -> Dictionary:
    var key = floor_key(poi_id,floor_index)
    return FLOORS.get(key,{}).duplicate(true)

static func ids() -> Array:
    var out:Array = []
    for entry in GROUND.values(): out.append(str(entry.get("id","")))
    for entry in FLOORS.values(): out.append(str(entry.get("id","")))
    return out
