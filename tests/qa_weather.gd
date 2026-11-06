extends SceneTree
# Visual QA (1.49): fog, rain and snow live in the world - two shots a few
# steps apart show the banks and the drops staying put while the camera moves.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_weather.gd -- --qa-output=<dir>
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
    game.field_hints.enabled = false
    game._qa_move_to_world_chunk(Vector2i(0, 0))
    await frames(20)
    var p0 = game.player.global_position
    # thick morning fog
    game.weather_state = "cloudy"
    game.world_minutes = 9.0 * 60.0
    game._qa_fog = 0.85
    game.fog_density = 0.85
    await frames(30)
    await snap("fog_a")
    game.player.global_position = p0 + Vector2(90, 0)
    await frames(2)
    await snap("fog_b")
    game.player.global_position = p0
    game._qa_fog = 0.0
    game.fog_density = 0.0
    # rain at noon
    game.weather_state = "rain"
    game.world_minutes = 12.0 * 60.0
    await frames(40)
    await snap("rain_a")
    game.player.global_position = p0 + Vector2(90, 0)
    await frames(1)
    await snap("rain_b")
    game.player.global_position = p0
    # snow before dawn
    game.world_minutes = 5.0 * 60.0
    await frames(60)
    print("SNOWING ", game._is_snowing())
    await snap("snow_a")
    quit(0)
