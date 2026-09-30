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
    await process_frame

    var door = game._create_door(game,Vector2i(77,77),Vector2(120,0),"qa_assault_door")
    check(door.is_in_group("shelter_defense_points"),"door must register as a shelter defense point")
    var enemy = game._spawn_enemy(game,Vector2i.ZERO,0,Vector2(120,-22))
    enemy.set_meta("spawn_id",17)
    var before_serial = int(door.get_meta("visual_fx_serial",0))
    check(game._enemy_strike_door(enemy,door),"enemy must strike shelter door")
    check(int(door.get_meta("visual_damage_stage",-1)) == 0,"first door hit should remain in intact HP band")
    check(game._enemy_strike_door(enemy,door),"second strike must advance shelter damage")
    check(int(door.get_meta("visual_damage_stage",-1)) == 1,"second door hit should enter worn stage")
    check(int(door.get_meta("visual_stage_change_from",-1)) == 0,"transition must remember previous stage")
    check(int(door.get_meta("visual_stage_change_to",-1)) == 1,"transition must remember destination stage")
    check(int(door.get_meta("visual_fx_serial",0)) == before_serial + 1,"damage stage transition must trigger one FX serial")
    var attack_dir = door.get_meta("breach_attack_dir",Vector2.ZERO)
    check(typeof(attack_dir) == TYPE_VECTOR2 and attack_dir.length() > 0.9,"strike must remember attack direction")
    var overlay = door.get_node_or_null("ShelterDamageVisual")
    check(overlay != null and overlay._transition_active(),"door transition FX must be active immediately after damage")

    var indicator = game._ensure_shelter_threat_indicator()
    check(indicator != null,"player must own shelter threat indicator")
    indicator._pick_active_target()
    check(indicator.tracked_target == door,"threat indicator must track the newest attacked defense point")
    check(indicator._target_direction().length() > 0.9,"threat indicator must expose a usable direction")

    var facade = Node2D.new()
    game.add_child(facade)
    var visual = game._tall_facade_window(facade,0,0,Vector2.ZERO)
    visual.set_meta("breach_window_x",0.0)
    var window_node = game._create_shelter_window(game,Vector2i(78,78),"qa_assault_window",0,Vector2(80,0),facade,0.0,0)
    check(window_node.is_in_group("shelter_defense_points"),"window must register as a shelter defense point")

    game.base_objects = [{"id":701,"kind":"barricade","x":160.0,"y":0.0,"rot":0.0,"condition":100.0}]
    game.next_base_id = 702
    game._create_base_system()
    var barricade = game.base_object_nodes.get(701,null)
    check(is_instance_valid(barricade) and barricade.is_in_group("shelter_defense_points"),"barricade must register as a shelter defense point")

    # Crowd scoring should push a new infected away from an already occupied entry.
    var crowd_a = game._spawn_enemy(game,Vector2i.ZERO,1,door.global_position + Vector2(6,0))
    var crowd_b = game._spawn_enemy(game,Vector2i.ZERO,2,door.global_position + Vector2(-5,0))
    var crowd_door = game._breach_candidate_crowd(door,enemy)
    var crowd_window = game._breach_candidate_crowd(window_node,enemy)
    check(crowd_door >= 2,"crowd helper must count infected already occupying a breach")
    check(crowd_window < crowd_door,"uncrowded breach must receive lower crowd count")
    check(game._breach_candidate_lane_bias(enemy,door) >= 0.0,"lane bias must be deterministic and non-negative")

    # Final breach must trigger the longer collapse burst instead of a bare state swap.
    for i in range(2):
        game._enemy_strike_door(enemy,door)
    check(int(door.get_meta("visual_damage_stage",-1)) == 3,"door must reach breached visual stage")
    check(overlay._breach_burst_active(),"final breach must start collapse/debris burst")
    check(int(door.get_meta("visual_stage_change_to",-1)) == 3,"final transition metadata must identify breach stage")

    crowd_a.queue_free()
    crowd_b.queue_free()
    game.free()
    print("SHELTER ASSAULT POLISH: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
