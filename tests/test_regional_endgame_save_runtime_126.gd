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
func _prime(state:Dictionary)->void:
    for route_id in RegionalStability.STARTER_ROUTE_IDS: state["world_routes"][route_id]={"id":route_id,"state":"open"}
    SettlementProjects.ensure_state(state); FactionEndgame.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); var rec=SettlementProjects.default_record(); rec["completed"]=true; rec["strategic_installed"]=true; state["settlement_projects"]["records"][fid]=rec
        var spec=FactionEndgame.chain(fid); var templates=spec.get("templates",[]); state["faction_endgame"]["chains"][fid]={"progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":20}; state["faction_endgame"]["effects"][str(spec.get("effect",""))]=true
        for resource_id in FactionEconomy.RESOURCE_KEYS: state["factions"][fid]["resources"][str(resource_id)]=62.0
    state["supply_events"]["active"]={}
func run()->void:
    var old=FactionEconomy.default_state()
    check(RegionalEndgame.phase(old)==RegionalEndgame.PHASE_DORMANT,"old/default state does not derive dormant regional endgame")
    _prime(old); check(bool(RegionalEndgame.start(old,80).get("ok",false)),"save fixture could not start season")
    RegionalEndgame.daily_tick(old,88)
    var roundtrip=FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(old)))
    check(RegionalEndgame.phase(roundtrip)==RegionalEndgame.PHASE_ACTIVE,"active season lost through schema-122 faction sanitize")
    check(int(roundtrip["regional_endgame"].get("started_day",0))==80,"start day lost after roundtrip")
    check(int(roundtrip["regional_endgame"].get("ends_day",0))==101,"end day lost after roundtrip")
    check(int(roundtrip["regional_endgame"].get("last_tick_day",0))==88,"last tick lost after roundtrip")
    var corrupt=FactionEconomy.sanitize_state({"regional_endgame":{"phase":"crisis_season","started_day":0,"ends_day":999999}})
    check(RegionalEndgame.phase(corrupt)==RegionalEndgame.PHASE_DORMANT,"corrupt active lifecycle was not reset safely")
    print("REGIONAL ENDGAME SAVE 1.26-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
