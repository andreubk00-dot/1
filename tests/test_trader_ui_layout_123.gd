extends SceneTree
var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null: quit(1); return
    var main = packed.instantiate(); root.add_child(main)
    await process_frame; await process_frame
    var viewport_size = main.get_viewport_rect().size
    check(main.trader_panel.position.y >= 0.0,"trader panel starts above viewport")
    check(main.trader_panel.position.y + main.trader_panel.size.y <= viewport_size.y,"trader panel extends below viewport")
    check(main.trader_stock_list.position.y + main.trader_stock_list.size.y <= main.trader_status.position.y,"trader stock list overlaps status")
    check(main.trader_inventory_list.position.y + main.trader_inventory_list.size.y <= main.trader_status.position.y,"trader inventory list overlaps status")
    check(main.trader_status.position.y + main.trader_status.size.y <= 298.0,"trader status reaches action buttons")
    var buttons = []
    for child in main.trader_panel.get_children():
        if child is Button:
            buttons.append(child)
    check(buttons.size() == 4,"trader panel no longer exposes exactly four action buttons")
    for button in buttons:
        check(button.position.y + button.size.y <= main.trader_panel.size.y,"trader button extends below panel: " + str(button.text))
    main.faction_state = main.FactionEconomy.default_state()
    main.world_day = 12
    main.FactionEconomy.add_reputation(main.faction_state,"perron",30)
    main._open_trader("perron_canteen")
    await process_frame
    check(main.trader_panel.visible,"trader panel did not open")
    check(main.trader_subtitle.get_combined_minimum_size().y <= main.trader_subtitle.size.y,"trader subtitle overflows compact area")
    main.queue_free(); await process_frame
    print("TRADER UI LAYOUT 1.23-dev15: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
