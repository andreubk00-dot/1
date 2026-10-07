extends SceneTree
const Main = preload("res://main_script_mod.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _open_all(game,state:Dictionary) -> void:
    for template_id in ["perron_zarya_route","lazaret_hospital_route","rubezh_police_route","mechanics_rail_depot"]:
        var route = game.ContractCatalog.template(template_id).get("reward",{}).get("route",{}).duplicate(true)
        route["state"] = "open"; route["opened_day"] = 20; route["source_contract"] = template_id
        state["world_routes"][str(route.get("id",""))] = route

func _develop_all(game,state:Dictionary) -> void:
    game.SettlementProjects.ensure_state(state)
    game.FactionEndgame.ensure_state(state)
    for faction_id in game.FactionCatalog.ids():
        var fid = str(faction_id)
        var project = game.SettlementProjects.project(fid)
        var rec = game.SettlementProjects.default_record()
        rec["strategic_installed"] = true; rec["installed_day"] = 20
        rec["resources"] = project.get("resource_targets",{}).duplicate(true)
        rec["completed"] = true; rec["completed_day"] = 20
        state["settlement_projects"]["records"][fid] = rec
        var chain = game.FactionEndgame.chain(fid)
        var templates = chain.get("templates",[])
        state["faction_endgame"]["chains"][fid] = {"progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":20}
        state["faction_endgame"]["effects"][str(chain.get("effect",""))] = true
    game.SettlementProjects.ensure_state(state)
    game.FactionEndgame.ensure_state(state)

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null: quit(1); return
    var game = packed.instantiate(); root.add_child(game)
    await process_frame; await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.world_day = 20; game.world_minutes = 720.0
    _open_all(game,game.faction_state); _develop_all(game,game.faction_state)
    for faction_id in game.FactionCatalog.ids():
        game.faction_state["factions"][str(faction_id)]["reputation"] = 250
        for resource_id in game.FactionEconomy.RESOURCE_KEYS:
            game.faction_state["factions"][str(faction_id)]["resources"][str(resource_id)] = 100.0

    var tech_before = float(game.faction_state["factions"]["mechanics"]["resources"]["technical"])
    game._process_world_day_rollovers(20,21)
    var tech_after = float(game.faction_state["factions"]["mechanics"]["resources"]["technical"])
    check(tech_before == 100.0 and tech_after < 100.0,"real main rollover still passively repins Mechanics technical to 100")
    check(game.TradingMarket.stock(game.faction_state,"mechanics_parts","scrap") > 0,"real rollover broke trader restocking")

    game._process_world_day_rollovers(21,70)
    check(float(game.faction_state["factions"]["mechanics"]["resources"]["technical"]) <= game.FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING + 0.001,"real multi-day rollover does not converge under passive ceiling")
    check(float(game.faction_state["factions"]["lazaret"]["resources"]["medicine"]) <= game.FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING + 0.001,"real multi-day Lazaret rollover does not converge under passive ceiling")
    check(game.SandboxRouteConsequences.is_open(game.faction_state,"route_mechanics_depot"),"main rollover closed a persistent starter route")
    check(game.SettlementProjects.is_completed(game.faction_state,"mechanics"),"main rollover lost completed settlement project")
    check(game.FactionEndgame.faction_effect_active(game.faction_state,"mechanics"),"main rollover lost endgame effect")

    game._update_hud()
    check(game.hud_feedback_panel != null,"dev16 runtime lost existing HUD feedback panel")

    game.queue_free(); await process_frame; await process_frame
    print("MULTI-ROUTE ECONOMY RUNTIME 1.23-dev16: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
