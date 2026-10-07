extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const SettlementProjects = preload("res://world/settlement_projects.gd")
const RegionalStability = preload("res://world/regional_stability.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func run()->void:
    var old=FactionEconomy.default_state()
    for route_id in RegionalStability.STARTER_ROUTE_IDS: old["world_routes"][route_id]={"id":route_id,"state":"open","opened_day":10}
    SettlementProjects.ensure_state(old); FactionEndgame.ensure_state(old)
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); var rec=SettlementProjects.default_record(); rec["completed"]=true; rec["strategic_installed"]=true; old["settlement_projects"]["records"][fid]=rec
        var spec=FactionEndgame.chain(fid); var templates=spec.get("templates",[]); old["faction_endgame"]["chains"][fid]={"progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":25}; old["faction_endgame"]["effects"][str(spec.get("effect",""))]=true
        for resource_id in FactionEconomy.RESOURCE_KEYS: old["factions"][fid]["resources"][str(resource_id)]=61.0
    old["supply_events"]["active"]={}
    check(not old.has("regional_stability"),"dev1 fixture unexpectedly persists a regional stability subsystem")
    var migrated=FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(old)))
    check(not migrated.has("regional_stability"),"1.26-dev1 added a new persistent readiness field")
    var report=RegionalStability.report(migrated,77)
    check(bool(report.get("ready",false)),"schema-122 style state does not reconstruct regional readiness after sanitize")
    check(int(report.get("score",0))==100,"reconstructed readiness score drifted after save JSON round-trip")
    print("REGIONAL STABILITY SAVE 1.26-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
