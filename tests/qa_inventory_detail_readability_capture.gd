extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var output := ""
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")
func _shot(path: String) -> int:
    return root.get_texture().get_image().save_png(path)
func run() -> void:
    if output == "":
        printerr("Pass --qa-output=<dir>")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output)
    var game = Harness.new()
    root.add_child(game)
    await process_frame
    game._create_inventory_ui()

    game.inventory_entries = [{"id":"akm","qty":1,"x":0,"y":0}]
    game._ensure_runtime_item_instance_ids()
    game._ensure_weapon_runtime_state(false)
    var iid = str(game.inventory_entries[0].get("instance_id",""))
    game._set_weapon_mod_slot("akm","magazine","akm_extmag",iid)
    game._set_weapon_mod_slot("akm","muzzle","muzzle_brake",iid)
    game.inventory_open = true
    game.selected_inventory_index = 0
    game._refresh_inventory_ui()
    await process_frame
    await RenderingServer.frame_post_draw
    var a = _shot(output + "/inventory_firearm_details.png")

    game.inventory_entries = []
    game.container_states = {"qa_box":{"name":"ОРУЖЕЙНЫЙ ЯЩИК","grid_w":8,"grid_h":8,"items":[{"id":"akm","qty":1,"x":0,"y":0}]}}
    game._ensure_runtime_item_instance_ids()
    game._ensure_weapon_runtime_state(false)
    var ciid = str(game.container_states["qa_box"]["items"][0].get("instance_id",""))
    game._set_weapon_mod_slot("akm","magazine","akm_extmag",ciid)
    game._set_weapon_mod_slot("akm","muzzle","muzzle_brake",ciid)
    game.active_container_key = "qa_box"
    game.selected_inventory_index = -1
    game.selected_container_index = 0
    game._refresh_inventory_ui()
    await process_frame
    await RenderingServer.frame_post_draw
    var b = _shot(output + "/container_firearm_details.png")

    game.queue_free()
    await process_frame
    print("INVENTORY DETAIL CAPTURE: ",output," errs=",a,",",b)
    quit(0 if a == OK and b == OK else 2)
