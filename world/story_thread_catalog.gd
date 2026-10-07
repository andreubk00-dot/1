extends RefCounted

# OSTATOK 1.25-dev4 — narrative-only synthesis of already-read environmental traces.
# Threads never unlock routes, rewards, items or objectives. Their synthetic IDs are
# stored through the existing WorldChronicle.story_seen list, so schema 122 stays intact.

const THREADS = [
    {
        "id":"thread_medical_collapse",
        "title":"Полевая сводка: медицинский контур",
        "requires":["district_hospital_triage_sheet","clinical_wards_transfer_sheet","clinical_surgery_last_board"],
        "text":"Районная больница ещё считала расходники, когда областной комплекс уже переносил тяжёлых вручную и терял питание секциями. Медицинская сеть распалась не сразу, а звено за звеном."
    },
    {
        "id":"thread_quarantine_breakdown",
        "title":"Полевая сводка: карантинный контур",
        "requires":["checkpoint_vostok_guard_order","quarantine_triage_protocol","quarantine_red_lab_note"],
        "text":"Внешний КПП требовал отходить при потере связи, а в карантинном центре уже сбоили связь и автоматика. Бумажные журналы стали последним способом понять, какие зоны ещё контролируются."
    },
    {
        "id":"thread_security_radio_silence",
        "title":"Полевая сводка: силовой контур",
        "requires":["district_police_duty_log","bastion_outer_guard_sheet","bastion_command_signal_log"],
        "text":"Полиция теряла машины и посты, караул арсенала экономил эфир, а командный узел дошёл до коротких сеансов без ответа. Силовые точки не исчезли сразу — они перестали слышать друг друга."
    },
    {
        "id":"thread_power_infrastructure",
        "title":"Полевая сводка: промышленный контур",
        "requires":["factory_7_shift_sheet","vector_access_shift_log","vector_core_engineer_note"],
        "text":"Комбинат терял смены и питание, у «Вектора» проседала вентиляция, а глубже резерв держал лишь часть контура. Инфраструктура ещё работала кусками, пока между ними исчезали люди."
    },
    {
        "id":"thread_logistics_fragmentation",
        "title":"Полевая сводка: транспортный контур",
        "requires":["rail_depot_dispatch_log","west_convoy_manifest","repair_oil_log"],
        "text":"Депо ждало пропавший состав, колонны шли без ясного получателя, ремонтники снимали детали ради генератора. Логистика не остановилась — она рассыпалась на временные решения."
    }
]

static func ids() -> Array:
    var out:Array=[]
    for row in THREADS: out.append(str(row.get("id","")))
    return out

static func ready_unseen(seen_ids:Array) -> Array:
    var seen={}
    for raw in seen_ids: seen[str(raw)]=true
    var out:Array=[]
    for row in THREADS:
        var thread_id=str(row.get("id",""))
        if thread_id=="" or seen.has(thread_id):
            continue
        var ready=true
        for req in row.get("requires",[]):
            if not seen.has(str(req)):
                ready=false
                break
        if ready: out.append(row.duplicate(true))
    return out
