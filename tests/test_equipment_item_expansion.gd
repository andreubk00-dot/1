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

func _loot_ids(table):
    var out = {}
    for rec in table:
        out[str(rec.get("id",""))] = float(rec.get("chance",0.0))
    return out

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var new_ids = [
        "wool_hat","ballistic_helmet","rain_jacket","military_vest",
        "hiking_backpack","expedition_pack","trauma_kit","emergency_ration"
    ]
    for id in new_ids:
        check(game.item_defs.has(id), "missing 1.10 item: " + id)
        check(game._make_item_icon(id) != null, "missing inventory art: " + id)
        check(game._make_world_loot_texture(id) != null, "missing world loot art: " + id)
        check(float(game.item_defs[id].get("weight",0.0)) > 0.0, "invalid weight: " + id)

    # Existing equipment slots remain the only gear architecture.
    check(str(game.item_defs["wool_hat"].get("slot","")) == "head", "wool hat slot mismatch")
    check(str(game.item_defs["ballistic_helmet"].get("slot","")) == "head", "helmet slot mismatch")
    check(str(game.item_defs["rain_jacket"].get("slot","")) == "outerwear", "rain jacket slot mismatch")
    check(str(game.item_defs["military_vest"].get("slot","")) == "body", "military vest slot mismatch")
    check(str(game.item_defs["hiking_backpack"].get("slot","")) == "backpack", "hiking pack slot mismatch")
    check(str(game.item_defs["expedition_pack"].get("slot","")) == "backpack", "expedition pack slot mismatch")

    # Head choices: warmth vs protection, not linear colour-tier copies.
    check(float(game.item_defs["wool_hat"].get("warmth",0.0)) > float(game.item_defs["cap"].get("warmth",0.0)), "wool hat should be warmer than cap")
    check(float(game.item_defs["ballistic_helmet"].get("armor",0.0)) > float(game.item_defs["cap"].get("armor",0.0)) * 5.0, "helmet protection is not meaningful")
    check(float(game.item_defs["ballistic_helmet"].get("weight",0.0)) > float(game.item_defs["wool_hat"].get("weight",0.0)) * 4.0, "helmet lacks weight tradeoff")

    # Body choices: weather specialization vs protection.
    check(float(game.item_defs["rain_jacket"].get("rain_protect",0.0)) >= 0.60, "rain jacket should strongly resist rain")
    check(float(game.item_defs["rain_jacket"].get("rain_protect",0.0)) > float(game.item_defs["light_jacket"].get("rain_protect",0.0)), "rain jacket not better than old jacket in rain")
    check(float(game.item_defs["military_vest"].get("armor",0.0)) > float(game.item_defs["police_vest"].get("armor",0.0)), "military vest not stronger than police vest")
    check(float(game.item_defs["military_vest"].get("weight",0.0)) > float(game.item_defs["police_vest"].get("weight",0.0)) + 1.5, "military vest lacks survival weight cost")

    # Backpack progression is substantial but still paid for in carried weight.
    var field_bonus = float(game.item_defs["field_backpack"].get("carry_bonus",0.0))
    var hiking_bonus = float(game.item_defs["hiking_backpack"].get("carry_bonus",0.0))
    var expedition_bonus = float(game.item_defs["expedition_pack"].get("carry_bonus",0.0))
    check(field_bonus < hiking_bonus and hiking_bonus < expedition_bonus, "backpack carry progression is not ordered")
    check(expedition_bonus - field_bonus >= 10.0, "expedition pack improvement is too small to motivate risk")
    check(float(game.item_defs["expedition_pack"].get("weight",0.0)) > float(game.item_defs["field_backpack"].get("weight",0.0)), "large pack must have a weight cost")

    # Computed survival effects use the production helpers, not duplicated test math.
    game.equipment = {"head":"wool_hat","body":"","outerwear":"rain_jacket","backpack":"hiking_backpack","utility":""}
    check(game._clothing_warmth() > 4.0, "warm/weather kit does not affect thermal helper")
    check(game._rain_protection() >= 0.70, "weather kit does not affect rain helper")
    check(game._carry_limit() >= 26.0, "hiking pack does not affect carry helper")

    game.equipment = {"head":"ballistic_helmet","body":"military_vest","outerwear":"","backpack":"expedition_pack","utility":""}
    check(game._armor_value() >= 0.53, "heavy protection kit does not affect armor helper")
    check(game._bleed_resistance() >= 0.45, "heavy protection kit does not affect bleed helper")
    check(game._carry_limit() >= 32.0, "expedition pack does not affect carry helper")

    # Live equip path swaps old gear back into inventory using the existing grid system.
    game.equipment = {"head":"cap","body":"","outerwear":"light_jacket","backpack":"field_backpack","utility":""}
    game.inventory_entries = [{"id":"ballistic_helmet","qty":1,"x":0,"y":0}]
    game._equip_item("ballistic_helmet")
    check(str(game.equipment.get("head","")) == "ballistic_helmet", "helmet did not equip")
    check(game._inventory_count("cap") == 1, "old headgear was not returned to inventory")
    check(game._inventory_count("ballistic_helmet") == 0, "equipped helmet remained in inventory")

    # Trauma kit is a meaningful high-value medical item, but cannot be wasted at full condition.
    game.inventory_entries = [{"id":"trauma_kit","qty":2,"x":0,"y":0}]
    game.selected_inventory_index = 0
    game.health = 100.0
    game.pain = 0.0
    game.bleeding = false
    game.body_condition = {"head":100.0,"torso":100.0,"arms":100.0,"legs":100.0}
    game.inv_details = Label.new(); game.add_child(game.inv_details)
    game._use_selected_inventory()
    check(game._inventory_count("trauma_kit") == 2, "trauma kit was consumed while not needed")

    game.selected_inventory_index = 0
    game.health = 61.0
    game.pain = 48.0
    game.bleeding = true
    game.body_condition["torso"] = 52.0
    game.wound_contamination = 44.0
    game._use_selected_inventory()
    check(game._inventory_count("trauma_kit") == 1, "trauma kit did not consume one charge")
    check(not game.bleeding, "trauma kit did not stop bleeding")
    check(game.health >= 84.9, "trauma kit healing too small")
    check(game.pain <= 30.1, "trauma kit did not reduce pain")
    check(float(game.body_condition["torso"]) >= 63.9, "trauma kit did not stabilize injury")
    check(game.wound_contamination <= 29.1, "trauma kit did not clean wound")

    # Emergency ration uses the existing survival variables and has a thirst tradeoff.
    game.inventory_entries = [{"id":"emergency_ration","qty":2,"x":0,"y":0}]
    game.selected_inventory_index = 0
    game.hunger = 20.0
    game.thirst = 70.0
    game.stamina = 20.0
    game._use_selected_inventory()
    check(game._inventory_count("emergency_ration") == 1, "ration did not consume")
    check(game.hunger >= 77.9, "ration hunger recovery mismatch")
    check(game.thirst <= 66.1, "ration should cost a little thirst")
    check(game.stamina >= 29.9, "ration did not restore stamina")

    # 1.11 keeps the 1.10 item roles, but moves advanced gear into targeted secure sources.
    var pharmacy = _loot_ids(game.loot_tables.get("pharmacy",[]))
    var medical_secure = _loot_ids(game.loot_tables.get("medical_secure",[]))
    var residential = _loot_ids(game.loot_tables.get("residential",[]))
    var police = _loot_ids(game.loot_tables.get("police",[]))
    var police_secure = _loot_ids(game.loot_tables.get("police_secure",[]))
    var military = _loot_ids(game.loot_tables.get("military",[]))
    var military_secure = _loot_ids(game.loot_tables.get("military_secure",[]))
    var rural = _loot_ids(game.loot_tables.get("rural",[]))
    check(not pharmacy.has("trauma_kit") and medical_secure.has("trauma_kit"), "trauma kit should live in medical reserve")
    check(residential.has("rain_jacket") and residential.has("hiking_backpack"), "residential pool missing civilian gear")
    check(not police.has("ballistic_helmet") and not police.has("military_vest") and police_secure.has("ballistic_helmet"), "police secure gear split mismatch")
    check(not military.has("military_vest") and not military.has("expedition_pack") and military_secure.has("military_vest") and military_secure.has("expedition_pack"), "military secure gear split mismatch")
    check(rural.has("hiking_backpack") and rural.has("wool_hat"), "rural pool missing outdoor gear")
    check(float(military_secure.get("military_vest",0.0)) >= 0.10, "military secure vest chance too low for a targeted source")
    check(float(military_secure.get("expedition_pack",0.0)) >= 0.08, "military secure pack chance too low for a targeted source")

    # Every new item is guaranteed in the permanent QA showcase crate.
    check(game.CONTAINER_W == 8 and game.CONTAINER_H == 8, "normal container grid changed")
    check(game.QA_ALL_ITEMS_CONTAINER_W == 20 and game.QA_ALL_ITEMS_CONTAINER_H == 10, "QA crate grid changed unexpectedly")
    var qa_entries = game._generate_loot("qa:test:equipment110","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var qa_ids = {}
    for rec in qa_entries:
        qa_ids[str(rec.get("id",""))] = true
    check(qa_ids.size() == game.item_defs.size(), "QA crate no longer fits the complete item catalogue")
    for id in new_ids:
        check(qa_ids.has(id), "QA crate missing new item: " + id)

    game.free()
    print("EQUIPMENT & ITEM EXPANSION: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
