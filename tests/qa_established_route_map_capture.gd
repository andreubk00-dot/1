extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")

func _route(game,template_id:String) -> Dictionary:
    var route = game.ContractCatalog.template(template_id).get("reward",{}).get("route",{}).duplicate(true)
    route["state"] = "open"
    route["opened_day"] = 42
    route["source_contract"] = template_id
    return route

func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game = Harness.new(); root.add_child(game)
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.current_chunk = Vector2i(0,0)
    game.region_map_center = Vector2i(0,1)
    game._create_region_map_ui()
    for template_id in ["perron_zarya_route","lazaret_hospital_route","rubezh_police_route","mechanics_rail_depot"]:
        var t = game.ContractCatalog.template(template_id)
        var route_id = str(t.get("reward",{}).get("route",{}).get("id",""))
        game.faction_state["world_routes"][route_id] = _route(game,template_id)
        game.discovered_pois[str(t.get("poi_id",""))] = true
        var faction_id = str(t.get("faction",""))
        var settlement_id = str(game.FactionCatalog.faction(faction_id).get("settlement_id",""))
        game.discovered_pois[settlement_id] = true
    for y in range(-4,8):
        for x in range(-9,10):
            game.discovered_chunks[game._zone_chunk_key(Vector2i(x,y))] = true
    game.region_map_selected_chunk = Vector2i(-3,3)
    game.region_map_open = true
    game.region_map_canvas.visible = true
    game.region_map_panel.visible = true
    game._refresh_region_map_ui()
    await process_frame; await process_frame
    var image = game.get_viewport().get_texture().get_image()
    var out = OS.get_environment("OSTATOK_QA_CAPTURE")
    if out == "": out = "/tmp/ostatok_dev17_established_route_map.png"
    var err = image.save_png(out)
    print("DEV17 ROUTE MAP CAPTURE: ",out," err=",err)
    game.queue_free(); await process_frame
    quit(0 if err == OK else 1)
