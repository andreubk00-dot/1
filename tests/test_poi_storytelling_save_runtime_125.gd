extends SceneTree
const Main = preload("res://main_script_mod.gd")
const WorldChronicle = preload("res://world/world_chronicle.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void:
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2); return
    call_deferred("run")

func run() -> void:
    var game = Main.new(); root.add_child(game)
    await process_frame; await process_frame
    var clue = Node2D.new()
    clue.set_meta("story_id","district_hospital_triage_sheet")
    clue.set_meta("story_title","Лист приёмного отделения")
    clue.set_meta("story_text","Проверка сохранения authored POI trace.")
    clue.set_meta("display_name","ЛИСТОК")
    game.add_child(clue)
    game._read_story_clue(clue)
    check(WorldChronicle.story_seen(game.faction_state,"district_hospital_triage_sheet"),"POI story read did not mark seen")
    var raw = game.SaveStore.read_save(game.SAVE_PATH)
    check(int(raw.get("save_version",0)) == 122,"1.25-dev2 changed production save schema")
    var raw_chronicle = raw.get("faction_state",{}).get("world_chronicle",{})
    check("district_hospital_triage_sheet" in raw_chronicle.get("story_seen",[]),"POI story id missing from existing world_chronicle state")
    check(not raw.has("poi_story") and not raw.has("poi_story_seen"),"dev2 introduced top-level POI narrative save state")
    game.queue_free(); await process_frame; await process_frame
    var loaded = Main.new(); root.add_child(loaded)
    await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    check(WorldChronicle.story_seen(loaded.faction_state,"district_hospital_triage_sheet"),"schema-122 reload lost POI story state")
    loaded.queue_free(); await process_frame
    print("AUTHORED POI STORYTELLING SAVE RUNTIME 1.25-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
