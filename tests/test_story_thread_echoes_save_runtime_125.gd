extends SceneTree
const Main = preload("res://main_script_mod.gd")
const WorldChronicle = preload("res://world/world_chronicle.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok: failures+=1; printerr("FAIL: ",msg)
func _initialize()->void:
    var isolated=OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated=="" or not OS.get_user_data_dir().begins_with(isolated+"/"):
        printerr("Use dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT."); quit(2); return
    call_deferred("run")
func _read(game:Node,id:String)->void:
    var n=Node2D.new(); n.set_meta("story_id",id); n.set_meta("story_title","QA"); n.set_meta("story_text","QA prerequisite"); n.set_meta("display_name","ЗАПИСКА"); game.add_child(n); game._read_story_clue(n)
func run()->void:
    var game=Main.new(); root.add_child(game); await process_frame; await process_frame
    game.faction_state["world_chronicle"]=WorldChronicle.default_state()
    for id in ["factory_7_shift_sheet","vector_access_shift_log","vector_core_engineer_note"]: _read(game,id)
    check(WorldChronicle.story_seen(game.faction_state,"thread_power_infrastructure"),"thread id not marked seen before save")
    var raw=game.SaveStore.read_save(game.SAVE_PATH)
    check(int(raw.get("save_version",0))==122,"dev4 changed production save schema")
    var wc=raw.get("faction_state",{}).get("world_chronicle",{})
    check("thread_power_infrastructure" in wc.get("story_seen",[]),"thread synthetic id missing from existing chronicle state")
    check(not raw.has("story_threads") and not raw.has("story_thread_state"),"dev4 introduced top-level thread persistence")
    game.queue_free(); await process_frame; await process_frame
    var loaded=Main.new(); root.add_child(loaded); await process_frame; await process_frame; loaded._load_data(); loaded._load_state()
    check(WorldChronicle.story_seen(loaded.faction_state,"thread_power_infrastructure"),"schema-122 reload lost thread synthetic id")
    loaded.queue_free(); await process_frame
    print("STORY THREAD ECHOES SAVE RUNTIME 1.25-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
