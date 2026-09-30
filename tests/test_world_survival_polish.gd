extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks = 0
var failures = 0

func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func add_wall(game,pos,size = Vector2(4,90)):
    var body = StaticBody2D.new()
    body.position = pos
    body.collision_layer = game.LAYER_WORLD
    body.collision_mask = 0
    game.add_child(body)
    var shape_node = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    return body

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    # Runtime balance must use production infected speed, not the old dev slow-motion.
    check(abs(game.ENEMY_SPEED - 60.0) < 0.001,"infected must use production base speed")
    check(game.MOVE_SPEED > game.ENEMY_SPEED,"healthy player walk must remain slightly faster than infected")
    check(game.MOVE_SPEED * game.SPRINT_SPEED_MULT > game.ENEMY_SPEED + 20.0,"sprint must create a meaningful escape gap")

    game.player.global_position = Vector2.ZERO
    game.inventory_open = false
    game.tracer = Line2D.new()
    game.add_child(game.tracer)
    game.muzzle_flash = Polygon2D.new()
    game.add_child(game.muzzle_flash)
    game.aim_direction = Vector2.RIGHT
    var free_muzzle = game._clamped_player_forward_point(Vector2.RIGHT,26.0,1.5)
    check(abs(free_muzzle.x - 26.0) < 0.01,"free muzzle point must keep authored 26px offset")

    var wall = add_wall(game,Vector2(15,0))
    await physics_frame
    var blocked_muzzle = game._clamped_player_forward_point(Vector2.RIGHT,26.0,1.5)
    check(blocked_muzzle.x > 0.0 and blocked_muzzle.x < 13.5,"muzzle must stay on near side of wall")
    var blocked_drop = game._clamped_player_forward_point(Vector2.RIGHT,34.0,4.0)
    check(blocked_drop.x > 0.0 and blocked_drop.x < 12.0,"drop point must stay on near side of wall")

    # Firearm integration: no damage through a wall even when the visual muzzle would
    # normally sit beyond it.
    game.inventory_entries = [{"id":"makarov","qty":1,"x":0,"y":0}]
    game.current_weapon_id = "makarov"
    game.equipped_melee_id = ""
    var pm_iid = game.set_test_weapon_state("makarov",8)
    game._switch_weapon("makarov",pm_iid)
    game.fire_cooldown = 0.0
    var target = game._spawn_enemy(game,Vector2i.ZERO,900,Vector2(55,0))
    var hp_before = float(target.get_meta("hp",70.0))
    game._fire_weapon()
    check(abs(float(target.get_meta("hp",70.0)) - hp_before) < 0.001,"firearm must not damage infected through solid wall")
    check(game._weapon_mag_value("makarov",pm_iid) == 7,"blocked shot must still consume the fired round")

    # Melee already had a LOS check; retain it during the world-polish changes.
    check(not game._melee_line_clear(target.global_position),"melee must remain blocked by world geometry")

    # Interaction target behind the same wall must not be selectable.
    var container = Node2D.new()
    container.position = Vector2(34,0)
    container.add_to_group("interactable")
    container.set_meta("interaction_type","container")
    container.set_meta("container_key","qa:container")
    container.set_meta("display_name","QA")
    game.add_child(container)
    check(not game._interactable_reachable(container),"container behind wall must be unreachable")
    check(game._nearest_interactable() == null,"nearest interaction must not tunnel through wall")

    wall.queue_free()
    await physics_frame
    check(game._interactable_reachable(container),"container must become reachable when wall is removed")
    check(game._nearest_interactable() == container,"reachable container must become the interaction target")

    # Firing without the wall should damage the same target.
    game.fire_cooldown = 0.0
    game._set_weapon_mag_value("makarov",8,pm_iid)
    game._fire_weapon()
    check(float(target.get_meta("hp",70.0)) < hp_before,"clear firearm shot must damage infected")

    container.queue_free()
    target.queue_free()
    await process_frame

    # Local steering must route around ordinary solid geometry without introducing a
    # second AI state machine.
    var steer_enemy = game._spawn_enemy(game,Vector2i.ZERO,901,Vector2.ZERO)
    var steer_wall = add_wall(game,Vector2(19,0),Vector2(5,110))
    await physics_frame
    var steered = game._enemy_local_steer(steer_enemy,Vector2.RIGHT)
    check(steered.x > 0.05,"avoidance must still make forward progress")
    check(abs(steered.y) > 0.15,"solid wall ahead must produce a side-steering component")
    var sid_parity = posmod(int(steer_enemy.get_meta("spawn_id",0)),2)
    check((steered.y > 0.0) == (sid_parity == 1),"equal-clearance steering must be stable per infected")

    steer_wall.queue_free()
    await physics_frame
    var straight = game._enemy_local_steer(steer_enemy,Vector2.RIGHT)
    check(straight.distance_to(Vector2.RIGHT) < 0.001,"clear route must not be altered by avoidance")

    # Physics integration: a short ordinary wall must be bypassed instead of becoming
    # a permanent walking-in-place trap.
    steer_enemy.global_position = Vector2.ZERO
    var short_wall = add_wall(game,Vector2(24,0),Vector2(6,34))
    await physics_frame
    for step in range(90):
        game._enemy_move_toward(steer_enemy,Vector2(90,0),game.ENEMY_SPEED,[steer_enemy])
        await physics_frame
    check(steer_enemy.global_position.x > 34.0,"infected must physically get past a short solid obstacle")
    check(steer_enemy.global_position.distance_to(Vector2(90,0)) < 58.0,"infected must keep progressing toward remembered goal after avoidance")
    short_wall.queue_free()
    await physics_frame

    # Breachable defenses keep ownership of their approach logic; local avoidance
    # must not cause infected to dodge an intact door they are meant to attack.
    var door = game._create_door(game,Vector2i(55,55),Vector2(24,0),"qa_world_polish_door")
    await physics_frame
    var toward_door = game._enemy_local_steer(steer_enemy,Vector2.RIGHT)
    check(toward_door.dot(Vector2.RIGHT) > 0.99,"local steering must not dodge active breachable door")

    # Loot generation remains deterministic, themed and grid-valid after the world pass.
    var tables = ["pharmacy","grocery","garage","residential","industrial","military","forest_cache","rural"]
    for table_name in tables:
        check(game.loot_tables.has(table_name),"missing loot table: %s" % table_name)
        var first = game._generate_loot("qa:%s" % table_name,table_name)
        var second = game._generate_loot("qa:%s" % table_name,table_name)
        check(first == second,"loot must be deterministic for persistent container key: %s" % table_name)
        for entry in first:
            var id = str(entry.get("id",""))
            check(game.item_defs.has(id),"loot table emitted unknown item %s in %s" % [id,table_name])
            check(int(entry.get("x",-1)) >= 0 and int(entry.get("y",-1)) >= 0,"loot entry must have valid grid position: %s" % id)

    # Quickbar remains a direct selector and must not fire while inventory UI owns input.
    game.inventory_entries = [
        {"id":"makarov","qty":1,"x":0,"y":0},
        {"id":"combat_knife","qty":1,"x":2,"y":0}
    ]
    game.inventory_open = false
    check(game._select_quick_slot(1) and game.current_weapon_id == "makarov","quick slot 1 must still select firearm")
    check(game._select_quick_slot(4) and game.equipped_melee_id == "combat_knife","quick slot 4 must still select melee")
    game.inventory_open = true
    check(not game._select_quick_slot(1),"quick slots must stay disabled while inventory is open")

    door.queue_free()
    steer_enemy.queue_free()
    game.free()
    print("WORLD SURVIVAL POLISH: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
