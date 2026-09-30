extends RefCounted

# OSTATOK 0.84 — authored plot arrangements for procedural chunks.
# The road cross still defines the main circulation, but buildings no longer sit
# on one rigid four-corner grid. Each district has several deterministic setback
# patterns and per-slot scale biases while keeping cache_0..cache_3 stable.

const GENERIC_VARIANTS = [
    [
        {"pos":Vector2(118,112),"scale":Vector2(1.08,0.94)},
        {"pos":Vector2(635,132),"scale":Vector2(0.88,1.08)},
        {"pos":Vector2(138,626),"scale":Vector2(0.92,1.02)},
        {"pos":Vector2(618,600),"scale":Vector2(1.04,0.90)}
    ],
    [
        {"pos":Vector2(142,136),"scale":Vector2(0.88,1.10)},
        {"pos":Vector2(614,104),"scale":Vector2(1.05,0.92)},
        {"pos":Vector2(108,604),"scale":Vector2(1.10,0.88)},
        {"pos":Vector2(642,628),"scale":Vector2(0.86,1.08)}
    ],
    [
        {"pos":Vector2(104,138),"scale":Vector2(0.94,0.90)},
        {"pos":Vector2(642,146),"scale":Vector2(1.08,1.06)},
        {"pos":Vector2(150,594),"scale":Vector2(0.84,1.10)},
        {"pos":Vector2(604,634),"scale":Vector2(1.06,0.86)}
    ]
]

