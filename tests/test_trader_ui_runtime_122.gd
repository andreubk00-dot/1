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

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null:
        print("TRADER UI RUNTIME 1.22-dev2: ",checks," checks, ",failures," failures")
        quit(1)
        return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame
    await process_frame
    check(main.trader_panel != null,"trader panel not created in _ready")
    check(main.trader_stock_list != null,"trader stock list not created")
    check(main.trader_inventory_list != null,"trader inventory list not created")
    main._open_trader("perron_general")
    await process_frame
    check(main.trader_open,"trader modal did not open")
    check(main.active_trader_id == "perron_general","active trader id mismatch")
    check(main.trader_panel.visible,"trader panel not visible")
    check(main.trader_stock_list.item_count > 0,"trader UI has no finite stock rows")
    check(main.trader_title.text.find("МИША") >= 0,"trader title does not show authored NPC")
    check(main.trader_subtitle.text.find("Талоны:") >= 0,"trader subtitle does not expose currency")

    # Exercise the real UI transaction handlers, not only pure economy functions.
    main.faction_state["currency_tickets"] = 1000
    var stock_before = int(main.faction_state["traders"]["perron_general"]["stock"].get("water",0))
    var water_before := 0
    for entry in main.inventory_entries:
        if str(entry.get("id","")) == "water":
            water_before += int(entry.get("qty",1))
    main.trader_selected_stock_item = "water"
    check(bool(main._trade_buy_selected()),"real trader UI buy handler failed")
    check(int(main.faction_state["traders"]["perron_general"]["stock"].get("water",0)) == stock_before - 1,"UI buy did not decrement finite stock")
    var water_after := 0
    var water_index := -1
    for i in range(main.inventory_entries.size()):
        var entry = main.inventory_entries[i]
        if str(entry.get("id","")) == "water":
            water_after += int(entry.get("qty",1))
            water_index = i
    check(water_after == water_before + 1,"UI buy did not add item to inventory")
    check(water_index >= 0,"bought water cannot be selected for resale")
    main.trader_selected_inventory_index = water_index
    check(bool(main._trade_sell_selected()),"real trader UI sell handler failed")

    main._close_trader()
    await process_frame
    check(not main.trader_open and not main.trader_panel.visible,"trader modal did not close")
    main.queue_free()
    await process_frame
    print("TRADER UI RUNTIME 1.22-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
