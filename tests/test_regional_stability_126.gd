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

func _open_routes(state:Dictionary)->void:
    for route_id in RegionalStability.STARTER_ROUTE_IDS:
        state["world_routes"][route_id]={"id":route_id,"state":"open","opened_day":12}
func _complete_projects(state:Dictionary)->void:
    SettlementProjects.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var rec=SettlementProjects.default_record(); rec["completed"]=true; rec["completed_day"]=18; rec["strategic_installed"]=true
        state["settlement_projects"]["records"][str(faction_id)]=rec
func _complete_networks(state:Dictionary)->void:
    FactionEndgame.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var spec=FactionEndgame.chain(str(faction_id)); var templates=spec.get("templates",[])
        state["faction_endgame"]["chains"][str(faction_id)]={"progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":24}
        state["faction_endgame"]["effects"][str(spec.get("effect",""))]=true
func _stable_resources(state:Dictionary,value:float=60.0)->void:
    for faction_id in FactionCatalog.ids():
        for resource_id in FactionEconomy.RESOURCE_KEYS:
            state["factions"][str(faction_id)]["resources"][str(resource_id)]=value
func _ready_state()->Dictionary:
    var state=FactionEconomy.default_state(); _open_routes(state); _complete_projects(state); _complete_networks(state); _stable_resources(state); state["supply_events"]["active"]={}; return state

func run()->void:
    check(abs(RegionalStability.STABLE_RESOURCE_MIN-55.0)<0.001,"regional stability floor drifted from settlement STABLE threshold")
    var base=FactionEconomy.default_state(); var r=RegionalStability.report(base,30)
    check(not bool(r.get("ready",false)),"fresh game is incorrectly endgame-ready")
    check(int(r.get("routes",0))==0,"fresh game route readiness must start at 0/4")
    check(int(r.get("projects",0))==0,"fresh game project readiness must start at 0/4")
    check(int(r.get("networks",0))==0,"fresh game network readiness must start at 0/4")

    var staged=FactionEconomy.default_state(); _open_routes(staged); _complete_projects(staged); _complete_networks(staged); _stable_resources(staged,54.0)
    r=RegionalStability.report(staged,40)
    check(int(r.get("routes",0))==4 and int(r.get("projects",0))==4 and int(r.get("networks",0))==4,"completed infrastructure is not counted 4/4")
    check(int(r.get("stable_settlements",0))==0,"54 resources must stay below STABLE readiness")
    check(int(r.get("score",0))==75,"readiness score must reflect 12/16 completed component slots")
    staged["factions"]["perron"]["resources"]["food"]=55.0
    check(int(RegionalStability.report(staged,40).get("stable_settlements",0))==0,"one repaired resource must not mark a whole settlement stable")

    var ready=_ready_state(); r=RegionalStability.report(ready,50)
    check(int(r.get("score",0))==100,"fully developed regional state must report 100%")
    check(bool(r.get("infrastructure_ready",false)),"fully developed state lost infrastructure readiness")
    check(bool(r.get("ready",false)),"fully developed calm state must be ready for crisis season")
    check(str(RegionalStability.summary(ready,50)).find("ГОТОВО К ФИНАЛЬНОМУ СЕЗОНУ")>=0,"ready summary does not advertise next endgame phase")

    ready["supply_events"]["active"]={"id":"qa_sos","faction":"perron"}
    r=RegionalStability.report(ready,50)
    check(int(r.get("score",0))==100,"active SOS incorrectly destroys infrastructure readiness score")
    check(bool(r.get("infrastructure_ready",false)),"active SOS incorrectly destroys infrastructure readiness")
    check(not bool(r.get("ready",true)),"active SOS must temporarily block crisis-season launch")
    check(str(RegionalStability.summary(ready,50)).find("SOS НЕ ЗАКРЫТ")>=0,"active incident is not explained in summary")

    var one_low=_ready_state(); one_low["factions"]["lazaret"]["resources"]["medicine"]=54.9; r=RegionalStability.report(one_low,55)
    check(int(r.get("stable_settlements",0))==3,"single sub-stable resource must block exactly its settlement")
    check(not bool(r.get("ready",true)),"sub-stable settlement must block readiness")
    check(str(r.get("blockers",[])[0]).find("стабилизировать поселения 3/4")>=0,"resource blocker does not explain 3/4 settlement state")

    print("REGIONAL STABILITY SYSTEM 1.26-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
