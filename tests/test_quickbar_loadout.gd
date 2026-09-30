extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    check(game.quick_slot_ids.size() == 6,"quickbar must keep six bindings")
    for id in game.quick_slot_ids:
        check(game._quick_slot_valid_item(id),"default quickbar contains invalid item: " + str(id))

    # New 1.18 firearms must be eligible for a real combat loadout.
    check(game._assign_quick_slot(1,"pps43"),"PPS-43 cannot be assigned to quickbar")
    check(game._quick_slot_item(1) == "pps43","PPS-43 binding was not stored")
    check(game._assign_quick_slot(2,"mosin"),"Mosin cannot be assigned to quickbar")
    check(game._quick_slot_item(2) == "mosin","Mosin binding was not stored")
    check(game._assign_quick_slot(3,"aks74u"),"AKS-74U cannot be assigned to quickbar")
    check(game._quick_slot_item(3) == "aks74u","AKS-74U binding was not stored")
    check(game._assign_quick_slot(4,"izh81"),"IZH-81 cannot be assigned to quickbar")
    check(game._quick_slot_item(4) == "izh81","IZH-81 binding was not stored")

    # Assigning an item that is already bound swaps instead of silently duplicating it.
    var displaced = game._quick_slot_item(1)
    var slot_two_before = game._quick_slot_item(2)
    check(displaced == "pps43" and slot_two_before == "mosin","test setup for quickbar swap failed")
    check(game._assign_quick_slot(2,"pps43"),"existing quickbar binding cannot be moved")
    check(game._quick_slot_item(2) == "pps43","moved binding landed in wrong slot")
    check(game._quick_slot_item(1) == "mosin","displaced binding was not swapped back")

    check(not game._assign_quick_slot(1,"ammo_545"),"ammunition must not occupy a combat quick slot")
    check(not game._assign_quick_slot(7,"makarov"),"out-of-range quick slot accepted")

    # Inventory-open number key assigns selected firearm instead of trying to activate it.
    game.inventory_entries = [
        {"id":"aks74u","qty":1,"x":0,"y":0},
        {"id":"combat_knife","qty":1,"x":3,"y":0}
    ]
    game._ensure_runtime_item_instance_ids()
    game.rest_open = false
    game.crafting_open = false
    game.base_build_open = false
    game.mod_panel_open = false
    game.region_map_open = false
    game.inventory_open = true
    game.selected_inventory_index = 0
    check(game._select_quick_slot(5),"inventory quick-slot assignment failed")
    check(game._quick_slot_item(5) == "aks74u","inventory assignment stored wrong firearm")

    game.selected_inventory_index = 1
    check(game._select_quick_slot(6),"melee quick-slot assignment failed")
    check(game._quick_slot_item(6) == "combat_knife","inventory assignment stored wrong melee item")

    # Closing inventory turns number keys back into activation.
    game.inventory_open = false
    check(game._select_quick_slot(5),"custom firearm quick slot cannot be activated")
    check(game.current_weapon_id == "aks74u" and game.equipped_melee_id == "","custom firearm activation selected wrong state")
    check(game._select_quick_slot(6),"custom melee quick slot cannot be activated")
    check(game.equipped_melee_id == "combat_knife","custom melee activation failed")

    # Old/malformed saves fall back to safe canonical bindings per slot.
    var sanitized = game._sanitize_quick_slot_ids(["mosin","ammo_545","bad_id"])
    check(sanitized.size() == 6,"sanitized quickbar changed slot count")
    check(sanitized[0] == "mosin","valid saved binding was lost")
    check(sanitized[1] == "shotgun","invalid saved binding did not fall back")
    check(sanitized[2] == "akm","unknown saved binding did not fall back")

    game.free()
    print("QUICKBAR LOADOUT: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
