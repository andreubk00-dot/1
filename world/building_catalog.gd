extends RefCounted

# OSTATOK 0.84 — data-driven building / location archetypes.
# Size envelopes are intentionally wider than 0.83 so a district reads as a real
# mix of sheds, houses, blocks and industrial halls instead of equal boxes.
# Region generation chooses an archetype; main_script_mod.gd renders its authored
# room plan, facade language, roof identity and yard dressing without changing
# persistent building/container ids.

const ARCHETYPES = {
    "panel_block": {
        "sign":"ЖИЛОЙ ДОМ", "loot":"residential", "size_min":Vector2(214,142), "size_max":Vector2(244,176), "color":Color("4d504b"),
        "layout":"panel_block", "facade":"panel", "roof":"panel", "yard":"residential", "door_x":0.0, "container_offset":Vector2(-58,-24)
    },
    "panel_entry": {
        "sign":"ПОДЪЕЗД", "loot":"residential", "size_min":Vector2(152,108), "size_max":Vector2(202,154), "color":Color("53514b"),
        "layout":"panel_entry", "facade":"panel_entry", "roof":"panel", "yard":"residential", "door_x":-0.18, "container_offset":Vector2(48,-24)
    },
    "utility_house": {
        "sign":"ХОЗБЛОК", "loot":"residential", "size_min":Vector2(112,86), "size_max":Vector2(164,122), "color":Color("494b47"),
        "layout":"utility", "facade":"utility", "roof":"flat_small", "yard":"residential", "door_x":0.18, "container_offset":Vector2(-34,-18)
    },
    "garage_row": {
        "sign":"ГАРАЖИ", "loot":"garage", "size_min":Vector2(202,94), "size_max":Vector2(246,124), "color":Color("474a47"),
        "layout":"garage_row", "facade":"garage_bays", "roof":"industrial", "yard":"garage", "door_x":0.0, "container_offset":Vector2(55,-16)
    },
    "clinic": {
        "sign":"ПОЛИКЛИНИКА", "loot":"pharmacy", "size_min":Vector2(260,188), "size_max":Vector2(330,228), "color":Color("4c5854"),
        "layout":"clinic", "facade":"clinic", "roof":"commercial", "yard":"medical", "door_x":-0.10, "container_offset":Vector2(-92,-48)
    },
    "pharmacy": {
        "sign":"АПТЕКА", "loot":"pharmacy", "size_min":Vector2(148,108), "size_max":Vector2(208,150), "color":Color("4c5b53"),
        "layout":"pharmacy", "facade":"medical_shop", "roof":"commercial", "yard":"commercial", "door_x":-0.16, "container_offset":Vector2(48,-24)
    },
    "grocery": {
        "sign":"ПРОДУКТЫ", "loot":"grocery", "size_min":Vector2(166,108), "size_max":Vector2(226,154), "color":Color("5a5042"),
        "layout":"grocery", "facade":"shop", "roof":"commercial", "yard":"commercial", "door_x":0.18, "container_offset":Vector2(-48,-24)
    },
    "cafe": {
        "sign":"КАФЕ", "loot":"grocery", "size_min":Vector2(136,98), "size_max":Vector2(190,138), "color":Color("574a43"),
        "layout":"cafe", "facade":"shop", "roof":"commercial", "yard":"commercial", "door_x":-0.18, "container_offset":Vector2(45,-25)
    },
    "service_shop": {
        "sign":"СЕРВИС", "loot":"garage", "size_min":Vector2(168,104), "size_max":Vector2(230,154), "color":Color("464d4b"),
        "layout":"service_shop", "facade":"service", "roof":"industrial", "yard":"garage", "door_x":0.22, "container_offset":Vector2(-48,-18)
    },
    "workshop": {
        "sign":"ЦЕХ", "loot":"industrial", "size_min":Vector2(208,132), "size_max":Vector2(246,178), "color":Color("454b48"),
        "layout":"workshop", "facade":"industrial_bay", "roof":"industrial", "yard":"industrial", "door_x":-0.22, "container_offset":Vector2(52,-28)
    },
    "warehouse": {
        "sign":"СКЛАД", "loot":"industrial", "size_min":Vector2(214,112), "size_max":Vector2(248,164), "color":Color("4c4b45"),
        "layout":"warehouse", "facade":"warehouse", "roof":"industrial", "yard":"industrial", "door_x":0.22, "container_offset":Vector2(-54,-24)
    },
    "repair_bay": {
        "sign":"РЕМЗОНА", "loot":"garage", "size_min":Vector2(174,104), "size_max":Vector2(232,154), "color":Color("454a49"),
        "layout":"repair_bay", "facade":"garage_bays", "roof":"industrial", "yard":"garage", "door_x":-0.20, "container_offset":Vector2(50,-22)
    },
    "factory_admin": {
        "sign":"АБК", "loot":"industrial", "size_min":Vector2(148,112), "size_max":Vector2(204,160), "color":Color("51514b"),
        "layout":"factory_admin", "facade":"office", "roof":"panel", "yard":"industrial", "door_x":0.0, "container_offset":Vector2(45,-26)
    },
    "rail_store": {
        "sign":"ПУТЕВОЙ СКЛАД", "loot":"industrial", "size_min":Vector2(212,96), "size_max":Vector2(246,136), "color":Color("4a4944"),
        "layout":"rail_store", "facade":"warehouse", "roof":"industrial", "yard":"rail", "door_x":0.24, "container_offset":Vector2(-54,-16)
    },
    "rail_service": {
        "sign":"ПЧ", "loot":"industrial", "size_min":Vector2(136,98), "size_max":Vector2(192,140), "color":Color("474c49"),
        "layout":"rail_service", "facade":"service", "roof":"industrial", "yard":"rail", "door_x":-0.22, "container_offset":Vector2(42,-20)
    },
    "dacha": {
        "sign":"ДАЧА", "loot":"rural", "size_min":Vector2(116,88), "size_max":Vector2(170,126), "color":Color("555044"),
        "layout":"dacha", "facade":"wood_house", "roof":"pitched", "yard":"dacha", "door_x":-0.18, "container_offset":Vector2(34,-20)
    },
    "country_house": {
        "sign":"ДОМ", "loot":"rural", "size_min":Vector2(148,104), "size_max":Vector2(202,150), "color":Color("514b42"),
        "layout":"country_house", "facade":"wood_house", "roof":"pitched", "yard":"dacha", "door_x":0.20, "container_offset":Vector2(-42,-22)
    },
    "shed": {
        "sign":"САРАЙ", "loot":"rural", "size_min":Vector2(88,68), "size_max":Vector2(136,104), "color":Color("464943"),
        "layout":"shed", "facade":"shed", "roof":"pitched_small", "yard":"dacha", "door_x":0.0, "container_offset":Vector2(0,-18)
    },
    "forester": {
        "sign":"ЛЕСНИК", "loot":"forest_cache", "size_min":Vector2(132,98), "size_max":Vector2(188,140), "color":Color("465047"),
        "layout":"forester", "facade":"wood_house", "roof":"pitched", "yard":"forest", "door_x":-0.18, "container_offset":Vector2(36,-20)
    },
    "forest_shed": {
        "sign":"КОРДОН", "loot":"forest_cache", "size_min":Vector2(92,70), "size_max":Vector2(140,108), "color":Color("414943"),
        "layout":"forest_shed", "facade":"shed", "roof":"pitched_small", "yard":"forest", "door_x":0.18, "container_offset":Vector2(-26,-16)
    },
    "checkpoint": {
        "sign":"КПП", "loot":"military", "size_min":Vector2(118,88), "size_max":Vector2(168,124), "color":Color("4a5047"),
        "layout":"checkpoint", "facade":"checkpoint", "roof":"military", "yard":"checkpoint", "door_x":-0.20, "container_offset":Vector2(34,-18)
    },
    "barracks": {
        "sign":"КАЗАРМА", "loot":"military", "size_min":Vector2(208,128), "size_max":Vector2(246,174), "color":Color("4b5049"),
        "layout":"barracks", "facade":"military", "roof":"military", "yard":"military", "door_x":0.0, "container_offset":Vector2(-56,-24)
    },
    "mil_store": {
        "sign":"СКЛАД В/Ч", "loot":"military", "size_min":Vector2(184,104), "size_max":Vector2(238,156), "color":Color("454a44"),
        "layout":"mil_store", "facade":"warehouse", "roof":"military", "yard":"military", "door_x":0.22, "container_offset":Vector2(-50,-22)
    },
    "comms": {
        "sign":"СВЯЗЬ", "loot":"military", "size_min":Vector2(124,96), "size_max":Vector2(176,142), "color":Color("464c48"),
        "layout":"comms", "facade":"military", "roof":"comms", "yard":"military", "door_x":-0.18, "container_offset":Vector2(38,-20)
    }
}

