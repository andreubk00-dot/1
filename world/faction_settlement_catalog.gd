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

# 1.22-dev4: every settlement sector gets an authored plan instead of the same
# three-box template. Building slots keep the old footprints (and therefore door
# lanes / cache ids); a sector may leave a slot empty to open a yard, square or
# parade ground. Set pieces are visual structures with small base collisions:
#   plain kind -> settlement_props_v1.png, "poi:" -> poi_props_v1.png,
#   "prop:" -> world_props_v19.png, "street:" -> street_furniture_v1.png.
# The centre band (x 300..470, y 300..430) stays free for NPCs, and gate lanes
# (x/y 320..450 from an outer wall to the centre) stay free for movement.
const SLOTS = {
    "nw":{"pos":Vector2(176,150),"size":Vector2(260,148)},
    "ne":{"pos":Vector2(610,150),"size":Vector2(220,128)},
    "se":{"pos":Vector2(610,616),"size":Vector2(206,116)},
    "sw":{"pos":Vector2(176,622),"size":Vector2(220,120)}
}
const SLOT_ORDER = ["nw","ne","se","sw"]

const PLANS = {
    "perron":[
        {"b":{"nw":["utility_house","БАРАКИ"],"ne":["panel_entry","БАРАК №2"],"x1":["shed","САРАЙ",Vector2(118,640),Vector2(108,80)]},
         "p":[["laundry_line",Vector2(170,318)],["laundry_line",Vector2(622,312)],["garden_beds",Vector2(262,560)],["garden_beds",Vector2(262,660)],
              ["chicken_coop",Vector2(560,570)],["poi:woodpile",Vector2(706,560)],["long_table",Vector2(600,690)],["fire_barrel",Vector2(470,300)],
              ["water_point",Vector2(470,560)],["street:bench",Vector2(300,736)]],
         "trees":[Vector2(720,470),Vector2(460,720),Vector2(740,720)]},
        {"b":{"nw":["utility_house","ВОДА"]},
         "p":[["water_tower",Vector2(618,244),0.82],["water_point",Vector2(710,320)],["garden_beds",Vector2(96,540)],["garden_beds",Vector2(226,540)],
              ["garden_beds",Vector2(96,640)],["garden_beds",Vector2(226,640)],["garden_beds",Vector2(96,740)],["garden_beds",Vector2(226,740)],
              ["poi:greenhouse",Vector2(560,560)],["poi:greenhouse",Vector2(690,560)],["poi:greenhouse",Vector2(560,690)],["poi:greenhouse",Vector2(690,690)],
              ["chicken_coop",Vector2(110,306)]],
         "trees":[Vector2(470,720),Vector2(470,540)]},
        {"b":{"nw":["warehouse","СКЛАД"],"ne":["warehouse","ЗЕРНО"],"se":["service_shop","ВЕСОВАЯ"],"x1":["shed","ТАРА",Vector2(118,640),Vector2(108,80)]},
         "p":[["poi:pallets_tarp",Vector2(262,560)],["poi:pallets_tarp",Vector2(262,700)],["prop:supply_crate",Vector2(360,560),0.62],["prop:cardboard_boxes",Vector2(400,570),0.58],
              ["fire_barrel",Vector2(440,640)],["poi:cable_drum",Vector2(482,730)],["poi:woodpile",Vector2(120,300)],["market_stall_b",Vector2(470,300)]],
         "trees":[Vector2(740,720)]},
        {"b":{"nw":["checkpoint","КПП"],"ne":["rail_service","ДЕПО"]},
         "p":[["poi:boxcar",Vector2(180,558)],["poi:boxcar",Vector2(560,558)],["laundry_line",Vector2(180,690)],["garden_beds",Vector2(560,650)],
              ["garden_beds",Vector2(560,740)],["fire_barrel",Vector2(250,290)],["long_table",Vector2(296,700)],["chicken_coop",Vector2(700,700)]],
         "trees":[Vector2(700,300),Vector2(60,730)]},
        {"b":{"nw":["grocery","РЫНОК"]},
         "p":[["market_stall",Vector2(522,206)],["market_stall_b",Vector2(622,206)],["market_stall",Vector2(716,206)],
              ["market_stall_b",Vector2(522,306)],["market_stall",Vector2(622,306)],["market_stall_b",Vector2(716,306)],
              ["platform_canopy",Vector2(200,520),0.74],["poi:tank_wagon",Vector2(600,558)],["street:notice_board",Vector2(110,296)],
              ["fire_barrel",Vector2(290,440)],["long_table",Vector2(150,660)],["long_table",Vector2(300,660)],["field_kitchen",Vector2(560,680)],
              ["long_table",Vector2(690,690)],["street:bench",Vector2(150,740)],["fire_barrel",Vector2(470,640)]],
         "garlands":[[Vector2(480,250),Vector2(750,250)],[Vector2(318,282),Vector2(480,250)],[Vector2(80,600),Vector2(370,600)]],
         "trees":[Vector2(460,740)]},
        {"b":{"nw":["cafe","СТОЛОВАЯ"]},
         "p":[["field_kitchen",Vector2(546,266)],["long_table",Vector2(650,228)],["long_table",Vector2(650,300)],
              ["poi:boxcar",Vector2(200,558)],["poi:boxcar",Vector2(560,558)],["laundry_line",Vector2(160,690)],["long_table",Vector2(288,690)],
              ["fire_barrel",Vector2(470,640)],["chicken_coop",Vector2(620,700)],["prop:supply_crate",Vector2(470,300),0.55]],
         "garlands":[[Vector2(500,190),Vector2(740,190)]],
         "trees":[Vector2(740,720)]},
        {"b":{"nw":["workshop","МАСТЕРСКИЕ"],"ne":["shed","СТОЛЯРКА",Vector2(610,150),Vector2(132,96)],"se":["utility_house","КУЗНЯ"]},
         "p":[["poi:woodpile",Vector2(120,560)],["poi:woodpile",Vector2(120,660)],["poi:pallets_tarp",Vector2(270,590)],["furnace",Vector2(290,720),0.62],
              ["poi:cable_drum",Vector2(430,600)],["fire_barrel",Vector2(470,300)],["laundry_line",Vector2(620,320)],["long_table",Vector2(130,740)],
              ["prop:toolbox",Vector2(420,720),0.6]],
         "trees":[Vector2(740,470)]},
        {"b":{"nw":["utility_house","РАДИО"],"ne":["utility_house","ГЕНЕРАТОРНАЯ"],"x1":["shed","СКЛАД",Vector2(118,640),Vector2(108,80)]},
         "p":[["radio_mast",Vector2(618,700),0.86],["poi:transformer",Vector2(540,560)],["prop:generator_prop",Vector2(262,560),0.66],["chicken_coop",Vector2(700,560)],
              ["garden_beds",Vector2(262,700)],["fire_barrel",Vector2(290,300)],["water_point",Vector2(500,700)]],
         "trees":[Vector2(740,300)]},
        {"b":{"nw":["checkpoint","КПП"],"ne":["utility_house","ДОСМОТР"],"x1":["shed","БАНЯ",Vector2(118,640),Vector2(108,80)]},
         "p":[["poi:pallets_tarp",Vector2(600,560)],["water_point",Vector2(660,690)],["laundry_line",Vector2(262,560)],["fire_barrel",Vector2(290,690)],
              ["street:bench",Vector2(290,300)],["chicken_coop",Vector2(520,690)],["poi:woodpile",Vector2(720,560)]],
         "trees":[Vector2(740,300)]}
    ],
    "rubezh":[
        {"b":{"nw":["barracks","КАЗАРМА"],"ne":["barracks","КАЗАРМА №2"]},
         "p":[["army_tent",Vector2(100,600)],["army_tent",Vector2(220,600)],["army_tent",Vector2(100,730)],["army_tent",Vector2(220,730)],
              ["hesco_row",Vector2(600,560)],["poi:pallets_tarp",Vector2(560,690)],["prop:ammo_crate",Vector2(680,690),0.62],["fire_barrel",Vector2(440,560)],
              ["street:bench",Vector2(90,300)],["sandbag_nest",Vector2(470,300)],["jersey_blocks",Vector2(700,330)]]},
        {"b":{"nw":["clinic","МЕДПУНКТ"],"ne":["utility_house","САНЧАСТЬ"]},
         "p":[["medical_tent",Vector2(560,600)],["medical_tent",Vector2(690,600)],["jersey_blocks",Vector2(150,560)],["prop:stretcher",Vector2(250,680),0.62],
              ["prop:medboxes_large",Vector2(130,690),0.62],["fire_barrel",Vector2(470,560)],["oxygen_rack",Vector2(690,320)],["ambulance",Vector2(610,730)],
              ["sandbag_nest",Vector2(272,316)]]},
        {"b":{"nw":["mil_store","СКЛАД"],"ne":["mil_store","СКЛАД ГСМ"],"se":["warehouse","ПРОДСКЛАД"]},
         "p":[["ammo_bunker",Vector2(170,630),0.8],["poi:pallets_tarp",Vector2(298,570)],["poi:forklift",Vector2(318,690)],["poi:army_truck",Vector2(170,440)],
              ["prop:ammo_crate",Vector2(460,560),0.62],["prop:supply_crate",Vector2(460,650),0.62],["hesco_row",Vector2(170,740)],["jersey_blocks",Vector2(600,300)]]},
        {"b":{"nw":["checkpoint","ПЕРИМЕТР"],"ne":["barracks","КАРАУЛКА"]},
         "p":[["searchlight_tower",Vector2(110,650),0.9],["sandbag_nest",Vector2(250,560)],["hesco_row",Vector2(240,730)],["poi:hedgehogs",Vector2(710,320)],
              ["army_tent",Vector2(560,620)],["army_tent",Vector2(690,620)],["poi:army_truck",Vector2(600,740)],["jersey_blocks",Vector2(506,722)]]},
        {"b":{"nw":["barracks","ШТАБ"],"ne":["comms","ДЕЖУРНАЯ"]},
         "p":[["flag_pole",Vector2(482,300),0.9],["btr",Vector2(560,650),0.8],["btr",Vector2(700,650),0.8],["poi:army_truck",Vector2(170,610)],
              ["jersey_blocks",Vector2(490,520)],["jersey_blocks",Vector2(700,520)],["sandbag_nest",Vector2(170,470)],["army_tent",Vector2(300,700)],
              ["fire_barrel",Vector2(150,730)]],
         "parade":Rect2(470,258,282,236)},
        {"b":{"nw":["mil_store","ОРУЖЕЙНАЯ"],"se":["repair_bay","РЕМБАТ"]},
         "p":[["poi:army_truck",Vector2(180,600)],["btr",Vector2(200,730),0.8],["poi:pallets_tarp",Vector2(640,290)],["prop:ammo_crate",Vector2(330,560),0.62],
              ["prop:weapon_rack",Vector2(520,290),0.62],["fire_barrel",Vector2(470,300)],["hesco_row",Vector2(262,476)]]},
        {"b":{"nw":["garage_row","АВТОПАРК"],"ne":["garage_row","БОКСЫ"]},
         "p":[["btr",Vector2(150,600),0.8],["btr",Vector2(150,730),0.8],["poi:army_truck",Vector2(560,590)],["poi:army_truck",Vector2(560,720)],
              ["fuel_station",Vector2(296,700),0.72],["jersey_blocks",Vector2(470,300)],["poi:pallets_tarp",Vector2(700,470)]]},
        {"b":{"nw":["comms","СВЯЗЬ"],"ne":["barracks","ПОСТ"]},
         "p":[["radio_mast",Vector2(620,700),0.86],["searchlight_tower",Vector2(140,660),0.9],["sandbag_nest",Vector2(250,480)],["poi:transformer",Vector2(700,540)],
              ["army_tent",Vector2(250,680)],["poi:pallets_tarp",Vector2(520,560)],["fire_barrel",Vector2(290,300)]]},
        {"b":{"nw":["checkpoint","КПП"],"se":["barracks","КАРАУЛ"]},
         "p":[["hesco_row",Vector2(170,560)],["sandbag_nest",Vector2(170,690)],["searchlight_tower",Vector2(700,340),0.9],["poi:hedgehogs",Vector2(560,300)],
              ["fire_barrel",Vector2(290,300)],["army_tent",Vector2(280,690)],["poi:hedgehogs",Vector2(700,470)]]}
    ],
    "mechanics":[
        {"b":{"nw":["workshop","РАЗБОР"],"x1":["garage_row","РАЗБОРКА",Vector2(176,630),Vector2(220,100)]},
         "p":[["jib_crane",Vector2(612,244),0.9],["scrap_heap",Vector2(560,560)],["scrap_heap",Vector2(690,690)],["car_on_blocks",Vector2(560,700)],
              ["car_on_blocks",Vector2(700,560)],["poi:pipe_stack",Vector2(200,300)],["fire_barrel",Vector2(470,300)],["scrap_heap",Vector2(474,566)]],
         "garlands":[[Vector2(480,320),Vector2(750,320)]]},
        {"b":{"nw":["workshop","ЭЛЕКТРОЦЕХ"],"ne":["warehouse","АККУМУЛЯТОРНАЯ"]},
         "p":[["wind_turbine",Vector2(110,640),0.9],["wind_turbine",Vector2(250,740),0.9],["solar_rig",Vector2(560,560)],["solar_rig",Vector2(690,560)],
              ["solar_rig",Vector2(560,690)],["solar_rig",Vector2(690,690)],["poi:transformer",Vector2(250,560)],["poi:cable_drum",Vector2(470,560)],
              ["poi:cable_drum",Vector2(292,306)]]},
        {"b":{"nw":["warehouse","МЕТАЛЛ"],"ne":["warehouse","ЛОМ"],"se":["repair_bay","ПРЕСС"]},
         "p":[["poi:pipe_stack",Vector2(140,560)],["poi:pipe_stack",Vector2(140,670)],["poi:forklift",Vector2(290,620)],["scrap_heap",Vector2(290,730)],
              ["jib_crane",Vector2(440,640),0.84],["poi:cable_drum",Vector2(470,300)],["scrap_heap",Vector2(140,760)]]},
        {"b":{"nw":["service_shop","ПРИЁМКА"],"se":["warehouse","ВЕСЫ"]},
         "p":[["container_shop",Vector2(170,620)],["poi:pallets_tarp",Vector2(270,730)],["poi:forklift",Vector2(460,600)],["scrap_heap",Vector2(620,300)],
              ["fire_barrel",Vector2(470,300)],["poi:pallets_tarp",Vector2(120,730)]],
         "garlands":[[Vector2(60,540),Vector2(300,540)]]},
        {"b":{"nw":["factory_admin","АРТЕЛЬ"],"x1":["repair_bay","РЕМЦЕХ",Vector2(176,622),Vector2(220,120)]},
         "p":[["jib_crane",Vector2(640,256),0.9],["container_shop",Vector2(610,650)],["furnace",Vector2(700,500)],["poi:pipe_stack",Vector2(470,720)],
              ["fire_barrel",Vector2(290,450)],["street:bench",Vector2(290,300)],["scrap_heap",Vector2(520,300)]],
         "garlands":[[Vector2(318,282),Vector2(560,300)],[Vector2(560,300),Vector2(750,300)]]},
        {"b":{"nw":["repair_bay","РЕМБОКС 1"],"se":["repair_bay","РЕМБОКС 2"],"x1":["repair_bay","РЕМБОКС 3",Vector2(176,622),Vector2(220,120)]},
         "p":[["car_on_blocks",Vector2(560,296)],["poi:cable_drum",Vector2(700,300)],["jib_crane",Vector2(470,720),0.84],["scrap_heap",Vector2(680,740)],
              ["prop:tool_case",Vector2(470,300),0.6]]},
        {"b":{"nw":["warehouse","ТОПЛИВО"]},
         "p":[["fuel_station",Vector2(170,630)],["poi:h_tank",Vector2(600,580)],["poi:h_tank",Vector2(600,700)],["poi:silo",Vector2(470,700)],
              ["prop:gas_can",Vector2(290,560),0.6],["prop:gas_can",Vector2(320,570),0.55],["jersey_blocks",Vector2(560,300)],["jersey_blocks",Vector2(170,740)],
              ["poi:pallets_tarp",Vector2(700,300)]]},
        {"b":{"nw":["warehouse","СНАБЖЕНИЕ"],"ne":["warehouse","ЭКСПЕДИЦИЯ"]},
         "p":[["container_shop",Vector2(610,600)],["container_shop",Vector2(610,730)],["poi:pallets_tarp",Vector2(170,590)],["poi:forklift",Vector2(270,690)],
              ["solar_rig",Vector2(130,730)],["fire_barrel",Vector2(290,300)]]},
        {"b":{"nw":["service_shop","ДИСПЕТЧЕРСКАЯ"],"se":["repair_bay","ГРУЗОВОЙ БОКС"]},
         "p":[["jib_crane",Vector2(200,650),0.9],["container_shop",Vector2(620,300)],["poi:pallets_tarp",Vector2(270,730)],["scrap_heap",Vector2(110,730)],
              ["container_shop",Vector2(110,560)]]}
    ],
    "lazaret":[
        {"b":{"nw":["panel_entry","ЖИЛОЙ КОРПУС"],"ne":["utility_house","ПРАЧЕЧНАЯ"],"x1":["panel_entry","КОРПУС Б",Vector2(176,622),Vector2(200,120)]},
         "p":[["laundry_line",Vector2(600,320)],["laundry_line",Vector2(170,316)],["herb_beds",Vector2(560,560)],["herb_beds",Vector2(690,560)],
              ["wash_station",Vector2(600,690)],["street:bench",Vector2(700,700)],["street:planter",Vector2(470,560)]],
         "trees":[Vector2(740,730),Vector2(460,730)]},
        {"b":{"nw":["pharmacy","АПТЕКА"],"ne":["warehouse","АПТЕЧНЫЙ СКЛАД"],"se":["utility_house","КОТЕЛЬНАЯ"]},
         "p":[["oxygen_rack",Vector2(150,570)],["poi:pallets_tarp",Vector2(280,660)],["prop:medboxes_large",Vector2(150,690),0.62],["herb_beds",Vector2(150,760)],
              ["prop:med_supply_stack",Vector2(470,560),0.58],["street:bench",Vector2(240,300)]],
         "trees":[Vector2(740,470),Vector2(470,740)]},
        {"b":{"nw":["utility_house","САНДВОР"],"x1":["utility_house","ДЕЗИНФЕКЦИЯ",Vector2(176,622),Vector2(200,116)]},
         "p":[["incinerator",Vector2(630,248),0.84],["wash_station",Vector2(540,560)],["decon_frame",Vector2(680,580)],["laundry_line",Vector2(600,700)],
              ["prop:trash_bag",Vector2(720,320),0.58],["oxygen_rack",Vector2(470,700)]],
         "trees":[Vector2(740,730)]},
        {"b":{"nw":["clinic","ПРИЁМ"],"se":["utility_house","РЕГИСТРАТУРА"]},
         "p":[["ambulance",Vector2(170,610)],["ambulance",Vector2(170,730)],["triage_canopy",Vector2(610,300)],["prop:stretcher",Vector2(320,700),0.62],
              ["prop:wheelchair",Vector2(470,560),0.58]]},
        {"b":{"nw":["clinic","КЛИНИКА"],"se":["pharmacy","ПРОЦЕДУРНАЯ"]},
         "p":[["triage_canopy",Vector2(612,244)],["herb_beds",Vector2(130,560)],["herb_beds",Vector2(130,660)],["herb_beds",Vector2(130,760)],
              ["medical_tent",Vector2(290,650)],["street:bench",Vector2(290,300)],["street:planter",Vector2(470,300)],["wash_station",Vector2(470,560)]],
         "trees":[Vector2(740,470),Vector2(470,740)]},
        {"b":{"nw":["clinic","ДИАГНОСТИКА"],"se":["utility_house","РЕНТГЕН"]},
         "p":[["oxygen_rack",Vector2(640,290)],["medical_tent",Vector2(150,620)],["medical_tent",Vector2(290,620)],["ambulance",Vector2(220,740)],
              ["prop:medical_screen",Vector2(470,300),0.58]],
         "trees":[Vector2(470,740)]},
        {"b":{"nw":["clinic","ИЗОЛЯТОР"]},
         "p":[["medical_tent",Vector2(140,600)],["medical_tent",Vector2(290,600)],["decon_frame",Vector2(560,600)],["incinerator",Vector2(690,700)],
              ["wash_station",Vector2(470,560)],["prop:body_bag",Vector2(200,650),0.55],["triage_canopy",Vector2(560,730)]],
         "quarantine":Rect2(60,520,280,150)},
        {"b":{"nw":["pharmacy","ЛАБОРАТОРИЯ"],"ne":["utility_house","ВИВАРИЙ"]},
         "p":[["herb_beds",Vector2(560,560)],["herb_beds",Vector2(690,560)],["herb_beds",Vector2(560,660)],["herb_beds",Vector2(690,660)],
              ["poi:greenhouse",Vector2(140,600)],["poi:greenhouse",Vector2(270,600)],["poi:greenhouse",Vector2(140,720)],["poi:greenhouse",Vector2(270,720)],
              ["solar_rig",Vector2(470,300)],["oxygen_rack",Vector2(620,740)]],
         "trees":[Vector2(740,470)]},
        {"b":{"nw":["utility_house","КПП"],"ne":["utility_house","САНПРОПУСКНИК"]},
         "p":[["wash_station",Vector2(270,690)],["ambulance",Vector2(600,600)],["herb_beds",Vector2(140,580)],["street:bench",Vector2(290,300)],
              ["prop:traffic_cone",Vector2(470,560),0.58],["decon_frame",Vector2(640,730)],["herb_beds",Vector2(140,680)]],
         "trees":[Vector2(740,720),Vector2(90,740)]}
    ]
}

