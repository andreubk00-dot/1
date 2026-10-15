extends SceneTree
# dev66: raiders remember the survivor. A man searched and let go may come
# back along the road alone, knows the face, and pays his debt once (a useful
# thing, rounds for the survivor's gun, a tip). Shooting men with their hands
# up gets round: after two, cowards fight to the death instead of giving up,
# until the rumour fades a few days on. Every raider has a name his mates shout.
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

func _open_spot(game, p: Vector2, r: float) -> Vector2:
    # a free spot with a clear line to the player
    var dir = game.marauder_director
    for k in range(16):
        var c = p + Vector2(r, 0).rotated(TAU * k / 16.0)
        var q = PhysicsRayQueryParameters2D.create(c, p)
        q.collision_mask = game.LAYER_WORLD
        if dir._free_at(c) and game.get_world_2d().direct_space_state.intersect_ray(q).is_empty():
            return c
    return p + Vector2(r, 0)

func _surrender(game, type_index: int):
    var dir = game.marauder_director
    var sq = dir.spawn_squad(dir.SQUAD_TYPES[type_index], _open_spot(game, game.player.global_position, 120.0))
    var m = sq.members[0]
    m.squad = sq
    await frames(5)
    m.hp = m.max_hp * 0.5
    m._surrender()
    await frames(2)
    return m

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(8)
    game.developer_invulnerable = true
    game.world_minutes = 12.0 * 60.0
    for e in game.get_tree().get_nodes_in_group("infected"):
        e.queue_free()
    var dir = game.marauder_director

    # names
    var nicks = {}
    for i in range(12):
        var t = dir.spawn_squad(dir.SQUAD_TYPES[3], _open_spot(game, game.player.global_position, 400.0))
        nicks[t.members[0].nick] = true
        dir._remove(t)
    check(nicks.size() >= 5, "raiders all share a handful of names: " + str(nicks.size()))

    # searched and let go: remembered
    var m = await _surrender(game, 1)
    var nick = m.nick
    check(m.state == "surrender", "test coward did not give up")
    game._search_captive(m)
    var spared: Array = dir.memory["spared"]
    check(spared.size() == 1 and str(spared[0]["nick"]) == nick, "the man let go is not remembered")
    for s in dir.squads.duplicate():
        dir._remove(s)
    await frames(2)

    # not on the same day; the next day he may come back alone
    check(dir._reunion_type() == null, "the spared man came back the same day")
    game.world_day += 1
    var rec = dir._reunion_type()
    check(rec != null, "the spared man never comes back")
    if rec != null:
        var sq = dir.spawn_reunion(rec, _open_spot(game, game.player.global_position, 110.0))
        var r = sq.members[0]
        sq.route = [r.global_position]
        sq.leg = 0
        check(r.nick == nick and r.has_meta("spared") and not r.hostile_to_player, "the man who came back is not the one let go")
        r.facing = (game.player.global_position - r.global_position).normalized()
        await frames(40)
        check(r.has_meta("greeted") and r.bark_label.visible, "he did not recognise the survivor")
        check(r.bark_label.text.find("отпустил") >= 0, "his greeting does not mention the mercy")
        check(dir._reunion_type() == null, "the same man can come back twice")
        var drops0 = game.dropped_items.size()
        game._talk_marauder(r)
        check(game.dropped_items.size() > drops0, "he did not pay his debt")
        check(bool(rec.get("paid", false)), "the debt is not marked paid")
        var drops1 = game.dropped_items.size()
        game._talk_marauder(r)
        check(game.dropped_items.size() == drops1, "he paid twice")
        check(game.discovered_pois.has("marauder_base"), "his tip did not point to the base")
        # saved and restored with his memory
        game._save_state()
        var g2 = Main.new()
        root.add_child(g2)
        await frames(5)
        var back = g2.marauder_director.memory["spared"]
        check(back.size() == 1 and bool(back[0].get("paid", false)) and str(back[0]["nick"]) == nick, "raider memory lost on reload")
        var again = false
        for s2 in g2.marauder_director.squads:
            for x in s2.alive():
                if x.nick == nick and x.has_meta("spared"):
                    again = true
        check(again, "the grateful man near the survivor was not restored")
        g2.queue_free()
        await frames(2)
    for s in dir.squads.duplicate():
        dir._remove(s)
    await frames(2)

    # killing men with their hands up
    check(not dir.no_mercy(), "no mercy before any execution")
    for i in range(2):
        var c = await _surrender(game, 1)
        check(c.state == "surrender", "coward %d did not give up" % i)
        game._damage_enemy(c, 500.0, Vector2.RIGHT)
        await frames(4)
        for s in dir.squads.duplicate():
            dir._remove(s)
        await frames(2)
    check(int(dir.memory["executions"]) == 2 and dir.no_mercy(), "executions were not counted")
    var dir_sq = dir.spawn_squad(dir.SQUAD_TYPES[1], _open_spot(game, game.player.global_position, 140.0))
    var hard = dir_sq.members[0]
    hard.last_seen_pos = game.player.global_position
    hard.last_seen_time = Time.get_ticks_msec() / 1000.0
    hard._set_state("combat")
    hard.hp = hard.max_hp * 0.5
    await frames(20)
    check(not hard.surrendered and hard.personality == "hostile", "a coward still gave up to the executioner")
    for s in dir.squads.duplicate():
        dir._remove(s)
    # the rumour fades
    game.world_day += 7
    check(not dir.no_mercy(), "the rumour of executions never fades")

    print("MARAUDER MEMORY dev66: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
