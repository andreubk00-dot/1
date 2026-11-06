extends SceneTree
# Visual QA (1.43): inside buildings - the survivor a step inside the door of
# one building of each kind, roofs lifted, noon.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_interior_tour.gd -- --qa-output=<dir>
const Main = preload("res://main_script_mod.gd")
var output = ""
var want_kind = ""
var game = null

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-kind="):
            want_kind = arg.trim_prefix("--qa-kind=")
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await process_frame

func run():
    Engine.set_meta("ostatok_new_game", true)
    game = Main.new()
    root.add_child(game)
    await frames(10)
    game.developer_invulnerable = true
    game.field_hints.finish_steps()
    game.field_hints._queue.clear()
    game.field_hints.enabled = false
    if "weather_state" in game:
        game.weather_state = "clear"
    var seen = {}
    var shot = 0
    var stops = [Vector2i(0, 0), Vector2i(-8, -2), Vector2i(3, -4), Vector2i(-5, 5), Vector2i(6, 6), Vector2i(-3, -7), Vector2i(8, -1)]
    if want_kind != "":
        stops = [Vector2i(2, 2), Vector2i(-2, 3), Vector2i(4, -2), Vector2i(-4, -3), Vector2i(1, 5), Vector2i(-6, 1), Vector2i(5, 4), Vector2i(-1, -5), Vector2i(7, 2), Vector2i(-7, -6)]
    for stop in stops:
        game._qa_move_to_world_chunk(stop)
        game.world_minutes = 12.0 * 60.0
        await frames(30)
        for b in game.get_tree().get_nodes_in_group("world_buildings"):
            if shot >= 14:
                break
            if not is_instance_valid(b) or not b.has_meta("building_size"):
                continue
            var size: Vector2 = b.get_meta("building_size")
            if size.x < 110 or size.y < 90:
                continue
            if want_kind != "":
                var has = false
                for c in b.get_children():
                    if c is Sprite2D and game.HOME_PROP_REGIONS.has(str(c.get_meta("world_prop_kind", ""))):
                        has = true
                if not has:
                    continue
            var kind = str(b.get_meta("archetype_id", b.get_meta("sign_text", "")))
            var key = "%s:%d" % [kind, int(size.x / 80)]
            if seen.has(key):
                continue
            seen[key] = true
            game.player.global_position = b.global_position + Vector2(float(b.get_meta("door_local_x", 0.0)), size.y * 0.5 - 30.0)
            await frames(25)
            await RenderingServer.frame_post_draw
            shot += 1
            root.get_texture().get_image().save_png("%s/%02d_%s.png" % [output, shot, str(b.get_meta("building_id", ""))])
            print("SHOT ", shot, " ", b.get_meta("building_id", ""), " ", size)
    quit(0)
