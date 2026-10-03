extends SceneTree
var checks := 0
var failures := 0
var main

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

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
    main.faction_state = main.FactionEconomy.default_state()
    main.world_day = 7
    for key in main.FactionEconomy.RESOURCE_KEYS:
        main.faction_state["factions"]["lazaret"]["resources"][key] = 80.0
    main.faction_state["factions"]["lazaret"]["resources"]["medicine"] = 12.0
    main.faction_state["supply_events"]["history"] = [{"faction":"lazaret","closed_day":6,"outcome":"lost"}]

    main._open_trader("lazaret_supplier")
    await process_frame
    check(main.trader_open,"Lazaret trader did not open")
    check(main.trader_subtitle.text.find("КРИЗИС") >= 0,"trader subtitle does not expose settlement crisis")
    check(main.trader_subtitle.text.find("медицина") >= 0,"trader subtitle does not identify crisis resource")
    check(main.trader_subtitle.text.find("потерян рейс") >= 0,"trader subtitle does not expose recent supply cause")
    main._close_trader()

    main.ContractSystem.refresh_offers(main.faction_state,main.world_day,true)
    main._open_contract_board("lazaret","Доктор Миронова")
    await process_frame
    check(main.contract_open,"Lazaret contract board did not open")
    check(main.contract_subtitle.text.find("КРИЗИС") >= 0,"contract board does not expose settlement crisis")
    var found_emergency = false
    for i in range(main.contract_list.item_count):
        if main.contract_list.get_item_text(i).find("АВАРИЙНЫЙ ЗАПАС: МЕДИЦИНА") >= 0:
            found_emergency = true
            break
    check(found_emergency,"medicine crisis did not surface emergency delivery on real contract board")
    main._close_contract_board()
    main.queue_free()
    await process_frame
    print("SETTLEMENT CRISIS UI 1.22-dev7: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
