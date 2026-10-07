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
    call_deferred("run")

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.world_day = 11
    game.world_minutes = 720.0

    var missing = game._set_named_npc_status("perron_trader","missing","Не вернулся с хозяйственного рейса.")
    check(bool(missing.get("ok",false)),"runtime missing status transition failed")
    check(game.WorldChronicle.entries(game.faction_state,10).size() == 1,"NPC status change must reach world chronicle")
    check(str(game.WorldChronicle.entries(game.faction_state,10)[0].get("kind","")) == "npc","NPC chronicle entry must use npc kind")

    game._open_trader("perron_general")
    check(not game.trader_open,"missing trader must not open trade service")

    var dummy_chunk = Node2D.new()
    game.add_child(dummy_chunk)
    var absent_node = game._create_faction_npc(dummy_chunk,{"npc_id":"perron_trader","faction_id":"perron","name":"Миша Рыжий","role":"хозяйственный торговец","pos":Vector2.ZERO})
    check(absent_node == null,"missing named NPC must not spawn")

    game._set_named_npc_status("perron_trader","wounded","Нашёлся раненым.")
    var wounded_node = game._create_faction_npc(dummy_chunk,{"npc_id":"perron_trader","faction_id":"perron","name":"Миша Рыжий","role":"хозяйственный торговец","pos":Vector2.ZERO})
    check(is_instance_valid(wounded_node),"wounded named NPC must spawn")
    if is_instance_valid(wounded_node):
        check(str(wounded_node.get_meta("npc_status","")) == "wounded","runtime NPC node missing wounded metadata")
        var status_label = wounded_node.get_node_or_null("NpcStatusLabel")
        check(status_label != null and status_label.visible and status_label.text == "РАНЕН","wounded NPC visual status label missing")

    game._open_trader("perron_general")
    check(game.trader_open,"wounded trader should remain usable")
    game._close_trader()

    game._set_named_npc_status("perron_steward","missing","Не вернулась после совета.")
    game._open_contract_board("perron","Вера Андреевна","perron_steward")
    check(not game.contract_open,"missing contract giver must make board unavailable")
    game._set_named_npc_status("perron_steward","alive","Вернулась в Перрон.")
    game._open_contract_board("perron","Вера Андреевна","perron_steward")
    check(game.contract_open,"restored contract giver must reopen board")
    check(game.active_contract_npc_id == "perron_steward","contract board must retain canonical NPC id")
    game._close_contract_board()

    var before = game.FactionNpcState.record(game.faction_state,"perron_radio",11)
    var talk_node = Node2D.new()
    talk_node.set_meta("npc_id","perron_radio")
    talk_node.set_meta("faction_id","perron")
    talk_node.set_meta("display_name","Лёнька")
    talk_node.set_meta("npc_role","радист")
    game.add_child(talk_node)
    game._talk_faction_npc(talk_node)
    var after = game.FactionNpcState.record(game.faction_state,"perron_radio",11)
    check(int(after.get("interaction_count",0)) == int(before.get("interaction_count",0)) + 1,"talk must enter NPC interaction history")
    check(str(game.FactionNpcState.last_history(game.faction_state,"perron_radio",11).get("kind","")) == "talk","talk history kind mismatch")

    dummy_chunk.queue_free()
    talk_node.queue_free()
    game.queue_free()
    await process_frame
    await process_frame
    print("NAMED NPC RUNTIME 1.23-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
