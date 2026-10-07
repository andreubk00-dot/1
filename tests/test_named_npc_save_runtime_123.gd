extends SceneTree
const Main = preload("res://main_script_mod.gd")

var checks := 0
var failures := 0
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
    game.world_day = 23
    game.world_minutes = 840.0
    game._set_named_npc_status("mechanics_electrician","wounded","Пострадал на ремонтном выезде.")
    game.FactionNpcState.record_interaction(game.faction_state,"mechanics_electrician",23,"contract_complete","Игрок доставил детали.",7)
    game._set_named_npc_status("lazaret_researcher","missing","Не вернулся из лабораторного корпуса.")
    game._save_state()

    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    var electrician = loaded.FactionNpcState.record(loaded.faction_state,"mechanics_electrician",23)
    var researcher = loaded.FactionNpcState.record(loaded.faction_state,"lazaret_researcher",23)
    check(str(electrician.get("status","")) == "wounded","production save/load lost wounded NPC status")
    check(int(electrician.get("attitude",0)) == 7,"production save/load lost personal attitude")
    check(int(electrician.get("interaction_count",0)) == 1,"production save/load lost interaction count")
    check(electrician.get("history",[]).size() == 2,"production save/load lost NPC history rows")
    check(str(researcher.get("status","")) == "missing","production save/load lost missing NPC status")
    check(not loaded.FactionNpcState.service_available(loaded.faction_state,"lazaret_researcher",23),"missing NPC service became available after load")
    var npc_news = loaded.WorldChronicle.entries(loaded.faction_state,10)
    check(npc_news.size() == 2,"production save/load lost NPC world news")
    check(int(loaded.faction_state.get("named_npcs",{}).get("records",{}).size()) == 16,"production save/load changed canonical NPC roster size")

    loaded.free()
    game.queue_free()
    await process_frame
    await process_frame
    print("NAMED NPC SAVE RUNTIME 1.23-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
