extends SceneTree
# Visual QA (1.42): the world, district by district - one sector of each kind
# at noon (and the start at dusk), the survivor in the middle, no windows.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_world_tour.gd -- --qa-output=<dir>
const Main = preload("res://main_script_mod.gd")
var output = ""
var game = null

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
    root.get_texture().get_image().save_png("%s/%s.png" % [output, name])
    print("SHOT ", name)

func run():
    Engine.set_meta("ostatok_new_game", true)
    game = Main.new()
    root.add_child(game)
    await frames(10)
    game.developer_invulnerable = true
    game.field_hints.finish_steps()
    game.field_hints._queue.clear()
    game.world_minutes = 12.0 * 60.0
    await frames(20)
    await snap("00_start_noon")
    game.world_minutes = 19.5 * 60.0
    await frames(20)
    await snap("01_start_dusk")
    game.world_minutes = 12.0 * 60.0
    # one sector of each district
    var seen = {}
    var stops = []
    for y in range(-12, 13, 3):
        for x in range(-12, 13, 3):
            var c = Vector2i(x, y)
            var d = game.RegionCatalog.district_id_for_chunk(c)
            if not seen.has(d):
                seen[d] = true
                stops.append([d, c])
    var i = 2
    for stop in stops:
        game._qa_move_to_world_chunk(stop[1])
        game.world_minutes = 12.0 * 60.0
        await frames(50)
        await snap("%02d_%s" % [i, stop[0]])
        i += 1
        if i > 13:
            break
    quit(0)
