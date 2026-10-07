extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const RegionalEndgame = preload("res://world/regional_endgame.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func _prime_complete(game)->void:
    var hardship={}; var minima={}
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); hardship[fid]=0; minima[fid]={}
        for resource_id in RegionalEndgame.RESOURCE_KEYS:
            var rid=str(resource_id); game.faction_state["factions"][fid]["resources"][rid]=70.0; minima[fid][rid]=60.0
    game.faction_state["regional_endgame"]={"phase":"season_complete","started_day":50,"ends_day":71,"last_tick_day":71,"completion_day":71,"pressure_applied_day":71,"checkpoints":[7,14],"hardship_days":hardship,"resource_minima":minima,"outcome":{},"history":[{"day":50,"event":"started"},{"day":71,"event":"completed"}]}
    RegionalEndgame.resolve_outcome(game.faction_state,71)
func run()->void:
    var game=Harness.new(); root.add_child(game); await process_frame; await process_frame
    game.faction_state=game.FactionEconomy.default_state(); game.world_day=90; _prime_complete(game)
    game.active_contract_faction="perron"; game.active_contract_npc_id=""; game.active_contract_npc_name="ДОСКА"; game.contract_open=true
    game._create_contract_ui(); game._refresh_contract_ui()
    check(str(game.contract_status.text).find("ИТОГ РЕГИОНА")>=0,"common board does not show frozen regional ending")
    check(str(game.contract_status.text).find("ОБЩИЙ КОНТУР")>=0,"common board does not show global outcome title")
    check(str(game.contract_status.text).find("Sandbox продолжается")>=0,"ending UI does not explain continued sandbox")
    game._create_region_map_ui(); game._create_world_chronicle_ui(); game._refresh_world_chronicle_ui()
    check(game.regional_endgame_button!=null,"endgame button missing after completed season")
    check(game.regional_endgame_button.disabled,"completed season button can be started again")
    check(str(game.regional_endgame_button.text)=="ИТОГ РЕГИОНА","completed season button has wrong terminal label")
    check(not bool(RegionalEndgame.can_start(game.faction_state,game.world_day).get("ok",false)),"completed save can restart crisis season")
    game.queue_free(); await process_frame
    print("REGIONAL CONSEQUENCE RUNTIME 1.26-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
