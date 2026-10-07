extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const PoiStoryCatalog = preload("res://world/poi_story_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _story_nodes(root:Node) -> Array:
    var out:Array = []
    var stack:Array = [root]
    while not stack.is_empty():
        var node:Node = stack.pop_back()
        if str(node.get_meta("interaction_type","")) == "story_clue": out.append(node)
        for child in node.get_children(): stack.append(child)
    return out

func run() -> void:
    var game = Harness.new(); root.add_child(game)
    await process_frame
    for raw_key in PoiStoryCatalog.ENTRIES.keys():
        var clue:Dictionary = PoiStoryCatalog.ENTRIES[raw_key]
        var poi_id = str(clue.get("poi_id",""))
        var offset:Vector2i = clue.get("cell",Vector2i.ZERO)
        var poi = RegionCatalog.poi_by_id(poi_id)
        var coord:Vector2i = poi.get("coord",Vector2i(999,999)) + offset
        var profile = RegionCatalog.chunk_profile(coord)
        check(str(profile.get("poi_id","")) == poi_id,str(raw_key) + " runtime coordinate no longer belongs to target POI")
        var chunk = Node2D.new(); chunk.position = Vector2(coord) * game.CHUNK_SIZE; game.add_child(chunk)
        check(game._build_major_poi_chunk(chunk,coord,profile),str(raw_key) + " production POI build failed")
        var nodes = _story_nodes(chunk)
        check(nodes.size() == 1,str(raw_key) + " runtime must contain exactly one authored story clue")
        if nodes.size() == 1:
            var node:Node = nodes[0]
            check(str(node.get_meta("story_id","")) == str(clue.get("id","")),str(raw_key) + " runtime story id mismatch")
            check(str(node.get_meta("story_text","")) == str(clue.get("text","")),str(raw_key) + " runtime story text mismatch")
            check(node.is_in_group("interactable"),str(raw_key) + " runtime story clue is not interactable")
        chunk.queue_free()
    game.free()
    print("AUTHORED POI STORYTELLING RUNTIME 1.25-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
