extends SceneTree
# Close-ups of single buildings for visual bug hunting (floors or walls showing
# past the facade, roof/facade seams, shadows): every building of the sampled
# chunks is shot from outside, and once more with the player inside.
# xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_building_closeup_capture.gd -- --qa-output=<dir> [--qa-chunks=x,y;x,y]
const Main = preload("res://main_script_mod.gd")
var output = ""
var chunks = [Vector2i(-1,-1),Vector2i(2,-1),Vector2i(2,1),Vector2i(-2,2),Vector2i(3,-3),Vector2i(-4,0)]

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-chunks="):
            chunks = []
            for p in arg.trim_prefix("--qa-chunks=").split(";"):
                var xy = p.split(",")
                chunks.append(Vector2i(int(xy[0]),int(xy[1])))
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
    for c in chunks:
        var center = Vector2(c) * 768.0 + Vector2(384,384)
        game.player.global_position = center
        for i in range(30):
            await process_frame
        if not game.loaded_chunks.has(c):
            game._load_chunk(c)
        var chunk = game.loaded_chunks.get(c)
        if chunk == null:
            continue
        var n = 0
        for b in chunk.get_children():
            if not b.has_meta("world_building"):
                continue
            var sz:Vector2 = b.get_meta("building_size",Vector2(100,100))
            var fh = float(b.get_meta("facade_height",0.0))
            var mid = b.global_position + Vector2(0,-fh * 0.5 + 10)
            # outside: player far below, the roof is opaque
            game.player.global_position = b.global_position + Vector2(0,sz.y * 0.5 + 150)
            for i in range(16):
                await process_frame
            game.world_minutes = 13.0 * 60.0
            cam.global_position = mid
            var z = clamp(min(1100.0 / (sz.x + 120.0),560.0 / (sz.y + fh + 120.0)),1.0,3.0)
            cam.zoom = Vector2(z,z)
            await _snap("%s/b_%d_%d_%d_out.png" % [output,c.x,c.y,n])
            # inside: the roof fades and the interior shows
            game.player.global_position = b.global_position
            for i in range(24):
                await process_frame
            game.world_minutes = 13.0 * 60.0
            await _snap("%s/b_%d_%d_%d_in.png" % [output,c.x,c.y,n])
            print("BUILDING ",c," ",n," ",b.get_meta("building_id","")," size ",sz," fh ",fh)
            n += 1
    quit(0)
