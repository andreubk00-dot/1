extends SceneTree
# dev87: the free quick bar in the bag window and icons inside their frames,
# on the full game (the HUD and the windows are real)
const Main = preload("res://main_script_mod.gd")
var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await process_frame

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(10)
    game.field_hints.finish_steps()
    game.field_hints._queue.clear()
    # dragging a thing from the bag onto the bag's quick row binds it; a right
    # click there empties the slot; the HUD bar hides under the open bag
    game.inventory_entries = [{"id":"canned_meat","qty":2,"x":0,"y":0}]
    game._ensure_runtime_item_instance_ids()
    game.inventory_open = false
    game._toggle_inventory()
    await frames(2)
    check(game.inv_quick_buttons.size() == 6,"the bag has no quick row")
    var shell = game.hud_world_root.get_node_or_null("QuickShell")
    check(shell != null and not shell.visible,"the HUD quick bar shows under the open bag")
    if game.inv_quick_buttons.size() == 6:
        game._begin_inventory_drag_candidate("inventory",0,"canned_meat")
        game._start_inventory_drag()
        game._finish_inventory_drag(game.inv_quick_buttons[1].get_global_rect().get_center())
        check(game._quick_slot_item(2) == "canned_meat","a dragged can did not land in quick slot 2")
        await frames(1)
        var icon = game.inv_quick_buttons[1].get_node_or_null("Icon")
        check(icon != null and Rect2(Vector2.ZERO,game.inv_quick_buttons[1].size).encloses(Rect2(icon.position,icon.size)),"the quick row icon runs out of its slot")
        var rc = InputEventMouseButton.new()
        rc.button_index = MOUSE_BUTTON_RIGHT
        rc.pressed = true
        game._inventory_quick_gui_input(rc,2)
        check(game._quick_slot_item(2) == "","a right click did not empty the quick slot")
    game._close_inventory()
    await frames(2)
    check(shell != null and shell.visible,"the HUD quick bar stays hidden after the bag closes")
    # worn gear is drawn inside its slot frame
    game._grid_add(game.inventory_entries,"insulated_parka",1,game.INV_W,game.INV_H)
    game._equip_item("insulated_parka")
    game._toggle_inventory()
    await frames(2)
    var eq_button = game.equipment_buttons.get("outerwear",null)
    var eq_icon = eq_button.get_node_or_null("EquipIcon") if eq_button != null else null
    check(eq_icon != null,"a worn parka has no icon")
    if eq_icon != null:
        check(eq_icon.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,"an equipment icon keeps its native size")
        check(Rect2(Vector2(5,3),Vector2(34,32)).encloses(Rect2(eq_icon.position,eq_icon.size)),"an equipment icon runs out of its frame")
    game._close_inventory()

    # every icon in the bag grid stays inside its cell
    game.inventory_entries = []
    for id in ["akm","mosin","insulated_parka","field_backpack","bandage","tool_kit","water"]:
        game._grid_add(game.inventory_entries,id,1,game.INV_W,game.INV_H)
    game._toggle_inventory()
    await frames(2)
    var grid_icons = game.inv_grid_control.find_children("ItemIcon","TextureRect",true,false)
    check(grid_icons.size() >= 5,"the bag grid shows too few icons (%d)" % grid_icons.size())
    for icon in grid_icons:
        var cell = icon.get_parent()
        check(Rect2(Vector2.ZERO,cell.size).encloses(Rect2(icon.position,icon.size)),"a bag icon runs out of its cell")
    game._close_inventory()
    print("FREE QUICKBAR dev87: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
