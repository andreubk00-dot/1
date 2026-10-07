extends SceneTree
const Main = preload("res://main_script_mod.gd")
var output := ""
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")
func _snap(name:String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var err = root.get_texture().get_image().save_png(output + "/" + name + ".png")
    print("SANDBOX_CONSEQUENCES_CAPTURE ",name," result=",err)
func _route_record(game,template_id:String) -> Dictionary:
    var route = game.ContractCatalog.template(template_id).get("reward",{}).get("route",{}).duplicate(true)
    route["state"] = "open"
    route["opened_day"] = 12
    route["source_contract"] = template_id
    return route
func run() -> void:
    if output == "":
        printerr("Pass --qa-output")
        quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    var game = Main.new(); root.add_child(game)
    for i in range(5): await process_frame
    game.world_day = 12
    game.world_minutes = 720.0
    game.faction_state = game.FactionEconomy.default_state()
    game.FactionEconomy.add_reputation(game.faction_state,"perron",30)
    game.faction_state["world_routes"]["route_perron_zarya"] = _route_record(game,"perron_zarya_route")
    game.SandboxRouteConsequences.apply_opening_stock(game.faction_state,"route_perron_zarya")
    game._open_trader("perron_canteen")
    for i in range(3): await process_frame
    await _snap("dev15_perron_route_trader")
    game._close_trader()

    var cook = Node2D.new()
    cook.set_meta("npc_id","perron_cook")
    cook.set_meta("faction_id","perron")
    cook.set_meta("display_name","Тётя Галя")
    cook.set_meta("npc_role","заведующая кухней")
    game.add_child(cook)
    game._talk_faction_npc(cook)
    for i in range(2): await process_frame
    await _snap("dev15_perron_route_npc")
    cook.queue_free()

    game._record_contract_world_news({"ok":true,"faction":"perron","title":"ДОРОГА К «ЗАРЕ»","opened_route":"route_perron_zarya","personal":false})
    game._open_world_chronicle()
    for i in range(3): await process_frame
    await _snap("dev15_perron_route_radio")

    game._close_region_map()
    game.faction_state = game.FactionEconomy.default_state()
    game.FactionEconomy.add_reputation(game.faction_state,"mechanics",30)
    game.faction_state["world_routes"]["route_mechanics_depot"] = _route_record(game,"mechanics_rail_depot")
    game.SandboxRouteConsequences.apply_opening_stock(game.faction_state,"route_mechanics_depot")
    game._open_trader("mechanics_parts")
    for i in range(3): await process_frame
    await _snap("dev15_mechanics_route_trader")

    game.queue_free(); await process_frame
    quit(0)
