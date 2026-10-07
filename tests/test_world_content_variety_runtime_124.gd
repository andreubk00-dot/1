extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const BuildingCatalog = preload("res://world/building_catalog.gd")
const WorldContentVariety = preload("res://world/world_content_variety.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _find_different_variant(archetype_id:String,index:int,origin:Vector2i) -> Vector2i:
    var first = WorldContentVariety.variant_for(origin,archetype_id,index)
    for y in range(-6,7):
        for x in range(-6,7):
            var coord = Vector2i(x,y)
            if WorldContentVariety.variant_for(coord,archetype_id,index) != first:
                return coord
    return origin

func _prop_kinds(root:Node) -> Dictionary:
    var out = {}
    var stack:Array = [root]
    while not stack.is_empty():
        var node = stack.pop_back()
        if node.has_meta("world_prop_kind"):
            out[str(node.get_meta("world_prop_kind"))] = true
        for child in node.get_children():
            stack.append(child)
    return out

func run() -> void:
    var game = Harness.new(); root.add_child(game)
    await process_frame
    var origin = Vector2i(2,2)
    var other = _find_different_variant("grocery",0,origin)
    check(other != origin,"runtime test could not find a second grocery dressing variant")

    var chunks = []
    for coord in [origin,other]:
        var chunk = Node2D.new(); game.add_child(chunk); chunks.append(chunk)
        var data = BuildingCatalog.by_id("grocery")
        var variant = WorldContentVariety.variant_for(coord,"grocery",0)
        data["content_variant"] = variant
        data["content_seed"] = WorldContentVariety.visual_seed_key(coord,"grocery",0)
        var building = game._create_building(chunk,coord,"building_0",Vector2(180,150),Vector2(190,132),"ПРОДУКТЫ",data.get("color",Color("5a5042")),true,"grocery",data)
        check(str(building.get_meta("building_id","")) == "building_0","visual variety changed persistent building id")
        check(int(building.get_meta("content_variant",-1)) == variant,"runtime building lost derived content variant")
        check(str(building.get_meta("content_seed","")) == str(data["content_seed"]),"runtime building lost derived visual seed")
        check(abs(float(building.get_meta("door_local_x",999.0)) - float(data.get("door_x",0.0)) * 190.0) < 0.01,"visual variety changed authored door position")
        var kinds = _prop_kinds(chunk)
        var profile = WorldContentVariety.profile_for("grocery",variant)
        check(kinds.has(str(profile["interior"][0]["kind"])),"runtime interior accent missing")
        check(kinds.has(str(profile["facade"][0]["kind"])),"runtime facade accent missing")
        check(kinds.has(str(profile["yard"][0]["kind"])),"runtime yard accent missing")

    # Raw authored data intentionally bypasses dev1 variety: major POIs stay authored.
    var authored_chunk = Node2D.new(); game.add_child(authored_chunk)
    var authored = BuildingCatalog.by_id("grocery")
    var authored_building = game._create_building(authored_chunk,Vector2i(30,30),"building_0",Vector2(180,150),Vector2(190,132),"ПРОДУКТЫ",authored.get("color",Color("5a5042")),true,"grocery",authored)
    check(not authored_building.has_meta("content_variant") and not authored_building.has_meta("content_seed"),"authored POI building received procedural variety state")

    for chunk in chunks:
        chunk.queue_free()
    authored_chunk.queue_free()
    game.free()
    print("WORLD CONTENT VARIETY RUNTIME 1.24-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
