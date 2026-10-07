extends SceneTree

const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const SettlementProjects = preload("res://world/settlement_projects.gd")
const SupplyEventSystem = preload("res://world/supply_event_system.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const SandboxRouteConsequences = preload("res://world/sandbox_route_consequences.gd")
const TradingMarket = preload("res://world/trading_market.gd")

var checks := 0
var failures := 0

func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)

func _initialize() -> void:
    call_deferred("run")

func _open_all_routes(state:Dictionary) -> void:
    var templates = ["perron_zarya_route","lazaret_hospital_route","rubezh_police_route","mechanics_rail_depot"]
    for template_id in templates:
        var route = ContractCatalog.template(template_id).get("reward",{}).get("route",{}).duplicate(true)
        route["state"] = "open"
        route["opened_day"] = 8
        route["source_contract"] = template_id
        state["world_routes"][str(route.get("id",""))] = route

func _activate_projects(state:Dictionary) -> void:
    SettlementProjects.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var spec = SettlementProjects.project(str(faction_id))
        var rec = SettlementProjects.default_record()
        rec["strategic_installed"] = true
        rec["installed_day"] = 8
        rec["resources"] = spec.get("resource_targets",{}).duplicate(true)
        rec["completed"] = true
        rec["completed_day"] = 8
        state["settlement_projects"]["records"][str(faction_id)] = rec
    SettlementProjects.ensure_state(state)

func _activate_endgame(state:Dictionary) -> void:
    FactionEndgame.ensure_state(state)
    for faction_id in FactionCatalog.ids():
        var spec = FactionEndgame.chain(str(faction_id))
        var templates = spec.get("templates",[])
        state["faction_endgame"]["chains"][str(faction_id)] = {
            "progress":templates.size(),"completed":templates.duplicate(),"finalized":true,"final_day":8
        }
        state["faction_endgame"]["effects"][str(spec.get("effect",""))] = true
    FactionEndgame.ensure_state(state)

func _force_supply_event(state:Dictionary,day:int = 4) -> Dictionary:
    SupplyEventSystem.ensure_state(state,1)
    state["supply_events"]["active"] = {}
    state["supply_events"]["next_event_day"] = day
    return SupplyEventSystem.daily_tick(state,day).get("event",{})

