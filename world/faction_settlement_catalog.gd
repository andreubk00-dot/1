extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")
const SettlementBuildingModels = preload("res://world/settlement_building_models.gd")

const FOOTPRINT_3X3 = [
    Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),
    Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),
    Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)
]

const SETTLEMENTS = {
    "settlement_perron":{"name":"ПОСЕЛЕНИЕ «ПЕРРОН»","kind":"faction_settlement","faction":"perron","ground":"settlement_civic","roles":["жилой север","водонапорная и огороды","складской двор","западный КПП","рынок и площадь","кухня и общежитие","ремесленный двор","радиоузел","южный КПП"],"signs":["БАРАКИ","ВОДА","СКЛАД","КПП","РЫНОК","КУХНЯ","МАСТЕРСКИЕ","РАДИО","КПП"]},
    "settlement_rubezh":{"name":"УКРЕПРАЙОН «РУБЕЖ»","kind":"faction_settlement","faction":"rubezh","ground":"settlement_military","roles":["казарменный сектор","медпункт гарнизона","склады снабжения","западный периметр","штаб и плац","оружейная и ремонт","автопарк","радио и наблюдение","восточный КПП"],"signs":["КАЗАРМА","МЕДПУНКТ","СКЛАД","ПЕРИМЕТР","ШТАБ","ОРУЖЕЙНАЯ","АВТОПАРК","СВЯЗЬ","КПП"]},
    "settlement_mechanics":{"name":"АРТЕЛЬ «МЕХАНИКИ»","kind":"faction_settlement","faction":"mechanics","ground":"settlement_industrial","roles":["разборочный двор","электроцех","склад металла","приёмка","главная мастерская","рембоксы","топливный двор","экспедиционный склад","грузовые ворота"],"signs":["РАЗБОР","ЭЛЕКТРОЦЕХ","МЕТАЛЛ","ПРИЁМКА","АРТЕЛЬ","РЕМЗОНА","ТОПЛИВО","СНАБЖЕНИЕ","ВОРОТА"]},
    "settlement_lazaret":{"name":"ПОСЕЛЕНИЕ «ЛАЗАРЕТ»","kind":"faction_settlement","faction":"lazaret","ground":"settlement_medical","roles":["жилой корпус","аптечный склад","санитарный двор","приёмное отделение","клиника и площадь","диагностика","изоляционный корпус","лаборатория","служебный КПП"],"signs":["ЖИЛОЙ КОРПУС","АПТЕКА","САНДВОР","ПРИЁМ","КЛИНИКА","ДИАГНОСТИКА","ИЗОЛЯТОР","ЛАБОРАТОРИЯ","КПП"]},
    # dev65: the raiders' stronghold - a fenced concrete plant taken by force.
    # Same town grid as the settlements, but nobody here trades: every building
    # is searchable, the garrison (world/marauder_base.gd) holds the walls.
    "marauder_base":{"name":"БАЗА «ЧЁРНЫЙ ДВОР»","kind":"marauder_base","faction":"raiders","ground":"settlement_industrial","hostile":true,"roles":["гаражи и ремзона","главный цех","котельная","западные ворота","общак и лагерь","ж/д ветка","казармы","мастерские и пролом","штаб"],"signs":["ГАРАЖИ","ЦЕХ","КОТЕЛЬНАЯ","КПП","ОБЩАК","ВЕТКА","КАЗАРМА","МАСТЕРСКИЕ","ШТАБ"]}
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

# 1.22-dev4: the settlements are laid out as towns, not as three boxes per sector.
# Street grid (local sector coords): a main street runs through the middle of every
# sector (x/y 336..432, continuing into the gates) and a lane runs along every
# inner sector border. That cuts each 3x3 settlement into 36 blocks (4 per sector:
# nw/ne/sw/se). A block either holds buildings standing on its street line (the
# south edge - every entrance faces south) or a yard / square with set pieces.
# Buildings use authored exterior models from settlement_building_models.gd.
#   "b": {quad: [[model, sign, dx], ...]}      dx = offset from the block centre
#   "y": {quad: preset}                        yard preset, see YARDS
#   "p": [[kind, pos, scale?], ...]            extra pieces in sector coords
const QUADS = ["nw","ne","sw","se"]

const TOWNS = {
    "perron":[
        {"b":{"nw":[["perron_barrack","БАРАКИ",0]],"ne":[["perron_izba","ДОМ 12",-64],["perron_bathhouse","БАНЯ",82]],
              "sw":[["perron_izba","ДОМ 7",-66]],"se":[["perron_barrack","БАРАКИ №2",0]]},
         "y":{"sw":"garden_side"}},
        {"b":{"nw":[["perron_izba","ДОМ 3",-66]],"se":[["perron_izba","ДОМ 5",66]]},
         "y":{"nw":"garden_side","ne":"water_tower","sw":"greenhouses","se":"garden_side_w"}},
        {"b":{"nw":[["perron_warehouse","СКЛАД",0]],"ne":[["perron_warehouse","ЗЕРНО",0]],"se":[["perron_bathhouse","ВЕСОВАЯ",-80]]},
         "y":{"sw":"depot_yard","se":"crates_side"}},
        {"b":{"nw":[["perron_izba","КПП",-66]],"ne":[["perron_barrack","КАЗАРМА ОХРАНЫ",0]],"se":[["perron_warehouse","ДЕПО",0]]},
         "y":{"nw":"woodpile_side","sw":"rail_yard_w"},
         "p":[["poi:boxcar",Vector2(170,764)],["poi:boxcar",Vector2(660,764)]]},
        {"b":{"nw":[["perron_market","РЫНОК",0]],"ne":[["perron_canteen","ЧАЙНАЯ",0]],"sw":[["perron_station","ВОКЗАЛ",0]]},
         "y":{"se":"market_square"},
         "p":[["fire_barrel",Vector2(300,452)],["street:notice_board",Vector2(470,462)],["poi:tank_wagon",Vector2(600,764)]],
         "garlands":[[Vector2(452,444),Vector2(716,444)]]},
        {"b":{"nw":[["perron_canteen","СТОЛОВАЯ",0]],"ne":[["perron_barrack","ОБЩЕЖИТИЕ",0]],"sw":[["perron_izba","ДОМ 21",-66]]},
         "y":{"se":"kitchen_yard","sw":"laundry_side"},
         "p":[["poi:boxcar",Vector2(620,764)]]},
        {"b":{"nw":[["perron_warehouse","МАСТЕРСКИЕ",0]],"ne":[["perron_bathhouse","КУЗНЯ",-80]],"sw":[["perron_barrack","СТОЛЯРКА",0]]},
         "y":{"ne":"smithy_side","se":"woodpile_yard"}},
        {"b":{"nw":[["perron_radio","РАДИО",-70]],"ne":[["perron_izba","ДОМ РАДИСТА",66]],"sw":[["perron_bathhouse","ГЕНЕРАТОРНАЯ",-80]]},
         "y":{"nw":"radio_side","se":"garden_small","sw":"generator_side"}},
        {"b":{"nw":[["perron_izba","КПП",-66]],"ne":[["perron_warehouse","ДОСМОТР",0]],"se":[["perron_barrack","КАРАУЛ",0]]},
         "y":{"sw":"shanty_yard","nw":"woodpile_side"}}
    ],
    "rubezh":[
        {"b":{"nw":[["rubezh_barracks","КАЗАРМА",0]],"ne":[["rubezh_barracks","КАЗАРМА №2",0]],"sw":[["rubezh_barracks","КАЗАРМА №3",0]]},
         "y":{"se":"tent_camp"}},
        {"b":{"nw":[["rubezh_medpoint","МЕДПУНКТ",-40]],"ne":[["rubezh_guardhouse","ПОСТ",-66]],"se":[["rubezh_garages","САНТРАНСПОРТ",0]]},
         "y":{"sw":"field_hospital","ne":"sandbag_side"}},
        {"b":{"nw":[["rubezh_armory","СКЛАД",-40]],"ne":[["rubezh_hangar","СКЛАД ГСМ",0]],"sw":[["rubezh_garages","ПРОДСКЛАД",0]]},
         "y":{"se":"supply_yard","nw":"crates_side_mil"}},
        {"b":{"nw":[["rubezh_guardhouse","ПЕРИМЕТР",-66]],"ne":[["rubezh_barracks","КАРАУЛКА",0]]},
         "y":{"nw":"tower_side","sw":"firing_pos","se":"truck_park"}},
        {"b":{"nw":[["rubezh_hq","ШТАБ",0]],"ne":[["rubezh_comms","ДЕЖУРНАЯ",-60]]},
         "y":{"ne":"flag_side","sw":"parade_w","se":"parade_e"},
         "parade":Rect2(40,440,688,280)},
        {"b":{"nw":[["rubezh_armory","ОРУЖЕЙНАЯ",-40]],"ne":[["rubezh_guardhouse","ПОСТ №2",-66]],"sw":[["rubezh_hangar","РЕМБАТ",0]]},
         "y":{"ne":"sandbag_side_e","se":"truck_park"}},
        {"b":{"nw":[["rubezh_garages","АВТОПАРК",0]],"ne":[["rubezh_garages","БОКСЫ",0]],"sw":[["rubezh_hangar","АНГАР",0]]},
         "y":{"se":"motor_pool"}},
        {"b":{"nw":[["rubezh_comms","СВЯЗЬ",-60]],"ne":[["rubezh_barracks","ПОСТ",0]]},
         "y":{"nw":"mast_side","sw":"tower_yard","se":"radio_yard"}},
        {"b":{"nw":[["rubezh_guardhouse","КПП",-66]],"ne":[["rubezh_barracks","КАРАУЛ",0]]},
         "y":{"nw":"sandbag_side","sw":"barricade_yard","se":"checkpoint_yard"}}
    ],
    "mechanics":[
        {"b":{"nw":[["mech_workshop","РАЗБОР",0]],"sw":[["mech_garages","РАЗБОРКА",0]]},
         "y":{"ne":"crane_yard","se":"scrap_yard"}},
        {"b":{"nw":[["mech_electro","ЭЛЕКТРОЦЕХ",0]],"ne":[["mech_containers","ЖИЛЬЁ",-40]]},
         "y":{"sw":"wind_farm","se":"solar_farm","ne":"cable_side"}},
        {"b":{"nw":[["mech_hangar","МЕТАЛЛ",0]],"ne":[["mech_garages","ЛОМ",0]],"se":[["mech_workshop","ПРЕСС",0]]},
         "y":{"sw":"pipe_yard"}},
        {"b":{"nw":[["mech_fuel","ПРИЁМКА",-66]],"ne":[["mech_containers","ЖИЛЬЁ №2",-40]],"se":[["mech_garages","ВЕСЫ",0]]},
         "y":{"nw":"crates_side_ind","sw":"shanty_yard"}},
        {"b":{"nw":[["mech_office","АРТЕЛЬ",0]],"ne":[["mech_boiler","КОТЕЛЬНАЯ",-60]],"sw":[["mech_workshop","РЕМЦЕХ",0]]},
         "y":{"se":"crane_yard_s","ne":"forge_side"}},
        {"b":{"nw":[["mech_garages","РЕМБОКСЫ",0]],"ne":[["mech_hangar","РЕМБОКС 2",0]],"sw":[["mech_containers","ЖИЛЬЁ №3",-40]]},
         "y":{"se":"repair_yard","sw":"scrap_side"}},
        {"b":{"nw":[["mech_fuel","ТОПЛИВО",-66]],"se":[["mech_garages","ЦИСТЕРНЫ",0]]},
         "y":{"nw":"fuel_side","ne":"tank_farm","sw":"fuel_station_yard"}},
        {"b":{"nw":[["mech_hangar","СНАБЖЕНИЕ",0]],"ne":[["mech_electro","ЭКСПЕДИЦИЯ",0]]},
         "y":{"sw":"container_yard","se":"solar_farm"}},
        {"b":{"nw":[["mech_workshop","ДИСПЕТЧЕРСКАЯ",0]],"ne":[["mech_containers","ЖИЛЬЁ №4",-40]],"se":[["mech_garages","ГРУЗОВОЙ БОКС",0]]},
         "y":{"sw":"crane_yard_s"}}
    ],
    "lazaret":[
        {"b":{"nw":[["laz_residence","ЖИЛОЙ КОРПУС",-30]],"ne":[["laz_laundry","ПРАЧЕЧНАЯ",-60]],"sw":[["laz_residence","КОРПУС Б",-30]]},
         "y":{"se":"herb_garden","ne":"laundry_side"}},
        {"b":{"nw":[["laz_pharmacy","АПТЕКА",-60]],"ne":[["laz_pavilion","АПТЕЧНЫЙ СКЛАД",0]],"se":[["laz_laundry","КОТЕЛЬНАЯ",-60]]},
         "y":{"sw":"supply_yard_med","nw":"bench_side"}},
        {"b":{"nw":[["laz_laundry","САНДВОР",-60]],"sw":[["laz_checkpoint","ДЕЗИНФЕКЦИЯ",-70]]},
         "y":{"ne":"incinerator_yard","se":"decon_yard","nw":"laundry_side"}},
        {"b":{"nw":[["laz_hospital","ПРИЁМ",0]],"ne":[["laz_checkpoint","РЕГИСТРАТУРА",-70]],"se":[["laz_pavilion","ПАЛАТА 1",0]]},
         "y":{"sw":"ambulance_yard","ne":"bench_side"}},
        {"b":{"nw":[["laz_hospital","КЛИНИКА",0]],"ne":[["laz_pharmacy","ПРОЦЕДУРНАЯ",-60]],"sw":[["laz_pavilion","ПАЛАТА 2",0]]},
         "y":{"se":"triage_yard","ne":"garden_side_med"}},
        {"b":{"nw":[["laz_lab","ДИАГНОСТИКА",-40]],"ne":[["laz_residence","ПЕРСОНАЛ",-30]],"se":[["laz_pavilion","РЕНТГЕН",0]]},
         "y":{"sw":"tent_ward"}},
        {"b":{"nw":[["laz_isolation","ИЗОЛЯТОР",-30]],"se":[["laz_checkpoint","САНПРОПУСКНИК",-70]]},
         "y":{"ne":"quarantine","sw":"tent_ward","se":"decon_side"},
         "quarantine":Rect2(444,60,272,236)},
        {"b":{"nw":[["laz_lab","ЛАБОРАТОРИЯ",-40]],"ne":[["laz_pavilion","ВИВАРИЙ",0]]},
         "y":{"sw":"greenhouses_med","se":"cemetery"}},
        {"b":{"nw":[["laz_checkpoint","КПП",-70]],"ne":[["laz_laundry","ГАРАЖ СКОРЫХ",-60]],"se":[["laz_pavilion","ПАЛАТА 3",0]]},
         "y":{"sw":"ambulance_yard","nw":"bench_side"}}
    ]
}

# dev65: the base. Gate faces west (toward the city and the Mechanics), a breach
# in the south wall of the workshop sector, a rail spur in the east, the boss'
# HQ in the far south-east corner. "loot" per building, "keep" = rail bed rects
# no clutter may land on.
# readable traces inside the base (sector index -> clue). Positions sit on free
# floor: HQ and общак in their back rooms, the rest in the yards.
const BASE_NOTES = {
    8:{"id":"black_yard_sedoy_ledger","title":"Тетрадь Седого","prompt":"ТЕТРАДЬ","prop_kind":"paper_stack","scale":0.40,"pos":Vector2(150,222),
       "text":"«Хромому — два цинка 7.62, отработал. Механикам передать: восточная дорога наша, пока платят. Новых к общаку не пускать. Пролом на юге — Сене, сказал же: до холодов. Если Рубеж сунется — уходим через ветку.»"},
    4:{"id":"black_yard_stash_inventory","title":"Опись общака","prompt":"ОПИСЬ","prop_kind":"paper_stack","scale":0.40,"pos":Vector2(120,212),
       "text":"«Обоз Артели (вторник): шесть канистр, ящик инструмента, двое ушли. Фура с трассы: консервы, вода, бинты. Двое с Перрона: два ствола, рюкзак. Делить по-честному. Седому — треть.»"},
    3:{"id":"black_yard_post_rules","title":"Правила поста","prompt":"ПРАВИЛА","prop_kind":"paper_stack","scale":0.40,"pos":Vector2(244,356),
       "text":"«На посту не спать. Чужой у ворот — сначала крикни, потом стреляй. Своих по свисту. Ночью фонари не гасить. Смена с двух ночи — по одному, отметился и назад, пост пустым долго не держать. Кто бросит пост — к Седому на разговор.»"},
    6:{"id":"black_yard_letter_home","title":"Письмо","prompt":"ПИСЬМО","prop_kind":"newspapers","scale":0.38,"pos":Vector2(520,470),
       "text":"«Мам, я живой. Тут кормят и есть крыша. Люди тут не хорошие, но с ними не трогают. Как наберу на дорогу — уйду к вам на Перрон. Не говори никому, где я.»"},
    7:{"id":"black_yard_breach_note","title":"Записка у пролома","prompt":"ЗАПИСКА","prop_kind":"paper_stack","scale":0.38,"pos":Vector2(664,700),
       "text":"«Сеня! Дыру заделай до холодов, плиты у котельной. Седой узнает, что через неё к нам ходят, — обоим конец.»"}
}

# outer walls: the west gate is the only way in for a vehicle; the breach is a
# gap knocked through the south wall of the workshop sector (x of its middle)
const BASE_BREACH_X = 600.0
const BASE_BREACH_HALF = 30.0
const BASE_TOWN = [
    {"b":{"nw":[["mech_garages","ГАРАЖИ",0,"garage"]],"sw":[["rubezh_hangar","РЕМЗОНА",0,"industrial"]]},
     "y":{"ne":"repair_yard","se":"scrap_yard"},
     "p":[["searchlight_tower",Vector2(80,92),0.9],["oil_drums",Vector2(250,92)]]},
    {"b":{"nw":[["mech_hangar","ЦЕХ №1",0,"industrial"]],"ne":[["mech_workshop","ЦЕХ №2",0,"industrial"]]},
     "y":{"sw":"pipe_yard","se":"crane_yard_s"}},
    {"b":{"nw":[["mech_boiler","КОТЕЛЬНАЯ",-50,"industrial"]],"sw":[["mech_electro","ТРАНСФОРМАТОРНАЯ",0,"industrial"]]},
     "y":{"ne":"tank_farm_base","se":"coal_yard"},
     "p":[["poi:woodpile",Vector2(286,240)],["searchlight_tower",Vector2(690,92),0.9]]},
    {"b":{"nw":[["rubezh_guardhouse","КПП",60,"marauder_supply"]],"ne":[["rubezh_barracks","КАРАУЛКА",0,"residential"]]},
     "y":{"se":"barricade_yard","sw":"gate_yard"}},
    {"b":{"nw":[["mech_hangar","ОБЩАК",0,"marauder_stash"]],"ne":[["mech_fuel","ВЕСОВАЯ",-66,"garage"]]},
     "y":{"ne":"crates_side_ind","sw":"container_yard","se":"camp_yard"}},
    {"b":{"nw":[["mech_garages","ПАКГАУЗ",0,"marauder_supply"]]},
     "y":{"ne":"loading_yard"},
     "p":[["poi:boxcar",Vector2(170,604)],["poi:boxcar",Vector2(560,604)],["poi:tank_wagon",Vector2(600,684)],["poi:rail_signal",Vector2(706,560)]],
     "keep":[Rect2(36,588,700,36),Rect2(36,668,700,36)]},
    {"b":{"nw":[["rubezh_barracks","КАЗАРМА",0,"residential"]],"sw":[["mech_containers","ЖИЛЬЁ",40,"residential"]]},
     "y":{"ne":"shanty_yard","se":"tent_camp_base"},
     "p":[["searchlight_tower",Vector2(74,690),0.9]]},
    {"b":{"nw":[["mech_workshop","МАСТЕРСКИЕ",0,"industrial"]],"ne":[["mech_electro","ГЕНЕРАТОРНАЯ",0,"industrial"]],"sw":[["mech_garages","БОКСЫ",0,"garage"]]},
     "y":{"se":"breach_yard"},
     "keep":[Rect2(BASE_BREACH_X - 40.0,432,80,320)]},
    {"b":{"nw":[["rubezh_hq","ШТАБ",0,"marauder_stash"]],"ne":[["rubezh_armory","ОРУЖЕЙНАЯ",0,"marauder_stash"]],"se":[["rubezh_comms","РАДИОРУБКА",-40,"marauder_supply"]]},
     "y":{"sw":"hq_yard"},
     "p":[["searchlight_tower",Vector2(690,690),0.9],["radio_mast",Vector2(684,560),0.9]]}
]
# loose stashes in the yards (sector index -> list); every spot sits on open
# ground next to a yard piece, checked by tests/test_marauder_base_dev65.gd
const BASE_STASHES = {
    0:[{"id":"stash_0","pos":Vector2(520,600),"loot":"garage","name":"Ящик с запчастями"}],
    3:[{"id":"stash_0","pos":Vector2(560,500),"loot":"marauder_supply","name":"Отобранное на воротах"}],
    4:[{"id":"stash_0","pos":Vector2(520,700),"loot":"marauder_supply","name":"Котомка у костра"}],
    5:[{"id":"stash_0","pos":Vector2(470,180),"loot":"marauder_supply","name":"Груз с поезда"}],
    6:[{"id":"stash_0","pos":Vector2(600,560),"loot":"residential","name":"Пожитки в палатке"}],
    8:[{"id":"stash_0","pos":Vector2(150,690),"loot":"marauder_stash","name":"Ящик главаря"}]
}

const CLUTTER = {
    "perron":["shanty","tarp_shelter","rain_tank","junk_pile","tire_wall","bonfire","swing_set","cart","firewood_rack"],
    "rubezh":["scrap_barricade","tire_wall","burnt_car","rubble_pile","warning_sign","dead_tree","oil_drums"],
    "mechanics":["burnt_car","junk_pile","tire_wall","rubble_pile","shanty","rain_tank","scrap_barricade","oil_drums"],
    "lazaret":["rain_tank","tarp_shelter","junk_pile","dead_tree","warning_sign","graves","swing_set"],
    "raiders":["burnt_car","tire_wall","scrap_barricade","oil_drums","junk_pile","rubble_pile","warning_sign"]
}

const BACKYARD = {
    "perron":["garden_beds","firewood_rack","laundry_line","chicken_coop","dog_kennel","water_point","wheelbarrow","bicycle"],
    "rubezh":["prop:ammo_crate","poi:pallets_tarp","jersey_blocks","sandbag_nest","oil_drums","dog_kennel"],
    "mechanics":["scrap_heap","oil_drums","poi:cable_drum","poi:pipe_stack","car_on_blocks","bicycle","wheelbarrow"],
    "lazaret":["herb_beds","laundry_line","street:bench","bicycle","street:planter","wheelbarrow"],
    "raiders":["oil_drums","scrap_heap","poi:cable_drum","car_on_blocks","tire_wall","prop:ammo_crate"]
}

# Yard presets: pieces relative to the block centre (blocks are ~290 x 290).
# "_side" presets fill the free strip beside a narrow building (east side by
# default, "_w" variants the west side).
const YARDS = {
    "garden_side":[["garden_beds",Vector2(84,-50)],["garden_beds",Vector2(84,30)],["poi:woodpile",Vector2(96,110)]],
    "garden_side_w":[["garden_beds",Vector2(-84,-50)],["garden_beds",Vector2(-84,30)],["chicken_coop",Vector2(-90,110)]],
    "garden_small":[["garden_beds",Vector2(-70,-40)],["garden_beds",Vector2(60,-40)],["garden_beds",Vector2(-70,50)],["chicken_coop",Vector2(60,60)],["street:bench",Vector2(0,120)]],
    "water_tower":[["water_tower",Vector2(-30,70),0.9],["water_point",Vector2(80,90)],["garden_beds",Vector2(80,-40)],["garden_beds",Vector2(-90,-60)]],
    "greenhouses":[["poi:greenhouse",Vector2(-72,-50)],["poi:greenhouse",Vector2(72,-50)],["poi:greenhouse",Vector2(-72,50)],["poi:greenhouse",Vector2(72,50)],["water_point",Vector2(0,120)]],
    "depot_yard":[["poi:pallets_tarp",Vector2(-80,-40)],["poi:pallets_tarp",Vector2(60,-40)],["prop:supply_crate",Vector2(-80,60),0.62],["poi:cable_drum",Vector2(40,70)],["fire_barrel",Vector2(100,110)]],
    "crates_side":[["prop:supply_crate",Vector2(96,-60),0.62],["prop:cardboard_boxes",Vector2(96,0),0.58],["poi:pallets_tarp",Vector2(90,90)]],
    "woodpile_side":[["poi:woodpile",Vector2(84,-40)],["poi:woodpile",Vector2(84,40)],["fire_barrel",Vector2(110,110)]],
    "rail_yard_w":[["laundry_line",Vector2(-40,-60)],["poi:woodpile",Vector2(60,-50)],["fire_barrel",Vector2(100,40)],["long_table",Vector2(-30,50)]],
    "market_square":[["market_stall",Vector2(-90,-70)],["market_stall_b",Vector2(0,-70)],["market_stall",Vector2(90,-70)],
                     ["market_stall_b",Vector2(-90,30)],["long_table",Vector2(20,30)],["field_kitchen",Vector2(100,40)],
                     ["platform_canopy",Vector2(-40,128),0.74],["fire_barrel",Vector2(90,120)]],
    "kitchen_yard":[["field_kitchen",Vector2(-70,-40)],["long_table",Vector2(50,-50)],["long_table",Vector2(50,30)],["long_table",Vector2(-70,50)],["fire_barrel",Vector2(100,110)]],
    "laundry_side":[["laundry_line",Vector2(90,-50)],["laundry_line",Vector2(90,40)]],
    "smithy_side":[["furnace",Vector2(60,-20),0.66],["poi:woodpile",Vector2(90,90)]],
    "woodpile_yard":[["poi:woodpile",Vector2(-80,-50)],["poi:woodpile",Vector2(-80,40)],["poi:pallets_tarp",Vector2(60,-40)],["poi:cable_drum",Vector2(60,60)],["long_table",Vector2(0,120)]],
    "radio_side":[["radio_mast",Vector2(70,40),0.9]],
    "generator_side":[["prop:generator_prop",Vector2(80,-20),0.66],["poi:transformer",Vector2(80,80)]],
    "coop_yard":[["chicken_coop",Vector2(-70,-40)],["garden_beds",Vector2(60,-50)],["garden_beds",Vector2(60,40)],["water_point",Vector2(-70,60)],["laundry_line",Vector2(0,120)]],
    "tent_camp":[["army_tent",Vector2(-80,-50)],["army_tent",Vector2(40,-50)],["army_tent",Vector2(-80,60)],["army_tent",Vector2(40,60)],["hesco_row",Vector2(0,130)],["fire_barrel",Vector2(110,10)]],
    "field_hospital":[["medical_tent",Vector2(-70,-30)],["medical_tent",Vector2(60,-30)],["prop:stretcher",Vector2(-70,70),0.62],["ambulance",Vector2(60,90)]],
    "sandbag_side":[["sandbag_nest",Vector2(90,-30)],["prop:ammo_crate",Vector2(100,60),0.62]],
    "sandbag_side_e":[["sandbag_nest",Vector2(90,-30)],["jersey_blocks",Vector2(80,80)]],
    "supply_yard":[["ammo_bunker",Vector2(-50,-30),0.8],["poi:pallets_tarp",Vector2(80,-40)],["poi:forklift",Vector2(80,50)],["prop:ammo_crate",Vector2(-70,90),0.62],["hesco_row",Vector2(0,130)]],
    "crates_side_mil":[["prop:ammo_crate",Vector2(100,-40),0.62],["prop:supply_crate",Vector2(100,40),0.62]],
    "tower_side":[["searchlight_tower",Vector2(80,40),0.9]],
    "firing_pos":[["sandbag_nest",Vector2(-70,-40)],["hesco_row",Vector2(40,-40)],["poi:hedgehogs",Vector2(-60,60)],["searchlight_tower",Vector2(70,90),0.9]],
    "truck_park":[["poi:army_truck",Vector2(-40,-50)],["poi:army_truck",Vector2(-40,60)],["jersey_blocks",Vector2(90,120)],["fuel_station",Vector2(90,-20),0.66]],
    "flag_side":[["flag_pole",Vector2(90,60),0.9]],
    "parade_w":[["btr",Vector2(-60,40),0.8],["poi:army_truck",Vector2(60,80)]],
    "parade_e":[["btr",Vector2(60,40),0.8],["sandbag_nest",Vector2(-70,100)]],
    "motor_pool":[["btr",Vector2(-60,-50),0.8],["btr",Vector2(60,-50),0.8],["poi:army_truck",Vector2(-40,70)],["fuel_station",Vector2(80,80),0.66]],
    "mast_side":[["radio_mast",Vector2(80,40),0.9]],
    "tower_yard":[["searchlight_tower",Vector2(-70,20),0.9],["army_tent",Vector2(50,-30)],["sandbag_nest",Vector2(50,80)]],
    "radio_yard":[["radio_mast",Vector2(-40,60),0.9],["poi:transformer",Vector2(60,-40)],["poi:pallets_tarp",Vector2(60,70)]],
    "hesco_yard":[["hesco_row",Vector2(-40,-60)],["hesco_row",Vector2(40,20)],["sandbag_nest",Vector2(-60,90)],["poi:hedgehogs",Vector2(80,110)]],
    "checkpoint_yard":[["searchlight_tower",Vector2(80,-20),0.9],["sandbag_nest",Vector2(-60,-40)],["poi:hedgehogs",Vector2(-40,80)]],
    "crane_yard":[["jib_crane",Vector2(-30,60),0.9],["scrap_heap",Vector2(80,-40)],["car_on_blocks",Vector2(-80,-60)],["poi:pipe_stack",Vector2(70,110)]],
    "crane_yard_s":[["jib_crane",Vector2(-60,70),0.9],["container_shop",Vector2(60,-40)],["poi:pallets_tarp",Vector2(70,90)]],
    "scrap_yard":[["scrap_heap",Vector2(-70,-50)],["scrap_heap",Vector2(60,-60)],["car_on_blocks",Vector2(-60,60)],["car_on_blocks",Vector2(70,70)],["fire_barrel",Vector2(0,130)]],
    "scrap_side":[["scrap_heap",Vector2(90,-10),0.6]],
    "cable_side":[["poi:cable_drum",Vector2(100,-40)],["poi:transformer",Vector2(96,60)]],
    "wind_farm":[["wind_turbine",Vector2(-70,0),0.9],["wind_turbine",Vector2(60,70),0.9],["poi:transformer",Vector2(60,-60)],["poi:cable_drum",Vector2(-60,110)]],
    "solar_farm":[["solar_rig",Vector2(-70,-60)],["solar_rig",Vector2(60,-60)],["solar_rig",Vector2(-70,30)],["solar_rig",Vector2(60,30)],["poi:transformer",Vector2(0,120)]],
    "pipe_yard":[["poi:pipe_stack",Vector2(-70,-60)],["poi:pipe_stack",Vector2(-70,40)],["poi:forklift",Vector2(60,-40)],["scrap_heap",Vector2(60,70)]],
    "crates_side_ind":[["poi:pallets_tarp",Vector2(90,-40)],["poi:forklift",Vector2(96,60)]],
    "container_yard":[["container_shop",Vector2(-60,-50)],["container_shop",Vector2(60,-50)],["poi:pallets_tarp",Vector2(-60,70)],["poi:forklift",Vector2(60,70)]],
    "forge_side":[["furnace",Vector2(80,0),0.7],["poi:pipe_stack",Vector2(80,100)]],
    "repair_yard":[["car_on_blocks",Vector2(-60,-50)],["jib_crane",Vector2(50,60),0.84],["car_on_blocks",Vector2(-60,70)],["prop:tool_case",Vector2(80,-60),0.6]],
    "fuel_side":[["prop:gas_can",Vector2(84,-40),0.6],["prop:gas_can",Vector2(104,-30),0.55],["jersey_blocks",Vector2(90,60)]],
    "tank_farm":[["poi:h_tank",Vector2(0,-50)],["poi:h_tank",Vector2(0,50)],["poi:silo",Vector2(100,120)]],
    "fuel_station_yard":[["fuel_station",Vector2(-30,-20)],["poi:h_tank",Vector2(20,90)],["jersey_blocks",Vector2(-80,120)]],
    "herb_garden":[["herb_beds",Vector2(-70,-60)],["herb_beds",Vector2(60,-60)],["herb_beds",Vector2(-70,20)],["herb_beds",Vector2(60,20)],["street:bench",Vector2(-60,110)],["street:planter",Vector2(60,110)]],
    "bench_side":[["street:bench",Vector2(96,-20)],["street:planter",Vector2(96,60)]],
    "bench_side_e":[["street:bench",Vector2(-96,-20)],["street:planter",Vector2(-96,60)]],
    "supply_yard_med":[["oxygen_rack",Vector2(-70,-50)],["poi:pallets_tarp",Vector2(60,-40)],["prop:medboxes_large",Vector2(-60,50),0.62],["prop:med_supply_stack",Vector2(60,60),0.58],["wash_station",Vector2(0,120)]],
    "incinerator_yard":[["incinerator",Vector2(-40,40),0.84],["prop:trash_bag",Vector2(70,-40),0.58],["oxygen_rack",Vector2(70,70)]],
    "decon_yard":[["decon_frame",Vector2(-60,-20)],["wash_station",Vector2(60,-40)],["laundry_line",Vector2(40,70)],["prop:trash_bag",Vector2(-70,90),0.58]],
    "laundry_side_med":[["laundry_line",Vector2(90,0)]],
    "ambulance_yard":[["ambulance",Vector2(-60,-50)],["ambulance",Vector2(-60,60)],["triage_canopy",Vector2(70,0)],["prop:stretcher",Vector2(70,100),0.62]],
    "triage_yard":[["triage_canopy",Vector2(-40,-40)],["medical_tent",Vector2(70,60)],["herb_beds",Vector2(-70,70)],["wash_station",Vector2(80,-60)]],
    "garden_side_med":[["herb_beds",Vector2(90,-40)],["herb_beds",Vector2(90,50)]],
    "tent_ward":[["medical_tent",Vector2(-70,-40)],["medical_tent",Vector2(50,-40)],["decon_frame",Vector2(-60,80)],["wash_station",Vector2(60,80)]],
    "quarantine":[["medical_tent",Vector2(-60,-10)],["medical_tent",Vector2(60,-10)],["prop:body_bag",Vector2(0,80),0.55]],
    "decon_side":[["decon_frame",Vector2(80,-20)],["incinerator",Vector2(80,100),0.7]],
    "cemetery":[["graves",Vector2(-70,-70)],["graves",Vector2(50,-70)],["graves",Vector2(-70,10)],["graves",Vector2(50,10)],
                 ["graves",Vector2(-10,90)],["dead_tree",Vector2(100,100),0.8],["street:bench",Vector2(-90,120)]],
    "shanty_yard":[["shanty",Vector2(-70,-50)],["shanty",Vector2(60,-60)],["tarp_shelter",Vector2(-60,60)],["bonfire",Vector2(40,40)],
                   ["rain_tank",Vector2(90,100)],["junk_pile",Vector2(-10,120)]],
    "barricade_yard":[["scrap_barricade",Vector2(-50,-60)],["tire_wall",Vector2(60,-40)],["burnt_car",Vector2(-40,50)],
                      ["warning_sign",Vector2(70,60)],["rubble_pile",Vector2(40,120)]],
    "tank_farm_base":[["poi:h_tank",Vector2(-10,-50)],["poi:h_tank",Vector2(-10,40)],["jersey_blocks",Vector2(80,110)]],
    "coal_yard":[["junk_pile",Vector2(-70,-50)],["junk_pile",Vector2(60,-60)],["poi:pipe_stack",Vector2(-60,60)],["fire_barrel",Vector2(70,60)]],
    "gate_yard":[["searchlight_tower",Vector2(-80,20),0.9],["sandbag_nest",Vector2(40,-50)],["poi:hedgehogs",Vector2(60,60)],["tire_wall",Vector2(-60,110)]],
    "camp_yard":[["bonfire",Vector2(-30,-10)],["long_table",Vector2(60,-60)],["tarp_shelter",Vector2(-80,-80)],["shanty",Vector2(80,60)],["oil_drums",Vector2(-80,80)],["fire_barrel",Vector2(30,110)]],
    "loading_yard":[["poi:pallets_tarp",Vector2(-70,-60)],["poi:forklift",Vector2(50,-50)],["prop:supply_crate",Vector2(-70,40),0.62],["poi:cable_drum",Vector2(60,60)]],
    "tent_camp_base":[["army_tent",Vector2(-80,-50)],["army_tent",Vector2(40,-50)],["army_tent",Vector2(-80,60)],["bonfire",Vector2(40,60)],["laundry_line",Vector2(0,124)]],
    "breach_yard":[["rubble_pile",Vector2(-90,90)],["burnt_car",Vector2(-70,-50)],["scrap_barricade",Vector2(90,-60)],["tire_wall",Vector2(100,110)]],
    "hq_yard":[["btr",Vector2(-60,-40),0.8],["fire_barrel",Vector2(80,-70)],["sandbag_nest",Vector2(70,40)],["poi:army_truck",Vector2(-40,90)]],
    "greenhouses_med":[["poi:greenhouse",Vector2(-72,-50)],["poi:greenhouse",Vector2(72,-50)],["poi:greenhouse",Vector2(-72,50)],["poi:greenhouse",Vector2(72,50)],["solar_rig",Vector2(0,130),0.5]]
}

# Displayed scale (atlas is drawn at 2x density). Authored per-piece scales are
# boosted a little so yard structures read against the large settlement blocks.
const PIECE_BASE_SCALE = 0.78
const PIECE_DEFAULT_SCALE = {
    "fire_barrel":0.6,"long_table":0.74,"laundry_line":0.76,"market_stall":0.8,"market_stall_b":0.8,
    "garden_beds":0.72,"herb_beds":0.72,"chicken_coop":0.74,"water_point":0.72,"field_kitchen":0.8,
    "sandbag_nest":0.74,"hesco_row":0.78,"jersey_blocks":0.74,"wash_station":0.66,"oxygen_rack":0.66,
    "solar_rig":0.66,"triage_canopy":0.74,"decon_frame":0.7,"medical_tent":0.78,"army_tent":0.8,
    "shanty":0.8,"tarp_shelter":0.72,"scrap_barricade":0.7,"tire_wall":0.62,"burnt_car":0.78,"graves":0.6,
    "warning_sign":0.52,"rubble_pile":0.66,"dead_tree":0.9,"bonfire":0.56,"rain_tank":0.6,"junk_pile":0.66,
    "bus_stop":0.66,"kiosk":0.66,"swing_set":0.62,"dog_kennel":0.55,"wheelbarrow":0.5,"bicycle":0.5,
    "poster_board":0.55,"oil_drums":0.56,"firewood_rack":0.6,"cart":0.56
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
    "shanty":Vector2(46,14),"tarp_shelter":Vector2(50,10),"scrap_barricade":Vector2(56,10),"tire_wall":Vector2(44,8),
    "burnt_car":Vector2(50,14),"graves":Vector2(48,10),"warning_sign":Vector2.ZERO,"rubble_pile":Vector2(50,10),
    "dead_tree":Vector2(6,6),"bonfire":Vector2.ZERO,"rain_tank":Vector2(18,10),"junk_pile":Vector2(44,10),
    "pole_wood":Vector2(6,4),"pole_concrete":Vector2(6,4),"bus_stop":Vector2(64,10),"kiosk":Vector2(40,14),
    "swing_set":Vector2(56,6),"dog_kennel":Vector2(22,10),"wheelbarrow":Vector2.ZERO,"bicycle":Vector2.ZERO,
    "poster_board":Vector2(40,4),"oil_drums":Vector2(40,12),"firewood_rack":Vector2(56,10),"cart":Vector2(40,12),
    "poi:hedgehogs":Vector2.ZERO,"poi:pipe_stack":Vector2(58,14),"poi:h_tank":Vector2(96,18),"poi:silo":Vector2(28,16)
}

static func is_base(poi_id:String) -> bool:
    return bool(SETTLEMENTS.get(poi_id,{}).get("hostile",false))

static func base_perimeter(offset:Vector2i) -> Dictionary:
    # walls on the outer sides only; "gate" opens the west wall of the gate
    # sector, the breach is a narrow gap off the middle of the south wall
    var walls = {}
    if offset.y == -1:
        walls["n"] = false
    if offset.y == 1:
        walls["s"] = {"breach":BASE_BREACH_X,"half":BASE_BREACH_HALF} if offset.x == 0 else false
    if offset.x == -1:
        walls["w"] = offset.y == 0
    if offset.x == 1:
        walls["e"] = false
    return walls

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

static func block_rect(offset:Vector2i,quad:String) -> Rect2:
    # Blocks sit between the sector's main street (336..432) and the lanes on the
    # sector borders; outer sectors keep an extra strip inside the perimeter wall.
    var west = quad.ends_with("w")
    var north = quad.begins_with("n")
    var x0 = (44.0 if offset.x == -1 else 36.0) if west else 432.0
    var x1 = 336.0 if west else (724.0 if offset.x == 1 else 732.0)
    var y0 = (52.0 if offset.y == -1 else 36.0) if north else 432.0
    var y1 = 336.0 if north else (712.0 if offset.y == 1 else 732.0)
    return Rect2(x0,y0,x1 - x0,y1 - y0)

static func street_line(offset:Vector2i,quad:String) -> float:
    # buildings stand on the block's south edge with an 8 px pavement in front
    return block_rect(offset,quad).end.y - 8.0

static func _piece(kind:String,pos:Vector2,scale_value:float = -1.0) -> Dictionary:
    var piece_scale = scale_value if scale_value > 0.0 else float(PIECE_DEFAULT_SCALE.get(kind,PIECE_BASE_SCALE))
    var solid = piece_solid(kind)
    if not kind.contains(":"):
        # footprints are authored for a 0.5 display scale
        solid = (solid * piece_scale / 0.5).round()
    return {"kind":kind,"pos":pos,"scale":piece_scale,"solid":solid,"flip":(int(pos.x + pos.y) % 3) == 0}

static func cell(poi_id:String,offset:Vector2i) -> Dictionary:
    if not has(poi_id) or offset not in FOOTPRINT_3X3:
        return {}
    var d = SETTLEMENTS[poi_id]
    var idx = _index(offset)
    var role = str(d["roles"][idx])
    var faction = str(d["faction"])
    var loot = "industrial" if faction == "mechanics" else ("military" if faction == "rubezh" else ("pharmacy" if faction == "lazaret" else "residential"))
    var base = is_base(poi_id)
    var plan = BASE_TOWN[idx] if base else TOWNS[faction][idx]
    var buildings = []
    var slot_index = 0
    var blocks = {}
    for quad in QUADS:
        var rect = block_rect(offset,quad)
        var line = street_line(offset,quad)
        var used = []
        for raw in plan.get("b",{}).get(quad,[]):
            var model_id = str(raw[0])
            var model = SettlementBuildingModels.model(model_id)
            var size = model.get("size",Vector2(160,110))
            var center = Vector2(rect.get_center().x + float(raw[2]),line - size.y * 0.5)
            buildings.append({
                "id":"building_%d" % slot_index,"archetype":str(model.get("archetype","utility_house")),
                "model":model_id,"pos":center,"size":size,"sign":str(raw[1]),
                "container_id":"cache_%d" % slot_index,"loot":str(raw[3]) if raw.size() > 3 else loot,"block":quad
            })
            used.append(Rect2(center - size * 0.5,size))
            slot_index += 1
        blocks[quad] = {"rect":rect,"street_line":line,"buildings":used,"yard":str(plan.get("y",{}).get(quad,""))}
    var pieces = []
    for quad in QUADS:
        var preset = str(plan.get("y",{}).get(quad,""))
        if preset == "":
            continue
        var c = blocks[quad]["rect"].get_center()
        for raw in YARDS.get(preset,[]):
            pieces.append(_piece(str(raw[0]),c + raw[1],float(raw[2]) if raw.size() > 2 else -1.0))
    for raw in plan.get("p",[]):
        pieces.append(_piece(str(raw[0]),raw[1],float(raw[2]) if raw.size() > 2 else -1.0))
    # back gardens: the strip behind a building row that its roof does not cover
    var rng = RandomNumberGenerator.new()
    rng.seed = int(abs(offset.x * 7919 + offset.y * 104729 + faction.hash())) + 17
    var back_kinds = BACKYARD.get(faction,[])
    for quad in QUADS:
        var block = blocks[quad]
        if block["buildings"].is_empty():
            continue
        var rect:Rect2 = block["rect"]
        var roof_top = 9999.0
        for raw in plan.get("b",{}).get(quad,[]):
            var model = SettlementBuildingModels.model(str(raw[0]))
            var size = model.get("size",Vector2(160,110))
            roof_top = min(roof_top,block["street_line"] - size.y - float(model.get("facade_height",50.0)) - float(model.get("roof_rise",0.0)))
        var strip = roof_top - rect.position.y
        if strip < 58.0:
            continue
        var y = rect.position.y + min(strip - 6.0,62.0)
        var count = 3 if rect.size.x > 260.0 else 2
        for i in range(count):
            var x = rect.position.x + rect.size.x * (float(i) + 0.5) / float(count) + rng.randf_range(-14.0,14.0)
            pieces.append(_piece(str(back_kinds[rng.randi_range(0,back_kinds.size() - 1)]),Vector2(round(x),round(y))))
    var workbenches = [Vector2(520,548)] if faction == "mechanics" and offset in [Vector2i.ZERO,Vector2i(1,0)] else []
    if base:
        return {
            "role":role,"ground":str(d["ground"]),"faction_id":faction,"safe_settlement":false,"marauder_base":true,
            "settlement_style":"raiders","settlement_index":idx,"settlement_offset":offset,
            "buildings":buildings,"blocks":blocks,
            "loose_containers":BASE_STASHES.get(idx,[]).duplicate(true),
            "fences":[],"perimeter":base_perimeter(offset),"set_pieces":pieces,"trees":[],"garlands":[],
            "parade":Rect2(),"quarantine":Rect2(),"lamps":[],"workbenches":[Vector2(520,560)] if idx == 7 else [],
            "props":[],"keep_clear":plan.get("keep",[]).duplicate(true),
            "enemy_count":0,"enemy_mult":0.0,"tree_mult":0.0,"car_mult":0.0
        }
    return {
        "role":role,"ground":str(d["ground"]),"faction_id":faction,"safe_settlement":true,
        "settlement_style":faction,"settlement_index":idx,"settlement_offset":offset,
        "buildings":buildings,"blocks":blocks,
        "loose_containers":[{"id":"cache_9","pos":Vector2(182,610),"loot":loot,"name":"Запасы поселения"}],
        "fences":[],
        "perimeter":perimeter(offset),
        "set_pieces":pieces,
        "trees":[],
        "garlands":plan.get("garlands",[]).duplicate(true),
        "parade":plan.get("parade",Rect2()),
        "quarantine":plan.get("quarantine",Rect2()),
        "lamps":[],
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
