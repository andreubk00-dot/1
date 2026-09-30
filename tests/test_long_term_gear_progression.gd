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

    # Character progression must be physical/world-driven: no XP/level state.
    var props = {}
    for prop in game.get_property_list():
        props[str(prop.get("name",""))] = true
    check(not props.has("skill_levels"), "skill_levels property returned")
    check(not props.has("skill_xp"), "skill_xp property returned")
    for recipe_id in game.recipe_defs.keys():
        check(not game.recipe_defs[recipe_id].has("skill_req"), "recipe has character-level gate: " + str(recipe_id))

    # Carry capacity comes from real equipment, not a hidden scavenging level.
    game.equipment = {"head":"","body":"","backpack":"","utility":""}
    check(abs(game._carry_limit() - 8.0) < 0.001, "base carry limit changed")
    game.equipment.backpack = "hiking_backpack"
    check(abs(game._carry_limit() - (8.0 + float(game.item_defs["hiking_backpack"].get("carry_bonus",0.0)))) < 0.001, "backpack does not define carry capacity")

    # Protection and mobility are actual equipped-item properties.
    game.equipment.body = "military_vest"
    game.equipment.head = "ballistic_helmet"
    check(game._armor_value_for_zone("torso") > 0.0, "body armor does not provide torso protection")
    check(game._armor_value_for_zone("head") > 0.0, "helmet does not provide head protection")
    check(game._equipment_move_multiplier() < 1.0, "heavy equipment has no mobility tradeoff")

    # Readiness is a neutral factual self-check, never an aggregate gear score or destination advice.
    game.inventory_entries = [
        {"id":"emergency_ration","qty":1,"x":0,"y":0},
        {"id":"trauma_kit","qty":1,"x":1,"y":0},
        {"id":"water","qty":1,"x":3,"y":0},
        {"id":"combat_knife","qty":1,"x":4,"y":0}
    ]
    var readiness = game._expedition_readiness()
    check(not readiness.has("score") and not readiness.has("total"), "readiness reintroduced aggregate score")
    check(int(readiness["facts"].get("food",0)) == 1, "emergency ration is not counted as ready food")
    check(int(readiness["facts"].get("medical",0)) == 1, "trauma kit is not counted as medical readiness")
    var readiness_text = str(readiness.get("text",""))
    for forbidden in ["БАСТИОН","КАРАНТИН","искать","добыть","Рекомендуется","профиль","шанс"]:
        check(readiness_text.find(forbidden) < 0, "readiness leaks destination/acquisition guidance: " + forbidden)
    check(readiness_text.find("Защита:") >= 0 and readiness_text.find("Мобильность") >= 0 and readiness_text.find("Свободный вес") >= 0, "readiness omits physical gear facts")

    # Permanent QA rule: future item registration automatically appears in the all-items crate.
    game.item_defs["qa_future_item"] = {"name":"QA FUTURE","short":"QA","w":1,"h":1,"stack":1,"weight":0.1,"category":"material","color":"#ffffff"}
    var qa_entries = game._generate_loot("qa:auto-catalogue","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var qa_ids = {}
    for rec in qa_entries:
        qa_ids[str(rec.get("id",""))] = true
    check(qa_ids.has("qa_future_item"), "new item is not auto-added to ТЕСТ: ВСЕ ПРЕДМЕТЫ")
    check(qa_ids.size() == game.item_defs.size(), "QA catalogue did not pack every registered item")
    game.item_defs.erase("qa_future_item")
    check(game.CONTAINER_W == 8 and game.CONTAINER_H == 8, "ordinary container grid was expanded for QA catalogue")

    game.free()
    print("LONG-TERM GEAR PROGRESSION: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
