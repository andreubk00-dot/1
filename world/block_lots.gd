extends RefCounted
# dev79: what fills a city block that holds no building. Every sector used to
# repeat the same picture - a crossroads and four houses, or a bare plot where
# a house did not come up. Now a free block (and, in new territory, now and
# then a block that would have held a house) becomes a square, a playground, a
# car park, a market, a ruin, a building site, a camp, a yard, a dump, an army
# depot or a kitchen garden, by the district.
#
# A plan is laid out in the block's own coordinates: u runs from the block's
# outer edge (0) to the north-south street (1), v from the outer edge (0) to the
# east-west street (1) - main mirrors them into the block's corner of the sector.
# Items:
#   {"surface":kind, "rect":[u,v,w,h], "edge":"kerb"|"soft"}   ground patch
#   {"piece":kind, "at":[u,v], "s":scale, "solid":[w,h]}       settlement piece
#   {"street":kind, "at":[u,v]}                                bench, planter...
#   {"prop":kind, "at":[u,v], "s":scale}                       world prop
#   {"tree":[u,v], "s":scale}
#   {"car":[u,v], "turn":true|false}                           parked car
#   {"lamp":[u,v]}
#   {"fence":[u,v], "len":px, "rot":"h"|"v"}
#   {"draw":kind, "at":[u,v]}                                  drawn in code
#   {"cache":[u,v], "name":text, "loot":table}                 a searchable stash
# An item with "opt":p appears with that chance.

const FAMILY_LOTS = {
    "city":[["square",4],["playground",4],["parking",4],["market",3],["ruin",3],["construction",3],["camp",2]],
    "industrial":[["yard",4],["parking",3],["ruin",3],["construction",3],["dump",3]],
    "military":[["depot",5],["parking",2],["ruin",2],["camp",2]],
    "rural":[["garden",5],["ruin",2],["camp",2],["dump",1]]
}

# chance that a block a house would stand on is a lot instead (new territory
# only, never more than one per sector), and that an empty block gets one
const CONVERT_CHANCE = {"city":0.09,"industrial":0.09,"military":0.08,"rural":0.05}
const FILL_EMPTY_CHANCE = {"city":0.92,"industrial":0.85,"military":0.8,"rural":0.6}

# plans that read the same turned a quarter (a car park's bays do not)
const TURNABLE = ["ruin","construction","camp","yard","dump","depot","garden","market"]

const LABELS = {
    "square":"СКВЕР","playground":"ДЕТСКАЯ ПЛОЩАДКА","parking":"СТОЯНКА","market":"СТИХИЙНЫЙ РЫНОК",
    "ruin":"РУИНЫ","construction":"СТРОЙКА","camp":"БРОШЕННЫЙ ЛАГЕРЬ","yard":"СКЛАДСКОЙ ДВОР",
    "dump":"СВАЛКА","depot":"ПОЛЕВОЙ СКЛАД","garden":"ОГОРОДЫ"
}

