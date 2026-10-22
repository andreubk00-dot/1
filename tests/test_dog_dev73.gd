extends SceneTree
# dev73: the dog (docs/DOG_DEV73.md).
# - a handful of yards, rural / residential, 3-6 sectors out, never where a
#   scene or a site stands; each with a chained dog and a kennel
# - fed, it is untied and follows; a taken yard stays empty; one dog at a time
# - it follows along the survivor's trail, keeps behind, catches up unseen
# - G: wait (it sits, the map marks it) / come (within a whistle)
# - it growls at the infected the survivor cannot see; barks at the near ones
#   it sees (a noise the infected hear), not while he sneaks; bitten, it yelps
#   and bolts
# - food and water run down with the clock; rain and the pump water it; E feeds,
#   waters, bandages; hunger and thirst kill it - for good, in the chronicle
# - the survivor dies: it stays by him, a stranger to the next one until fed
# - saved
const Main = preload("res://main_script_mod.gd")
const DogCatalog = preload("res://world/dog_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const SceneCatalog = preload("res://world/scene_catalog.gd")
const EncounterCatalog = preload("res://world/encounter_catalog.gd")
const WorldChronicle = preload("res://world/world_chronicle.gd")
const InputBindings = preload("res://world/input_bindings.gd")

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

func secs(t: float) -> void:
    await create_timer(t).timeout

func give(game, id: String, qty: int = 1) -> void:
    game._grid_add(game.inventory_entries, id, qty, game.INV_W, game.INV_H)

func drop_all(game, id: String) -> void:
    for i in range(game.inventory_entries.size() - 1, -1, -1):
        if str(game.inventory_entries[i]["id"]) == id:
            game.inventory_entries.remove_at(i)

func coord_of(k: String) -> Vector2i:
    var p = k.split(",")
    return Vector2i(int(p[0]), int(p[1]))

func chained_in(game, k: String):
    for d in game.get_tree().get_nodes_in_group("dog"):
        if is_instance_valid(d) and d.mode == "chained" and d.site == k:
            return d
    return null

func clear_infected(game) -> void:
    for e in game.get_tree().get_nodes_in_group("infected"):
        e.remove_from_group("infected")
        e.queue_free()

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(8)
    game.developer_invulnerable = true
    clear_infected(game)
    game.world_minutes = 12.0 * 60.0
    game.weather_state = "clear"

    # --- the yards ------------------------------------------------------------
    var sites = DogCatalog.sites()
    check(sites.size() >= 4 and sites.size() <= 6, "not a handful of yards: %d" % sites.size())
    var names = {}
    for k in sites:
        var c = coord_of(k)
        var pr = RegionCatalog.chunk_profile(c)
        var ring = max(abs(c.x), abs(c.y))
        check(ring >= 3 and ring <= 6, "a yard %s is not at the edge of town" % k)
        check(str(pr["zone"]) in ["rural", "residential"], "a yard %s in %s" % [k, pr["zone"]])
        check(str(pr.get("poi_id", "")) == "", "a yard %s on a site" % k)
        check(EncounterCatalog.event_for(c, str(pr["zone"]), int(pr["risk"]), "").is_empty() and SceneCatalog.scene_for(c, str(pr["zone"]), int(pr["risk"]), "").is_empty(), "a yard %s shares a scene's sector" % k)
        names[sites[k]] = true
    check(names.size() == sites.size(), "two yards share a name")
    check(InputBindings.codes_of("dog_command") == ["k:71"], "the dog key is not G by default")

    # --- a chained dog --------------------------------------------------------------
    var k0 = sites.keys()[0]
    var c0 = coord_of(k0)
    game.player.global_position = Vector2(c0) * game.CHUNK_SIZE + Vector2(384, 384)
    game._refresh_chunks(true)
    await frames(3)
    clear_infected(game)
    var cd = chained_in(game, k0)
    check(cd != null, "no chained dog in its yard %s" % k0)
    var built = 0
    for k in sites:
        game.player.global_position = Vector2(coord_of(k)) * game.CHUNK_SIZE + Vector2(384, 384)
        game._refresh_chunks(true)
        await frames(2)
        built += int(chained_in(game, k) != null)
    check(built >= sites.size() - 1, "yards that did not build: %d of %d" % [built, sites.size()])
    clear_infected(game)
    game.player.global_position = Vector2(c0) * game.CHUNK_SIZE + Vector2(384, 384)
    game._refresh_chunks(true)
    await frames(3)
    clear_infected(game)
    cd = chained_in(game, k0)
    if cd == null:
        check(false, "the chained dog is gone")
        print("DOG dev73: ", checks, " checks, ", failures, " failures")
        quit(1)
        return
    var kennel = false
    for n in cd.get_parent().get_children():
        if bool(n.get_meta("world_scene_piece", false)) and n.global_position.distance_to(cd.global_position) < 80.0:
            kennel = true
    check(kennel, "the yard has no kennel")
    check(cd.chain != null, "the chained dog has no chain")
    check(cd.wants_attention() and cd.need() == "adopt", "the chained dog cannot be approached")
    game.player.global_position = cd.global_position + Vector2(0, 26)
    await frames(3)
    check(game._nearest_interactable() == cd, "E does not reach the chained dog")
    for f in DogCatalog.FOODS:
        drop_all(game, f)
    check(cd.prompt_text().find("НУЖНА ЕДА") >= 0, "the prompt does not say it wants food")
    cd.care()
    check(cd.mode == "chained" and game.dog == null, "the dog was untied without food")
    await frames(4)
    check(cd.current_clip() == "alert", "a chained dog is calm with a stranger at arm's length")
    give(game, "canned_meat", 2)
    check(cd.prompt_text().begins_with("НАКОРМИТЬ"), "the prompt does not offer to feed it")
    game._interact()
    await frames(2)
    check(game.dog == cd and cd.mode == "follow" and cd.trusted and cd.get_parent() == game, "feeding did not untie it")
    check(game._inventory_count("canned_meat") == 1, "the tin was not eaten")
    check(str(game.dog_state["sites"].get(k0, "")) == "taken", "the yard does not remember it was emptied")
    check(cd.chain == null, "the chain is still on")
    var d = game.dog
    # the yard stays empty
    game.player.global_position = Vector2(c0 + Vector2i(4, 0)) * game.CHUNK_SIZE
    game._refresh_chunks(true)
    await frames(2)
    game.player.global_position = Vector2(c0) * game.CHUNK_SIZE + Vector2(384, 384)
    game._refresh_chunks(true)
    await frames(2)
    check(chained_in(game, k0) == null, "a second dog appeared in the emptied yard")
    # one dog at a time
    if sites.size() > 1:
        var k1 = sites.keys()[1]
        game.player.global_position = Vector2(coord_of(k1)) * game.CHUNK_SIZE + Vector2(384, 384)
        game._refresh_chunks(true)
        await frames(3)
        var cd2 = chained_in(game, k1)
        if cd2 != null:
            check(cd2.prompt_text().find("ВТОРОГО") >= 0, "a second dog is offered")
            cd2.care()
            check(cd2.mode == "chained" and game.dog == d, "a second dog was taken")
    clear_infected(game)

    # --- following --------------------------------------------------------------------
    # an open field: the start yard
    game.player.global_position = Vector2(384, 384)
    game._refresh_chunks(true)
    await frames(3)
    clear_infected(game)
    d.global_position = game.player.global_position + Vector2(-30, 0)
    d.trail = []
    await frames(5)
    var start = game.player.global_position
    for i in range(90):
        game.player.global_position = start + Vector2(0, -2.0 * i)
        await physics_frame
    var lag = d.global_position.distance_to(game.player.global_position)
    check(lag < 140.0, "it fell behind on a walk: %.0f" % lag)
    await secs(2.0)
    lag = d.global_position.distance_to(game.player.global_position)
    check(lag < d.GAP + 24.0 and lag > 10.0, "it did not settle behind: %.0f" % lag)
    check(d.current_clip() in ["idle", "alert"], "a dog at rest is not standing: %s" % d.current_clip())
    # far away and out of sight it closes up
    game.player.global_position += Vector2(900, 0)
    await frames(4)
    check(d.global_position.distance_to(game.player.global_position) < 400.0, "it did not catch up from far away")

    # --- wait / come -------------------------------------------------------------------
    # back in the open start yard; he walks off the way he walked before
    game.player.global_position = start
    d.global_position = start + Vector2(-30, 0)
    d.trail = []
    await frames(3)
    check(d.command() == "wait" and d.mode == "wait", "G did not make it wait")
    var here = d.global_position
    for i in range(90):
        game.player.global_position = start + Vector2(0, -2.0 * i)
        await physics_frame
    await secs(0.5)
    check(d.global_position.distance_to(here) < 4.0 and d.current_clip() == "sit", "a waiting dog did not sit and stay")
    var snap = game._region_map_snapshot() if game.has_method("_region_map_snapshot") else {}
    if game.has_method("_region_map_snapshot"):
        check(snap.has("dog") and snap["dog"]["coord"] == game._world_to_chunk(here), "the map does not mark where it waits")
    d.food = 90.0
    d.water = 90.0
    d.hp = 60.0
    check(d.wants_attention() and d.need() == "call", "a waiting dog cannot be called with E")
    var stood = game.player.global_position
    game.player.global_position = here + Vector2(900, 0)
    check(d.command() == "far" and d.mode == "wait", "a call carried across the map")
    game.player.global_position = stood
    check(d.trail.size() > 5, "it did not keep the survivor's steps while waiting")
    check(d.command() == "come" and d.mode == "follow", "G did not call it back")
    await secs(2.5)
    check(d.global_position.distance_to(game.player.global_position) < 80.0, "called, it did not come")
    check(not d.wants_attention(), "a dog at heel that needs nothing takes the E prompt")

    # --- senses --------------------------------------------------------------------------
    d.global_position = game.player.global_position + Vector2(-30, 0)
    clear_infected(game)
    await frames(1)
    var e = game._spawn_enemy(game, Vector2i.ZERO, 7301, Vector2.ZERO)
    await frames(1)
    # behind the survivor, off the screen
    e.global_position = d.global_position + Vector2(0, 340)
    game._enemy_set_state(e, "idle", 5.0)
    d.growl_cd = 0.0
    d._sense()
    check(d.sensed == e, "it did not sense an infected the survivor cannot see")
    check(not d.survivor_sees(e), "an off-screen infected counted as seen")
    # close and in sight: it barks, and the infected hear it
    var e2 = game._spawn_enemy(game, Vector2i.ZERO, 7302, Vector2.ZERO)
    await frames(1)
    e.global_position = d.global_position + Vector2(5000, 0)
    e2.global_position = d.global_position + Vector2(110, 10)
    game._enemy_set_state(e2, "chase", 5.0)
    game.is_crouching = true
    d.bark_cd = 0.0
    d._sense()
    check(d.bark_cd == 0.0, "it barked while the survivor sneaked")
    game.is_crouching = false
    var e3 = game._spawn_enemy(game, Vector2i.ZERO, 7303, Vector2.ZERO)
    await frames(1)
    # in the open, within earshot: a bark carries less through a wall
    for off in [Vector2(-150, 60), Vector2(0, 150), Vector2(-150, -40), Vector2(60, -140), Vector2(-100, 100), Vector2(0, -150)]:
        e3.global_position = d.global_position + off
        if d._clear_line(d.global_position, e3.global_position):
            break
    game._enemy_set_state(e3, "idle", 5.0)
    e3.set_meta("suspicion", 0.0)
    e2.global_position = d.global_position + Vector2(110, 10)
    d._sense()
    check(d.bark_cd > 0.0, "it did not bark at an infected coming in sight")
    check(float(e3.get_meta("suspicion", 0.0)) > 0.0 and str(e3.get_meta("ai_state", "idle")) != "idle", "the bark was not heard")
    # bitten: it yelps, bolts and is hurt
    var hp0 = d.hp
    e2.global_position = d.global_position + Vector2(6, 0)
    game._enemy_set_state(e2, "chase", 5.0)
    d.bite_cd = 0.0
    d._bitten()
    check(d.hp < hp0 and d.flee_t > 0.0, "a bite did nothing")
    for n in [e, e2, e3]:
        n.remove_from_group("infected")
        n.queue_free()
    await frames(2)

    # --- needs -----------------------------------------------------------------------------
    d.hp = d.hp
    d.food = 100.0
    d.water = 100.0
    d.advance(1440.0)
    check(d.water < 2.0 and abs(d.food - 50.0) < 2.0, "food %.0f / water %.0f after a day" % [d.food, d.water])
    check(d.weak(), "a thirsty dog is not weak")
    drop_all(game, "dirty_water")
    drop_all(game, "water")
    give(game, "dirty_water", 1)
    check(d.need() == "water" and d.wants_attention(), "a thirsty dog does not ask for water")
    d.care()
    check(d.water >= 99.0 and game._inventory_count("dirty_water") == 0, "watering it did not work")
    d.food = 10.0
    give(game, "canned_meat", 1)
    var cans = game._inventory_count("canned_meat")
    check(d.need() == "food", "a hungry dog does not ask for food")
    d.care()
    check(d.food > 50.0 and game._inventory_count("canned_meat") == cans - 1, "feeding it did not work")
    d.hp = 20.0
    check(d.limping(), "a hurt dog does not limp")
    give(game, "bandage", 1)
    var bandages = game._inventory_count("bandage")
    check(d.need() == "bandage", "a hurt dog cannot be bandaged")
    d.care()
    check(d.hp >= 49.0 and game._inventory_count("bandage") == bandages - 1, "the bandage did not help")
    # rain waters it
    d.water = 10.0
    game.weather_state = "rain"
    game.is_sheltered = false
    d.advance(60.0)
    check(d.water > 60.0, "the rain did not water it")
    game.weather_state = "clear"
    # the pump
    d.water = 10.0
    var pump = Node2D.new()
    game.add_child(pump)
    pump.global_position = d.global_position + Vector2(20, 0)
    game._use_water_pump(pump)
    check(d.water >= 99.0, "it did not drink at the pump")
    pump.queue_free()

    # --- the survivor dies -------------------------------------------------------------------
    d.food = 80.0
    d.water = 80.0
    d.hp = 60.0
    game.player_death_time = 1.0
    await frames(3)
    check(not d.trusted and d.mode == "wait", "the dog did not stay by the fallen survivor")
    game.player_death_time = 0.0
    await frames(2)
    check(d.command() == "stranger" and d.mode == "wait", "the next survivor commands a dog that does not know him")
    check(d.need() == "befriend" and d.wants_attention(), "the stranger cannot win it over")
    give(game, "canned_meat", 1)
    d.care()
    check(d.trusted and d.mode == "follow", "fed, it did not take to the new survivor")

    # --- saved ---------------------------------------------------------------------------------
    d.hp = 41.0
    d.food = 33.0
    game._save_state()
    var g2 = Main.new()
    root.add_child(g2)
    await frames(6)
    var d2 = g2.dog
    check(d2 != null and is_instance_valid(d2) and d2.dog_name == d.dog_name, "the dog was not saved")
    if d2 != null:
        check(abs(d2.hp - 41.0) < 1.0 and abs(d2.food - 33.0) < 1.0 and d2.mode == "follow" and d2.trusted, "the dog came back changed")
        check(d2.global_position.distance_to(g2.player.global_position) < 80.0, "a following dog came back far from the survivor")
    check(str(g2.dog_state["sites"].get(k0, "")) == "taken", "the yard forgot")
    g2.queue_free()
    await frames(2)

    # --- for good ------------------------------------------------------------------------------
    var who = d.dog_name
    d.food = 0.0
    d.water = 0.0
    d.hp = 3.0
    d.advance(120.0)
    check(d.dead and game.dog == null and game.dog_state["dog"].is_empty(), "starved, it did not die")
    check(who in game.dog_state["lost"], "the dead dog is not remembered")
    var told = false
    for entry in WorldChronicle.entries(game.faction_state, 40, true):
        if WorldChronicle.entry_text(entry).find(who) >= 0:
            told = true
    check(told, "the chronicle does not remember it")
    check(not d.is_in_group("interactable"), "a dead dog can be talked to")
    check(d.command() == "", "a dead dog answers the key")

    print("DOG dev73: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
