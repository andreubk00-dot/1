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

    check(game._shelter_visual_stage(100.0,100.0) == 0,"intact shelter point must use clean visual stage")
    check(game._shelter_visual_stage(60.0,100.0) == 1,"moderate damage must use worn stage")
    check(game._shelter_visual_stage(30.0,100.0) == 2,"heavy damage must use critical visual stage")
    check(game._shelter_visual_stage(0.0,100.0) == 3,"zero HP must use breach stage")

    var facade = Node2D.new()
    game.add_child(facade)
    var visual = game._tall_facade_window(facade,0,0,Vector2.ZERO)
    visual.set_meta("breach_window_x",0.0)
    var window_node = game._create_shelter_window(game,Vector2i(40,40),"qa_visual",0,Vector2(40,0),facade,0.0,0)
    var window_overlay = window_node.get_node_or_null("ShelterDamageVisual")
    check(window_overlay != null,"window must own procedural damage overlay")
    check(int(window_node.get_meta("visual_damage_stage",-1)) == 0,"new window must begin visually intact")

    var enemy = game._spawn_enemy(game,Vector2i.ZERO,0,window_node.position + Vector2(0,-20))
    game._enemy_strike_window(enemy,window_node)
    check(int(window_node.get_meta("visual_damage_stage",-1)) == 1,"first window hit must expose visible wear")
    game._enemy_strike_window(enemy,window_node)
    check(int(window_node.get_meta("visual_damage_stage",-1)) == 2,"second window hit must expose critical damage")
    game._enemy_strike_window(enemy,window_node)
    check(int(window_node.get_meta("visual_damage_stage",-1)) == 3,"broken window must expose breach stage")
    check(window_overlay._recently_attacked(),"recent strike must activate attack-point indicator")

    enemy.set_meta("attack_anim",0.0)
    enemy.position += Vector2(100,0)
    game.inventory_entries = []
    game._grid_add(game.inventory_entries,"scrap",3,game.INV_W,game.INV_H)
    game._grid_add(game.inventory_entries,"tape",1,game.INV_W,game.INV_H)
    check(game._repair_shelter_window(window_node),"broken window must still repair after visual pass")
    check(int(window_node.get_meta("visual_damage_stage",-1)) < 3,"window repair must immediately restore non-breached visual")
    check(bool(window_node.get_meta("visual_reinforced",false)),"rebuilt window visual must remember reinforcement")

    var door = game._create_door(game,Vector2i(41,41),Vector2(120,0),"qa_visual_door")
    var door_overlay = door.get_node_or_null("ShelterDamageVisual")
    check(door_overlay != null,"door must own procedural damage overlay")
    game._enemy_strike_door(enemy,door)
    game._enemy_strike_door(enemy,door)
    check(int(door.get_meta("visual_damage_stage",-1)) == 1,"half-damaged door must switch to worn stage")
    game._enemy_strike_door(enemy,door)
    check(int(door.get_meta("visual_damage_stage",-1)) == 2,"quarter-health door must switch to critical stage")
    game._enemy_strike_door(enemy,door)
    check(int(door.get_meta("visual_damage_stage",-1)) == 3,"destroyed door must switch to breach stage")

    game.base_objects = [{"id":99,"kind":"barricade","x":0.0,"y":70.0,"rot":0.0,"condition":100.0}]
    game.next_base_id = 100
    game._create_base_system()
    var barricade = game.base_object_nodes.get(99,null)
    check(is_instance_valid(barricade),"barricade must spawn for visual test")
    var barricade_overlay = barricade.get_node_or_null("ShelterDamageVisual") if is_instance_valid(barricade) else null
    check(barricade_overlay != null,"barricade must own procedural damage overlay")
    if is_instance_valid(barricade):
        for i in range(3):
            game._enemy_strike_barricade(enemy,barricade)
        check(int(barricade.get_meta("visual_damage_stage",-1)) == 2,"heavily damaged barricade must expose critical stage")
        game._enemy_strike_barricade(enemy,barricade)
        game._enemy_strike_barricade(enemy,barricade)
        check(int(barricade.get_meta("visual_damage_stage",-1)) == 3,"broken barricade must expose breach stage")
        check(barricade_overlay._recently_attacked(),"barricade impact must activate attack-point indicator")

    game.free()
    print("SHELTER VISUAL DAMAGE: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
