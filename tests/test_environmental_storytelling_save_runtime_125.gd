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

func _clue_node() -> Node2D:
    var node = Node2D.new()
    node.set_meta("interaction_type","story_clue")
    node.set_meta("display_name","ЛИСТОК")
    node.set_meta("story_id","north_camp_rain_log")
    node.set_meta("story_title","Промокший листок")
    node.set_meta("story_text","Проверка сохранения полевой записи.")
    return node

func run() -> void:
    var game = Main.new(); root.add_child(game)
    await process_frame; await process_frame
    var clue = _clue_node(); game.add_child(clue)
    game._read_story_clue(clue)
    check(WorldChronicle.story_seen(game.faction_state,"north_camp_rain_log"),"runtime read did not mark story seen")
    var raw = game.SaveStore.read_save(game.SAVE_PATH)
    check(int(raw.get("save_version",0)) == 122,"1.25-dev1 changed production save schema")
    var raw_chronicle = raw.get("faction_state",{}).get("world_chronicle",{})
    check("north_camp_rain_log" in raw_chronicle.get("story_seen",[]),"story seen id missing from existing world_chronicle save state")
    check(not raw.has("environmental_story") and not raw.has("story_clues"),"dev1 introduced a new top-level narrative save schema")
    var before = WorldChronicle.entries(game.faction_state,100).size()
    game.queue_free(); await process_frame; await process_frame

    var loaded = Main.new(); root.add_child(loaded)
    await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    check(WorldChronicle.story_seen(loaded.faction_state,"north_camp_rain_log"),"schema-122 load lost story seen state")
    var repeat = WorldChronicle.append_story(loaded.faction_state,loaded.world_day,int(loaded.world_minutes),"north_camp_rain_log","Промокший листок","Проверка сохранения полевой записи.")
    check(not bool(repeat.get("new",true)),"loaded story clue can duplicate chronicle entry")
    check(WorldChronicle.entries(loaded.faction_state,100).size() == before,"loaded repeat story read grew chronicle")
    loaded.queue_free(); await process_frame
    print("ENVIRONMENTAL STORYTELLING SAVE RUNTIME 1.25-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