const PLANS = {
    "square":[
        {"surface":"paving","rect":[0.40,0.0,0.20,1.11],"edge":"kerb"},
        {"surface":"paving","rect":[0.0,0.40,1.11,0.20],"edge":"kerb"},
        {"surface":"paving","rect":[0.30,0.30,0.40,0.40],"edge":"kerb"},
        {"draw":"monument","at":[0.5,0.5]},
        {"street":"bench","at":[0.24,0.36]},
        {"street":"bench","at":[0.76,0.36]},
        {"street":"bench","at":[0.24,0.66],"opt":0.7},
        {"street":"planter","at":[0.36,0.26]},
        {"street":"planter","at":[0.64,0.26],"opt":0.7},
        {"tree":[0.16,0.16],"s":1.0},
        {"tree":[0.84,0.14],"s":0.9},
        {"tree":[0.14,0.84],"s":1.05},
        {"tree":[0.86,0.86],"s":0.95,"opt":0.7},
        {"lamp":[0.66,0.66]},
        {"prop":"trash_bin","at":[0.60,0.80],"s":0.5,"opt":0.6},
        {"piece":"poster_board","at":[0.30,0.80],"s":0.42,"opt":0.5}
    ],
    "playground":[
        {"surface":"sand","rect":[0.14,0.12,0.62,0.56],"edge":"soft"},
        {"surface":"path","rect":[0.0,0.74,1.11,0.12],"edge":"soft"},
        {"piece":"swing_set","at":[0.32,0.34],"s":0.48,"solid":[36,8]},
        {"draw":"slide","at":[0.62,0.30]},
        {"draw":"sandbox","at":[0.34,0.58]},
        {"draw":"carousel","at":[0.62,0.56],"opt":0.75},
        {"street":"bench","at":[0.18,0.82]},
        {"street":"bench","at":[0.54,0.82],"opt":0.7},
        {"tree":[0.88,0.16],"s":1.0},
        {"tree":[0.86,0.58],"s":0.9,"opt":0.7},
        {"tree":[0.08,0.08],"s":0.85,"opt":0.6},
        {"piece":"laundry_line","at":[0.80,0.94],"s":0.42,"opt":0.6},
        {"piece":"bicycle","at":[0.80,0.38],"s":0.42,"opt":0.4},
        {"prop":"trash_bin","at":[0.42,0.92],"s":0.48,"opt":0.6}
    ],
    "parking":[
        {"surface":"asphalt","rect":[0.04,0.06,0.92,0.86],"edge":"kerb"},
        {"draw":"bays","at":[0.5,0.30]},
        {"draw":"bays","at":[0.5,0.72]},
        {"car":[0.20,0.30],"turn":true},
        {"car":[0.46,0.30],"turn":true,"opt":0.6},
        {"car":[0.72,0.30],"turn":true,"opt":0.5},
        {"car":[0.32,0.72],"turn":true,"opt":0.7},
        {"car":[0.60,0.72],"turn":true,"opt":0.5},
        {"piece":"kiosk","at":[0.88,0.92],"s":0.42,"solid":[26,10]},
        {"prop":"road_barrier","at":[0.92,0.52],"s":0.56},
        {"prop":"traffic_cone","at":[0.86,0.60],"s":0.48,"opt":0.6},
        {"cache":[0.24,0.48],"name":"Багажник брошенной машины","loot":"garage"}
    ],
    "market":[
        {"surface":"paving","rect":[0.06,0.10,0.88,0.80],"edge":"kerb"},
        {"piece":"market_stall","at":[0.24,0.30],"s":0.46,"solid":[40,10]},
        {"piece":"market_stall_b","at":[0.56,0.30],"s":0.46,"solid":[40,10]},
        {"piece":"kiosk","at":[0.84,0.32],"s":0.44,"solid":[26,10]},
        {"piece":"market_stall","at":[0.36,0.66],"s":0.46,"solid":[40,10],"opt":0.7},
        {"piece":"cart","at":[0.70,0.66],"s":0.42,"opt":0.7},
        {"prop":"cardboard_boxes","at":[0.14,0.52],"s":0.48},
        {"prop":"trash_bag","at":[0.88,0.62],"s":0.46,"opt":0.7},
        {"prop":"crate","at":[0.52,0.52],"s":0.46,"opt":0.6},
        {"prop":"shopping_cart","at":[0.22,0.80],"s":0.46,"opt":0.5},
        {"cache":[0.62,0.48],"name":"Ларёк","loot":"grocery"}
    ],
    "ruin":[
        {"surface":"slab","rect":[0.10,0.10,0.74,0.66],"edge":"kerb"},
        {"draw":"wall_h","at":[0.46,0.12]},
        {"draw":"wall_v","at":[0.12,0.38]},
        {"draw":"wall_stub","at":[0.80,0.20]},
        {"piece":"rubble_pile","at":[0.36,0.38],"s":0.5,"solid":[30,8]},
        {"piece":"rubble_pile","at":[0.66,0.56],"s":0.44,"solid":[26,8],"opt":0.7},
        {"piece":"junk_pile","at":[0.26,0.68],"s":0.44,"opt":0.7},
        {"prop":"wooden_debris","at":[0.56,0.34],"s":0.5},
        {"prop":"old_mattress","at":[0.46,0.66],"s":0.46,"opt":0.6},
        {"piece":"dead_tree","at":[0.90,0.84],"s":0.42,"opt":0.7},
        {"piece":"burnt_car","at":[0.62,0.88],"s":0.46,"solid":[40,12],"opt":0.4},
        {"cache":[0.50,0.48],"name":"Завал","loot":"residential"}
    ],
    "construction":[
        {"surface":"gravel","rect":[0.04,0.04,0.92,0.88],"edge":"soft"},
        {"fence":[0.5,0.94],"len":180,"rot":"h"},
        {"piece":"jib_crane","at":[0.24,0.30],"s":0.58,"solid":[22,10]},
        {"draw":"slabs","at":[0.58,0.24]},
        {"draw":"pipes","at":[0.78,0.52]},
        {"draw":"sandpile","at":[0.40,0.62]},
        {"piece":"container_shop","at":[0.80,0.80],"s":0.44,"solid":[44,12]},
        {"piece":"oil_drums","at":[0.18,0.70],"s":0.42,"opt":0.7},
        {"prop":"supply_crate","at":[0.56,0.46],"s":0.48,"opt":0.6},
        {"piece":"wheelbarrow","at":[0.30,0.80],"s":0.42,"opt":0.6},
        {"cache":[0.66,0.72],"name":"Бытовка строителей","loot":"industrial"}
    ],
    "camp":[
        {"surface":"path","rect":[0.12,0.14,0.72,0.66],"edge":"soft"},
        {"piece":"army_tent","at":[0.28,0.32],"s":0.5,"solid":[40,12]},
        {"piece":"tarp_shelter","at":[0.66,0.30],"s":0.46,"solid":[40,10]},
        {"piece":"fire_barrel","at":[0.48,0.56],"s":0.42,"solid":[10,6]},
        {"piece":"laundry_line","at":[0.70,0.70],"s":0.42,"opt":0.7},
        {"piece":"junk_pile","at":[0.22,0.72],"s":0.42,"opt":0.7},
        {"prop":"old_mattress","at":[0.40,0.74],"s":0.46,"opt":0.6},
        {"piece":"graves","at":[0.86,0.88],"s":0.4,"opt":0.35},
        {"cache":[0.30,0.52],"name":"Палатка","loot":"residential"}
    ],
    "yard":[
        {"surface":"gravel","rect":[0.04,0.06,0.92,0.86],"edge":"soft"},
        {"piece":"container_shop","at":[0.26,0.28],"s":0.48,"solid":[46,12]},
        {"piece":"scrap_heap","at":[0.66,0.30],"s":0.48,"solid":[40,10]},
        {"piece":"oil_drums","at":[0.84,0.56],"s":0.42},
        {"piece":"car_on_blocks","at":[0.34,0.66],"s":0.48,"solid":[40,12],"opt":0.7},
        {"piece":"tire_wall","at":[0.70,0.80],"s":0.44,"opt":0.7},
        {"prop":"barrel","at":[0.14,0.56],"s":0.5},
        {"prop":"crate","at":[0.56,0.56],"s":0.48,"opt":0.7},
        {"draw":"pipes","at":[0.18,0.86],"opt":0.5},
        {"cache":[0.48,0.44],"name":"Ящик с запчастями","loot":"garage"}
    ],
    "dump":[
        {"surface":"path","rect":[0.08,0.08,0.84,0.80],"edge":"soft"},
        {"piece":"junk_pile","at":[0.28,0.30],"s":0.5},
        {"piece":"scrap_heap","at":[0.64,0.34],"s":0.48,"solid":[40,10]},
        {"piece":"tire_wall","at":[0.36,0.66],"s":0.44},
        {"piece":"burnt_car","at":[0.70,0.70],"s":0.46,"solid":[40,12],"opt":0.7},
        {"piece":"rubble_pile","at":[0.18,0.84],"s":0.42,"opt":0.6},
        {"prop":"trash_bag","at":[0.50,0.50],"s":0.48},
        {"prop":"old_fridge","at":[0.86,0.46],"s":0.44,"opt":0.6},
        {"cache":[0.46,0.80],"name":"Куча хлама","loot":"garage"}
    ],
    "depot":[
        {"surface":"gravel","rect":[0.06,0.06,0.88,0.84],"edge":"soft"},
        {"piece":"hesco_row","at":[0.50,0.12],"s":0.5,"solid":[70,10]},
        {"piece":"army_tent","at":[0.28,0.40],"s":0.5,"solid":[40,12]},
        {"piece":"sandbag_nest","at":[0.74,0.42],"s":0.46,"solid":[34,10]},
        {"piece":"jersey_blocks","at":[0.50,0.82],"s":0.46,"solid":[56,8]},
        {"prop":"ammo_crate","at":[0.52,0.52],"s":0.5},
        {"prop":"supply_crate","at":[0.20,0.66],"s":0.5,"opt":0.7},
        {"piece":"oil_drums","at":[0.82,0.66],"s":0.42,"opt":0.6},
        {"cache":[0.40,0.60],"name":"Армейский ящик","loot":"military"}
    ],
    "garden":[
        {"surface":"path","rect":[0.46,0.0,0.10,1.0],"edge":"soft"},
        {"piece":"garden_beds","at":[0.24,0.28],"s":0.5},
        {"piece":"garden_beds","at":[0.76,0.28],"s":0.5},
        {"piece":"garden_beds","at":[0.24,0.64],"s":0.5,"opt":0.8},
        {"piece":"rain_tank","at":[0.80,0.66],"s":0.42,"solid":[18,8]},
        {"piece":"firewood_rack","at":[0.14,0.88],"s":0.42,"opt":0.7},
        {"piece":"wheelbarrow","at":[0.62,0.86],"s":0.42,"opt":0.6},
        {"piece":"chicken_coop","at":[0.82,0.90],"s":0.42,"solid":[30,10],"opt":0.5},
        {"tree":[0.06,0.10],"s":0.9,"opt":0.7},
        {"cache":[0.40,0.46],"name":"Погреб","loot":"rural"}
    ]
}

static func _h(coord:Vector2i,slot:int,salt:int) -> int:
    return abs(int(coord.x) * 73856093 ^ int(coord.y) * 19349663 ^ (slot + 1) * 83492791 ^ salt * 2654435761) % 1000003

static func roll(coord:Vector2i,slot:int,salt:int) -> float:
    return float(_h(coord,slot,salt) % 10000) / 10000.0

static func pick(family:String,coord:Vector2i,slot:int) -> String:
    var table = FAMILY_LOTS.get(family,[])
    if table.is_empty():
        return ""
    var total = 0
    for e in table:
        total += int(e[1])
    var r = _h(coord,slot,7) % total
    for e in table:
        r -= int(e[1])
        if r < 0:
            return str(e[0])
    return str(table[0][0])

static func converts(family:String,coord:Vector2i,slot:int) -> bool:
    return roll(coord,slot,11) < float(CONVERT_CHANCE.get(family,0.0))

static func fills_empty(family:String,coord:Vector2i,slot:int) -> bool:
    return roll(coord,slot,13) < float(FILL_EMPTY_CHANCE.get(family,0.0))

static func plan(kind:String) -> Array:
    return PLANS.get(kind,[])
