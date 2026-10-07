extends SceneTree
const Main = preload("res://main_script_mod.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _talk(game,npc_id:String,faction_id:String,name:String,role:String) -> String:
    var node = Node2D.new()
    node.set_meta("npc_id",npc_id)
    node.set_meta("faction_id",faction_id)
    node.set_meta("display_name",name)
    node.set_meta("npc_role",role)
    game.add_child(node)
    game._talk_faction_npc(node)
    var text = game.survival_feedback
    node.queue_free()
    return text

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null: quit(1); return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame; await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.world_day = 12
    game.world_minutes = 700.0

    var rows = [
        ["route_perron_zarya","perron","perron_cook","Тётя Галя","заведующая кухней","Заре","Рубежу"],
        ["route_lazaret_hospital","lazaret","lazaret_supplier","Тимур","снабженец","районной больнице","Механики"],
        ["route_rubezh_police","rubezh","rubezh_quartermaster","Старшина Лебедев","снабженец","Полицейский маршрут","Механикам"],
        ["route_mechanics_depot","mechanics","mechanics_trader","Рита","приёмщица деталей","Депо","Лазарет"]
    ]
    for row in rows:
        var route_id = str(row[0]); var faction_id = str(row[1])
        game.faction_state = game.FactionEconomy.default_state()
        game.faction_state["world_routes"][route_id] = {"state":"open","opened_day":11,"source_contract":"qa"}
        var text = _talk(game,str(row[2]),faction_id,str(row[3]),str(row[4]))
        check(text.find(str(row[5])) >= 0,route_id + " NPC talk does not mention the opened route consequence")
        check(text.find(str(row[6])) >= 0,route_id + " NPC talk does not preserve cross-faction sandbox contrast")
        game._update_hud()
        check(game.hud_feedback_panel != null and game.hud_feedback_panel.visible,route_id + " NPC reaction is not rendered on the HUD")
        check(game.hud_feedback_label != null and str(game.hud_feedback_label.text).find(str(row[5])) >= 0,route_id + " HUD feedback does not render the route-specific NPC line")

        game.faction_state["world_chronicle"] = []
        game._record_contract_world_news({"ok":true,"faction":faction_id,"title":"QA ROUTE","opened_route":route_id,"personal":false})
        var entries = game.WorldChronicle.entries(game.faction_state,10)
        check(entries.size() == 1,route_id + " did not create one route chronicle entry")
        if not entries.is_empty():
            check(str(entries[0].get("kind","")) == "route",route_id + " chronicle kind mismatch")
            check(str(entries[0].get("text","")) == game.SandboxRouteConsequences.news_text(route_id),route_id + " runtime radio text fell back to generic route message")

    # Real completion hook: the main UI path applies the one-time trader package before forced restock.
    game.faction_state = game.FactionEconomy.default_state()
    game.FactionEconomy.add_reputation(game.faction_state,"perron",8)
    game.ContractSystem.refresh_offers(game.faction_state,12,true)
    var offer = {}
    for row in game.ContractSystem.offers_for_faction(game.faction_state,"perron",12):
        if str(row.get("template_id","")) == "perron_zarya_route": offer = row; break
    check(not offer.is_empty(),"runtime Perron route offer missing")
    var accepted = game.ContractSystem.accept(game.faction_state,str(offer.get("id","")),12)
    check(bool(accepted.get("ok",false)),"runtime Perron route could not be accepted")
    game.discovered_pois["dacha_coop_zarya"] = true
    game._open_contract_board("perron","Вера Андреевна","perron_steward")
    await process_frame
    var active = accepted.get("contract",{})
    game.selected_contract_id = str(active.get("id",""))
    game.selected_contract_source = "active"
    var grain_before = game.TradingMarket.stock(game.faction_state,"perron_canteen","grain")
    check(game._contract_complete_selected(),"real UI completion could not close Perron starter route")
    check(game.SandboxRouteConsequences.is_open(game.faction_state,"route_perron_zarya"),"real UI completion did not persist Perron route")
    check(bool(game.faction_state["world_routes"]["route_perron_zarya"].get("opening_stock_applied",false)),"real UI completion skipped route opening-stock marker")
    check(game.TradingMarket.stock(game.faction_state,"perron_canteen","grain") >= grain_before + 4,"real UI completion did not add the route opening package to trader stock")
    var chronicle = game.WorldChronicle.entries(game.faction_state,20)
    var found_specific = false
    for entry in chronicle:
        if str(entry.get("kind","")) == "route" and str(entry.get("text","")).find("СНТ «Заря»") >= 0:
            found_specific = true
    check(found_specific,"real UI completion did not broadcast specific Zarya route news")

    game.queue_free(); await process_frame; await process_frame
    print("SANDBOX ROUTE CONSEQUENCES RUNTIME 1.23-dev15: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
