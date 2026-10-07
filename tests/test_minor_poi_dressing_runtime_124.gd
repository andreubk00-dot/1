extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const MinorPoiDressing = preload("res://world/minor_poi_dressing.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _dressing_nodes(root:Node) -> Array:
    var out:Array = []
    for child in root.get_children():
        if bool(child.get_meta("minor_poi_dressing",false)):
            out.append(child)
    return out

func run() -> void:
    var game = Harness.new(); root.add_child(game)
    await process_frame
    var samples = [
        ["dacha_coop_zarya",Vector2i(-1,0)],
        ["dacha_coop_zarya",Vector2i(0,1)],
        ["dacha_coop_zarya",Vector2i(-1,1)],
        ["military_checkpoint",Vector2i(0,-1)],
        ["district_police",Vector2i(1,0)],
        ["hunting_cordon",Vector2i(1,0)]
    ]
    for sample in samples:
        var poi_id:String = sample[0]
        var offset:Vector2i = sample[1]
        var poi = RegionCatalog.poi_by_id(poi_id)
        var coord:Vector2i = poi.get("coord",Vector2i.ZERO) + offset
        var chunk = Node2D.new(); game.add_child(chunk)
        check(game._build_major_poi_chunk(chunk,coord,game._chunk_profile(coord)),poi_id + " production POI chunk build failed")
        var nodes = _dressing_nodes(chunk)
        var expected = MinorPoiDressing.accents_for(poi_id,offset)
        check(nodes.size() == expected.size(),poi_id + " runtime dev3 accent count mismatch")
        var kinds = {}
        for node in nodes:
            kinds[str(node.get_meta("world_prop_kind",""))] = true
            check(str(node.get_meta("minor_poi_id","")) == poi_id,poi_id + " runtime accent lost POI identity")
            check(str(node.get_meta("minor_poi_cell","")) == MinorPoiDressing.cell_key(offset),poi_id + " runtime accent lost cell identity")
        for accent in expected:
            check(kinds.has(str(accent.get("kind",""))),poi_id + " runtime accent missing " + str(accent.get("kind","")))
        chunk.queue_free()
    game.free()
    print("MINOR POI DRESSING RUNTIME 1.24-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
