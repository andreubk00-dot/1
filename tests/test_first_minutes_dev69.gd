extends SceneTree
# dev69: the first minutes of a new run. The start yard on day one holds two
# infected set well clear of the survivor (not a ring of four at the edge of
# hearing); a survivor beaten to zero dies even when fed and watered (natural
# healing used to lift 0 hp by a hair before the death check - immortal at
# zero under three infected); a body at zero does not heal.
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
    Engine.set_meta("ostatok_new_game", true)
    var game = Main.new()
    root.add_child(game)
    await frames(6)
    check(game.world_day <= 1, "a new run does not start on day one")
    var yard = []
    for e in game.get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e) and e.get_meta("chunk_coord", Vector2i(9, 9)) == Vector2i(0, 0):
            yard.append(e.global_position.distance_to(game.player.global_position))
    check(yard.size() == game.START_YARD_FIRST_DAY_INFECTED, "the start yard holds %d infected on day one" % yard.size())
    for d in yard:
        check(d >= game.START_YARD_CLEARANCE * 0.9 - 1.0, "an infected waits %.0f px from a fresh survivor" % d)
    # they leave a quiet survivor alone
    var hp = game.health
    await frames(240)
    check(game.health >= hp - 0.01, "the fresh survivor is struck while standing still")

    # the goal has a direction from the first frame: the Lazaret, far off
    var target = game._objective_target_world()
    check(target != null and target.distance_to(game.player.global_position) > game.OBJECTIVE_POINTER_NEAR, "a new survivor has no direction to the goal")
    # by the start the water bottle's prompt is up: the pointer gives it the floor
    if game.hud_interaction_panel.visible:
        check(not game._objective_pointer_wanted(), "the pointer crowds the interaction prompt")
    game.player.global_position += Vector2(0, 160)
    await frames(90)
    check(not game.hud_interaction_panel.visible, "something to pick up still under the survivor")
    check(game.objective_pointer.visible and game._objective_pointer_alpha > 0.5, "the pointer to the goal is not shown")
    game._toggle_inventory()
    check(not game._objective_pointer_wanted(), "the pointer stays over the inventory")
    game._toggle_inventory()
    var st = game.get_meta("settings").duplicate()
    st["objective_pointer"] = false
    game.set_meta("settings", st)
    check(not game._objective_pointer_wanted(), "the pointer ignores its setting")
    st["objective_pointer"] = true
    game.set_meta("settings", st)
    # beside the goal it steps aside
    game.player.global_position = target + Vector2(60, 0)
    check(not game._objective_pointer_wanted(), "the pointer nags at the goal itself")
    # the goal hint comes right after the controls
    var q = []
    for e in game.field_hints._queue:
        q.append(str(e["id"]))
    var order = game.field_hints.seen.keys() + q
    check(order.find("goal") >= 0 and (order.find("interact") < 0 or order.find("goal") < order.find("interact")), "the goal hint comes late: " + str(order))
    # a gun not yet owned is only a ghost on the quick bar
    game._update_hud()
    for slot in game.hud_quick_slots:
        var id = str(slot.get("id", ""))
        if id != "" and not game._inventory_has_item(id) and slot.get("icon") != null:
            check(slot["icon"].modulate.a < 0.3, "an unowned %s looks like it is in the kit" % id)

    # beaten to zero while fed and watered: dies
    game.developer_invulnerable = false
    game.hunger = 100.0
    game.thirst = 100.0
    game.bleeding = false
    game.health = 0.0
    await frames(3)
    check(game.player_death_time > 0.0, "a survivor at zero health does not die")
    # zero does not heal
    game.player_death_time = 0.0
    game.health = 0.0
    game._update_survival(1.0)
    check(game.health == 0.0, "a body at zero heals: %.3f" % game.health)
    game.health = 40.0
    game._update_survival(10.0)
    check(game.health > 40.0, "a fed survivor no longer heals at all")

    # later days fill the yard again
    Engine.remove_meta("ostatok_new_game")
    print("FIRST MINUTES dev69: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
