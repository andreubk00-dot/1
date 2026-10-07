extends SceneTree
const Main = preload("res://main_script_mod.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok: failures+=1; printerr("FAIL: ",msg)
func _initialize()->void:
    var isolated=OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated=="" or not OS.get_user_data_dir().begins_with(isolated+"/"):
        printerr("Use dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")
func run()->void:
    var game=Main.new(); root.add_child(game); await process_frame; await process_frame
    game.modern_survivor_idle_time=11.5
    game._save_state()
    var raw=game.SaveStore.read_save(game.SAVE_PATH)
    check(not raw.is_empty(),"production save fixture was not written")
    check(int(raw.get("save_version",0))==122,"idle polish changed save schema")
    check(not raw.has("modern_survivor_idle_time"),"transient idle animation timer leaked into top-level save payload")
    check(not raw.get("faction_state",{}).has("modern_survivor_idle_time"),"transient idle animation timer leaked into faction_state")
    game.queue_free(); await process_frame
    print("IDLE ANIMATION SAVE BOUNDARY 1.27-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
