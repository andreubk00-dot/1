extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionSettlementCatalog = preload("res://world/faction_settlement_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const BuildingCatalog = preload("res://world/building_catalog.gd")

var checks := 0
var failures := 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize(): call_deferred("run")

func run():
    check(FactionCatalog.ids().size() == 4,"1.22 must ship exactly four major factions")
    for id in ["perron","rubezh","mechanics","lazaret"]:
        var f = FactionCatalog.faction(id)
        check(not f.is_empty(),id + " faction missing")
        check(f.get("npc_roster",[]).size() >= 4,id + " needs an authored NPC roster")
        check(f.get("market_focus",[]).size() >= 3,id + " market specialization too weak")
        var settlement_id = str(f.get("settlement_id",""))
        check(FactionSettlementCatalog.has(settlement_id),settlement_id + " settlement missing")
        check(FactionSettlementCatalog.footprint(settlement_id).size() == 9,settlement_id + " must be a 3x3 large settlement")
        check(PoiCatalog.has_compound(settlement_id),settlement_id + " not routed through POI catalog")
        var poi = RegionCatalog.poi_by_id(settlement_id)
        check(not poi.is_empty() and bool(poi.get("safe_settlement",false)),settlement_id + " world POI missing/safety flag")
        for offset in FactionSettlementCatalog.footprint(settlement_id):
            var cell = PoiCatalog.cell(settlement_id,offset)
            check(not cell.is_empty(),settlement_id + " empty cell " + str(offset))
            check(str(cell.get("faction_id","")) == id,settlement_id + " faction mismatch")
            check(float(cell.get("enemy_mult",1.0)) == 0.0,settlement_id + " should suppress ambient hostile density")
            for spec in cell.get("buildings",[]):
                check(not BuildingCatalog.by_id(str(spec.get("archetype",""))).is_empty(),settlement_id + " invalid building archetype")

    var state = FactionEconomy.default_state()
    check(int(state.get("currency_tickets",-1)) == 0,"tickets default must be zero")
    check(FactionEconomy.reputation_tier(state,"rubezh").get("id","") == "outsider","initial reputation tier")
    FactionEconomy.add_reputation(state,"rubezh",80)
    check(FactionEconomy.reputation_tier(state,"rubezh").get("id","") == "reliable","reputation progression")
    check(FactionCatalog.market_affinity("rubezh","ammo_9x18") > 1.0,"Rubezh must value ammunition")
    check(FactionCatalog.market_affinity("mechanics","water_filter") > 1.0,"Mechanics must value technical goods")
    check(FactionCatalog.market_affinity("lazaret","antibiotics") > 1.0,"Lazaret must value medicine")
    var before = FactionEconomy.sell_multiplier(state,"mechanics","water_filter")
    FactionEconomy.record_sale(state,"mechanics","water_filter",20)
    var after = FactionEconomy.sell_multiplier(state,"mechanics","water_filter")
    check(after < before,"market saturation must reduce repeated-sale value")
    var old_food = float(state["factions"]["perron"]["resources"]["food"])
    FactionEconomy.daily_tick(state)
    check(float(state["factions"]["perron"]["resources"]["food"]) < old_food,"settlement resources must consume over time")
    var roundtrip = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(state)))
    check(int(roundtrip["factions"]["rubezh"]["reputation"]) == 80,"faction state must survive JSON roundtrip")

    print("FACTIONS 1.22: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
