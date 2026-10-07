extends SceneTree
const Main = preload("res://main_script_mod.gd")
const WorldChronicle = preload("res://world/world_chronicle.gd")
var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok: failures += 1; printerr("FAIL: ",msg)
func _initialize() -> void:
    var isolated=OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated=="" or not OS.get_user_data_dir().begins_with(isolated+"/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT."); quit(2); return
    call_deferred("run")
func run() -> void:
    var game=Main.new(); root.add_child(game); await process_frame; await process_frame
    var clue=Node2D.new(); clue.set_meta("story_id","vector_core_engineer_note"); clue.set_meta("story_title","Запись инженерной смены"); clue.set_meta("story_text","Проверка schema-122 High Risk story state."); clue.set_meta("display_name","ЖУРНАЛ"); game.add_child(clue)
    game._read_story_clue(clue)
    check(WorldChronicle.story_seen(game.faction_state,"vector_core_engineer_note"),"High Risk story read did not mark seen")
    var raw=game.SaveStore.read_save(game.SAVE_PATH)
    check(int(raw.get("save_version",0))==122,"1.25-dev3 changed production save schema")
    var wc=raw.get("faction_state",{}).get("world_chronicle",{})
    check("vector_core_engineer_note" in wc.get("story_seen",[]),"High Risk story id missing from existing chronicle state")
    check(not raw.has("high_risk_story") and not raw.has("high_risk_story_seen"),"dev3 introduced top-level narrative persistence")
    game.queue_free(); await process_frame; await process_frame
    var loaded=Main.new(); root.add_child(loaded); await process_frame; await process_frame; loaded._load_data(); loaded._load_state()
    check(WorldChronicle.story_seen(loaded.faction_state,"vector_core_engineer_note"),"schema-122 reload lost High Risk story state")
    loaded.queue_free(); await process_frame
    print("HIGH RISK STORYTELLING SAVE RUNTIME 1.25-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
