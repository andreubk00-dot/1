extends SceneTree
const Main = preload("res://main_script_mod.gd")

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
    game.discovered_chunks = {"0:0":true,"1:0":true,"0:1":true}
    game.discovered_pois = {"central_clinic":true}
    game._save_state()
    var raw = game.SaveStore.read_save(game.SAVE_PATH)
    check(int(raw.get("save_version",0)) == 122,"dev18 changed production save schema")
    check(not raw.has("district_survey") and not raw.has("region_survey_context"),"dev18 persisted derived district survey presentation")
    check(bool(raw.get("discovered_chunks",{}).get("0:0",false)) and bool(raw.get("discovered_pois",{}).get("central_clinic",false)),"production save lost existing exploration knowledge")
    game.queue_free(); await process_frame; await process_frame

    var loaded = Main.new(); root.add_child(loaded)
    await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    var context = loaded.RegionSurveyContext.context_for_coord(Vector2i(0,0),loaded.discovered_chunks,loaded.discovered_pois,[])
    check(str(context.get("district_id","")) == "old_center","loaded schema-122 save cannot reconstruct district identity")
    check(int(context.get("known_sectors",0)) == 3,"loaded schema-122 save cannot reconstruct district survey progress")
    check(context.get("known_landmarks",[]) == ["ПОЛИКЛИНИКА"],"loaded schema-122 save cannot reconstruct known district landmarks")
    loaded.queue_free(); await process_frame

    print("DISTRICT SURVEY CONTEXT SAVE RUNTIME 1.23-dev18: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
