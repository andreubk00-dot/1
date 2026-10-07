extends SceneTree

const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const TradingMarket = preload("res://world/trading_market.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const SandboxRouteConsequences = preload("res://world/sandbox_route_consequences.gd")

var checks := 0
var failures := 0

func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)

func _initialize() -> void:
    call_deferred("run")

func _open_route(state:Dictionary,route_id:String) -> void:
    var template_by_route = {
        "route_perron_zarya":"perron_zarya_route",
        "route_lazaret_hospital":"lazaret_hospital_route",
        "route_rubezh_police":"rubezh_police_route",
        "route_mechanics_depot":"mechanics_rail_depot"
    }
    var template_id = str(template_by_route.get(route_id,""))
    var route = ContractCatalog.template(template_id).get("reward",{}).get("route",{}).duplicate(true)
    route["state"] = "open"
    route["opened_day"] = 6
    route["source_contract"] = template_id
    state["world_routes"][route_id] = route

func _stock(state:Dictionary,trader_id:String,item_id:String) -> int:
    return TradingMarket.stock(state,trader_id,item_id)

func run() -> void:
    var specs = {
        "route_perron_zarya":{"faction":"perron","category":"food","other":"ammo","trader":"perron_canteen","item":"grain","factor":1.12,"resource":"food"},
        "route_lazaret_hospital":{"faction":"lazaret","category":"medicine","other":"parts","trader":"lazaret_supplier","item":"sterile_bandage","factor":1.12,"resource":"medicine"},
        "route_rubezh_police":{"faction":"rubezh","category":"ammo","other":"food","trader":"rubezh_armorer","item":"ammo_9x18","factor":1.10,"resource":"security"},
        "route_mechanics_depot":{"faction":"mechanics","category":"parts","other":"medicine","trader":"mechanics_parts","item":"scrap","factor":1.12,"resource":"technical"}
    }
    check(SandboxRouteConsequences.ROUTES.size() == 4,"dev15 must define exactly four starter-route consequence profiles")

    var notes = {}
    var news = {}
    for route_id in specs.keys():
        var spec:Dictionary = specs[route_id]
        var faction_id = str(spec["faction"])
        check(SandboxRouteConsequences.route_for_faction(faction_id) == route_id,route_id + " faction mapping drifted")
        var closed = FactionEconomy.default_state()
        check(not SandboxRouteConsequences.is_open(closed,route_id),route_id + " starts open")
        check(abs(SandboxRouteConsequences.restock_factor(closed,faction_id,"qa",str(spec["category"])) - 1.0) < 0.001,route_id + " boosts market before route opens")
        _open_route(closed,route_id)
        check(SandboxRouteConsequences.is_open(closed,route_id),route_id + " open state not detected")
        check(abs(SandboxRouteConsequences.restock_factor(closed,faction_id,"qa",str(spec["category"])) - float(spec["factor"])) < 0.001,route_id + " profile restock factor mismatch")
        check(abs(SandboxRouteConsequences.restock_factor(closed,faction_id,"qa",str(spec["other"])) - 1.0) < 0.001,route_id + " boosts unrelated categories")
        for other_faction in FactionCatalog.ids():
            if str(other_faction) != faction_id:
                check(abs(SandboxRouteConsequences.restock_factor(closed,str(other_faction),"qa",str(spec["category"])) - 1.0) < 0.001,route_id + " leaks restock effect into " + str(other_faction))

        var route_note = SandboxRouteConsequences.npc_note(closed,faction_id)
        var route_news = SandboxRouteConsequences.news_text(route_id)
        check(route_note.length() >= 40,route_id + " NPC consequence is too vague")
        check(route_news.length() >= 55,route_id + " radio consequence is too vague")
        notes[route_note] = true
        news[route_news] = true
        check(SandboxRouteConsequences.summary(closed,faction_id).find("маршрут:") == 0,route_id + " has no readable route summary")

        # Ongoing consequence: depleted matching stock returns more strongly after the route opens.
        var baseline = FactionEconomy.default_state()
        var routed = FactionEconomy.default_state()
        _open_route(routed,route_id)
        baseline["traders"][str(spec["trader"])]["stock"][str(spec["item"])] = 0
        routed["traders"][str(spec["trader"])]["stock"][str(spec["item"])] = 0
        check(TradingMarket.restock(baseline,str(spec["trader"]),20,true),route_id + " baseline restock failed")
        check(TradingMarket.restock(routed,str(spec["trader"]),20,true),route_id + " routed restock failed")
        check(_stock(routed,str(spec["trader"]),str(spec["item"])) > _stock(baseline,str(spec["trader"]),str(spec["item"])),route_id + " does not visibly improve matching trader restock")

        # Existing daily route economics still carry the deficit consequence; dev15 must not create a second resource grant system.
        var dry = FactionEconomy.default_state()
        var supplied = FactionEconomy.default_state()
        _open_route(supplied,route_id)
        var resource_id = str(spec["resource"])
        dry["factions"][faction_id]["resources"][resource_id] = 55.0
        supplied["factions"][faction_id]["resources"][resource_id] = 55.0
        for day in range(10):
            FactionEconomy.daily_tick(dry)
            FactionEconomy.daily_tick(supplied)
        check(float(supplied["factions"][faction_id]["resources"][resource_id]) > float(dry["factions"][faction_id]["resources"][resource_id]),route_id + " no longer improves its settlement deficit over time")

        # One-time opening package is real trader stock and is idempotent.
        var opening = FactionEconomy.default_state()
        _open_route(opening,route_id)
        var before_total = 0
        for row in SandboxRouteConsequences.route(route_id).get("opening_stock",[]):
            before_total += _stock(opening,str(row.get("trader","")),str(row.get("item","")))
        var first = SandboxRouteConsequences.apply_opening_stock(opening,route_id)
        check(bool(first.get("applied",false)) and int(first.get("added",0)) > 0,route_id + " opening trader package did not apply")
        var after_total = 0
        for row in SandboxRouteConsequences.route(route_id).get("opening_stock",[]):
            after_total += _stock(opening,str(row.get("trader","")),str(row.get("item","")))
        check(after_total - before_total == int(first.get("added",0)),route_id + " opening trader package added the wrong quantity")
        var second = SandboxRouteConsequences.apply_opening_stock(opening,route_id)
        check(not bool(second.get("applied",true)) and int(second.get("added",-1)) == 0,route_id + " opening trader package can be farmed twice")
        check(bool(opening["world_routes"][route_id].get("opening_stock_applied",false)),route_id + " did not persist its one-shot marker inside existing route state")

    check(notes.size() == 4,"route NPC consequences are not faction-distinct")
    check(news.size() == 4,"route radio consequences are not faction-distinct")

    # Migration: dev14 route records have no one-shot marker. Loading/sanitizing them must
    # activate derived ongoing consequences without gifting new stock or mutating the route.
    var legacy = FactionEconomy.default_state()
    _open_route(legacy,"route_perron_zarya")
    var legacy_stock = _stock(legacy,"perron_canteen","grain")
    var migrated = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(legacy)))
    check(SandboxRouteConsequences.is_open(migrated,"route_perron_zarya"),"dev14 open route was lost during schema-122 migration")
    check(_stock(migrated,"perron_canteen","grain") == legacy_stock,"dev14 migration gifted one-time route stock")
    check(not bool(migrated["world_routes"]["route_perron_zarya"].get("opening_stock_applied",false)),"dev14 migration forged opening-stock history")
    check(SandboxRouteConsequences.restock_factor(migrated,"perron","grain","food") > 1.0,"dev14 open route did not gain dev15 ongoing market consequence")

    print("SANDBOX ROUTE CONSEQUENCES 1.23-dev15: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
