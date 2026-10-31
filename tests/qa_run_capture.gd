extends SceneTree
# Visual QA for dev81: the survivor running for real (input held, camera
# following), every frame saved around the player - for a GIF.
# xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_run_capture.gd -- --qa-output=<dir> [--qa-leg=right|right_sprint|down|up|diag]
const Main = preload("res://main_script_mod.gd")
var output = ""
var leg = "right"

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-leg="):
            leg = arg.trim_prefix("--qa-leg=")
    call_deferred("run")

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(20):
        await process_frame
    for node in game.find_children("*","CanvasLayer",true,false):
        node.visible = false
    game.developer_invulnerable = true
    game.qa_bot_driver = true
    game.world_minutes = 13.0 * 60.0
    var dirs = {"right":[["move_right"],Vector2.RIGHT,Vector2(120,384)],
        "right_sprint":[["move_right","sprint"],Vector2.RIGHT,Vector2(80,384)],
        "down":[["move_down"],Vector2.DOWN,Vector2(384,100)],
        "up":[["move_up"],Vector2.UP,Vector2(384,660)],
        "diag":[["move_right","move_down"],Vector2(1,1).normalized(),Vector2(160,160)]}
    var spec = dirs[leg]
    game.player.global_position = spec[2]
    game.qa_locked_aim = spec[1]
    game.stamina = 100.0
    for i in range(10):
        await process_frame
    for a in spec[0]:
        Input.action_press(a)
    var n = 0
    for i in range(110):
        await process_frame
        await RenderingServer.frame_post_draw
        if i >= 20:
            var img = root.get_texture().get_image()
            var vp = game.get_viewport()
            var sp = vp.get_canvas_transform() * game.player.global_position
            sp *= Vector2(img.get_size()) / vp.get_visible_rect().size
            var c = Vector2i(int(sp.x), int(sp.y))
            img = img.get_region(Rect2i(c.x - 130, c.y - 150, 260, 210))
            img.save_png("%s/f_%03d.png" % [output,n])
            n += 1
    quit(0)
