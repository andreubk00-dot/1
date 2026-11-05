extends SceneTree
# Visual QA (1.43): the survivor standing (the combat stance), then jogging
# right and down, then a sprint - close-up frames of him and his feet.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_stance_capture.gd -- --qa-output=<dir>
const Main = preload("res://main_script_mod.gd")
var output = ""

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")

func grab(game, name: String) -> void:
    await RenderingServer.frame_post_draw
    var img = root.get_texture().get_image()
    var vp = root.get_visible_rect().size
    var scale = img.get_width() / vp.x
    var c = game.player.get_global_transform_with_canvas().origin * scale
    var r = Rect2i(int(c.x - 60), int(c.y - 80), 120, 120)
    img.get_region(r).save_png("%s/%s.png" % [output, name])

func run():
    Engine.set_meta("ostatok_new_game", true)
    var game = Main.new()
    root.add_child(game)
    for i in range(10):
        await process_frame
    game.developer_invulnerable = true
    game.field_hints.finish_steps()
    game.field_hints.enabled = false
    game.qa_bot_driver = true
    game.player.collision_mask = 0
    var n = 0
    for i in range(24):
        await process_frame
        if i % 3 == 0:
            await grab(game, "a_idle_%02d" % n)
            n += 1
    for leg in [[Vector2.RIGHT, false, "b_jog_e"], [Vector2.DOWN, false, "c_jog_s"], [Vector2.RIGHT, true, "d_run_e"]]:
        game.qa_forced_move_direction = leg[0]
        game.qa_locked_aim = leg[0]
        game.is_sprinting = leg[1]
        n = 0
        for i in range(40):
            await process_frame
            if i >= 10 and i % 2 == 0:
                await grab(game, "%s_%02d" % [leg[2], n])
                n += 1
    quit(0)
