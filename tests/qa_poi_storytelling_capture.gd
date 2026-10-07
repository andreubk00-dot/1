extends SceneTree
# Visual QA for 1.25-dev2 authored POI story traces.
const Main = preload("res://main_script_mod.gd")
const PoiStoryCatalog = preload("res://world/poi_story_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

const TARGET_KEYS = ["rail_depot|0,0","dacha_coop_zarya|0,0","district_hospital|0,0","military_checkpoint|0,0"]
var output := ""
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
    call_deferred("run")
func _find_story(root:Node,story_id:String):
    var stack:Array=[root]
    while not stack.is_empty():
        var node:Node=stack.pop_back()
        if str(node.get_meta("story_id","")) == story_id: return node
        for child in node.get_children(): stack.append(child)
    return null
func run() -> void:
    if output == "": printerr("Pass --qa-output=<dir>"); quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    var game=Main.new(); root.add_child(game)
    for i in range(5): await process_frame
    game.world_minutes=13.0*60.0; game.weather_state="clear"
    if game.camera != null: game.camera.enabled=false
    var cam=Camera2D.new(); game.add_child(cam); cam.enabled=true; cam.make_current()
    for key in TARGET_KEYS:
        var clue:Dictionary=PoiStoryCatalog.ENTRIES[key]
        var poi=RegionCatalog.poi_by_id(str(clue.get("poi_id","")))
        var coord:Vector2i=poi.get("coord",Vector2i.ZERO)+clue.get("cell",Vector2i.ZERO)
        game.player.global_position=Vector2(coord)*game.CHUNK_SIZE+Vector2(game.CHUNK_SIZE*0.5,game.CHUNK_SIZE*0.5)
        for i in range(18): await process_frame
        if not game.loaded_chunks.has(coord): game._load_chunk(coord)
        for i in range(4): await process_frame
        var story=_find_story(game.loaded_chunks[coord],str(clue.get("id","")))
        if story == null: printerr("POI STORY MISSING: ",key); quit(2); return
        game.player.global_position=story.global_position+Vector2(34,0)
        cam.global_position=story.global_position; cam.zoom=Vector2(1.125,1.125)
        for i in range(3): await process_frame
        await RenderingServer.frame_post_draw
        var path="%s/poi_story_%s.png" % [output,str(clue.get("poi_id",""))]
        var err=root.get_texture().get_image().save_png(path)
        print("DEV2 POI STORY CAPTURE: ",path," err=",err)
        if err != OK: quit(3); return
    game.queue_free(); await process_frame; quit(0)
