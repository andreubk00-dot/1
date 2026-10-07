extends SceneTree
# Requires isolated XDG_DATA_HOME + matching OSTATOK_QA_SAVE_ROOT.
const Main=preload("res://main_script_mod.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",why)
func _initialize()->void:
    var isolated=OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated=="" or not OS.get_user_data_dir().begins_with(isolated+"/"):
        printerr("Use dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")
func run()->void:
    var game=Main.new()
    root.add_child(game)
    await process_frame
    await process_frame
    game.equipped_melee_id="combat_knife"
    game.modern_survivor_idle_time=12.375
    game._save_state()
    var raw=game.SaveStore.read_save(game.SAVE_PATH)
    check(not raw.is_empty(),"no production save")
    check(int(raw.get("save_version",0))==122,"save schema changed")
    check(not raw.has("modern_survivor_idle_time"),"idle timer leaked to top-level save")
    check(not raw.has("modern_survivor_idle_frame"),"idle frame leaked to top-level save")
    var faction=raw.get("faction_state",{})
    check(not faction.has("modern_survivor_idle_time"),"idle timer leaked to faction_state")
    check(not faction.has("modern_survivor_idle_frame"),"idle frame leaked to faction_state")
    game.queue_free()
    await process_frame
    print("LOCOMOTION SAVE BOUNDARY 1.27-dev2: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
