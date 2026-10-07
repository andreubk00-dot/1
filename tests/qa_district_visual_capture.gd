extends SceneTree
# Visual QA across the open world: for every district one representative
# (non-POI) chunk is loaded and shot wide and at gameplay zoom.
# xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_district_visual_capture.gd -- --qa-output=<dir> [--qa-only=<district_id>]
const Main = preload("res://main_script_mod.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
var output = ""
var only = ""

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-only="):
            only = arg.trim_prefix("--qa-only=")
    call_deferred("run")

func _snap(path:String):
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(path)

func _sample_chunks() -> Dictionary:
    # nearest chunk of every district, skipping POI footprints
    var found = {}
    for r in range(0,26):
        for y in range(-r,r + 1):
            for x in range(-r,r + 1):
                if max(abs(x),abs(y)) != r:
                    continue
                var c = Vector2i(x,y)
                var d = RegionCatalog.district_id_for_chunk(c)
                if found.has(d):
                    continue
                if not RegionCatalog.poi_for_chunk(c).is_empty():
                    continue
                found[d] = c
    return found

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
    var samples = _sample_chunks()
    for d in samples.keys():
        if only != "" and d != only:
            continue
        var c:Vector2i = samples[d]
        var center = Vector2(c) * 768.0 + Vector2(384,384)
        game.player.global_position = center + Vector2(0,300)
        for i in range(30):
            await process_frame
        for dy in range(-1,2):
            for dx in range(-1,2):
                if not game.loaded_chunks.has(c + Vector2i(dx,dy)):
                    game._load_chunk(c + Vector2i(dx,dy))
        for i in range(6):
            await process_frame
        game.world_minutes = 13.0 * 60.0
        cam.global_position = center
        cam.zoom = Vector2(0.62,0.62)
        await _snap("%s/%s_wide.png" % [output,d])
        for k in range(2):
            var local = Vector2(384,250) if k == 0 else Vector2(384,560)
            game.player.global_position = Vector2(c) * 768.0 + local + Vector2(0,60)
            for i in range(14):
                await process_frame
            game.world_minutes = 13.0 * 60.0
            cam.global_position = Vector2(c) * 768.0 + local
            cam.zoom = Vector2(1.0,1.0)
            await _snap("%s/%s_%s.png" % [output,d,"a" if k == 0 else "b"])
        print("DISTRICT CAPTURE ",d," ",c)
    quit(0)
