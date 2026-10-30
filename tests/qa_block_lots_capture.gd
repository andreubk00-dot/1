extends SceneTree
# Visual QA for the dev79 block lots and street scenes: finds one of every kind
# (or of --qa-only=<kind>, several; streets as street_<kind>) and shoots it at
# gameplay zoom.
# xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_block_lots_capture.gd -- --qa-output=<dir> [--qa-only=square] [--qa-count=1]
#   [--qa-aerial=x,y]  instead: one aerial shot of the 3 x 3 sectors round x,y
const Main = preload("res://main_script_mod.gd")
var output = ""
var only = ""
var count = 1
var aerial = null

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-only="):
            only = arg.trim_prefix("--qa-only=")
        if arg.begins_with("--qa-count="):
            count = int(arg.trim_prefix("--qa-count="))
        if arg.begins_with("--qa-aerial="):
            var p = arg.trim_prefix("--qa-aerial=").split(",")
            aerial = Vector2i(int(p[0]),int(p[1]))
    call_deferred("run")

func _snap(path:String):
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(path)

func _aerial(game,c:Vector2i):
    game.player.global_position = Vector2(c) * 768.0 + Vector2(384,384)
    for i in range(20):
        await process_frame
    for dy in range(-2,3):
        for dx in range(-2,3):
            if not game.loaded_chunks.has(c + Vector2i(dx,dy)):
                game._load_chunk(c + Vector2i(dx,dy))
    game.camera.enabled = false
    var cam = Camera2D.new()
    game.add_child(cam)
    cam.enabled = true
    cam.make_current()
    for i in range(8):
        await process_frame
    game.world_minutes = 13.0 * 60.0
    game._update_day_night(0.0)
    cam.global_position = Vector2(c) * 768.0 + Vector2(384,384)
    cam.zoom = Vector2(0.56,0.56)
    await _snap("%s/aerial_%d_%d.png" % [output,c.x,c.y])

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(4):
        await process_frame
    for node in game.find_children("*","CanvasLayer",true,false):
        node.visible = false
    if aerial != null:
        await _aerial(game,aerial)
        quit(0)
        return
    # find lots: a spiral of sectors round the start
    var found = {}
    for r in range(1,16):
        for y in range(-r,r + 1):
            for x in range(-r,r + 1):
                if max(abs(x),abs(y)) != r:
                    continue
                var c = Vector2i(x,y)
                if not game.loaded_chunks.has(c):
                    game._load_chunk(c)
                var ch = game.loaded_chunks.get(c,null)
                if ch == null:
                    continue
                for n in ch.get_children():
                    if n.has_meta("block_lot") or n.has_meta("street_scene"):
                        var k = str(n.get_meta("block_lot")) if n.has_meta("block_lot") else "street_" + str(n.get_meta("street_scene"))
                        if only != "" and k != only:
                            continue
                        if not found.has(k):
                            found[k] = []
                        if found[k].size() < count:
                            found[k].append([c,ch.position + n.position])
                game._unload_chunk(c)
        await process_frame
    print("LOTS FOUND ",found.keys())
    game.camera.enabled = false
    var cam = Camera2D.new()
    game.add_child(cam)
    cam.enabled = true
    cam.make_current()
    game.world_minutes = 13.0 * 60.0
    for k in found.keys():
        var idx = 0
        for entry in found[k]:
            var c:Vector2i = entry[0]
            var at:Vector2 = entry[1]
            game.player.global_position = at + Vector2(0,170)
            for i in range(20):
                await process_frame
            for dy in range(-1,2):
                for dx in range(-1,2):
                    if not game.loaded_chunks.has(c + Vector2i(dx,dy)):
                        game._load_chunk(c + Vector2i(dx,dy))
            for i in range(8):
                await process_frame
            game.world_minutes = 13.0 * 60.0
            game._update_day_night(0.0)
            cam.global_position = at + Vector2(0,30)
            cam.zoom = Vector2(1.0,1.0)
            await _snap("%s/lot_%s_%d.png" % [output,k,idx])
            print("LOT CAPTURE ",k," ",c," ",at)
            idx += 1
    quit(0)
