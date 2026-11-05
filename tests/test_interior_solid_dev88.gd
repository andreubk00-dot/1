extends SceneTree
# 1.43: furniture inside buildings is solid - and adding the bodies did not
# wall anyone in: from each door the survivor's own capsule still reaches most
# of the floor and every container in the room.
const Main = preload("res://main_script_mod.gd")
var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", msg)

func _initialize():
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func free_at(space, shape, p: Vector2, exclude: Array) -> bool:
    var q = PhysicsShapeQueryParameters2D.new()
    q.shape = shape
    q.transform = Transform2D(0.0, p + Vector2(0, 3))
    q.collision_mask = 1
    q.exclude = exclude
    return space.intersect_shape(q, 1).is_empty()

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(10)
    game.developer_invulnerable = true
    var shape = CapsuleShape2D.new()
    shape.radius = 7.0
    shape.height = 22.0
    var solid_props = 0
    var buildings = 0
    var stops = [Vector2i(0, 0), Vector2i(-8, -2), Vector2i(3, -4), Vector2i(-5, 5), Vector2i(6, 6)]
    for stop in stops:
        game._qa_move_to_world_chunk(stop)
        await frames(4)
        var space = game.get_world_2d().direct_space_state
        var exclude = [game.player.get_rid()]
        for b in game.get_tree().get_nodes_in_group("world_buildings"):
            if not is_instance_valid(b) or not b.has_meta("building_size"):
                continue
            var size: Vector2 = b.get_meta("building_size")
            if size.x < 90 or size.y < 70:
                continue
            for c in b.get_children():
                if c is Sprite2D and c.has_meta("prop_solid"):
                    solid_props += 1
            # flood the floor from just inside the door, on the survivor's capsule
            var door = b.global_position + Vector2(float(b.get_meta("door_local_x", 0.0)), size.y * 0.5 - 22.0)
            if not free_at(space, shape, door, exclude):
                continue    # a door we cannot stand in (a sealed / high-risk front): not this test's
            buildings += 1
            var step = 6.0
            var lo = b.global_position - size * 0.5 + Vector2(14, 14)
            var hi = b.global_position + size * 0.5 - Vector2(14, 14)
            var seen = {}
            var queue = [door.snapped(Vector2(step, step))]
            seen[queue[0]] = true
            var reached = []
            while not queue.is_empty() and reached.size() < 40000:
                var p = queue.pop_back()
                reached.append(p)
                for d in [Vector2(step, 0), Vector2(-step, 0), Vector2(0, step), Vector2(0, -step)]:
                    var n = p + d
                    if seen.has(n) or n.x < lo.x or n.y < lo.y or n.x > hi.x or n.y > hi.y:
                        continue
                    seen[n] = true
                    if free_at(space, shape, n, exclude):
                        queue.append(n)
            # every free cell of the floor is reached
            var free_cells = 0
            var y = lo.y
            while y <= hi.y:
                var x = lo.x
                while x <= hi.x:
                    var p = Vector2(x, y).snapped(Vector2(step, step))
                    if free_at(space, shape, p, exclude):
                        free_cells += 1
                    x += step
                y += step
            var share = float(reached.size()) / max(1.0, float(free_cells))
            check(share >= 0.85, "%s: only %.0f%% of the open floor is reachable from the door" % [str(b.get_meta("building_id", "")), share * 100.0])
            # every container in the room can be reached (within its use range)
            for n in game.get_tree().get_nodes_in_group("interactable"):
                if not is_instance_valid(n) or str(n.get_meta("interaction_type", "")) != "container":
                    continue
                var lp = n.global_position - b.global_position
                if abs(lp.x) > size.x * 0.5 or abs(lp.y) > size.y * 0.5:
                    continue
                var radius = float(n.get_meta("interaction_radius", 34.0))
                var ok = false
                for p in reached:
                    if p.distance_to(n.global_position) <= radius:
                        ok = true
                        break
                check(ok, "%s: a container at %s cannot be reached" % [str(b.get_meta("building_id", "")), str(lp.round())])
    check(buildings >= 4, "too few buildings walked (%d)" % buildings)
    check(solid_props >= 10, "the furniture has no bodies (%d solid props)" % solid_props)
    print("INTERIOR SOLID dev88: ", checks, " checks, ", failures, " failures (", buildings, " buildings, ", solid_props, " solid props)")
    quit(1 if failures else 0)
