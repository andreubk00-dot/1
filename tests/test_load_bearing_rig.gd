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

    for rig_id in ["field_rig","assault_rig"]:
        check(game.item_defs.has(rig_id), "missing load-bearing rig: " + rig_id)
        check(str(game.item_defs[rig_id].get("slot","")) == "rig", "rig uses wrong equipment layer: " + rig_id)
        check(game._make_item_icon(rig_id) != null, "missing rig inventory art: " + rig_id)
        check(game._make_world_loot_texture(rig_id) != null, "missing rig world-loot art: " + rig_id)

    check(int(game.item_defs["field_rig"].get("quick_pockets",0)) == 1, "field rig must expose one quick pocket")
    check(int(game.item_defs["assault_rig"].get("quick_pockets",0)) == 2, "assault rig must expose two quick pockets")
    check(float(game.item_defs["assault_rig"].get("reload_mult",1.0)) < float(game.item_defs["field_rig"].get("reload_mult",1.0)), "assault rig must give faster ammo access")
    check(bool(game.item_defs["bandage"].get("rig_quick",false)), "bandage should fit rig quick pocket")
    check(not game._rig_quick_valid_item("ammo_9x18"), "ammo stack must not be usable as a consumable quick pocket")

    game.equipment = {"head":"","body":"","outerwear":"","rig":"field_rig","backpack":"","utility":""}
    game._ensure_equipment_slots()
    check(game._rig_pocket_count() == 1, "field rig pocket count wrong")
    var base_reload = float(game.weapon_defs["akm"].get("reload",0.0))
    check(abs(game._reload_duration_for_weapon("akm") - base_reload * 0.92) < 0.001, "field rig reload multiplier not applied")
    check(game._assign_rig_quick_slot(1,"bandage"), "field rig cannot bind first pocket")
    check(not game._assign_rig_quick_slot(2,"emergency_ration"), "field rig incorrectly exposes second pocket")

    game.equipment["rig"] = "assault_rig"
    check(game._rig_pocket_count() == 2, "assault rig pocket count wrong")
    check(abs(game._reload_duration_for_weapon("akm") - base_reload * 0.82) < 0.001, "assault rig reload multiplier not applied")
    check(game._assign_rig_quick_slot(2,"emergency_ration"), "assault rig cannot bind second pocket")
    check(str(game.rig_quick_ids[0]) == "bandage" and str(game.rig_quick_ids[1]) == "emergency_ration", "rig quick bindings not retained")

    # Outside inventory, 7/8 use the assigned carried consumable without opening the backpack.
    game.inventory_entries = [
        {"id":"bandage","qty":2,"x":0,"y":0},
        {"id":"emergency_ration","qty":1,"x":1,"y":0}
    ]
    game.inventory_open = false
    game.bleeding = true
    game.health = 70.0
    check(game._use_rig_quick_slot(1), "rig quick-use failed")
    check(not game.bleeding, "quick bandage did not stop bleeding")
    check(game._inventory_count("bandage") == 1, "quick bandage consumed wrong amount")

    # Inventory-open 7/8 are binding actions, mirroring combat quickbar assignment.
    game.rest_open = false
    game.crafting_open = false
    game.base_build_open = false
    game.mod_panel_open = false
    game.region_map_open = false
    game.inventory_open = true
    game.selected_inventory_index = 1
    check(game._use_rig_quick_slot(1), "inventory-open rig assignment failed")
    check(str(game.rig_quick_ids[0]) == "emergency_ration", "inventory-open assignment did not update pocket")

    # Unequipped rig removes quick access and reload benefit without deleting bindings.
    game.inventory_open = false
    game.equipment["rig"] = ""
    check(game._rig_pocket_count() == 0, "quick pockets remain active without rig")
    check(abs(game._reload_duration_for_weapon("akm") - base_reload) < 0.001, "reload bonus remains active without rig")

    check(game.CONTAINER_W == 8 and game.CONTAINER_H == 8, "normal container grid changed")
    var qa_entries = game._generate_loot("qa:test:rig","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var ids = {}
    for rec in qa_entries:
        ids[str(rec.get("id",""))] = true
    check(ids.has("field_rig") and ids.has("assault_rig"), "QA catalogue missing load-bearing rigs")
    check(ids.size() == game.item_defs.size(), "QA all-items catalogue no longer fits complete item set")

    game.free()
    print("LOAD-BEARING RIG: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
