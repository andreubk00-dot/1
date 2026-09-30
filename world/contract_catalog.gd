extends RefCounted

# OSTATOK 1.22-dev3 — authored faction contracts.
# Templates describe intent and rewards; contract_system.gd owns lifecycle/state.
const BOARDS = {
    "perron_steward":{"faction":"perron","name":"Вера Андреевна","label":"ХОЗЯЙСТВЕННЫЕ ПОРУЧЕНИЯ"},
    "rubezh_dispatch":{"faction":"rubezh","name":"Ирина","label":"ДИСПЕТЧЕРСКАЯ РУБЕЖА"},
    "mechanics_electrician":{"faction":"mechanics","name":"Гена","label":"ЗАКАЗЫ АРТЕЛИ"},
    "lazaret_doctor":{"faction":"lazaret","name":"Доктор Миронова","label":"СНАБЖЕНИЕ ЛАЗАРЕТА"}
}

# requirements for delivery contracts are alternatives: satisfying any inner array is valid.
# Discovery contracts deliberately provide verbal hints instead of exact map coordinates.
const TEMPLATES = {
    "perron_food_reserve":{
        "faction":"perron","title":"КУХОННЫЙ РЕЗЕРВ","kind":"delivery","need_key":"food","min_rep":0,
        "description":"Кухня Перрона просит пополнить общий запас до следующей поставки.",
        "hint":"Подойдут консервы или зерно — везти можно тем, что удалось найти.",
        "requirements":[[{"id":"canned_meat","qty":6}],[{"id":"grain","qty":10}]],
        "reward":{"tickets":52,"reputation":8,"resources":{"food":14.0}}
    },
    "perron_waterworks":{
        "faction":"perron","title":"ВОДОНАПОРНАЯ","kind":"delivery","need_key":"technical","min_rep":25,
        "description":"Водяной узел работает на изношенных фильтрах и латках. Нужны расходники для ремонта.",
        "hint":"Можно привезти новые фильтры либо собрать ремонтный комплект из доступных материалов.",
        "requirements":[[{"id":"water_filter","qty":2}],[{"id":"scrap","qty":10},{"id":"tape","qty":4}]],
        "reward":{"tickets":78,"reputation":10,"resources":{"technical":12.0,"food":5.0}}
    },
    "perron_zarya_route":{
        "faction":"perron","title":"ДОРОГА К «ЗАРЕ»","kind":"discover_poi","need_key":"security","min_rep":25,
        "description":"Перрон хочет понять, можно ли снова использовать дорогу через дачные массивы.",
        "hint":"Проверь СНТ «Заря» западнее города и вернись с наблюдениями. Точная точка не отмечается.",
        "poi_id":"dacha_coop_zarya",
        "reward":{"tickets":86,"reputation":11,"resources":{"security":10.0,"food":5.0},"route":{"id":"route_perron_zarya","beneficiaries":["perron"],"daily_resources":{"food":0.35,"security":0.25}}}
    },

    "rubezh_ammo_reserve":{
        "faction":"rubezh","title":"ПАТРУЛЬНЫЙ РЕЗЕРВ","kind":"delivery","need_key":"security","min_rep":0,
        "description":"Патрули расходуют боезапас быстрее, чем приходит снабжение.",
        "hint":"Нужен массовый пистолетный боезапас либо дробовые патроны для постов.",
        "requirements":[[{"id":"ammo_9x18","qty":30}],[{"id":"ammo_12g","qty":14}]],
        "reward":{"tickets":74,"reputation":9,"resources":{"security":13.0}}
    },
    "rubezh_police_route":{
        "faction":"rubezh","title":"СТАРЫЙ ПОЛИЦЕЙСКИЙ МАРШРУТ","kind":"discover_poi","need_key":"security","min_rep":25,
        "description":"Диспетчерская хочет восстановить безопасный коридор через старый районный отдел.",
        "hint":"Найди районный отдел полиции в западной панельной застройке и осмотри подходы.",
        "poi_id":"district_police",
        "reward":{"tickets":94,"reputation":12,"resources":{"security":14.0,"technical":3.0},"route":{"id":"route_rubezh_police","beneficiaries":["rubezh","perron"],"daily_resources":{"security":0.45}}}
    },
    "rubezh_east_checkpoint":{
        "faction":"rubezh","title":"КПП «ВОСТОК»","kind":"discover_poi","need_key":"technical","min_rep":75,
        "description":"Рубеж планирует дальние патрули к старому военному КПП, но давно не имеет сведений о секторе.",
        "hint":"Проверь военный КПП «Восток» на северо-восточном направлении. Это опасный маршрут.",
        "poi_id":"military_checkpoint",
        "reward":{"tickets":138,"reputation":15,"resources":{"security":18.0,"technical":8.0},"route":{"id":"route_rubezh_east","beneficiaries":["rubezh","mechanics"],"daily_resources":{"security":0.55,"technical":0.20}}}
    },

    "mechanics_pump_repair":{
        "faction":"mechanics","title":"НАСОС НА ВОДООЧИСТКЕ","kind":"delivery","need_key":"technical","min_rep":0,
        "description":"На старом насосе снова разваливается привод. Артели нужен ремонтный набор или материалы для переборки.",
        "hint":"Можно отдать готовые ремкомплекты либо принести металл и ленту — Артель соберёт узел сама.",
        "requirements":[[{"id":"repair_kit","qty":2}],[{"id":"scrap","qty":12},{"id":"tape","qty":4}]],
        "reward":{"tickets":82,"reputation":9,"resources":{"technical":16.0}}
    },
    "mechanics_rail_depot":{
        "faction":"mechanics","title":"ДЕПО: ПРОВЕРКА ПОДХОДОВ","kind":"discover_poi","need_key":"security","min_rep":25,
        "description":"Артель хочет снова вывозить тяжёлые детали из железнодорожного депо.",
        "hint":"Осмотри железнодорожное депо у промышленной ветки и оцени, можно ли провести грузовую группу.",
        "poi_id":"rail_depot",
        "reward":{"tickets":98,"reputation":12,"resources":{"technical":12.0,"security":7.0},"route":{"id":"route_mechanics_depot","beneficiaries":["mechanics","perron"],"daily_resources":{"technical":0.50,"security":0.20}}}
    },
    "mechanics_factory":{
        "faction":"mechanics","title":"КОМБИНАТ №7","kind":"discover_poi","need_key":"technical","min_rep":75,
        "description":"Саныч считает, что на Промкомбинате №7 ещё остались пригодные промышленные узлы.",
        "hint":"Найди Промкомбинат №7 в промышленном поясе и вернись после разведки территории.",
        "poi_id":"factory_7",
        "reward":{"tickets":132,"reputation":14,"resources":{"technical":18.0},"route":{"id":"route_mechanics_factory","beneficiaries":["mechanics"],"daily_resources":{"technical":0.65}}}
    },

    "lazaret_dressing_supply":{
        "faction":"lazaret","title":"ПЕРЕВЯЗОЧНАЯ","kind":"delivery","need_key":"medicine","min_rep":0,
        "description":"Лазарету нужны материалы для ежедневной перевязочной работы.",
        "hint":"Примут обычные бинты либо меньший набор стерильных материалов с антисептиком.",
        "requirements":[[{"id":"bandage","qty":8}],[{"id":"sterile_bandage","qty":4},{"id":"antiseptic","qty":2}]],
        "reward":{"tickets":68,"reputation":9,"resources":{"medicine":15.0}}
    },
    "lazaret_hospital_route":{
        "faction":"lazaret","title":"РАЙОННАЯ БОЛЬНИЦА","kind":"discover_poi","need_key":"medicine","min_rep":25,
        "description":"Медики хотят восстановить вылазки к районной больнице за расходниками.",
        "hint":"Найди районную больницу на восточной стороне города и проверь пути к хозяйственному двору.",
        "poi_id":"district_hospital",
        "reward":{"tickets":96,"reputation":12,"resources":{"medicine":14.0,"security":5.0},"route":{"id":"route_lazaret_hospital","beneficiaries":["lazaret"],"daily_resources":{"medicine":0.55,"security":0.15}}}
    },
    "lazaret_quarantine_recon":{
        "faction":"lazaret","title":"КАРАНТИН №12","kind":"discover_poi","need_key":"security","min_rep":75,
        "description":"Лазарету нужны актуальные сведения о карантинном центре №12 перед медицинской экспедицией.",
        "hint":"Найди внешний сектор карантинного центра. Это дальняя и опасная задача; проникать глубже ради отчёта не требуется.",
        "poi_id":"quarantine_center_12",
        "reward":{"tickets":142,"reputation":15,"resources":{"medicine":16.0,"security":9.0},"route":{"id":"route_lazaret_quarantine","beneficiaries":["lazaret","rubezh"],"daily_resources":{"medicine":0.45,"security":0.35}}}
    }
}

static func board_for_npc(npc_id:String) -> Dictionary:
    return BOARDS.get(npc_id,{}).duplicate(true)

static func board_faction(npc_id:String) -> String:
    return str(BOARDS.get(npc_id,{}).get("faction",""))

static func template(template_id:String) -> Dictionary:
    var out = TEMPLATES.get(template_id,{}).duplicate(true)
    if not out.is_empty():
        out["template_id"] = template_id
    return out

static func templates_for_faction(faction_id:String) -> Array:
    var out = []
    for template_id in TEMPLATES.keys():
        if str(TEMPLATES[template_id].get("faction","")) == faction_id:
            var entry = TEMPLATES[template_id].duplicate(true)
            entry["template_id"] = str(template_id)
            out.append(entry)
    return out
