extends SceneTree
# QA (1.47): a sweep over the world for placement bugs - props on cars or
# inside buildings, furniture inside furniture, NPCs and loot in walls, doors
# blocked, windows on windows. Prints one AUDIT line per problem.
#   godot --headless --path . --script tests/qa_world_audit.gd [-- --qa-step=3]
const Main = preload("res://main_script_mod.gd")
var game
var counts = {}
var seen = {}
var checked = {}

func _initialize():
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func report(kind: String, msg: String) -> void:
    if seen.has(msg):
        return
    seen[msg] = true
    counts[kind] = counts.get(kind, 0) + 1
    if counts[kind] <= 25:
        print("AUDIT ", kind, " | ", msg)

func sprite_rect(s: Sprite2D) -> Rect2:
    var r = s.get_rect()
    var xf = s.get_global_transform()
    return Rect2(xf * r.position, xf.basis_xform(r.size)).abs()

func blocked_at(space, p: Vector2, radius: float, exclude: Array) -> Array:
    var q = PhysicsShapeQueryParameters2D.new()
    var c = CircleShape2D.new()
    c.radius = radius
    q.shape = c
    q.transform = Transform2D(0.0, p)
    q.collision_mask = 1
    q.exclude = exclude
    return space.intersect_shape(q, 4)

func body_name(hit) -> String:
    var o = hit.get("collider")
    if o == null:
        return "?"
    var spr = o.get_meta("prop_sprite", null) if o.has_meta("prop_sprite") else null
    if is_instance_valid(spr):
        return "prop:" + str(spr.get_meta("world_prop_kind", spr.get_meta("street_furniture_kind", "")))
    var p = o.get_parent()
    return str(o.name) + "@" + (str(p.name) if p else "")

func run():
    Engine.set_meta("ostatok_new_game", true)
    game = Main.new()
    root.add_child(game)
    await frames(10)
    game.developer_invulnerable = true
    var step = 3
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--qa-step="):
            step = int(a.trim_prefix("--qa-step="))
    var stops = []
    for y in range(-12, 13, step):
        for x in range(-12, 13, step):
            stops.append(Vector2i(x, y))
    stops.append(Vector2i(-8, -2))
    for stop in stops:
        game._qa_move_to_world_chunk(stop)
        await frames(8)
        audit(str(stop))
    var total = 0
    for k in counts:
        total += counts[k]
        print("AUDIT_COUNT ", k, " ", counts[k])
    print("AUDIT_CHECKED ", checked)
    print("WORLD AUDIT: ", total, " problems over ", stops.size(), " stops")
    quit(0)

func tick(k: String) -> void:
    checked[k] = checked.get(k, 0) + 1

