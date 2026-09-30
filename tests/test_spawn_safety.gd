extends SceneTree
var checks = 0
var failures = 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
const Main = preload("res://main_script_mod.gd")
func _initialize(): call_deferred("run")
func run():
    var g = Main.new()
    root.add_child(g)
    g.set_process(false)
    var total = 0
    var blocked = 0
    for coord in [Vector2i.ZERO,Vector2i(5,6),Vector2i(-5,-5),Vector2i(3,3),Vector2i(-4,3),Vector2i(-9,1),Vector2i(-7,2),Vector2i(7,-7),Vector2i(8,-5)]:
        g.player.global_position = Vector2(coord) * 768 + Vector2(384,384)
        g._refresh_chunks(true)
        await physics_frame
        await physics_frame
        for e in get_nodes_in_group("infected"):
            if e.is_queued_for_deletion(): continue
            total += 1
            var q = PhysicsShapeQueryParameters2D.new()
            var shape = CapsuleShape2D.new()
            shape.radius = 8.0
            shape.height = 24.0
            q.shape = shape
            q.transform = Transform2D(0,e.global_position + Vector2(0,4))
            q.collision_mask = g.LAYER_WORLD
            var hits = g.get_world_2d().direct_space_state.intersect_shape(q)
            check(hits.is_empty(),"infected overlaps world at %s / %s" % [str(e.get_meta("chunk_coord")),str(e.get_meta("spawn_id"))])
            check(not bool(e.get_meta("spawn_pending",false)),"spawn validation must finish before AI starts")
            if not hits.is_empty():
                blocked += 1
                if blocked <= 12: print("BLOCKED ",e.get_meta("chunk_coord")," ",e.get_meta("spawn_id")," ",e.position," collider=",hits[0].collider.get_parent().name)
    print("SPAWN OVERLAP: ",blocked,"/",total)
    check(total >= 200,"representative loaded-sector population must remain present")
    g.free()
    print("SPAWN SAFETY: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
