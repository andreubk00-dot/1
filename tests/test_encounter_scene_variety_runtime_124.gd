extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const EncounterSceneVariety = preload("res://world/encounter_scene_variety.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _prop_kinds(root:Node) -> Dictionary:
    var out = {}
    for child in root.get_children():
        if child.has_meta("world_prop_kind"):
            out[str(child.get_meta("world_prop_kind"))] = int(out.get(str(child.get_meta("world_prop_kind")),0)) + 1
    return out

func run() -> void:
    var game = Harness.new(); root.add_child(game)
    await process_frame
    var samples = {
        "abandoned_camp":Vector2i(-20,-20),
        "failed_evacuation":Vector2i(-6,-20),
        "repair_breakdown":Vector2i(10,12),
        "looted_convoy":Vector2i(14,12),
        "feeding_site":Vector2i(12,10)
    }
    for event_id in samples.keys():
        var coord:Vector2i = samples[event_id]
        var scene = Node2D.new(); game.add_child(scene)
        var expected_variant = EncounterSceneVariety.variant_for(coord,event_id)
        var result = game._decorate_world_event_variant(scene,coord,event_id)
        check(result == expected_variant,event_id + " runtime variant mismatch")
        check(int(scene.get_meta("scene_variant",-1)) == expected_variant,event_id + " runtime root lost derived scene variant")
        var kinds = _prop_kinds(scene)
        var accents = EncounterSceneVariety.accents_for(coord,event_id)
        var sprite_total = 0
        for count in kinds.values(): sprite_total += int(count)
        check(sprite_total == 2,event_id + " runtime variety added wrong number of prop sprites")
        for accent in accents:
            check(kinds.has(str(accent.get("kind",""))),event_id + " runtime cosmetic accent missing: " + str(accent.get("kind","")))
        scene.queue_free()

    var supply = Node2D.new(); game.add_child(supply)
    check(game._decorate_world_event_variant(supply,Vector2i(5,5),"supply_convoy") == -1,"supply convoy received dev2 runtime variety")
    check(supply.get_child_count() == 0 and not supply.has_meta("scene_variant"),"supply convoy runtime scene was modified")
    supply.queue_free(); game.free()
    print("ENCOUNTER SCENE VARIETY RUNTIME 1.24-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
