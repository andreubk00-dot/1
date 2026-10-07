extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _route(game,template_id:String) -> Dictionary:
    var route = game.ContractCatalog.template(template_id).get("reward",{}).get("route",{}).duplicate(true)
    route["state"] = "open"
    route["opened_day"] = 21
    route["source_contract"] = template_id
    return route

func run() -> void:
    var game = Harness.new(); root.add_child(game)
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.current_chunk = Vector2i(-8,6)
    game.region_map_center = Vector2i(-5,4)
    game.discovered_pois = {"settlement_perron":true,"dacha_coop_zarya":true}
    game.discovered_chunks = {"-8:6":true,"-3:3":true}
    game.faction_state["world_routes"]["route_perron_zarya"] = _route(game,"perron_zarya_route")
    game._create_region_map_ui()

    var snap = game._region_map_snapshot()
    check(snap.get("established_routes",[]).size() == 1,"runtime map snapshot does not include open known route")
    check(not snap.has("route"),"established route incorrectly activates expedition navigation")
    check(not snap.has("target"),"established route incorrectly creates a navigation target")

    game.region_map_selected_chunk = Vector2i(-3,3)
    game._refresh_region_map_ui()
    check(str(game.region_map_location_label.text).find("ЗАРЯ") >= 0,"route target selection lost discovered POI identity")
    check(str(game.region_map_detail_label.text).find("Налаженный маршрут: ПЕРРОН ↔ СНТ «ЗАРЯ»") >= 0,"target detail does not explain established route")

    game.region_map_selected_chunk = Vector2i(-8,6)
    game._refresh_region_map_ui()
    check(str(game.region_map_detail_label.text).find("Налаженный маршрут: ПЕРРОН ↔ СНТ «ЗАРЯ»") >= 0,"source settlement detail does not explain established route")

    # Active expedition route and persistent logistics link must coexist as separate layers.
    game.expedition_journal["home"] = {"key":"qa","name":"QA HOME","chunk":[-8,6],"position":[0.0,0.0]}
    game.expedition_active = true
    game.expedition_target_chunk = Vector2i(-3,3)
    game.expedition_target_name = "СНТ «ЗАРЯ»"
    var active = game._region_map_snapshot()
    check(active.get("established_routes",[]).size() == 1,"active expedition hid persistent route network")
    check(active.get("route",[]).size() > 1,"active expedition route disappeared after established-route integration")
    check(active.get("target",Vector2i(999,999)) == Vector2i(-3,3),"persistent route changed active navigation target")

    # Discovery-first: corrupt/legacy knowledge cannot reveal a missing endpoint.
    game.discovered_pois.erase("dacha_coop_zarya")
    var hidden = game._region_map_snapshot()
    check(not hidden.has("established_routes") or hidden.get("established_routes",[]).is_empty(),"runtime map reveals undiscovered route target")

    game.queue_free(); await process_frame
    print("ESTABLISHED ROUTE MAP RUNTIME 1.23-dev17: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
