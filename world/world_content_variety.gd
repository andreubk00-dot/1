extends RefCounted

# OSTATOK 1.24-dev1 — deterministic cosmetic variation for procedural buildings.
# The helper never changes building ids, doors, walls, containers, loot profiles or
# save keys. It only selects non-colliding dressing from existing art.

const VARIANT_COUNT := 3

const GROUPS = {
    "panel_block":"residential",
    "panel_entry":"residential",
    "utility_house":"residential",
    "country_house":"residential",
    "dacha":"residential",
    "grocery":"commercial",
    "pharmacy":"commercial",
    "cafe":"commercial",
    "service_shop":"commercial",
    "garage_row":"garage",
    "repair_bay":"garage",
    "workshop":"warehouse",
    "warehouse":"warehouse",
    "factory_admin":"warehouse",
    "rail_store":"warehouse",
    "rail_service":"warehouse"
}

# Positions are normalized against the building footprint. Facade fy is a fraction
# of facade height below the cornice. Yard positions are offsets from the front-center.
const PROFILES = {
    "residential":[
        {
            "interior":[{"kind":"floor_papers","fx":-0.12,"fy":0.22,"scale":0.46,"z":2}],
            "facade":[{"kind":"wall_poster","fx":-0.22,"fy":0.46,"scale":0.44,"z":3}],
            "yard":[{"kind":"newspapers_wide","fx":-0.22,"dy":12.0,"scale":0.40,"z":2}]
        },
        {
            "interior":[{"kind":"scattered_bottles","fx":0.16,"fy":0.24,"scale":0.42,"z":2}],
            "facade":[{"kind":"electrical_box","fx":0.24,"fy":0.40,"scale":0.42,"z":3}],
            "yard":[{"kind":"trash_bag","fx":0.24,"dy":8.0,"scale":0.38,"z":3}]
        },
        {
            "interior":[{"kind":"newspapers","fx":0.18,"fy":0.20,"scale":0.42,"z":2}],
            "facade":[{"kind":"wall_grime","fx":0.20,"fy":0.52,"scale":0.42,"z":2}],
            "yard":[{"kind":"wooden_debris","fx":-0.24,"dy":10.0,"scale":0.38,"z":2}]
        }
    ],
    "commercial":[
        {
            "interior":[{"kind":"floor_papers","fx":0.10,"fy":0.24,"scale":0.46,"z":2}],
            "facade":[{"kind":"wall_poster","fx":0.24,"fy":0.42,"scale":0.46,"z":3}],
            "yard":[{"kind":"shopping_cart","fx":-0.26,"dy":10.0,"scale":0.38,"z":3}]
        },
        {
            "interior":[{"kind":"scattered_bottles","fx":-0.16,"fy":0.22,"scale":0.44,"z":2}],
            "facade":[{"kind":"electrical_box","fx":-0.25,"fy":0.38,"scale":0.42,"z":3}],
            "yard":[{"kind":"cardboard_boxes","fx":0.24,"dy":9.0,"scale":0.38,"z":3}]
        },
        {
            "interior":[{"kind":"newspapers_wide","fx":0.18,"fy":0.20,"scale":0.42,"z":2}],
            "facade":[{"kind":"hanging_wires","fx":0.18,"fy":0.56,"scale":0.40,"z":2}],
            "yard":[{"kind":"traffic_cone","fx":-0.24,"dy":10.0,"scale":0.42,"z":4}]
        }
    ],
    "garage":[
        {
            "interior":[{"kind":"puddle","fx":-0.16,"fy":0.22,"scale":0.46,"z":1}],
            "facade":[{"kind":"wall_grime","fx":-0.22,"fy":0.46,"scale":0.44,"z":2}],
            "yard":[{"kind":"gas_can","fx":0.25,"dy":8.0,"scale":0.40,"z":3}]
        },
        {
            "interior":[{"kind":"rubble_papers","fx":0.18,"fy":0.22,"scale":0.42,"z":2}],
            "facade":[{"kind":"wall_pipe","fx":0.24,"fy":0.44,"scale":0.42,"z":3}],
            "yard":[{"kind":"wooden_debris","fx":-0.26,"dy":10.0,"scale":0.40,"z":2}]
        },
        {
            "interior":[{"kind":"scattered_bottles","fx":0.14,"fy":0.24,"scale":0.42,"z":2}],
            "facade":[{"kind":"electrical_box","fx":-0.24,"fy":0.38,"scale":0.40,"z":3}],
            "yard":[{"kind":"barrel","fx":0.26,"dy":6.0,"scale":0.42,"z":3}]
        }
    ],
    "warehouse":[
        {
            "interior":[{"kind":"rubble_papers","fx":-0.16,"fy":0.22,"scale":0.44,"z":2}],
            "facade":[{"kind":"wall_pipe","fx":-0.24,"fy":0.46,"scale":0.42,"z":3}],
            "yard":[{"kind":"supply_crate","fx":0.26,"dy":8.0,"scale":0.38,"z":3}]
        },
        {
            "interior":[{"kind":"puddle","fx":0.18,"fy":0.24,"scale":0.46,"z":1}],
            "facade":[{"kind":"wall_grime","fx":0.24,"fy":0.50,"scale":0.44,"z":2}],
            "yard":[{"kind":"barrel","fx":-0.26,"dy":7.0,"scale":0.42,"z":3}]
        },
        {
            "interior":[{"kind":"floor_papers","fx":0.12,"fy":0.20,"scale":0.44,"z":2}],
            "facade":[{"kind":"hanging_wires","fx":-0.20,"fy":0.56,"scale":0.40,"z":2}],
            "yard":[{"kind":"traffic_cone","fx":0.25,"dy":10.0,"scale":0.42,"z":4}]
        }
    ]
}

static func _text_hash(text:String) -> int:
    var value:int = 5381
    for i in range(text.length()):
        value = int((value * 33 + text.unicode_at(i)) & 0x7fffffff)
    return value

static func group_for_archetype(archetype_id:String) -> String:
    return str(GROUPS.get(archetype_id,""))

static func variant_for(coord:Vector2i,archetype_id:String,building_index:int) -> int:
    var group = group_for_archetype(archetype_id)
    if group == "":
        return -1
    var value = coord.x * 92821 + coord.y * 68917 + coord.x * coord.y * 317
    value += (coord.x + coord.y) * (coord.x - coord.y) * 173
    value += _text_hash(archetype_id) * 19 + building_index * 7927 + 12401
    return posmod(value,VARIANT_COUNT)

static func visual_seed_key(coord:Vector2i,archetype_id:String,building_index:int) -> String:
    return "%d:%d:%s:%d" % [coord.x,coord.y,archetype_id,building_index]

static func profile_for(archetype_id:String,variant:int) -> Dictionary:
    var group = group_for_archetype(archetype_id)
    if group == "" or not PROFILES.has(group):
        return {}
    var variants:Array = PROFILES[group]
    if variants.is_empty():
        return {}
    return variants[posmod(variant,variants.size())].duplicate(true)
