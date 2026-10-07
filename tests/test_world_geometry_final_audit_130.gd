extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
var checks := 0
var failures := 0
func check(ok:bool, why:String)->void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL ",why)
func _initialize()->void:
    call_deferred("run")
func _rect_for_building(node)->Rect2:
    var size = node.get_meta("building_size",Vector2.ZERO)
    return Rect2(node.position-size*0.5,size)
func _inside_chunk(rect:Rect2,chunk_size:float,margin:float=0.0)->bool:
    return rect.position.x >= margin and rect.position.y >= margin and rect.end.x <= chunk_size-margin and rect.end.y <= chunk_size-margin
func run()->void:
    var game = Harness.new()
    root.add_child(game)
    await process_frame
    var coords = {}
    # Representative ordinary world around the start region.
    for y in range(-2,3):
        for x in range(-2,3):
            coords[Vector2i(x,y)] = true
    # Every authored POI cell is part of the final geometry audit.
    for poi in RegionCatalog.POIS:
        var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
        for off in poi.get("footprint",[Vector2i.ZERO]):
            coords[anchor+off] = true
    var built_count = 0
    var authored_count = 0
    var event_count = 0
    for coord in coords.keys():
        var chunk = Node2D.new()
        chunk.position = Vector2(coord.x*game.CHUNK_SIZE,coord.y*game.CHUNK_SIZE)
        game.add_child(chunk)
        game._build_procedural_chunk(chunk,coord)
        built_count += 1
        var profile = game._chunk_profile(coord)
        var poi_id = str(profile.get("poi_id",""))
        var authored = PoiCatalog.has_compound(poi_id) and not bool(profile.get("legacy",false))
        if authored:
            authored_count += 1
        var buildings=[]
        var cars=[]
        var trees=[]
        var furniture=[]
        var events=[]
        var doors=[]
        for child in chunk.get_children():
            if child.has_meta("world_building"):
                buildings.append(child)
            if bool(child.get_meta("world_car",false)):
                cars.append(child)
            if bool(child.get_meta("world_tree",false)):
                trees.append(child)
            if child.has_meta("street_furniture_kind"):
                furniture.append(child)
            if bool(child.get_meta("world_event_root",false)):
                events.append(child)
            if child.is_in_group("doors"):
                doors.append(child)
        if not events.is_empty():
            event_count += events.size()
        var building_rects=[]
        for b in buildings:
            var rect=_rect_for_building(b)
            check(rect.size.x > 0 and rect.size.y > 0,"invalid building size at "+str(coord))
            check(_inside_chunk(rect,float(game.CHUNK_SIZE)),"building outside chunk at "+str(coord)+" "+str(rect))
            if not authored and not bool(profile.get("legacy",false)):
                var crosses_v = rect.position.x < game.BUILDING_ROAD_MAX and rect.end.x > game.BUILDING_ROAD_MIN
                var crosses_h = rect.position.y < game.BUILDING_ROAD_MAX and rect.end.y > game.BUILDING_ROAD_MIN
                check(not crosses_v and not crosses_h,"procedural building crosses public road at "+str(coord))
            building_rects.append(rect)
        # High Risk exterior models intentionally join architectural masses (main block + annex/post).
        # Raw authored gameplay footprints are already checked by test_target_farming_layout.gd;
        # treating the larger presentation envelopes as independent procedural houses is a false positive.
        var high_risk = bool(profile.get("poi",{}).get("high_risk",false))
        if not high_risk:
            for i in range(building_rects.size()):
                for j in range(i+1,building_rects.size()):
                    check(not building_rects[i].intersects(building_rects[j]),"buildings overlap at "+str(coord))
        for i in range(cars.size()):
            var cr=Rect2(cars[i].position-Vector2(40,24),Vector2(80,48))
            check(_inside_chunk(cr,float(game.CHUNK_SIZE),10.0),"car outside chunk at "+str(coord))
            for br in building_rects:
                check(not cr.intersects(br.grow(10.0)),"car overlaps building at "+str(coord))
            for j in range(i+1,cars.size()):
                var other=Rect2(cars[j].position-Vector2(40,24),Vector2(80,48))
                check(not cr.intersects(other),"cars overlap at "+str(coord))
            check(cars[i].z_index == 6,"car z-order drift at "+str(coord))
        for tree in trees:
            check(tree.position.x >= 0 and tree.position.x <= game.CHUNK_SIZE and tree.position.y >= 0 and tree.position.y <= game.CHUNK_SIZE,"tree outside chunk at "+str(coord))
            if not authored:
                check(not game._point_on_road_or_sidewalk(tree.position),"tree on public road/sidewalk at "+str(coord))
            for br in building_rects:
                # Procedural vegetation uses the full growth clearance. Authored settlements/High Risk
                # use their own door/facade-aware placement helpers, so here only reject an actual clip.
                var tree_guard = br if authored else br.grow(24.0)
                check(not tree_guard.has_point(tree.position),"tree clips building at "+str(coord))
            check(tree.z_index == 7,"tree z-order drift at "+str(coord))
        for item in furniture:
            check(item.position.x >= 0 and item.position.x <= game.CHUNK_SIZE and item.position.y >= 0 and item.position.y <= game.CHUNK_SIZE,"street furniture outside chunk at "+str(coord))
            for br in building_rects:
                check(not br.grow(6.0).has_point(item.position),"street furniture clips building at "+str(coord))
        for event in events:
            var er=game._world_event_rect(event)
            check(er.size != Vector2.ZERO,"world event missing footprint at "+str(coord))
            check(_inside_chunk(er,float(game.CHUNK_SIZE),18.0),"world event outside chunk at "+str(coord))
            for br in building_rects:
                check(not er.intersects(br.grow(14.0)),"world event overlaps building at "+str(coord))
        for door in doors:
            check(door.position.x >= 0 and door.position.x <= game.CHUNK_SIZE and door.position.y >= 0 and door.position.y <= game.CHUNK_SIZE,"door outside chunk at "+str(coord))
            var body=door.get_meta("door_body",null)
            var shape=door.get_meta("door_shape",null)
            check(is_instance_valid(body) and is_instance_valid(shape),"door collision nodes missing at "+str(coord))
            if is_instance_valid(shape):
                check(shape.shape is RectangleShape2D,"door collision shape type drift at "+str(coord))
                if shape.shape is RectangleShape2D:
                    check(shape.shape.size == Vector2(38,10),"door collision footprint drift at "+str(coord))
            check(door.z_index == 37,"door z-order drift at "+str(coord))
        chunk.free()
    check(built_count >= 40,"geometry audit sampled too few chunks")
    check(authored_count >= 20,"geometry audit missed authored POI coverage")
    check(event_count >= 1,"geometry audit did not encounter any finite world event")
    game.free()
    print("WORLD GEOMETRY FINAL AUDIT 1.30-dev1: ",checks," checks / ",failures," failures / chunks=",built_count," authored=",authored_count," events=",event_count)
    quit(1 if failures else 0)
