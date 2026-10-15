extends SceneTree
# dev63 marauders: squads spawn on clear ground, notice and fight the player,
# leave searchable bodies with their gear (saved with the world), a coward
# surrenders and drops the gun, a neutral warns before turning hostile, the
# director keeps at most two squads and lets them go when the player leaves.
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

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(10)
    for e in game.get_tree().get_nodes_in_group("infected"):
        e.queue_free()
    var dir = game.marauder_director
    check(dir != null, "no marauder director")
    for o in ["gopnik", "bandit", "deserter"]:
        for w in ["makarov", "akm", "shotgun", "none"]:
            check(ResourceLoader.exists("res://art/marauders/%s_%s_Walk.png" % [o, w]), "missing sheet %s %s" % [o, w])

    # hostile squad engages a player standing in the open
    var p = game.player.global_position
    var sq = dir.spawn_squad(dir.SQUAD_TYPES[2], p + Vector2(220, 0))
    check(sq != null and sq.members.size() >= 2, "hostile squad did not spawn")
    for m in sq.members:
        check(dir._free_at(m.global_position), "marauder spawned inside geometry")
        check(m.is_in_group("marauders") and m.has_meta("is_enemy"), "marauder not targetable")
    var hp0 = game.health
    await frames(480)
    var fighting = sq.alive().filter(func(m): return m.state == "combat").size()
    check(fighting >= 1, "squad never engaged the player")
    check(game.health < hp0, "squad engaged but never hurt the player")
    check(game.health > 0.0 or game.player_death_time > 0.0, "health went negative")

    # killed: bodies with their weapons, saved and restored
    game.health = 100.0
    for m in sq.members.duplicate():
        if is_instance_valid(m):
            game._damage_enemy(m, 500.0, Vector2.RIGHT)
    await frames(90)
    var bodies = game.player_bodies.filter(func(b): return str(b.get("kind", "")) == "marauder")
    check(bodies.size() == sq.members.size(), "not every marauder left a body")
    var weapons_found = 0
    for b in bodies:
        var key = "%d:%d:container:%s" % [b["coord"][0], b["coord"][1], b["id"]]
        for e in game.container_states.get(key, {}).get("items", []):
            if game.weapon_defs.has(str(e.get("id", ""))):
                weapons_found += 1
    check(weapons_found == bodies.size(), "a marauder body lacks its gun")
    var spots = []
    for n in game.get_tree().get_nodes_in_group("player_bodies"):
        for s in spots:
            check(s.distance_to(n.global_position) >= 13.9, "bodies lie on top of each other")
        spots.append(n.global_position)
    game._save_state()
    var g2 = Main.new()
    root.add_child(g2)
    await frames(5)
    check(g2.player_bodies.filter(func(b): return str(b.get("kind", "")) == "marauder").size() == bodies.size(), "marauder bodies lost on reload")
    g2.queue_free()
    await frames(2)

    # coward surrenders and drops the gun
    var sqc = dir.spawn_squad(dir.SQUAD_TYPES[1], game.player.global_position + Vector2(-160, 0))
    var mc = sqc.members[0]
    await frames(90)
    game._damage_enemy(mc, 50.0, Vector2.LEFT)
    await frames(20)
    check(mc.surrendered and mc.weapon_dropped and mc.state == "surrender", "coward did not surrender")
    var drops = game.dropped_items.filter(func(d): return str(d.get("id", "")) == mc.weapon)
    check(not drops.is_empty(), "surrendered coward did not drop the weapon")

    # neutral: warns, then turns when a gun stays on them
    var sqn = dir.spawn_squad(dir.SQUAD_TYPES[3], game.player.global_position + Vector2(0, 140))
    var mn = sqn.members[0]
    sqn.route = [mn.global_position]
    sqn.leg = 0
    await frames(90)
    check(not mn.hostile_to_player, "neutral attacked unprovoked")
    game.qa_bot_driver = true
    var warned = false
    for i in range(420):
        game.qa_locked_aim = (mn.global_position - game.player.global_position).normalized()
        await physics_frame
        if mn.bark_label.visible and mn.bark_label.text in mn.BARKS["aim"]:
            warned = true
    check(warned, "neutral never warned about the raised gun")
    check(mn.hostile_to_player, "neutral ignored a gun pointed at them")
    game.qa_bot_driver = false

    # director: at most two squads, gone when the player leaves
    for s in dir.squads.duplicate():
        dir._remove(s)
    dir.age = 999.0
    var most = 0
    for k in range(40):
        dir.check_t = 0.0
        await physics_frame
        most = max(most, dir.squads.size())
    check(most >= 1 and most <= dir.MAX_SQUADS, "director squad count out of range: " + str(most))
    game.developer_invulnerable = true
    game.player.global_position += Vector2(3200, 0)
    game._refresh_chunks(true)
    await frames(20)
    check(dir.squads.is_empty(), "squads stayed after the player left")

    print("MARAUDERS dev63: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
