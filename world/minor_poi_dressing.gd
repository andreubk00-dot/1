extends RefCounted

# OSTATOK 1.24-dev3 — final cosmetic dressing pass for sparse authored minor-POI cells.
# This layer is derived at runtime and intentionally contains no gameplay fields:
# no loot, containers, enemies, collisions, doors, risk, farming or persistence keys.

const TARGETS = {
    "dacha_coop_zarya": {
        "-1,0":[
            {"kind":"rain_collector","pos":Vector2(526,526),"scale":0.42,"z":3},
            {"kind":"wooden_debris","pos":Vector2(562,536),"scale":0.38,"z":2}
        ],
        "0,1":[
            {"kind":"plant","pos":Vector2(524,524),"scale":0.42,"z":3},
            {"kind":"cardboard_boxes","pos":Vector2(560,532),"scale":0.34,"z":3}
        ],
        "-1,1":[
            {"kind":"campfire","pos":Vector2(524,526),"scale":0.44,"z":3},
            {"kind":"trash_bag","pos":Vector2(566,534),"scale":0.34,"z":3}
        ]
    },
    "military_checkpoint": {
        "0,-1":[
            {"kind":"sandbags","pos":Vector2(526,526),"scale":0.44,"z":3},
            {"kind":"ammo_crate","pos":Vector2(566,532),"scale":0.36,"z":3}
        ]
    },
    "district_police": {
        "1,0":[
            {"kind":"gas_can","pos":Vector2(526,528),"scale":0.38,"z":3},
            {"kind":"toolbox","pos":Vector2(562,532),"scale":0.40,"z":3}
        ]
    },
    "hunting_cordon": {
        "1,0":[
            {"kind":"rain_collector","pos":Vector2(526,526),"scale":0.40,"z":3},
            {"kind":"cardboard_boxes","pos":Vector2(562,534),"scale":0.32,"z":3}
        ]
    }
}

static func cell_key(cell_offset:Vector2i) -> String:
    return "%d,%d" % [cell_offset.x,cell_offset.y]

static func accents_for(poi_id:String,cell_offset:Vector2i) -> Array:
    if not TARGETS.has(poi_id):
        return []
    var cells:Dictionary = TARGETS[poi_id]
    var key = cell_key(cell_offset)
    if not cells.has(key):
        return []
    return cells[key].duplicate(true)

static func target_cell_count() -> int:
    var total := 0
    for cells in TARGETS.values():
        total += cells.size()
    return total
