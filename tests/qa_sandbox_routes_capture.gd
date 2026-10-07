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
    print("SANDBOX_CAPTURE ",name," result=",err)
func run() -> void:
    if output == "":
        printerr("Pass --qa-output")
        quit(1); return
    var game = Main.new()
    root.add_child(game)
    for i in range(5): await process_frame

    game.world_day = 5
    game.faction_state = game.FactionEconomy.default_state()
    game.FactionEconomy.add_reputation(game.faction_state,"perron",8)
    game.ContractSystem.refresh_offers(game.faction_state,game.world_day,true)
    game._open_contract_board("perron","Вера Андреевна","perron_steward")
    for i in range(3): await process_frame
    await _snap("sandbox_perron_board")
    game._close_contract_board()

    game.faction_state = game.FactionEconomy.default_state()
    game.FactionEconomy.add_reputation(game.faction_state,"lazaret",16)
    game.ContractSystem.refresh_offers(game.faction_state,game.world_day,true)
    game._open_contract_board("lazaret","Доктор Миронова","lazaret_doctor")
    for i in range(3): await process_frame
    await _snap("sandbox_lazaret_board")

    game.queue_free()
    await process_frame
    quit(0)
