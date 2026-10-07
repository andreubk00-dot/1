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
func near(a:float,b:float,eps:float=0.001)->bool: return abs(a-b)<=eps
func _initialize()->void: call_deferred("run")
func _ready_state(value:float=70.0)->Dictionary:
    var state=FactionEconomy.default_state()
    for route_id in RegionalStability.STARTER_ROUTE_IDS:
        state["world_routes"][route_id]={"id":route_id,"state":"open"}
    SettlementProjects.ensure_state(state); FactionEndgame.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); var rec=SettlementProjects.default_record(); rec["completed"]=true; rec["strategic_installed"]=true; state["settlement_projects"]["records"][fid]=rec
        var spec=FactionEndgame.chain(fid); var templates=spec.get("templates",[]); state["faction_endgame"]["chains"][fid]={"progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":20}; state["faction_endgame"]["effects"][str(spec.get("effect",""))]=true
        for resource_id in FactionEconomy.RESOURCE_KEYS: state["factions"][fid]["resources"][str(resource_id)]=value
    state["supply_events"]["active"]={}
    return state
func _res(state:Dictionary,fid:String,rid:String)->float: return float(state["factions"][fid]["resources"][rid])
func run()->void:
    var state=_ready_state(); check(bool(RegionalEndgame.start(state,50).get("ok",false)),"pressure fixture cannot start season")
    var d1=RegionalEndgame.daily_tick(state,51)
    check(bool(d1.get("active",false)),"day 1 unexpectedly completed season")
    check(near(_res(state,"perron","food"),69.45),"Perron food day-1 pressure drifted")
    check(near(_res(state,"rubezh","security"),68.90),"Rubezh security day-1 pressure drifted")
    check(near(_res(state,"mechanics","technical"),68.90),"Mechanics technical day-1 pressure drifted")
    check(near(_res(state,"lazaret","medicine"),69.05),"Lazaret medicine day-1 pressure drifted")
    var once=_res(state,"perron","food"); RegionalEndgame.daily_tick(state,51)
    check(near(_res(state,"perron","food"),once),"same-day regional tick applied pressure twice")

    var week=RegionalEndgame.daily_tick(state,57)
    check(week.get("checkpoints",[])==[7],"week-1 checkpoint missing or duplicated")
    check(near(_res(state,"perron","food"),63.15),"week-1 Perron pressure including pulse is wrong")
    check(state["regional_endgame"].get("checkpoints",[])==[7],"checkpoint 7 was not persisted")

    # Direct player/supply recovery remains outside the daily pressure and is not erased by a duplicate tick.
    state["factions"]["perron"]["resources"]["food"]+=10.0
    var recovered=_res(state,"perron","food"); RegionalEndgame.daily_tick(state,57)
    check(near(_res(state,"perron","food"),recovered),"same-day pressure erased direct recovery")

    var fortnight=RegionalEndgame.daily_tick(state,64)
    check(fortnight.get("checkpoints",[])==[14],"week-2 checkpoint missing or duplicated")
    check(state["regional_endgame"].get("checkpoints",[])==[7,14],"checkpoint persistence order drifted")
    var done=RegionalEndgame.daily_tick(state,71)
    check(bool(done.get("completed",false)),"season did not complete after final pressure day")
    check(int(state["regional_endgame"].get("pressure_applied_day",0))==71,"final pressure day was not persisted")
    var after=_res(state,"rubezh","security"); RegionalEndgame.daily_tick(state,72)
    check(near(_res(state,"rubezh","security"),after),"pressure continued after completed season")
    var minima=state["regional_endgame"].get("resource_minima",{})
    check(float(minima.get("rubezh",{}).get("security",100.0))<=_res(state,"rubezh","security")+0.001,"resource minima did not track pressure")
    print("CRISIS SEASON PRESSURE 1.26-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
