extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const SettlementProjects = preload("res://world/settlement_projects.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const RegionalStability = preload("res://world/regional_stability.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func _prime(game)->void:
    for route_id in RegionalStability.STARTER_ROUTE_IDS: game.faction_state["world_routes"][route_id]={"id":route_id,"state":"open"}
    SettlementProjects.ensure_state(game.faction_state); FactionEndgame.ensure_state(game.faction_state)
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); var rec=SettlementProjects.default_record(); rec["completed"]=true; rec["strategic_installed"]=true; game.faction_state["settlement_projects"]["records"][fid]=rec
        var spec=FactionEndgame.chain(fid); var templates=spec.get("templates",[]); game.faction_state["faction_endgame"]["chains"][fid]={"progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":20}; game.faction_state["faction_endgame"]["effects"][str(spec.get("effect",""))]=true
        for resource_id in game.FactionEconomy.RESOURCE_KEYS: game.faction_state["factions"][fid]["resources"][str(resource_id)]=60.0
    game.faction_state["supply_events"]["active"]={}
func run()->void:
    var game=Harness.new(); root.add_child(game); await process_frame; await process_frame
    game.faction_state=game.FactionEconomy.default_state(); _prime(game)
    game.active_contract_faction="perron"; game.active_contract_npc_id=""; game.active_contract_npc_name="ДОСКА"; game.contract_open=true; game._create_contract_ui(); game._refresh_contract_ui()
    check(str(game.contract_status.text).find("УСТОЙЧИВОСТЬ 100%")>=0,"common contract board does not show regional readiness")
    check(str(game.contract_status.text).find("ГОТОВО К ФИНАЛЬНОМУ СЕЗОНУ")>=0,"common board does not expose next endgame threshold")
    game.faction_state["supply_events"]["active"]={"id":"qa","faction":"perron"}; game._refresh_contract_ui()
    check(str(game.contract_status.text).find("SOS НЕ ЗАКРЫТ")>=0,"common board does not reflect active supply incident gate")
    game.queue_free(); await process_frame
    print("REGIONAL STABILITY RUNTIME 1.26-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
