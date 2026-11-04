extends SceneTree
# dev84: walking across sector borders never builds more than one sector in a
# frame - the sectors ahead are built while the survivor nears the edge, the
# ones behind are freed one a frame. (Crossing used to build three and free
# three in the same frame: a 150-800 ms hitch on every border.)
const Main = preload("res://main_script_mod.gd")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", msg)

func _initialize():
    call_deferred("run")

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(20):
        await physics_frame
    game.developer_invulnerable = true
    game.qa_bot_driver = true
    game.player.collision_mask = 0
    var crossings = 0
    var worst_built = 0
    var worst_freed = 0
    var max_loaded = 0
    var last = game.current_chunk
    var prev = game.loaded_chunks.keys()
    for leg in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
        game.qa_forced_move_direction = leg
        game.qa_locked_aim = leg
        # the stream works in _process (one sector a rendered frame); headless,
        # several rendered frames can fall between two physics steps, so the
        # count is taken per rendered frame while the walk runs on physics time
        var leg_start = Engine.get_physics_frames()
        while Engine.get_physics_frames() - leg_start < 60 * 26:
            await process_frame
            var keys = game.loaded_chunks.keys()
            var built = 0
            for k in keys:
                if not prev.has(k):
                    built += 1
            var freed = 0
            for k in prev:
                if not keys.has(k):
                    freed += 1
            worst_built = max(worst_built, built)
            worst_freed = max(worst_freed, freed)
            max_loaded = max(max_loaded, keys.size())
            prev = keys
            if game.current_chunk != last:
                crossings += 1
                last = game.current_chunk
            # what must be there is there
            var c = game.current_chunk
            for y in range(c.y - 1, c.y + 2):
                for x in range(c.x - 1, c.x + 2):
                    if not game.loaded_chunks.has(Vector2i(x, y)):
                        check(false, "sector %s missing around the survivor" % Vector2i(x, y))
    game.qa_forced_move_direction = Vector2.ZERO
    check(crossings >= 3, "the walk crossed only %d borders" % crossings)
    check(worst_built <= 1, "%d sectors built in one frame" % worst_built)
    check(worst_freed <= 1, "%d sectors freed in one frame" % worst_freed)
    # 9 around him + 5 ahead at a corner + one waiting to be freed + slack
    check(max_loaded <= 16, "%d sectors loaded at once" % max_loaded)
    print("CHUNK STREAMING dev84: ", checks, " checks, ", failures, " failures (crossings=", crossings, " max_loaded=", max_loaded, ")")
    quit(1 if failures else 0)
