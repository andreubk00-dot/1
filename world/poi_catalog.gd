extends RefCounted
const FactionSettlementCatalog = preload("res://world/faction_settlement_catalog.gd")

# OSTATOK 0.85 — authored multi-chunk points of interest.
# A POI is described as a small compound made of several chunk-cells.  The
# renderer in main_script_mod.gd consumes this data while keeping gameplay and
# persistence ids stable.  This gives future map/quest/expedition systems a
# deterministic physical location instead of a procedural marker.

const COMPOUNDS = {
    "garage_coop_sever": {
        "name":"ГСК «СЕВЕР»",
        "kind":"garage_coop",
        "footprint":[Vector2i(0,0),Vector2i(-1,0),Vector2i(0,-1),Vector2i(-1,-1)],
        "cells":{
            "0,0":{
                "role":"центральный проезд",
                "ground":"garage_lanes",
                "buildings":[
                    {"id":"building_0","archetype":"garage_row","pos":Vector2(176,150),"size":Vector2(278,108),"sign":"ГАРАЖИ 21–28","container_id":"cache_0"},
                    {"id":"building_1","archetype":"repair_bay","pos":Vector2(604,150),"size":Vector2(226,126),"sign":"ШИНОМОНТАЖ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(148,620),"size":Vector2(126,88),"sign":"СТОРОЖКА","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(602,612),"loot":"garage","name":"Запчасти у ворот"}],
                "fences":[{"pos":Vector2(384,58),"length":610},{"pos":Vector2(690,220),"length":120}],
                "props":[
                    {"kind":"gas_can","pos":Vector2(518,330),"z":4,"scale":0.52},
                    {"kind":"road_barrier","pos":Vector2(384,292),"z":4,"scale":0.62},
                    {"kind":"wooden_debris","pos":Vector2(560,548),"z":2,"scale":0.46}
                ],
                "lamps":[Vector2(318,280),Vector2(576,494)],
                "enemy_mult":0.90,"tree_mult":0.25,"car_mult":0.85
            },
            "-1,0":{
                "role":"старые боксы",
                "ground":"garage_lanes",
                "buildings":[
                    {"id":"building_0","archetype":"garage_row","pos":Vector2(170,144),"size":Vector2(292,112),"sign":"ГАРАЖИ 1–10","container_id":"cache_0"},
                    {"id":"building_1","archetype":"garage_row","pos":Vector2(604,136),"size":Vector2(240,104),"sign":"ГАРАЖИ 11–16","container_id":"cache_1"},
                    {"id":"building_2","archetype":"garage_row","pos":Vector2(188,620),"size":Vector2(258,104),"sign":"ГАРАЖИ 17–20","container_id":"cache_2"},
                    {"id":"building_3","archetype":"shed","pos":Vector2(624,610),"size":Vector2(104,78),"sign":"СКЛАД","container_id":"cache_3"}
                ],
                "fences":[{"pos":Vector2(384,62),"length":620}],
                "props":[{"kind":"trash_bin","pos":Vector2(580,318),"z":3,"scale":0.54},{"kind":"scattered_bottles","pos":Vector2(208,526),"z":2,"scale":0.42}],
                "tree_mult":0.18,"car_mult":0.65
            },
            "0,-1":{
                "role":"ремонтный двор",
                "ground":"service_yard",
                "buildings":[
                    {"id":"building_0","archetype":"service_shop","pos":Vector2(176,150),"size":Vector2(252,138),"sign":"АВТОСЕРВИС","container_id":"cache_0"},
                    {"id":"building_1","archetype":"repair_bay","pos":Vector2(600,144),"size":Vector2(242,128),"sign":"РЕМЗОНА","container_id":"cache_1"},
                    {"id":"building_2","archetype":"warehouse","pos":Vector2(184,616),"size":Vector2(214,112),"sign":"ЗАПЧАСТИ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(608,604),"loot":"garage","name":"Ящик с инструментом"}],
                "workbenches":[Vector2(570,560)],
                "props":[{"kind":"generator_prop","pos":Vector2(530,528),"z":4,"scale":0.52},{"kind":"barrel","pos":Vector2(628,538),"z":4,"scale":0.50}],
                "tree_mult":0.12,"car_mult":1.15,"enemy_mult":1.05
            },
            "-1,-1":{
                "role":"заброшенный край",
                "ground":"garage_lanes",
                "buildings":[
                    {"id":"building_0","archetype":"garage_row","pos":Vector2(188,150),"size":Vector2(270,106),"sign":"ГАРАЖИ 29–36","container_id":"cache_0"},
                    {"id":"building_1","archetype":"utility_house","pos":Vector2(614,140),"size":Vector2(132,96),"sign":"ЭЛЕКТРОЩИТОВАЯ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"shed","pos":Vector2(150,620),"size":Vector2(94,72),"sign":"САРАЙ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(620,620),"loot":"garage","name":"Брошенный багажник"}],
                "props":[{"kind":"rubble","pos":Vector2(566,512),"z":2,"scale":0.48},{"kind":"gas_can","pos":Vector2(528,520),"z":3,"scale":0.44}],
                "tree_mult":0.40,"car_mult":0.70
            }
        }
    },

    "factory_7": {
        "name":"ПРОМКОМБИНАТ №7",
        "kind":"factory_complex",
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)],
        "cells":{
            "0,0":{
                "role":"главный цех",
                "ground":"factory_hall",
                "buildings":[
                    {"id":"building_0","archetype":"workshop","pos":Vector2(190,160),"size":Vector2(334,202),"sign":"ЦЕХ №1","container_id":"cache_0"},
                    {"id":"building_1","archetype":"factory_admin","pos":Vector2(612,148),"size":Vector2(172,132),"sign":"МАСТЕРСКАЯ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"repair_bay","pos":Vector2(608,616),"size":Vector2(232,128),"sign":"РЕМОНТНЫЙ БОКС","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(202,596),"loot":"industrial","name":"Тележка с деталями"}],
                "workbenches":[Vector2(596,548)],
                "fences":[{"pos":Vector2(384,58),"length":630}],
                "props":[{"kind":"generator_prop","pos":Vector2(516,530),"z":4,"scale":0.54},{"kind":"barrel","pos":Vector2(548,526),"z":4,"scale":0.52},{"kind":"road_sign","pos":Vector2(350,286),"z":4,"scale":0.58}],
                "lamps":[Vector2(315,282),Vector2(574,500)],
                "enemy_mult":1.25,"tree_mult":0.05,"car_mult":0.75
            },
            "1,0":{
                "role":"склад и рампа",
                "ground":"factory_loading",
                "buildings":[
                    {"id":"building_0","archetype":"warehouse","pos":Vector2(188,152),"size":Vector2(322,166),"sign":"СКЛАД ГОТОВОЙ ПРОДУКЦИИ","container_id":"cache_0"},
                    {"id":"building_1","archetype":"warehouse","pos":Vector2(612,144),"size":Vector2(230,120),"sign":"СКЛАД №2","container_id":"cache_1"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(624,610),"size":Vector2(118,86),"sign":"КОМПРЕССОРНАЯ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(190,604),"loot":"industrial","name":"Паллеты у рампы"}],
                "props":[{"kind":"cardboard_boxes","pos":Vector2(232,536),"z":3,"scale":0.52},{"kind":"supply_crate","pos":Vector2(270,538),"z":3,"scale":0.50},{"kind":"shopping_cart","pos":Vector2(520,520),"z":4,"scale":0.56}],
                "enemy_mult":1.20,"tree_mult":0.03,"car_mult":1.10
            },
            "0,1":{
                "role":"АБК и проходная",
                "ground":"factory_admin",
                "buildings":[
                    {"id":"building_0","archetype":"factory_admin","pos":Vector2(174,152),"size":Vector2(236,164),"sign":"АБК","container_id":"cache_0"},
                    {"id":"building_1","archetype":"checkpoint","pos":Vector2(618,138),"size":Vector2(126,92),"sign":"ПРОХОДНАЯ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"warehouse","pos":Vector2(170,616),"size":Vector2(218,116),"sign":"АРХИВ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(612,604),"loot":"industrial","name":"Шкаф охраны"}],
                "fences":[{"pos":Vector2(560,286),"length":210}],
                "props":[{"kind":"road_barrier","pos":Vector2(388,296),"z":4,"scale":0.64},{"kind":"traffic_cone","pos":Vector2(430,308),"z":4,"scale":0.54}],
                "lamps":[Vector2(328,286)],
                "enemy_mult":1.05,"tree_mult":0.10,"car_mult":0.85
            },
            "1,1":{
                "role":"энергодвор",
                "ground":"factory_yard",
                "buildings":[
                    {"id":"building_0","archetype":"repair_bay","pos":Vector2(164,150),"size":Vector2(238,130),"sign":"ЭНЕРГОЦЕХ","container_id":"cache_0","loot":"industrial_secure"},
                    {"id":"building_1","archetype":"utility_house","pos":Vector2(616,144),"size":Vector2(126,92),"sign":"ЩИТОВАЯ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"shed","pos":Vector2(626,612),"size":Vector2(106,78),"sign":"ЗИП","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(184,602),"loot":"industrial_secure","name":"Защищённый технический резерв"}],
                "workbenches":[Vector2(210,548)],
                "props":[{"kind":"generator_prop","pos":Vector2(512,520),"z":4,"scale":0.62},{"kind":"barrel","pos":Vector2(550,534),"z":4,"scale":0.52},{"kind":"barrel","pos":Vector2(578,526),"z":4,"scale":0.48}],
                "enemy_mult":1.35,"tree_mult":0.02,"car_mult":0.65
            }
        }
    },

    "rail_depot": {
        "name":"ЖЕЛЕЗНОДОРОЖНОЕ ДЕПО",
        "kind":"rail_depot",
        "footprint":[Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0)],
        "cells":{
            "-1,0":{
                "role":"ремонтные пути",
                "ground":"rail_repair",
                "buildings":[
                    {"id":"building_0","archetype":"workshop","pos":Vector2(184,156),"size":Vector2(314,174),"sign":"ЛОКОМОТИВНЫЙ ЦЕХ","container_id":"cache_0"},
                    {"id":"building_1","archetype":"rail_service","pos":Vector2(620,144),"size":Vector2(154,108),"sign":"ПЧ-4","container_id":"cache_1"},
                    {"id":"building_2","archetype":"repair_bay","pos":Vector2(614,616),"size":Vector2(214,118),"sign":"СМОТРОВАЯ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(182,606),"loot":"industrial","name":"Инструментальная тележка"}],
                "workbenches":[Vector2(590,554)],
                "props":[{"kind":"gas_can","pos":Vector2(548,532),"z":3,"scale":0.44},{"kind":"barrel","pos":Vector2(520,532),"z":4,"scale":0.50}],
                "enemy_mult":1.15,"tree_mult":0.02,"car_mult":0.45
            },
            "0,0":{
                "role":"управление депо",
                "ground":"rail_platform",
                "buildings":[
                    {"id":"building_0","archetype":"factory_admin","pos":Vector2(170,150),"size":Vector2(224,158),"sign":"УПРАВЛЕНИЕ ДЕПО","container_id":"cache_0"},
                    {"id":"building_1","archetype":"rail_store","pos":Vector2(600,142),"size":Vector2(270,118),"sign":"ПУТЕВОЙ СКЛАД","container_id":"cache_1"},
                    {"id":"building_2","archetype":"rail_service","pos":Vector2(158,620),"size":Vector2(148,102),"sign":"ДЕЖУРНЫЙ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(612,604),"loot":"industrial","name":"Складской шкаф"}],
                "lamps":[Vector2(328,282),Vector2(516,492)],
                "props":[{"kind":"road_sign","pos":Vector2(370,294),"z":4,"scale":0.62},{"kind":"supply_crate","pos":Vector2(534,528),"z":3,"scale":0.48}],
                "enemy_mult":1.10,"tree_mult":0.03,"car_mult":0.50
            },
            "1,0":{
                "role":"грузовой двор",
                "ground":"rail_loading",
                "buildings":[
                    {"id":"building_0","archetype":"warehouse","pos":Vector2(188,152),"size":Vector2(304,148),"sign":"ГРУЗОВОЙ СКЛАД","container_id":"cache_0"},
                    {"id":"building_1","archetype":"rail_store","pos":Vector2(614,142),"size":Vector2(230,110),"sign":"МАТЕРИАЛЬНЫЙ СКЛАД","container_id":"cache_1"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(618,616),"size":Vector2(118,84),"sign":"ВЕСОВАЯ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(182,602),"loot":"industrial","name":"Паллеты на платформе"}],
                "props":[{"kind":"cardboard_boxes","pos":Vector2(236,532),"z":3,"scale":0.50},{"kind":"supply_crate","pos":Vector2(270,532),"z":3,"scale":0.48}],
                "enemy_mult":1.20,"tree_mult":0.02,"car_mult":0.55
            }
        }
    },

    "dacha_coop_zarya": {
        "name":"СНТ «ЗАРЯ»",
        "kind":"dacha_coop",
        "footprint":[Vector2i(0,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(-1,1)],
        "cells":{
            "0,0":{
                "role":"главная улица",
                "ground":"dacha_plots",
                "buildings":[
                    {"id":"building_0","archetype":"country_house","pos":Vector2(164,142),"size":Vector2(184,132),"sign":"ДОМ №18","container_id":"cache_0"},
                    {"id":"building_1","archetype":"dacha","pos":Vector2(618,152),"size":Vector2(148,110),"sign":"ДАЧА №21","container_id":"cache_1"},
                    {"id":"building_2","archetype":"shed","pos":Vector2(130,624),"size":Vector2(92,70),"sign":"САРАЙ","container_id":"cache_2"},
                    {"id":"building_3","archetype":"dacha","pos":Vector2(626,612),"size":Vector2(126,94),"sign":"ДАЧА №22","container_id":"cache_3"}
                ],
                "fences":[{"pos":Vector2(188,276),"length":188},{"pos":Vector2(590,510),"length":156}],
                "props":[{"kind":"wooden_debris","pos":Vector2(548,538),"z":2,"scale":0.42}],
                "tree_mult":1.25,"car_mult":0.40,"enemy_mult":0.80
            },
            "-1,0":{
                "role":"старые участки",
                "ground":"dacha_plots",
                "buildings":[
                    {"id":"building_0","archetype":"dacha","pos":Vector2(142,150),"size":Vector2(126,96),"sign":"ДАЧА №3","container_id":"cache_0"},
                    {"id":"building_1","archetype":"country_house","pos":Vector2(612,140),"size":Vector2(196,140),"sign":"ДОМ №5","container_id":"cache_1"},
                    {"id":"building_2","archetype":"shed","pos":Vector2(166,618),"size":Vector2(108,78),"sign":"ХОЗБЛОК","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(620,610),"loot":"rural","name":"Погребные запасы"}],
                "fences":[{"pos":Vector2(180,276),"length":178},{"pos":Vector2(590,508),"length":170}],
                "tree_mult":1.40,"car_mult":0.30
            },
            "0,1":{
                "role":"садовые участки",
                "ground":"dacha_gardens",
                "buildings":[
                    {"id":"building_0","archetype":"country_house","pos":Vector2(176,150),"size":Vector2(202,146),"sign":"ДОМ №27","container_id":"cache_0"},
                    {"id":"building_1","archetype":"shed","pos":Vector2(620,138),"size":Vector2(102,76),"sign":"ТЕПЛИЦА","container_id":"cache_1"},
                    {"id":"building_2","archetype":"dacha","pos":Vector2(620,618),"size":Vector2(142,106),"sign":"ДАЧА №29","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(154,606),"loot":"rural","name":"Ящик с садовым инструментом"}],
                "fences":[{"pos":Vector2(384,270),"length":250}],
                "tree_mult":1.55,"car_mult":0.22,"enemy_mult":0.72
            },
            "-1,1":{
                "role":"край кооператива",
                "ground":"dacha_gardens",
                "buildings":[
                    {"id":"building_0","archetype":"dacha","pos":Vector2(156,146),"size":Vector2(134,102),"sign":"ДАЧА №9","container_id":"cache_0"},
                    {"id":"building_1","archetype":"shed","pos":Vector2(608,140),"size":Vector2(96,72),"sign":"БАНЯ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"country_house","pos":Vector2(174,616),"size":Vector2(188,134),"sign":"ДОМ №12","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(618,610),"loot":"rural","name":"Старая кладовая"}],
                "tree_mult":1.60,"car_mult":0.20,"enemy_mult":0.70
            }
        }
    },

    "military_checkpoint": {
        "name":"ВОЕННЫЙ КПП «ВОСТОК»",
        "kind":"military_checkpoint",
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(1,-1)],
        "cells":{
            "0,0":{
                "role":"внешний КПП",
                "ground":"mil_checkpoint",
                "buildings":[
                    {"id":"building_0","archetype":"checkpoint","pos":Vector2(154,150),"size":Vector2(144,102),"sign":"КПП-1","container_id":"cache_0"},
                    {"id":"building_1","archetype":"mil_store","pos":Vector2(618,146),"size":Vector2(226,126),"sign":"СКЛАД ОХРАНЫ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"comms","pos":Vector2(620,616),"size":Vector2(142,110),"sign":"СВЯЗЬ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(166,604),"loot":"military","name":"Полевой ящик КПП"}],
                "fences":[{"pos":Vector2(384,70),"length":640},{"pos":Vector2(684,244),"length":170}],
                "props":[{"kind":"sandbags","pos":Vector2(342,292),"z":5,"scale":0.70},{"kind":"road_barrier","pos":Vector2(414,296),"z":4,"scale":0.68}],
                "lamps":[Vector2(316,278),Vector2(512,494)],
                "enemy_mult":1.35,"tree_mult":0.04,"car_mult":0.55
            },
            "1,0":{
                "role":"складской сектор",
                "ground":"mil_yard",
                "buildings":[
                    {"id":"building_0","archetype":"mil_store","pos":Vector2(186,152),"size":Vector2(286,150),"sign":"СКЛАД В/Ч №2","container_id":"cache_0","loot":"military_secure"},
                    {"id":"building_1","archetype":"mil_store","pos":Vector2(612,144),"size":Vector2(224,118),"sign":"СКЛАД ГСМ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(622,614),"size":Vector2(116,84),"sign":"КАРАУЛ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(184,608),"loot":"military_secure","name":"Запечатанный армейский ящик"}],
                "fences":[{"pos":Vector2(384,66),"length":650}],
                "props":[{"kind":"ammo_crate","pos":Vector2(526,532),"z":4,"scale":0.52},{"kind":"barrel","pos":Vector2(558,532),"z":4,"scale":0.50}],
                "enemy_mult":1.45,"tree_mult":0.02,"car_mult":0.45
            },
            "0,-1":{
                "role":"казарменный двор",
                "ground":"mil_parade",
                "buildings":[
                    {"id":"building_0","archetype":"barracks","pos":Vector2(192,154),"size":Vector2(314,178),"sign":"КАЗАРМА №1","container_id":"cache_0"},
                    {"id":"building_1","archetype":"barracks","pos":Vector2(606,146),"size":Vector2(250,150),"sign":"КАЗАРМА №2","container_id":"cache_1"},
                    {"id":"building_2","archetype":"comms","pos":Vector2(620,618),"size":Vector2(148,112),"sign":"УЗЕЛ СВЯЗИ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,610),"loot":"military","name":"Шкаф дневального"}],
                "fences":[{"pos":Vector2(384,64),"length":650}],
                "lamps":[Vector2(300,286),Vector2(536,492)],
                "enemy_mult":1.30,"tree_mult":0.04,"car_mult":0.35
            },
            "1,-1":{
                "role":"технический парк",
                "ground":"mil_motorpool",
                "buildings":[
                    {"id":"building_0","archetype":"repair_bay","pos":Vector2(184,150),"size":Vector2(268,142),"sign":"АВТОПАРК","container_id":"cache_0"},
                    {"id":"building_1","archetype":"mil_store","pos":Vector2(616,144),"size":Vector2(226,122),"sign":"ЗИП","container_id":"cache_1"},
                    {"id":"building_2","archetype":"checkpoint","pos":Vector2(626,614),"size":Vector2(120,86),"sign":"ТЕХПОСТ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(178,608),"loot":"military","name":"Ремкомплект автопарка"}],
                "workbenches":[Vector2(216,548)],
                "props":[{"kind":"generator_prop","pos":Vector2(520,526),"z":4,"scale":0.56},{"kind":"gas_can","pos":Vector2(554,532),"z":3,"scale":0.46}],
                "enemy_mult":1.40,"tree_mult":0.01,"car_mult":0.75
            }
        }
    }
    ,
    "district_hospital": {
        "name":"РАЙОННАЯ БОЛЬНИЦА",
        "kind":"hospital_complex",
        "footprint":[Vector2i(0,0),Vector2i(1,0)],
        "cells":{
            "0,0":{
                "role":"приёмное отделение",
                "ground":"hospital_yard",
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(186,150),"size":Vector2(316,210),"sign":"РАЙОННАЯ БОЛЬНИЦА","container_id":"cache_0"},
                    {"id":"building_1","archetype":"pharmacy","pos":Vector2(620,144),"size":Vector2(184,126),"sign":"БОЛЬНИЧНАЯ АПТЕКА","container_id":"cache_1"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,614),"size":Vector2(126,92),"sign":"ПРИЁМНЫЙ ПОСТ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(178,606),"loot":"pharmacy","name":"Шкаф приёмного отделения"}],
                "lamps":[Vector2(320,284),Vector2(520,494)],
                "props":[{"kind":"road_barrier","pos":Vector2(408,298),"z":4,"scale":0.54},{"kind":"traffic_cone","pos":Vector2(446,308),"z":4,"scale":0.48}],
                "enemy_mult":1.12,"tree_mult":0.12,"car_mult":0.85
            },
            "1,0":{
                "role":"лечебный корпус",
                "ground":"hospital_service",
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(194,154),"size":Vector2(300,202),"sign":"ЛЕЧЕБНЫЙ КОРПУС","container_id":"cache_0"},
                    {"id":"building_1","archetype":"utility_house","pos":Vector2(618,142),"size":Vector2(142,96),"sign":"ПРАЧЕЧНАЯ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"service_shop","pos":Vector2(620,616),"size":Vector2(166,106),"sign":"ХОЗЧАСТЬ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"medical_secure","name":"Медицинский резерв"}],
                "props":[{"kind":"wheelchair","pos":Vector2(534,526),"z":3,"scale":0.52},{"kind":"cardboard_boxes","pos":Vector2(566,528),"z":3,"scale":0.46}],
                "enemy_mult":1.18,"tree_mult":0.10,"car_mult":0.65
            }
        }
    },

    "district_police": {
        "name":"РАЙОННЫЙ ОТДЕЛ ПОЛИЦИИ",
        "kind":"police_station",
        "footprint":[Vector2i(0,0),Vector2i(1,0)],
        "cells":{
            "0,0":{
                "role":"дежурная часть",
                "ground":"police_yard",
                "buildings":[
                    {"id":"building_0","archetype":"checkpoint","pos":Vector2(176,150),"size":Vector2(210,142),"sign":"ОТДЕЛ ПОЛИЦИИ","container_id":"cache_0","loot":"police"},
                    {"id":"building_1","archetype":"utility_house","pos":Vector2(620,144),"size":Vector2(144,96),"sign":"ДЕЖУРНАЯ ЧАСТЬ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"garage_row","pos":Vector2(616,612),"size":Vector2(226,112),"sign":"СЛУЖЕБНЫЙ ГАРАЖ","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"police","name":"Шкаф дежурного"}],
                "fences":[{"pos":Vector2(384,72),"length":420}],
                "props":[{"kind":"road_barrier","pos":Vector2(398,296),"z":4,"scale":0.58},{"kind":"traffic_cone","pos":Vector2(438,306),"z":4,"scale":0.48}],
                "enemy_mult":1.18,"tree_mult":0.16,"car_mult":0.95
            },
            "1,0":{
                "role":"закрытый двор",
                "ground":"police_motorpool",
                "buildings":[
                    {"id":"building_0","archetype":"service_shop","pos":Vector2(184,150),"size":Vector2(238,138),"sign":"АВТОХОЗЯЙСТВО","container_id":"cache_0"},
                    {"id":"building_1","archetype":"utility_house","pos":Vector2(618,142),"size":Vector2(130,92),"sign":"АРХИВ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"checkpoint","pos":Vector2(622,614),"size":Vector2(126,88),"sign":"ПОСТ","container_id":"cache_2","loot":"police"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"police_secure","name":"Опечатанный служебный ящик"}],
                "fences":[{"pos":Vector2(384,68),"length":520}],
                "enemy_mult":1.22,"tree_mult":0.08,"car_mult":1.00
            }
        }
    },

    "hunting_cordon": {
        "name":"ОХОТНИЧИЙ КОРДОН «СОСНЫ»",
        "kind":"hunting_cordon",
        "footprint":[Vector2i(0,0),Vector2i(1,0)],
        "cells":{
            "0,0":{
                "role":"дом смотрителя",
                "ground":"forest_cordon",
                "buildings":[
                    {"id":"building_0","archetype":"forester","pos":Vector2(176,148),"size":Vector2(198,144),"sign":"КОРДОН «СОСНЫ»","container_id":"cache_0"},
                    {"id":"building_1","archetype":"forest_shed","pos":Vector2(620,144),"size":Vector2(118,86),"sign":"СКЛАД СНАРЯЖЕНИЯ","container_id":"cache_1","loot":"hunting_secure"},
                    {"id":"building_2","archetype":"shed","pos":Vector2(620,616),"size":Vector2(104,76),"sign":"ДРОВЯНИК","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"forest_cache","name":"Охотничий ящик"}],
                "props":[{"kind":"campfire","pos":Vector2(520,526),"z":3,"scale":0.58},{"kind":"wooden_debris","pos":Vector2(558,536),"z":2,"scale":0.44}],
                "enemy_mult":0.92,"tree_mult":1.65,"car_mult":0.28
            },
            "1,0":{
                "role":"хозяйственная поляна",
                "ground":"forest_cordon",
                "buildings":[
                    {"id":"building_0","archetype":"country_house","pos":Vector2(170,152),"size":Vector2(182,132),"sign":"ДОМ ЕГЕРЯ","container_id":"cache_0"},
                    {"id":"building_1","archetype":"forest_shed","pos":Vector2(620,142),"size":Vector2(108,80),"sign":"СНАСТИ","container_id":"cache_1"},
                    {"id":"building_2","archetype":"shed","pos":Vector2(616,616),"size":Vector2(96,72),"sign":"НАВЕС","container_id":"cache_2"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,608),"loot":"hunting_secure","name":"Запас егеря"}],
                "props":[{"kind":"wooden_debris","pos":Vector2(530,532),"z":2,"scale":0.48}],
                "enemy_mult":0.88,"tree_mult":1.75,"car_mult":0.20
            }
        }
    }
    ,
    "quarantine_center_12": {
        "name":"КАРАНТИННЫЙ ЦЕНТР №12",
        "kind":"quarantine_dungeon",
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)],
        "cells":{
            "0,0":{
                "role":"внешний триаж",
                "ground":"quarantine_gate",
                "buildings":[
                    {"id":"building_0","archetype":"checkpoint","pos":Vector2(168,146),"size":Vector2(172,118),"sign":"КАРАНТИН • КПП","container_id":"cache_0","loot":"police"},
                    {"id":"building_1","archetype":"clinic","pos":Vector2(612,148),"size":Vector2(250,180),"sign":"ТРИАЖ","container_id":"cache_1","loot":"pharmacy"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(132,92),"sign":"ДЕЗПОСТ","container_id":"cache_2","loot":"pharmacy"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"pharmacy","name":"Аварийная аптечка триажа"}],
                "fences":[
                    {"pos":Vector2(176,66),"length":240},{"pos":Vector2(594,66),"length":220},
                    {"pos":Vector2(72,384),"length":300,"rotation":1.5707963}
                ],
                "props":[{"kind":"road_barrier","pos":Vector2(384,292),"z":4,"scale":0.62},{"kind":"traffic_cone","pos":Vector2(430,306),"z":4,"scale":0.50}],
                "lamps":[Vector2(310,282),Vector2(530,500)],
                "enemy_count":6,"enemy_profile":"high_perimeter","tree_mult":0.10,"car_mult":0.65
            },
            "1,0":{
                "role":"изоляционный корпус А",
                "ground":"quarantine_ward",
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(188,152),"size":Vector2(310,206),"sign":"ИЗОЛЯТОР А","container_id":"cache_0","loot":"pharmacy"},
                    {"id":"building_1","archetype":"pharmacy","pos":Vector2(620,144),"size":Vector2(178,122),"sign":"ПОСТ МЕДСЕСТРЫ","container_id":"cache_1","loot":"medical_secure"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(618,616),"size":Vector2(132,92),"sign":"САНПРОПУСКНИК","container_id":"cache_2","loot":"pharmacy"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"medical_secure","name":"Запас изолятора"}],
                "fences":[{"pos":Vector2(384,70),"length":520},{"pos":Vector2(500,384),"length":230,"rotation":1.5707963}],
                "props":[{"kind":"wheelchair","pos":Vector2(530,526),"z":3,"scale":0.52},{"kind":"cardboard_boxes","pos":Vector2(564,532),"z":3,"scale":0.46}],
                "enemy_count":8,"enemy_profile":"high_interior","tree_mult":0.04,"car_mult":0.35
            },
            "2,0":{
                "role":"лабораторный блок",
                "ground":"quarantine_lab",
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(188,152),"size":Vector2(304,204),"sign":"ЛАБОРАТОРНЫЙ БЛОК","container_id":"cache_0","loot":"medical_secure"},
                    {"id":"building_1","archetype":"utility_house","pos":Vector2(620,144),"size":Vector2(136,96),"sign":"ХОЛОДИЛЬНАЯ","container_id":"cache_1","loot":"medical_secure"},
                    {"id":"building_2","archetype":"service_shop","pos":Vector2(616,614),"size":Vector2(174,108),"sign":"ТЕХСЕКТОР","container_id":"cache_2","loot":"garage"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"medical_secure","name":"Лабораторный резерв"}],
                "fences":[{"pos":Vector2(384,70),"length":560},{"pos":Vector2(696,390),"length":310,"rotation":1.5707963}],
                "props":[{"kind":"generator_prop","pos":Vector2(520,528),"z":4,"scale":0.54},{"kind":"road_barrier","pos":Vector2(398,300),"z":4,"scale":0.58}],
                "enemy_count":9,"enemy_profile":"high_interior","tree_mult":0.03,"car_mult":0.30
            },
            "0,1":{
                "role":"служебный двор",
                "ground":"quarantine_service",
                "buildings":[
                    {"id":"building_0","archetype":"service_shop","pos":Vector2(178,150),"size":Vector2(226,136),"sign":"ТРАНСПОРТНАЯ","container_id":"cache_0","loot":"garage"},
                    {"id":"building_1","archetype":"warehouse","pos":Vector2(612,146),"size":Vector2(228,124),"sign":"ХОЗСКЛАД","container_id":"cache_1","loot":"residential"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(126,90),"sign":"ОХРАНА","container_id":"cache_2","loot":"police"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(178,606),"loot":"pharmacy","name":"Брошенный санитарный ящик"}],
                "fences":[{"pos":Vector2(176,700),"length":230},{"pos":Vector2(596,700),"length":220},{"pos":Vector2(72,384),"length":300,"rotation":1.5707963}],
                "props":[{"kind":"generator_prop","pos":Vector2(526,526),"z":4,"scale":0.54},{"kind":"barrel","pos":Vector2(560,532),"z":4,"scale":0.48}],
                "enemy_count":6,"enemy_profile":"high_perimeter","tree_mult":0.08,"car_mult":0.85
            },
            "1,1":{
                "role":"красная зона",
                "ground":"quarantine_red",
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(190,154),"size":Vector2(318,212),"sign":"КРАСНАЯ ЗОНА","container_id":"cache_0","loot":"medical_secure"},
                    {"id":"building_1","archetype":"clinic","pos":Vector2(612,146),"size":Vector2(236,172),"sign":"ИЗОЛЯТОР Б","container_id":"cache_1","loot":"medical_secure"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(130,92),"sign":"ШЛЮЗ","container_id":"cache_2","loot":"pharmacy"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"medical_secure","name":"Резерв красной зоны"}],
                "fences":[{"pos":Vector2(384,696),"length":530},{"pos":Vector2(510,384),"length":250,"rotation":1.5707963}],
                "props":[{"kind":"wheelchair","pos":Vector2(530,526),"z":3,"scale":0.50},{"kind":"road_barrier","pos":Vector2(402,300),"z":4,"scale":0.60}],
                "enemy_count":9,"enemy_profile":"high_interior","tree_mult":0.02,"car_mult":0.25
            },
            "2,1":{
                "role":"стерильный резерв",
                "ground":"quarantine_core",
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(186,152),"size":Vector2(306,206),"sign":"РЕЗЕРВ • СЕКТОР 12","container_id":"cache_0","loot":"quarantine_core"},
                    {"id":"building_1","archetype":"pharmacy","pos":Vector2(618,144),"size":Vector2(186,128),"sign":"СТЕРИЛЬНЫЙ СКЛАД","container_id":"cache_1","loot":"quarantine_core"},
                    {"id":"building_2","archetype":"checkpoint","pos":Vector2(620,616),"size":Vector2(132,92),"sign":"ВНУТРЕННИЙ ПОСТ","container_id":"cache_2","loot":"police"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(178,606),"loot":"quarantine_core","name":"Герметичный медицинский резерв"}],
                "fences":[{"pos":Vector2(384,696),"length":560},{"pos":Vector2(696,382),"length":330,"rotation":1.5707963},{"pos":Vector2(220,384),"length":230,"rotation":1.5707963}],
                "props":[{"kind":"pallets_tarp","pos":Vector2(526,526),"z":4,"scale":0.52},{"kind":"guard_booth","pos":Vector2(430,314),"z":4,"scale":0.46}],
                "enemy_count":10,"enemy_profile":"high_core","tree_mult":0.01,"car_mult":0.15
            }
        }
    },

    "reserve_arsenal_bastion": {
        "name":"РЕЗЕРВНЫЙ АРСЕНАЛ «БАСТИОН»",
        "kind":"arsenal_dungeon",
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)],
        "cells":{
            "0,0":{
                "role":"внешний КПП",
                "ground":"mil_arsenal_gate",
                "buildings":[
                    {"id":"building_0","archetype":"checkpoint","pos":Vector2(170,146),"size":Vector2(176,120),"sign":"БАСТИОН • КПП","container_id":"cache_0","loot":"military"},
                    {"id":"building_1","archetype":"barracks","pos":Vector2(606,150),"size":Vector2(242,164),"sign":"КАРАУЛ","container_id":"cache_1","loot":"military"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(126,90),"sign":"ДОСМОТР","container_id":"cache_2","loot":"military"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"military","name":"Ящик внешнего караула"}],
                "fences":[{"pos":Vector2(172,66),"length":235},{"pos":Vector2(598,66),"length":225},{"pos":Vector2(72,384),"length":310,"rotation":1.5707963}],
                "props":[{"kind":"boom_barrier","pos":Vector2(384,292),"z":5,"scale":0.62},{"kind":"hedgehogs","pos":Vector2(438,312),"z":4,"scale":0.52}],
                "enemy_count":7,"enemy_profile":"high_perimeter","tree_mult":0.01,"car_mult":0.45
            },
            "1,0":{
                "role":"казарменный сектор",
                "ground":"mil_arsenal_barracks",
                "buildings":[
                    {"id":"building_0","archetype":"barracks","pos":Vector2(190,154),"size":Vector2(314,178),"sign":"КАЗАРМА РЕЗЕРВА","container_id":"cache_0","loot":"military"},
                    {"id":"building_1","archetype":"comms","pos":Vector2(616,146),"size":Vector2(154,112),"sign":"СВЯЗЬ","container_id":"cache_1","loot":"military"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(128,90),"sign":"ДЕЖУРКА","container_id":"cache_2","loot":"military"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"military","name":"Шкаф дежурной смены"}],
                "fences":[{"pos":Vector2(384,70),"length":540},{"pos":Vector2(504,384),"length":235,"rotation":1.5707963}],
                "lamps":[Vector2(310,284),Vector2(536,496)],
                "enemy_count":8,"enemy_profile":"high_interior","tree_mult":0.01,"car_mult":0.25
            },
            "2,0":{
                "role":"логистическая рампа",
                "ground":"mil_arsenal_logistics",
                "buildings":[
                    {"id":"building_0","archetype":"mil_store","pos":Vector2(186,152),"size":Vector2(286,154),"sign":"СКЛАД БК №1","container_id":"cache_0","loot":"military_secure"},
                    {"id":"building_1","archetype":"warehouse","pos":Vector2(612,146),"size":Vector2(226,124),"sign":"ИНТЕНДАНТСКИЙ","container_id":"cache_1","loot":"military"},
                    {"id":"building_2","archetype":"checkpoint","pos":Vector2(622,614),"size":Vector2(126,90),"sign":"ПОСТ 2","container_id":"cache_2","loot":"military"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"military_secure","name":"Промежуточный армейский резерв"}],
                "fences":[{"pos":Vector2(384,70),"length":560},{"pos":Vector2(696,384),"length":320,"rotation":1.5707963}],
                "props":[{"kind":"army_truck","pos":Vector2(520,530),"z":5,"scale":0.54},{"kind":"pallets_tarp","pos":Vector2(570,532),"z":4,"scale":0.46}],
                "enemy_count":9,"enemy_profile":"high_interior","tree_mult":0.00,"car_mult":0.55
            },
            "0,1":{
                "role":"автопарк и эвакуационный двор",
                "ground":"mil_arsenal_motorpool",
                "buildings":[
                    {"id":"building_0","archetype":"repair_bay","pos":Vector2(182,150),"size":Vector2(268,142),"sign":"АВТОПАРК","container_id":"cache_0","loot":"garage"},
                    {"id":"building_1","archetype":"mil_store","pos":Vector2(616,144),"size":Vector2(222,120),"sign":"ЗИП","container_id":"cache_1","loot":"military"},
                    {"id":"building_2","archetype":"checkpoint","pos":Vector2(620,616),"size":Vector2(124,88),"sign":"ЗАПАСНОЙ ПОСТ","container_id":"cache_2","loot":"military"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(178,606),"loot":"military","name":"Ремзапас автопарка"}],
                "workbenches":[Vector2(214,548)],
                "fences":[{"pos":Vector2(172,700),"length":235},{"pos":Vector2(598,700),"length":225},{"pos":Vector2(72,384),"length":310,"rotation":1.5707963}],
                "props":[{"kind":"army_truck","pos":Vector2(520,530),"z":5,"scale":0.56},{"kind":"generator_prop","pos":Vector2(568,530),"z":4,"scale":0.50}],
                "enemy_count":7,"enemy_profile":"high_perimeter","tree_mult":0.00,"car_mult":0.85
            },
            "1,1":{
                "role":"командный двор",
                "ground":"mil_arsenal_command",
                "buildings":[
                    {"id":"building_0","archetype":"comms","pos":Vector2(184,150),"size":Vector2(174,124),"sign":"ШТАБ РЕЗЕРВА","container_id":"cache_0","loot":"military"},
                    {"id":"building_1","archetype":"barracks","pos":Vector2(610,148),"size":Vector2(248,166),"sign":"ОХРАНА ХРАНИЛИЩА","container_id":"cache_1","loot":"military"},
                    {"id":"building_2","archetype":"mil_store","pos":Vector2(620,616),"size":Vector2(192,112),"sign":"СКЛАД СНАРЯЖЕНИЯ","container_id":"cache_2","loot":"military_secure"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"military_secure","name":"Оружейная комендатуры"}],
                "fences":[{"pos":Vector2(384,696),"length":540},{"pos":Vector2(510,384),"length":245,"rotation":1.5707963}],
                "props":[{"kind":"watchtower","pos":Vector2(526,526),"z":5,"scale":0.50},{"kind":"hedgehogs","pos":Vector2(566,532),"z":4,"scale":0.48}],
                "enemy_count":9,"enemy_profile":"high_interior","tree_mult":0.00,"car_mult":0.20
            },
            "2,1":{
                "role":"внутреннее хранилище",
                "ground":"mil_arsenal_core",
                "buildings":[
                    {"id":"building_0","archetype":"mil_store","pos":Vector2(186,152),"size":Vector2(296,162),"sign":"АРСЕНАЛ • СЕКТОР А","container_id":"cache_0","loot":"arsenal_core"},
                    {"id":"building_1","archetype":"mil_store","pos":Vector2(612,146),"size":Vector2(242,134),"sign":"АРСЕНАЛ • СЕКТОР Б","container_id":"cache_1","loot":"arsenal_core"},
                    {"id":"building_2","archetype":"checkpoint","pos":Vector2(620,616),"size":Vector2(130,92),"sign":"ВНУТРЕННИЙ ПОСТ","container_id":"cache_2","loot":"military_secure"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(178,606),"loot":"arsenal_core","name":"Центральный оружейный резерв"}],
                "fences":[{"pos":Vector2(384,696),"length":570},{"pos":Vector2(696,382),"length":330,"rotation":1.5707963},{"pos":Vector2(220,384),"length":240,"rotation":1.5707963}],
                "props":[{"kind":"ammo_crate","pos":Vector2(522,526),"z":4,"scale":0.56},{"kind":"pallets_tarp","pos":Vector2(568,532),"z":4,"scale":0.50}],
                "enemy_count":11,"enemy_profile":"high_core","tree_mult":0.00,"car_mult":0.10
            }
        }
    },


    "regional_clinical_complex_4": {
        "name":"ОБЛАСТНОЙ КЛИНИЧЕСКИЙ КОМПЛЕКС №4",
        "kind":"medical_endgame_dungeon",
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)],
        "entry_offset":Vector2i(0,0),
        "exit_offset":Vector2i(2,0),
        "core_offset":Vector2i(2,1),
        "encounter_flow":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,0),Vector2i(2,1)],
        "cells":{
            "0,0":{
                "role":"приёмное отделение и главный вход",
                "ground":"hospital_arrival",
                "flow_stage":0,
                "access_points":[{"kind":"entry","pos":Vector2(78,384),"label":"ГЛАВНЫЙ ВХОД"}],
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(190,154),"size":Vector2(318,210),"sign":"ПРИЁМНОЕ ОТДЕЛЕНИЕ","container_id":"cache_0","loot":"pharmacy"},
                    {"id":"building_1","archetype":"pharmacy","pos":Vector2(620,146),"size":Vector2(184,126),"sign":"ПОСТ НЕОТЛОЖНОЙ ПОМОЩИ","container_id":"cache_1","loot":"medical_secure"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(132,92),"sign":"ОХРАНА ПРИЁМА","container_id":"cache_2","loot":"police"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(178,606),"loot":"pharmacy","name":"Аварийный комплект приёмного"}],
                "fences":[{"pos":Vector2(170,70),"length":220},{"pos":Vector2(590,70),"length":230},{"pos":Vector2(704,390),"length":290,"rotation":1.5707963}],
                "props":[{"kind":"stretcher","pos":Vector2(364,302),"z":4,"scale":0.56},{"kind":"wheelchair","pos":Vector2(420,306),"z":4,"scale":0.50},{"kind":"road_barrier","pos":Vector2(500,520),"z":4,"scale":0.55}],
                "lamps":[Vector2(308,284),Vector2(530,500)],
                "enemy_count":7,"enemy_profile":"clinical_perimeter","tree_mult":0.05,"car_mult":0.38
            },
            "1,0":{
                "role":"диагностический двор",
                "ground":"hospital_diagnostics",
                "flow_stage":1,
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(188,152),"size":Vector2(320,210),"sign":"ДИАГНОСТИКА","container_id":"cache_0","loot":"medical_secure"},
                    {"id":"building_1","archetype":"clinic","pos":Vector2(606,150),"size":Vector2(250,184),"sign":"ЛУЧЕВАЯ ДИАГНОСТИКА","container_id":"cache_1","loot":"medical_secure"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(134,94),"sign":"АРХИВ","container_id":"cache_2","loot":"residential"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"medical_secure","name":"Диагностический резерв"}],
                "fences":[{"pos":Vector2(384,70),"length":548},{"pos":Vector2(510,392),"length":230,"rotation":1.5707963}],
                "props":[{"kind":"wheelchair","pos":Vector2(526,526),"z":4,"scale":0.48},{"kind":"med_cart","pos":Vector2(566,528),"z":4,"scale":0.48},{"kind":"cardboard_boxes","pos":Vector2(596,536),"z":3,"scale":0.44}],
                "enemy_count":9,"enemy_profile":"clinical_interior","tree_mult":0.03,"car_mult":0.24
            },
            "2,0":{
                "role":"служебный двор и эвакуационный выезд",
                "ground":"hospital_service_exit",
                "flow_stage":2,
                "access_points":[{"kind":"exit","pos":Vector2(690,384),"label":"ЭВАКУАЦИОННЫЙ ВЫЕЗД"}],
                "buildings":[
                    {"id":"building_0","archetype":"service_shop","pos":Vector2(180,150),"size":Vector2(232,142),"sign":"САНТРАНСПОРТ","container_id":"cache_0","loot":"garage"},
                    {"id":"building_1","archetype":"warehouse","pos":Vector2(606,146),"size":Vector2(230,126),"sign":"КИСЛОРОДНЫЙ СКЛАД","container_id":"cache_1","loot":"medical_secure"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(132,92),"sign":"ДИСПЕТЧЕРСКАЯ","container_id":"cache_2","loot":"pharmacy"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(178,606),"loot":"medical_secure","name":"Запас эвакуационной бригады"}],
                "workbenches":[Vector2(214,548)],
                "fences":[{"pos":Vector2(384,70),"length":560},{"pos":Vector2(72,386),"length":310,"rotation":1.5707963},{"pos":Vector2(694,188),"length":190,"rotation":1.5707963},{"pos":Vector2(694,592),"length":190,"rotation":1.5707963}],
                "props":[{"kind":"generator_prop","pos":Vector2(520,526),"z":4,"scale":0.52},{"kind":"road_barrier","pos":Vector2(468,308),"z":4,"scale":0.56},{"kind":"traffic_cone","pos":Vector2(506,314),"z":4,"scale":0.48}],
                "enemy_count":8,"enemy_profile":"clinical_perimeter","tree_mult":0.02,"car_mult":0.72
            },
            "0,1":{
                "role":"палатные корпуса",
                "ground":"hospital_wards",
                "flow_stage":1,
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(188,152),"size":Vector2(324,214),"sign":"ПАЛАТНЫЙ КОРПУС А","container_id":"cache_0","loot":"pharmacy"},
                    {"id":"building_1","archetype":"clinic","pos":Vector2(604,150),"size":Vector2(252,184),"sign":"ПАЛАТНЫЙ КОРПУС Б","container_id":"cache_1","loot":"medical_secure"},
                    {"id":"building_2","archetype":"pharmacy","pos":Vector2(620,616),"size":Vector2(178,122),"sign":"ПОСТ МЕДСЕСТРЫ","container_id":"cache_2","loot":"medical_secure"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(178,606),"loot":"pharmacy","name":"Палатный запас"}],
                "fences":[{"pos":Vector2(170,696),"length":222},{"pos":Vector2(590,696),"length":234},{"pos":Vector2(72,386),"length":300,"rotation":1.5707963}],
                "props":[{"kind":"stretcher","pos":Vector2(520,528),"z":4,"scale":0.54},{"kind":"wheelchair","pos":Vector2(562,528),"z":4,"scale":0.48},{"kind":"blood_smear","pos":Vector2(430,306),"z":1,"scale":0.48}],
                "enemy_count":8,"enemy_profile":"clinical_interior","tree_mult":0.04,"car_mult":0.16
            },
            "1,1":{
                "role":"изоляция и переход к операционному блоку",
                "ground":"hospital_isolation",
                "flow_stage":2,
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(190,154),"size":Vector2(320,212),"sign":"ИЗОЛЯЦИОННЫЙ КОРПУС","container_id":"cache_0","loot":"medical_secure"},
                    {"id":"building_1","archetype":"clinic","pos":Vector2(608,148),"size":Vector2(246,180),"sign":"ПОСЛЕОПЕРАЦИОННЫЙ","container_id":"cache_1","loot":"medical_secure"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(132,92),"sign":"САНШЛЮЗ","container_id":"cache_2","loot":"pharmacy"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(180,606),"loot":"medical_secure","name":"Резерв изолятора"}],
                "fences":[{"pos":Vector2(384,696),"length":540},{"pos":Vector2(510,388),"length":245,"rotation":1.5707963},{"pos":Vector2(696,384),"length":316,"rotation":1.5707963}],
                "props":[{"kind":"medical_screen","pos":Vector2(526,526),"z":4,"scale":0.54},{"kind":"med_supply_stack","pos":Vector2(566,532),"z":4,"scale":0.48},{"kind":"road_barrier","pos":Vector2(406,306),"z":4,"scale":0.55}],
                "enemy_count":10,"enemy_profile":"clinical_interior","tree_mult":0.01,"car_mult":0.10
            },
            "2,1":{
                "role":"операционный блок и хирургический резерв",
                "ground":"hospital_surgical_core",
                "flow_stage":3,
                "buildings":[
                    {"id":"building_0","archetype":"clinic","pos":Vector2(188,152),"size":Vector2(322,214),"sign":"ОПЕРАЦИОННЫЙ БЛОК","container_id":"cache_0","loot":"clinical_core"},
                    {"id":"building_1","archetype":"pharmacy","pos":Vector2(616,146),"size":Vector2(190,132),"sign":"СТЕРИЛЬНЫЙ РЕЗЕРВ","container_id":"cache_1","loot":"clinical_core"},
                    {"id":"building_2","archetype":"clinic","pos":Vector2(604,616),"size":Vector2(246,176),"sign":"РЕАНИМАЦИЯ","container_id":"cache_2","loot":"medical_secure"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"clinical_core","name":"Хирургический аварийный резерв"}],
                "fences":[{"pos":Vector2(384,696),"length":566},{"pos":Vector2(696,382),"length":330,"rotation":1.5707963},{"pos":Vector2(218,384),"length":236,"rotation":1.5707963}],
                "props":[{"kind":"med_supply_stack","pos":Vector2(520,438),"z":4,"scale":0.52},{"kind":"large_med_cabinet","pos":Vector2(568,438),"z":4,"scale":0.48},{"kind":"stretcher","pos":Vector2(430,312),"z":4,"scale":0.52}],
                "enemy_count":12,"enemy_profile":"clinical_core","tree_mult":0.01,"car_mult":0.08
            }
        }
    },

    "underground_object_vector": {
        "name":"ПОДЗЕМНЫЙ ОБЪЕКТ «ВЕКТОР»",
        "kind":"underground_endgame_dungeon",
        "footprint":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,2),Vector2i(1,2)],
        "entry_offset":Vector2i(0,0),
        "exit_offset":Vector2i(0,2),
        "core_offset":Vector2i(1,2),
        "encounter_flow":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,2),Vector2i(1,2)],
        "cells":{
            "0,0":{
                "role":"шахта доступа и гермошлюз",
                "ground":"vector_access",
                "flow_stage":0,
                "access_points":[{"kind":"entry","pos":Vector2(384,74),"label":"ШАХТА ДОСТУПА"}],
                "buildings":[
                    {"id":"building_0","archetype":"checkpoint","pos":Vector2(184,150),"size":Vector2(154,108),"sign":"ГЕРМОШЛЮЗ","container_id":"cache_0","loot":"industrial_secure"},
                    {"id":"building_1","archetype":"utility_house","pos":Vector2(606,148),"size":Vector2(150,106),"sign":"ПОСТ ДОПУСКА","container_id":"cache_1","loot":"industrial"},
                    {"id":"building_2","archetype":"warehouse","pos":Vector2(612,616),"size":Vector2(220,126),"sign":"АВАРИЙНЫЙ ЗАПАС","container_id":"cache_2","loot":"industrial_secure"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"industrial","name":"Инструменты входной группы"}],
                "fences":[{"pos":Vector2(72,384),"length":312,"rotation":1.5707963},{"pos":Vector2(696,384),"length":312,"rotation":1.5707963},{"pos":Vector2(384,326),"length":244}],
                "props":[{"kind":"generator_prop","pos":Vector2(504,520),"z":4,"scale":0.52},{"kind":"road_barrier","pos":Vector2(390,304),"z":4,"scale":0.54},{"kind":"barrel","pos":Vector2(548,526),"z":3,"scale":0.48}],
                "lamps":[Vector2(306,292),Vector2(520,488)],
                "enemy_count":7,"enemy_profile":"vector_access","tree_mult":0.00,"car_mult":0.00
            },
            "1,0":{
                "role":"контрольный коридор и узел охраны",
                "ground":"vector_security",
                "flow_stage":1,
                "buildings":[
                    {"id":"building_0","archetype":"barracks","pos":Vector2(190,152),"size":Vector2(238,164),"sign":"КАРАУЛЬНОЕ ПОМЕЩЕНИЕ","container_id":"cache_0","loot":"military"},
                    {"id":"building_1","archetype":"comms","pos":Vector2(610,146),"size":Vector2(166,124),"sign":"СВЯЗЬ И КОНТРОЛЬ","container_id":"cache_1","loot":"military_secure"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(618,616),"size":Vector2(142,96),"sign":"ТЕХШКАФ","container_id":"cache_2","loot":"industrial_secure"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(174,606),"loot":"military","name":"Оставленный пост охраны"}],
                "fences":[{"pos":Vector2(384,70),"length":552},{"pos":Vector2(382,384),"length":300,"rotation":1.5707963},{"pos":Vector2(696,384),"length":310,"rotation":1.5707963}],
                "props":[{"kind":"sandbags","pos":Vector2(514,520),"z":4,"scale":0.58},{"kind":"ammo_crate","pos":Vector2(558,526),"z":4,"scale":0.50},{"kind":"rubble","pos":Vector2(420,308),"z":2,"scale":0.48}],
                "enemy_count":10,"enemy_profile":"vector_tunnels","tree_mult":0.00,"car_mult":0.00
            },
            "0,1":{
                "role":"энергоблок и насосная",
                "ground":"vector_power",
                "flow_stage":1,
                "buildings":[
                    {"id":"building_0","archetype":"repair_bay","pos":Vector2(188,152),"size":Vector2(226,150),"sign":"ЭНЕРГОБЛОК","container_id":"cache_0","loot":"industrial_secure"},
                    {"id":"building_1","archetype":"workshop","pos":Vector2(608,150),"size":Vector2(238,166),"sign":"НАСОСНАЯ","container_id":"cache_1","loot":"industrial_secure"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(146,100),"sign":"РЕЗЕРВ ПИТАНИЯ","container_id":"cache_2","loot":"industrial"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"industrial_secure","name":"Ремонтный комплект энергослужбы"}],
                "workbenches":[Vector2(214,536)],
                "fences":[{"pos":Vector2(72,384),"length":306,"rotation":1.5707963},{"pos":Vector2(510,384),"length":242,"rotation":1.5707963},{"pos":Vector2(384,696),"length":544}],
                "props":[{"kind":"generator_prop","pos":Vector2(518,522),"z":4,"scale":0.54},{"kind":"barrel","pos":Vector2(558,530),"z":3,"scale":0.50},{"kind":"pallets_tarp","pos":Vector2(590,528),"z":3,"scale":0.46}],
                "enemy_count":9,"enemy_profile":"vector_tunnels","tree_mult":0.00,"car_mult":0.00
            },
            "1,1":{
                "role":"командный сектор и серверный коридор",
                "ground":"vector_command",
                "flow_stage":2,
                "buildings":[
                    {"id":"building_0","archetype":"factory_admin","pos":Vector2(186,150),"size":Vector2(198,154),"sign":"КОМАНДНЫЙ ПУНКТ","container_id":"cache_0","loot":"military_secure"},
                    {"id":"building_1","archetype":"comms","pos":Vector2(606,146),"size":Vector2(174,136),"sign":"СЕРВЕРНАЯ","container_id":"cache_1","loot":"industrial_secure"},
                    {"id":"building_2","archetype":"mil_store","pos":Vector2(610,616),"size":Vector2(224,132),"sign":"РЕЗЕРВ СВЯЗИ","container_id":"cache_2","loot":"military"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"industrial_secure","name":"Комплект аварийной связи"}],
                "fences":[{"pos":Vector2(384,70),"length":548},{"pos":Vector2(384,696),"length":548},{"pos":Vector2(510,384),"length":248,"rotation":1.5707963}],
                "props":[{"kind":"supply_crate","pos":Vector2(518,522),"z":4,"scale":0.52},{"kind":"rubble","pos":Vector2(558,526),"z":2,"scale":0.46},{"kind":"road_barrier","pos":Vector2(420,308),"z":4,"scale":0.52}],
                "enemy_count":11,"enemy_profile":"vector_tunnels","tree_mult":0.00,"car_mult":0.00
            },
            "0,2":{
                "role":"сервисный тоннель и аварийный выход",
                "ground":"vector_escape",
                "flow_stage":2,
                "access_points":[{"kind":"exit","pos":Vector2(74,384),"label":"СЕРВИСНЫЙ ТОННЕЛЬ"}],
                "buildings":[
                    {"id":"building_0","archetype":"service_shop","pos":Vector2(184,150),"size":Vector2(222,148),"sign":"СЕРВИСНЫЙ ШЛЮЗ","container_id":"cache_0","loot":"industrial"},
                    {"id":"building_1","archetype":"warehouse","pos":Vector2(606,146),"size":Vector2(226,132),"sign":"АВАРИЙНЫЙ СКЛАД","container_id":"cache_1","loot":"industrial_secure"},
                    {"id":"building_2","archetype":"utility_house","pos":Vector2(620,616),"size":Vector2(146,98),"sign":"ВЕНТУЗЕЛ","container_id":"cache_2","loot":"industrial"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"industrial_secure","name":"Запас сервисной смены"}],
                "fences":[{"pos":Vector2(384,70),"length":548},{"pos":Vector2(696,384),"length":306,"rotation":1.5707963},{"pos":Vector2(382,430),"length":230,"rotation":1.5707963}],
                "props":[{"kind":"generator_prop","pos":Vector2(518,520),"z":4,"scale":0.50},{"kind":"gas_can","pos":Vector2(556,526),"z":3,"scale":0.48},{"kind":"rubble","pos":Vector2(430,308),"z":2,"scale":0.46}],
                "enemy_count":8,"enemy_profile":"vector_access","tree_mult":0.00,"car_mult":0.00
            },
            "1,2":{
                "role":"глубокое инженерное ядро",
                "ground":"vector_core",
                "flow_stage":3,
                "buildings":[
                    {"id":"building_0","archetype":"workshop","pos":Vector2(188,152),"size":Vector2(238,168),"sign":"ИНЖЕНЕРНОЕ ЯДРО","container_id":"cache_0","loot":"vector_core"},
                    {"id":"building_1","archetype":"mil_store","pos":Vector2(608,146),"size":Vector2(230,142),"sign":"АВТОНОМНЫЙ РЕЗЕРВ","container_id":"cache_1","loot":"vector_core"},
                    {"id":"building_2","archetype":"comms","pos":Vector2(620,616),"size":Vector2(170,132),"sign":"КОНТРОЛЬ СИСТЕМ","container_id":"cache_2","loot":"industrial_secure"}
                ],
                "loose_containers":[{"id":"cache_3","pos":Vector2(176,606),"loot":"vector_core","name":"Аварийный инженерный резерв"}],
                "workbenches":[Vector2(214,536)],
                "fences":[{"pos":Vector2(384,70),"length":552},{"pos":Vector2(384,696),"length":552},{"pos":Vector2(510,384),"length":250,"rotation":1.5707963},{"pos":Vector2(696,384),"length":310,"rotation":1.5707963}],
                "props":[{"kind":"generator_prop","pos":Vector2(520,522),"z":4,"scale":0.56},{"kind":"supply_crate","pos":Vector2(562,526),"z":4,"scale":0.52},{"kind":"pallets_tarp","pos":Vector2(598,528),"z":3,"scale":0.46}],
                "enemy_count":13,"enemy_profile":"vector_core","tree_mult":0.00,"car_mult":0.00
            }
        }
    }

}

static func _key(offset:Vector2i) -> String:
    return "%d,%d" % [offset.x,offset.y]

static func compound(poi_id:String) -> Dictionary:
    if FactionSettlementCatalog.has(poi_id):
        return FactionSettlementCatalog.compound(poi_id)
    return COMPOUNDS.get(poi_id,{}).duplicate(true)

static func has_compound(poi_id:String) -> bool:
    return COMPOUNDS.has(poi_id) or FactionSettlementCatalog.has(poi_id)

static func cell(poi_id:String,offset:Vector2i) -> Dictionary:
    if FactionSettlementCatalog.has(poi_id):
        return FactionSettlementCatalog.cell(poi_id,offset)
    var compound_data = COMPOUNDS.get(poi_id,{})
    if compound_data.is_empty():
        return {}
    return compound_data.get("cells",{}).get(_key(offset),{}).duplicate(true)

static func footprint(poi_id:String) -> Array:
    if FactionSettlementCatalog.has(poi_id):
        return FactionSettlementCatalog.footprint(poi_id)
    return COMPOUNDS.get(poi_id,{}).get("footprint",[]).duplicate(true)
