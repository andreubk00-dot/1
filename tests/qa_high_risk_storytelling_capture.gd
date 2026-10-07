extends SceneTree
# Visual QA for 1.25-dev3 High Risk environmental traces.
const Main = preload("res://main_script_mod.gd")
const HighRiskStoryCatalog = preload("res://world/high_risk_story_catalog.gd")
const HighRiskFloorCatalog = preload("res://world/high_risk_floor_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
var output := ""
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
    call_deferred("run")
func _find_story(root:Node,story_id:String):
    var stack:Array=[root]
    while not stack.is_empty():
        var node:Node=stack.pop_back()
        if str(node.get_meta("story_id",""))==story_id: return node
        for child in node.get_children(): stack.append(child)
    return null
func _capture(game:Node,cam:Camera2D,node:Node,path:String) -> int:
    game.player.global_position=node.global_position+Vector2(34,0); cam.global_position=node.global_position; cam.zoom=Vector2(1.125,1.125)
    for i in range(3): await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image().save_png(path)
func run() -> void:
    if output=="": printerr("Pass --qa-output=<dir>"); quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    var game=Main.new(); root.add_child(game)
    for i in range(5): await process_frame
    game.world_minutes=13.0*60.0; game.weather_state="clear"
    if game.camera!=null: game.camera.enabled=false
    var cam=Camera2D.new(); game.add_child(cam); cam.enabled=true; cam.make_current()
    for key in ["regional_clinical_complex_4|0,1","reserve_arsenal_bastion|0,0"]:
        var clue:Dictionary=HighRiskStoryCatalog.GROUND[key]; var poi=RegionCatalog.poi_by_id(str(clue.get("poi_id",""))); var coord:Vector2i=poi.get("coord",Vector2i.ZERO)+clue.get("cell",Vector2i.ZERO)
        game.player.global_position=Vector2(coord)*game.CHUNK_SIZE+Vector2(game.CHUNK_SIZE*0.5,game.CHUNK_SIZE*0.5)
        for i in range(18): await process_frame
        if not game.loaded_chunks.has(coord): game._load_chunk(coord)
        for i in range(4): await process_frame
        var story=_find_story(game.loaded_chunks[coord],str(clue.get("id","")))
        if story==null: printerr("GROUND STORY MISSING: ",key); quit(2); return
        var err=await _capture(game,cam,story,"%s/hr_story_ground_%s.png" % [output,str(clue.get("poi_id",""))]); if err!=OK: quit(3); return
    for key in ["quarantine_center_12|3","underground_object_vector|3"]:
        var clue:Dictionary=HighRiskStoryCatalog.FLOORS[key]; var floor_root=Node2D.new(); game.add_child(floor_root); game._build_high_risk_floor(floor_root,str(clue.get("poi_id","")),3,HighRiskFloorCatalog.floor(str(clue.get("poi_id","")),3)); await process_frame
        var story=_find_story(floor_root,str(clue.get("id","")))
        if story==null: printerr("FLOOR STORY MISSING: ",key); quit(4); return
        var err=await _capture(game,cam,story,"%s/hr_story_floor_%s.png" % [output,str(clue.get("poi_id",""))]); if err!=OK: quit(5); return
        floor_root.queue_free(); await process_frame
    game.queue_free(); await process_frame; quit(0)