const SETS = {
    "old_center":["pharmacy","grocery","panel_entry","service_shop"],
    "panel_estate":["panel_block","panel_entry","utility_house","garage_row"],
    "mixed_residential":["panel_entry","country_house","utility_house","garage_row"],
    "commercial_strip":["grocery","pharmacy","cafe","service_shop"],
    "industrial_belt":["workshop","warehouse","repair_bay","factory_admin"],
    "rail_service":["rail_store","rail_service","warehouse","repair_bay"],
    "dacha_coop":["dacha","shed","country_house","shed"],
    "woodland_edge":["forester","forest_shed","shed","forest_shed"],
    "military_perimeter":["checkpoint","mil_store","barracks","comms"]
}

const POI_SETS = {
    "garage_coop":["garage_row","garage_row","repair_bay","utility_house"],
    "factory_complex":["workshop","warehouse","factory_admin","repair_bay"],
    "rail_depot":["rail_store","rail_service","warehouse","repair_bay"],
    "dacha_coop":["dacha","country_house","shed","dacha"],
    "military_checkpoint":["checkpoint","mil_store","barracks","comms"],
    "medical_hub":["clinic","pharmacy","grocery","service_shop"],
    "hospital_complex":["clinic","pharmacy","utility_house","clinic"],
    "police_station":["checkpoint","service_shop","utility_house","garage_row"],
    "hunting_cordon":["forester","forest_shed","country_house","shed"]
}

