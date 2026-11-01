extends SceneTree
# Visual QA (dev84): a newcomer's first session, screen by screen - the title,
# a new run with its first hints, the walk toward the goal, the first crate,
# the inventory, the map, the first infected, the night, a death, the pause menu.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_newcomer_playtest.gd -- --qa-output=<dir>
const Main = preload("res://main_script_mod.gd")
var output = ""
var game = null
var shot = 0

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await process_frame

func snap(name: String) -> void:
    await RenderingServer.frame_post_draw
    shot += 1
    var path = "%s/%02d_%s.png" % [output, shot, name]
    root.get_texture().get_image().save_png(path)
    print("SHOT ", path, " hint=", _hint_text(), " prompt=", game.interaction_label.text if game.interaction_label != null else "")

func _hint_text() -> String:
    var fh = game.field_hints
    if fh != null and fh._panel != null and fh._panel.visible:
        return fh._text.text
    return ""

func walk(dir: Vector2, secs: float) -> void:
    game.qa_forced_move_direction = dir.normalized()
    game.qa_locked_aim = dir.normalized()
    await frames(int(secs * 60.0))
    game.qa_forced_move_direction = Vector2.ZERO

func run():
    Engine.set_meta("ostatok_new_game", true)
    game = Main.new()
    root.add_child(game)
    await frames(10)
    game.qa_bot_driver = true
    # 1. the title screen a player meets
    game._open_menu("title")
    await frames(20)
    await snap("title")
    game.pause_menu.close()
    get_paused_fix()
    await frames(5)
    # 2. the first seconds of a run
    await frames(120)
    await snap("start")
    await frames(420)
    await snap("start_8s")
    # 3. toward the goal
    var target = game._objective_target_world()
    if target != null:
        await walk(target - game.player.global_position, 4.0)
    await snap("toward_goal")
    # 4. the nearest crate
    var best = null
    var bd = 1e9
    for n in get_nodes_in_group("interactable"):
        if str(n.get_meta("interaction_type", "")) == "container":
            var d = n.global_position.distance_to(game.player.global_position)
            if d < bd:
                bd = d
                best = n
    if best != null:
        var box: Rect2 = game._interaction_footprint(best)
        game.player.global_position = best.get_global_transform() * Vector2(box.get_center().x, box.end.y + 10.0)
        await frames(30)
        await snap("at_crate")
        game._interact()
        await frames(20)
        await snap("crate_open")
        game._close_inventory()
        await frames(5)
    # 5. the inventory
    game._toggle_inventory()
    await frames(20)
    await snap("inventory")
    game._close_inventory()
    await frames(5)
    # 6. the map
    game._toggle_region_map()
    await frames(20)
    await snap("map")
    game._toggle_region_map()
    await frames(10)
    # 7. the first infected
    var inf = null
    bd = 1e9
    for e in get_nodes_in_group("infected"):
        if is_instance_valid(e):
            var d = e.global_position.distance_to(game.player.global_position)
            if d < bd:
                bd = d
                inf = e
    if inf != null:
        game.developer_invulnerable = true
        game.player.global_position = inf.global_position + Vector2(-90, 0)
        game.qa_locked_aim = Vector2.RIGHT
        await frames(60)
        await snap("infected_near")
        for i in range(3):
            game.fire_cooldown = 0.0
            game._fire_weapon()
            await frames(12)
        await snap("infected_fight")
    # 8. night
    game.world_minutes = 22.5 * 60.0
    await frames(90)
    await snap("night")
    # 9. a death
    game.developer_invulnerable = false
    game.health = 0.0
    await frames(150)
    await snap("death")
    await frames(240)
    await snap("after_death")
    # 10. the pause menu
    game._open_menu("pause")
    await frames(20)
    await snap("pause")
    quit(0)

func get_paused_fix() -> void:
    paused = false
