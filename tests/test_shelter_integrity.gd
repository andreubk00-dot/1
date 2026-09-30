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

    # 0.94/0.95 saves did not store barricade durability. Migration must keep them intact.
    game.base_objects = [{"id":2,"kind":"barricade","x":0.0,"y":0.0,"rot":0.0}]
    game.next_base_id = 3
    game._sanitize_base_objects()
    check(abs(float(game.base_objects[0].get("condition",-1.0)) - game.BARRICADE_MAX_CONDITION) < 0.001,
        "legacy barricade must migrate as intact")

    game._create_base_system()
    var barrier = game.base_object_nodes.get(2,null)
    check(is_instance_valid(barrier),"barricade node must spawn")
    check(str(barrier.get_meta("interaction_type","")) == "base_barricade","barricade must be interactable")
    var body = barrier.get_meta("barricade_body",null)
    check(is_instance_valid(body) and body.collision_layer == game.LAYER_WORLD,"intact barricade must block the world layer")

    var enemy = game._spawn_enemy(game,Vector2i.ZERO,0,Vector2(0,-20))
    game.player.position = Vector2(0,60)
    enemy.set_meta("last_known_position",Vector2(0,60))
    enemy.set_meta("heard_position",Vector2(0,60))
    enemy.set_meta("search_anchor",Vector2(0,60))
    enemy.set_meta("ai_state","chase")
    await physics_frame
    await physics_frame

    check(game._enemy_breachable_obstacle(enemy,"chase") == barrier,
        "pursuit must recognize intact barricade as the first breachable obstacle")
    check(game._enemy_door_obstacle(enemy,"chase") == null,
        "legacy door helper must not misclassify barricades")

    check(game._enemy_strike_barricade(enemy,barrier),"infected must be able to strike barricade")
    check(abs(float(game.base_objects[0]["condition"]) - 78.0) < 0.001,
        "first strike must reduce condition by configured damage")

    for i in range(4):
        game._enemy_strike_barricade(enemy,barrier)
    check(float(game.base_objects[0]["condition"]) == 0.0,"sustained pressure must break barricade")
    check(body.collision_layer == 0,"broken barricade must stop blocking movement")
    var sprite = barrier.get_meta("barricade_sprite",null)
    check(is_instance_valid(sprite) and str(sprite.get_meta("world_prop_kind","")) == "barricade_scraps",
        "broken barricade must switch to scrap visual")
    await physics_frame
    check(game._enemy_breachable_obstacle(enemy,"chase") == null,
        "broken barricade must not remain a breach target")

    game.inventory_entries = []
    check(not game._repair_base_barricade(barrier),"repair without materials must fail")
    game._grid_add(game.inventory_entries,"scrap",3,game.INV_W,game.INV_H)
    game._grid_add(game.inventory_entries,"tape",1,game.INV_W,game.INV_H)
    check(game._repair_base_barricade(barrier),"broken barricade must accept field repair with scrap and tape")
    check(abs(float(game.base_objects[0]["condition"]) - game.BARRICADE_REPAIR_AMOUNT) < 0.001,
        "first repair must restore configured condition")
    check(body.collision_layer == game.LAYER_WORLD,"repaired barricade must block again")
    check(game._inventory_count("tape") == 0,"rebuilding a broken barricade must consume tape")
    check(game._inventory_count("scrap") == 2,"each repair must consume one scrap")

    check(game._repair_base_barricade(barrier),"damaged barricade must accept reinforcement")
    check(game._inventory_count("scrap") == 1,"reinforcement must consume another scrap")
    check(float(game.base_objects[0]["condition"]) > game.BARRICADE_REPAIR_AMOUNT,
        "reinforcement must improve condition")

    # Production AI update must use the generic breach path, not a test-only helper.
    enemy.position = Vector2(0,-20)
    enemy.set_meta("ai_state","chase")
    enemy.set_meta("can_see_player",false)
    enemy.set_meta("sense_cd",100.0)
    enemy.set_meta("attack_cd",0.0)
    enemy.set_meta("lost_sight_time",0.0)
    enemy.set_meta("last_known_position",Vector2(0,60))
    await physics_frame
    await physics_frame
    var before = float(game.base_objects[0]["condition"])
    game._update_enemies(0.2)
    check(float(game.base_objects[0]["condition"]) < before,
        "production enemy update must damage blocking barricade")

    game.free()
    print("SHELTER INTEGRITY: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
