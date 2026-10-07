extends RefCounted

# OSTATOK 0.82 — macro-region catalog.
# This file intentionally contains only world identity / metadata. Rendering,
# persistence and gameplay systems stay in main_script_mod.gd for now.

const REGION_LAYOUT_VERSION = 1

const DISTRICTS = {
    "old_center": {
        "name":"СТАРЫЙ ЦЕНТР",
        "zone":"central",
        "risk":2,
        "density":0.96,
        "enemy_mult":1.05,
        "tree_mult":0.55,
        "car_mult":1.10,
        "building_set":"old_center",
        "loot_theme":"mixed",
        "description":"Старая торгово-жилая застройка вокруг поликлиники и площади."
    },
    "panel_west": {
        "name":"ЗАПАДНЫЙ ЖИЛМАССИВ",
        "zone":"residential",
        "risk":2,
        "density":0.92,
        "enemy_mult":1.05,
        "tree_mult":0.85,
        "car_mult":1.00,
        "building_set":"panel_estate",
        "loot_theme":"residential",
        "description":"Панельные дома, дворы, хозяйственные помещения и гаражи."
    },
    "market_east": {
        "name":"ВОСТОЧНАЯ ТОРГОВАЯ ПОЛОСА",
        "zone":"commercial",
        "risk":3,
        "density":0.96,
        "enemy_mult":1.12,
        "tree_mult":0.55,
        "car_mult":1.20,
        "building_set":"commercial_strip",
        "loot_theme":"commercial",
        "description":"Магазины, аптеки, сервисы и небольшие склады вдоль магистрали."
    },
    "south_residential": {
        "name":"ЮЖНЫЕ КВАРТАЛЫ",
        "zone":"residential",
        "risk":2,
        "density":0.86,
        "enemy_mult":0.95,
        "tree_mult":1.00,
        "car_mult":0.90,
        "building_set":"mixed_residential",
        "loot_theme":"residential",
        "description":"Жилые кварталы на переходе от города к частному сектору."
    },
    "industrial_belt": {
        "name":"ВОСТОЧНАЯ ПРОМЗОНА",
        "zone":"industrial",
        "risk":4,
        "density":0.88,
        "enemy_mult":1.18,
        "tree_mult":0.45,
        "car_mult":1.25,
        "building_set":"industrial_belt",
        "loot_theme":"industrial",
        "description":"Цеха, склады, ремонтные боксы и заводские дворы."
    },
    "rail_corridor": {
        "name":"ЖЕЛЕЗНОДОРОЖНЫЙ КОРИДОР",
        "zone":"industrial",
        "risk":4,
        "density":0.72,
        "enemy_mult":1.15,
        "tree_mult":0.35,
        "car_mult":0.75,
        "building_set":"rail_service",
        "loot_theme":"industrial",
        "description":"Полоса железнодорожной инфраструктуры между городом и промзоной."
    },
    "dacha_west": {
        "name":"ДАЧНЫЙ КООПЕРАТИВ",
        "zone":"rural",
        "risk":2,
        "density":0.67,
        "enemy_mult":0.78,
        "tree_mult":1.35,
        "car_mult":0.65,
        "building_set":"dacha_coop",
        "loot_theme":"rural",
        "description":"Дачи, сараи, огороды и небольшие частные дома."
    },
    "north_woodland": {
        "name":"СЕВЕРНАЯ ЛЕСОПОЛОСА",
        "zone":"woodland",
        "risk":3,
        "density":0.28,
        "enemy_mult":0.72,
        "tree_mult":1.55,
        "car_mult":0.35,
        "building_set":"woodland_edge",
        "loot_theme":"forest_cache",
        "description":"Лесополоса, служебные будки и заброшенные хозяйственные постройки."
    },
    "military_northeast": {
        "name":"СЕВЕРО-ВОСТОЧНЫЙ ПЕРИМЕТР",
        "zone":"military",
        "risk":5,
        "density":0.78,
        "enemy_mult":1.30,
        "tree_mult":0.45,
        "car_mult":0.80,
        "building_set":"military_perimeter",
        "loot_theme":"military",
        "description":"Ограждённые склады, КПП и служебные здания бывшей части."
    },
    "outer_residential": {
        "name":"ОКРАИНЫ ГОРОДА",
        "zone":"residential",
        "risk":2,
        "density":0.76,
        "enemy_mult":0.92,
        "tree_mult":1.05,
        "car_mult":0.82,
        "building_set":"mixed_residential",
        "loot_theme":"residential",
        "description":"Разреженная городская окраина."
    },
    "outer_industrial": {
        "name":"ПРОМЫШЛЕННАЯ ОКРАИНА",
        "zone":"industrial",
        "risk":4,
        "density":0.72,
        "enemy_mult":1.08,
        "tree_mult":0.60,
        "car_mult":1.00,
        "building_set":"industrial_belt",
        "loot_theme":"industrial",
        "description":"Разрозненные склады и производственные площадки за городской чертой."
    },
    "outer_rural": {
        "name":"ПРИГОРОД",
        "zone":"rural",
        "risk":2,
        "density":0.56,
        "enemy_mult":0.75,
        "tree_mult":1.25,
        "car_mult":0.55,
        "building_set":"dacha_coop",
        "loot_theme":"rural",
        "description":"Частный сектор и разрозненные хозяйства."
    },
    "outer_woodland": {
        "name":"ЛЕСНАЯ ОКРАИНА",
        "zone":"woodland",
        "risk":3,
        "density":0.22,
        "enemy_mult":0.68,
        "tree_mult":1.65,
        "car_mult":0.25,
        "building_set":"woodland_edge",
        "loot_theme":"forest_cache",
        "description":"Лесные массивы и просеки за пределами городской застройки."
    }
}

