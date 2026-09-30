extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var checks = 0
var failures = 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
func _initialize():
    call_deferred("run")
func fresh():
    var game = Harness.new()
    root.add_child(game)
    game.player.position = Vector2(1000,1000)
    return game
func walk(game,enemies,target,steps):
    for i in range(steps):
        await physics_frame
        for enemy in enemies:
            game._enemy_move_toward(enemy,target,game.ENEMY_SPEED,enemies)
func run():
    var game = fresh()
    var enemy = game._spawn_enemy(game,Vector2i.ZERO,900,Vector2.ZERO)
    game._add_static_rect(game,Vector2(55,0),Vector2(10,220))
    await walk(game,[enemy],Vector2(140,0),520)
    check(enemy.position.distance_to(Vector2(140,0)) < 15,"long wall must be bypassed physically")
    game.free()

    game = fresh()
    enemy = game._spawn_enemy(game,Vector2i.ZERO,900,Vector2.ZERO)
    game._add_static_rect(game,Vector2(55,0),Vector2(10,170))
    game._add_static_rect(game,Vector2(95,-80),Vector2(90,10))
    game._add_static_rect(game,Vector2(115,45),Vector2(12,50))
    await walk(game,[enemy],Vector2(165,0),650)
    check(enemy.position.distance_to(Vector2(165,0)) < 15,"corner and successive obstacles must not trap infected")
    game.free()

    game = fresh()
    var group = []
    for i in range(3):
        group.append(game._spawn_enemy(game,Vector2i.ZERO,910+i,Vector2(-i*16,(i-1)*18)))
    game._add_static_rect(game,Vector2(65,-60),Vector2(10,84))
    game._add_static_rect(game,Vector2(65,60),Vector2(10,84))
    await walk(game,group,Vector2(150,0),420)
    for member in group:
        check(member.position.x > 100,"group member must cross narrow doorway")
    game.free()
    game = fresh()
    enemy = game._spawn_enemy(game,Vector2i.ZERO,900,Vector2.ZERO)
    game._add_static_rect(game,Vector2(60,0),Vector2(10,160))
    game._add_static_rect(game,Vector2(0,-80),Vector2(130,10))
    game._add_static_rect(game,Vector2(0,80),Vector2(130,10))
    await walk(game,[enemy],Vector2(140,0),900)
    check(enemy.position.distance_to(Vector2(140,0)) < 15,"U-shaped dead end requires moving away from goal before bypass")
    game.free()
    # Cache invalidation must follow the supplied goal/state, never player position.
    game = fresh()
    enemy = game._spawn_enemy(game,Vector2i.ZERO,920,Vector2.ZERO)
    enemy.set_meta("ai_state","investigate")
    enemy.set_meta("navigation_state","investigate")
    enemy.set_meta("navigation_goal",Vector2(140,0))
    enemy.set_meta("navigation_path",[Vector2(0,-60)])
    var direction = game._enemy_navigation_direction(enemy,Vector2(-100,0),Vector2.LEFT)
    check(direction.dot(Vector2.LEFT) > 0.99,"retarget discards stale waypoints")
    enemy.set_meta("navigation_path",[Vector2(0,-60)])
    enemy.set_meta("navigation_state","chase")
    direction = game._enemy_navigation_direction(enemy,Vector2(-100,0),Vector2.LEFT)
    check(direction.dot(Vector2.LEFT) > 0.99,"state transition discards stale route")
    enemy.set_meta("navigation_path",[])
    direction = game._enemy_navigation_direction(enemy,Vector2(100,0),Vector2.RIGHT)
    game.player.position = Vector2(-700,700)
    check(game._enemy_navigation_direction(enemy,Vector2(100,0),Vector2.RIGHT) == direction,"hidden player movement cannot redirect geometric planning")
    var door = game._create_door(game,Vector2i.ZERO,Vector2(0,-22),"navigation")
    await physics_frame
    await physics_frame
    enemy.set_meta("navigation_path",[Vector2(0,-60)])
    enemy.set_meta("navigation_goal",Vector2(0,-100))
    direction = game._enemy_navigation_direction(enemy,Vector2(0,-100),Vector2.UP)
    check(direction.dot(Vector2.UP) > 0.99,"intact door remains an approach target")
    check(enemy.get_meta("navigation_path").is_empty(),"closed defense cancels cached passage")
    check(not game._enemy_navigation_segment_clear(enemy,Vector2.ZERO,Vector2(0,-60)),"body sweep rejects closed doorway")
    game._apply_door_state(door,true,true)
    await physics_frame
    await physics_frame
    check(game._enemy_navigation_segment_clear(enemy,Vector2.ZERO,Vector2(0,-60)),"opening door makes route physically available")
    game.free()

    game = fresh()
    enemy = game._spawn_enemy(game,Vector2i.ZERO,930,Vector2.ZERO)
    for spec in [[Vector2(40,0),Vector2(10,100)],[Vector2(-40,0),Vector2(10,100)],
        [Vector2(0,-45),Vector2(90,10)],[Vector2(0,45),Vector2(90,10)]]:
        game._add_static_rect(game,spec[0],spec[1])
    await physics_frame
    await physics_frame
    var result = game.LocalNavigation.plan(Vector2.ZERO,Vector2(140,0),func(from,to): return game._enemy_navigation_segment_clear(enemy,from,to))
    check(result["path"].is_empty(),"sealed room produces no invented path")
    check(int(result["expanded"]) <= game.LocalNavigation.MAX_EXPANSIONS,"unreachable search has a hard work limit")
    enemy.set_meta("ai_state","investigate")
    enemy.set_meta("ai_state_time",1.0)
    enemy.set_meta("heard_position",Vector2(140,0))
    for i in range(1200):
        await physics_frame
        game._update_enemies(1.0/60.0)
    check(str(enemy.get_meta("ai_state")) == "idle","unreachable sound search expires instead of pursuing forever")
    check(abs(enemy.position.x) < 40 and abs(enemy.position.y) < 45,"unreachable route never tunnels through walls")
    game.free()
    print("INFECTED NAVIGATION: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
