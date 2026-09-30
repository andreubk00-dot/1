extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const Plan = preload("res://world/supply_plan.gd")
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
    game.container_states["base_stash_2"] = {"name":"Домашний ящик","marker":"keep","items":[
        {"id":"water","qty":4,"x":0,"y":0},
        {"id":"canned_meat","qty":4,"x":1,"y":0},
        {"id":"bandage","qty":6,"x":2,"y":0},
        {"id":"ammo_9x18","qty":20,"x":3,"y":0}
    ]}
    return game

func total_everywhere(game,id):
    var result = game._inventory_count(id)
    for state in game.container_states.values():
        result += Plan.count(state.get("items",[]),[id])
    return result

func _initialize():
    call_deferred("run")

func run():
    var game = fresh()
    check(game._home_unloadable_item("scrap"),"scrap must be unloadable")
    check(game._home_unloadable_item("cloth"),"cloth must be unloadable")
    check(game._home_unloadable_item("firewood"),"firewood must be unloadable")
    check(game._home_unloadable_item("muzzle_brake"),"weapon modules are safe home resources")
    check(game._home_unloadable_item("grain"),"raw grain must be unloadable")
    check(game._home_unloadable_item("herbs"),"raw herbs must be unloadable")
    check(game._home_unloadable_item("dirty_water"),"raw collected water must be unloadable")
    for id in ["makarov","ammo_9x18","bandage","water","canned_meat","trauma_kit","repair_kit","water_filter","military_vest"]:
        check(not game._home_unloadable_item(id),"combat/ready item must stay in pack: " + id)
    game.inventory_entries = [
        {"id":"scrap","qty":5,"x":0,"y":0},
        {"id":"cloth","qty":3,"x":1,"y":0},
        {"id":"grain","qty":2,"x":2,"y":0},
        {"id":"muzzle_brake","qty":1,"x":3,"y":0,"instance_id":"qa_mod_1"},
        {"id":"makarov","qty":1,"x":4,"y":0,"instance_id":"qa_gun_1"},
        {"id":"ammo_9x18","qty":8,"x":6,"y":0},
        {"id":"bandage","qty":2,"x":7,"y":0}
    ]
    var conserved = {}
    for id in ["scrap","cloth","grain","muzzle_brake","makarov","ammo_9x18","bandage"]:
        conserved[id] = total_everywhere(game,id)
    var saves_before = game.save_calls
    check(game._home_unloadable_count() == 11,"unload counter must count only safe resource units")
    check(game._home_unload_resources(),"home unload should move safe resources")
    check(game.save_calls == saves_before + 1,"successful unload should save exactly once")
    check(game._inventory_count("scrap") == 0 and game._inventory_count("cloth") == 0 and game._inventory_count("grain") == 0,"materials/raw resources should leave backpack")
    check(game._inventory_count("muzzle_brake") == 0,"loose weapon module should be stored")
    var stored_mod_id = ""
    for stored_entry in game.container_states["base_stash_2"].get("items",[]):
        if str(stored_entry.get("id","")) == "muzzle_brake":
            stored_mod_id = str(stored_entry.get("instance_id",""))
    check(stored_mod_id == "qa_mod_1","unload must preserve module instance identity")
    check(game._inventory_count("makarov") == 1,"weapon must stay in backpack")
    check(game._inventory_count("ammo_9x18") == 8,"ammunition must stay in backpack")
    check(game._inventory_count("bandage") == 2,"medical supplies must stay in backpack")
    for id in conserved:
        check(total_everywhere(game,id) == conserved[id],"unload must conserve quantity: " + id)
    check(game.container_states["base_stash_2"].get("marker","") == "keep","stash metadata must survive unload")
    check(game.home_supply_feedback.contains("Разгружено: 11"),"unload feedback should report moved amount")
    saves_before = game.save_calls
    check(not game._home_unload_resources() and game.save_calls == saves_before,"second unload with no resources must not write")
    game.free()

    game = fresh()
    game.inventory_entries = [{"id":"scrap","qty":4,"x":0,"y":0}]
    game.player.position = Vector2(-49,40)
    var state_before = game.container_states.duplicate(true)
    var inv_before = game.inventory_entries.duplicate(true)
    check(not game._home_unload_resources(),"distant stash must block resource unload")
    check(game.container_states == state_before and game.inventory_entries == inv_before,"failed distant unload must be atomic")
    game.free()

    game = fresh()
    game.inventory_entries = [{"id":"scrap","qty":4,"x":0,"y":0}]
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
    inv_before = game.inventory_entries.duplicate(true)
    check(not game._home_unload_resources(),"wall must block resource unload")
    check(game.container_states == state_before and game.inventory_entries == inv_before,"wall-blocked unload must change nothing")
    game.free()

    game = fresh()
    # Fill the gameplay stash completely with unique 1x1 cells.
    var full = []
    for y in range(game.CONTAINER_H):
        for x in range(game.CONTAINER_W):
            full.append({"id":"scrap","qty":20,"x":x,"y":y})
    game.container_states["base_stash_2"]["items"] = full
    game.inventory_entries = [{"id":"cloth","qty":2,"x":0,"y":0}]
    state_before = game.container_states.duplicate(true)
    inv_before = game.inventory_entries.duplicate(true)
    saves_before = game.save_calls
    check(not game._home_unload_resources(),"full home stash must reject resource unload")
    check(game.container_states == state_before and game.inventory_entries == inv_before and game.save_calls == saves_before,"full-stash failure must be atomic/no-save")
    game.free()

    game = fresh()
    game._create_region_map_ui()
    game._create_home_journal_ui()
    game.inventory_entries = [{"id":"scrap","qty":3,"x":0,"y":0}]
    game.expedition_active = true
    game.expedition_target_chunk = Vector2i(4,5)
    game.expedition_target_name = "АРСЕНАЛ «БАСТИОН»"
    game.expedition_journal["supply_preset"] = 0
    game._open_home_journal()
    game._toggle_home_supply_view()
    check(game.home_unload_button != null and game.home_unload_button.visible,"supply view must expose resource unload")
    check(game.home_pack_button.visible and game.home_supply_preset.visible,"supply view must retain packing controls")
    check(game.home_unload_button.position.y == game.home_pack_button.position.y,"supply actions must share one row")
    check(game.home_unload_button.position.x + game.home_unload_button.size.x <= game.home_pack_button.position.x,"supply action buttons must not overlap")
    check(game.home_pack_button.position.x + game.home_pack_button.size.x <= game.home_journal_panel.size.x - 16.0 + 0.01,"pack button must remain inside journal panel")
    check(game.home_report_text.position.y + game.home_report_text.size.y <= game.home_pack_button.position.y,"supply text must not overlap actions")
    check(not game.home_report_text.text.contains("Рекомендуется:"),"supply panel must not recommend a preset from destination")
    check(game.home_report_text.text.contains("Выбранный комплект: КОРОТКИЙ ВЫХОД"),"supply panel should show only the player-selected preset")
    check(game.home_report_text.text.contains("Ресурсы к разгрузке: 3"),"supply panel should show unloadable amount")
    check(not game.home_unload_button.disabled,"resource unload should be enabled when reachable stash exists")
    game._home_unload_resources()
    check(game.home_unload_button.disabled,"unload action should disable after resources are stored")
    check(game.home_supply_status.get_minimum_size().x <= 568.0,"home action feedback must fit status row")
    game.free()

    print("HOME PREPARATION FINALIZATION: ",checks," checks, ",failures," failures")
    quit(1 if failures > 0 else 0)
