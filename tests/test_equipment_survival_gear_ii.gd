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

    # 1.19 introduces a real outerwear layer instead of forcing armor and jackets
    # to occupy the same body slot.
    game.equipment = {"head":"","body":"","backpack":"","utility":""}
    game._ensure_equipment_slots()
    check(game.equipment.has("outerwear"), "outerwear slot was not added to legacy equipment state")
    check(str(game.item_defs["light_jacket"].get("slot","")) == "outerwear", "light jacket did not migrate to outerwear architecture")
    check(str(game.item_defs["rain_jacket"].get("slot","")) == "outerwear", "rain jacket did not migrate to outerwear architecture")
    check(str(game.item_defs["military_vest"].get("slot","")) == "body", "armor must stay in body slot")

    # Old save migration must preserve the equipped jacket rather than delete it.
    game.equipment = {"head":"cap","body":"rain_jacket","backpack":"field_backpack","utility":""}
    game._ensure_equipment_slots()
    check(str(game.equipment.get("body","")) == "", "legacy body jacket was not removed from armor slot")
    check(str(game.equipment.get("outerwear","")) == "rain_jacket", "legacy body jacket was not moved to outerwear")

    # New items are specialized choices, not linear tiers.
    for item_id in ["insulated_parka","storm_poncho"]:
        check(game.item_defs.has(item_id), "missing 1.19 item: " + item_id)
        check(game._make_item_icon(item_id) != null, "missing inventory art: " + item_id)
        check(game._make_world_loot_texture(item_id) != null, "missing world loot art: " + item_id)
        check(str(game.item_defs[item_id].get("slot","")) == "outerwear", "new gear uses wrong slot: " + item_id)

    var parka = game.item_defs["insulated_parka"]
    var poncho = game.item_defs["storm_poncho"]
    var rain = game.item_defs["rain_jacket"]
    check(float(parka.get("warmth",0.0)) > float(game.item_defs["light_jacket"].get("warmth",0.0)), "parka is not a real warmth specialization")
    check(float(poncho.get("rain_protect",0.0)) > float(rain.get("rain_protect",0.0)), "poncho is not a real rain specialization")
    check(float(poncho.get("warmth",0.0)) < float(parka.get("warmth",0.0)), "poncho became a pure upgrade over parka")
    check(float(poncho.get("move_mult",1.0)) < float(rain.get("move_mult",1.0)), "poncho lacks mobility tradeoff")

    # Armor + outerwear must stack as two physical layers with diminishing returns.
    game.equipment = {"head":"ballistic_helmet","body":"military_vest","outerwear":"","backpack":"","utility":""}
    var vest_only_torso = game._armor_value_for_zone("torso")
    var vest_only_arms = game._armor_value_for_zone("arms")
    var vest_only_warmth = game._clothing_warmth()
    game.equipment["outerwear"] = "insulated_parka"
    check(game._armor_value_for_zone("torso") > vest_only_torso, "outerwear weak protection does not layer over vest")
    check(game._armor_value_for_zone("torso") < vest_only_torso + float(parka.get("armor_torso",0.0)) + 0.001, "layered armor is additive instead of diminishing")
    check(game._armor_value_for_zone("arms") > vest_only_arms, "outerwear does not add broad arm coverage")
    check(game._clothing_warmth() > vest_only_warmth + 4.5, "parka does not materially change thermal protection over armor")
    check(game._equipment_move_multiplier() < 0.94, "armor + parka has no mobility cost")

    # Equipping outerwear swaps only outerwear; it must not knock off armor.
    game.equipment = {"head":"","body":"military_vest","outerwear":"rain_jacket","backpack":"","utility":""}
    game.inventory_entries = [{"id":"insulated_parka","qty":1,"x":0,"y":0}]
    game._equip_item("insulated_parka")
    check(str(game.equipment.get("body","")) == "military_vest", "equipping parka displaced body armor")
    check(str(game.equipment.get("outerwear","")) == "insulated_parka", "parka did not equip into outerwear")
    check(game._inventory_count("rain_jacket") == 1, "old outerwear was not returned to inventory")

    # Weather choice is observable through production survival helpers.
    game.equipment = {"head":"wool_hat","body":"","outerwear":"insulated_parka","backpack":"hiking_backpack","utility":""}
    var parka_warmth = game._clothing_warmth()
    var parka_rain = game._rain_protection()
    game.equipment["outerwear"] = "storm_poncho"
    check(game._clothing_warmth() < parka_warmth, "poncho did not sacrifice warmth")
    check(game._rain_protection() > parka_rain, "poncho did not improve rain protection")

    # Permanent QA rule: new equipment automatically appears without enlarging normal containers.
    check(game.CONTAINER_W == 8 and game.CONTAINER_H == 8, "normal container grid changed")
    var qa_entries = game._generate_loot("qa:test:equipment119","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var qa_ids = {}
    for rec in qa_entries:
        qa_ids[str(rec.get("id",""))] = true
    check(qa_ids.size() == game.item_defs.size(), "QA catalogue cannot pack complete 1.19 item set")
    check(qa_ids.has("insulated_parka") and qa_ids.has("storm_poncho"), "QA catalogue missing 1.19 outerwear")

    game.free()
    print("EQUIPMENT & SURVIVAL GEAR II: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
