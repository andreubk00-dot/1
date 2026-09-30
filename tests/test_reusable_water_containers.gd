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

    for item_id in ["canteen","water_canister"]:
        check(game.item_defs.has(item_id), "missing reusable water vessel: " + item_id)
        check(str(game.item_defs[item_id].get("use","")) == "water_container", "wrong use type: " + item_id)
        check(int(game.item_defs[item_id].get("stack",0)) == 1, "water vessel must be per-instance: " + item_id)
        check(float(game.item_defs[item_id].get("capacity_l",0.0)) > 0.0, "water vessel has no capacity: " + item_id)
        check(game._make_item_icon(item_id) != null, "missing inventory art: " + item_id)
        check(game._make_world_loot_texture(item_id) != null, "missing world-loot art: " + item_id)

    check(abs(float(game.item_defs["canteen"].get("capacity_l",0.0)) - 1.0) < 0.001, "canteen must hold 1.0 L")
    check(abs(float(game.item_defs["water_canister"].get("capacity_l",0.0)) - 3.0) < 0.001, "canister must hold 3.0 L")

    game.inventory_entries = [
        {"id":"canteen","qty":1,"x":0,"y":0},
        {"id":"water","qty":2,"x":1,"y":0}
    ]
    game._ensure_runtime_item_instance_ids()
    game._ensure_water_container_runtime_state()
    var iid = str(game.inventory_entries[0].get("instance_id",""))
    check(iid != "", "canteen did not receive persistent instance id")
    check(abs(game._water_container_fill_l("canteen",iid)) < 0.001, "new canteen should start empty")

    # R/refill path transfers one legacy 0.5 L clean-water portion without destroying the vessel.
    game.selected_inventory_index = 0
    check(game._refill_selected_water_container(), "clean-water refill failed")
    check(abs(game._water_container_fill_l("canteen",iid) - 0.5) < 0.001, "clean-water refill did not add 0.5 L")
    check(game._inventory_count("water") == 1, "clean-water refill consumed wrong amount")
    check(game._inventory_count("canteen") == 1, "refill destroyed the canteen")

    # Filled water contributes exactly its mass in kilograms.
    var expected_weight = float(game.item_defs["canteen"].get("weight",0.0)) + 0.5 + float(game.item_defs["water"].get("weight",0.0))
    check(abs(game._inventory_weight() - expected_weight) < 0.001, "filled-water mass is not included in carry weight")

    # Drinking is partial: at most 0.25 L, and the empty vessel remains.
    game.thirst = 50.0
    check(game._drink_selected_water_container(), "drinking from canteen failed")
    check(abs(game.thirst - 71.0) < 0.01, "0.25 L sip has wrong hydration value")
    check(abs(game._water_container_fill_l("canteen",iid) - 0.25) < 0.001, "sip did not reduce fill by 0.25 L")
    check(game._inventory_count("canteen") == 1, "drinking consumed the reusable vessel")

    # Near full thirst consumes only what is needed, not a forced full sip.
    game.thirst = 95.0
    var before = game._water_container_fill_l("canteen",iid)
    check(game._drink_selected_water_container(), "small required sip failed")
    var expected_used = 5.0 / game.WATER_HYDRATION_PER_L
    check(abs(game.thirst - 100.0) < 0.01, "small sip should stop at full thirst")
    check(abs(game._water_container_fill_l("canteen",iid) - (before - expected_used)) < 0.002, "small sip wasted excess water")

    # Dirty water can be purified directly into the selected vessel when a valid method exists.
    game.inventory_entries = [
        {"id":"canteen","qty":1,"x":0,"y":0,"instance_id":iid},
        {"id":"dirty_water","qty":1,"x":1,"y":0},
        {"id":"water_filter","qty":1,"x":2,"y":0}
    ]
    game.water_container_states[iid] = {"item_id":"canteen","fill_l":0.0}
    game.selected_inventory_index = 0
    check(game._refill_selected_water_container(), "filter-to-vessel refill failed")
    check(game._inventory_count("dirty_water") == 0, "filtered dirty water was not consumed")
    check(abs(game._water_container_fill_l("canteen",iid) - 0.5) < 0.001, "filtered refill did not add 0.5 L")

    # Instance state survives a physical transfer between grids.
    var moved = []
    var source = game.inventory_entries[0].duplicate(true)
    check(game._grid_add_existing_entry(moved,source,8,8) == 0, "water vessel did not transfer to another grid")
    check(str(moved[0].get("instance_id","")) == iid, "water vessel transfer changed instance id")
    check(abs(game._water_container_fill_l("canteen",iid) - 0.5) < 0.001, "water fill state was lost across grid transfer")

    # Readiness counts actual liquid volume, not just legacy disposable water stacks.
    game.inventory_entries = [{"id":"canteen","qty":1,"x":0,"y":0,"instance_id":iid}]
    game.water_container_states[iid] = {"item_id":"canteen","fill_l":0.5}
    var readiness = game._expedition_readiness()
    check(abs(float(readiness.get("facts",{}).get("water_liters",0.0)) - 0.5) < 0.001, "readiness ignores vessel water")
    check(str(readiness.get("text","")).contains("Питьё: 0.5 л"), "readiness does not report actual drink volume")

    check(game.CONTAINER_W == 8 and game.CONTAINER_H == 8, "normal container grid changed")
    var qa_entries = game._generate_loot("qa:test:water-vessels","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var ids = {}
    for rec in qa_entries:
        ids[str(rec.get("id",""))] = true
    check(ids.has("canteen") and ids.has("water_canister"), "QA catalogue missing reusable water vessels")
    check(ids.size() == game.item_defs.size(), "QA all-items catalogue no longer fits full item set")

    game.free()
    print("REUSABLE WATER CONTAINERS: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
