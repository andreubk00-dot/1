extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _find_button(parent: Node, caption: String):
    for child in parent.get_children():
        if child is Button and str(child.text) == caption:
            return child
    return null

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame
    game._create_inventory_ui()

    game.inventory_entries = [{"id":"akm","qty":1,"x":0,"y":0}]
    game._ensure_runtime_item_instance_ids()
    game._ensure_weapon_runtime_state(false)
    var iid = str(game.inventory_entries[0].get("instance_id",""))
    check(iid != "","AKM test instance id was not created")
    check(game._set_weapon_mod_slot("akm","magazine","akm_extmag",iid),"AKM extended magazine setup failed")
    check(game._set_weapon_mod_slot("akm","muzzle","muzzle_brake",iid),"AKM muzzle setup failed")
    game.inventory_open = true
    game.selected_inventory_index = 0
    game._refresh_inventory_ui()
    await process_frame

    var use_button = _find_button(game.inventory_panel,"ИСП.")
    check(use_button != null,"inventory use button missing")
    check(game.inv_details.text.count("\n") == 5,"full firearm description must keep six information lines")
    check(game.inv_details.text.contains("Моды: 45Р, ДТК"),"full firearm description lost installed mods")
    check(game.inv_details.text.contains("Быстрый слот"),"inventory firearm description lost quick-slot hint")
    check(game.inv_details.get_combined_minimum_size().y <= game.inv_details.size.y + 0.1,"inventory details control is shorter than its rendered text")
    if use_button != null:
        check(game.inv_details.position.y + game.inv_details.size.y <= use_button.position.y,"inventory firearm details overlap action row")
    check(game.inventory_panel.position.y + game.inventory_panel.size.y * game.inventory_panel.scale.y <= 360.0,"inventory panel exceeds 640x360 viewport")

    game.inventory_entries = []
    game.container_states = {"qa_box":{"name":"ОРУЖЕЙНЫЙ ЯЩИК","grid_w":8,"grid_h":8,"items":[{"id":"akm","qty":1,"x":0,"y":0}]}}
    game._ensure_runtime_item_instance_ids()
    game._ensure_weapon_runtime_state(false)
    var ce = game.container_states["qa_box"]["items"][0]
    var ciid = str(ce.get("instance_id",""))
    check(ciid != "","container AKM test instance id was not created")
    check(game._set_weapon_mod_slot("akm","magazine","akm_extmag",ciid),"container AKM extended magazine setup failed")
    check(game._set_weapon_mod_slot("akm","muzzle","muzzle_brake",ciid),"container AKM muzzle setup failed")
    game.active_container_key = "qa_box"
    game.selected_inventory_index = -1
    game.selected_container_index = 0
    game._refresh_inventory_ui()
    await process_frame

    check(game.cont_details.text.count("\n") <= 2,"container inspection must stay within three lines")
    check(game.cont_details.text.contains("Сост."),"container firearm inspection lost condition")
    check(game.cont_details.text.contains("Урон"),"container firearm inspection lost damage")
    check(game.cont_details.text.contains("Маг."),"container firearm inspection lost magazine state")
    check(not game.cont_details.text.contains("Быстрый слот"),"container inspection must not show irrelevant quick-slot hint")
    check(game.cont_details.get_combined_minimum_size().y <= game.cont_details.size.y + 0.1,"container details control is shorter than compact text")
    check(game.cont_details.position.y + game.cont_details.size.y <= game.cont_take_button.position.y,"container details overlap take buttons")
    check(game.container_panel.position.y + game.container_panel.size.y * game.container_panel.scale.y <= 360.0,"default container panel exceeds 640x360 viewport")

    game.container_states["qa_box"]["items"] = [{"id":"generator_control_unit","qty":1,"x":0,"y":0}]
    game.selected_container_index = 0
    game._refresh_inventory_ui()
    await process_frame
    check(game.cont_details.text.contains("Блок управления генератором"),"long strategic name missing in compact inspection")
    check(game.cont_details.get_combined_minimum_size().x <= game.cont_details.size.x + 0.1,"long strategic name widens container details past panel")
    check(game.cont_details.get_combined_minimum_size().y <= game.cont_details.size.y + 0.1,"strategic container details exceed reserved height")

    game.queue_free()
    await process_frame
    print("INVENTORY DETAIL READABILITY 1.28: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
