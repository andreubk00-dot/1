extends RefCounted

# OSTATOK 1.24-dev2 — deterministic cosmetic variety for finite open-world
# encounter scenes. The helper never changes event selection, enemy budgets,
# loot profiles, spawn ids, interaction nodes or persistence keys.

const VARIANT_COUNT := 3

const SUPPORTED_EVENTS = [
    "abandoned_camp",
    "failed_evacuation",
    "repair_breakdown",
    "looted_convoy",
    "feeding_site"
]

# Each profile adds exactly two non-colliding sprite accents from the existing
# world-prop atlas. Positions are local to the already-authored encounter root.
const PROFILES = {
    "abandoned_camp":[
        [
            {"kind":"newspapers_wide","pos":Vector2(-48,30),"scale":0.38,"z":2},
            {"kind":"trash_bag","pos":Vector2(54,24),"scale":0.36,"z":3}
        ],
        [
            {"kind":"scattered_bottles","pos":Vector2(-50,-28),"scale":0.38,"z":2},
            {"kind":"folded_blanket","pos":Vector2(50,28),"scale":0.40,"z":3}
        ],
        [
            {"kind":"rubble_papers","pos":Vector2(-52,28),"scale":0.38,"z":2},
            {"kind":"cardboard_boxes","pos":Vector2(52,-28),"scale":0.34,"z":3}
        ]
    ],
    "failed_evacuation":[
        [
            {"kind":"dirty_linen","pos":Vector2(-54,30),"scale":0.38,"z":2},
            {"kind":"medicine_boxes","pos":Vector2(52,26),"scale":0.34,"z":3}
        ],
        [
            {"kind":"broken_trolley","pos":Vector2(-54,26),"scale":0.34,"z":3},
            {"kind":"floor_papers","pos":Vector2(50,30),"scale":0.38,"z":2}
        ],
        [
            {"kind":"oxygen_cylinder","pos":Vector2(-56,22),"scale":0.34,"z":3},
            {"kind":"trash_bag","pos":Vector2(54,28),"scale":0.36,"z":3}
        ]
    ],
    "repair_breakdown":[
        [
            {"kind":"puddle","pos":Vector2(-50,30),"scale":0.40,"z":1},
            {"kind":"rubble_papers","pos":Vector2(52,28),"scale":0.36,"z":2}
        ],
        [
            {"kind":"floor_cable","pos":Vector2(-52,28),"scale":0.38,"z":2},
            {"kind":"wooden_debris","pos":Vector2(52,-28),"scale":0.34,"z":2}
        ],
        [
            {"kind":"shattered_glass","pos":Vector2(-52,-28),"scale":0.38,"z":1},
            {"kind":"scattered_bottles","pos":Vector2(54,26),"scale":0.36,"z":2}
        ]
    ],
    "looted_convoy":[
        [
            {"kind":"shattered_glass","pos":Vector2(-56,30),"scale":0.40,"z":1},
            {"kind":"cardboard_boxes","pos":Vector2(62,32),"scale":0.34,"z":3}
        ],
        [
            {"kind":"street_debris","pos":Vector2(-58,30),"scale":0.36,"z":2},
            {"kind":"gas_can","pos":Vector2(62,30),"scale":0.34,"z":3}
        ],
        [
            {"kind":"floor_papers","pos":Vector2(-56,30),"scale":0.38,"z":2},
            {"kind":"barricade_scraps","pos":Vector2(62,30),"scale":0.36,"z":2}
        ]
    ],
    "feeding_site":[
        [
            {"kind":"floor_papers","pos":Vector2(-46,28),"scale":0.38,"z":2},
            {"kind":"broken_chair_detail","pos":Vector2(46,24),"scale":0.38,"z":2}
        ],
        [
            {"kind":"scattered_bottles","pos":Vector2(-48,-26),"scale":0.36,"z":2},
            {"kind":"trash_bag","pos":Vector2(48,24),"scale":0.34,"z":3}
        ],
        [
            {"kind":"shattered_glass","pos":Vector2(-48,26),"scale":0.38,"z":1},
            {"kind":"newspapers_wide","pos":Vector2(48,-24),"scale":0.36,"z":2}
        ]
    ]
}

static func _text_hash(text:String) -> int:
    var value:int = 5381
    for i in range(text.length()):
        value = int((value * 33 + text.unicode_at(i)) & 0x7fffffff)
    return value

static func variant_for(coord:Vector2i,event_id:String) -> int:
    if not event_id in SUPPORTED_EVENTS:
        return -1
    # A small integer avalanche avoids the modulo-3 coordinate correlation that
    # made rare events collapse to one cosmetic variant in the first dev2 draft.
    var value:int = int(coord.x * 0x45d9f3b) ^ int(coord.y * 0x119de1f3)
    value = value ^ int(coord.x * coord.y * 0x27d4eb2d)
    value = value ^ _text_hash(event_id) ^ int(3 * 0x9e3779b9)
    value = value & 0x7fffffff
    value = value ^ (value >> 16)
    value = int((value * 0x45d9f3b) & 0x7fffffff)
    value = value ^ (value >> 15)
    return posmod(value,VARIANT_COUNT)

static func accents_for(coord:Vector2i,event_id:String) -> Array:
    var variant = variant_for(coord,event_id)
    if variant < 0 or not PROFILES.has(event_id):
        return []
    var variants:Array = PROFILES[event_id]
    return variants[posmod(variant,variants.size())].duplicate(true)
