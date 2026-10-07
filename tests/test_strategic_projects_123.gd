extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const SettlementProjects = preload("res://world/settlement_projects.gd")
const HighRiskMechanics = preload("res://world/high_risk_mechanics.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func near(a:float,b:float,eps:=0.001)->bool: return abs(a-b)<=eps
func _initialize(): call_deferred("run")

func _fund(state:Dictionary,faction_id:String,value:float=100.0):
    for r in SettlementProjects.RESOURCE_KEYS:
        state["factions"][faction_id]["resources"][r] = value

func _complete_project(state:Dictionary,faction_id:String,day:int=12):
    state["factions"][faction_id]["reputation"] = SettlementProjects.MIN_REPUTATION
    _fund(state,faction_id,100.0)
    var spec = SettlementProjects.project(faction_id)
    var install = SettlementProjects.install_strategic_item(state,faction_id,str(spec.get("strategic_item","")),day)
    check(bool(install.get("ok",false)),faction_id+" strategic install failed")
    var guard = 0
    while not SettlementProjects.is_completed(state,faction_id) and guard < 30:
        var res = SettlementProjects.commit_resources(state,faction_id,day)
        check(bool(res.get("ok",false)),faction_id+" bulk resource commit stalled before completion")
        guard += 1
    check(SettlementProjects.is_completed(state,faction_id),faction_id+" did not complete")

func run():
    check(SettlementProjects.ids().size()==4,"project roster must cover all four factions")
    check(SettlementProjects.strategic_item_ids().size()==4,"strategic item roster must contain four items")
    var unique_items = {}
    for faction_id in FactionCatalog.ids():
        var spec = SettlementProjects.project(str(faction_id))
        check(not spec.is_empty(),str(faction_id)+" missing local project")
        var item_id = str(spec.get("strategic_item",""))
        check(item_id != "",str(faction_id)+" missing strategic item")
        check(not unique_items.has(item_id),"strategic item reused: "+item_id)
        unique_items[item_id]=true
        check(FactionCatalog.item_category(item_id)=="strategic",item_id+" is trade-category loot instead of strategic")
        check(SettlementProjects.faction_for_item(item_id)==str(faction_id),item_id+" reverse faction mapping broken")
        for trader_id in TraderCatalog.ids():
            check(not TraderCatalog.accepts_item(str(trader_id),item_id),item_id+" can be accidentally sold to trader "+str(trader_id))
        var target_total:=0.0
        for r in SettlementProjects.RESOURCE_KEYS: target_total += float(spec.get("resource_targets",{}).get(r,0.0))
        check(target_total >= 55.0,str(faction_id)+" resource sink is too small to be strategic")
        check(float(spec.get("restock_factor",1.0)) > 1.0,str(faction_id)+" completed project has no restock benefit")

    # Every High Risk site owns exactly the intended one-off progression find.
    var site_items = {}
    for poi_id in HighRiskMechanics.SITE_IDS:
        var item = HighRiskMechanics.strategic_item(str(poi_id))
        check(item != "",str(poi_id)+" has no strategic find")
        check(unique_items.has(item),str(poi_id)+" points to unknown strategic item "+item)
        check(not site_items.has(item),"same strategic item assigned to multiple High Risk sites: "+item)
        site_items[item]=true

    var state = FactionEconomy.default_state()
    check(state.has("settlement_projects"),"default faction state lacks settlement project state")
    check(not SettlementProjects.has_access(state,"perron"),"projects accessible at zero reputation")
    var wrong = SettlementProjects.install_strategic_item(state,"perron","military_radio_station",5)
    check(not bool(wrong.get("ok",false)) and str(wrong.get("reason",""))=="reputation","wrong-item check bypassed reputation gate")
    state["factions"]["perron"]["reputation"] = 74
    check(not SettlementProjects.has_access(state,"perron"),"project unlocked below reputation threshold")
    state["factions"]["perron"]["reputation"] = 75
    check(SettlementProjects.has_access(state,"perron"),"project did not unlock at threshold")
    wrong = SettlementProjects.install_strategic_item(state,"perron","military_radio_station",5)
    check(not bool(wrong.get("ok",false)) and str(wrong.get("reason",""))=="wrong_item","project accepted another faction's node")

    # Reserve floor: project is a sink only for surplus logistics, never emergency stock.
    for r in SettlementProjects.RESOURCE_KEYS: state["factions"]["perron"]["resources"][r] = 45.0
    var blocked = SettlementProjects.commit_resources(state,"perron",5)
    check(not bool(blocked.get("ok",false)) and str(blocked.get("reason",""))=="reserve_floor","project drained emergency reserve")
    for r in SettlementProjects.RESOURCE_KEYS: state["factions"]["perron"]["resources"][r] = 50.0
    var before = state["factions"]["perron"]["resources"].duplicate(true)
    var first = SettlementProjects.commit_resources(state,"perron",5)
    check(bool(first.get("ok",false)),"project could not consume safe surplus")
    var spent:=0.0
    for r in SettlementProjects.RESOURCE_KEYS:
        var after = float(state["factions"]["perron"]["resources"][r])
        spent += float(before[r])-after
        check(after + 0.001 >= SettlementProjects.RESERVE_FLOOR,"bulk commit pushed "+r+" below reserve floor")
    check(spent <= SettlementProjects.COMMIT_BATCH+0.001,"single warehouse commit exceeded batch limit")

    # Complete all four projects and verify rewards are one-time and local.
    for faction_id in FactionCatalog.ids():
        var local = FactionEconomy.default_state()
        local["factions"][faction_id]["reputation"] = SettlementProjects.MIN_REPUTATION
        var rep_before = int(local["factions"][faction_id]["reputation"])
        _complete_project(local,str(faction_id),12)
        var spec = SettlementProjects.project(str(faction_id))
        var rec = SettlementProjects.record(local,str(faction_id))
        check(bool(rec.get("strategic_installed",false)),str(faction_id)+" completion lost installed strategic node")
        check(int(rec.get("completed_day",0))==12,str(faction_id)+" completion day incorrect")
        check(int(local["factions"][faction_id]["reputation"])==rep_before+int(spec.get("completion_reputation",0)),str(faction_id)+" completion reputation missing/duplicated")
        var profile_categories = spec.get("restock_categories",[])
        var matched_item = ""
        for candidate in TraderCatalog.BASE_VALUES.keys():
            if FactionCatalog.item_category(str(candidate)) in profile_categories:
                matched_item = str(candidate)
                break
        check(matched_item != "",str(faction_id)+" project restock profile matches no real trade item")
        if matched_item != "":
            check(near(SettlementProjects.restock_factor(local,str(faction_id),matched_item),float(spec.get("restock_factor",1.0))),str(faction_id)+" completed project restock factor not applied")
        var repeat = SettlementProjects.commit_resources(local,str(faction_id),13)
        check(not bool(repeat.get("ok",false)) and str(repeat.get("reason",""))=="completed",str(faction_id)+" completed sink still consumes resources")
        var daily = spec.get("daily_resources",{})
        var before_daily = local["factions"][faction_id]["resources"].duplicate(true)
        SettlementProjects.apply_daily_effects(local)
        for r in daily.keys():
            check(near(float(local["factions"][faction_id]["resources"][r]),min(100.0,float(before_daily[r])+float(daily[r])),0.002),str(faction_id)+" daily project bonus incorrect for "+str(r))

    # Sanitizer clamps impossible progress and never trusts a forged completed bit.
    var dirty = {"records":{"perron":{"strategic_installed":false,"resources":{"food":9999.0,"technical":-5.0},"completed":true,"completed_day":999}}}
    var clean = SettlementProjects.sanitize_state(dirty)
    var cr = clean["records"]["perron"]
    check(not bool(cr.get("completed",false)),"sanitizer trusted impossible completed project")
    check(near(float(cr["resources"]["food"]),34.0),"sanitizer failed to clamp project over-progress")
    check(near(float(cr["resources"]["technical"]),0.0),"sanitizer failed to clamp negative project progress")
    check(int(cr.get("completed_day",0))==0,"sanitizer retained completion day for incomplete project")

    print("STRATEGIC PROJECTS 1.23-dev6: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
