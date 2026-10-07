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
    route["opened_day"] = 45
    route["source_contract"] = template_id
    return route

func run() -> void:
    var game = Harness.new(); root.add_child(game)
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.current_chunk = Vector2i(0,0)
    game.region_map_center = Vector2i(0,0)
    game.discovered_chunks = {"0:0":true,"1:0":true,"0:1":true}
    game.discovered_pois = {"central_clinic":true}
    game._create_region_map_ui()

    game.region_map_selected_chunk = Vector2i(1,0)
    game._refresh_region_map_ui()
    var known_text = str(game.region_map_detail_label.text)
    check(known_text.find("Район: СТАРЫЙ ЦЕНТР") >= 0,"runtime district identity missing")
    check(known_text.find("Характер: Старая торгово-жилая") >= 0,"runtime authored district character missing")
    check(known_text.find("Обследовано секторов района: 3") >= 0,"runtime district survey progress missing")
    check(known_text.find("Известные ориентиры: ПОЛИКЛИНИКА") >= 0,"runtime known landmark summary missing")
    check(known_text.find("loot") < 0 and known_text.find("фарм") < 0 and known_text.find("refresh") < 0,"runtime survey text leaked hidden economy/farm metadata")

    game.region_map_selected_chunk = Vector2i(2,2)
    game._refresh_region_map_ui()
    var unknown_text = str(game.region_map_detail_label.text)
    check(unknown_text.find("НЕ ИССЛЕДОВАН") >= 0,"unknown sector lost exploration status")
    check(unknown_text.find("Район:") < 0 and unknown_text.find("Характер:") < 0 and unknown_text.find("Обследовано") < 0,"unknown sector leaked district survey context")

    # Established routes enrich only already-known district context and remain non-navigation data.
    game.faction_state["world_routes"]["route_perron_zarya"] = _route(game,"perron_zarya_route")
    game.discovered_pois["settlement_perron"] = true
    game.discovered_pois["dacha_coop_zarya"] = true
    game.discovered_chunks["-3:3"] = true
    game.region_map_selected_chunk = Vector2i(-3,3)
    game._refresh_region_map_ui()
    var route_text = str(game.region_map_detail_label.text)
    check(route_text.find("Налаженных связей района: 1") >= 0,"district context did not count established geographic link")
    check(route_text.find("Налаженный маршрут: ПЕРРОН ↔ СНТ «ЗАРЯ»") >= 0,"dev17 established route detail regressed")
    var snap = game._region_map_snapshot()
    check(not snap.has("target") and not snap.has("route"),"district survey context activated expedition navigation")

    game.queue_free(); await process_frame
    print("DISTRICT SURVEY CONTEXT RUNTIME 1.23-dev18: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
