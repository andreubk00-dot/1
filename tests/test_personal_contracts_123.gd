extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionNpcState = preload("res://world/faction_npc_state.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const ContractSystem = preload("res://world/contract_system.gd")

var failures := 0
var checks := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _fresh_with_rep(faction_id:String,rep:int = 25,day:int = 1) -> Dictionary:
    var state = FactionEconomy.default_state()
    FactionEconomy.add_reputation(state,faction_id,rep)
    ContractSystem.ensure_state(state,day)
    return state

func _personal_offer(state:Dictionary,npc_id:String,day:int) -> Dictionary:
    var rows = ContractSystem.offers_for_npc(state,npc_id,day)
    return rows[0] if not rows.is_empty() else {}

func run() -> void:
    var personal_npcs = ContractCatalog.personal_board_npcs()
    check(personal_npcs.size() == 4,"dev4 must expose exactly four authored personal contract boards")
    for npc_id in ["perron_radio","rubezh_commander","mechanics_storekeeper","lazaret_researcher"]:
        var board = ContractCatalog.board_for_npc(npc_id)
        check(not board.is_empty(),npc_id + " personal board missing")
        check(bool(board.get("personal",false)),npc_id + " board must be marked personal")
        check(TraderCatalog.trader_for_npc(npc_id) == "",npc_id + " personal board must not steal a trader interaction")
        var templates = ContractCatalog.personal_templates_for_npc(npc_id)
        check(templates.size() == 2,npc_id + " must own a two-step personal chain")
        if templates.size() == 2:
            check(int(templates[0].get("chain_step",0)) == 1,npc_id + " first personal stage must be step 1")
            check(int(templates[1].get("chain_step",0)) == 2,npc_id + " second personal stage must be step 2")
            check(str(templates[0].get("chain_id","")) == str(templates[1].get("chain_id","")),npc_id + " personal stages must share one chain id")
    for faction_id in FactionCatalog.ids():
        for template in ContractCatalog.templates_for_faction(faction_id):
            check(str(template.get("owner_npc_id","")) == "",faction_id + " general board leaked a personal template")

    # Perron chain: personal offers are separate from the faction board and step 2 unlocks only after step 1 completion.
    var perron = _fresh_with_rep("perron",25,1)
    var step1 = _personal_offer(perron,"perron_radio",1)
    check(str(step1.get("template_id","")) == "perron_radio_backup_power","Perron personal chain did not start at authored step 1")
    check(ContractSystem.offers_for_board(perron,"perron","perron_radio",1).size() == 1,"personal board offer filter failed")
    for row in ContractSystem.offers_for_board(perron,"perron","perron_steward",1):
        check(str(row.get("owner_npc_id","")) == "","general Perron board exposed a personal offer")
    var accepted1 = ContractSystem.accept(perron,str(step1.get("id","")),1)
    check(bool(accepted1.get("ok",false)),"Perron personal step 1 could not be accepted")
    var active1 = accepted1.get("contract",{})
    check(int(active1.get("deadline_day",0)) == 5,"personal active deadline must be acceptance day + authored lifetime")
    check(ContractSystem.active_for_board(perron,"perron","perron_radio").size() == 1,"personal active contract missing from owner board")
    check(ContractSystem.active_for_board(perron,"perron","perron_steward").is_empty(),"general board must not claim a personal active contract")
    check(ContractSystem.can_complete(active1,{"repair_kit":1,"scrap":5},{}),"Perron personal delivery requirements should accept authored kit")
    check(not ContractSystem.can_complete(active1,{"repair_kit":1,"scrap":4},{}),"Perron personal delivery completed with insufficient materials")
    var attitude_before_complete = int(FactionNpcState.record(perron,"perron_radio",1).get("attitude",0))
    var done1 = ContractSystem.complete(perron,str(active1.get("id","")),2)
    check(bool(done1.get("ok",false)),"Perron personal step 1 completion failed")
    check(bool(done1.get("personal",false)),"personal completion result lost personal marker")
    check(str(done1.get("owner_npc_id","")) == "perron_radio","personal completion result lost owner")
    check(int(FactionNpcState.record(perron,"perron_radio",2).get("attitude",0)) > attitude_before_complete,"personal completion must improve owner attitude")
    ContractSystem.refresh_offers(perron,2,false)
    var step2 = _personal_offer(perron,"perron_radio",2)
    check(str(step2.get("template_id","")) == "perron_radio_dead_frequency","Perron personal step 2 did not unlock after step 1")
    var accepted2 = ContractSystem.accept(perron,str(step2.get("id","")),2)
    check(bool(accepted2.get("ok",false)),"Perron personal step 2 could not be accepted")
    var active2 = accepted2.get("contract",{})
    check(not ContractSystem.can_complete(active2,{},{}),"personal discovery step completed before POI discovery")
    check(ContractSystem.can_complete(active2,{}, {"district_police":true}),"personal discovery step ignored discovered POI")
    var done2 = ContractSystem.complete(perron,str(active2.get("id","")),3)
    check(bool(done2.get("ok",false)),"Perron personal step 2 completion failed")
    check(str(done2.get("opened_route","")) == "route_perron_warning_net","personal chain final did not create persistent world route")
    check(str(perron.get("world_routes",{}).get("route_perron_warning_net",{}).get("state","")) == "open","personal world route not stored")
    ContractSystem.refresh_offers(perron,20,true)
    check(ContractSystem.offers_for_npc(perron,"perron_radio",20).is_empty(),"completed personal chain must not restart")

    # Deadline failure has explicit faction/resource/personal consequences and history, then cooldown prevents instant re-offer.
    var rubezh = _fresh_with_rep("rubezh",25,1)
    var r_offer = _personal_offer(rubezh,"rubezh_commander",1)
    check(str(r_offer.get("template_id","")) == "rubezh_commander_missing_post","Rubezh personal step 1 missing")
    var r_accept = ContractSystem.accept(rubezh,str(r_offer.get("id","")),1)
    check(bool(r_accept.get("ok",false)),"Rubezh personal deadline fixture could not accept")
    var r_contract = r_accept.get("contract",{})
    var r_deadline = int(r_contract.get("deadline_day",0))
    var r_rep_before = FactionEconomy.reputation(rubezh,"rubezh")
    var r_sec_before = float(rubezh["factions"]["rubezh"]["resources"]["security"])
    var r_att_before = int(FactionNpcState.record(rubezh,"rubezh_commander",1).get("attitude",0))
    check(ContractSystem.daily_tick(rubezh,r_deadline).is_empty(),"contract must remain valid through the end of its deadline day")
    var deadline_events = ContractSystem.daily_tick(rubezh,r_deadline + 1)
    check(deadline_events.size() == 1,"expired personal contract must emit one day event")
    check(str(deadline_events[0].get("status","")) == "failed","deadline event status must be failed")
    check(ContractSystem.active_for_npc(rubezh,"rubezh_commander").is_empty(),"failed personal contract remained active")
    check(FactionEconomy.reputation(rubezh,"rubezh") == r_rep_before - 4,"deadline failure reputation penalty mismatch")
    check(float(rubezh["factions"]["rubezh"]["resources"]["security"]) < r_sec_before,"deadline failure must damage relevant settlement resource")
    check(int(FactionNpcState.record(rubezh,"rubezh_commander",r_deadline + 1).get("attitude",0)) == r_att_before - 7,"deadline failure personal attitude penalty mismatch")
    check(str(rubezh.get("contract_history",[])[-1].get("status","")) == "failed","deadline failure missing persistent history")
    check(ContractSystem.offers_for_npc(rubezh,"rubezh_commander",r_deadline + 1).is_empty(),"failed personal contract reappeared without cooldown")

    # Explicit abandon penalties apply only to authored personal work; old general contract behavior remains untouched.
    var mechanics = _fresh_with_rep("mechanics",25,1)
    var m_offer = _personal_offer(mechanics,"mechanics_storekeeper",1)
    var m_accept = ContractSystem.accept(mechanics,str(m_offer.get("id","")),1)
    check(bool(m_accept.get("ok",false)),"Mechanics personal abandon fixture could not accept")
    var m_rep_before = FactionEconomy.reputation(mechanics,"mechanics")
    var m_att_before = int(FactionNpcState.record(mechanics,"mechanics_storekeeper",1).get("attitude",0))
    var abandoned = ContractSystem.abandon_with_result(mechanics,str(m_accept.get("contract",{}).get("id","")),2)
    check(bool(abandoned.get("ok",false)),"personal abandon mutation failed")
    check(FactionEconomy.reputation(mechanics,"mechanics") == m_rep_before - 1,"personal abandon reputation penalty mismatch")
    check(int(FactionNpcState.record(mechanics,"mechanics_storekeeper",2).get("attitude",0)) == m_att_before - 4,"personal abandon attitude penalty mismatch")
    check(str(mechanics.get("contract_history",[])[-1].get("status","")) == "abandoned","personal abandon history missing")

    # An ignored personal offer actually disappears for the history cooldown instead of instantly recreating itself.
    var lazaret_expiry = _fresh_with_rep("lazaret",25,1)
    var l_offer = _personal_offer(lazaret_expiry,"lazaret_researcher",1)
    check(int(l_offer.get("offer_expires_day",0)) == 3,"personal offer authored two-day window mismatch")
    ContractSystem.refresh_offers(lazaret_expiry,4,false)
    check(ContractSystem.offers_for_npc(lazaret_expiry,"lazaret_researcher",4).is_empty(),"ignored personal offer must disappear after expiration")
    check(str(lazaret_expiry.get("contract_history",[])[-1].get("status","")) == "offer_expired","ignored personal offer expiration not persisted")
    ContractSystem.refresh_offers(lazaret_expiry,9,false)
    check(not ContractSystem.offers_for_npc(lazaret_expiry,"lazaret_researcher",9).is_empty(),"expired personal offer did not return after cooldown")

    # If the named owner disappears/dies, an active personal contract is cancelled without blaming the player.
    var owner_loss = _fresh_with_rep("lazaret",25,1)
    var owner_offer = _personal_offer(owner_loss,"lazaret_researcher",1)
    var owner_accept = ContractSystem.accept(owner_loss,str(owner_offer.get("id","")),1)
    check(bool(owner_accept.get("ok",false)),"owner-loss personal fixture could not accept")
    var owner_rep_before = FactionEconomy.reputation(owner_loss,"lazaret")
    FactionNpcState.set_status(owner_loss,"lazaret_researcher","missing",1,"Ушёл на внешний вызов и не вернулся.")
    var owner_events = ContractSystem.daily_tick(owner_loss,2)
    check(owner_events.size() == 1 and str(owner_events[0].get("status","")) == "cancelled","missing owner must cancel personal work")
    check(FactionEconomy.reputation(owner_loss,"lazaret") == owner_rep_before,"owner disappearance must not penalize player reputation")
    check(str(owner_loss.get("contract_history",[])[-1].get("status","")) == "cancelled_owner_unavailable","owner cancellation history status mismatch")

    # Nested schema remains save-compatible: JSON + faction sanitizer + contract sanitizer keep personal active/deadline state.
    var saved = _fresh_with_rep("mechanics",25,7)
    var save_offer = _personal_offer(saved,"mechanics_storekeeper",7)
    var save_accept = ContractSystem.accept(saved,str(save_offer.get("id","")),7)
    check(bool(save_accept.get("ok",false)),"personal save fixture could not accept")
    var save_id = str(save_accept.get("contract",{}).get("id",""))
    var save_deadline = int(save_accept.get("contract",{}).get("deadline_day",0))
    var decoded = JSON.parse_string(JSON.stringify(saved))
    var roundtrip = FactionEconomy.sanitize_state(decoded)
    ContractSystem.ensure_state(roundtrip,7)
    var restored = ContractSystem.contract_by_id(roundtrip,save_id)
    check(not restored.is_empty(),"personal active contract lost across schema-122 nested roundtrip")
    check(int(restored.get("deadline_day",0)) == save_deadline,"personal deadline lost across schema-122 nested roundtrip")
    check(str(restored.get("owner_npc_id","")) == "mechanics_storekeeper","personal owner lost across nested roundtrip")

    print("PERSONAL CONTRACTS 1.23-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
