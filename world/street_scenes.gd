extends RefCounted
# dev79: what happened on a street. The sector's four street arms (the stretch
# between the crossing and the sector edge) all used to be the same clear run of
# asphalt. Now and then an arm holds a jam of abandoned cars, a roadblock, a
# collapsed carriageway or a street the weeds are taking back; out of town a
# track holds a fallen tree or a car stuck in the mud.
#
# Positions are in the arm's own frame: "at":[along, across] - along runs from
# the crossing (0) to the sector edge (1), across from one kerb (-1) to the
# other (1). The pavements stay open, so no arm is ever closed to a survivor on
# foot. Items as in block_lots.gd ("car" takes "turn" in degrees from the
# street's own direction), plus {"veg":kind,"at":[a,c]} for a bush or weeds.

const FAMILY_SCENES = {
    "city":[["jam",4],["roadblock",3],["crater",3],["overgrown",3]],
    "industrial":[["jam",3],["roadblock",2],["crater",3],["overgrown",3]],
    "military":[["roadblock",5],["jam",2],["crater",2]],
    "rural":[["fallen_tree",4],["stuck_car",3],["overgrown",2]],
    "woodland":[["fallen_tree",5],["stuck_car",2]]
}
const ARM_CHANCE = {"city":0.13,"industrial":0.13,"military":0.15,"rural":0.12,"woodland":0.12}

const LABELS = {"jam":"ПРОБКА","roadblock":"БЛОКПОСТ","crater":"ПРОВАЛ","overgrown":"ЗАРОСШАЯ УЛИЦА",
    "fallen_tree":"ПОВАЛЕННОЕ ДЕРЕВО","stuck_car":"ЗАСТРЯВШАЯ МАШИНА"}

# scenes that need the arm to run north-south (sprites that lie across it)
const VERTICAL_ONLY = ["roadblock"]

const PLANS = {
    "jam":[
        {"car":[0.10,-0.45],"turn":-6},
        {"car":[0.46,-0.40],"turn":4},
        {"car":[0.82,-0.48],"turn":-3,"opt":0.7},
        {"car":[0.28,0.42],"turn":178,"opt":0.6},
        {"piece":"burnt_car","at":[0.70,0.40],"s":0.48,"solid":[42,12],"opt":0.6},
        {"prop":"street_debris","at":[0.40,0.0],"s":0.5},
        {"prop":"gas_can","at":[0.58,-0.05],"s":0.46,"opt":0.6},
        {"prop":"shattered_glass","at":[0.30,-0.10],"s":0.5,"opt":0.6}
    ],
    "roadblock":[
        {"piece":"jersey_blocks","at":[0.46,-0.55],"s":0.5,"solid":[58,8]},
        {"piece":"jersey_blocks","at":[0.50,0.40],"s":0.5,"solid":[58,8]},
        {"piece":"sandbag_nest","at":[0.66,-0.30],"s":0.44,"solid":[32,10],"opt":0.7},
        {"piece":"warning_sign","at":[0.30,0.80],"s":0.42,"opt":0.8},
        {"prop":"road_barrier","at":[0.34,-0.10],"s":0.56},
        {"prop":"traffic_cone","at":[0.30,0.20],"s":0.46,"opt":0.7},
        {"piece":"tire_wall","at":[0.70,0.62],"s":0.42,"opt":0.6},
        {"prop":"barricade_scraps","at":[0.58,-0.02],"s":0.5,"opt":0.6}
    ],
    "crater":[
        {"draw":"crater","at":[0.52,-0.08]},
        {"prop":"road_barrier","at":[0.30,-0.40],"s":0.56},
        {"prop":"traffic_cone","at":[0.32,0.24],"s":0.46},
        {"prop":"traffic_cone","at":[0.74,0.30],"s":0.46,"opt":0.7},
        {"piece":"rubble_pile","at":[0.70,-0.55],"s":0.4,"opt":0.7},
        {"prop":"broken_tile_pile","at":[0.40,0.50],"s":0.5,"opt":0.6}
    ],
    "overgrown":[
        {"surface":"weeds","rect":[0.12,-1.0,0.80,0.42],"edge":"soft"},
        {"surface":"weeds","rect":[0.30,0.55,0.62,0.45],"edge":"soft","opt":0.8},
        {"veg":"bush_yellow","at":[0.62,-0.82]},
        {"veg":"bush_bare","at":[0.40,0.86],"opt":0.7},
        {"veg":"bush_orange","at":[0.20,-0.86],"opt":0.6},
        {"piece":"dead_tree","at":[0.80,0.70],"s":0.4,"opt":0.4},
        {"veg":"tall_grass","at":[0.30,-0.50],"opt":0.8},
        {"veg":"weeds","at":[0.70,-0.30],"opt":0.8},
        {"veg":"bush_olive","at":[0.84,-0.70],"opt":0.6},
        {"piece":"burnt_car","at":[0.50,0.10],"s":0.46,"solid":[42,12],"opt":0.5}
    ],
    "fallen_tree":[
        {"draw":"log","at":[0.50,0.0]},
        {"veg":"fallen_branch","at":[0.36,0.50],"opt":0.8},
        {"veg":"leaf_pile","at":[0.62,-0.50],"opt":0.7},
        {"prop":"wooden_debris","at":[0.44,-0.30],"s":0.46,"opt":0.6}
    ],
    "stuck_car":[
        {"draw":"mud","at":[0.50,0.0]},
        {"car":[0.50,0.05],"turn":12},
        {"prop":"wooden_debris","at":[0.38,-0.40],"s":0.46,"opt":0.7},
        {"prop":"gas_can","at":[0.66,0.45],"s":0.46,"opt":0.6}
    ]
}

static func _h(coord:Vector2i,arm:int,salt:int) -> int:
    return abs(int(coord.x) * 92837111 ^ int(coord.y) * 689287499 ^ (arm + 3) * 283923481 ^ salt * 2654435761) % 1000003

static func pick(family:String,coord:Vector2i,arm:int,vertical:bool) -> String:
    if float(_h(coord,arm,5) % 10000) / 10000.0 >= float(ARM_CHANCE.get(family,0.0)):
        return ""
    var table = []
    for e in FAMILY_SCENES.get(family,[]):
        if not vertical and str(e[0]) in VERTICAL_ONLY:
            continue
        table.append(e)
    var total = 0
    for e in table:
        total += int(e[1])
    if total <= 0:
        return ""
    var r = _h(coord,arm,9) % total
    for e in table:
        r -= int(e[1])
        if r < 0:
            return str(e[0])
    return ""

static func plan(kind:String) -> Array:
    return PLANS.get(kind,[])
