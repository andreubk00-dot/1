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

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null:
        quit(1); return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame; await process_frame

    var viewport_size = main.get_viewport_rect().size
    check(main.contract_panel.position.y >= 0.0,"contract panel starts above viewport")
    check(main.contract_panel.position.y + main.contract_panel.size.y <= viewport_size.y,"contract panel extends below viewport")
    check(main.contract_status.position.y + main.contract_status.size.y <= main.contract_accept_button.position.y,"contract status overlaps action buttons")
    check(main.contract_accept_button.position.y + main.contract_accept_button.size.y <= main.contract_panel.size.y,"accept button extends below panel")
    check(main.contract_close_button.position.y + main.contract_close_button.size.y <= main.contract_panel.size.y,"close button extends below panel")

    main.world_day = 6
    main.faction_state = main.FactionEconomy.default_state()
    main.FactionEconomy.add_reputation(main.faction_state,"mechanics",9)
    main.ContractSystem.refresh_offers(main.faction_state,main.world_day,true)
    main._open_contract_board("mechanics","Гена","mechanics_electrician")
    await process_frame
    var idx := -1
    for i in range(main.contract_list.item_count):
        if main.contract_list.get_item_text(i).find("ДЕПО: ПРОВЕРКА ПОДХОДОВ") >= 0:
            idx = i
            break
    check(idx >= 0,"long Mechanics recon offer missing")
    if idx >= 0:
        main.contract_list.select(idx)
        main._contract_selected(idx)
        await process_frame
        check(main.contract_status.get_combined_minimum_size().y <= main.contract_status.size.y,"selected long contract description overflows status area")
        check(main.contract_status.position.y + main.contract_status.size.y <= main.contract_accept_button.position.y,"selected description reaches buttons")

    main.queue_free()
    await process_frame
    print("CONTRACT UI LAYOUT 1.23-dev14: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
