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
    var route = game.ContractCatalog.template("rubezh_police_route").get("reward",{}).get("route",{}).duplicate(true)
    route["state"] = "open"; route["opened_day"] = 31; route["source_contract"] = "rubezh_police_route"
    game.faction_state["world_routes"]["route_rubezh_police"] = route
    game.discovered_pois = {"settlement_rubezh":true,"district_police":true}
    game.discovered_chunks = {"8:-3":true,"-3:-1":true}
    game._save_state()
    var raw = game.SaveStore.read_save(game.SAVE_PATH)
    check(int(raw.get("save_version",0)) == 122,"dev17 changed production save schema")
    check(raw.get("faction_state",{}).get("world_routes",{}).has("route_rubezh_police"),"production save lost open route")
    check(bool(raw.get("discovered_pois",{}).get("settlement_rubezh",false)) and bool(raw.get("discovered_pois",{}).get("district_police",false)),"production save lost route endpoint knowledge")
    check(not raw.has("established_routes") and not raw.get("faction_state",{}).has("established_routes"),"dev17 persisted derived map presentation data")
    game.queue_free(); await process_frame; await process_frame

    var loaded = Main.new(); root.add_child(loaded)
    await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    var links = loaded.SandboxRouteMap.links(loaded.faction_state,loaded.discovered_pois)
    check(links.size() == 1,"loaded schema-122 save cannot reconstruct established route map")
    if not links.is_empty():
        check(str(links[0].get("route_id","")) == "route_rubezh_police","loaded route projection resolved wrong route")
        check(links[0].get("from",Vector2i.ZERO) == Vector2i(8,-3) and links[0].get("to",Vector2i.ZERO) == Vector2i(-3,-1),"loaded route endpoint coordinates drifted")

    # Dev15-style route record without source_contract is still presentable after sanitize/load logic.
    var legacy = loaded.FactionEconomy.default_state()
    legacy["world_routes"]["route_lazaret_hospital"] = {"state":"open","opened_day":9}
    var clean = loaded.FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(legacy)))
    var migrated = loaded.SandboxRouteMap.links(clean,{"settlement_lazaret":true,"district_hospital":true})
    check(migrated.size() == 1,"dev15-style route record lost map reconstruction")
    check(not clean["world_routes"]["route_lazaret_hospital"].has("source_contract"),"map reconstruction mutated legacy save state")

    loaded.queue_free(); await process_frame
    print("ESTABLISHED ROUTE MAP SAVE RUNTIME 1.23-dev17: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