static func archetype_id(building_set:String,index:int,poi_kind:String = "") -> String:
    var list = POI_SETS.get(poi_kind,SETS.get(building_set,SETS["mixed_residential"]))
    return str(list[posmod(index,list.size())])

static func archetype(building_set:String,index:int,poi_kind:String = "") -> Dictionary:
    var id = archetype_id(building_set,index,poi_kind)
    var data = ARCHETYPES.get(id,ARCHETYPES["utility_house"]).duplicate(true)
    data["id"] = id
    return data

static func by_id(archetype_id:String) -> Dictionary:
    var data = ARCHETYPES.get(archetype_id,ARCHETYPES["utility_house"]).duplicate(true)
    data["id"] = archetype_id if ARCHETYPES.has(archetype_id) else "utility_house"
    return data

static func gameplay_profile(archetype_id:String) -> Dictionary:
    var id = str(archetype_id)
    var result = {
        "shelter_score":1,
        "tags":["building"],
        "utility_hooks":["storage"]
    }
    if id in ["panel_block","panel_entry","country_house","dacha","forester"]:
        result["shelter_score"] = 3
        result["tags"] = ["building","shelter_candidate","residential"]
        result["utility_hooks"] = ["storage","sleep","heat","light"]
    elif id in ["utility_house","shed","forest_shed"]:
        result["shelter_score"] = 2
        result["tags"] = ["building","small_shelter","storage"]
        result["utility_hooks"] = ["storage","heat"]
    elif id in ["garage_row","service_shop","repair_bay","workshop"]:
        result["shelter_score"] = 2
        result["tags"] = ["building","workshop_candidate","vehicle_service"]
        result["utility_hooks"] = ["storage","workbench","power","heat"]
    elif id in ["warehouse","rail_store","mil_store"]:
        result["shelter_score"] = 2
        result["tags"] = ["building","warehouse","high_storage"]
        result["utility_hooks"] = ["storage","power"]
    elif id in ["pharmacy","clinic"]:
        result["tags"] = ["building","medical","commercial"]
        result["utility_hooks"] = ["storage","medical","light"]
    elif id in ["grocery","cafe"]:
        result["tags"] = ["building","commercial","food"]
        result["utility_hooks"] = ["storage","food","water","light"]
    elif id in ["factory_admin","rail_service"]:
        result["tags"] = ["building","office","industrial"]
        result["utility_hooks"] = ["storage","power","records"]
    elif id in ["checkpoint","barracks","comms"]:
        result["shelter_score"] = 2
        result["tags"] = ["building","military","secure_candidate"]
        result["utility_hooks"] = ["storage","power","security","light"]
    return result

const LEGACY_082_SIZES = {
    "panel_block":[Vector2(185,125),Vector2(220,155)],
    "panel_entry":[Vector2(155,110),Vector2(190,140)],
    "utility_house":[Vector2(145,105),Vector2(175,130)],
    "garage_row":[Vector2(175,105),Vector2(220,125)],
    "pharmacy":[Vector2(150,105),Vector2(190,135)],
    "grocery":[Vector2(155,110),Vector2(200,140)],
    "cafe":[Vector2(145,105),Vector2(185,135)],
    "service_shop":[Vector2(155,110),Vector2(205,145)],
    "workshop":[Vector2(185,120),Vector2(225,155)],
    "warehouse":[Vector2(190,115),Vector2(230,150)],
    "repair_bay":[Vector2(175,110),Vector2(215,145)],
    "factory_admin":[Vector2(150,115),Vector2(190,145)],
    "rail_store":[Vector2(180,105),Vector2(225,135)],
    "rail_service":[Vector2(150,105),Vector2(185,130)],
    "dacha":[Vector2(145,105),Vector2(175,130)],
    "country_house":[Vector2(155,110),Vector2(190,140)],
    "shed":[Vector2(125,90),Vector2(155,115)],
    "forester":[Vector2(145,105),Vector2(175,130)],
    "forest_shed":[Vector2(125,90),Vector2(155,115)],
    "checkpoint":[Vector2(145,100),Vector2(175,125)],
    "barracks":[Vector2(185,120),Vector2(225,150)],
    "mil_store":[Vector2(175,110),Vector2(220,145)],
    "comms":[Vector2(145,105),Vector2(180,135)]
}

static func legacy_082_size(archetype_id:String) -> Array:
    return LEGACY_082_SIZES.get(archetype_id,[Vector2(145,105),Vector2(210,150)]).duplicate(true)
