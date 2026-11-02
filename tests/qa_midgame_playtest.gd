extends SceneTree
# Visual QA (dev85): the middle and the end of a run, screen by screen - the
# Lazaret, Dr Mironova, the contract board, a trader, the workbench, building,
# the radio chronicle, the clinical complex, the ending.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_midgame_playtest.gd -- --qa-output=<dir>
const Main = preload("res://main_script_mod.gd")
var output = ""
var game = null
var shot = 0

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await process_frame

func snap(name: String) -> void:
    await RenderingServer.frame_post_draw
    shot += 1
    root.get_texture().get_image().save_png("%s/%02d_%s.png" % [output, shot, name])
    var obj = game._hud_survival_objective()
    print("SHOT %02d_%s goal=%s | %s" % [shot, name, obj.get("title", ""), obj.get("sub", "")])

func find_npc(npc_id: String):
    for n in get_nodes_in_group("interactable"):
        if is_instance_valid(n) and str(n.get_meta("npc_id", "")) == npc_id:
            return n
    return null

func run():
    Engine.set_meta("ostatok_new_game", true)
    game = Main.new()
    root.add_child(game)
    await frames(10)
    game.developer_invulnerable = true
    game.field_hints.finish_steps()
    game.field_hints._queue.clear()
    # the Lazaret
    var laz = game.RegionCatalog.poi_by_id(game.VerticalSlice.SETTLEMENT_ID).get("coord", Vector2i(-8, -2))
    game._qa_move_to_world_chunk(laz)
    game.world_minutes = 11.0 * 60.0
    await frames(60)
    game._vertical_slice_refresh()
    await frames(10)
    await snap("lazaret_arrival")
    # Dr Mironova
    var doc = find_npc("lazaret_doctor")
    print("DOCTOR found=", doc != null)
    if doc != null:
        game.player.global_position = doc.global_position + Vector2(0, 22)
        await frames(20)
        await snap("doctor_near")
        game._talk_faction_npc(doc)
        await frames(10)
        await snap("doctor_talk")
        game._close_contract_board()
        await frames(5)
    game._vertical_slice_refresh()
    await frames(5)
    await snap("after_doctor")
    # the contract board
    game._open_contract_board("lazaret", "Доктор Миронова", "lazaret_doctor")
    await frames(10)
    await snap("contract_board")
    game._close_contract_board()
    await frames(5)
    # a trader
    game._open_trader("lazaret_supplier")
    await frames(10)
    await snap("trader")
    game._close_trader()
    await frames(5)
    # the workbench and building
    game._open_crafting()
    await frames(10)
    await snap("crafting")
    game._close_crafting()
    game._close_inventory()
    await frames(5)
    game._open_base_build()
    await frames(10)
    await snap("base_build")
    game._close_base_build()
    game._close_inventory()
    await frames(5)
    # the radio chronicle
    if game.has_method("_open_world_chronicle"):
        game._open_world_chronicle()
        await frames(10)
        await snap("chronicle")
        if game.has_method("_close_world_chronicle"):
            game._close_world_chronicle()
        else:
            game._close_region_map()
        await frames(5)
    # the clinical complex
    var cl = game.RegionCatalog.poi_by_id(game.VerticalSlice.HIGH_RISK_POI_ID).get("coord", Vector2i(-7, 1))
    game._qa_move_to_world_chunk(cl)
    await frames(60)
    await snap("clinic_outside")
    # the ending
    var ending = game.RegionalEndgame.outcome_definition(game.faction_state)
    game._show_ending_screen({}, ending, 30)
    await frames(30)
    await snap("ending")
    quit(0)
