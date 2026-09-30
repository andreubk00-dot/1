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
    game.shelter_breach_states = {}
    game.base_objects = []
    game._create_base_system()

    check(game._breachable_window_xs("ЖИЛОЙ ДОМ",Vector2(180,150),"qa_house",0.0).size() >= 1,
        "residential facade must expose ground-floor defense windows")
    check(game._breachable_window_xs("ЦЕХ",Vector2(220,170),"qa_factory",0.0).is_empty(),
        "industrial gates must not be misclassified as ordinary windows")

    # Production building integration: the south wall must be segmented around
    # actual defense windows so a broken window becomes a real route, not decoration.
    game._create_building(game,Vector2i(92,92),"qa_building",Vector2(500,500),Vector2(180,150),"ЖИЛОЙ ДОМ",Color("6f7068"),true)
    await physics_frame
    await physics_frame
    var integrated_window = null
    for candidate in get_nodes_in_group("shelter_windows"):
        if is_instance_valid(candidate) and str(candidate.get_meta("breach_key","")).find("qa_building") >= 0:
            integrated_window = candidate
            break
    check(is_instance_valid(integrated_window),"production building must create a linked defense window")
    if is_instance_valid(integrated_window):
        check(is_instance_valid(integrated_window.get_meta("window_visual",null)),"defense window must own the matching facade visual")
        var probe = PhysicsRayQueryParameters2D.create(integrated_window.global_position + Vector2(0,26),integrated_window.global_position + Vector2(0,-26),game.LAYER_WORLD)
        var hit = game.get_world_2d().direct_space_state.intersect_ray(probe)
        check(not hit.is_empty() and game._collider_breach_node(hit.get("collider",null)) == integrated_window,
            "south wall opening must expose window collision as first obstruction")

    var facade = Node2D.new()
    game.add_child(facade)
    var visual = game._tall_facade_window(facade,0,0,Vector2(0,-24))
    visual.set_meta("breach_window_x",0.0)
    var window_node = game._create_shelter_window(game,Vector2i(90,90),"qa_house",0,Vector2(55,0),facade,0.0,0)
    await physics_frame
    await physics_frame
    check(is_instance_valid(window_node),"defense window must spawn")
    check(str(window_node.get_meta("interaction_type","")) == "shelter_window","window must be interactable")
    check(window_node.get_meta("window_body").collision_layer == game.LAYER_WORLD,"intact window must block entry")

    var enemy_a = game._spawn_enemy(game,Vector2i.ZERO,20,Vector2(0,-60))
    var enemy_b = game._spawn_enemy(game,Vector2i.ZERO,21,Vector2(10,-62))
    game.player.position = Vector2(0,80)
    for enemy in [enemy_a,enemy_b]:
        enemy.set_meta("last_known_position",game.player.position)
        enemy.set_meta("heard_position",game.player.position)
        enemy.set_meta("search_anchor",game.player.position)
        enemy.set_meta("ai_state","chase")
    var blank_wall = game._add_static_rect(game,Vector2(0,0),Vector2(70,10))
    await physics_frame
    await physics_frame
    check(game._enemy_preferred_breach_point(enemy_a,"chase") == window_node,
        "infected must steer toward a visible weak point instead of blank wall")
    blank_wall.free()
    await physics_frame

    var before = float(window_node.get_meta("window_condition"))
    check(game._enemy_strike_window(enemy_a,window_node),"first infected must damage window")
    check(game._enemy_strike_window(enemy_b,window_node),"second infected must add pressure to same window")
    check(float(window_node.get_meta("window_condition")) < before - game.WINDOW_HIT_DAMAGE,
        "multiple infected must accumulate structural damage")
    check(game._enemy_strike_window(enemy_a,window_node),"third blow must finish ordinary window")
    check(float(window_node.get_meta("window_condition")) == 0.0,"ordinary window must breach after sustained blows")
    check(window_node.get_meta("window_body").collision_layer == 0,"breached window must become traversable")
    check(int(visual.get_meta("window_state",-1)) == 1,"breached window must switch to broken visual state")

    game.inventory_entries = [
        {"id":"scrap","qty":8,"x":0,"y":0},
        {"id":"tape","qty":4,"x":1,"y":0}
    ]
    enemy_a.position = window_node.position + Vector2(0,-20)
    enemy_a.set_meta("attack_anim",0.20)
    check(not game._repair_shelter_window(window_node),"repair must be blocked while infected is actively striking")
    enemy_a.set_meta("attack_anim",0.0)
    check(game._repair_shelter_window(window_node),"breached window must accept field repair")
    check(bool(window_node.get_meta("window_reinforced",false)),"rebuilt window must become reinforced")
    check(window_node.get_meta("window_body").collision_layer == game.LAYER_WORLD,"repaired window must block again")
    check(int(visual.get_meta("window_state",-1)) == 2,"reinforced window must use boarded visual state")

    var saved_condition = float(window_node.get_meta("window_condition"))
    var saved_key = str(window_node.get_meta("breach_key"))
    var saved_state = game.shelter_breach_states[saved_key].duplicate(true)
    game.shelter_breach_states = {saved_key:saved_state}
    check(abs(float(game._breach_state_record(saved_key,"window",game.WINDOW_MAX_CONDITION)["condition"]) - saved_condition) < 0.001,
        "window integrity state must survive dictionary reload")

    var door = game._create_door(game,Vector2i(91,91),Vector2(150,0),"qa_door")
    for i in range(4):
        game._enemy_strike_door(enemy_a,door)
        game._update_doors(1.2)
    check(bool(door.get_meta("door_open",false)),"sustained door pressure must still breach on established rhythm")
    check(float(door.get_meta("door_condition",-1.0)) == 0.0,"breached door must retain structural damage")
    enemy_a.set_meta("attack_anim",0.0)
    game.player.position = Vector2(300,200)
    check(game._repair_shelter_door(door),"breached door must be repairable with existing materials")
    check(float(door.get_meta("door_condition",0.0)) > 0.0,"door repair must restore integrity")
    check(not bool(door.get_meta("door_open",true)),"repaired clear doorway should close again")

    game.free()
    print("SHELTER DEFENSE & BREACH: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
