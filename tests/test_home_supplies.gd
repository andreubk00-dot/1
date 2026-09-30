extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const Plan = preload("res://world/supply_plan.gd")
const Journal = preload("res://world/expedition_journal.gd")
var checks = 0
var failures = 0

func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func fresh():
    var game = Harness.new()
    root.add_child(game)
    game.current_chunk = Vector2i.ZERO
    game.roof_records[0]["building_key"] = "0:0:home"
    game.roof_records[0]["building_name"] = "ДОМ"
    game.roof_records[0]["chunk_coord"] = Vector2i.ZERO
    game.equipment = {"body":"","head":"","backpack":"","utility":""}
    game.inventory_entries = []
    game._claim_current_home()
    game.base_objects.append({"id":2,"kind":"stash","x":20.0,"y":0.0})
    game.container_states["base_stash_2"] = {"name":"Личный ящик","extra":"preserved","items":[
        {"id":"water","qty":5,"x":0,"y":0},
        {"id":"canned_meat","qty":5,"x":1,"y":0},
        {"id":"bandage","qty":5,"x":2,"y":0},
        {"id":"ammo_9x18","qty":20,"x":3,"y":0}
    ]}
    return game

func total(game,id):
    var amount = game._inventory_count(id)
    for state in game.container_states.values():
        amount += Plan.count(state.get("items",[]),[id])
    return amount

func _initialize():
    call_deferred("run")

