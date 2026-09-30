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

    # Plain backpack/container mode is the only modal state where loadout binding
    # and the inventory-specific R action are allowed.
    game.rest_open = false
    game.crafting_open = false
    game.base_build_open = false
    game.mod_panel_open = false
    game.region_map_open = false
    game.inventory_open = true
    check(game._inventory_item_action_mode(), "plain inventory must allow item actions")

    # R must reach reusable-water refill instead of being swallowed by reload input.
    game.inventory_entries = [
        {"id":"canteen","qty":1,"x":0,"y":0},
        {"id":"water","qty":1,"x":1,"y":0}
    ]
    game._ensure_runtime_item_instance_ids()
    game._ensure_water_container_runtime_state()
    var iid = str(game.inventory_entries[0].get("instance_id",""))
    game.selected_inventory_index = 0
    check(game._handle_reload_action(), "inventory R route did not refill selected vessel")
    check(abs(game._water_container_fill_l("canteen",iid) - 0.5) < 0.001, "inventory R route added wrong water amount")
    check(game._inventory_count("water") == 0, "inventory R route did not consume source water")

    # Modal screens also set inventory_open internally, but they must not inherit
    # stale selected_inventory_index and mutate loadout / water state.
    game.inventory_entries = [
        {"id":"canteen","qty":1,"x":0,"y":0,"instance_id":iid},
        {"id":"water","qty":1,"x":1,"y":0},
        {"id":"makarov","qty":1,"x":2,"y":0,"instance_id":"integration_pm"},
        {"id":"bandage","qty":1,"x":4,"y":0}
    ]
    game.water_container_states[iid] = {"item_id":"canteen","fill_l":0.0}
    game.selected_inventory_index = 0
    game.rest_open = true
    check(not game._inventory_item_action_mode(), "rest panel must block inventory item actions")
    check(not game._handle_reload_action(), "R must do nothing while rest panel owns inventory_open")
    check(abs(game._water_container_fill_l("canteen",iid)) < 0.001, "rest-panel R changed vessel fill")
    check(game._inventory_count("water") == 1, "rest-panel R consumed source water")

    game.quick_slot_ids = ["makarov","shotgun","akm","combat_knife","steel_pipe","fire_axe"]
    var quick_before = game.quick_slot_ids.duplicate()
    game.selected_inventory_index = 2
    check(not game._select_quick_slot(2), "rest panel unexpectedly rebound combat quickbar")
    check(game.quick_slot_ids == quick_before, "rest panel mutated combat quickbar bindings")

    game.equipment = {"head":"","body":"","outerwear":"","rig":"assault_rig","backpack":"","utility":""}
    game.rig_quick_ids = ["bandage","emergency_ration"]
    var rig_before = game.rig_quick_ids.duplicate()
    game.selected_inventory_index = 3
    check(not game._use_rig_quick_slot(2), "rest panel unexpectedly rebound rig pocket")
    check(game.rig_quick_ids == rig_before, "rest panel mutated rig quick bindings")

    # The same guard applies to crafting and base-build modes.
    game.rest_open = false
    game.crafting_open = true
    check(not game._inventory_item_action_mode(), "crafting must block loadout binding mode")
    game.crafting_open = false
    game.base_build_open = true
    check(not game._inventory_item_action_mode(), "base build must block loadout binding mode")

    # Save schema is unchanged by this stabilization pass.
    check(game.CONTAINER_W == 8 and game.CONTAINER_H == 8, "normal container grid changed")
    var qa_entries = game._generate_loot("qa:test:survival-integration","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var ids = {}
    for rec in qa_entries:
        ids[str(rec.get("id",""))] = true
    check(ids.size() == game.item_defs.size(), "QA all-items catalogue no longer fits complete item set")

    game.free()
    print("SURVIVAL GEAR INTEGRATION: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