# Displayed scale (atlas is drawn at 2x density). Authored per-piece scales are
# boosted a little so yard structures read against the large settlement blocks.
const PIECE_BASE_SCALE = 0.78
const PIECE_DEFAULT_SCALE = {
    "fire_barrel":0.6,"long_table":0.74,"laundry_line":0.76,"market_stall":0.8,"market_stall_b":0.8,
    "garden_beds":0.72,"herb_beds":0.72,"chicken_coop":0.74,"water_point":0.72,"field_kitchen":0.8,
    "sandbag_nest":0.74,"hesco_row":0.78,"jersey_blocks":0.74,"wash_station":0.66,"oxygen_rack":0.66,
    "solar_rig":0.66,"triage_canopy":0.74,"decon_frame":0.7,"medical_tent":0.78,"army_tent":0.8
}

# Collision footprints (world px, bottom-anchored) for the set pieces.
const PIECE_SOLIDS = {
    "market_stall":Vector2(44,10),"market_stall_b":Vector2(40,10),"water_tower":Vector2(30,16),"garden_beds":Vector2.ZERO,
    "laundry_line":Vector2.ZERO,"field_kitchen":Vector2(34,12),"platform_canopy":Vector2(90,12),"radio_mast":Vector2(20,12),
    "water_point":Vector2(40,10),"chicken_coop":Vector2(44,12),"long_table":Vector2(52,10),"fire_barrel":Vector2(10,6),
    "sandbag_nest":Vector2(46,10),"hesco_row":Vector2(70,10),"army_tent":Vector2(40,14),"flag_pole":Vector2(8,6),
    "searchlight_tower":Vector2(24,12),"ammo_bunker":Vector2(60,16),"btr":Vector2(70,18),"jersey_blocks":Vector2(66,6),
    "jib_crane":Vector2(16,10),"scrap_heap":Vector2(56,12),"wind_turbine":Vector2(12,8),"fuel_station":Vector2(60,14),
    "car_on_blocks":Vector2(58,14),"furnace":Vector2(36,14),"solar_rig":Vector2(60,8),"container_shop":Vector2(68,14),
    "medical_tent":Vector2(40,14),"decon_frame":Vector2(40,10),"triage_canopy":Vector2(64,10),"herb_beds":Vector2.ZERO,
    "incinerator":Vector2(32,14),"oxygen_rack":Vector2(44,8),"ambulance":Vector2(56,16),"wash_station":Vector2(36,8),
    "poi:woodpile":Vector2(30,10),"poi:greenhouse":Vector2(54,16),"poi:pallets_tarp":Vector2(52,14),"poi:cable_drum":Vector2(22,10),
    "poi:boxcar":Vector2(110,20),"poi:tank_wagon":Vector2(110,20),"poi:transformer":Vector2(40,16),"poi:army_truck":Vector2(104,26),"poi:forklift":Vector2(32,12),
    "poi:hedgehogs":Vector2.ZERO,"poi:pipe_stack":Vector2(58,14),"poi:h_tank":Vector2(96,18),"poi:silo":Vector2(28,16)
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

static func perimeter(offset:Vector2i) -> Dictionary:
    # Walls run only along the outer edge of the 3x3 settlement, so the nine
    # sectors read as one enclosed town. Every side opens in its middle sector
    # (aligned with the regional road cross); the south-east sector - the service
    # checkpoint / cargo gate of every faction - has its own south gate.
    var walls = {}
    if offset.y == -1:
        walls["n"] = offset.x == 0
    if offset.y == 1:
        walls["s"] = offset.x == 0 or offset.x == 1
    if offset.x == -1:
        walls["w"] = offset.y == 0
    if offset.x == 1:
        walls["e"] = offset.y == 0
    return walls

static func piece_solid(kind:String) -> Vector2:
    return PIECE_SOLIDS.get(kind,Vector2.ZERO)

static func cell(poi_id:String,offset:Vector2i) -> Dictionary:
    if not has(poi_id) or offset not in FOOTPRINT_3X3:
        return {}
    var d = SETTLEMENTS[poi_id]
    var idx = _index(offset)
    var role = str(d["roles"][idx])
    var sign = str(d["signs"][idx])
    var faction = str(d["faction"])
    var loot = "industrial" if faction == "mechanics" else ("military" if faction == "rubezh" else ("pharmacy" if faction == "lazaret" else "residential"))
    var plan = PLANS[faction][idx]
    var buildings = []
    var slot_index = 0
    for slot in SLOT_ORDER + ["x1","x2"]:
        var spec = plan["b"].get(slot,[])
        if spec.is_empty():
            slot_index += 1
            continue
        var building_sign = str(spec[1]) if spec.size() > 1 else sign
        var slot_data = SLOTS.get(slot,{})
        buildings.append({
            "id":"building_%d" % slot_index,"archetype":str(spec[0]),
            "pos":spec[2] if spec.size() > 2 else slot_data.get("pos",Vector2(384,384)),
            "size":spec[3] if spec.size() > 3 else slot_data.get("size",Vector2(160,110)),
            "sign":building_sign,"container_id":"cache_%d" % slot_index,"loot":loot
        })
        slot_index += 1
    var pieces = []
    for raw in plan.get("p",[]):
        var kind = str(raw[0])
        var piece_scale = float(raw[2]) if raw.size() > 2 else float(PIECE_DEFAULT_SCALE.get(kind,PIECE_BASE_SCALE))
        var solid = piece_solid(kind)
        if not kind.contains(":"):
            # footprints are authored for a 0.5 display scale
            solid = (solid * piece_scale / 0.5).round()
        pieces.append({
            "kind":kind,"pos":raw[1],"scale":piece_scale,
            "solid":solid,"flip":(int(raw[1].x + raw[1].y) % 3) == 0
        })
    var lamps = [Vector2(318,282),Vector2(574,500)]
    var workbenches = [Vector2(520,548)] if faction == "mechanics" and offset in [Vector2i.ZERO,Vector2i(1,0)] else []
    return {
        "role":role,"ground":str(d["ground"]),"faction_id":faction,"safe_settlement":true,
        "settlement_style":faction,"settlement_index":idx,
        "buildings":buildings,
        "loose_containers":[{"id":"cache_9","pos":Vector2(182,610),"loot":loot,"name":"Запасы поселения"}],
        "fences":[],
        "perimeter":perimeter(offset),
        "set_pieces":pieces,
        "trees":plan.get("trees",[]).duplicate(),
        "garlands":plan.get("garlands",[]).duplicate(true),
        "parade":plan.get("parade",Rect2()),
        "quarantine":plan.get("quarantine",Rect2()),
        "lamps":lamps,
        "workbenches":workbenches,
        "props":[],
        "enemy_count":0,"enemy_mult":0.0,"tree_mult":0.0,"car_mult":0.0
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
