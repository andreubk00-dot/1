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

    # the first people met on the road: the trader, before any raiders
    check(not bool(dir.memory.get("met_trader", false)), "a new world starts with the trader already met")
    dir.age = dir.FIRST_TRADER_DELAY + 1.0
    dir.check_t = 0.0
    await frames(3)
    var first = dir.squads.filter(func(q): return str(q.kind.get("trader", "")) != "")
    check(first.size() == 1 and dir.memory["met_trader"], "the trader did not come first")
    check(dir.squads.size() == 1, "raiders came along with the first trader")
    for q in dir.squads.duplicate():
        dir._remove(q)
    dir.check_t = 0.0
    await frames(3)
    check(dir.squads.filter(func(q): return str(q.kind.get("trader", "")) != "").is_empty(), "the first-meeting trader came twice")
    for q in dir.squads.duplicate():
        dir._remove(q)
    dir.age = 0.0

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

    # the road trader: a guarded caravan that halts for a customer and sells
    game.faction_state["currency_tickets"] = 300
    var tq = dir.spawn_squad(dir.SQUAD_TYPES[dir.TRADER_TYPE], _open_spot(game, game.player.global_position, 100.0))
    check(tq != null and tq.members.size() == 2, "the trader caravan did not spawn with its guard")
    var kuz = tq.members[0]
    check(kuz.has_meta("trader_id") and str(kuz.get_meta("interaction_type", "")) == "trader" and kuz.nick == "Кузьмич", "the trader cannot be traded with")
    check(str(tq.members[1].get_meta("interaction_type", "")) == "marauder_talk", "the trader's guard is not just a guard")
    var tid = str(kuz.get_meta("trader_id"))
    var stock = game.faction_state["traders"][tid]["stock"]
    var have = 0
    for k in stock.keys():
        have += int(stock[k])
    check(have > 20, "the trader came with an empty pack")
    await frames(40)
    check(tq.hold, "the caravan does not halt for a customer")
    var lead_pos = kuz.global_position
    await frames(60)
    check(kuz.global_position.distance_to(lead_pos) < 6.0, "the trader walks off while the survivor is near")
    game._open_trader(tid)
    check(game.trader_open and game.trader_subtitle.text.begins_with("На дороге"), "the road stall did not open")
    var item = ""
    for k in stock.keys():
        if int(stock[k]) > 0 and game.TradingMarket.buy_quote(game.faction_state, tid, k, 1).get("ok", false):
            item = k
            break
    check(item != "", "nothing at the road stall can be bought")
    if item != "":
        var before = game._inventory_count(item)
        var town_price = game.TradingMarket.buy_price(game.faction_state, "perron_general", "water")
        var road_price = game.TradingMarket.buy_price(game.faction_state, tid, "water")
        check(road_price >= town_price, "the road is cheaper than the town")
        for i in range(game.trader_stock_list.item_count):
            if str(game.trader_stock_list.get_item_metadata(i)) == item:
                game.trader_stock_list.select(i)
                game._trader_stock_selected(i)
        game._trade_buy_selected()
        check(game._inventory_count(item) > before, "buying at the road stall failed")
    # walk away: the stall closes, the caravan goes on
    game.player.global_position += Vector2(400, 0)
    await frames(30)
    check(not game.trader_open, "the stall stayed open after the survivor walked off")
    check(not tq.hold, "the caravan stays halted with nobody near")
    # turn on him: no more trade
    game.player.global_position -= Vector2(400, 0)
    kuz.become_hostile()
    await frames(5)
    check(not kuz.is_in_group("interactable"), "a trader who was attacked still trades")
    for s in dir.squads.duplicate():
        dir._remove(s)

    print("MARAUDER MEMORY dev66: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