func audit(where: String) -> void:
    var space = game.get_world_2d().direct_space_state
    var buildings = []
    for b in game.get_tree().get_nodes_in_group("world_buildings"):
        if is_instance_valid(b) and b.has_meta("building_size") and not b.is_queued_for_deletion():
            var sz: Vector2 = b.get_meta("building_size")
            buildings.append([b, Rect2(b.global_position - sz * 0.5, sz)])
    var cars = []
    for c in game.get_tree().get_nodes_in_group("world_cars"):
        if is_instance_valid(c) and not c.is_queued_for_deletion():
            cars.append(c)
    # outdoor props: on a car, inside a building
    for ch in game.find_children("Chunk_*", "", true, false):
        for n in ch.get_children():
            if not (n is Sprite2D) or n.is_queued_for_deletion() or not n.visible:
                continue
            var kind = str(n.get_meta("world_prop_kind", n.get_meta("street_furniture_kind", "")))
            if kind == "" or game._interior_kind_walkable(kind):
                continue
            var p = n.global_position
            for c in cars:
                var lp = (p - c.global_position).rotated(-c.rotation)
                if abs(lp.x) < 26 and abs(lp.y) < 9:
                    report("prop_on_car", "%s %s at %s on a car" % [where, kind, str(p.round())])
            for br in buildings:
                if br[1].size.x < 420 and br[1].grow(-8).has_point(p):
                    report("prop_in_building", "%s outdoor %s at %s inside %s" % [where, kind, str(p.round()), str(br[0].get_meta("building_id", ""))])
    # furniture inside furniture
    for br in buildings:
        var b = br[0]
        var bodies = []
        for c in b.get_children():
            if c is StaticBody2D and c.has_meta("prop_solid_body") and not c.is_queued_for_deletion():
                for s in c.get_children():
                    if s is CollisionShape2D and s.shape is RectangleShape2D:
                        bodies.append([c, Rect2(c.global_position + s.position - s.shape.size * 0.5, s.shape.size)])
        for i in range(bodies.size()):
            for j in range(i + 1, bodies.size()):
                var r1: Rect2 = bodies[i][1]
                var r2: Rect2 = bodies[j][1]
                var inter = r1.intersection(r2)
                if inter.get_area() > 0.35 * min(r1.get_area(), r2.get_area()):
                    report("furniture_overlap", "%s %s: %s and %s overlap" % [where, str(b.get_meta("building_id", "")), body_name({"collider": bodies[i][0]}), body_name({"collider": bodies[j][0]})])
    # 1.50: standing pieces on each other or on a partition (by what they draw)
    for br in buildings:
        var b = br[0]
        var feet = []
        var keep_pts = []
        for n in game.get_tree().get_nodes_in_group("interactable"):
            if is_instance_valid(n) and b.get_parent().is_ancestor_of(n):
                keep_pts.append(n.global_position)

        for c in b.get_children():
            if game._standing_piece(c):
                feet.append([c, game._prop_foot(c), game._prop_body_rect(c), game._prop_drawn_rect(c), game._near_any(c.global_position, keep_pts, 16.0)])
        tick("pieces")
        var parts = b.get_meta("partitions", [])
        for i in range(feet.size()):
            for w in parts:
                if not feet[i][4] and feet[i][3].grow(-1.0).intersects(w):
                    report("piece_on_wall", "%s %s: %s stands on a partition" % [where, str(b.get_meta("building_id", "")), str(feet[i][0].get_meta("world_prop_kind", ""))])
                    break
            for j in range(i + 1, feet.size()):
                if feet[i][2].grow(-1.5).intersects(feet[j][2].grow(-1.5)):
                    var near_cache = false
                    report("piece_on_piece", "%s %s: %s on %s" % [where, str(b.get_meta("building_id", "")), str(feet[i][0].get_meta("world_prop_kind", "")), str(feet[j][0].get_meta("world_prop_kind", ""))])
    # NPCs standing in solids
    for npc in game.get_tree().get_nodes_in_group("faction_npcs"):
        if not is_instance_valid(npc) or npc.is_queued_for_deletion():
            continue
        var ex = [game.player.get_rid()]
        if npc is CollisionObject2D:
            ex.append(npc.get_rid())
        for c in npc.find_children("*", "CollisionObject2D", true, false):
            ex.append(c.get_rid())
        tick("npcs")
        var hits = blocked_at(space, npc.global_position + Vector2(0, 3), 5.0, ex)
        for h in hits:
            report("npc_in_solid", "%s npc %s at %s inside %s" % [where, str(npc.get_meta("npc_id", npc.name)), str(npc.global_position.round()), body_name(h)])
    # loot in solids
    for it in game.get_tree().get_nodes_in_group("world_items"):
        if not is_instance_valid(it) or it.is_queued_for_deletion():
            continue
        var ex2 = [game.player.get_rid()]
        for c in it.find_children("*", "CollisionObject2D", true, false):
            ex2.append(c.get_rid())
        tick("items")
        var hits2 = blocked_at(space, it.global_position, 3.0, ex2)
        if not hits2.is_empty():
            # reachable from a side is fine; fully surrounded is not
            var free = false
            for d in [Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(0, -14)]:
                if blocked_at(space, it.global_position + d, 6.0, ex2).is_empty():
                    free = true
            if not free:
                report("loot_buried", "%s item at %s inside %s" % [where, str(it.global_position.round()), body_name(hits2[0])])
    # front doors: a solid right in front or behind
    for br in buildings:
        var b = br[0]
        var sz: Vector2 = b.get_meta("building_size")
        tick("doors")
        var door = b.global_position + Vector2(float(b.get_meta("door_local_x", 0.0)), sz.y * 0.5)
        for off in [Vector2(0, -16), Vector2(0, 16)]:
            var hits3 = blocked_at(space, door + off, 6.0, [game.player.get_rid()])
            for h in hits3:
                var nm = body_name(h)
                if nm.begins_with("prop:") or nm.find("Car") >= 0:
                    report("door_blocked", "%s %s door %s blocked by %s" % [where, str(b.get_meta("building_id", "")), "inside" if off.y < 0 else "outside", nm])
    # windows on windows / on doors
    var wins = []
    for w in game.get_tree().get_nodes_in_group("architecture_windows"):
        if is_instance_valid(w) and w is Sprite2D and w.is_visible_in_tree() and not w.is_queued_for_deletion():
            wins.append(sprite_rect(w))
            tick("windows")
    var leaves = []
    for l in game.get_tree().get_nodes_in_group("front_door_leaves"):
        if is_instance_valid(l) and l is Sprite2D and l.is_visible_in_tree():
            leaves.append(sprite_rect(l))
    for i in range(wins.size()):
        for j in range(i + 1, wins.size()):
            var it2 = wins[i].intersection(wins[j])
            if abs(wins[i].get_center().y - wins[j].get_center().y) < 8 and it2.get_area() > 0.25 * min(wins[i].get_area(), wins[j].get_area()):
                report("window_overlap", "%s windows at %s and %s overlap" % [where, str(wins[i].get_center().round()), str(wins[j].get_center().round())])
        for l in leaves:
            if wins[i].intersection(l).get_area() > 0.2 * min(wins[i].get_area(), l.get_area()):
                report("window_on_door", "%s window at %s over a door" % [where, str(wins[i].get_center().round())])
