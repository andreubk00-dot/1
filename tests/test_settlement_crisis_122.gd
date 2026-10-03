extends SceneTree
const FactionEconomy = preload("res://world/faction_economy.gd")
const SettlementCrisis = preload("res://world/settlement_crisis.gd")
const TradingMarket = preload("res://world/trading_market.gd")
const ContractSystem = preload("res://world/contract_system.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const SupplyEventSystem = preload("res://world/supply_event_system.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _offer_with_template(state:Dictionary,faction_id:String,template_id:String,day:int) -> Dictionary:
    for row in ContractSystem.offers_for_faction(state,faction_id,day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}

func run() -> void:
    check(SettlementCrisis.stage_for_value(80.0) == "stable","80 must be stable")
    check(SettlementCrisis.stage_for_value(55.0) == "stable","55 boundary must be stable")
    check(SettlementCrisis.stage_for_value(54.9) == "strain","below 55 must be strain")
    check(SettlementCrisis.stage_for_value(35.0) == "strain","35 boundary must be strain")
    check(SettlementCrisis.stage_for_value(34.9) == "shortage","below 35 must be shortage")
    check(SettlementCrisis.stage_for_value(20.0) == "shortage","20 boundary must be shortage")
    check(SettlementCrisis.stage_for_value(19.9) == "crisis","below 20 must be crisis")

    var state = FactionEconomy.default_state()
    for key in FactionEconomy.RESOURCE_KEYS:
        state["factions"]["lazaret"]["resources"][key] = 80.0
    state["factions"]["lazaret"]["resources"]["medicine"] = 12.0
    var status = SettlementCrisis.faction_status(state,"lazaret")
    check(str(status.get("stage","")) == "crisis","Lazaret medicine collapse must make settlement crisis")
    check(str(status.get("worst_resource","")) == "medicine","worst resource must identify medicine")
    check(SettlementCrisis.item_stage(state,"lazaret","bandage") == "crisis","medical goods must inherit medicine crisis")
    check(SettlementCrisis.item_stage(state,"lazaret","water") == "stable","unrelated water/food goods must stay stable")

    var healthy = FactionEconomy.default_state()
    for key in FactionEconomy.RESOURCE_KEYS:
        healthy["factions"]["lazaret"]["resources"][key] = 80.0
    var healthy_med_price = TradingMarket.buy_price(healthy,"lazaret_supplier","bandage")
    var crisis_med_price = TradingMarket.buy_price(state,"lazaret_supplier","bandage")
    var healthy_water_price = TradingMarket.buy_price(healthy,"lazaret_supplier","water")
    var crisis_water_price = TradingMarket.buy_price(state,"lazaret_supplier","water")
    check(crisis_med_price > healthy_med_price,"medicine crisis must raise medical retail prices")
    check(crisis_water_price >= healthy_water_price,"global poor condition may not make unrelated goods cheaper")
    check(SettlementCrisis.market_sell_factor(state,"lazaret","bandage") > 1.0,"crisis must raise settlement demand for needed goods")
    check(TradingMarket.sell_price(state,"lazaret_supplier","bandage") < TradingMarket.buy_price(state,"lazaret_supplier","bandage"),"crisis price spread must not invert")

    # Crisis suppresses FUTURE restock but never deletes visible stock.
    var low = FactionEconomy.default_state()
    var high = FactionEconomy.default_state()
    low["factions"]["lazaret"]["resources"]["medicine"] = 10.0
    high["factions"]["lazaret"]["resources"]["medicine"] = 100.0
    low["traders"]["lazaret_supplier"]["stock"]["bandage"] = 0
    high["traders"]["lazaret_supplier"]["stock"]["bandage"] = 0
    low["traders"]["lazaret_supplier"]["stock"]["antibiotics"] = 0
    check(TradingMarket.restock(low,"lazaret_supplier",3,true),"crisis forced restock failed")
    check(TradingMarket.restock(high,"lazaret_supplier",3,true),"healthy forced restock failed")
    check(TradingMarket.stock(high,"lazaret_supplier","bandage") > TradingMarket.stock(low,"lazaret_supplier","bandage"),"healthy medicine must replenish more than crisis medicine")
    check(TradingMarket.stock(low,"lazaret_supplier","antibiotics") == 0,"reliable-tier medicine must stay unavailable during full crisis")
    low["traders"]["lazaret_supplier"]["stock"]["antibiotics"] = 2
    check(TradingMarket.restock(low,"lazaret_supplier",4,true),"second crisis restock failed")
    check(TradingMarket.stock(low,"lazaret_supplier","antibiotics") == 2,"restock must not delete existing rare stock")

    # Emergency delivery appears only for real shortage/crisis and survives save reconstruction.
    var crisis_contract_state = FactionEconomy.default_state()
    crisis_contract_state["factions"]["mechanics"]["resources"]["technical"] = 14.0
    crisis_contract_state["factions"]["mechanics"]["resources"]["food"] = 90.0
    crisis_contract_state["factions"]["mechanics"]["resources"]["medicine"] = 90.0
    crisis_contract_state["factions"]["mechanics"]["resources"]["security"] = 90.0
    ContractSystem.ensure_state(crisis_contract_state,2)
    var crisis_offer = _offer_with_template(crisis_contract_state,"mechanics","crisis_mechanics_technical",2)
    check(not crisis_offer.is_empty(),"technical crisis must create emergency Mechanics contract")
    check(bool(crisis_offer.get("crisis_only",false)),"emergency offer must be marked crisis_only")
    var accepted = ContractSystem.accept(crisis_contract_state,str(crisis_offer.get("id","")),2)
    check(bool(accepted.get("ok",false)),"emergency crisis contract must be acceptable")
    var saved = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(crisis_contract_state)))
    ContractSystem.ensure_state(saved,2)
    check(ContractSystem.active_for_faction(saved,"mechanics").size() == 1,"crisis contract must survive faction save sanitization")
    check(str(ContractSystem.active_for_faction(saved,"mechanics")[0].get("template_id","")) == "crisis_mechanics_technical","saved crisis contract template reconstruction failed")

    var stable_contract_state = FactionEconomy.default_state()
    for key in FactionEconomy.RESOURCE_KEYS:
        stable_contract_state["factions"]["mechanics"]["resources"][key] = 90.0
    ContractSystem.refresh_offers(stable_contract_state,2,true)
    check(_offer_with_template(stable_contract_state,"mechanics","crisis_mechanics_technical",2).is_empty(),"stable settlement must not get emergency contract")

    # Security crisis shortens the next supply-incident cadence after an event closes.
    var secure_events = FactionEconomy.default_state()
    var unsafe_events = FactionEconomy.default_state()
    for faction_id in unsafe_events["factions"].keys():
        unsafe_events["factions"][faction_id]["resources"]["security"] = 10.0
    secure_events["supply_events"]["active"] = {"id":"x","faction":"perron","coord":[5,5],"created_day":1,"expires_day":2,"stage":"distress","cargo_resource":"food","cargo_label":"еда","loot_profile":"residential","severity":1}
    unsafe_events["supply_events"]["active"] = secure_events["supply_events"]["active"].duplicate(true)
    SupplyEventSystem.daily_tick(secure_events,2,[])
    SupplyEventSystem.daily_tick(unsafe_events,2,[])
    var secure_delay = int(secure_events["supply_events"]["next_event_day"]) - 2
    var unsafe_delay = int(unsafe_events["supply_events"]["next_event_day"]) - 2
    check(unsafe_delay <= secure_delay,"security crisis must not delay supply incidents")
    check(unsafe_delay >= 2,"security crisis incident cadence must keep a minimum two-day gap")

    # Status text explains the dominant problem and can mention a recent lost shipment.
    state["supply_events"]["history"] = [{"faction":"lazaret","closed_day":6,"outcome":"lost"}]
    var summary = SettlementCrisis.summary(state,"lazaret",7)
    check("КРИЗИС" in summary and "медицина" in summary,"settlement summary must expose crisis and resource")
    check("потерян рейс" in summary,"settlement summary must explain recent lost shipment")

    print("SETTLEMENT CRISIS 1.22-dev7: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