func run() -> void:
    check(abs(FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING - 92.0) < 0.001,"dev16 passive logistics ceiling drifted")

    # Below the guardrail, the original route contribution stays intact rather than being nerfed.
    var dry = FactionEconomy.default_state()
    var routed = FactionEconomy.default_state()
    var route = ContractCatalog.template("mechanics_rail_depot").get("reward",{}).get("route",{}).duplicate(true)
    route["state"] = "open"; route["opened_day"] = 8; route["source_contract"] = "mechanics_rail_depot"
    routed["world_routes"]["route_mechanics_depot"] = route
    dry["factions"]["mechanics"]["resources"]["technical"] = 60.0
    routed["factions"]["mechanics"]["resources"]["technical"] = 60.0
    FactionEconomy.daily_tick(dry)
    FactionEconomy.daily_tick(routed)
    var delta = float(routed["factions"]["mechanics"]["resources"]["technical"]) - float(dry["factions"]["mechanics"]["resources"]["technical"])
    check(delta > 0.45 and delta < 0.56,"starter route contribution changed below the dev16 ceiling")

    # Fully developed passive infrastructure must no longer refill ordinary decay back to 100.
    var stacked = FactionEconomy.default_state()
    _open_all_routes(stacked); _activate_projects(stacked); _activate_endgame(stacked)
    for faction_id in FactionCatalog.ids():
        for resource_id in FactionEconomy.RESOURCE_KEYS:
            stacked["factions"][str(faction_id)]["resources"][str(resource_id)] = 100.0
    FactionEconomy.daily_tick(stacked)
    check(float(stacked["factions"]["rubezh"]["resources"]["security"]) < 100.0,"stacked Rubezh security still pins to 100 after daily decay")
    check(float(stacked["factions"]["mechanics"]["resources"]["technical"]) < 100.0,"stacked Mechanics technical still pins to 100 after daily decay")
    check(float(stacked["factions"]["lazaret"]["resources"]["medicine"]) < 100.0,"stacked Lazaret medicine still pins to 100 after daily decay")

    for day in range(40):
        FactionEconomy.daily_tick(stacked)
    check(float(stacked["factions"]["rubezh"]["resources"]["security"]) <= FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING + 0.001,"Rubezh passive stack does not settle under the ceiling")
    check(float(stacked["factions"]["mechanics"]["resources"]["technical"]) <= FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING + 0.001,"Mechanics passive stack does not settle under the ceiling")
    check(float(stacked["factions"]["lazaret"]["resources"]["medicine"]) <= FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING + 0.001,"Lazaret passive stack does not settle under the ceiling")

    # Emergency self-supply remains a separate low-resource guardrail and still works.
    var emergency = FactionEconomy.default_state()
    emergency["factions"]["perron"]["resources"]["food"] = 10.0
    FactionEconomy.daily_tick(emergency)
    check(float(emergency["factions"]["perron"]["resources"]["food"]) > 8.6,"emergency recovery was accidentally capped with passive logistics")

    # Direct supply recovery remains able to reach the real 100 cap.
    var rescued = FactionEconomy.default_state()
    var event = _force_supply_event(rescued,4)
    check(not event.is_empty(),"supply recovery fixture could not create an event")
    if not event.is_empty():
        var faction_id = str(event.get("faction",""))
        var resource_id = str(event.get("cargo_resource",""))
        rescued["factions"][faction_id]["resources"][resource_id] = 99.0
        var result = SupplyEventSystem.resolve_success(rescued,str(event.get("id","")),4)
        check(bool(result.get("ok",false)),"supply event recovery failed in dev16 fixture")
        check(abs(float(rescued["factions"][faction_id]["resources"][resource_id]) - 100.0) < 0.001,"direct supply recovery was incorrectly limited by passive ceiling")

    # Legitimate player deliveries through trading are direct supply too. They may cross 92;
    # only a later passive daily refill is guarded.
    var sold = FactionEconomy.default_state()
    sold["factions"]["mechanics"]["resources"]["technical"] = 91.5
    sold["traders"]["mechanics_parts"]["ticket_reserve"] = 5000
    var sale = TradingMarket.sell_quote(sold,"mechanics_parts","scrap",10)
    check(bool(sale.get("ok",false)),"direct trader delivery fixture cannot produce a sale quote")
    if bool(sale.get("ok",false)):
        check(TradingMarket.apply_sale(sold,"mechanics_parts","scrap",10,int(sale.get("total",0))),"direct trader delivery failed")
        check(float(sold["factions"]["mechanics"]["resources"]["technical"]) > FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING,"trader delivery was incorrectly limited by passive ceiling")

    # Restock multipliers remain multiplicative and unchanged; dev16 only guards daily resources.
    var market = FactionEconomy.default_state()
    _open_all_routes(market); _activate_projects(market); _activate_endgame(market)
    check(abs(SandboxRouteConsequences.restock_factor(market,"mechanics","scrap","parts") - 1.12) < 0.001,"dev15 depot restock factor changed")
    check(abs(SettlementProjects.restock_factor(market,"mechanics","scrap") - 1.06) < 0.001,"project restock factor changed")
    check(abs(FactionEndgame.restock_factor(market,"mechanics","scrap") - 1.25) < 0.001,"endgame restock factor changed")

    var route_only = FactionEconomy.default_state()
    _open_all_routes(route_only)
    route_only["factions"]["mechanics"]["resources"]["technical"] = 92.0
    route_only["traders"]["mechanics_parts"]["stock"]["scrap"] = 0
    TradingMarket.restock(route_only,"mechanics_parts",20,true)
    var route_stock = TradingMarket.stock(route_only,"mechanics_parts","scrap")

    var route_project = FactionEconomy.default_state()
    _open_all_routes(route_project); _activate_projects(route_project)
    route_project["factions"]["mechanics"]["resources"]["technical"] = 92.0
    route_project["traders"]["mechanics_parts"]["stock"]["scrap"] = 0
    TradingMarket.restock(route_project,"mechanics_parts",20,true)
    var project_stock = TradingMarket.stock(route_project,"mechanics_parts","scrap")

    market["factions"]["mechanics"]["resources"]["technical"] = 92.0
    market["traders"]["mechanics_parts"]["stock"]["scrap"] = 0
    TradingMarket.restock(market,"mechanics_parts",20,true)
    var full_stock = TradingMarket.stock(market,"mechanics_parts","scrap")
    check(project_stock > route_stock,"route x project 1.06 no longer compounds in real restock target")
    check(full_stock > project_stock,"endgame restock effect no longer compounds with route + project")

    # Schema-122 migration remains derived: no new persistence field is required.
    var legacy = FactionEconomy.default_state()
    _open_all_routes(legacy)
    var migrated = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(legacy)))
    check(not migrated.has("passive_logistics"),"dev16 introduced a new persisted logistics subsystem")
    check(SandboxRouteConsequences.is_open(migrated,"route_perron_zarya"),"dev15 open route was lost during dev16 sanitize")
    check(not bool(migrated["world_routes"]["route_perron_zarya"].get("opening_stock_applied",false)),"dev16 migration fabricated dev15 one-shot opening stock history")

    print("MULTI-ROUTE ECONOMY SYSTEM 1.23-dev16: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
