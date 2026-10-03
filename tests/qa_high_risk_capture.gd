extends SceneTree
# Visual QA for High Risk locations: overview of every site plus gameplay-zoom
# shots of every sector. Usage:
# xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_high_risk_capture.gd -- --qa-output=<dir> [--qa-only=<poi_id>] [--qa-night]
const Main = preload("res://main_script_mod.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const SITES = ["regional_clinical_complex_4","quarantine_center_12","reserve_arsenal_bastion","underground_object_vector"]
var output = ""
var only = ""
var night = false

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-only="):
            only = arg.trim_prefix("--qa-only=")
        if arg == "--qa-night":
            night = true
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
    for poi_id in SITES:
        if only != "" and poi_id != only:
            continue
        var poi = RegionCatalog.poi_by_id(poi_id)
        var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
        var fp = PoiCatalog.footprint(poi_id)
        var lo = Vector2i(999,999)
        var hi = Vector2i(-999,-999)
        for o in fp:
            lo = Vector2i(min(lo.x,o.x),min(lo.y,o.y))
            hi = Vector2i(max(hi.x,o.x),max(hi.y,o.y))
        var center = (Vector2(anchor + lo) + Vector2(anchor + hi) + Vector2.ONE) * 384.0
        game.player.global_position = center
        for i in range(30):
            await process_frame
        for o in fp:
            if not game.loaded_chunks.has(anchor + o):
                game._load_chunk(anchor + o)
        for i in range(6):
            await process_frame
        game.world_minutes = (22.5 if night else 13.0) * 60.0
        var span = Vector2(hi - lo + Vector2i.ONE) * 768.0
        var z = min(640.0 / span.x,360.0 / span.y)
        cam.global_position = center
        cam.zoom = Vector2(z,z)
        await _snap("%s/%s_overview%s.png" % [output,poi_id,"_night" if night else ""])
        var k = 0
        for o in fp:
            var c = anchor + o
            for local in [Vector2(384,300),Vector2(384,560)]:
                game.player.global_position = Vector2(c) * 768.0 + local + Vector2(0,60)
                for i in range(16):
                    await process_frame
                game.world_minutes = (22.5 if night else 13.0) * 60.0
                cam.global_position = Vector2(c) * 768.0 + local
                cam.zoom = Vector2(1.0,1.0)
                await _snap("%s/%s_cell_%d_%d_%s%s.png" % [output,poi_id,o.x,o.y,"a" if local.y < 400 else "b","_night" if night else ""])
                k += 1
        print("HR CAPTURE ",poi_id," ",k)
    quit(0)
