extends SceneTree
const Harness=preload("res://tests/rest_harness.gd")
var output:=""
func _initialize()->void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
    call_deferred("run")
func run()->void:
    if output=="": printerr("Pass --qa-output=<dir>"); quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    var game=Harness.new(); root.add_child(game); await process_frame
    game.faction_state=game.FactionEconomy.default_state(); game.current_chunk=Vector2i(0,0); game.region_map_center=Vector2i(0,0)
    game._create_region_map_ui()
    for y in range(-1,2):
        for x in range(-1,2): game.discovered_chunks[game._zone_chunk_key(Vector2i(x,y))]=true
    game.discovered_pois["central_clinic"]=true
    game.region_map_selected_chunk=Vector2i(0,0); game.region_map_open=true; game.region_map_canvas.visible=true; game.region_map_panel.visible=true
    game._refresh_region_map_ui(); await process_frame; await RenderingServer.frame_post_draw
    var path=output+"/region_map_action_strip.png"
    var err=root.get_texture().get_image().save_png(path)
    print("REGION MAP ACTION STRIP CAPTURE: ",path," err=",err)
    game.queue_free(); await process_frame; quit(0 if err==OK else 2)
