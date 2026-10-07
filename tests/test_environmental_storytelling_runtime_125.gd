extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const EnvironmentalStoryCatalog = preload("res://world/environmental_story_catalog.gd")
const EncounterCatalog = preload("res://world/encounter_catalog.gd")
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
    for raw_key in EnvironmentalStoryCatalog.CLUES.keys():
        var parts = str(raw_key).split(",")
        var coord = Vector2i(int(parts[0]),int(parts[1]))
        var profile = RegionCatalog.chunk_profile(coord)
        var event = EncounterCatalog.event_for(coord,str(profile.get("zone","residential")),int(profile.get("risk",2)),str(profile.get("poi_id","")))
        var chunk = Node2D.new(); game.add_child(chunk)
        check(game._build_world_event(chunk,coord,profile,event),str(coord) + " production encounter build failed")
        var nodes = _story_nodes(chunk)
        check(nodes.size() == 1,str(coord) + " runtime must contain exactly one authored story clue")
        if nodes.size() == 1:
            var clue = EnvironmentalStoryCatalog.clue_for(coord,str(event.get("id","")))
            var node:Node = nodes[0]
            check(str(node.get_meta("story_id","")) == str(clue.get("id","")),str(coord) + " runtime story id mismatch")
            check(str(node.get_meta("story_text","")) == str(clue.get("text","")),str(coord) + " runtime story text mismatch")
            check(str(node.get_meta("display_name","")) == str(clue.get("prompt","")),str(coord) + " runtime story prompt mismatch")
            check(node.is_in_group("interactable"),str(coord) + " runtime story clue is not interactable")
        chunk.queue_free()
    game.free()
    print("ENVIRONMENTAL STORYTELLING RUNTIME 1.25-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
