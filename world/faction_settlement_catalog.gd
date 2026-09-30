extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")

const FOOTPRINT_3X3 = [
    Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),
    Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),
    Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)
]

const SETTLEMENTS = {
    "settlement_perron":{"name":"ПОСЕЛЕНИЕ «ПЕРРОН»","kind":"faction_settlement","faction":"perron","ground":"settlement_civic","roles":["жилой север","водонапорная и огороды","складской двор","западный КПП","рынок и площадь","кухня и общежитие","ремесленный двор","радиоузел","южный КПП"],"signs":["БАРАКИ","ВОДА","СКЛАД","КПП","РЫНОК","КУХНЯ","МАСТЕРСКИЕ","РАДИО","КПП"]},
    "settlement_rubezh":{"name":"УКРЕПРАЙОН «РУБЕЖ»","kind":"faction_settlement","faction":"rubezh","ground":"settlement_military","roles":["казарменный сектор","медпункт гарнизона","склады снабжения","западный периметр","штаб и плац","оружейная и ремонт","автопарк","радио и наблюдение","восточный КПП"],"signs":["КАЗАРМА","МЕДПУНКТ","СКЛАД","ПЕРИМЕТР","ШТАБ","ОРУЖЕЙНАЯ","АВТОПАРК","СВЯЗЬ","КПП"]},
    "settlement_mechanics":{"name":"АРТЕЛЬ «МЕХАНИКИ»","kind":"faction_settlement","faction":"mechanics","ground":"settlement_industrial","roles":["разборочный двор","электроцех","склад металла","приёмка","главная мастерская","рембоксы","топливный двор","экспедиционный склад","грузовые ворота"],"signs":["РАЗБОР","ЭЛЕКТРОЦЕХ","МЕТАЛЛ","ПРИЁМКА","АРТЕЛЬ","РЕМЗОНА","ТОПЛИВО","СНАБЖЕНИЕ","ВОРОТА"]},
    "settlement_lazaret":{"name":"ПОСЕЛЕНИЕ «ЛАЗАРЕТ»","kind":"faction_settlement","faction":"lazaret","ground":"settlement_medical","roles":["жилой корпус","аптечный склад","санитарный двор","приёмное отделение","клиника и площадь","диагностика","изоляционный корпус","лаборатория","служебный КПП"],"signs":["ЖИЛОЙ КОРПУС","АПТЕКА","САНДВОР","ПРИЁМ","КЛИНИКА","ДИАГНОСТИКА","ИЗОЛЯТОР","ЛАБОРАТОРИЯ","КПП"]}
}


const NPC_PLACEMENTS = {
    "settlement_perron":[
        {"npc_id":"perron_steward","cell":Vector2i(0,0),"pos":Vector2(344,350)},
        {"npc_id":"perron_trader","cell":Vector2i(0,0),"pos":Vector2(426,350)},
        {"npc_id":"perron_cook","cell":Vector2i(1,0),"pos":Vector2(382,386)},
        {"npc_id":"perron_radio","cell":Vector2i(0,1),"pos":Vector2(384,374)}
    ],
    "settlement_rubezh":[
        {"npc_id":"rubezh_commander","cell":Vector2i(0,0),"pos":Vector2(350,348)},
        {"npc_id":"rubezh_armorer","cell":Vector2i(1,0),"pos":Vector2(392,370)},
        {"npc_id":"rubezh_quartermaster","cell":Vector2i(1,-1),"pos":Vector2(386,382)},
        {"npc_id":"rubezh_dispatch","cell":Vector2i(0,1),"pos":Vector2(384,370)}
    ],
    "settlement_mechanics":[
        {"npc_id":"mechanics_master","cell":Vector2i(0,0),"pos":Vector2(350,360)},
        {"npc_id":"mechanics_trader","cell":Vector2i(-1,0),"pos":Vector2(392,374)},
        {"npc_id":"mechanics_electrician","cell":Vector2i(0,-1),"pos":Vector2(384,382)},
        {"npc_id":"mechanics_storekeeper","cell":Vector2i(0,1),"pos":Vector2(384,372)}
    ],
    "settlement_lazaret":[
        {"npc_id":"lazaret_doctor","cell":Vector2i(0,0),"pos":Vector2(348,352)},
        {"npc_id":"lazaret_supplier","cell":Vector2i(0,-1),"pos":Vector2(390,378)},
        {"npc_id":"lazaret_nurse","cell":Vector2i(-1,0),"pos":Vector2(390,370)},
        {"npc_id":"lazaret_researcher","cell":Vector2i(0,1),"pos":Vector2(384,374)}
    ]
}

