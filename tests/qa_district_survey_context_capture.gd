extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")

func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game = Harness.new(); root.add_child(game)
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.current_chunk = Vector2i(0,0)
    game.region_map_center = Vector2i(0,0)
    game._create_region_map_ui()
    for y in range(-1,2):
        for x in range(-1,2):
            game.discovered_chunks[game._zone_chunk_key(Vector2i(x,y))] = true
    game.discovered_pois["central_clinic"] = true
    game.region_map_selected_chunk = Vector2i(0,0)
    game.region_map_open = true
    game.region_map_canvas.visible = true
    game.region_map_panel.visible = true
    game._refresh_region_map_ui()
    await process_frame; await process_frame
    var image = game.get_viewport().get_texture().get_image()
    var out = OS.get_environment("OSTATOK_QA_CAPTURE")
    if out == "": out = "/tmp/ostatok_dev18_district_survey_context.png"
    var err = image.save_png(out)
    print("DEV18 DISTRICT SURVEY CAPTURE: ",out," err=",err)
    game.queue_free(); await process_frame
    quit(0 if err == OK else 1)
