extends SceneTree

const FactionEconomy = preload("res://world/faction_economy.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const SandboxRouteMap = preload("res://world/sandbox_route_map.gd")
const RegionSurveyContext = preload("res://world/region_survey_context.gd")
const RegionMapView = preload("res://world/region_map_view.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _open(state:Dictionary,template_id:String) -> void:
    var template = ContractCatalog.template(template_id)
    var route = template.get("reward",{}).get("route",{}).duplicate(true)
    var route_id = str(route.get("id",""))
    route["state"] = "open"
    route["opened_day"] = 44
    route["source_contract"] = template_id
    state["world_routes"][route_id] = route

func run() -> void:
    check(str(RegionMapView.SHORT_NAMES.get("outer_residential","")) == "ОКРАИНЫ","outer residential district lacks map identity label")
    check(str(RegionMapView.SHORT_NAMES.get("outer_industrial","")) == "ПРОМ. ОКРАИНА","outer industrial district lacks map identity label")
    check(str(RegionMapView.SHORT_NAMES.get("outer_rural","")) == "ПРИГОРОД","outer rural district lacks map identity label")
    check(str(RegionMapView.SHORT_NAMES.get("outer_woodland","")) == "ЛЕСНАЯ ОКРАИНА","outer woodland district lacks map identity label")

    var old_center_chunks = {"0:0":true,"1:0":true,"0:1":true,"-1:0":false,"bad-key":true}
    var unknown = RegionSurveyContext.context_for_coord(Vector2i(2,2),old_center_chunks,{"central_clinic":true})
    check(unknown.is_empty(),"unknown sector leaked district survey identity")

    var center = RegionSurveyContext.context_for_coord(Vector2i(0,0),old_center_chunks,{"central_clinic":true})
    check(str(center.get("district_id","")) == "old_center","old-center survey resolved wrong district")
    check(str(center.get("name","")) == "СТАРЫЙ ЦЕНТР","district display identity drifted")
    check(str(center.get("description","")).find("Старая торгово-жилая") >= 0,"district authored character missing")
    check(int(center.get("known_sectors",0)) == 3,"survey counted unknown/false/malformed chunk as explored")
    check(center.get("known_landmarks",[]) == ["ПОЛИКЛИНИКА"],"survey does not limit landmarks to discovered POIs")
    check(int(center.get("established_links",-1)) == 0,"empty route network fabricated district links")
    for forbidden in ["loot","loot_theme","building_set","enemy_mult","tree_mult","car_mult","density","refresh_days","farm_profile","total_pois"]:
        check(not center.has(forbidden),"survey context leaked hidden gameplay field: " + forbidden)

    # Lazaret sits in a procedural outer-rural macrocell, but its discovered authored
    # POI identity is outer-residential. The override must happen only after discovery.
    var settlement_known = RegionSurveyContext.context_for_coord(Vector2i(-8,-2),{"-8:-2":true},{"settlement_lazaret":true})
    check(str(settlement_known.get("district_id","")) == "outer_residential","discovered Lazaret did not use authored POI district identity")
    var settlement_hidden = RegionSurveyContext.context_for_coord(Vector2i(-8,-2),{"-8:-2":true},{})
    check(str(settlement_hidden.get("district_id","")) == "outer_rural","unknown Lazaret POI leaked authored district identity")

    var state = FactionEconomy.default_state()
    _open(state,"perron_zarya_route")
    var known_pois = {"settlement_perron":true,"dacha_coop_zarya":true}
    var links = SandboxRouteMap.links(state,known_pois)
    var dacha = RegionSurveyContext.context_for_coord(Vector2i(-3,3),{"-3:3":true,"-4:3":true},known_pois,links)
    check(str(dacha.get("district_id","")) == "dacha_west","dacha route endpoint resolved wrong district identity")
    check(int(dacha.get("known_sectors",0)) == 2,"dacha survey progress drifted")
    check(dacha.get("known_landmarks",[]) == ["СНТ «ЗАРЯ»"],"dacha survey landmark identity drifted")
    check(int(dacha.get("established_links",0)) == 1,"known established route not counted in district survey")
    check(RegionSurveyContext.landmark_text(dacha) == "СНТ «ЗАРЯ»","landmark summary text drifted")

    var hidden_landmark = RegionSurveyContext.context_for_coord(Vector2i(-3,3),{"-3:3":true},{"settlement_perron":true},links)
    check(hidden_landmark.get("known_landmarks",[]).is_empty(),"undiscovered POI leaked into district landmark summary")

    print("DISTRICT SURVEY CONTEXT 1.23-dev18: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
