extends SceneTree
const Main = preload("res://main_script_mod.gd")
const MinorPoiDressing = preload("res://world/minor_poi_dressing.gd")

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
    var expected = MinorPoiDressing.accents_for("dacha_coop_zarya",Vector2i(-1,1))
    var game = Main.new(); root.add_child(game)
    await process_frame; await process_frame
    game.discovered_chunks = {"0:0":true,"-4:4":true}
    game._save_state()
    var raw = game.SaveStore.read_save(game.SAVE_PATH)
    check(int(raw.get("save_version",0)) == 122,"1.24-dev3 changed production save schema")
    for forbidden in ["minor_poi_dressing","minor_poi_variant","poi_dressing","dressing_accents"]:
        check(not raw.has(forbidden),"derived minor-POI dressing leaked into production save: " + forbidden)
    game.queue_free(); await process_frame; await process_frame

    var loaded = Main.new(); root.add_child(loaded)
    await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    check(bool(loaded.discovered_chunks.get("-4:4",false)),"schema-122 load lost discovered minor-POI chunk")
    check(MinorPoiDressing.accents_for("dacha_coop_zarya",Vector2i(-1,1)) == expected,"derived minor-POI dressing changed after production load")
    loaded.queue_free(); await process_frame
    print("MINOR POI DRESSING SAVE RUNTIME 1.24-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
