extends SceneTree
# 1.22-dev4: faction settlements are authored towns. Their new walls and set
# pieces must never cut off a gate, the sector cross-lanes or a named NPC.
const Main = preload("res://main_script_mod.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionSettlementCatalog = preload("res://world/faction_settlement_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

var checks := 0
var failures := 0
func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _static_rects(node:Node,out:Array,skip_walls:bool) -> void:
    for child in node.get_children():
        if skip_walls and child.has_meta("settlement_wall"):
            continue
        if child is StaticBody2D:
            for shape_node in child.get_children():
                if shape_node is CollisionShape2D and shape_node.shape is RectangleShape2D:
                    var size = shape_node.shape.size
                    var center = shape_node.global_position
                    out.append(Rect2(center - size * 0.5,size))
        _static_rects(child,out,skip_walls)

var last_block := Rect2()
func _blocked(rects:Array,area:Rect2) -> bool:
    for r in rects:
        if r.intersects(area):
            last_block = r
            return true
    return false

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame
    # The authored plan itself: two distinct faction perimeters, gates on all sides.
    var gate_sides = {}
    for offset in FactionSettlementCatalog.FOOTPRINT_3X3:
        for side in FactionSettlementCatalog.perimeter(offset).keys():
            if bool(FactionSettlementCatalog.perimeter(offset)[side]):
                gate_sides[side] = true
    check(gate_sides.size() == 4,"settlements must open a gate on every side")
    check(FactionSettlementCatalog.perimeter(Vector2i.ZERO).is_empty(),"centre sector must not be walled")

    var kinds_by_faction = {}
    for faction_id in FactionCatalog.ids():
        var settlement_id = str(FactionCatalog.faction(faction_id).get("settlement_id",""))
        var anchor:Vector2i = RegionCatalog.poi_by_id(settlement_id).get("coord",Vector2i.ZERO)
        var kinds = {}
        var building_count := 0
        for offset in FactionSettlementCatalog.footprint(settlement_id):
            var cell = FactionSettlementCatalog.cell(settlement_id,offset)
            check(not cell.get("set_pieces",[]).is_empty(),settlement_id + " sector without set pieces " + str(offset))
            var ids = {}
            for spec in cell.get("buildings",[]):
                check(not ids.has(spec["id"]),settlement_id + " duplicate building id " + str(offset))
                ids[spec["id"]] = true
            building_count += cell.get("buildings",[]).size()

            var coord = anchor + offset
            if game.loaded_chunks.has(coord):
                game._unload_chunk(coord)
                await process_frame
            game._load_chunk(coord)
            await physics_frame
            var chunk = game.loaded_chunks.get(coord)
            check(is_instance_valid(chunk),settlement_id + " chunk failed " + str(offset))
            if not is_instance_valid(chunk):
                continue
            check(str(chunk.get_meta("faction_settlement","")) == faction_id,settlement_id + " style meta missing")
            var skipped = chunk.get_meta("settlement_pieces_skipped",[])
            check(skipped.is_empty(),settlement_id + " " + str(offset) + " could not place " + str(skipped))
            for node in chunk.get_children():
                if node.has_meta("settlement_piece_kind"):
                    kinds[str(node.get_meta("settlement_piece_kind"))] = true

            var origin = chunk.global_position
            var inner = []
            _static_rects(chunk,inner,true)
            var all_rects = []
            _static_rects(chunk,all_rects,false)
            # cross lanes of every sector stay open (walls excluded: they close the outer edge)
            check(not _blocked(inner,Rect2(origin + Vector2(352,40),Vector2(64,688))),settlement_id + " " + str(offset) + " north-south lane blocked by " + str(Rect2(last_block.position - origin,last_block.size)))
            check(not _blocked(inner,Rect2(origin + Vector2(40,352),Vector2(688,64))),settlement_id + " " + str(offset) + " west-east lane blocked by " + str(Rect2(last_block.position - origin,last_block.size)))
            # every gate opening is physically passable, including walls and posts
            var walls = FactionSettlementCatalog.perimeter(offset)
            for side in walls.keys():
                if not bool(walls[side]):
                    continue
                var gap = Rect2()
                match str(side):
                    "n": gap = Rect2(origin + Vector2(352,0),Vector2(64,80))
                    "s": gap = Rect2(origin + Vector2(352,688),Vector2(64,80))
                    "w": gap = Rect2(origin + Vector2(0,352),Vector2(80,64))
                    "e": gap = Rect2(origin + Vector2(688,352),Vector2(80,64))
                check(not _blocked(all_rects,gap),settlement_id + " " + str(offset) + " gate " + str(side) + " blocked by " + str(Rect2(last_block.position - origin,last_block.size)))
            # named NPCs keep a free standing circle
            for npc in FactionSettlementCatalog.npcs(settlement_id,offset):
                var p = origin + npc.get("pos",Vector2.ZERO)
                check(not _blocked(all_rects,Rect2(p - Vector2(16,16),Vector2(32,32))),settlement_id + " NPC boxed in: " + str(npc.get("npc_id","")))
            game._unload_chunk(coord)
            await process_frame
        check(building_count >= 18,settlement_id + " should read as a town (>=18 buildings), got " + str(building_count))
        check(kinds.size() >= 10,settlement_id + " needs >=10 distinct structures, got " + str(kinds.size()))
        kinds_by_faction[faction_id] = kinds

    # Faction identity: each settlement owns signature structures the others lack.
    var signatures = {
        "perron":["market_stall","water_tower","platform_canopy","poi:boxcar"],
        "rubezh":["btr","flag_pole","hesco_row","searchlight_tower"],
        "mechanics":["jib_crane","wind_turbine","fuel_station","container_shop"],
        "lazaret":["medical_tent","decon_frame","incinerator","triage_canopy"]
    }
    for faction_id in signatures.keys():
        for kind in signatures[faction_id]:
            check(kinds_by_faction.get(faction_id,{}).has(kind),faction_id + " missing signature structure " + kind)
    game.queue_free()
    await process_frame
    print("SETTLEMENT LAYOUT 1.22-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
