extends SceneTree

var checks := 0
var failures := 0
var main

func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)

func _initialize() -> void:
    call_deferred("run")

func _board_text() -> String:
    var rows = []
    for i in range(main.contract_list.item_count):
        rows.append(main.contract_list.get_item_text(i))
    return "\n".join(rows)

func _open_and_check(faction_id:String,npc_name:String,npc_id:String,rep:int,title:String,risk:int) -> void:
    main._close_contract_board()
    main.faction_state = main.FactionEconomy.default_state()
    main.FactionEconomy.add_reputation(main.faction_state,faction_id,rep)
    main.ContractSystem.refresh_offers(main.faction_state,main.world_day,true)
    main._open_contract_board(faction_id,npc_name,npc_id)
    await process_frame
    var text = _board_text()
    check(text.find(title) >= 0,title + " missing from runtime board")
    check(text.find("[РАЗВЕДКА • РИСК %d]" % risk) >= 0,title + " does not show authored risk")
    check(text.find("[ПОСТАВКА]") >= 0,faction_id + " board lost delivery/recon contrast")

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null:
        quit(1); return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame; await process_frame
    main.world_day = 6

    await _open_and_check("perron","Вера Андреевна","perron_steward",8,"ДОРОГА К «ЗАРЕ»",2)
    await _open_and_check("lazaret","Доктор Миронова","lazaret_doctor",10,"РАЙОННАЯ БОЛЬНИЦА",3)
    await _open_and_check("rubezh","Ирина","rubezh_dispatch",9,"СТАРЫЙ ПОЛИЦЕЙСКИЙ МАРШРУТ",3)
    await _open_and_check("mechanics","Гена","mechanics_electrician",9,"ДЕПО: ПРОВЕРКА ПОДХОДОВ",4)

    main.queue_free()
    await process_frame; await process_frame
    print("SANDBOX ROUTE IDENTITY RUNTIME 1.23-dev14: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
