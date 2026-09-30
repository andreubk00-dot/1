extends SceneTree
var failures := 0
var checks := 0
var main

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _find_list_row(source:String) -> int:
    for i in range(main.contract_list.item_count):
        var meta = main.contract_list.get_item_metadata(i)
        if typeof(meta) == TYPE_DICTIONARY and str(meta.get("source","")) == source:
            return i
    return -1

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null:
        quit(1)
        return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame
    await process_frame
    check(main.contract_panel != null,"contract panel not created in _ready")
    check(main.contract_list != null,"contract list not created")
    # Do not inherit a real/previous QA save: this test owns its contract fixture.
    main.faction_state = main.FactionEconomy.default_state()
    main.ContractSystem.ensure_state(main.faction_state,main.world_day)

    main._open_contract_board("perron","Вера Андреевна")
    await process_frame
    check(main.contract_open,"contract board did not open")
    check(main.contract_panel.visible,"contract panel not visible")
    check(main.contract_list.item_count >= 1,"contract board has no offer rows")
    check(main.contract_title.text.find("ПЕРРОН") >= 0,"contract title does not show faction")
    check(main.contract_subtitle.text.find("Вера") >= 0,"contract subtitle does not show responsible NPC")

    var offer_row = _find_list_row("offer")
    check(offer_row >= 0,"no selectable offer row")
    if offer_row >= 0:
        main._contract_selected(offer_row)
        var selected_id = main.selected_contract_id
        check(selected_id != "","offer selection lost contract id")
        check(bool(main._contract_accept_selected()),"real contract UI accept handler failed")
        check(main.selected_contract_source == "active","accepted contract did not become active selection")
        check(main.faction_state["contracts"]["active"].has(selected_id),"accepted contract missing from persistent active state")

        # Give the real inventory enough for whichever Perron delivery alternative was selected.
        var active_contract = main.ContractSystem.contract_by_id(main.faction_state,selected_id)
        var requirements = active_contract.get("requirements",[])
        if requirements.size() > 0:
            var option = requirements[0]
            for req in option:
                var item_id = str(req.get("id",""))
                var need = int(req.get("qty",0))
                var have = main._inventory_count(item_id)
                if have < need:
                    main._grid_add(main.inventory_entries,item_id,need-have,main.INV_W,main.INV_H)
            main._refresh_contract_ui()
            var active_row = _find_list_row("active")
            check(active_row >= 0,"accepted contract row missing")
            if active_row >= 0:
                main._contract_selected(active_row)
                var tickets_before = int(main.faction_state.get("currency_tickets",0))
                check(bool(main._contract_complete_selected()),"real contract UI completion handler failed")
                check(int(main.faction_state.get("currency_tickets",0)) > tickets_before,"UI completion did not pay tickets")
                check(not main.faction_state["contracts"]["active"].has(selected_id),"completed contract remained active")

    main._close_contract_board()
    await process_frame
    check(not main.contract_open and not main.contract_panel.visible,"contract modal did not close")
    main.queue_free()
    await process_frame
    print("CONTRACT UI RUNTIME 1.22-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
