extends SceneTree
# dev84: the first steps of a new survivor - pick a thing up, drink, search a
# crate, fight off an infected, open the map - shown as the current goal with
# the gold arrow on the thing; any order; walking off ends them; every hint
# can be read again (Esc -> Советы); a death says plainly what happened.
const Main = preload("res://main_script_mod.gd")
const FieldHints = preload("res://world/field_hints.gd")

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

func title(game) -> String:
    return str(game._hud_survival_objective().get("title", ""))

func run():
    Engine.set_meta("ostatok_new_game", true)
    var game = Main.new()
    root.add_child(game)
    await frames(10)
    game.developer_invulnerable = true
    var fh = game.field_hints
    check(fh.steps_active, "a new run has no first steps")
    check(title(game) == "ПОДОБРАТЬ ВЕЩЬ", "the first goal is %s" % title(game))
    check(str(game._hud_survival_objective().get("sub", "")).begins_with("Шаг 1/5"), "the step does not say which of five")
    # every step's line fits the goal panel (no text cut off)
    for i in range(fh.STEPS.size()):
        fh.steps_done = {}
        for j in range(i):
            fh.steps_done[fh.STEPS[j]["id"]] = true
        game._update_hud()
        var sub = game.hud_objective_sub_label
        check(sub.get_visible_line_count() >= sub.get_line_count(), "step %d does not fit the goal panel" % (i + 1))
        check(game._hud_single_line_label_fits(game.hud_objective_label), "step %d title does not fit" % (i + 1))
    fh.steps_done = {}
    # the arrow points at the bottle by the road, even close by
    var t = game._objective_target_world()
    check(t != null, "no arrow to a thing to pick up")
    if t != null:
        game.player.global_position = t + Vector2(0, 120)
        await frames(4)
        check(game._objective_pointer_wanted(), "the arrow hides 120 px from the bottle")
    # 1. pick up
    var item = null
    for n in game.get_tree().get_nodes_in_group("interactable"):
        if str(n.get_meta("interaction_type", "")) == "world_item":
            item = n
            break
    check(item != null, "nothing lies on the ground in the start yard")
    if item != null:
        game._pickup_world_item(item)
    check(fh.steps_done.has("pickup"), "picking up did not count")
    check(title(game) == "ПОПИТЬ ВОДЫ", "after a pick-up the goal is %s" % title(game))
    # 2. drink (thirst goes up)
    game.thirst = 50.0
    await frames(40)
    game.thirst = 70.0
    await frames(40)
    check(fh.steps_done.has("drink"), "drinking did not count")
    # 3. search: the arrow goes to a crate, opening it counts
    t = game._objective_target_world()
    check(t != null, "no arrow to a crate")
    var key = ""
    for n in game.get_tree().get_nodes_in_group("interactable"):
        if str(n.get_meta("interaction_type", "")) == "container" and not game._container_locked(str(n.get_meta("container_key", ""))):
            key = str(n.get_meta("container_key", ""))
            break
    game._open_container(key)
    check(fh.steps_done.has("search"), "searching a crate did not count")
    game._close_inventory()
    # 4. fight
    var inf = null
    for e in game.get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e):
            inf = e
            break
    check(inf != null, "no infected in the start yard")
    if inf != null:
        game._damage_enemy(inf, 9999.0)
    check(fh.steps_done.has("fight"), "killing an infected did not count")
    # 5. the map
    game._toggle_region_map()
    await frames(2)
    game._toggle_region_map()
    check(not fh.steps_active, "five steps done and the steps go on")
    check(title(game) == "ДОБРАТЬСЯ ДО ЛАЗАРЕТА", "after the steps the goal is %s" % title(game))
    var q = []
    for e in fh._queue:
        q.append(str(e["id"]))
    check(q.has("steps_done") or fh.seen.has("steps_done"), "no word that the basics are done")
    # saved and loaded
    var st = fh.state()
    var fh2 = FieldHints.new()
    fh2.load_state(st)
    check(not fh2.steps_active and fh2.steps_done.size() == 5, "the steps do not survive a save")
    fh2.free()
    # an old save has no steps
    var fh3 = FieldHints.new()
    fh3.load_state({"enabled": true, "seen": {}})
    check(not fh3.steps_active, "an old save starts the first steps")
    fh3.free()

    # every hint shown can be read again
    fh._queue.clear()
    fh.seen.erase("dark")
    fh.hint("dark", "Темно. проверка")
    for i in range(3):
        await frames(40)
    check(fh.texts.has("dark"), "a shown hint is not kept to read again")
    game._open_menu("pause")
    await process_frame
    game.pause_menu._open_tips()
    await process_frame
    var tips = 0
    for c in game.pause_menu._confirm_box.find_children("*", "Label", true, false):
        if str(c.text).begins_with("• "):
            tips += 1
    check(tips >= 1, "the Советы page is empty")
    game.pause_menu.close()

    # a death says what happened
    fh._queue.clear()
    game.developer_invulnerable = false
    game.health = 0.0
    await frames(int(60 * (game.PLAYER_DEATH_DURATION + 0.6)))
    var said = false
    for e in fh._queue:
        if str(e["id"]) == "death":
            said = true
    if fh._panel != null and fh._panel.visible and str(fh._panel.get_meta("id", "")) == "death":
        said = true
    check(said, "a death passes with no card")
    game.developer_invulnerable = true
    game.queue_free()
    await frames(3)

    # walking off from the start area ends the steps (a new game from the
    # menu removes the save first)
    for path in [Main.SAVE_PATH, Main.SAVE_PATH + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    Engine.set_meta("ostatok_new_game", true)
    var g2 = Main.new()
    root.add_child(g2)
    await frames(10)
    g2.developer_invulnerable = true
    check(g2.field_hints.steps_active, "a second new run has no steps")
    g2.player.global_position = Vector2(4, 0) * g2.CHUNK_SIZE + Vector2(384, 384)
    g2._refresh_chunks(true)
    await frames(60)
    check(not g2.field_hints.steps_active, "far from the start the steps still hold him")
    print("FIRST STEPS dev84: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
