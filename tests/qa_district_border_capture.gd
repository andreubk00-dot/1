extends SceneTree
# Shots of the seams between district grounds: for the nearest chunk pairs
# with different ground families, the border is shot where it crosses the road
# and where it crosses the plots.
# xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_district_border_capture.gd -- --qa-output=<dir> [--qa-max=8]
const Main = preload("res://main_script_mod.gd")
var output = ""
var max_pairs = 16

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-max="):
            max_pairs = int(arg.trim_prefix("--qa-max="))
    call_deferred("run")

func _snap(path:String):
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(path)

const RegionCatalog = preload("res://world/region_catalog.gd")

func _kind(game,c) -> String:
    # a location (POI / settlement / High Risk site) counts as its own ground
    var poi = RegionCatalog.poi_for_chunk(c)
    if not poi.is_empty():
        return "poi-" + str(poi.get("id","?"))
    return game._ground_family(c)

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
    cam.make_current()
    var pairs = []
    var seen = {}
    for r in range(0,13):
        for y in range(-r,r + 1):
            for x in range(-r,r + 1):
                if max(abs(x),abs(y)) != r:
                    continue
                var c = Vector2i(x,y)
                for dir in [Vector2i(1,0),Vector2i(0,1)]:
                    var a = _kind(game,c)
                    var b = _kind(game,c + dir)
                    var key = a + ">" + b if a < b else b + ">" + a
                    if a != b and not seen.has(key + str(dir)):
                        seen[key + str(dir)] = true
                        pairs.append([c,dir,a,b])
    var n = 0
    for p in pairs:
        if n >= max_pairs:
            break
        var c:Vector2i = p[0]
        var dir:Vector2i = p[1]
        var edge = Vector2(c) * 768.0 + Vector2(dir) * 768.0
        for k in range(2):
            # k 0: across the road, k 1: across the plots
            var along = 384.0 if k == 0 else 150.0
            var at = edge + (Vector2(0,along) if dir.x == 1 else Vector2(along,0))
            game.player.global_position = at + Vector2(0,40)
            for i in range(24):
                await process_frame
            for d in [Vector2i(0,0),dir]:
                if not game.loaded_chunks.has(c + d):
                    game._load_chunk(c + d)
            for i in range(4):
                await process_frame
            # keep the player near (chunks stay loaded) but off the frame
            game.player.global_position = at + (Vector2(0,330) if dir.x == 1 else Vector2(330,0))
            game.world_minutes = 13.0 * 60.0
            cam.global_position = at
            cam.zoom = Vector2(1.0,1.0)
            await _snap("%s/border_%d_%s_%s_%s.png" % [output,n,p[2] if p[2] != "" else "city",p[3] if p[3] != "" else "city","road" if k == 0 else "plot"])
        print("BORDER ",c," ",dir," ",p[2]," | ",p[3])
        n += 1
    quit(0)
