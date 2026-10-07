extends SceneTree

const FactionEconomy = preload("res://world/faction_economy.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const RouteMap = preload("res://world/sandbox_route_map.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _open(state:Dictionary,template_id:String,with_source:bool = true) -> String:
    var template = ContractCatalog.template(template_id)
    var route = template.get("reward",{}).get("route",{}).duplicate(true)
    var route_id = str(route.get("id",""))
    route["state"] = "open"
    route["opened_day"] = 12
    if with_source:
        route["source_contract"] = template_id
    state["world_routes"][route_id] = route
    return route_id

func run() -> void:
    var state = FactionEconomy.default_state()
    check(RouteMap.links(state,{}).is_empty(),"empty sandbox fabricated established map routes")

    var route_id = _open(state,"perron_zarya_route")
    var hidden = RouteMap.links(state,{"settlement_perron":true})
    check(hidden.is_empty(),"route map revealed an undiscovered target POI")
    var known = {"settlement_perron":true,"dacha_coop_zarya":true}
    var links = RouteMap.links(state,known)
    check(links.size() == 1,"known Perron route did not project exactly one map link")
    if not links.is_empty():
        var link = links[0]
        check(str(link.get("route_id","")) == route_id,"route id drifted in map projection")
        check(link.get("from",Vector2i.ZERO) == Vector2i(-8,6),"Perron map source coordinate drifted")
        check(link.get("to",Vector2i.ZERO) == Vector2i(-3,3),"Zarya map target coordinate drifted")
        check(str(link.get("label","")) == "ПЕРРОН ↔ СНТ «ЗАРЯ»","Perron map label leaks or drifts")
        for forbidden in ["daily_resources","resources","loot","risk","refresh_days","restock"]:
            check(not link.has(forbidden),"map projection leaked gameplay/economy field: " + forbidden)
        check(RouteMap.labels_at_coord(links,Vector2i(-8,6)).size() == 1,"source endpoint lost route detail label")
        check(RouteMap.labels_at_coord(links,Vector2i(-3,3)).size() == 1,"target endpoint lost route detail label")
        check(RouteMap.labels_at_coord(links,Vector2i(-2,3)).is_empty(),"map implies an authored intermediate path where none exists")

    # Dev14/dev15-style records may lack source_contract; route-id lookup must recover presentation only.
    var legacy = FactionEconomy.default_state()
    _open(legacy,"lazaret_hospital_route",false)
    var legacy_links = RouteMap.links(legacy,{"settlement_lazaret":true,"district_hospital":true})
    check(legacy_links.size() == 1,"legacy open hospital route cannot be projected without source_contract")
    if not legacy_links.is_empty():
        check(str(legacy_links[0].get("template_id","")) == "lazaret_hospital_route","legacy route-id fallback resolved wrong contract")
        check(legacy_links[0].get("from",Vector2i.ZERO) == Vector2i(-8,-2),"Lazaret map source coordinate drifted")
        check(legacy_links[0].get("to",Vector2i.ZERO) == Vector2i(2,0),"district hospital map target coordinate drifted")

    # Four starter reconnaissance routes remain four distinct geographic links.
    var mature = FactionEconomy.default_state()
    var all_known = {}
    for template_id in ["perron_zarya_route","lazaret_hospital_route","rubezh_police_route","mechanics_rail_depot"]:
        var template = ContractCatalog.template(template_id)
        _open(mature,template_id)
        var faction_id = str(template.get("faction",""))
        var settlement = {"perron":"settlement_perron","lazaret":"settlement_lazaret","rubezh":"settlement_rubezh","mechanics":"settlement_mechanics"}.get(faction_id,"")
        all_known[settlement] = true
        all_known[str(template.get("poi_id",""))] = true
    var starter_links = RouteMap.links(mature,all_known)
    check(starter_links.size() == 4,"four starter routes do not produce four map links")
    _open(mature,"mechanics_storekeeper_depot_run")
    check(RouteMap.links(mature,all_known).size() == 4,"duplicate physical depot connection is drawn twice after personal route improvement")
    var ids = []
    for link in starter_links: ids.append(str(link.get("route_id","")))
    ids.sort()
    check(ids == ["route_lazaret_hospital","route_mechanics_depot","route_perron_zarya","route_rubezh_police"],"starter route map set drifted")

    # A precise later reconnaissance route is geographic too.
    var later = FactionEconomy.default_state()
    _open(later,"rubezh_east_checkpoint")
    var later_links = RouteMap.links(later,{"settlement_rubezh":true,"military_checkpoint":true})
    check(later_links.size() == 1 and later_links[0].get("to",Vector2i.ZERO) == Vector2i(4,-3),"later POI-backed route is missing from route map")

    # Final network routes are abstract logistics decisions; no fake line is authored for them.
    var abstract_state = FactionEconomy.default_state()
    _open(abstract_state,"perron_endgame_civilian_exchange")
    check(RouteMap.links(abstract_state,null).is_empty(),"abstract final network fabricated a geographic map line")

    var closed = FactionEconomy.default_state()
    var closed_id = _open(closed,"mechanics_rail_depot")
    closed["world_routes"][closed_id]["state"] = "closed"
    check(RouteMap.links(closed,null).is_empty(),"non-open route remains visible on map")

    print("ESTABLISHED ROUTE MAP 1.23-dev17: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
