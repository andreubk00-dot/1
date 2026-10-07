extends SceneTree
const FactionCatalog=preload("res://world/faction_catalog.gd")
const FactionEconomy=preload("res://world/faction_economy.gd")
const SettlementProjects=preload("res://world/settlement_projects.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String):
    checks+=1
    if not ok:
        failures+=1; printerr("FAIL: ",msg)
func _initialize(): call_deferred("run")
func _complete(state:Dictionary,faction_id:String):
    state["factions"][faction_id]["reputation"]=75
    for r in SettlementProjects.RESOURCE_KEYS: state["factions"][faction_id]["resources"][r]=100.0
    var spec=SettlementProjects.project(faction_id)
    SettlementProjects.install_strategic_item(state,faction_id,str(spec.get("strategic_item","")),1)
    var guard=0
    while not SettlementProjects.is_completed(state,faction_id) and guard<30:
        SettlementProjects.commit_resources(state,faction_id,1)
        guard+=1
func run():
    var state=FactionEconomy.default_state()
    for faction_id in FactionCatalog.ids():
        _complete(state,str(faction_id))
        check(SettlementProjects.is_completed(state,str(faction_id)),str(faction_id)+" soak fixture incomplete")
    var baseline_rep={}
    for faction_id in FactionCatalog.ids(): baseline_rep[faction_id]=int(state["factions"][faction_id]["reputation"])
    for day in range(1,181):
        FactionEconomy.daily_tick(state)
        if day in [30,60,180]:
            for faction_id in FactionCatalog.ids():
                var rec=SettlementProjects.record(state,str(faction_id))
                check(bool(rec.get("completed",false)),"completed project reset by day "+str(day)+": "+str(faction_id))
                check(int(state["factions"][faction_id]["reputation"])==int(baseline_rep[faction_id]),"daily project effect duplicated reputation by day "+str(day)+": "+str(faction_id))
                for r in SettlementProjects.RESOURCE_KEYS:
                    var v=float(state["factions"][faction_id]["resources"][r])
                    check(v>=0.0 and v<=100.0,"resource escaped bounds at day "+str(day)+": "+str(faction_id)+"/"+r)
            # Serialization-style sanitize during a long world must not alter project completion.
            state=FactionEconomy.sanitize_state(state)
            for faction_id in FactionCatalog.ids(): check(SettlementProjects.is_completed(state,str(faction_id)),"sanitize reset project at day "+str(day)+": "+str(faction_id))

    # No resource-loop exploit: project completion is terminal and cannot repeatedly consume/reward.
    for faction_id in FactionCatalog.ids():
        var resources_before=state["factions"][faction_id]["resources"].duplicate(true)
        var rep_before=int(state["factions"][faction_id]["reputation"])
        for i in range(20):
            var result=SettlementProjects.commit_resources(state,str(faction_id),181)
            check(not bool(result.get("ok",false)) and str(result.get("reason",""))=="completed",str(faction_id)+" completed sink reopened on repeat commit")
        check(state["factions"][faction_id]["resources"]==resources_before,str(faction_id)+" repeated completed commits changed stock")
        check(int(state["factions"][faction_id]["reputation"])==rep_before,str(faction_id)+" repeated completed commits changed reputation")

    # An unfinished project parked at the protected floor cannot bootstrap itself from emergency self-supply.
    var blocked=FactionEconomy.default_state()
    blocked["factions"]["perron"]["reputation"]=75
    for r in SettlementProjects.RESOURCE_KEYS: blocked["factions"]["perron"]["resources"][r]=45.0
    var total_before=float(SettlementProjects.record(blocked,"perron").get("total_committed",0.0))
    for day in range(90):
        FactionEconomy.daily_tick(blocked)
        SettlementProjects.commit_resources(blocked,"perron",day+1)
    var total_after=float(SettlementProjects.record(blocked,"perron").get("total_committed",0.0))
    check(total_after<=total_before+0.001,"emergency self-supply funded project progress from protected reserve")
    check(not SettlementProjects.is_completed(blocked,"perron"),"protected-reserve project completed itself without player logistics")

    print("STRATEGIC PROJECTS SOAK 1.23-dev6: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
