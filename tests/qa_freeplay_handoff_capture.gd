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
    print("FREEPLAY_CAPTURE ",name," result=",err)
func _completed_slice(game) -> Dictionary:
    var rec = game.VerticalSlice.default_state()
    rec["initialized"] = true
    rec["completed"] = true
    rec["enabled"] = false
    rec["completed_day"] = 2
    rec["completion_feedback_issued"] = true
    rec["doctor_debrief_seen"] = true
    rec["doctor_debrief_day"] = 2
    return rec
func _find_offer(game,template_id:String) -> Dictionary:
    for row in game.ContractSystem.offers_for_faction(game.faction_state,"lazaret",game.world_day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}
func run() -> void:
    if output == "":
        printerr("Pass --qa-output")
        quit(1); return
    var game = Main.new()
    root.add_child(game)
    for i in range(5): await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.faction_state["vertical_slice"] = _completed_slice(game)
    game.world_day = 2
    game.expedition_journal = game.ExpeditionJournal.empty_state()
    game.expedition_active = false
    game.home_navigation_active = false
    game.FactionEconomy.add_reputation(game.faction_state,"lazaret",16)
    game.ContractSystem.refresh_offers(game.faction_state,game.world_day,true)
    var offer = _find_offer(game,"lazaret_hospital_route")
    if not offer.is_empty():
        game.ContractSystem.accept(game.faction_state,str(offer.get("id","")),game.world_day)
    game._update_hud()
    for i in range(3): await process_frame
    await _snap("freeplay_active_contract_hud")

    # Remove the contract so the no-home handoff can be inspected directly.
    game.faction_state["contracts"]["active"] = {}
    game._update_hud()
    game.region_map_selected_chunk = game.current_chunk + Vector2i(1,0)
    game._open_region_map()
    game._refresh_region_map_ui()
    for i in range(3): await process_frame
    await _snap("freeplay_map_no_home")
    game._close_region_map()

    game.expedition_journal["home"] = {"key":"cap-home","name":"УБЕЖИЩЕ","chunk":[game.current_chunk.x,game.current_chunk.y],"position":[0.0,0.0]}
    game._update_hud()
    game.region_map_selected_chunk = game.current_chunk + Vector2i(1,0)
    game._open_region_map()
    game._refresh_region_map_ui()
    for i in range(3): await process_frame
    await _snap("freeplay_map_with_home")
    game.queue_free()
    await process_frame
    quit(0)
