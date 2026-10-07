extends SceneTree

const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const ContractSystem = preload("res://world/contract_system.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _count_status(state:Dictionary,template_id:String,status:String) -> int:
    var n := 0
    for row in state.get("contract_history",[]):
        if str(row.get("template_id","")) == template_id and str(row.get("status","")) == status:
            n += 1
    return n

func _check_checkpoint(state:Dictionary,day:int) -> void:
    var personal = state.get("contracts",{}).get("personal_offers",{})
    var total := 0
    for npc_id in ContractCatalog.personal_board_npcs():
        var rows = personal.get(npc_id,[])
        check(rows.size() <= 1,"day %d: personal board %s exceeded one offer" % [day,npc_id])
        total += rows.size()
    check(total <= ContractCatalog.personal_board_npcs().size(),"day %d: personal offers grew without bound" % day)
    check(state.get("contract_history",[]).size() <= ContractSystem.MAX_HISTORY,"day %d: contract history exceeded cap" % day)
    check(state.get("contracts",{}).get("active",{}).size() <= ContractSystem.MAX_ACTIVE,"day %d: active contract cap exceeded" % day)

func run() -> void:
    var state = FactionEconomy.default_state()
    for faction_id in FactionCatalog.ids():
        FactionEconomy.add_reputation(state,faction_id,100)
    ContractSystem.ensure_state(state,1)

    for npc_id in ContractCatalog.personal_board_npcs():
        check(ContractSystem.offers_for_npc(state,npc_id,1).size() == 1,"initial personal offer missing for " + npc_id)

    var perron_offer = ContractSystem.offers_for_npc(state,"perron_radio",1)[0]
    var accepted = ContractSystem.accept(state,str(perron_offer.get("id","")),1)
    check(bool(accepted.get("ok",false)),"soak fixture personal contract failed to accept")
    var template_id = str(accepted.get("contract",{}).get("template_id",""))
    var expected_deadline = int(accepted.get("contract",{}).get("deadline_day",0))
    check(expected_deadline > 1,"accepted personal contract has no future deadline")

    var rep_before = FactionEconomy.reputation(state,"perron")
    var failure_seen := false
    var failure_event_count := 0
    for day in range(2,181):
        var events = ContractSystem.daily_tick(state,day)
        for event in events:
            if str(event.get("status","")) == "failed" and str(event.get("contract",{}).get("template_id","")) == template_id:
                failure_seen = true
                failure_event_count += 1
        if day in [30,60,180]:
            _check_checkpoint(state,day)

    check(failure_seen,"accepted personal contract never failed after its deadline")
    check(failure_event_count == 1,"deadline failure fired more than once")
    check(FactionEconomy.reputation(state,"perron") < rep_before,"deadline failure did not apply reputation consequence")
    check(state.get("contract_history",[]).size() <= ContractSystem.MAX_HISTORY,"180-day personal history cap regression")

    print("PERSONAL CONTRACT SOAK 1.23-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
