extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const Journal = preload("res://world/expedition_journal.gd")
var checks = 0
var failures = 0

func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func fresh():
    var game = Harness.new()
    root.add_child(game)
    game.current_chunk = Vector2i.ZERO
    game.roof_records[0]["building_key"] = "0:0:home"
    game.roof_records[0]["building_name"] = "МАСТЕРСКАЯ"
    game.roof_records[0]["chunk_coord"] = Vector2i.ZERO
    game.roof_records.append({"rect":Rect2(100,0,80,80),"building_key":"0:0:other","building_name":"ГАРАЖ","chunk_coord":Vector2i.ZERO})
    game.equipment = {"body":"","head":"","backpack":"","utility":""}
    game.inventory_entries = [{"id":"water","qty":2,"x":0,"y":0},{"id":"canned_meat","qty":2,"x":1,"y":0}]
    return game

func plan(game):
    game.region_map_selected_chunk = Vector2i(2,0)
    game._plan_selected_expedition()

func depart(game):
    game.player.position = Vector2(60,0)
    game._update_expedition_progress()

func return_home(game):
    game.player.position = Vector2.ZERO
    game.current_chunk = Vector2i.ZERO
    game._update_expedition_progress()

func _initialize():
    call_deferred("run")

func run():
    var game = fresh()
    plan(game)
    check(not game.expedition_active,"new expeditions require home identity")
    game.player.position = Vector2(70,0)
    check(not game._claim_current_home(),"cannot claim outdoors")
    game.player.position = Vector2.ZERO
    check(game._claim_current_home(),"can mark occupied building")
    check(game._at_home() and game._home_chunk() == Vector2i.ZERO,"home has exact identity and chunk")
    check(game._region_map_cell_tooltip(Vector2i.ZERO).begins_with("ДОМ:"),"map must mark home even in current sector")
    plan(game)
    check(game.expedition_active,"missing supplies warn but do not prevent planning")
    var original_start = game.expedition_started_minutes
    game.world_minutes += 20
    game.inventory_entries[0]["qty"] = 3
    depart(game)
    check(game.expedition_journal["departure"]["items"]["water"] == 3,"baseline must capture supplies packed after planning")
    check(game.expedition_started_minutes == original_start + 20,"trip duration starts on leaving home")
    var start = game.expedition_started_minutes
    var baseline = game.expedition_journal["departure"].duplicate(true)
    game.world_minutes += 12
    game.region_map_selected_chunk = Vector2i(3,0)
    game._plan_selected_expedition()
    check(game.expedition_started_minutes == start and game.expedition_journal["departure"] == baseline,"retarget must preserve departure baseline and clock")
    game.player.position = Vector2(120,20)
    check(not game._claim_current_home(),"cannot move home during active trip")
    game.current_chunk = Vector2i(3,0)
    game.player.position = Vector2(2400,100)
    game._update_expedition_progress()
    check(game.expedition_target_reached,"entering destination must mark target reached")
    check(game._navigation_target_chunk() == Vector2i.ZERO,"return route must lead home after target")
    game.current_chunk = Vector2i.ZERO
    game.player.position = Vector2(120,20)
    game._update_expedition_progress()
    check(game.expedition_active,"wrong building in home sector cannot finish expedition")
    game.player.position = Vector2(60,0)
    game._update_expedition_progress()
    check(game.expedition_active,"street in home sector cannot finish expedition")
    game.inventory_entries[0]["qty"] = 1
    game.inventory_entries.append({"id":"scrap","qty":4,"x":2,"y":0})
    game.health = 72
    game.wetness = 80
    game.world_day = 2
    game.world_minutes = 20
    return_home(game)
    check(not game.expedition_active,"entering exact home must finish trip")
    var report = game.expedition_journal["last_report"]
    check(report["reached"] and report["status"] == "returned","report must retain objective outcome")
    var delta = Journal.item_delta(report["before"],report["after"])
    check(delta["gains"].get("scrap",0) == 4 and delta["losses"].get("water",0) == 2,"report must include net supplies gained and used")
    check(report["after"]["vitals"]["health"] == 72.0 and report["after"]["vitals"]["wetness"] == 80.0,"report must snapshot injuries and exposure")
    check(report["elapsed"] == int(1440 + 20 - start),"duration must include midnight")
    game._update_expedition_progress()
    game.health = 100
    check(game.expedition_journal["last_report"]["after"]["vitals"]["health"] == 72.0,"recovery must not rewrite historical return state")
    game.free()

    game = fresh()
    game._claim_current_home()
    plan(game)
    depart(game)
    game.expedition_journal["returning"] = true
    check(game._navigation_target_chunk() == Vector2i.ZERO,"early return route must lead home")
    return_home(game)
    check(not game.expedition_journal["last_report"]["reached"],"return without objective must not claim success")
    game.free()

    game = fresh()
    game.inventory_entries = [{"id":"makarov","qty":1,"x":0,"y":0},{"id":"ammo_9x18","qty":20,"x":2,"y":0},{"id":"light_jacket","qty":1,"x":3,"y":0}]
    var expedition_pm_iid = game.set_test_weapon_state("makarov",0)
    game._switch_weapon("makarov",expedition_pm_iid)
    baseline = game._expedition_snapshot()
    game._equip_item("light_jacket")
    for entry in game.inventory_entries:
        if entry["id"] == "ammo_9x18":
            entry["qty"] = 12
    game._set_weapon_mag_value("makarov",8,expedition_pm_iid)
    delta = Journal.item_delta(baseline,game._expedition_snapshot())
    check(delta["gains"].is_empty() and delta["losses"].is_empty(),"equipping and reloading must not fabricate gains/losses")
    game._set_weapon_mag_value("makarov",6,expedition_pm_iid)
    delta = Journal.item_delta(baseline,game._expedition_snapshot())
    check(delta["losses"].get("ammo_9x18",0) == 2,"fired loaded rounds must count as expenditure")
    game.inventory_entries = [{"id":"grain","qty":20},{"id":"dirty_water","qty":10}]
    check(game._expedition_readiness()["text"].contains("[нет] Готовая еда: 0"),"raw grain is not ready expedition food")
    check(game._expedition_readiness()["text"].contains("[нет] Питьё: 0.0 л"),"dirty water is not clean drinking supply")
    game.free()

    game = fresh()
    game._claim_current_home()
    plan(game)
    depart(game)
    var saved = JSON.parse_string(JSON.stringify({"expedition_journal":game.expedition_journal}))
    var restored = fresh()
    restored.expedition_active = true
    restored._load_expedition_journal(saved)
    check(restored._at_home(),"home identity must survive JSON round trip")
    check(restored.expedition_journal["departed"] and restored.expedition_journal["departure"] == game.expedition_journal["departure"],"ongoing expedition baseline must survive save/load")
    restored._load_expedition_journal({})
    check(not restored._has_home(),"0.92 saves must load without fabricating a home")
    restored.expedition_origin_chunk = Vector2i.ZERO
    restored.expedition_target_chunk = Vector2i(2,0)
    restored.expedition_target_reached = true
    restored._update_expedition_progress()
    check(not restored.expedition_active,"old active route may finish in its original sector")
    check(restored.expedition_journal["last_report"]["before"].is_empty(),"legacy report must not invent a departure inventory")
    game._finish_expedition("incapacitated")
    check(game.expedition_journal["last_report"]["status"] == "incapacitated" and not game.expedition_active,"incapacitation must close expedition before respawn")
    saved = JSON.parse_string(JSON.stringify(game.expedition_journal))
    check(Journal.normalize(saved)["last_report"] == game.expedition_journal["last_report"],"last report must survive JSON round trip")
    check(Journal.normalize({"home":[],"departure":"bad","last_report":42})["home"].is_empty(),"malformed optional data must not break old saves")
    check(Journal.home({"key":"x","chunk":["bad",0],"position":[0,0]}).is_empty(),"invalid home coordinates must be discarded")
    game.free()
    restored.free()

    game = fresh()
    game._create_region_map_ui()
    game._create_home_journal_ui()
    game._open_home_journal()
    check(game.region_map_open and game.home_journal_panel.visible and not game.region_map_panel.visible,"journal must use map input guard")
    game._claim_current_home()
    check(game.home_claim_button.disabled,"claim button must disable in own home")
    check(game.home_claim_hint.get_minimum_size().x <= 568,"home hint must fit panel")
    check(game.home_journal_label.get_minimum_size().y <= 30,"home address must fit header")
    check(game.home_report_text.scroll_active and game.home_preparation_text.scroll_active,"long supplies and report must remain scrollable")
    game._pan_region_map(Vector2i(18,-12))
    check(game.region_map_center == Vector2i(18,-12) and game.region_map_grid.contains_sector(Vector2i(18,-12)),"panning must keep the requested center selectable")
    check(game.region_map_grid.unproject(game.region_map_grid.size*0.5) == Vector2i(18,-12),"panned grid must bind world coordinates")
    game.expedition_journal["home"] = {"key":"20:20:home","name":"Дальний дом","chunk":[20,20],"position":[15400.0,15400.0]}
    game._navigate_home()
    check(game.region_map_grid.contains_sector(Vector2i(20,20)) and game.region_map_grid.data.get("home") == Vector2i(20,20),"home outside original map must remain visible")
    game.body_condition["legs"] = 42.0
    check(game._expedition_snapshot()["body"]["legs"] == 42.0,"report must retain specific limb injuries")
    game._close_region_map()
    check(not game.region_map_open and not game.home_journal_panel.visible,"closing map must close journal and restore controls")
    game.free()
    print("EXPEDITION REGRESSION: ",checks," checks, ",failures," failures")
    quit(1 if failures > 0 else 0)