const POIS = [
    {
        "id":"central_clinic",
        "coord":Vector2i(0,0),
        "footprint":[Vector2i(0,0)],
        "name":"СТАРАЯ ПОЛИКЛИНИКА",
        "short_name":"ПОЛИКЛИНИКА",
        "kind":"medical_hub",
        "district":"old_center",
        "risk":2,
        "loot":"pharmacy",
        "status":"existing",
        "description":"Существующий центральный медицинский узел и стартовый ориентир."
    },
    {
        "id":"garage_coop_sever",
        "coord":Vector2i(-2,1),
        "footprint":[Vector2i(0,0),Vector2i(-1,0),Vector2i(0,-1),Vector2i(-1,-1)],
        "name":"ГСК «СЕВЕР»",
        "short_name":"ГСК «СЕВЕР»",
        "kind":"garage_coop",
        "district":"panel_west",
        "risk":2,
        "loot":"garage",
        "status":"active",
        "description":"Крупный гаражный кооператив с ремонтным двором, сторожкой и рядами боксов."
    },
    {
        "id":"factory_7",
        "coord":Vector2i(3,3),
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)],
        "name":"ПРОМКОМБИНАТ №7",
        "short_name":"КОМБИНАТ №7",
        "kind":"factory_complex",
        "district":"industrial_belt",
        "risk":4,
        "loot":"industrial",
        "farm_profile":"industrial_secure",
        "refresh_days":7,
        "status":"active",
        "description":"Заводской комплекс из главного цеха, складов, АБК, проходной и энергодвора."
    },
    {
        "id":"rail_depot",
        "coord":Vector2i(4,2),
        "footprint":[Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0)],
        "name":"ЖЕЛЕЗНОДОРОЖНОЕ ДЕПО",
        "short_name":"Ж/Д ДЕПО",
        "kind":"rail_depot",
        "district":"rail_corridor",
        "risk":4,
        "loot":"industrial",
        "farm_profile":"industrial_secure",
        "refresh_days":7,
        "status":"active",
        "description":"Трёхсекционное депо: локомотивный цех, управление и грузовой двор."
    },
    {
        "id":"dacha_coop_zarya",
        "coord":Vector2i(-3,3),
        "footprint":[Vector2i(0,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(-1,1)],
        "name":"СНТ «ЗАРЯ»",
        "short_name":"СНТ «ЗАРЯ»",
        "kind":"dacha_coop",
        "district":"dacha_west",
        "risk":2,
        "loot":"rural",
        "farm_profile":"rural_secure",
        "refresh_days":4,
        "status":"active",
        "description":"Дачный кооператив с разными участками, домами, сараями и садовыми зонами."
    },
    {
        "id":"district_hospital",
        "coord":Vector2i(2,0),
        "footprint":[Vector2i(0,0),Vector2i(1,0)],
        "name":"РАЙОННАЯ БОЛЬНИЦА",
        "short_name":"БОЛЬНИЦА",
        "kind":"hospital_complex",
        "district":"market_east",
        "risk":3,
        "loot":"pharmacy",
        "farm_profile":"medical_secure",
        "refresh_days":5,
        "status":"active",
        "description":"Два корпуса районной больницы: приёмное отделение, аптека и хозяйственный двор."
    },
    {
        "id":"district_police",
        "coord":Vector2i(-3,-1),
        "footprint":[Vector2i(0,0),Vector2i(1,0)],
        "name":"РАЙОННЫЙ ОТДЕЛ ПОЛИЦИИ",
        "short_name":"ОТДЕЛ ПОЛИЦИИ",
        "kind":"police_station",
        "district":"panel_west",
        "risk":3,
        "loot":"police",
        "farm_profile":"police_secure",
        "refresh_days":6,
        "status":"active",
        "description":"Отдел полиции с дежурной частью, гаражом и небольшим закрытым двором."
    },
    {
        "id":"hunting_cordon",
        "coord":Vector2i(0,-3),
        "footprint":[Vector2i(0,0),Vector2i(1,0)],
        "name":"ОХОТНИЧИЙ КОРДОН «СОСНЫ»",
        "short_name":"КОРДОН «СОСНЫ»",
        "kind":"hunting_cordon",
        "district":"north_woodland",
        "risk":3,
        "loot":"forest_cache",
        "farm_profile":"hunting_secure",
        "refresh_days":6,
        "status":"active",
        "description":"Лесной кордон с домиком смотрителя, складом снастей и хозяйственной площадкой."
    },
    {
        "id":"military_checkpoint",
        "coord":Vector2i(4,-3),
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(1,-1)],
        "name":"ВОЕННЫЙ КПП «ВОСТОК»",
        "short_name":"КПП «ВОСТОК»",
        "kind":"military_checkpoint",
        "district":"military_northeast",
        "risk":5,
        "loot":"military",
        "farm_profile":"military_secure",
        "refresh_days":8,
        "status":"active",
        "description":"Внешний КПП, складской сектор, казарменный двор и технический парк военной части."
    }    ,
    {
        "id":"quarantine_center_12",
        "coord":Vector2i(-6,-5),
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)],
        "name":"КАРАНТИННЫЙ ЦЕНТР №12",
        "short_name":"КАРАНТИН №12",
        "kind":"quarantine_dungeon",
        "district":"outer_woodland",
        "risk":5,
        "loot":"quarantine_core",
        "farm_profile":"quarantine_core",
        "refresh_days":10,
        "status":"active",
        "high_risk":true,
        "dungeon_tier":1,
        "hard_requirements":[],
        "description":"Шесть секторов бывшего карантинного центра: внешний триаж, изоляторы, лабораторные корпуса, красная зона и закрытые внутренние помещения."
    },
    {
        "id":"reserve_arsenal_bastion",
        "coord":Vector2i(4,5),
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)],
        "name":"РЕЗЕРВНЫЙ АРСЕНАЛ «БАСТИОН»",
        "short_name":"АРСЕНАЛ «БАСТИОН»",
        "kind":"arsenal_dungeon",
        "district":"industrial_belt",
        "risk":5,
        "loot":"arsenal_core",
        "farm_profile":"arsenal_core",
        "refresh_days":12,
        "status":"active",
        "high_risk":true,
        "dungeon_tier":1,
        "hard_requirements":[],
        "description":"Шестисекторный резервный военный объект: КПП, автопарк, казармы, командный двор и закрытые внутренние хранилища."
    },
    {
        "id":"regional_clinical_complex_4",
        "coord":Vector2i(-9,1),
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)],
        "name":"ОБЛАСТНОЙ КЛИНИЧЕСКИЙ КОМПЛЕКС №4",
        "short_name":"КЛИНИЧЕСКИЙ КОМПЛЕКС №4",
        "kind":"medical_endgame_dungeon",
        "district":"outer_residential",
        "risk":5,
        "loot":"clinical_core",
        "farm_profile":"clinical_core",
        "refresh_days":12,
        "status":"active_integrated",
        "high_risk":true,
        "dungeon_tier":2,
        "hard_requirements":[],
        "spatial_identity":"open_medical_campus",
        "activation_operation":"operation_3",
        "description":"Открытый шестисекторный госпитальный кампус высшего риска: приёмное отделение, диагностика, палатные корпуса, изоляция, служебный эвакуационный выезд и хирургический резерв. Вход не требует предмета, добываемого внутри объекта."
    },
    {
        "id":"settlement_perron",
        "coord":Vector2i(-8,6),
        "footprint":[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)],
        "name":"ПОСЕЛЕНИЕ «ПЕРРОН»",
        "short_name":"ПЕРРОН",
        "kind":"faction_settlement",
        "faction":"perron",
        "district":"outer_rural",
        "risk":1,
        "loot":"residential",
        "status":"active_122",
        "safe_settlement":true,
        "description":"Крупное гражданское поселение вокруг транспортного узла: рынок, жилые бараки, кухня, склады, вода, радиоузел и два КПП."
    },
    {
        "id":"settlement_rubezh",
        "coord":Vector2i(8,-3),
        "footprint":[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)],
        "name":"УКРЕПРАЙОН «РУБЕЖ»",
        "short_name":"РУБЕЖ",
        "kind":"faction_settlement",
        "faction":"rubezh",
        "district":"outer_industrial",
        "risk":2,
        "loot":"military",
        "status":"active_122",
        "safe_settlement":true,
        "description":"Укреплённый гарнизон с плацем, штабом, казармами, оружейной, автопарком, снабжением и контролем маршрутов."
    },
    {
        "id":"settlement_mechanics",
        "coord":Vector2i(8,4),
        "footprint":[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)],
        "name":"АРТЕЛЬ «МЕХАНИКИ»",
        "short_name":"МЕХАНИКИ",
        "kind":"faction_settlement",
        "faction":"mechanics",
        "district":"outer_industrial",
        "risk":2,
        "loot":"industrial",
        "status":"active_122",
        "safe_settlement":true,
        "description":"Девятисекторная промышленная артель: разборка, электроцех, главная мастерская, ремонтные боксы, топливо и экспедиционное снабжение."
    },
    {
        "id":"settlement_lazaret",
        "coord":Vector2i(-8,-2),
        "footprint":[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)],
        "name":"ПОСЕЛЕНИЕ «ЛАЗАРЕТ»",
        "short_name":"ЛАЗАРЕТ",
        "kind":"faction_settlement",
        "faction":"lazaret",
        "district":"outer_residential",
        "risk":1,
        "loot":"pharmacy",
        "status":"active_122",
        "safe_settlement":true,
        "description":"Медицинское поселение с приёмным отделением, диагностикой, аптечным складом, изолятором, лабораторией и санитарным двором."
    },
    {
        "id":"underground_object_vector",
        "coord":Vector2i(7,-7),
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,2),Vector2i(1,2)],
        "name":"ПОДЗЕМНЫЙ ОБЪЕКТ «ВЕКТОР»",
        "short_name":"ОБЪЕКТ «ВЕКТОР»",
        "kind":"underground_endgame_dungeon",
        "district":"outer_industrial",
        "risk":5,
        "loot":"vector_core",
        "farm_profile":"vector_core",
        "refresh_days":14,
        "status":"active_integrated",
        "high_risk":true,
        "dungeon_tier":2,
        "hard_requirements":[],
        "activation_operation":"operation_4",
        "spatial_identity":"sealed_underground_node",
        "description":"Шестисекторный подземный технический узел высшего риска: шахта доступа, охрана, энергоблок, командный сектор, сервисный тоннель и глубокое инженерное ядро. Вход не требует предмета, добываемого внутри объекта."
    }

]

