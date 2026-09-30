extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var failures = 0
var checks = 0

func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    var door = game._create_door(game,Vector2i(999,999),Vector2.ZERO,"pressure_test")
    var enemy = game._spawn_enemy(game,Vector2i.ZERO,0,Vector2(0,-18))
    game.player.position = Vector2(0,18)
    enemy.set_meta("last_known_position",Vector2(0,60))
    enemy.set_meta("heard_position",Vector2(0,60))
    enemy.set_meta("search_anchor",Vector2(0,60))
    enemy.set_meta("ai_state","chase")
    await physics_frame
    await physics_frame
    check(game._enemy_door_obstacle(enemy,"chase") == door,"pursuit finds closed doorway")
    check(game._enemy_door_obstacle(enemy,"investigate") == door,"heard goal can lead to door")
    check(game._enemy_door_obstacle(enemy,"search") == door,"search retains remembered doorway")
    check(game._enemy_door_obstacle(enemy,"idle") == null,"idle does not attack doors")
    check(game._enemy_door_obstacle(enemy,"return") == null,"returning does not attack doors")
    enemy.set_meta("last_known_position",Vector2(80,-18))
    check(game._enemy_door_obstacle(enemy,"chase") == null,"nearby door unrelated to goal ignored")
    enemy.set_meta("last_known_position",Vector2(0,60))
    var wall = game._add_static_rect(game,Vector2(0,-10),Vector2(50,2))
    await physics_frame
    await physics_frame
    check(game._enemy_door_obstacle(enemy,"chase") == null,"wall before door prevents remote blows")
    wall.free()
    await physics_frame
    enemy.position = Vector2(0,-55)
    check(game._enemy_door_obstacle(enemy,"chase") == null,"door outside reach ignored")
    enemy.position = Vector2(0,-11)
    game.player.position = Vector2(0,11)
    enemy.set_meta("can_see_player",true)
    check(not game._enemy_can_hit_player(enemy),"fresh closed door blocks hit despite cached vision")
    game._apply_door_state(door,true,true)
    await physics_frame
    await physics_frame
    check(game._enemy_can_hit_player(enemy),"open doorway permits melee")
    check(game._enemy_door_obstacle(enemy,"chase") == null,"open door cannot be bashed")
    check(not game._enemy_strike_door(enemy,door),"open door rejects extra strike")
    game._apply_door_state(door,false,true)
    enemy.position = Vector2(0,-18)
    game.player.position = Vector2(0,60)
    var listener = game._spawn_enemy(game,Vector2i.ZERO,1,Vector2(30,-25))
    await physics_frame
    await physics_frame
    var remembered = enemy.get_meta("heard_position")
    game.last_player_noise_time = 0.0
    for i in range(3):
        check(game._enemy_strike_door(enemy,door),"closed door accepts blow")
        game._update_doors(1.2)
        var expected_hp = game.DOOR_MAX_CONDITION - game.DOOR_HIT_DAMAGE * float(i + 1)
        check(abs(float(door.get_meta("door_condition",-1.0)) - expected_hp) < 0.01,"door HP must be the only breach progress")
        check(not bool(door.get_meta("door_open")),"first three blows keep door shut")
    check(float(listener.get_meta("suspicion")) > 0.0,"door blows attract other infected")
    check(enemy.get_meta("heard_position") == remembered,"own sound does not erase goal")
    check(game.last_player_noise_time == 0.0,"infected sound not shown as player noise")
    check(game._enemy_strike_door(enemy,door),"fourth structural hit must be accepted")
    check(abs(float(door.get_meta("door_condition",-1.0))) < 0.01,"fourth hit must reduce door HP to zero")
    check(bool(door.get_meta("door_open")),"zero-HP door must become an open breach")
    check(bool(game.door_states["999:999:door:pressure_test"]),"breached door uses saved open state")
    check(door.get_meta("door_body").collision_layer == 0,"breach clears physical obstruction")
    listener.free()
    await physics_frame

    # Reset structural state for production-update/cooldown checks.
    var reset_rec = game._door_defense_record(door)
    reset_rec["condition"] = game.DOOR_MAX_CONDITION
    game._set_breach_state_record(str(door.get_meta("door_key","")),reset_rec)
    game._refresh_door_defense(door)
    game.door_states[str(door.get_meta("door_key",""))] = false
    game._apply_door_state(door,false,true)

    enemy.position = Vector2(0,-22)
    enemy.set_meta("ai_state","chase")
    enemy.set_meta("can_see_player",false)
    enemy.set_meta("sense_cd",100.0)
    enemy.set_meta("attack_cd",0.0)
    enemy.set_meta("lost_sight_time",2.1)
    enemy.set_meta("last_known_position",Vector2(0,60))
    await physics_frame
    await physics_frame
    game._update_enemies(0.2)
    check(abs(float(door.get_meta("door_condition",0.0)) - 75.0) < 0.01,"production update strikes obstructing door once")
    check(str(enemy.get_meta("ai_state")) == "search","lost sight searches instead of tracking player")
    game._update_enemies(0.1)
    check(abs(float(door.get_meta("door_condition",0.0)) - 75.0) < 0.01,"cooldown prevents per-frame blows")
    enemy.set_meta("attack_cd",0.0)
    enemy.set_meta("stagger",1.0)
    game._update_enemies(0.1)
    check(abs(float(door.get_meta("door_condition",0.0)) - 75.0) < 0.01,"stagger prevents door attack")
    enemy.set_meta("stagger",0.0)
    for i in range(45):
        await physics_frame
        game._update_doors(0.1)
        game._update_enemies(0.1)
    check(bool(door.get_meta("door_open")),"production search persists long enough to breach")
    check(float(door.get_meta("door_condition",1.0)) <= 0.01,"production breach must still be driven by HP")
    game.free()
    print("SHELTER DOOR BREACH CORE: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
