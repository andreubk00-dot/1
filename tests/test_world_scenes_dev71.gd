extends SceneTree
# dev71: six new world scenes (docs/SCENES_DEV71.md).
# - the old five keep their exact places; a new scene never shares a sector
#   with an old one, a site, the start ring or an «ЭФИР» note
# - every one of the six exists somewhere in the region and builds there
# - the car survivor: locked while infected are near; let go -> gift, the
#   nearest settlement thinks better of you; robbed -> more, and worse
# - the bait: opening the bag raises a hostile squad, once
# - the checkpoint radio marks the nearest unfound site, once
# - the burn-pit radio plays what «ЭФИР» is now
# - the living camp: neutral strangers at the fire; dead, they stay dead
# - a pre-dev71 save keeps the sectors it had visited exactly as they were
# - scene state is saved
const Main = preload("res://main_script_mod.gd")
const RC = preload("res://world/region_catalog.gd")
const EC = preload("res://world/encounter_catalog.gd")
const SC = preload("res://world/scene_catalog.gd")
const StoryEther = preload("res://world/story_ether.gd")

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

func scene_root(game, coord: Vector2i):
    var chunk = game.loaded_chunks.get(coord, null)
    if chunk == null:
        return null
    for n in chunk.get_children():
        if bool(n.get_meta("world_scene", false)):
            return n
    return null

func visit(game, coord: Vector2i, offset: Vector2 = Vector2(0, 260)):
    game.player.global_position = Vector2(coord) * game.CHUNK_SIZE + Vector2(384, 384) + offset
    game._refresh_chunks(true)
    await frames(4)
    return scene_root(game, coord)

func find_action(root, action: String):
    if root == null:
        return null
    for n in root.find_children("*", "Node2D", true, false):
        if str(n.get_meta("scene_action", "")) == action:
            return n
    return null

func clear_infected_near(game, pos: Vector2, r: float) -> void:
    for e in game.get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e) and e.global_position.distance_to(pos) < r:
            game._damage_enemy(e, 99999.0, Vector2.RIGHT)
    await frames(2)

