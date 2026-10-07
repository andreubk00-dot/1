extends SceneTree
const Main = preload("res://main_script_mod.gd")
const WorldContentVariety = preload("res://world/world_content_variety.gd")

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
    var coord = Vector2i(7,3)
    var expected_variant = WorldContentVariety.variant_for(coord,"warehouse",1)
    var expected_seed = WorldContentVariety.visual_seed_key(coord,"warehouse",1)

    var game = Main.new(); root.add_child(game)
    await process_frame; await process_frame
    game.discovered_chunks = {"0:0":true,"7:3":true}
    game._save_state()
    var raw = game.SaveStore.read_save(game.SAVE_PATH)
    check(int(raw.get("save_version",0)) == 122,"1.24-dev1 changed production save schema")
    for forbidden in ["world_content_variety","content_variant","content_seed","procedural_dressing"]:
        check(not raw.has(forbidden),"derived world-content state leaked into production save: " + forbidden)
    check(int(raw.get("building_layout_version",0)) == game.BUILDING_LAYOUT_VERSION,"existing building layout version was not preserved")
    game.queue_free(); await process_frame; await process_frame

    var loaded = Main.new(); root.add_child(loaded)
    await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    check(bool(loaded.discovered_chunks.get("7:3",false)),"schema-122 load lost discovered chunk")
    check(WorldContentVariety.variant_for(coord,"warehouse",1) == expected_variant,"derived dressing variant changed after production load")
    check(WorldContentVariety.visual_seed_key(coord,"warehouse",1) == expected_seed,"derived visual seed changed after production load")
    loaded.queue_free(); await process_frame

    print("WORLD CONTENT VARIETY SAVE RUNTIME 1.24-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
