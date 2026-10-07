extends SceneTree
var checks := 0
var failures := 0
var main
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _list_text() -> String:
    var out = []
    for i in range(main.contract_list.item_count):
        out.append(main.contract_list.get_item_text(i))
    return "\n".join(out)

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null: quit(1); return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame; await process_frame

    main.world_day = 5
    main.faction_state = main.FactionEconomy.default_state()
    main.FactionEconomy.add_reputation(main.faction_state,"perron",8)
    main.ContractSystem.refresh_offers(main.faction_state,main.world_day,true)
    main._open_contract_board("perron","Вера Андреевна","perron_steward")
    await process_frame
    var text = _list_text()
    check(text.find("[ПОСТАВКА]") >= 0,"common board no longer labels delivery offers")
    check(text.find("[РАЗВЕДКА • РИСК 2]") >= 0,"Perron reconnaissance does not show authored risk on the common board")
    check(text.find("ДОРОГА К «ЗАРЕ»") >= 0,"Perron starter reconnaissance missing from runtime board")
    check(text.find("[ДОСТУПНО]") < 0,"generic offer prefix still hides contract type")

    # Lazaret after the successful slice likewise shows a real exploration option, not a system quest.
    main._close_contract_board()
    main.faction_state = main.FactionEconomy.default_state()
    main.FactionEconomy.add_reputation(main.faction_state,"lazaret",16)
    main.ContractSystem.refresh_offers(main.faction_state,main.world_day,true)
    main._open_contract_board("lazaret","Доктор Миронова","lazaret_doctor")
    await process_frame
    text = _list_text()
    check(text.find("[РАЗВЕДКА • РИСК 3]") >= 0,"Lazaret reconnaissance does not show authored risk")
    check(text.find("РАЙОННАЯ БОЛЬНИЦА") >= 0,"district hospital is not visible on the post-slice board")

    # Personal board identity stays intact after the common-board UX change.
    main._close_contract_board()
    main.faction_state = main.FactionEconomy.default_state()
    main.FactionEconomy.add_reputation(main.faction_state,"perron",30)
    main.ContractSystem.refresh_offers(main.faction_state,main.world_day,true)
    main._open_contract_board("perron","Лёнька","perron_radio")
    await process_frame
    text = _list_text()
    check(text.find("[ЛИЧНО]") >= 0,"personal board lost its personal offer label")
    check(text.find("[ПОСТАВКА]") < 0 and text.find("[РАЗВЕДКА") < 0,"personal board was relabeled as a common board")

    main.queue_free()
    await process_frame; await process_frame
    print("SANDBOX ROUTES RUNTIME 1.23-dev14 regression: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
