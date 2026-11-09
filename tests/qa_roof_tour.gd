extends SceneTree
# Visual QA (1.50): roofs - the survivor in front of one building of each
# roof style, the roof and the facade in view, noon.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_roof_tour.gd -- --qa-output=<dir>
const Main = preload("res://main_script_mod.gd")
var output = ""

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")
    # a QA capture never hangs a session: quit after four minutes whatever happens
    create_timer(240.0).timeout.connect(func(): quit(0))

func frames(n: int) -> void:
    for i in range(n):
        await process_frame

func run():
    Engine.set_meta("ostatok_new_game", true)
    var game = Main.new()
    root.add_child(game)
    await frames(10)
    game.developer_invulnerable = true
    game.field_hints.finish_steps()
    game.field_hints._queue.clear()
    game.field_hints.enabled = false
    game.weather_state = "clear"
    var seen = {}
    var shot = 0
    for stop in [Vector2i(0, 0), Vector2i(-8, -2), Vector2i(3, -4), Vector2i(-5, 5), Vector2i(6, 6)]:
        if shot >= 4:
            break
        game._qa_move_to_world_chunk(stop)
        game.world_minutes = 12.0 * 60.0
        await frames(20)
        for chunk in game.find_children("Chunk_*", "", true, false):
            for r in chunk.find_children("*", "Sprite2D", true, false):
                if shot >= 4 or not r.has_meta("roof_style") or not r.is_visible_in_tree():
                    continue
                var st = int(r.get_meta("roof_style"))
                var w = r.region_rect.size.x * r.scale.x
                if seen.has(st) or w < 120:
                    continue
                seen[st] = true
                var rh = r.region_rect.size.y * r.scale.y
                game.player.global_position = r.global_position + Vector2(w * 0.5 + 30.0, rh * 0.5 + 150.0)
                await frames(25)
                await RenderingServer.frame_post_draw
                shot += 1
                root.get_texture().get_image().save_png("%s/roof_%02d_s%d.png" % [output, shot, st])
                print("SHOT ", shot, " style ", st, " ", w)
    quit(0)