static func has(poi_id:String) -> bool:
    return SETTLEMENTS.has(poi_id)

static func footprint(poi_id:String) -> Array:
    return FOOTPRINT_3X3.duplicate(true) if has(poi_id) else []

static func compound(poi_id:String) -> Dictionary:
    if not has(poi_id):
        return {}
    var d = SETTLEMENTS[poi_id].duplicate(true)
    d["footprint"] = FOOTPRINT_3X3.duplicate(true)
    return d

static func _index(offset:Vector2i) -> int:
    return (offset.y + 1) * 3 + (offset.x + 1)

static func cell(poi_id:String,offset:Vector2i) -> Dictionary:
    if not has(poi_id) or offset not in FOOTPRINT_3X3:
        return {}
    var d = SETTLEMENTS[poi_id]
    var idx = _index(offset)
    var role = str(d["roles"][idx])
    var sign = str(d["signs"][idx])
    var faction = str(d["faction"])
    var archetypes = ["utility_house","warehouse","service_shop"]
    if faction == "rubezh":
        archetypes = ["barracks","mil_store","checkpoint"]
    elif faction == "mechanics":
        archetypes = ["workshop","warehouse","repair_bay"]
    elif faction == "lazaret":
        archetypes = ["clinic","pharmacy","utility_house"]
    elif faction == "perron":
        archetypes = ["utility_house","grocery","cafe"]
    var center_archetype = "factory_admin" if faction == "mechanics" else ("barracks" if faction == "rubezh" else ("clinic" if faction == "lazaret" else "grocery"))
    if offset == Vector2i.ZERO:
        archetypes[0] = center_archetype
    var loot = "industrial" if faction == "mechanics" else ("military" if faction == "rubezh" else ("pharmacy" if faction == "lazaret" else "residential"))
    return {
        "role":role,"ground":str(d["ground"]),"faction_id":faction,"safe_settlement":true,
        "buildings":[
            {"id":"building_0","archetype":archetypes[0],"pos":Vector2(176,150),"size":Vector2(260,148),"sign":sign,"container_id":"cache_0","loot":loot},
            {"id":"building_1","archetype":archetypes[1],"pos":Vector2(610,150),"size":Vector2(220,128),"sign":"СЕКТОР %02d" % (idx + 1),"container_id":"cache_1","loot":loot},
            {"id":"building_2","archetype":archetypes[2],"pos":Vector2(610,616),"size":Vector2(206,116),"sign":"СЛУЖЕБНОЕ","container_id":"cache_2","loot":loot}
        ],
        "loose_containers":[{"id":"cache_3","pos":Vector2(182,610),"loot":loot,"name":"Запасы поселения"}],
        "fences":[{"pos":Vector2(384,58),"length":620},{"pos":Vector2(384,710),"length":620}],
        "lamps":[Vector2(318,282),Vector2(574,500)],
        "workbenches":[Vector2(520,548)] if faction == "mechanics" and offset in [Vector2i.ZERO,Vector2i(1,0)] else [],
        "props":[{"kind":"road_barrier","pos":Vector2(384,300),"z":4,"scale":0.54}],
        "enemy_count":0,"enemy_mult":0.0,"tree_mult":0.15,"car_mult":0.35
    }

static func npcs(poi_id:String,offset:Vector2i) -> Array:
    if not has(poi_id):
        return []
    var faction_id = str(SETTLEMENTS[poi_id].get("faction",""))
    var roster = {}
    for raw in FactionCatalog.faction(faction_id).get("npc_roster",[]):
        roster[str(raw.get("id",""))] = raw
    var result = []
    for placement in NPC_PLACEMENTS.get(poi_id,[]):
        if placement.get("cell",Vector2i(999,999)) != offset:
            continue
        var npc_id = str(placement.get("npc_id",""))
        var merged = placement.duplicate(true)
        var info = roster.get(npc_id,{})
        merged["name"] = str(info.get("name",npc_id))
        merged["role"] = str(info.get("role","житель поселения"))
        merged["faction_id"] = faction_id
        result.append(merged)
    return result

