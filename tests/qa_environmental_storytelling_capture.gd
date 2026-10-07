extends SceneTree
# Visual QA for 1.25-dev1 authored environmental traces.
# Run with Godot 4.7.2:
#   godot --path . --script tests/qa_environmental_storytelling_capture.gd -- --qa-output=/abs/dir
const Main = preload("res://main_script_mod.gd")
const EnvironmentalStoryCatalog = preload("res://world/environmental_story_catalog.gd")

const TARGETS = [Vector2i(1,-2),Vector2i(3,-6),Vector2i(-5,1),Vector2i(-5,4)]
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
    for coord in TARGETS:
        game.player.global_position=Vector2(coord)*768.0+Vector2(384,650)
        for i in range(18): await process_frame
        if not game.loaded_chunks.has(coord): game._load_chunk(coord)
        for i in range(4): await process_frame
        var clue=EnvironmentalStoryCatalog.CLUES[EnvironmentalStoryCatalog.coord_key(coord)]
        var story=_find_story(game.loaded_chunks[coord],str(clue.get("id","")))
        if story == null: printerr("STORY CLUE MISSING: ",coord); quit(2); return
        game.player.global_position=story.global_position+Vector2(34,0)
        cam.global_position=story.global_position
        cam.zoom=Vector2(360.0/320.0,360.0/320.0)
        for i in range(3): await process_frame
        await RenderingServer.frame_post_draw
        var path="%s/story_%d_%d.png" % [output,coord.x,coord.y]
        var err=root.get_texture().get_image().save_png(path)
        print("DEV1 ENV STORY CAPTURE: ",path," err=",err)
        if err != OK: quit(3); return
    game.queue_free(); await process_frame; quit(0)
