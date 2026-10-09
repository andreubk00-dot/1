extends SceneTree
# Visual QA for wet streets at night: close-ups of every lit puddle (street
# lamps, lit entrances) in a few town chunks, in the rain.
# xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_puddle_reflection_capture.gd -- --qa-output=<dir> [--qa-hour=23] [--qa-rain=1]
const Main = preload("res://main_script_mod.gd")
var output = ""
var hour = 23.0
var rain = 1.0

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-hour="):
            hour = float(arg.trim_prefix("--qa-hour="))
        if arg.begins_with("--qa-rain="):
            rain = float(arg.trim_prefix("--qa-rain="))
    call_deferred("run")

func _snap(path:String):
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(path)

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(4):
        await process_frame
    for node in game.find_children("*","CanvasLayer",true,false):
        node.visible = false
    game.camera.enabled = false
    var cam = Camera2D.new()
    game.add_child(cam)
    cam.enabled = true
    cam.make_current()
    game.weather_state = "rain" if rain > 0.5 else "clear"
    game.weather_timer = 99999.0
    var n = 0
    for c in [Vector2i(1,1),Vector2i(-1,2),Vector2i(2,1),Vector2i(1,-2)]:
        var center = Vector2(c) * 768.0 + Vector2(384,384)
        game.player.global_position = center + Vector2(0,300)
        for i in range(20):
            await process_frame
        if not game.loaded_chunks.has(c):
            game._load_chunk(c)
        game.world_minutes = hour * 60.0
        for i in range(8):
            await process_frame
        var ch = game.loaded_chunks[c]
        for p in ch.get_children():
            if not p.is_in_group("puddles"):
                continue
            var lit = 0
            for r in p.get_children():
                if r.is_in_group("puddle_reflections"):
                    lit += 1
            if lit == 0:
                continue
            cam.global_position = p.global_position + Vector2(0,-14)
            cam.zoom = Vector2(3,3)
            await _snap("%s/p%02d.png" % [output,n])
            n += 1
    print("PUDDLE SHOTS ",n)
    quit()
