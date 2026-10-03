extends RefCounted

# OSTATOK 1.23-dev2 — High Risk site dressing.
# Each of the four High Risk sites gets its own ground, perimeter and landmarks so
# the six sectors read as one place with a story, not as repeated boxes:
#   clinic     — hospital campus: car park, lawns, a helipad with the Mi-8 that
#                never took off, ambulances, a makeshift graveyard in the garden;
#   quarantine — the campus turned camp: mud, duckboards, tents, decon tunnels,
#                burn pits and body bags in the red zone;
#   bastion    — reserve arsenal: concrete apron, dragon's teeth, HESCO, a dead
#                T-72 and a downed helicopter next to the command block;
#   vector     — research object in an overgrown clearing: service road, a rail
#                spur into the access shaft, vent heads, cooling arrays, masts.
# Pieces: plain kind -> settlement_props_v1.png, "hr:" -> art/high_risk/hr_props_v1.png,
# "poi:" -> poi_props_v1.png, "prop:" -> world_props_v19.png.
# Every piece is still checked at runtime against doors, buildings, containers,
# floor stairs and fences; a blocked piece is skipped, never forced.

const SITES = {
    "regional_clinical_complex_4":{
        "style":"clinic",
        "ground":["asphalt","pavement","lawn"],
        "perimeter":true,
        "clutter":["burnt_car","rubble_pile","junk_pile","prop:wheelchair","prop:stretcher","dead_tree","oil_drums","prop:trash_bag"],
        "cells":{
            "0,0":{"pieces":[["hr:hospital_sign",Vector2(96,500)],["hr:burnt_ambulance",Vector2(330,548)],["ambulance",Vector2(452,640)],
                             ["triage_canopy",Vector2(300,700)],["prop:stretcher",Vector2(400,560),0.55],["dead_tree",Vector2(64,700),0.8]],
                   "paint":"ambulance_bay","lawn":Rect2(40,640,200,100)},
            "1,0":{"pieces":[["burnt_car",Vector2(110,520)],["burnt_car",Vector2(330,520)],["hr:fuel_bowser",Vector2(440,690)],
                             ["street:bench",Vector2(60,700)],["dead_tree",Vector2(280,700),0.85],["prop:wheelchair",Vector2(470,540),0.5]],
                   "paint":"parking"},
            "2,0":{"pieces":[["hr:heli_wreck",Vector2(310,560),0.72],["hr:crater",Vector2(440,690),0.6],["hr:cryo_trailer",Vector2(610,470),0.66],
                             ["hr:light_mast",Vector2(60,470),0.8],["hr:generator_trailer",Vector2(90,700)]],
                   "paint":"helipad"},
            "0,1":{"pieces":[["graves",Vector2(110,520)],["graves",Vector2(290,520)],["graves",Vector2(290,620)],["dead_tree",Vector2(430,560),0.9],
                             ["street:bench",Vector2(80,700)],["prop:wheelchair",Vector2(380,700),0.5],["street:planter",Vector2(470,700)]],
                   "paint":"garden","lawn":Rect2(40,480,470,260)},
            "1,1":{"pieces":[["hr:decon_tunnel",Vector2(330,520),0.7],["hr:hazmat_drums",Vector2(470,640)],["hr:body_bags",Vector2(330,690),0.62],
                             ["incinerator",Vector2(90,700),0.8],["hr:quarantine_sign",Vector2(470,510),0.6]],
                   "paint":"hatched"},
            "2,1":{"pieces":[["hr:generator_trailer",Vector2(110,520)],["hr:container_stack",Vector2(330,560),0.7],["oxygen_rack",Vector2(90,700)],
                             ["hr:light_mast",Vector2(460,500),0.8],["hr:hazmat_drums",Vector2(230,720)]],
                   "paint":"service"}
        }
    },
    "quarantine_center_12":{
        "style":"quarantine",
        "ground":["dirt_yard","gravel","grass_dry"],
        "perimeter":true,
        "clutter":["hr:hazmat_drums","rubble_pile","junk_pile","burnt_car","prop:body_bag","oil_drums","hr:sandbag_wall","prop:trash_bag"],
        "cells":{
            "0,0":{"pieces":[["hr:decon_tunnel",Vector2(300,500),0.7],["medical_tent",Vector2(110,520)],["hr:quarantine_sign",Vector2(470,500),0.6],
                             ["hr:light_mast",Vector2(60,700),0.8],["hr:sandbag_wall",Vector2(330,690),0.62],["burnt_car",Vector2(460,680)]],
                   "paint":"duckboards"},
            "1,0":{"pieces":[["army_tent",Vector2(100,520)],["army_tent",Vector2(250,520)],["army_tent",Vector2(400,520)],
                             ["army_tent",Vector2(100,690)],["army_tent",Vector2(320,690)],["hr:light_mast",Vector2(470,690),0.8]],
                   "paint":"duckboards"},
            "2,0":{"pieces":[["hr:cryo_trailer",Vector2(120,520),0.66],["hr:hazmat_drums",Vector2(320,520)],["hr:container_stack",Vector2(330,680),0.7],
                             ["hr:generator_trailer",Vector2(460,560)],["hr:quarantine_sign",Vector2(90,690),0.6]],
                   "paint":"gravel"},
            "0,1":{"pieces":[["hr:fuel_bowser",Vector2(120,520)],["hr:container_stack",Vector2(330,540),0.7],["hr:burnt_ambulance",Vector2(320,690)],
                             ["scrap_heap",Vector2(470,690)],["hr:light_mast",Vector2(60,700),0.8]],
                   "paint":"gravel"},
            "1,1":{"pieces":[["bonfire",Vector2(300,600),0.9],["hr:body_bags",Vector2(110,520),0.66],["hr:body_bags",Vector2(110,690),0.66],
                             ["graves",Vector2(440,690)],["hr:hazmat_drums",Vector2(460,520)],["hr:quarantine_sign",Vector2(300,500),0.6],
                             ["hr:crater",Vector2(320,700),0.55]],
                   "paint":"burn_pit"},
            "2,1":{"pieces":[["hr:decon_tunnel",Vector2(320,510),0.7],["hr:light_mast",Vector2(460,690),0.8],["hr:sandbag_wall",Vector2(110,520),0.62],
                             ["hr:generator_trailer",Vector2(300,690)],["searchlight_tower",Vector2(80,700),0.85]],
                   "paint":"duckboards"}
        }
    },
    "reserve_arsenal_bastion":{
        "style":"bastion",
        "ground":["concrete_slabs","gravel","grass_dry"],
        "perimeter":true,
        "clutter":["hr:sandbag_wall","jersey_blocks","rubble_pile","oil_drums","prop:ammo_crate","hr:crater","burnt_car"],
        "cells":{
            "0,0":{"pieces":[["hr:dragon_teeth",Vector2(140,520),0.7],["hr:dragon_teeth",Vector2(320,520),0.7],["btr",Vector2(330,690),0.8],
                             ["searchlight_tower",Vector2(70,700),0.9],["hr:sandbag_wall",Vector2(470,560),0.62]],
                   "paint":"apron"},
            "1,0":{"pieces":[["flag_pole",Vector2(300,600),0.9],["hesco_row",Vector2(120,520)],["hesco_row",Vector2(460,520)],
                             ["hr:light_mast",Vector2(80,700),0.8],["btr",Vector2(420,690),0.8]],
                   "paint":"parade"},
            "2,0":{"pieces":[["hr:fuel_bowser",Vector2(330,540)],["hr:container_stack",Vector2(330,700),0.7],["hr:generator_trailer",Vector2(460,620)]],
                   "paint":"taxi"},
            "0,1":{"pieces":[["hr:tank_wreck",Vector2(320,560),0.8],["btr",Vector2(110,520),0.8],["hr:crater",Vector2(440,690),0.7],
                             ["hr:fuel_bowser",Vector2(310,700)],["hr:light_mast",Vector2(60,700),0.8]],
                   "paint":"taxi"},
            "1,1":{"pieces":[["hr:heli_wreck",Vector2(320,580),0.8],["hr:crater",Vector2(330,700),0.66],["hr:lattice_mast",Vector2(470,500),0.8],
                             ["hr:sandbag_wall",Vector2(110,520),0.62],["searchlight_tower",Vector2(80,700),0.9]],
                   "paint":"apron"},
            "2,1":{"pieces":[["hr:tank_wreck",Vector2(390,700),0.8],["hr:dragon_teeth",Vector2(330,520),0.7],["hr:light_mast",Vector2(60,520),0.8],
                             ["hr:crater",Vector2(470,560),0.6]],
                   "paint":"taxi"}
        }
    },
    "underground_object_vector":{
        "style":"vector",
        "ground":["grass_dry","asphalt","lawn"],
        "perimeter":true,
        "clutter":["rubble_pile","hr:vent_head","dead_tree","oil_drums","junk_pile","prop:gas_can","burnt_car"],
        "cells":{
            "0,0":{"pieces":[["hr:rail_cart",Vector2(475,520),0.66],["hr:vent_head",Vector2(110,530),0.7],["hr:light_mast",Vector2(300,700),0.8],
                             ["hr:cooling_fans",Vector2(110,690),0.7]],
                   "paint":"rail_to_shaft"},
            "1,0":{"pieces":[["hr:lattice_mast",Vector2(300,600),0.85],["hr:cooling_fans",Vector2(110,530),0.7],["hr:generator_trailer",Vector2(450,690)],
                             ["hr:vent_head",Vector2(110,690),0.7]],
                   "paint":"service_road"},
            "0,1":{"pieces":[["poi:transformer",Vector2(110,520)],["poi:transformer",Vector2(250,520)],["hr:cooling_fans",Vector2(380,720),0.7],
                             ["hr:vent_head",Vector2(470,540),0.7],["hr:light_mast",Vector2(80,700),0.8]],
                   "paint":"service_road"},
            "1,1":{"pieces":[["hr:lattice_mast",Vector2(120,560),0.85],["hr:lattice_mast",Vector2(440,560),0.85],["hr:vent_head",Vector2(300,690),0.7],
                             ["hr:generator_trailer",Vector2(110,700)]],
                   "paint":"pads"},
            "0,2":{"pieces":[["hr:rail_cart",Vector2(182,486),0.66],["hr:container_stack",Vector2(110,690),0.7],["hr:vent_head",Vector2(470,540),0.7],
                             ["hr:light_mast",Vector2(330,700),0.8]],
                   "paint":"rail_to_shaft"},
            "1,2":{"pieces":[["hr:cooling_fans",Vector2(130,520),0.7],["hr:cooling_fans",Vector2(330,520),0.7],["hr:crater",Vector2(320,690),0.6],
                             ["hr:fuel_bowser",Vector2(110,700)],["hr:vent_head",Vector2(470,690),0.7]],
                   "paint":"pads"}
        }
    }
}

static func has(poi_id:String) -> bool:
    return SITES.has(poi_id)

static func site(poi_id:String) -> Dictionary:
    return SITES.get(poi_id,{})

static func cell(poi_id:String,offset:Vector2i) -> Dictionary:
    return SITES.get(poi_id,{}).get("cells",{}).get("%d,%d" % [offset.x,offset.y],{})
