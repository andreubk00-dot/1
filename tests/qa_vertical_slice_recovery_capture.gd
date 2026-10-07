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
    print("SLICE_RECOVERY_CAPTURE ",name," result=",err)
func _find_crisis_offer(game,day:int) -> Dictionary:
    for row in game.ContractSystem.offers_for_faction(game.faction_state,"lazaret",day):
        if str(row.get("template_id","")) == game.VerticalSlice.CRISIS_TEMPLATE_ID:
            return row
    return {}
func run() -> void:
    if output == "":
        printerr("Pass --qa-output with an existing screenshot directory")
        quit(1); return
    var game = Main.new()
    root.add_child(game)
    for i in range(4): await process_frame
    var laz = game.RegionCatalog.poi_by_id(game.VerticalSlice.SETTLEMENT_ID).get("coord",Vector2i(-8,-2))
    var clinic = game.RegionCatalog.poi_by_id(game.VerticalSlice.HIGH_RISK_POI_ID).get("coord",Vector2i(-9,1))
    game._qa_move_to_world_chunk(laz)
    game.VerticalSlice.mark_doctor_met(game.faction_state,game.world_day)
    game.ContractSystem.refresh_offers(game.faction_state,game.world_day,true)
    var offer = _find_crisis_offer(game,game.world_day)
    if not offer.is_empty():
        game.ContractSystem.accept(game.faction_state,str(offer.get("id","")),game.world_day)
    game.world_day += 1
    game.SupplyEventSystem.daily_tick(game.faction_state,game.world_day,[])
    var event = game.SupplyEventSystem.active_event(game.faction_state,game.world_day)
    if not event.is_empty():
        game.SupplyEventSystem.resolve_success(game.faction_state,str(event.get("id","")),game.world_day)
    game._vertical_slice_refresh()
    game._vertical_slice_issue_field_reserve()
    game._qa_move_to_world_chunk(clinic)
    game.health = 0.0
    game._respawn_player()
    for i in range(6): await process_frame
    await _snap("recovery_hud")
    game._open_region_map()
    for i in range(3): await process_frame
    await _snap("recovery_map")
    game.queue_free()
    await process_frame
    quit(0)