func run():
    var game = fresh()
    check(game._home_stashes().size() == 1,"only home stash is listed")
    check(game.expedition_journal["home"]["bounds"].size() == 4,"claim must persist building bounds")
    var before = {}
    for id in ["water","canned_meat","bandage","ammo_9x18"]:
        before[id] = total(game,id)
    check(game._pack_home_supplies(),"nearby stash supplies short kit")
    check(game._inventory_count("water") == 1 and game._inventory_count("canned_meat") == 1 and game._inventory_count("bandage") == 2,"short template takes exact target quantities")
    for id in before:
        check(total(game,id) == before[id],"inventory and stash must conserve " + id)
    check(game.container_states["base_stash_2"]["extra"] == "preserved","stash metadata must survive transfer")
    var saved = game.save_calls
    check(not game._pack_home_supplies() and game.save_calls == saved,"repeated complete pack must not duplicate or write")
    game.expedition_journal["supply_preset"] = 2
    check(game._pack_home_supplies(),"larger kit tops up existing quantities")
    check(game._inventory_count("water") == 3 and game._inventory_count("bandage") == 4,"far kit tops up rather than adds whole preset")
    game.free()

    game = fresh()
    game.inventory_entries = [{"id":"makarov","qty":1,"x":0,"y":0}]
    var supply_pm_iid = game.set_test_weapon_state("makarov",6)
    game._switch_weapon("makarov",supply_pm_iid)
    game._pack_home_supplies()
    check(game._inventory_count("ammo_9x18") == 2,"loaded rounds count toward ammunition goal")
    game.inventory_entries.append({"id":"herbal_tea","qty":5,"x":4,"y":0})
    var water_before = Plan.count(game.container_states["base_stash_2"]["items"],["water"])
    game._pack_home_supplies()
    check(Plan.count(game.container_states["base_stash_2"]["items"],["water"]) == water_before,"existing substitutes and surplus must not be replaced")
    game.free()

    game = fresh()
    game.container_states["base_stash_2"]["items"] = [{"id":"grain","qty":20},{"id":"dirty_water","qty":20},{"id":"flashlight","qty":1,"instance_id":"itm_00000123"}]
    var state_before = game.container_states.duplicate(true)
    check(not game._pack_home_supplies(),"raw supplies cannot become ready food or water")
    check(game.container_states == state_before,"unrelated unique items and metadata must be untouched")
    game.free()

    game = fresh()
    game.roof_records.append({"rect":Rect2(100,0,80,80),"building_key":"0:0:other","chunk_coord":Vector2i.ZERO})
    game.base_objects.append({"id":3,"kind":"stash","x":120.0,"y":20.0})
    game.container_states["base_stash_3"] = {"items":[{"id":"water","qty":99}]}
    check(Plan.count(game._home_stock_entries(),["water"]) == 5,"neighbor building cannot enter home stock")
    game.player.position = Vector2(120,20)
    state_before = game.container_states.duplicate(true)
    check(not game._pack_home_supplies() and state_before == game.container_states,"other building cannot remotely withdraw supplies")
    game.player.position = Vector2(-49,40)
    check(game._home_stashes(true).is_empty() and not game._pack_home_supplies(),"distant stash inside same home cannot be remotely accessed")
    game.free()

    game = fresh()
    game.base_objects.append(game.base_objects[1].duplicate(true))
    check(Plan.count(game._home_stock_entries(),["water"]) == 5,"duplicate record cannot count same stash twice")
    game.free()

    game = fresh()
    for y in range(game.INV_H):
        for x in range(game.INV_W):
            game.inventory_entries.append({"id":"cloth","qty":1,"x":x,"y":y})
    state_before = game.container_states.duplicate(true)
    check(not game._pack_home_supplies(),"full grid rejects transfer")
    check(game.container_states == state_before,"full grid must not consume source items")
    game.free()

    game = fresh()
    game.inventory_entries = [{"id":"scrap","qty":11,"x":0,"y":0}]
    state_before = game.container_states.duplicate(true)
    check(not game._pack_home_supplies() and state_before == game.container_states,"weight reserve must prevent removal from source")
    game.inventory_entries[0]["qty"] = 10
    check(game._pack_home_supplies(),"partial fit must transfer only possible items")
    check(game._inventory_count("water") == 1 and game._inventory_count("bandage") == 1 and game._inventory_count("canned_meat") == 0,"partial fit must respect actual item weights")
    check(game._inventory_weight() <= game._carry_limit()*0.9 + 0.00001,"packing must leave 10 percent weight capacity")
    check(total(game,"water") == 5 and total(game,"bandage") == 5,"partial transfer must conserve quantities")
    game.free()

    game = fresh()
    var wall = StaticBody2D.new()
    wall.collision_layer = game.LAYER_WORLD
    wall.position = Vector2(10,0)
    var shape = CollisionShape2D.new()
    var box = RectangleShape2D.new()
    box.size = Vector2(4,100)
    shape.shape = box
    wall.add_child(shape)
    game.add_child(wall)
    await physics_frame
    await physics_frame
    state_before = game.container_states.duplicate(true)
    check(not game._pack_home_supplies() and game.container_states == state_before,"walls must block otherwise nearby stash")
    game.free()

    game = fresh()
    game.base_objects.append({"id":4,"kind":"rain_collector","x":70.0,"y":0.0,"stored_water":7.5})
    game.base_objects.append({"id":5,"kind":"heater","x":0.0,"y":0.0,"on":true,"fuel":60.0})
    game.base_objects.append({"id":6,"kind":"heater","x":5.0,"y":0.0,"on":true,"fuel":30.0})
    var infrastructure = game._home_infrastructure_text()
    check(infrastructure.contains("сырая вода: 7.5"),"collector contents must be shown separately")
    check(infrastructure.contains("самый долгий ~240 мин"),"parallel heaters must not sum burn time")
    check(Plan.count(game._home_stock_entries(),["water"]) == 5,"collector water must not inflate drinking stock")
    var snapshot = JSON.parse_string(JSON.stringify(game.expedition_journal))
    snapshot["supply_preset"] = 2
    game.expedition_journal = Journal.normalize(snapshot)
    game.roof_records.clear()
    check(game._home_supply_bounds().has_area() and game._home_stashes().size() == 1,"saved bounds allow stock inspection after chunk unload")
    check(not game._pack_home_supplies(),"cached bounds must never grant physical access")
    check(game.expedition_journal["supply_preset"] == 2,"preset must survive JSON load")
    game.expedition_journal["home"].erase("bounds")
    check(not game._home_supply_bounds().has_area(),"old unvisited home must not fabricate bounds")
    check(Journal.normalize({})["supply_preset"] == 0,"older saves must default to short kit")
    check(Journal.normalize({"supply_preset":900})["supply_preset"] == 2,"invalid preset must be clamped")
    game.free()

    game = fresh()
    game._create_region_map_ui()
    game._create_home_journal_ui()
    game._open_home_journal()
    game._toggle_home_supply_view()
    check(game.home_pack_button.visible and game.home_supply_preset.visible,"supply view must expose packing controls")
    check(game.home_report_text.position.y + game.home_report_text.size.y <= game.home_pack_button.position.y,"scroll area must not overlap pack action")
    game._pack_home_supplies()
    check(game.home_pack_button.disabled and game.home_pack_button.text == "ГОТОВО","complete kit disables repeat action")
    check(game.home_supply_status.get_minimum_size().x <= 568.0,"transfer result must fit status row")
    game._toggle_home_supply_view()
    check(not game.home_pack_button.visible and game.home_report_text.size.y == 158,"journal tab must restore report area")
    game.free()
    print("HOME SUPPLIES: ",checks," checks, ",failures," failures")
    quit(1 if failures > 0 else 0)
