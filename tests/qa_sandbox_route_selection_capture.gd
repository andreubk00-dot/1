extends SceneTree
const Main = preload("res://main_script_mod.gd")
var output := ""
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
    call_deferred("run")
func _snap(name:String) -> void:
    await process_frame; await RenderingServer.frame_post_draw
    print("ROUTE_SELECTION_CAPTURE ",name," result=",root.get_texture().get_image().save_png(output + "/" + name + ".png"))
func run() -> void:
    if output == "": quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    var game = Main.new(); root.add_child(game)
    for i in range(5): await process_frame
    game.world_day=6
    game.faction_state=game.FactionEconomy.default_state()
    game.FactionEconomy.add_reputation(game.faction_state,"mechanics",9)
    game.ContractSystem.refresh_offers(game.faction_state,game.world_day,true)
    game._open_contract_board("mechanics","Гена","mechanics_electrician")
    for i in range(3): await process_frame
    var idx=-1
    for i in range(game.contract_list.item_count):
        if game.contract_list.get_item_text(i).find("ДЕПО: ПРОВЕРКА ПОДХОДОВ")>=0: idx=i; break
    if idx>=0:
        game.contract_list.select(idx); game._contract_selected(idx)
    for i in range(3): await process_frame
    await _snap("dev14_mechanics_selected")
    game.queue_free(); await process_frame
    quit(0)
