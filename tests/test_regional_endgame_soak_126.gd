extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const FactionRelations = preload("res://world/faction_relations.gd")
const SettlementProjects = preload("res://world/settlement_projects.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const RegionalEndgame = preload("res://world/regional_endgame.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func _open_route(state:Dictionary,template_id:String)->void:
    var route=ContractCatalog.template(template_id).get("reward",{}).get("route",{}).duplicate(true)
    check(not route.is_empty(),"missing route template "+template_id)
    if route.is_empty(): return
    route["state"]="open"; route["opened_day"]=1; route["source_contract"]=template_id
    state["world_routes"][str(route.get("id",""))]=route
func _prime()->Dictionary:
    var state=FactionEconomy.default_state()
    for template_id in ["perron_zarya_route","lazaret_hospital_route","rubezh_police_route","mechanics_rail_depot"]:
        _open_route(state,template_id)
    SettlementProjects.ensure_state(state); FactionEndgame.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id)
        var project=SettlementProjects.default_record(); project["strategic_installed"]=true; project["installed_day"]=1; project["completed"]=true; project["completed_day"]=1
        var spec=SettlementProjects.project(fid); project["resources"]=spec.get("resource_targets",{}).duplicate(true); state["settlement_projects"]["records"][fid]=project
        var chain=FactionEndgame.chain(fid); var templates=chain.get("templates",[])
        state["faction_endgame"]["chains"][fid]={"progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":1}
        state["faction_endgame"]["effects"][str(chain.get("effect",""))]=true
        for resource_id in FactionEconomy.RESOURCE_KEYS: state["factions"][fid]["resources"][str(resource_id)]=80.0
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); var effect=FactionEndgame.effect_for_faction(state,fid); var relations=effect.get("relations",{})
        if typeof(relations)==TYPE_DICTIONARY:
            for other_id in relations.keys(): FactionRelations.adjust_relation(state,fid,str(other_id),int(relations[other_id]),1,"dev5_endgame_soak")
    state["supply_events"]["active"]={}
    return state
func _worst(state:Dictionary,fid:String)->float:
    var value=100.0
    for resource_id in FactionEconomy.RESOURCE_KEYS: value=min(value,float(state["factions"][fid]["resources"][str(resource_id)]))
    return value
func _run(mode:String)->Dictionary:
    var state=_prime(); check(bool(RegionalEndgame.start(state,100).get("ok",false)),mode+" fixture could not start season")
    var outcome={}
    for day in range(101,122):
        FactionEconomy.daily_tick(state)
        var result=RegionalEndgame.daily_tick(state,day)
        if mode=="supported" and (day-100)%3==0:
            for fid in ["perron","rubezh","mechanics","lazaret"]:
                for resource_id in FactionEconomy.RESOURCE_KEYS: FactionEconomy.adjust_resource(state,fid,str(resource_id),4.0)
        elif mode=="selective" and (day-100)%3==0:
            for fid in ["perron","lazaret"]:
                for resource_id in FactionEconomy.RESOURCE_KEYS: FactionEconomy.adjust_resource(state,fid,str(resource_id),4.0)
        if bool(result.get("completed",false)):
            outcome=RegionalEndgame.resolve_outcome(state,day)
    check(RegionalEndgame.is_complete(state),mode+" did not complete after 21 days")
    check(not outcome.is_empty(),mode+" did not resolve consequence outcome")
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); var worst=_worst(state,fid)
        check(worst>=-0.001 and worst<=100.001,mode+" resource escaped bounds for "+fid)
    return {"state":state,"outcome":outcome}
func run()->void:
    var idle=_run("idle")
    var supported=_run("supported")
    var selective=_run("selective")
    for fid in ["perron","rubezh","mechanics","lazaret"]:
        check(_worst(supported["state"],fid)+0.001>=_worst(idle["state"],fid),"direct support made "+fid+" worse than idle")
    for fid in ["perron","lazaret"]:
        check(_worst(selective["state"],fid)+0.001>=_worst(idle["state"],fid),"selective support failed to improve/protect "+fid)
    var frozen=supported["outcome"].duplicate(true)
    var pressure_day=int(supported["state"]["regional_endgame"].get("pressure_applied_day",0))
    for day in range(122,182):
        FactionEconomy.daily_tick(supported["state"])
        RegionalEndgame.daily_tick(supported["state"],day)
    check(supported["state"]["regional_endgame"].get("outcome",{})==frozen,"60-day post-ending sandbox recalculated outcome")
    check(int(supported["state"]["regional_endgame"].get("pressure_applied_day",0))==pressure_day,"seasonal pressure resumed after ending")
    check(not bool(RegionalEndgame.can_start(supported["state"],182).get("ok",false)),"completed endgame became restartable during long sandbox")
    print("REGIONAL ENDGAME SOAK 1.26-dev5: ",checks," checks, ",failures," failures"," idle=",idle["outcome"].get("id","")," supported=",supported["outcome"].get("id","")," selective=",selective["outcome"].get("id",""))
    quit(1 if failures else 0)
