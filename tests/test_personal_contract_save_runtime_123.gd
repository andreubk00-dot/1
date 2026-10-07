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
    game.world_day = 17
    game.world_minutes = 735.0
    game.FactionEconomy.add_reputation(game.faction_state,"perron",25)
    game.ContractSystem.ensure_state(game.faction_state,game.world_day)

    var offers = game.ContractSystem.offers_for_npc(game.faction_state,"perron_radio",game.world_day)
    check(offers.size() == 1,"production save fixture has no personal step 1")
    if offers.is_empty():
        game.queue_free()
        await process_frame
        quit(1)
        return
    var a1 = game.ContractSystem.accept(game.faction_state,str(offers[0].get("id","")),game.world_day)
    check(bool(a1.get("ok",false)),"production save fixture could not accept personal step 1")
    var c1 = a1.get("contract",{})
    var d1 = game.ContractSystem.complete(game.faction_state,str(c1.get("id","")),game.world_day)
    check(bool(d1.get("ok",false)),"production save fixture could not complete personal step 1")
    game.ContractSystem.refresh_offers(game.faction_state,game.world_day,false)
    var step2 = game.ContractSystem.offers_for_npc(game.faction_state,"perron_radio",game.world_day)
    check(step2.size() == 1 and str(step2[0].get("template_id","")) == "perron_radio_dead_frequency","production save fixture did not unlock personal step 2")
    var a2 = game.ContractSystem.accept(game.faction_state,str(step2[0].get("id","")),game.world_day)
    check(bool(a2.get("ok",false)),"production save fixture could not accept personal step 2")
    var active = a2.get("contract",{})
    var active_id = str(active.get("id",""))
    var deadline = int(active.get("deadline_day",0))
    var attitude = int(game.FactionNpcState.record(game.faction_state,"perron_radio",game.world_day).get("attitude",0))
    game._save_state()
    game.queue_free()
    await process_frame
    await process_frame

    var loaded = Main.new()
    root.add_child(loaded)
    await process_frame
    await process_frame
    loaded._load_data()
    loaded._load_state()
    loaded.ContractSystem.ensure_state(loaded.faction_state,loaded.world_day)
    check(int(loaded.world_day) == 17,"production save/load changed personal contract world day")
    var restored = loaded.ContractSystem.contract_by_id(loaded.faction_state,active_id)
    check(not restored.is_empty(),"production save/load lost active personal contract")
    check(str(restored.get("template_id","")) == "perron_radio_dead_frequency","production save/load restored wrong personal stage")
    check(str(restored.get("owner_npc_id","")) == "perron_radio","production save/load lost personal owner")
    check(int(restored.get("deadline_day",0)) == deadline,"production save/load lost active personal deadline")
    check(int(loaded.FactionNpcState.record(loaded.faction_state,"perron_radio",17).get("attitude",0)) == attitude,"production save/load lost personal-chain NPC attitude")
    var history = loaded.faction_state.get("contract_history",[])
    var saw_step1 = false
    for row in history:
        if str(row.get("template_id","")) == "perron_radio_backup_power" and str(row.get("status","")) == "completed":
            saw_step1 = true
            break
    check(saw_step1,"production save/load lost completed personal prerequisite history")

    # Expire the restored contract through the same real day-rollover path the game uses.
    loaded.world_day = deadline + 1
    loaded._process_world_day_rollovers(17,deadline + 1)
    check(loaded.ContractSystem.contract_by_id(loaded.faction_state,active_id).is_empty(),"restored personal deadline did not expire through production day rollover")
    check(str(loaded.faction_state.get("contract_history",[])[-1].get("status","")) == "failed","restored personal failure history missing after rollover")
    var news = loaded.WorldChronicle.entries(loaded.faction_state,20)
    var saw_failure_news = false
    for row in news:
        if str(row.get("text","")).find("срок поручения") >= 0:
            saw_failure_news = true
            break
    check(saw_failure_news,"restored personal deadline failure did not reach world chronicle")
    loaded._save_state()
    loaded.queue_free()
    await process_frame
    await process_frame

    var loaded_again = Main.new()
    loaded_again._load_data()
    loaded_again._load_state()
    loaded_again.ContractSystem.ensure_state(loaded_again.faction_state,loaded_again.world_day)
    check(loaded_again.ContractSystem.contract_by_id(loaded_again.faction_state,active_id).is_empty(),"failed personal contract resurrected after second production load")
    check(str(loaded_again.faction_state.get("contract_history",[])[-1].get("status","")) == "failed","failed personal history did not persist through second production load")

    loaded_again.free()
    await process_frame
    await process_frame
    print("PERSONAL CONTRACT SAVE RUNTIME 1.23-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
