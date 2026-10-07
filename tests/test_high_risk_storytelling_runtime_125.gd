extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const HighRiskStoryCatalog = preload("res://world/high_risk_story_catalog.gd")
const HighRiskFloorCatalog = preload("res://world/high_risk_floor_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok: failures += 1; printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")
func _story_nodes(root:Node) -> Array:
    var out:Array=[]; var stack:Array=[root]
    while not stack.is_empty():
        var node:Node=stack.pop_back()
        if str(node.get_meta("interaction_type","")) == "story_clue": out.append(node)
        for child in node.get_children(): stack.append(child)
    return out
func run() -> void:
    var game=Harness.new(); root.add_child(game); await process_frame
    for entry in HighRiskStoryCatalog.GROUND.values():
        var poi_id=str(entry.get("poi_id","")); var cell:Vector2i=entry.get("cell",Vector2i.ZERO)
        var poi=RegionCatalog.poi_by_id(poi_id); var coord:Vector2i=poi.get("coord",Vector2i.ZERO)+cell
        var chunk=Node2D.new(); chunk.position=Vector2(coord)*game.CHUNK_SIZE; game.add_child(chunk)
        check(game._build_major_poi_chunk(chunk,coord,RegionCatalog.chunk_profile(coord)),poi_id+" ground build failed")
        var matches=[]
        for node in _story_nodes(chunk):
            if str(node.get_meta("story_id","")) == str(entry.get("id","")): matches.append(node)
        check(matches.size()==1,poi_id+" ground runtime story missing/duplicated")
        chunk.queue_free()
    for entry in HighRiskStoryCatalog.FLOORS.values():
        var poi_id=str(entry.get("poi_id","")); var floor_index=int(entry.get("floor",3))
        var floor_root=Node2D.new(); game.add_child(floor_root)
        game._build_high_risk_floor(floor_root,poi_id,floor_index,HighRiskFloorCatalog.floor(poi_id,floor_index))
        var matches=[]
        for node in _story_nodes(floor_root):
            if str(node.get_meta("story_id","")) == str(entry.get("id","")): matches.append(node)
        check(matches.size()==1,poi_id+" floor runtime story missing/duplicated")
        floor_root.queue_free()
    game.free()
    print("HIGH RISK STORYTELLING RUNTIME 1.25-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
