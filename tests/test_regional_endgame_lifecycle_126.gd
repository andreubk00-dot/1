extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
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
func _ready_state()->Dictionary:
    var state=FactionEconomy.default_state()
    for route_id in RegionalStability.STARTER_ROUTE_IDS:
        state["world_routes"][route_id]={"id":route_id,"state":"open"}
    SettlementProjects.ensure_state(state); FactionEndgame.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); var rec=SettlementProjects.default_record(); rec["completed"]=true; rec["strategic_installed"]=true; state["settlement_projects"]["records"][fid]=rec
        var spec=FactionEndgame.chain(fid); var templates=spec.get("templates",[]); state["faction_endgame"]["chains"][fid]={"progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":20}; state["faction_endgame"]["effects"][str(spec.get("effect",""))]=true
        for resource_id in FactionEconomy.RESOURCE_KEYS:
            state["factions"][fid]["resources"][str(resource_id)]=60.0
    state["supply_events"]["active"]={}
    return state
func run()->void:
    check(RegionalEndgame.DURATION_DAYS==21,"crisis season duration drifted")
    var cold=FactionEconomy.default_state(); check(not bool(RegionalEndgame.can_start(cold,30).get("ok",true)),"fresh state can start crisis season")
    var state=_ready_state(); check(bool(RegionalEndgame.can_start(state,50).get("ok",false)),"100% ready state cannot start crisis season")
    var started=RegionalEndgame.start(state,50)
    check(bool(started.get("ok",false)),"crisis season start failed")
    check(RegionalEndgame.phase(state)==RegionalEndgame.PHASE_ACTIVE,"phase did not enter crisis_season")
    check(int(state["regional_endgame"].get("started_day",0))==50,"start day not persisted")
    check(int(state["regional_endgame"].get("ends_day",0))==71,"21-day end boundary is wrong")
    check(RegionalEndgame.days_left(state,50)==21,"season must begin with 21 days left")
    check(not bool(RegionalEndgame.start(state,51).get("ok",true)),"active season can be started twice")
    var before=RegionalEndgame.daily_tick(state,70)
    check(bool(before.get("active",false)) and not bool(before.get("completed",true)),"season completed one day too early")
    check(RegionalEndgame.days_left(state,70)==1,"day 70 should leave one day")
    var done=RegionalEndgame.daily_tick(state,71)
    check(bool(done.get("completed",false)),"season did not complete at day 71")
    check(RegionalEndgame.phase(state)==RegionalEndgame.PHASE_COMPLETE,"completed season phase not persisted")
    check(int(state["regional_endgame"].get("completion_day",0))==71,"completion day is wrong")
    check(not bool(RegionalEndgame.can_start(state,90).get("ok",true)),"completed season can be restarted")
    check(state["regional_endgame"].get("history",[]).size()==2,"lifecycle history must contain start and completion only")
    print("REGIONAL ENDGAME LIFECYCLE 1.26-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
