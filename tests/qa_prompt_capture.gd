extends SceneTree
# Visual QA (dev84): the interaction prompt next to a door, full screen.
# xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_prompt_capture.gd -- --qa-output=<file.png>
const Main = preload("res://main_script_mod.gd")
var output = ""

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(30):
        await process_frame
    game.developer_invulnerable = true
    game.world_minutes = 13.0 * 60.0
    var door = null
    for n in get_nodes_in_group("interactable"):
        if str(n.get_meta("interaction_type","")) == "door":
            var box: Rect2 = game._interaction_footprint(n)
            game.player.global_position = n.get_global_transform() * Vector2(0, box.end.y + 10.0)
            await physics_frame
            if game._nearest_interactable() == n:
                door = n
                break
    for i in range(30):
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output)
    print("PROMPT CAPTURE door=", door != null, " text=", game.interaction_label.text)
    quit(0)
