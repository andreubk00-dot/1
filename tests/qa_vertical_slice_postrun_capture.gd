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
    print("SLICE_POSTRUN_CAPTURE ",name," result=",err)
func _find_crisis_offer(game,day:int) -> Dictionary:
    for row in game.ContractSystem.offers_for_faction(game.faction_state,"lazaret",day):
        if str(row.get("template_id","")) == game.VerticalSlice.CRISIS_TEMPLATE_ID:
            return row
    return {}
func _find_active_row(game) -> int:
    for i in range(game.contract_list.item_count):
        var meta = game.contract_list.get_item_metadata(i)
        if typeof(meta) != TYPE_DICTIONARY or str(meta.get("source","")) != "active":
            continue
        var row = game.ContractSystem.contract_by_id(game.faction_state,str(meta.get("id","")))
        if str(row.get("template_id","")) == game.VerticalSlice.CRISIS_TEMPLATE_ID:
            return i
    return -1
func run() -> void:
    if output == "":
        printerr("Pass --qa-output with an existing screenshot directory")
        quit(1); return
    var game = Main.new()
    root.add_child(game)
    for i in range(4): await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.VerticalSlice.setup_new_game(game.faction_state,1)
    game.SupplyEventSystem.ensure_state(game.faction_state,1)
    game.ContractSystem.ensure_state(game.faction_state,1)
    game.world_day = 2
    game.VerticalSlice.mark_doctor_met(game.faction_state,1)
    var offer = _find_crisis_offer(game,1)
    if not offer.is_empty():
        game.ContractSystem.accept(game.faction_state,str(offer.get("id","")),1)
    game.faction_state["supply_events"]["active"] = {}
    game.faction_state["supply_events"]["history"] = [{"id":"cap_supply","faction":"lazaret","created_day":2,"closed_day":2,"outcome":"recovered","stage":"distress"}]
    game.FactionEconomy.adjust_resource(game.faction_state,"lazaret","medicine",14.0)
    var laz = game.RegionCatalog.poi_by_id(game.VerticalSlice.SETTLEMENT_ID).get("coord",Vector2i(-8,-2))
    game._qa_move_to_world_chunk(laz)
    game.discovered_pois[game.VerticalSlice.HIGH_RISK_POI_ID] = true
    game._grid_add(game.inventory_entries,"sterile_bandage",4,game.INV_W,game.INV_H)
    game._grid_add(game.inventory_entries,"painkillers",3,game.INV_W,game.INV_H)
    game._vertical_slice_refresh()
    game._open_contract_board("lazaret","Доктор Миронова","lazaret_doctor")
    await process_frame
    var row = _find_active_row(game)
    if row >= 0:
        game._contract_selected(row)
        game._contract_complete_selected()
    game._close_contract_board()
    for i in range(4): await process_frame
    await _snap("postrun_hud_before_debrief")
    game._open_region_map()
    for i in range(3): await process_frame
    await _snap("postrun_map_free")
    game._close_region_map()
    var doctor = Node2D.new()
    doctor.set_meta("npc_id","lazaret_doctor")
    doctor.set_meta("faction_id","lazaret")
    doctor.set_meta("display_name","Доктор Миронова")
    doctor.set_meta("npc_role","старший врач")
    game.add_child(doctor)
    game._talk_faction_npc(doctor)
    for i in range(3): await process_frame
    await _snap("postrun_hud_after_debrief")
    game._open_world_chronicle()
    for i in range(3): await process_frame
    await _snap("postrun_radio")
    game.queue_free()
    await process_frame
    quit(0)
