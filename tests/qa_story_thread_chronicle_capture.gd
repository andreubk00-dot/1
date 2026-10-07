extends SceneTree
# Visual QA for 1.25-dev4 synthesized field summaries in the existing chronicle UI.
const Main = preload("res://main_script_mod.gd")
const WorldChronicle = preload("res://world/world_chronicle.gd")
var output := ""
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
    call_deferred("run")
func run() -> void:
    if output=="": printerr("Pass --qa-output=<dir>"); quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    var game=Main.new(); root.add_child(game)
    for i in range(6): await process_frame
    game.faction_state["world_chronicle"]=WorldChronicle.default_state()
    for id in ["district_hospital_triage_sheet","clinical_wards_transfer_sheet","clinical_surgery_last_board"]:
        WorldChronicle.append_story(game.faction_state,game.world_day,int(game.world_minutes),id,"QA trace","QA prerequisite")
    game._resolve_story_thread_echoes()
    game._open_world_chronicle()
    for i in range(4): await process_frame
    await RenderingServer.frame_post_draw
    var path="%s/story_thread_chronicle.png" % output
    var err=root.get_texture().get_image().save_png(path)
    print("DEV4 STORY THREAD CAPTURE: ",path," err=",err)
    game.queue_free(); await process_frame
    quit(0 if err==OK else 2)
