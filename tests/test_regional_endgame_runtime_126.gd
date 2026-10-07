extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const SettlementProjects = preload("res://world/settlement_projects.gd")
const RegionalStability = preload("res://world/regional_stability.gd")
const RegionalEndgame = preload("res://world/regional_endgame.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func _prime(game)->void:
    for route_id in RegionalStability.STARTER_ROUTE_IDS:
        game.faction_state["world_routes"][route_id]={"id":route_id,"state":"open"}
    SettlementProjects.ensure_state(game.faction_state)
    FactionEndgame.ensure_state(game.faction_state)
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id)
        var rec=SettlementProjects.default_record()
        rec["completed"]=true
        rec["strategic_installed"]=true
        game.faction_state["settlement_projects"]["records"][fid]=rec
        var spec=FactionEndgame.chain(fid)
        var templates=spec.get("templates",[])
        game.faction_state["faction_endgame"]["chains"][fid]={"progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":20}
        game.faction_state["faction_endgame"]["effects"][str(spec.get("effect",""))]=true
        for resource_id in game.FactionEconomy.RESOURCE_KEYS:
            game.faction_state["factions"][fid]["resources"][str(resource_id)]=60.0
    game.faction_state["supply_events"]["active"]={}
func run()->void:
    var game=Harness.new()
    root.add_child(game)
    await process_frame
    await process_frame
    game.faction_state=game.FactionEconomy.default_state()
    game.world_day=50
    _prime(game)
    game._create_region_map_ui()
    game._create_world_chronicle_ui()
    game._refresh_world_chronicle_ui()
    check(game.regional_endgame_button!=null,"regional endgame button was not created in chronicle")
    check(not game.regional_endgame_button.disabled,"100% ready calm state does not enable crisis-season button")
    check(str(game.regional_endgame_button.text)=="КРИЗИСНЫЙ СЕЗОН","ready button has wrong label")
    check(game._regional_endgame_start(),"runtime start action failed")
    check(RegionalEndgame.phase(game.faction_state)==RegionalEndgame.PHASE_ACTIVE,"runtime start action did not persist active phase")
    check(game.regional_endgame_button.disabled,"active season button must be disabled")
    check(str(game.regional_endgame_button.text).find("21")>=0,"active season button does not show days left")
    game.queue_free()
    await process_frame
    print("REGIONAL ENDGAME RUNTIME 1.26-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
