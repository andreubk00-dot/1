extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const RegionalEndgame = preload("res://world/regional_endgame.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func _profile(category:String)->Dictionary:
    match category:
        "secure": return {"final":70.0,"minimum":60.0,"hardship":0}
        "strained": return {"final":45.0,"minimum":40.0,"hardship":4}
        "scarred": return {"final":30.0,"minimum":25.0,"hardship":10}
        "critical": return {"final":15.0,"minimum":10.0,"hardship":18}
    return {"final":15.0,"minimum":10.0,"hardship":18}
func _complete_state(categories:Dictionary)->Dictionary:
    var state=FactionEconomy.default_state()
    var hardship={}
    var minima={}
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id)
        var profile=_profile(str(categories.get(fid,"secure")))
        hardship[fid]=int(profile["hardship"])
        minima[fid]={}
        for resource_id in RegionalEndgame.RESOURCE_KEYS:
            var rid=str(resource_id)
            state["factions"][fid]["resources"][rid]=float(profile["final"])
            minima[fid][rid]=float(profile["minimum"])
    state["regional_endgame"]={
        "phase":RegionalEndgame.PHASE_COMPLETE,"started_day":50,"ends_day":71,"last_tick_day":71,"completion_day":71,
        "pressure_applied_day":71,"checkpoints":[7,14],"hardship_days":hardship,"resource_minima":minima,"outcome":{},
        "history":[{"day":50,"event":"started"},{"day":71,"event":"completed"}]
    }
    state["supply_events"]["history"]=[]
    return state
func _id(categories:Dictionary)->String:
    var state=_complete_state(categories)
    return str(RegionalEndgame.resolve_outcome(state,100).get("id",""))
func run()->void:
    check(_id({})=="cohesive","all-secure scenario did not produce cohesive outcome")
    check(_id({"perron":"strained","rubezh":"strained"})=="holding_network","strained but intact network did not produce holding_network")
    check(_id({"mechanics":"scarred"})=="fragile_balance","scarred/no-critical scenario did not produce fragile_balance")
    check(_id({"lazaret":"critical"})=="fractured_region","one critical settlement did not produce fractured_region")
    check(_id({"perron":"critical","rubezh":"critical","mechanics":"critical"})=="survival_islands","three critical settlements did not produce survival_islands")

    var supply_state=_complete_state({"perron":"strained"})
    supply_state["supply_events"]["history"]=[
        {"faction":"perron","closed_day":49,"outcome":"lost"},
        {"faction":"perron","closed_day":51,"outcome":"recovered"},
        {"faction":"perron","closed_day":60,"outcome":"recovered"},
        {"faction":"perron","closed_day":72,"outcome":"lost"}
    ]
    var supply_outcome=RegionalEndgame.resolve_outcome(supply_state,99)
    var perron=supply_outcome.get("factions",{}).get("perron",{})
    check(str(perron.get("category",""))=="secure","two in-season recovered supply runs did not improve strained Perron")
    check(int(perron.get("supply_recovered",0))==2 and int(perron.get("supply_lost",0))==0,"supply outcome counted events outside the 21-day season")
    check(int(supply_outcome.get("resolved_day",0))==71,"migrated/late outcome used current day instead of completion day")

    # Completion deliberately defers the snapshot until production same-day supply recovery has run.
    var final_day=_complete_state({})
    final_day["regional_endgame"]["phase"]=RegionalEndgame.PHASE_ACTIVE
    final_day["regional_endgame"]["completion_day"]=0
    final_day["regional_endgame"]["pressure_applied_day"]=70
    final_day["regional_endgame"]["last_tick_day"]=70
    final_day["regional_endgame"]["outcome"]={}
    var completion=RegionalEndgame.daily_tick(final_day,71)
    check(bool(completion.get("completed",false)) and completion.get("outcome",{}).is_empty(),"completion tick froze outcome before final-day recovery window")
    final_day["supply_events"]["history"].append({"faction":"lazaret","closed_day":71,"outcome":"recovered"})
    var after_recovery=RegionalEndgame.resolve_outcome(final_day,71)
    check(int(after_recovery.get("factions",{}).get("lazaret",{}).get("supply_recovered",0))==1,"final-day recovered supply run was omitted from consequence snapshot")

    var frozen_state=_complete_state({})
    var first=RegionalEndgame.resolve_outcome(frozen_state,71)
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id)
        for resource_id in RegionalEndgame.RESOURCE_KEYS:
            frozen_state["factions"][fid]["resources"][str(resource_id)]=0.0
        frozen_state["regional_endgame"]["hardship_days"][fid]=21
    frozen_state["supply_events"]["history"].append({"faction":"perron","closed_day":60,"outcome":"lost"})
    frozen_state["supply_events"]["history"].append({"faction":"perron","closed_day":61,"outcome":"lost"})
    var second=RegionalEndgame.resolve_outcome(frozen_state,365)
    check(second==first,"resolved regional outcome changed during post-season sandbox")
    print("REGIONAL CONSEQUENCE ENDING 1.26-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