# 1.20.0-dev5 — operation 5 integrates both tier-2 locations. No planned high-risk
# skeleton remains; core-only target farming is active with hidden cooldowns.
const HIGH_RISK_DEV_SKELETONS = []

static func planned_high_risk_poi_by_id(poi_id:String) -> Dictionary:
    for poi in HIGH_RISK_DEV_SKELETONS:
        if str(poi.get("id","")) == poi_id:
            return poi.duplicate(true)
    return {}

static func _hash_pair(x:int,y:int,salt:int = 0) -> int:
    return abs(x * 92821 + y * 68917 + x * y * 97 + 1337 + salt * 7919)

static func _outer_district_id(coord:Vector2i) -> String:
    # Outside the authored 11x11 core, use large 4x4 macro-cells instead of
    # per-chunk randomness. The result is still deterministic but forms coherent
    # stretches of countryside/forest/industry rather than visual confetti.
    var sx = int(floor(float(coord.x) / 4.0))
    var sy = int(floor(float(coord.y) / 4.0))
    var pick = _hash_pair(sx,sy,17) % 100

    # Directional bias keeps industry mostly east/south-east, woodland north,
    # and rural land west/south-west while still allowing mixed outskirts.
    if coord.y <= -5:
        return "outer_woodland" if pick < 72 else "outer_residential"
    if coord.x >= 6 and coord.y >= 0:
        return "outer_industrial" if pick < 68 else "outer_residential"
    if coord.x <= -6 or coord.y >= 6:
        return "outer_rural" if pick < 62 else ("outer_woodland" if pick < 82 else "outer_residential")
    if pick < 40:
        return "outer_residential"
    if pick < 62:
        return "outer_rural"
    if pick < 82:
        return "outer_woodland"
    return "outer_industrial"

