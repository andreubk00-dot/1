extends SceneTree
const Main = preload("res://main_script_mod.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void:
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2); return
    call_deferred("run")

func run() -> void:
    var game = Main.new(); root.add_child(game)
    await process_frame; await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.world_day = 40; game.world_minutes = 600.0
    var route = game.ContractCatalog.template("rubezh_police_route").get("reward",{}).get("route",{}).duplicate(true)
    route["state"] = "open"; route["opened_day"] = 39; route["source_contract"] = "rubezh_police_route"
    game.faction_state["world_routes"]["route_rubezh_police"] = route
    game.faction_state["factions"]["rubezh"]["resources"]["security"] = 100.0
    game._save_state()

    var raw = game.SaveStore.read_save(game.SAVE_PATH)
    check(not raw.is_empty(),"production SaveStore could not read dev16 fixture")
    check(int(raw.get("save_version",0)) == 122,"dev16 changed save schema instead of preserving 122")
    check(not raw.get("faction_state",{}).has("passive_logistics"),"dev16 persisted a new passive-logistics state blob")
    check(abs(float(raw.get("faction_state",{}).get("factions",{}).get("rubezh",{}).get("resources",{}).get("security",0.0)) - 100.0) < 0.001,"saving dev15-compatible state eagerly rewrote security")
    game.queue_free(); await process_frame; await process_frame

    var loaded = Main.new(); root.add_child(loaded)
    await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    check(loaded.SandboxRouteConsequences.is_open(loaded.faction_state,"route_rubezh_police"),"production load lost dev15 police route")
    check(abs(float(loaded.faction_state["factions"]["rubezh"]["resources"]["security"]) - 100.0) < 0.001,"production load rewrote old resource value before a day elapsed")
    loaded._process_world_day_rollovers(40,41)
    check(float(loaded.faction_state["factions"]["rubezh"]["resources"]["security"]) < 100.0,"loaded dev15 state did not adopt dev16 runtime anti-saturation rule")
    loaded._save_state()
    var raw2 = loaded.SaveStore.read_save(loaded.SAVE_PATH)
    check(int(raw2.get("save_version",0)) == 122,"post-rollover save schema changed from 122")
    check(loaded.SandboxRouteConsequences.is_open(raw2.get("faction_state",{}),"route_rubezh_police"),"post-rollover save lost starter route")

    loaded.queue_free(); await process_frame
    print("MULTI-ROUTE ECONOMY SAVE RUNTIME 1.23-dev16: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