const SET_VARIANTS = {
    "panel_estate":[
        [
            {"pos":Vector2(132,112),"scale":Vector2(1.08,1.00)},
            {"pos":Vector2(628,126),"scale":Vector2(0.90,1.06)},
            {"pos":Vector2(112,624),"scale":Vector2(0.84,0.94)},
            {"pos":Vector2(636,596),"scale":Vector2(1.10,0.90)}
        ],
        [
            {"pos":Vector2(118,144),"scale":Vector2(0.96,1.08)},
            {"pos":Vector2(648,104),"scale":Vector2(1.02,0.92)},
            {"pos":Vector2(144,604),"scale":Vector2(0.90,1.04)},
            {"pos":Vector2(604,632),"scale":Vector2(1.12,0.88)}
        ]
    ],
    "commercial_strip":[
        [
            {"pos":Vector2(138,118),"scale":Vector2(1.04,0.94)},
            {"pos":Vector2(624,108),"scale":Vector2(0.92,1.04)},
            {"pos":Vector2(112,628),"scale":Vector2(0.86,0.94)},
            {"pos":Vector2(642,610),"scale":Vector2(1.08,0.90)}
        ],
        [
            {"pos":Vector2(108,126),"scale":Vector2(0.90,1.06)},
            {"pos":Vector2(646,142),"scale":Vector2(1.06,0.92)},
            {"pos":Vector2(150,598),"scale":Vector2(1.02,0.90)},
            {"pos":Vector2(606,636),"scale":Vector2(0.88,1.06)}
        ]
    ],
    "industrial_belt":[
        [
            {"pos":Vector2(134,120),"scale":Vector2(1.10,1.04)},
            {"pos":Vector2(630,142),"scale":Vector2(1.04,0.88)},
            {"pos":Vector2(104,616),"scale":Vector2(0.92,1.00)},
            {"pos":Vector2(646,598),"scale":Vector2(0.82,1.08)}
        ],
        [
            {"pos":Vector2(110,146),"scale":Vector2(0.96,1.08)},
            {"pos":Vector2(648,112),"scale":Vector2(1.10,0.90)},
            {"pos":Vector2(148,594),"scale":Vector2(1.08,0.90)},
            {"pos":Vector2(610,636),"scale":Vector2(0.88,1.04)}
        ],
        [
            {"pos":Vector2(146,104),"scale":Vector2(1.04,0.92)},
            {"pos":Vector2(610,148),"scale":Vector2(0.90,1.08)},
            {"pos":Vector2(114,642),"scale":Vector2(0.88,0.94)},
            {"pos":Vector2(640,604),"scale":Vector2(1.10,1.00)}
        ]
    ],
    "rail_service":[
        [
            {"pos":Vector2(132,104),"scale":Vector2(1.10,0.86)},
            {"pos":Vector2(626,146),"scale":Vector2(0.90,1.04)},
            {"pos":Vector2(106,624),"scale":Vector2(1.02,0.88)},
            {"pos":Vector2(646,612),"scale":Vector2(0.88,1.00)}
        ],
        [
            {"pos":Vector2(104,148),"scale":Vector2(0.94,1.02)},
            {"pos":Vector2(648,108),"scale":Vector2(1.08,0.88)},
            {"pos":Vector2(146,598),"scale":Vector2(1.06,0.90)},
            {"pos":Vector2(610,640),"scale":Vector2(0.90,1.06)}
        ]
    ],
    "dacha_coop":[
        [
            {"pos":Vector2(104,106),"scale":Vector2(0.82,0.92)},
            {"pos":Vector2(640,146),"scale":Vector2(1.08,1.00)},
            {"pos":Vector2(150,630),"scale":Vector2(0.92,1.06)},
            {"pos":Vector2(612,588),"scale":Vector2(0.76,0.86)}
        ],
        [
            {"pos":Vector2(146,142),"scale":Vector2(1.02,1.02)},
            {"pos":Vector2(610,104),"scale":Vector2(0.78,0.86)},
            {"pos":Vector2(102,596),"scale":Vector2(0.84,0.94)},
            {"pos":Vector2(646,636),"scale":Vector2(1.06,1.00)}
        ]
    ],
    "woodland_edge":[
        [
            {"pos":Vector2(124,114),"scale":Vector2(0.92,1.00)},
            {"pos":Vector2(644,136),"scale":Vector2(0.78,0.88)},
            {"pos":Vector2(102,638),"scale":Vector2(0.82,0.92)},
            {"pos":Vector2(626,600),"scale":Vector2(0.76,0.86)}
        ],
        [
            {"pos":Vector2(146,142),"scale":Vector2(0.86,0.96)},
            {"pos":Vector2(618,102),"scale":Vector2(0.82,0.92)},
            {"pos":Vector2(112,604),"scale":Vector2(0.76,0.86)},
            {"pos":Vector2(648,638),"scale":Vector2(0.90,1.02)}
        ]
    ],
    "military_perimeter":[
        [
            {"pos":Vector2(116,138),"scale":Vector2(0.82,0.92)},
            {"pos":Vector2(638,108),"scale":Vector2(1.04,0.92)},
            {"pos":Vector2(146,606),"scale":Vector2(1.08,1.02)},
            {"pos":Vector2(610,638),"scale":Vector2(0.84,0.94)}
        ],
        [
            {"pos":Vector2(142,104),"scale":Vector2(0.90,0.94)},
            {"pos":Vector2(610,142),"scale":Vector2(1.08,1.02)},
            {"pos":Vector2(104,632),"scale":Vector2(0.88,0.92)},
            {"pos":Vector2(644,598),"scale":Vector2(0.92,1.08)}
        ]
    ]
}

static func _hash_coord(coord:Vector2i,salt:int = 0) -> int:
    return abs(coord.x * 92821 + coord.y * 68917 + coord.x * coord.y * 131 + salt * 7919 + 48017)

static func slots_for(building_set:String,coord:Vector2i,poi_kind:String = "") -> Array:
    var key = building_set
    if poi_kind == "garage_coop":
        key = "panel_estate"
    elif poi_kind == "factory_complex":
        key = "industrial_belt"
    elif poi_kind == "rail_depot":
        key = "rail_service"
    elif poi_kind == "dacha_coop":
        key = "dacha_coop"
    elif poi_kind == "military_checkpoint":
        key = "military_perimeter"
    elif poi_kind == "hospital_complex":
        key = "commercial_strip"
    elif poi_kind == "police_station":
        key = "panel_estate"
    elif poi_kind == "hunting_cordon":
        key = "woodland_edge"
    var variants = SET_VARIANTS.get(key,GENERIC_VARIANTS)
    var variant = variants[_hash_coord(coord,31) % variants.size()]
    return variant.duplicate(true)
