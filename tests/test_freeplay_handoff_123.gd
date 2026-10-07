extends SceneTree
const FactionEconomy = preload("res://world/faction_economy.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const ContractSystem = preload("res://world/contract_system.gd")
const VerticalSlice = preload("res://world/vertical_slice.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _has_offer(rows:Array,template_id:String) -> bool:
    for row in rows:
        if typeof(row) == TYPE_DICTIONARY and str(row.get("template_id","")) == template_id:
            return true
    return false

func run() -> void:
    var route = ContractCatalog.template("lazaret_hospital_route")
    check(not route.is_empty(),"district hospital contract template missing")
    check(int(route.get("min_rep",999)) == 10,"district hospital free-play route must unlock at rep 10")
    check(str(route.get("kind","")) == "discover_poi","district hospital handoff must remain a real reconnaissance contract")
    check(str(route.get("poi_id","")) == "district_hospital","district hospital handoff points at wrong POI")
    check(not route.has("global_goal"),"free-play handoff invented a global goal")

    var low = FactionEconomy.default_state()
    FactionEconomy.add_reputation(low,"lazaret",9)
    ContractSystem.refresh_offers(low,8,true)
    check(not _has_offer(ContractSystem.offers_for_faction(low,"lazaret",8),"lazaret_hospital_route"),"district hospital route unlocks below rep 10")

    var ready = FactionEconomy.default_state()
    FactionEconomy.add_reputation(ready,"lazaret",10)
    ContractSystem.refresh_offers(ready,8,true)
    var offers = ContractSystem.offers_for_faction(ready,"lazaret",8)
    check(_has_offer(offers,"lazaret_hospital_route"),"district hospital route not offered at rep 10")
    check(FactionEconomy.reputation(ready,"lazaret") == 10,"offer refresh changed reputation")

    var rec = VerticalSlice.default_state()
    rec["initialized"] = true
    rec["completed"] = true
    rec["enabled"] = false
    rec["completed_day"] = 7
    rec["doctor_debrief_seen"] = true
    ready["vertical_slice"] = rec
    var sanitized = FactionEconomy.sanitize_state(ready)
    var after = VerticalSlice.record(sanitized)
    check(bool(after.get("completed",false)),"free-play handoff lost completed vertical slice")
    check(not bool(after.get("enabled",true)),"completed slice was re-enabled by dev12")
    check(int(sanitized.get("save_version",122)) == 122 or not sanitized.has("save_version"),"free-play handoff should not require a save schema bump")

    print("FREE-PLAY HANDOFF 1.23-dev12: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
