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
    print("SANDBOX_IDENTITY_CAPTURE ",name," result=",err)
func _board(game,faction_id:String,npc_name:String,npc_id:String,rep:int,name:String) -> void:
    game._close_contract_board()
    game.faction_state = game.FactionEconomy.default_state()
    game.FactionEconomy.add_reputation(game.faction_state,faction_id,rep)
    game.ContractSystem.refresh_offers(game.faction_state,game.world_day,true)
    game._open_contract_board(faction_id,npc_name,npc_id)
    for i in range(3): await process_frame
    await _snap(name)
func run() -> void:
    if output == "":
        printerr("Pass --qa-output")
        quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    var game = Main.new(); root.add_child(game)
    for i in range(5): await process_frame
    game.world_day = 6
    await _board(game,"perron","Вера Андреевна","perron_steward",8,"dev14_perron_risk2")
    await _board(game,"lazaret","Доктор Миронова","lazaret_doctor",10,"dev14_lazaret_risk3")
    await _board(game,"rubezh","Ирина","rubezh_dispatch",9,"dev14_rubezh_risk3")
    await _board(game,"mechanics","Гена","mechanics_electrician",9,"dev14_mechanics_risk4")
    game.queue_free(); await process_frame
    quit(0)
