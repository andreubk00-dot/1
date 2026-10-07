extends SceneTree
# Visual QA for 1.24-dev3 minor-POI final pass.
# Run with Godot 4.7.2:
#   godot --path . --script tests/qa_minor_poi_dressing_capture.gd -- --qa-output=/abs/dir
const Main = preload("res://main_script_mod.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

const TARGETS = [
    {"name":"zarya_old","poi":"dacha_coop_zarya","offset":Vector2i(-1,0)},
    {"name":"zarya_garden","poi":"dacha_coop_zarya","offset":Vector2i(0,1)},
    {"name":"police_yard","poi":"district_police","offset":Vector2i(1,0)},
    {"name":"cordon_clearing","poi":"hunting_cordon","offset":Vector2i(1,0)}
]
var output := ""
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")
func run() -> void:
    if output == "":
        printerr("Pass --qa-output=<dir>"); quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    var game = Main.new(); root.add_child(game)
    for i in range(5): await process_frame
    game.world_minutes = 13.0 * 60.0; game.weather_state = "clear"
    for node in game.find_children("*","CanvasLayer",true,false): node.visible = false
    if game.camera != null: game.camera.enabled = false
    var cam = Camera2D.new(); game.add_child(cam); cam.enabled = true; cam.make_current()
    for target in TARGETS:
        var poi = RegionCatalog.poi_by_id(str(target["poi"]))
        var coord:Vector2i = poi.get("coord",Vector2i.ZERO) + target["offset"]
        game.player.global_position = Vector2(coord) * 768.0 + Vector2(384,650)
        for i in range(18): await process_frame
        if not game.loaded_chunks.has(coord): game._load_chunk(coord)
        for i in range(4): await process_frame
        cam.global_position = Vector2(coord) * 768.0 + Vector2(384,384)
        cam.zoom = Vector2(360.0 / 780.0,360.0 / 780.0)
        await process_frame; await RenderingServer.frame_post_draw
        var path = "%s/%s_%d_%d.png" % [output,str(target["name"]),coord.x,coord.y]
        var err = root.get_texture().get_image().save_png(path)
        print("DEV3 MINOR POI CAPTURE: ",path," err=",err)
        if err != OK: quit(3); return
    game.queue_free(); await process_frame; quit(0)
