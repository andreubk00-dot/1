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
    game.world_day = 18; game.world_minutes = 730.0
    game.faction_state["world_routes"]["route_mechanics_depot"] = {"state":"open","opened_day":17,"source_contract":"mechanics_rail_depot"}
    var scrap_before = game.TradingMarket.stock(game.faction_state,"mechanics_parts","scrap")
    var applied = game.SandboxRouteConsequences.apply_opening_stock(game.faction_state,"route_mechanics_depot")
    check(bool(applied.get("applied",false)),"save fixture could not apply depot opening package")
    check(game.TradingMarket.stock(game.faction_state,"mechanics_parts","scrap") == scrap_before + 6,"save fixture depot stock wrong")
    game._save_state()
    var raw = game.SaveStore.read_save(game.SAVE_PATH)
    check(not raw.is_empty(),"production SaveStore could not read dev15 save")
    check(int(raw.get("save_version",0)) == 122,"dev15 changed save schema instead of extending schema 122")
    check(bool(raw.get("faction_state",{}).get("world_routes",{}).get("route_mechanics_depot",{}).get("opening_stock_applied",false)),"route one-shot marker missing from production save")
    game.queue_free(); await process_frame; await process_frame

    var loaded = Main.new(); root.add_child(loaded)
    await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    check(loaded.SandboxRouteConsequences.is_open(loaded.faction_state,"route_mechanics_depot"),"production load lost opened depot route")
    check(bool(loaded.faction_state["world_routes"]["route_mechanics_depot"].get("opening_stock_applied",false)),"production load lost opening-stock marker")
    check(loaded.TradingMarket.stock(loaded.faction_state,"mechanics_parts","scrap") == scrap_before + 6,"production load changed route-added trader stock")
    var second = loaded.SandboxRouteConsequences.apply_opening_stock(loaded.faction_state,"route_mechanics_depot")
    check(not bool(second.get("applied",true)) and int(second.get("added",-1)) == 0,"load enabled duplicate route opening stock")
    check(loaded.SandboxRouteConsequences.restock_factor(loaded.faction_state,"mechanics","scrap","parts") > 1.0,"production load lost ongoing route restock consequence")

    # Controlled dev14 migration: open route with no marker gains only derived ongoing effects.
    var legacy = loaded.FactionEconomy.default_state()
    legacy["world_routes"]["route_lazaret_hospital"] = {"state":"open","opened_day":9,"source_contract":"lazaret_hospital_route"}
    var old_stock = loaded.TradingMarket.stock(legacy,"lazaret_supplier","sterile_bandage")
    var clean = loaded.FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(legacy)))
    check(loaded.SandboxRouteConsequences.is_open(clean,"route_lazaret_hospital"),"dev14 migration lost hospital route")
    check(not bool(clean["world_routes"]["route_lazaret_hospital"].get("opening_stock_applied",false)),"dev14 migration fabricated one-time package history")
    check(loaded.TradingMarket.stock(clean,"lazaret_supplier","sterile_bandage") == old_stock,"dev14 migration gifted route stock")
    check(loaded.SandboxRouteConsequences.npc_note(clean,"lazaret").find("районной больнице") >= 0,"dev14 migration did not gain derived NPC consequence")

    loaded.queue_free(); await process_frame
    print("SANDBOX ROUTE CONSEQUENCES SAVE RUNTIME 1.23-dev15: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
