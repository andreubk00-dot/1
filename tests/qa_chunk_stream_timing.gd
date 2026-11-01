extends SceneTree
# Perf QA (dev84): run across several sectors for real (forced movement) and
# report the frame times a player would feel at the borders.
# godot --headless --script tests/qa_chunk_stream_timing.gd
const Main = preload("res://main_script_mod.gd")

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
    var times = []
    var crossings = 0
    var last = game.current_chunk
    var prev_keys = game.loaded_chunks.keys()
    for leg in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
        game.qa_forced_move_direction = leg
        game.qa_locked_aim = leg
        for i in range(60 * 30):
            var t0 = Time.get_ticks_usec()
            await physics_frame
            var dt = Time.get_ticks_usec() - t0
            times.append(dt)
            var keys = game.loaded_chunks.keys()
            if dt > 80000 and OS.get_cmdline_user_args().has("--verbose"):
                var added = []
                for k in keys:
                    if not prev_keys.has(k): added.append(k)
                var gone = []
                for k in prev_keys:
                    if not keys.has(k): gone.append(k)
                print("LONG %d us at %s cross=%s +%s -%s" % [dt, game.current_chunk, game.current_chunk != last, added, gone])
            prev_keys = keys
            if game.current_chunk != last:
                crossings += 1
                last = game.current_chunk
    game.qa_forced_move_direction = Vector2.ZERO
    times.sort()
    var n = times.size()
    var over50 = 0
    var over100 = 0
    for t in times:
        if t > 50000: over50 += 1
        if t > 100000: over100 += 1
    print("STREAM frames=%d crossings=%d p50=%d p99=%d max=%d us  >50ms=%d >100ms=%d loaded=%d" % [n, crossings, times[n / 2], times[int(n * 0.99)], times[n - 1], over50, over100, game.loaded_chunks.size()])
    quit(0)