func run():
    # --- placement ------------------------------------------------------------
    var where = {}
    var old_counts = {}
    for y in range(-14, 15):
        for x in range(-16, 20):
            var c = Vector2i(x, y)
            var p = RC.chunk_profile(c)
            if p.is_empty():
                continue
            var z = str(p.get("zone", "")); var r = int(p.get("risk", 2)); var pid = str(p.get("poi_id", ""))
            var e = EC.event_for(c, z, r, pid)
            if not e.is_empty():
                old_counts[e["id"]] = int(old_counts.get(e["id"], 0)) + 1
            var s = SC.scene_for(c, z, r, pid)
            if s.is_empty():
                continue
            check(e.is_empty(), "a new scene shares %s with an old one" % c)
            check(pid == "", "a new scene stands on a site at %s" % c)
            check(max(abs(c.x), abs(c.y)) > 2, "a new scene in the start ring at %s" % c)
            check(not StoryEther.NOTES.has("%d,%d" % [c.x, c.y]) and c != StoryEther.COLUMN_NOTE["coord"], "a new scene on an «ЭФИР» sector %s" % c)
            if not where.has(s["id"]):
                where[s["id"]] = []
            where[s["id"]].append(c)
    # the old scenes did not move (counts as of dev70)
    check(old_counts == {"abandoned_camp": 24, "feeding_site": 16, "failed_evacuation": 3, "repair_breakdown": 8, "looted_convoy": 10}, "an old scene moved: " + str(old_counts))
    for id in SC.SCENES.keys():
        check(where.has(id) and where[id].size() >= 5, "%s is (almost) nowhere: %s" % [id, where.get(id, [])])
    check(EC.EVENTS.size() == 5, "the old catalogue changed")

    var game = Main.new()
    root.add_child(game)
    await frames(8)
    game.developer_invulnerable = true
    game.world_minutes = 12.0 * 60.0
    check(game.world_scenes != null and game.scene_legacy_chunks.is_empty(), "a new game has legacy sectors or no scene keeper")

    # every kind builds in at least one of its sectors, on clear ground
    var built = {}
    for id in where.keys():
        for c in where[id]:
            var root_node = await visit(game, c)
            if root_node != null and str(root_node.get_meta("world_event_id", "")) == id:
                built[id] = c
                var rect = game._world_event_rect(root_node)
                for b in game.loaded_chunks[c].get_children():
                    if b.has_meta("world_building"):
                        var bs = b.get_meta("building_size", Vector2.ZERO)
                        check(not Rect2(b.global_position - bs * 0.5, bs).intersects(rect.grow(-4.0)), "%s at %s stands in a building" % [id, c])
                # the big piece that makes the scene readable is really there
                var want_piece = {"trapped_survivor":"burnt_car", "abandoned_checkpoint":"poi:guard_booth", "pharmacy_van":"ambulance", "living_camp":"bonfire", "burn_pit":"rubble_pile"}
                if want_piece.has(id):
                    var found = false
                    for b in game.loaded_chunks[c].get_children():
                        if bool(b.get_meta("world_scene_piece", false)) and str(b.get_meta("settlement_piece_kind", "")) == want_piece[id]:
                            found = true
                            check(rect.grow(20.0).has_point(b.position), "%s: its %s stands outside the scene" % [id, want_piece[id]])
                    check(found, "%s at %s lacks its %s" % [id, c, want_piece[id]])
                for n in root_node.find_children("*", "Node2D", true, false):
                    if n.is_in_group("interactable"):
                        check(game.marauder_director._free_at(n.global_position) or str(n.get_meta("interaction_type", "")) == "container", "%s: %s cannot be reached" % [id, n.name])
                break
        check(built.has(id), "%s never built in any of its sectors" % id)

    # --- the car survivor --------------------------------------------------------
    if built.has("trapped_survivor"):
        var c = built["trapped_survivor"]
        var rn = await visit(game, c)
        var car = find_action(rn, "survivor")
        check(car != null, "no one in the car")
        var near = 0
        for e in game.get_tree().get_nodes_in_group("infected"):
            if is_instance_valid(e) and e.global_position.distance_to(rn.global_position) < 160.0:
                near += 1
        check(near >= 2, "the car is not besieged: %d" % near)
        game.player.global_position = car.global_position + Vector2(0, 30)
        game.world_scenes.interact(car)
        check(game.get_tree().root.get_node_or_null("StoryDialog") == null and game.world_scenes.state_of(c) == "", "the car opened with infected round it")
        await clear_infected_near(game, rn.global_position, 260.0)
        var town = game.world_scenes.nearest_settlement(car.global_position)
        var fid = str(town.get("faction", ""))
        var rep0 = game.FactionEconomy.reputation(game.faction_state, fid)
        var inv0 = game.inventory_entries.size()
        game.world_scenes.interact(car)
        await process_frame
        var dlg = game.get_tree().root.get_node_or_null("StoryDialog")
        check(dlg != null and dlg.buttons.size() == 3, "no choice at the car")
        if dlg != null:
            dlg.buttons[0].emit_signal("pressed")
        await process_frame
        check(game.world_scenes.state_of(c) == "freed", "letting go did not stick")
        check(game.inventory_entries.size() > inv0 or game._inventory_weight() > 0.0, "the survivor gave nothing")
        check(game.FactionEconomy.reputation(game.faction_state, fid) > rep0, "the settlement did not hear of the kindness")
        await frames(2)
        check(find_action(scene_root(game, c), "survivor") == null, "the survivor is still in the car")
        # robbing elsewhere costs standing
        game.world_scene_state.erase(SC.SCENES.keys()[0])
        var rep1 = game.FactionEconomy.reputation(game.faction_state, fid)
        game.world_scenes.resolve_survivor(Vector2i(99, 99), "robbed", fid, "Тест", null)
        check(game.FactionEconomy.reputation(game.faction_state, fid) < rep1, "robbing a survivor costs nothing")

    # --- the bait --------------------------------------------------------------
    if built.has("bait_ambush"):
        var c = built["bait_ambush"]
        var rn = await visit(game, c)
        var key = "%d:%d:container:scene_bait" % [c.x, c.y]
        check(game.container_states.has(key) and not game.container_states[key].get("items", []).is_empty(), "the crate on the road is empty")
        var clue = null
        for n in rn.find_children("*", "Node2D", true, false):
            if str(n.get_meta("interaction_type", "")) == "story_clue":
                clue = n
        check(clue != null, "no warning beside the bait")
        var before = game.marauder_director.squads.size()
        game.player.global_position = rn.global_position + Vector2(0, 30)
        game._open_container(key)
        game._close_inventory()
        await frames(2)
        check(game.marauder_director.squads.size() == before + 1, "opening the crate raised no one")
        if game.marauder_director.squads.size() > before:
            var sq = game.marauder_director.squads[-1]
            check(str(sq.members[0].personality if "personality" in sq.members[0] else "hostile") != "neutral", "the ambushers are friendly")
        game._open_container(key)
        game._close_inventory()
        await frames(2)
        check(game.marauder_director.squads.size() <= before + 1, "the ambush sprang twice")

    # --- the checkpoint radio ------------------------------------------------------
    if built.has("abandoned_checkpoint"):
        var c = built["abandoned_checkpoint"]
        var rn = await visit(game, c)
        var radio = find_action(rn, "radio")
        check(radio != null, "no radio at the checkpoint")
        var known = game.discovered_pois.size()
        if radio != null:
            game.world_scenes.interact(radio)
        check(game.discovered_pois.size() == known + 1, "the radio named no site")
        check(game.world_scenes.state_of(c) == "radio_used", "the radio can be used again")
        rn = await visit(game, c + Vector2i(30, 30))
        rn = await visit(game, c)
        check(find_action(rn, "radio") == null, "the used radio came back")

    # --- the burn-pit radio ---------------------------------------------------------
    if built.has("burn_pit"):
        var c = built["burn_pit"]
        var rn = await visit(game, c)
        var radio = find_action(rn, "pit_radio")
        check(radio != null, "no radio at the pit")
        for choice in ["", "truth", "silence"]:
            game.story_ether["choice"] = choice
            game.world_scenes.interact(radio)
            check(game.survival_feedback.find(SC.pit_radio(choice).left(20)) >= 0, "the pit radio ignores «ЭФИР»: " + choice)
        game.story_ether["choice"] = ""

    # --- the living camp -----------------------------------------------------------
    if built.has("living_camp"):
        var c = built["living_camp"]
        var rn = await visit(game, c, Vector2(0, 0))
        game.world_scenes.tick()
        await frames(2)
        var sq = game.world_scenes._camps.get(SC.SCENES.keys()[0], null)
        sq = game.world_scenes._camps.get(game.world_scenes.key(c), null)
        check(sq != null and sq.members.size() >= 1, "no one at the camp fire")
        if sq != null:
            for m in sq.members:
                check(not m.hostile_to_player, "the camp strangers shoot on sight")
                game._damage_enemy(m, 9999.0, Vector2.RIGHT)
            await frames(80)
            game.world_scenes.tick()
            await frames(2)
            game.world_scenes.tick()
            check(game.world_scenes.state_of(c) == "camp_dead", "a dead camp is not remembered")
            game.world_scenes.tick()
            check(not game.world_scenes._camps.has(game.world_scenes.key(c)), "the dead came back to the fire")

    # --- saved; an old save keeps what it had visited -------------------------------
    game._save_state()
    var g2 = Main.new()
    root.add_child(g2)
    await frames(6)
    if built.has("trapped_survivor"):
        check(g2.world_scenes.state_of(built["trapped_survivor"]) == "freed", "scene state lost on reload")
    var snap = g2._scene_legacy_snapshot({"discovered_chunks": {"5:6": true}, "container_states": {"-7:3:container:x": {}}, "defeated": {"2:-9:4": true}, "picked_world_items": {}})
    check(snap.has("5:6") and snap.has("-7:3") and snap.has("2:-9"), "the legacy snapshot misses visited sectors: " + str(snap))
    if built.has("pharmacy_van"):
        var c = built["pharmacy_van"]
        g2.scene_legacy_chunks[g2._zone_chunk_key(c)] = true
        g2.player.global_position = Vector2(c) * g2.CHUNK_SIZE + Vector2(384, 384)
        g2._refresh_chunks(true)
        await frames(3)
        check(scene_root(g2, c) == null, "a sector an old save had visited got a new scene")
    g2.queue_free()
    await frames(2)

    print("WORLD SCENES dev71: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