static func district_id_for_chunk(coord:Vector2i) -> String:
    # Authored macro layout around the starting region.
    if coord.x >= -1 and coord.x <= 1 and coord.y >= -1 and coord.y <= 1:
        return "old_center"
    if coord.x >= 3 and coord.x <= 5 and coord.y >= -5 and coord.y <= -2:
        return "military_northeast"
    if coord.y <= -2 and coord.y >= -5 and coord.x >= -4 and coord.x <= 2:
        return "north_woodland"
    if coord.y == 2 and coord.x >= 1 and coord.x <= 5:
        return "rail_corridor"
    if coord.x >= 2 and coord.x <= 5 and coord.y >= 1 and coord.y <= 5:
        return "industrial_belt"
    if coord.x <= -2 and coord.x >= -5 and coord.y >= 2 and coord.y <= 5:
        return "dacha_west"
    if coord.x >= -3 and coord.x <= -2 and coord.y >= -1 and coord.y <= 1:
        return "panel_west"
    if coord.x >= 2 and coord.x <= 3 and coord.y >= -1 and coord.y <= 1:
        return "market_east"
    if coord.x >= -1 and coord.x <= 1 and coord.y >= 2 and coord.y <= 4:
        return "south_residential"
    return _outer_district_id(coord)

static func district_profile(district_id:String) -> Dictionary:
    return DISTRICTS.get(district_id,DISTRICTS["outer_residential"]).duplicate(true)

