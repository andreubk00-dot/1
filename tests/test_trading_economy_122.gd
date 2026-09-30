extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionSettlementCatalog = preload("res://world/faction_settlement_catalog.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")
const TradingMarket = preload("res://world/trading_market.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var trader_ids = TraderCatalog.ids()
    check(trader_ids.size() == 8,"dev2 must ship two authored traders per faction")
    var per_faction := {}
    for faction_id in FactionCatalog.ids():
        per_faction[faction_id] = 0
    for trader_id in trader_ids:
        var data = TraderCatalog.trader(trader_id)
        var faction_id = str(data.get("faction",""))
        check(FactionCatalog.ids().has(faction_id),trader_id + " references unknown faction")
        per_faction[faction_id] = int(per_faction.get(faction_id,0)) + 1
        check(str(data.get("npc_id","")) != "",trader_id + " has no NPC")
        check(str(data.get("settlement_id","")) == str(FactionCatalog.faction(faction_id).get("settlement_id","")),trader_id + " settlement/faction mismatch")
        check(data.get("stock",[]).size() >= 6,trader_id + " stock is too small to define a market role")
        for spec in data.get("stock",[]):
            var item_id = str(spec.get("id",""))
            check(TraderCatalog.BASE_VALUES.has(item_id),trader_id + " missing base value for " + item_id)
            check(TraderCatalog.accepts_item(trader_id,item_id),trader_id + " cannot accept own stock item " + item_id)
            check(int(spec.get("qty",0)) > 0,trader_id + " has non-positive configured stock")
    for faction_id in per_faction.keys():
        check(int(per_faction[faction_id]) == 2,faction_id + " must have exactly two traders in dev2")

    # Every large settlement has four named inhabitants in authored cells and two of them trade.
    for faction_id in FactionCatalog.ids():
        var settlement_id = str(FactionCatalog.faction(faction_id).get("settlement_id",""))
        var npcs:Array = []
        for offset in FactionSettlementCatalog.footprint(settlement_id):
            var cell = FactionSettlementCatalog.cell(settlement_id,offset)
            check(int(cell.get("enemy_count",-1)) == 0,settlement_id + " authored safe cell must request zero hostiles")
            npcs.append_array(FactionSettlementCatalog.npcs(settlement_id,offset))
        check(npcs.size() == 4,settlement_id + " must currently place four named NPCs")
        var trade_npcs := 0
        for npc in npcs:
            if TraderCatalog.trader_for_npc(str(npc.get("npc_id",""))) != "":
                trade_npcs += 1
        check(trade_npcs == 2,settlement_id + " must expose two physical traders")

    var state = FactionEconomy.default_state()
    check(state.get("traders",{}).size() == 8,"default faction state must persist all trader states")

    # Finite stock + actual ticket transfer.
    FactionEconomy.add_tickets(state,1000)
    var buy_item = "water"
    var old_stock = TradingMarket.stock(state,"perron_general",buy_item)
    var old_tickets = int(state.get("currency_tickets",0))
    var old_reserve = TradingMarket.reserve(state,"perron_general")
    var bq = TradingMarket.buy_quote(state,"perron_general",buy_item,1)
    check(bool(bq.get("ok",false)),"outsider must be able to buy Perron water")
    check(TradingMarket.apply_purchase(state,"perron_general",buy_item,1,int(bq.get("total",0))),"purchase mutation failed")
    check(TradingMarket.stock(state,"perron_general",buy_item) == old_stock - 1,"purchase must consume physical stock")
    check(int(state.get("currency_tickets",0)) == old_tickets - int(bq.get("total",0)),"purchase must remove player tickets")
    check(TradingMarket.reserve(state,"perron_general") == old_reserve + int(bq.get("total",0)),"purchase must move tickets into trader reserve")

    # Reputation gates assortment, not just a discount.
    var locked = TradingMarket.buy_quote(state,"rubezh_armorer","akm",1)
    check(not bool(locked.get("ok",false)) and str(locked.get("reason","")) == "Недостаточная репутация","AKM must be locked for an outsider")
    FactionEconomy.add_reputation(state,"rubezh",150)
    check(TradingMarket.item_unlocked(state,"rubezh_armorer","akm"),"trusted Rubezh reputation must unlock AKM")
    var unlocked = TradingMarket.buy_quote(state,"rubezh_armorer","akm",1)
    check(bool(unlocked.get("ok",false)),"trusted player with tickets must receive AKM quote")

    # Even the best reputation + perfect supply may narrow the spread, but never invert it.
    for trader_id in trader_ids:
        var arb_state = FactionEconomy.default_state()
        var arb_faction = str(TraderCatalog.trader(trader_id).get("faction",""))
        FactionEconomy.add_reputation(arb_state,arb_faction,250)
        for resource_id in FactionEconomy.RESOURCE_KEYS:
            arb_state["factions"][arb_faction]["resources"][resource_id] = 100.0
        for raw_item_id in TraderCatalog.BASE_VALUES.keys():
            var arb_item_id = str(raw_item_id)
            if TraderCatalog.accepts_item(trader_id,arb_item_id):
                check(TradingMarket.sell_price(arb_state,trader_id,arb_item_id) <= TradingMarket.buy_price(arb_state,trader_id,arb_item_id),trader_id + " buy/sell arbitrage on " + arb_item_id)

    # Market specialization is enforced, not cosmetic.
    check(TraderCatalog.accepts_item("mechanics_parts","scrap"),"Mechanics must buy scrap")
    check(not TraderCatalog.accepts_item("mechanics_parts","canned_meat"),"Mechanics parts desk must reject food")
    check(TraderCatalog.accepts_item("lazaret_supplier","antibiotics"),"Lazaret must buy medicine")
    check(not TraderCatalog.accepts_item("lazaret_supplier","akm"),"Lazaret must reject weapons")

    # Selling pays from a finite reserve, creates stock, feeds settlement resources, and floods price.
    var sale_state = FactionEconomy.default_state()
    var tech_before = float(sale_state["factions"]["mechanics"]["resources"]["technical"])
    var sell_before = TradingMarket.sell_price(sale_state,"mechanics_parts","repair_kit")
    var sq = TradingMarket.sell_quote(sale_state,"mechanics_parts","repair_kit",10)
    check(bool(sq.get("ok",false)),"Mechanics scrap sale quote failed")
    var sale_stock_before = TradingMarket.stock(sale_state,"mechanics_parts","repair_kit")
    check(TradingMarket.apply_sale(sale_state,"mechanics_parts","repair_kit",10,int(sq.get("total",0))),"sale mutation failed")
    check(TradingMarket.stock(sale_state,"mechanics_parts","repair_kit") == sale_stock_before + 10,"sold goods must enter trader stock")
    check(float(sale_state["factions"]["mechanics"]["resources"]["technical"]) > tech_before,"technical sale must improve Mechanics supply")
    var sell_after = TradingMarket.sell_price(sale_state,"mechanics_parts","repair_kit")
    check(sell_after < sell_before,"market flooding must lower repeated sale value")
    sale_state["traders"]["mechanics_parts"]["ticket_reserve"] = 0
    var broke_quote = TradingMarket.sell_quote(sale_state,"mechanics_parts","repair_kit",1)
    check(not bool(broke_quote.get("ok",false)),"trader with zero reserve must not buy goods")

    # Barter can cover price partly or entirely with accepted goods and moves both stock legs.
    var barter_state = FactionEconomy.default_state()
    FactionEconomy.add_tickets(barter_state,200)
    var target_before = TradingMarket.stock(barter_state,"perron_general","water")
    var offered_before = TradingMarket.stock(barter_state,"perron_general","canned_meat")
    var barter = TradingMarket.barter_quote(barter_state,"perron_general","water",1,"canned_meat",1)
    check(bool(barter.get("ok",false)),"basic Perron barter quote failed")
    var delta = int(barter.get("ticket_delta",0))
    var tickets_before_barter = int(barter_state.get("currency_tickets",0))
    check(TradingMarket.apply_barter(barter_state,"perron_general","water",1,"canned_meat",1,delta),"barter mutation failed")
    check(TradingMarket.stock(barter_state,"perron_general","water") == target_before - 1,"barter must remove requested stock")
    check(TradingMarket.stock(barter_state,"perron_general","canned_meat") == offered_before + 1,"barter must add offered stock")
    check(int(barter_state.get("currency_tickets",0)) == tickets_before_barter - delta,"barter ticket difference applied incorrectly")

    # Restock is timed and settlement supply controls how much returns.
    var poor = FactionEconomy.default_state()
    var rich = FactionEconomy.default_state()
    poor["traders"]["mechanics_parts"]["stock"]["scrap"] = 0
    rich["traders"]["mechanics_parts"]["stock"]["scrap"] = 0
    poor["factions"]["mechanics"]["resources"]["technical"] = 0.0
    rich["factions"]["mechanics"]["resources"]["technical"] = 100.0
    check(not TradingMarket.restock(poor,"mechanics_parts",2,false),"restock must respect its day interval")
    check(TradingMarket.restock(poor,"mechanics_parts",3,false),"restock should occur when interval elapses")
    check(TradingMarket.restock(rich,"mechanics_parts",3,false),"rich settlement restock failed")
    check(TradingMarket.stock(rich,"mechanics_parts","scrap") > TradingMarket.stock(poor,"mechanics_parts","scrap"),"healthy supply must restock more goods than severe shortage")

    # Daily economy and save roundtrip preserve finite trader state.
    var pressure_before = float(sale_state["factions"]["mechanics"]["market_pressure"].get("repair_kit",0.0))
    FactionEconomy.daily_tick(sale_state)
    var pressure_after = float(sale_state["factions"]["mechanics"]["market_pressure"].get("repair_kit",0.0))
    check(pressure_after < pressure_before,"daily tick must let flooded markets recover")
    var roundtrip = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(barter_state)))
    check(TradingMarket.stock(roundtrip,"perron_general","water") == TradingMarket.stock(barter_state,"perron_general","water"),"trader stock must survive JSON save roundtrip")
    check(TradingMarket.reserve(roundtrip,"perron_general") == TradingMarket.reserve(barter_state,"perron_general"),"trader reserve must survive JSON save roundtrip")

    print("TRADING 1.22-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
