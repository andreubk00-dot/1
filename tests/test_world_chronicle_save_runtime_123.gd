extends SceneTree
const Main = preload("res://main_script_mod.gd")

var failures := 0
var checks := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.world_day = 17
    game.world_minutes = 615.0
    game._record_world_news("supply","perron","Перрон: контрольный рейс вернулся на маршрут.",17,615,false)
    game.WorldChronicle.mark_read(game.faction_state)
    game._record_world_news("relations","rubezh","Рубеж сообщает: совместный пост снова принимает связных.",17,630,false)
    check(game.WorldChronicle.entries(game.faction_state,10).size() == 2,"fixture chronicle history missing")
    check(game.WorldChronicle.unread_count(game.faction_state) == 1,"fixture unread state missing")
    game._save_state()

    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    var entries = loaded.WorldChronicle.entries(loaded.faction_state,10,false)
    check(entries.size() == 2,"production save/load lost chronicle history")
    check(loaded.WorldChronicle.unread_count(loaded.faction_state) == 1,"production save/load changed chronicle read position")
    check(str(entries[0].get("text","")).find("контрольный рейс") >= 0,"production save/load changed first chronicle text")
    check(int(entries[1].get("minute",0)) == 630,"production save/load changed chronicle timestamp")
    check(int(loaded.faction_state.get("world_chronicle",{}).get("serial",0)) == 2,"production save/load changed chronicle serial")

    loaded.free()
    game.queue_free()
    await process_frame
    await process_frame
    print("WORLD CHRONICLE SAVE RUNTIME 1.23-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
