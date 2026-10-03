extends SceneTree

const Main = preload("res://main_script_mod.gd")
const Store = preload("res://world/save_store.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")
const TradingMarket = preload("res://world/trading_market.gd")
const ContractSystem = preload("res://world/contract_system.gd")
const SupplyEventSystem = preload("res://world/supply_event_system.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")

func _clear_live_save() -> void:
    for suffix in ["",".bak",".tmp"]:
        var path = Main.SAVE_PATH + suffix
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)

func run() -> void:
    _clear_live_save()
    check(str(ProjectSettings.get_setting("application/config/version","")) == "1.22.0","stable project version mismatch")

    var game = Main.new()
    root.add_child(game)
    game.set_process(false)
    await process_frame
    await process_frame

    check(not game._developer_tools_available(),"stable build exposed developer tools")
    check(not InputMap.has_action("developer_panel"),"stable build created F10 developer action")
    check(game.developer_panel == null and game.developer_hud_button == null,"stable build created developer UI")
    check(FactionCatalog.ids().size() == 4,"stable faction catalog must contain four factions")
    check(TraderCatalog.ids().size() == 8,"stable trader catalog must contain eight traders")
    check(game.faction_state.get("factions",{}).size() == 4,"production startup lost faction state")
    check(game.faction_state.get("traders",{}).size() == 8,"production startup lost trader state")
    check(game.faction_state.has("relations") and game.faction_state.has("world_influence"),"stable startup missing faction relations state")
    check(game.faction_state.has("supply_events"),"stable startup missing supply-event state")
    check(game.faction_state.has("faction_endgame"),"stable startup missing endgame state")

    ContractSystem.ensure_state(game.faction_state,game.world_day)
    var offer_count := 0
    for faction_id in FactionCatalog.ids():
        offer_count += ContractSystem.offers_for_faction(game.faction_state,faction_id,game.world_day).size()
    check(offer_count > 0,"stable startup produced no faction contract offers")

    var next_supply = int(game.faction_state.get("supply_events",{}).get("next_event_day",0))
    check(next_supply >= game.world_day + 3 and next_supply <= game.world_day + 6,"stable startup scheduled supply event outside 3-6 day window")

    # One production market round-trip must be valid but must not create settlement resources.
    game.FactionEconomy.add_tickets(game.faction_state,500)
    var before_resource = float(game.faction_state["factions"]["perron"]["resources"]["food"])
    var buy = TradingMarket.buy_quote(game.faction_state,"perron_general","canned_meat",1)
    check(bool(buy.get("ok",false)),"stable market could not quote a basic purchase")
    if bool(buy.get("ok",false)):
        check(TradingMarket.apply_purchase(game.faction_state,"perron_general","canned_meat",1,int(buy.get("total",0))),"stable market purchase failed")
        var sell = TradingMarket.sell_quote(game.faction_state,"perron_general","canned_meat",1)
        check(bool(sell.get("ok",false)),"stable market could not quote the return sale")
        if bool(sell.get("ok",false)):
            check(TradingMarket.apply_sale(game.faction_state,"perron_general","canned_meat",1,int(sell.get("total",0))),"stable market return sale failed")
            var after_resource = float(game.faction_state["factions"]["perron"]["resources"]["food"])
            check(after_resource <= before_resource + 0.001,"local buy/sell round-trip inflated settlement resource")

    game._save_state()
    await process_frame
    var raw = Store.read_save(Main.SAVE_PATH)
    check(not raw.is_empty(),"stable production save was not readable")
    check(int(raw.get("save_version",0)) == 122,"stable save schema changed unexpectedly")
    check(typeof(raw.get("faction_state",{})) == TYPE_DICTIONARY,"stable save lost faction_state")

    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    check(loaded.world_day == game.world_day,"stable production reload changed world day")
    check(loaded.faction_state.has("relations") and loaded.faction_state.has("supply_events") and loaded.faction_state.has("faction_endgame"),"stable production reload lost 1.22 systems")

    loaded.free()
    game.queue_free()
    await process_frame
    _clear_live_save()
    print("STABLE RELEASE GATE 1.22.0: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