static func poi_for_chunk(coord:Vector2i) -> Dictionary:
    for poi in POIS:
        var anchor = poi.get("coord",Vector2i(99999,99999))
        var footprint = poi.get("footprint",[Vector2i.ZERO])
        for offset in footprint:
            if anchor + offset == coord:
                var result = poi.duplicate(true)
                result["anchor"] = anchor
                result["cell_offset"] = offset
                result["is_anchor"] = offset == Vector2i.ZERO
                return result
    return {}

static func poi_by_id(poi_id:String) -> Dictionary:
    for poi in POIS:
        if str(poi.get("id","")) == poi_id:
            return poi.duplicate(true)
    return {}

static func chunk_profile(coord:Vector2i) -> Dictionary:
    var district_id = district_id_for_chunk(coord)
    var profile = district_profile(district_id)
    profile["district_id"] = district_id
    profile["coord"] = coord
    var poi = poi_for_chunk(coord)
    profile["poi"] = poi
    profile["poi_id"] = str(poi.get("id",""))
    if not poi.is_empty():
        profile["risk"] = int(poi.get("risk",profile.get("risk",2)))
        profile["loot_theme"] = str(poi.get("loot",profile.get("loot_theme","mixed")))
    return profile

static func zone_for_chunk(coord:Vector2i) -> String:
    return str(chunk_profile(coord).get("zone","residential"))
