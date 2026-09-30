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

    game.expedition_journal["home"] = {
        "key":"0:0:building_2","name":"Штурмовой тест","chunk":[0,0],
        "position":[0.0,0.0],"bounds":[-60.0,-60.0,120.0,120.0]
    }
    game.roof_records = []
    game.player.position = Vector2(0,0)

    var door = game._create_door(game,Vector2i(0,0),Vector2(-48,48),"building_2")
    var enemy = game._spawn_enemy(game,Vector2i.ZERO,31,Vector2(-48,82))
    enemy.set_meta("spawn_id",31)
    enemy.set_meta("last_known_position",Vector2(-48,-40))
    enemy.set_meta("heard_position",Vector2(-48,-40))
    enemy.set_meta("search_anchor",Vector2(-48,-40))
    enemy.set_meta("ai_state","chase")
    await physics_frame
    await physics_frame

    var hp_before = float(door.get_meta("door_condition",game.DOOR_MAX_CONDITION))
    check(game._enemy_strike_door(enemy,door),"door strike must remain functional")
    check(float(door.get_meta("door_condition",game.DOOR_MAX_CONDITION)) < hp_before,"door strike must reduce the existing structural HP")
    check(game.shelter_assault_last_event_ms > 0,"home defense hit must mark a recent attack")
    check(game._shelter_assault_state_text() == "ИДЁТ АТАКА","recent hit must expose only the simple attack state")
    game.shelter_assault_last_event_ms = -1000000
    check(game._shelter_assault_state_text() == "","attack state must clear after the grace window")

    # A destroyed window is a route only when the remembered direct route is blocked.
    var facade = Node2D.new()
    game.add_child(facade)
    var window_visual = game._tall_facade_window(facade,0,0,Vector2(42,0))
    window_visual.set_meta("breach_window_x",42.0)
    var window_node = game._create_shelter_window(game,Vector2i(0,0),"building_2",0,Vector2(42,0),facade,42.0,0)
    var window_key = str(window_node.get_meta("breach_key",""))
    var window_rec = game.shelter_breach_states[window_key].duplicate(true)
    window_rec["condition"] = 0.0
    game.shelter_breach_states[window_key] = window_rec
    game._refresh_shelter_window(window_node)
    check(game._breach_node_open(window_node),"zero-HP window must be an open passage")
    check(not game._breach_node_active(window_node),"open passage must not remain a strike target")

    enemy.position = Vector2(0,70)
    enemy.set_meta("last_known_position",Vector2(0,-70))
    enemy.set_meta("heard_position",Vector2(0,-70))
    enemy.set_meta("search_anchor",Vector2(0,-70))
    var route_wall = game._add_static_rect(game,Vector2(0,35),Vector2(28,8))
    await physics_frame
    await physics_frame
    check(game._enemy_preferred_open_entry(enemy,"chase") == window_node,"blocked infected must use an existing breach")
    route_wall.free()
    await physics_frame
    await physics_frame
    check(game._enemy_preferred_open_entry(enemy,"chase") == null,"clear direct route must not detour through a breach")

    # Intrusion has one concrete meaning: someone is inside. It does not create
    # pressure tiers or a second damage model.
    enemy.position = Vector2(10,10)
    enemy.set_meta("ai_state","return")
    enemy.set_meta("shelter_intruder",false)
    game._update_shelter_assault(0.1)
    check(game.shelter_intruders_active == 1,"infected inside home bounds must count as an intruder")
    check(str(enemy.get_meta("ai_state","")) == "search","intruder must search/chase inside instead of attacking furniture")
    check(enemy.get_meta("search_anchor",Vector2(999,999)) == game.player.global_position,"intruder search must anchor on the player")
    check(game._shelter_assault_state_text() == "ПРОНИКНОВЕНИЕ","UI must name active intrusion directly")
    check(game.player.get_meta("shelter_intruders_active",0) == 1,"threat indicator metadata must receive intrusion count")

    var door_rec = game._door_defense_record(door)
    door_rec["condition"] = 40.0
    game._set_breach_state_record(str(door.get_meta("door_key","")),door_rec)
    game._refresh_door_defense(door)
    game.inventory_entries = [
        {"id":"scrap","qty":4,"x":0,"y":0},
        {"id":"tape","qty":4,"x":1,"y":0}
    ]
    check(game._shelter_intruders_block_repair(door),"repair must remain blocked while an infected is inside")
    check(not game._repair_shelter_door(door),"door repair must be rejected during intrusion")

    # Old 1.02/1.03 furniture durability is accepted but stripped: furniture is
    # normal furniture again and stored loot is never disabled by raid HP.
    game.base_objects = [
        {"id":901,"kind":"stash","x":0.0,"y":0.0,"rot":0.0,"raid_condition":0.0},
        {"id":902,"kind":"lamp","x":18.0,"y":0.0,"rot":0.0,"on":false,"raid_condition":12.0}
    ]
    game.container_states["base_stash_901"] = {"name":"Старый ящик","items":[{"id":"water","qty":2,"x":0,"y":0}]}
    game._sanitize_base_objects()
    check(not game.base_objects[0].has("raid_condition") and not game.base_objects[1].has("raid_condition"),"obsolete furniture raid HP must be removed during normalization")
    game._create_base_system()
    await process_frame
    var stash = game.base_object_nodes.get(901,null)
    check(is_instance_valid(stash) and str(stash.get_meta("interaction_type","")) == "container","legacy damaged stash must become a normal container")
    check(not stash.is_in_group("shelter_interior_targets"),"furniture must not remain a separate raid target system")
    check(game._home_stashes(false).has("base_stash_901"),"legacy raid HP must not hide a home stash or its contents")

    enemy.position = Vector2(180,180)
    game._update_shelter_assault(0.2)
    check(game.shelter_intruders_active == 0,"intruder count must clear after infected leaves")
    check(not game._shelter_intruders_block_repair(door),"repairs may resume after the shelter is clear")

    var indicator = game._ensure_shelter_threat_indicator()
    game.shelter_intruders_active = 1
    game.player.set_meta("shelter_intruders_active",1)
    check(indicator._intruders_active() == 1,"threat indicator must expose intrusion without a pressure meter")

    game.free()
    await process_frame

    # Production geometry: an infected outside a real facade must physically use
    # the destroyed window and cross into the shelter.
    var route_game = Harness.new()
    root.add_child(route_game)
    await process_frame
    route_game.roof_records = []
    route_game._create_building(route_game,Vector2i(92,92),"qa_route",Vector2(500,500),Vector2(180,150),"ЖИЛОЙ ДОМ",Color("6f7068"),true)
    await physics_frame
    await physics_frame
    var route_record = route_game.roof_records[0]
    var route_rect = route_record["rect"]
    route_game.expedition_journal["home"] = {
        "key":"92:92:qa_route","name":"QA","chunk":[92,92],
        "position":[500.0,500.0],
        "bounds":[route_rect.position.x,route_rect.position.y,route_rect.size.x,route_rect.size.y]
    }
    var route_window = null
    for candidate in get_nodes_in_group("shelter_windows"):
        if str(candidate.get_meta("breach_key","")).find("qa_route:0") >= 0:
            route_window = candidate
            break
    check(is_instance_valid(route_window),"production facade must expose a breach window")
    if is_instance_valid(route_window):
        var route_key = str(route_window.get_meta("breach_key",""))
        var route_state = route_game.shelter_breach_states[route_key].duplicate(true)
        route_state["condition"] = 0.0
        route_game.shelter_breach_states[route_key] = route_state
        route_game._refresh_shelter_window(route_window)
        route_game.player.global_position = Vector2(456,520)
        var route_enemy = route_game._spawn_enemy(route_game,Vector2i.ZERO,777,Vector2(456,592))
        route_enemy.set_meta("ai_state","chase")
        route_enemy.set_meta("last_known_position",route_game.player.global_position)
        route_enemy.set_meta("heard_position",route_game.player.global_position)
        route_enemy.set_meta("search_anchor",route_game.player.global_position)
        route_enemy.set_meta("sense_cd",100.0)
        route_enemy.set_meta("can_see_player",false)
        route_enemy.set_meta("lost_sight_time",0.0)
        route_enemy.set_meta("attack_cd",0.0)
        var used_open_entry = false
        var became_intruder = false
        for _step in range(150):
            await physics_frame
            route_game._update_enemies(1.0 / 60.0)
            route_game._update_shelter_assault(1.0 / 60.0)
            if str(route_enemy.get_meta("assault_entry_key","")) == route_key:
                used_open_entry = true
            if route_game.shelter_intruders_active > 0:
                became_intruder = true
                break
        check(used_open_entry,"infected must select the destroyed window as its route")
        check(became_intruder,"infected must physically cross the breach")
        check(route_game._home_rect_contains_enemy(route_enemy,route_rect),"crossing must place infected inside the real home bounds")
    route_game.free()
    await process_frame

    print("SHELTER ASSAULT CORE: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
