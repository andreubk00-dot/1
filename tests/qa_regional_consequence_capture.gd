extends SceneTree
# Visual QA for 1.26-dev4 frozen regional consequence UI.
# Run with Godot 4.7.2:
#   godot --path . --script tests/qa_regional_consequence_capture.gd -- --qa-output=/abs/dir
const Main = preload("res://main_script_mod.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const RegionalEndgame = preload("res://world/regional_endgame.gd")
var output := ""
func _initialize()->void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output=arg.trim_prefix("--qa-output=")
    call_deferred("run")
func _prime(game)->void:
    var hardship={}; var minima={}
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); hardship[fid]=0; minima[fid]={}
        for resource_id in RegionalEndgame.RESOURCE_KEYS:
            var rid=str(resource_id); game.faction_state["factions"][fid]["resources"][rid]=70.0; minima[fid][rid]=60.0
    game.faction_state["regional_endgame"]={"phase":"season_complete","started_day":50,"ends_day":71,"last_tick_day":71,"completion_day":71,"pressure_applied_day":71,"checkpoints":[7,14],"hardship_days":hardship,"resource_minima":minima,"outcome":{},"history":[{"day":50,"event":"started"},{"day":71,"event":"completed"}]}
    var outcome=RegionalEndgame.resolve_outcome(game.faction_state,71)
    game._record_regional_endgame_outcome(outcome,71)
func _snap(name:String)->int:
    await process_frame
    await RenderingServer.frame_post_draw
    var path="%s/%s.png" % [output,name]
    var err=root.get_texture().get_image().save_png(path)
    print("REGIONAL CONSEQUENCE CAPTURE: ",path," err=",err)
    return err
func run()->void:
    if output=="":
        printerr("Pass --qa-output=<dir>")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output)
    var game=Main.new(); root.add_child(game)
    for i in range(6): await process_frame
    game.faction_state=game.FactionEconomy.default_state(); game.world_day=90; _prime(game)
    game.active_contract_faction="perron"; game.active_contract_npc_id=""; game.active_contract_npc_name="ДОСКА"; game.contract_open=true
    game._create_contract_ui(); game._refresh_contract_ui()
    for i in range(3): await process_frame
    var err1=await _snap("regional_consequence_board")
    game.contract_panel.visible=false
    game._open_world_chronicle()
    for i in range(3): await process_frame
    var err2=await _snap("regional_consequence_chronicle")
    game.queue_free(); await process_frame
    quit(0 if err1==OK and err2==OK else 2)
