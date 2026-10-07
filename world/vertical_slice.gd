extends RefCounted
const SettlementCrisis = preload("res://world/settlement_crisis.gd")

# OSTATOK 1.23.0-dev15 — vertical slice state retained; sandbox route consequences remain owned by normal routes/markets/NPCs.
# This is not a global story goal and not a parallel quest generator. It only makes
# a fresh game's first 2–4 hour systemic loop legible by connecting systems that
# already exist: settlement shortage -> named NPC/board -> supply incident ->
# High Risk medical run -> delivery -> visible settlement recovery.
const FACTION_ID = "lazaret"
const SETTLEMENT_ID = "settlement_lazaret"
const DOCTOR_NPC_ID = "lazaret_doctor"
const CRISIS_TEMPLATE_ID = "crisis_lazaret_medicine"
const HIGH_RISK_POI_ID = "regional_clinical_complex_4"
const INITIAL_MEDICINE = 26.0
const CRISIS_OFFER_GRACE_DAYS = 30
const POSTRUN_HUD_DAYS = 2

static func default_state() -> Dictionary:
    return {
        "enabled":false,
        "initialized":false,
        "started_day":0,
        "visited_settlement":false,
        "met_doctor":false,
        "supply_scheduled":false,
        "supply_seen":false,
        "supply_resolved":false,
        "supply_outcome":"",
        "field_reserve_issued":false,
        "field_reserve_day":0,
        "clinical_incapacitations":0,
        "last_incapacitation_day":0,
        "last_incapacitation_floor":0,
        "recovery_pending":false,
        "recovery_aid_issued":false,
        "recovery_aid_day":0,
        "clinical_discovered":false,
        "clinical_cargo_secured":false,
        "crisis_contract_completed":false,
        "shortage_resolved":false,
        "completed":false,
        "completed_day":0,
        "completion_feedback_issued":false,
        "completion_feedback_day":0,
        "doctor_debrief_seen":false,
        "doctor_debrief_day":0
    }

static func sanitize_state(raw) -> Dictionary:
    var clean = default_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    clean["enabled"] = bool(raw.get("enabled",false))
    clean["initialized"] = bool(raw.get("initialized",false))
    clean["started_day"] = max(0,int(raw.get("started_day",0)))
    for key in ["visited_settlement","met_doctor","supply_scheduled","supply_seen","supply_resolved","field_reserve_issued","recovery_pending","recovery_aid_issued","clinical_discovered","clinical_cargo_secured","crisis_contract_completed","shortage_resolved","completed","completion_feedback_issued","doctor_debrief_seen"]:
        clean[key] = bool(raw.get(key,false))
    var outcome = str(raw.get("supply_outcome",""))
    clean["supply_outcome"] = outcome if outcome in ["","recovered","lost"] else ""
    clean["field_reserve_day"] = max(0,int(raw.get("field_reserve_day",0)))
    clean["clinical_incapacitations"] = clamp(int(raw.get("clinical_incapacitations",0)),0,99)
    clean["last_incapacitation_day"] = max(0,int(raw.get("last_incapacitation_day",0)))
    clean["last_incapacitation_floor"] = clamp(int(raw.get("last_incapacitation_floor",0)),0,9)
    clean["recovery_aid_day"] = max(0,int(raw.get("recovery_aid_day",0)))
    clean["completed_day"] = max(0,int(raw.get("completed_day",0)))
    clean["completion_feedback_day"] = max(0,int(raw.get("completion_feedback_day",0)))
    clean["doctor_debrief_day"] = max(0,int(raw.get("doctor_debrief_day",0)))
    if clean["clinical_cargo_secured"] or clean["completed"]:
        clean["recovery_pending"] = false
    if clean["completed"]:
        clean["enabled"] = false
    return clean

static func ensure_state(state:Dictionary) -> void:
    state["vertical_slice"] = sanitize_state(state.get("vertical_slice",{}))

static func record(state:Dictionary) -> Dictionary:
    ensure_state(state)
    return state["vertical_slice"].duplicate(true)

static func active(state:Dictionary) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    return bool(rec.get("enabled",false)) and not bool(rec.get("completed",false))

static func setup_new_game(state:Dictionary,world_day:int) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    if bool(rec.get("initialized",false)):
        return false
    rec = default_state()
    rec["enabled"] = true
    rec["initialized"] = true
    rec["started_day"] = max(1,world_day)
    state["vertical_slice"] = rec
    # Fresh games deliberately begin with one real but recoverable shortage so the
    # settlement economy is visible immediately. Existing saves never pass here.
    if state.get("factions",{}).has(FACTION_ID):
        var faction = state["factions"][FACTION_ID]
        var resources = faction.get("resources",{})
        resources["medicine"] = min(float(resources.get("medicine",INITIAL_MEDICINE)),INITIAL_MEDICINE)
        faction["resources"] = resources
        state["factions"][FACTION_ID] = faction
    return true

static func mark_settlement_visited(state:Dictionary) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    if not bool(rec.get("enabled",false)) or bool(rec.get("visited_settlement",false)):
        return false
    rec["visited_settlement"] = true
    state["vertical_slice"] = rec
    return true

static func mark_doctor_met(state:Dictionary,world_day:int) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    if not bool(rec.get("enabled",false)):
        return false
    var changed = not bool(rec.get("met_doctor",false))
    rec["visited_settlement"] = true
    rec["met_doctor"] = true
    # The first supply incident is pulled forward only after the player has seen the
    # shortage and spoken to the settlement. Its faction is still chosen by the real
    # need-scoring system; Lazaret's medical shortage naturally makes it the top need.
    var event_state = state.get("supply_events",{})
    if typeof(event_state) == TYPE_DICTIONARY:
        var active_event = event_state.get("active",{})
        var history = event_state.get("history",[])
        if (typeof(active_event) != TYPE_DICTIONARY or active_event.is_empty()) and (typeof(history) != TYPE_ARRAY or history.is_empty()):
            var next_day = max(1,world_day) + 1
            event_state["next_event_day"] = min(int(event_state.get("next_event_day",next_day)),next_day)
            state["supply_events"] = event_state
            rec["supply_scheduled"] = true
    _pin_crisis_offer(state,world_day)
    state["vertical_slice"] = rec
    return changed

static func _contract_completed(state:Dictionary,template_id:String) -> bool:
    var history = state.get("contract_history",[])
    if typeof(history) != TYPE_ARRAY:
        return false
    for row in history:
        if typeof(row) == TYPE_DICTIONARY and str(row.get("template_id","")) == template_id and str(row.get("status","")) == "completed":
            return true
    return false

static func crisis_contract_active(state:Dictionary) -> bool:
    var active_contracts = state.get("contracts",{}).get("active",{})
    if typeof(active_contracts) != TYPE_DICTIONARY:
        return false
    for row in active_contracts.values():
        if typeof(row) == TYPE_DICTIONARY and str(row.get("template_id","")) == CRISIS_TEMPLATE_ID:
            return true
    return false

static func _pin_crisis_offer(state:Dictionary,world_day:int) -> void:
    # The emergency order is a real crisis-board offer, but a successful first
    # convoy can lift medicine above shortage before a curious player accepts it.
    # Preserve that already-generated offer for the onboarding window instead of
    # inventing a parallel quest or changing the settlement's recovered resources.
    var contracts = state.get("contracts",{})
    if typeof(contracts) != TYPE_DICTIONARY:
        return
    var offers = contracts.get("offers",{})
    if typeof(offers) != TYPE_DICTIONARY:
        return
    var rows = offers.get(FACTION_ID,[])
    if typeof(rows) != TYPE_ARRAY:
        return
    var pinned_until = max(1,world_day) + CRISIS_OFFER_GRACE_DAYS
    var changed = false
    for row in rows:
        if typeof(row) != TYPE_DICTIONARY or str(row.get("template_id","")) != CRISIS_TEMPLATE_ID:
            continue
        row["offer_expires_day"] = max(int(row.get("offer_expires_day",pinned_until)),pinned_until)
        changed = true
    if changed:
        offers[FACTION_ID] = rows
        contracts["offers"] = offers
        state["contracts"] = contracts

static func _refresh_supply_milestones(state:Dictionary,rec:Dictionary) -> void:
    # The vertical slice is about the *first* Lazaret supply incident. Once that
    # incident is closed its consequence is frozen; later world events must not
    # rewrite the onboarding outcome or retroactively unlock the recovery reserve.
    if bool(rec.get("supply_resolved",false)):
        return
    var started_day = max(1,int(rec.get("started_day",1)))
    var event_state = state.get("supply_events",{})
    if typeof(event_state) != TYPE_DICTIONARY:
        return
    var active_event = event_state.get("active",{})
    if typeof(active_event) == TYPE_DICTIONARY and not active_event.is_empty():
        if str(active_event.get("faction","")) == FACTION_ID and int(active_event.get("created_day",0)) >= started_day:
            rec["supply_seen"] = true
    var history = event_state.get("history",[])
    if typeof(history) != TYPE_ARRAY:
        return
    for row in history:
        if typeof(row) != TYPE_DICTIONARY:
            continue
        if str(row.get("faction","")) != FACTION_ID or int(row.get("created_day",0)) < started_day:
            continue
        var outcome = str(row.get("outcome",""))
        if not outcome in ["recovered","lost"]:
            continue
        rec["supply_seen"] = true
        rec["supply_resolved"] = true
        rec["supply_outcome"] = outcome
        return


static func field_reserve_ready(state:Dictionary) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    return bool(rec.get("enabled",false)) and bool(rec.get("supply_resolved",false)) and str(rec.get("supply_outcome","")) == "recovered" and not bool(rec.get("field_reserve_issued",false))

static func mark_field_reserve_issued(state:Dictionary,world_day:int) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    if not bool(rec.get("enabled",false)) or not bool(rec.get("supply_resolved",false)) or str(rec.get("supply_outcome","")) != "recovered" or bool(rec.get("field_reserve_issued",false)):
        return false
    rec["field_reserve_issued"] = true
    rec["field_reserve_day"] = max(1,world_day)
    state["vertical_slice"] = rec
    return true

static func clinical_recovery_aid_ready(state:Dictionary) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    return bool(rec.get("enabled",false)) and bool(rec.get("recovery_pending",false)) and int(rec.get("clinical_incapacitations",0)) == 1 and not bool(rec.get("recovery_aid_issued",false)) and not bool(rec.get("clinical_cargo_secured",false))

static func mark_clinical_recovery_aid_issued(state:Dictionary,world_day:int) -> bool:
    if not clinical_recovery_aid_ready(state):
        return false
    var rec = state["vertical_slice"]
    rec["recovery_aid_issued"] = true
    rec["recovery_aid_day"] = max(1,world_day)
    state["vertical_slice"] = rec
    return true

static func medical_cargo_ready(inventory_counts:Dictionary) -> bool:
    return _has_medical_cargo(inventory_counts)


static func clinical_first_run_balance_active(state:Dictionary) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    if not bool(rec.get("enabled",false)) or bool(rec.get("completed",false)):
        return false
    # Once the first Lazaret supply beat is resolved, keep the authored first-run
    # threat budget stable until the vertical slice is actually completed. Do not
    # key this to the current crisis-contract status: an expiry/re-offer while the
    # player is inside the clinic must never make already-cleared enemies "reappear"
    # simply because an unloaded floor falls back to its full late-game count.
    return bool(rec.get("met_doctor",false)) and bool(rec.get("supply_resolved",false))

static func clinical_ground_enemy_count(state:Dictionary,cell_offset:Vector2i,base_count:int) -> int:
    var base = max(0,base_count)
    if not clinical_first_run_balance_active(state):
        return base
    # Only the authored reception/entry sector is on the mandatory first-run path.
    # Side wings keep their full High Risk population so the whole campus is not
    # globally nerfed by onboarding.
    if cell_offset == Vector2i(0,0):
        return min(base,5)
    return base

static func clinical_floor_enemy_count(state:Dictionary,floor_index:int,base_count:int) -> int:
    var base = max(0,base_count)
    if not clinical_first_run_balance_active(state):
        return base
    match floor_index:
        2:
            return min(base,7)
        3:
            return min(base,9)
    return base

static func clinical_readiness(inventory_counts:Dictionary) -> Dictionary:
    # Advisory only: it never blocks the player. The values describe the starter PM
    # route after the recovered convoy reserve and are intentionally conservative.
    var ammo = max(0,int(inventory_counts.get("ammo_9x18",0)))
    var treatment = max(0,int(inventory_counts.get("bandage",0))) + max(0,int(inventory_counts.get("sterile_bandage",0)))
    var water = max(0,int(inventory_counts.get("water",0)))
    return {
        "ammo":ammo,"ammo_target":32,
        "treatment":treatment,"treatment_target":2,
        "water":water,"water_target":1,
        "ready":ammo >= 32 and treatment >= 2 and water >= 1
    }

static func clinical_readiness_text(inventory_counts:Dictionary) -> String:
    var r = clinical_readiness(inventory_counts)
    return "БК %d/%d • лечение %d/%d • вода %d/%d" % [
        int(r["ammo"]),int(r["ammo_target"]),
        int(r["treatment"]),int(r["treatment_target"]),
        int(r["water"]),int(r["water_target"])
    ]

static func mark_clinical_incapacitation(state:Dictionary,world_day:int,floor_index:int,inventory_counts:Dictionary = {}) -> Dictionary:
    ensure_state(state)
    var rec = state["vertical_slice"]
    if not bool(rec.get("enabled",false)) or bool(rec.get("completed",false)):
        return {}
    if not bool(rec.get("met_doctor",false)) or not bool(rec.get("supply_resolved",false)):
        return {}
    rec["clinical_discovered"] = true
    rec["clinical_cargo_secured"] = _has_medical_cargo(inventory_counts)
    rec["clinical_incapacitations"] = clamp(int(rec.get("clinical_incapacitations",0)) + 1,0,99)
    rec["last_incapacitation_day"] = max(1,world_day)
    rec["last_incapacitation_floor"] = clamp(floor_index,1,9)
    rec["recovery_pending"] = not bool(rec.get("clinical_cargo_secured",false))
    state["vertical_slice"] = rec
    return {
        "count":int(rec["clinical_incapacitations"]),
        "recovery_pending":bool(rec["recovery_pending"]),
        "cargo_secured":bool(rec["clinical_cargo_secured"]),
        "aid_ready":clinical_recovery_aid_ready(state)
    }

static func _has_medical_cargo(inventory_counts:Dictionary) -> bool:
    # Match the real crisis contract alternatives exactly. The clinical core has
    # three authored caches using a profile that guarantees these medical stacks,
    # so the route never tells the player to return before the order can be fulfilled.
    var field_option = int(inventory_counts.get("bandage",0)) >= 8 and int(inventory_counts.get("antiseptic",0)) >= 2
    var sterile_option = int(inventory_counts.get("sterile_bandage",0)) >= 4 and int(inventory_counts.get("painkillers",0)) >= 3
    return field_option or sterile_option

static func refresh_progress(state:Dictionary,world_day:int,at_lazaret:bool,clinical_discovered:bool,inventory_counts:Dictionary) -> Dictionary:
    ensure_state(state)
    var rec = state["vertical_slice"]
    if not bool(rec.get("enabled",false)):
        return rec.duplicate(true)
    if at_lazaret:
        rec["visited_settlement"] = true
    if bool(rec.get("met_doctor",false)) and not bool(rec.get("crisis_contract_completed",false)):
        _pin_crisis_offer(state,world_day)
    _refresh_supply_milestones(state,rec)
    if clinical_discovered:
        rec["clinical_discovered"] = true
    # Completion must be recognized before re-evaluating the live backpack. The UI
    # removes delivered medicine immediately before ContractSystem.complete(); if we
    # checked inventory first, a legitimate turn-in would clear the cargo milestone
    # in the same frame and prevent the slice from ever closing. Once the real crisis
    # delivery is in contract history, the delivered cargo is by definition secured.
    if _contract_completed(state,CRISIS_TEMPLATE_ID):
        rec["crisis_contract_completed"] = true
        rec["clinical_cargo_secured"] = true
        rec["recovery_pending"] = false
    elif bool(rec.get("clinical_discovered",false)):
        # Before actual turn-in this stays intentionally non-sticky: if the player
        # consumes required medicine in the clinic, the objective must return to
        # gathering rather than point at an impossible delivery.
        rec["clinical_cargo_secured"] = _has_medical_cargo(inventory_counts)
        if bool(rec.get("clinical_cargo_secured",false)):
            rec["recovery_pending"] = false
    if bool(rec.get("recovery_pending",false)) and not at_lazaret:
        # Leaving Lazaret after evacuation is the player's explicit retry. The
        # failure history stays recorded, but the temporary regroup objective clears.
        rec["recovery_pending"] = false
    var medicine_stage = SettlementCrisis.resource_stage(state,FACTION_ID,"medicine")
    if SettlementCrisis.stage_rank(medicine_stage) < SettlementCrisis.stage_rank("shortage"):
        rec["shortage_resolved"] = true
    if bool(rec.get("met_doctor",false)) and bool(rec.get("supply_resolved",false)) and bool(rec.get("clinical_cargo_secured",false)) and bool(rec.get("crisis_contract_completed",false)) and bool(rec.get("shortage_resolved",false)):
        rec["completed"] = true
        rec["enabled"] = false
        if int(rec.get("completed_day",0)) <= 0:
            rec["completed_day"] = max(1,world_day)
    state["vertical_slice"] = rec
    return rec.duplicate(true)


static func completion_feedback_ready(state:Dictionary) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    return bool(rec.get("completed",false)) and not bool(rec.get("completion_feedback_issued",false))

static func mark_completion_feedback_issued(state:Dictionary,world_day:int) -> bool:
    if not completion_feedback_ready(state):
        return false
    var rec = state["vertical_slice"]
    rec["completion_feedback_issued"] = true
    rec["completion_feedback_day"] = max(1,world_day)
    state["vertical_slice"] = rec
    return true

static func doctor_debrief_ready(state:Dictionary) -> bool:
    ensure_state(state)
    var rec = state["vertical_slice"]
    return bool(rec.get("completed",false)) and not bool(rec.get("doctor_debrief_seen",false))

static func mark_doctor_debrief_seen(state:Dictionary,world_day:int) -> bool:
    if not doctor_debrief_ready(state):
        return false
    var rec = state["vertical_slice"]
    rec["doctor_debrief_seen"] = true
    rec["doctor_debrief_day"] = max(1,world_day)
    state["vertical_slice"] = rec
    return true

static func settlement_recovery_summary(state:Dictionary) -> Dictionary:
    ensure_state(state)
    var value = SettlementCrisis.resource_value(state,FACTION_ID,"medicine")
    var stage = SettlementCrisis.resource_stage(state,FACTION_ID,"medicine")
    var note = "Первый аварийный заказ закрыт, но текущий медрезерв снова в кризисе."
    if stage == "stable":
        note = "Медрезерв вернулся к штатному уровню; аптечный склад снова работает без дефицитного режима."
    elif stage == "strain":
        note = "Аварийный дефицит снят; аптечный склад работает, но резерв пока берегут."
    elif stage == "shortage":
        note = "Первый аварийный заказ закрыт, но текущий медрезерв снова ушёл в дефицит."
    return {"stage":stage,"value":value,"note":note}

static func objective(state:Dictionary,world_day:int,at_lazaret:bool,clinical_discovered:bool,inventory_counts:Dictionary) -> Dictionary:
    var rec = refresh_progress(state,world_day,at_lazaret,clinical_discovered,inventory_counts)
    if bool(rec.get("completed",false)):
        var completed_day = int(rec.get("completed_day",0))
        if completed_day > 0 and world_day < completed_day + POSTRUN_HUD_DAYS:
            if not bool(rec.get("doctor_debrief_seen",false)):
                return {"title":"ПЕРВЫЙ ЦИКЛ ЗАВЕРШЁН","sub":"Миронова готова подвести итог • дальше цель выбираете вы"}
            return {"title":"СВОБОДНЫЙ МАРШРУТ","sub":"Первый цикл закрыт • M — выберите следующую вылазку"}
        return {}
    if not bool(rec.get("enabled",false)):
        return {}
    if not bool(rec.get("visited_settlement",false)):
        return {"title":"ДОБРАТЬСЯ ДО ЛАЗАРЕТА","sub":"M — полевой маршрут отмечен на карте"}
    if not bool(rec.get("met_doctor",false)):
        return {"title":"НАЙТИ ДОКТОРА МИРОНОВУ","sub":"Главная площадь • доска снабжения"}
    var active_event = state.get("supply_events",{}).get("active",{})
    if not bool(rec.get("supply_resolved",false)) and typeof(active_event) == TYPE_DICTIONARY and not active_event.is_empty() and str(active_event.get("faction","")) == FACTION_ID:
        return {"title":"ОТВЕТИТЬ НА SOS ЛАЗАРЕТА","sub":"M — аварийный сигнал отмечен на карте"}
    var contract_done = bool(rec.get("crisis_contract_completed",false))
    var contract_active = crisis_contract_active(state)
    if not contract_active and not contract_done:
        return {"title":"ВЗЯТЬ АВАРИЙНЫЙ ЗАКАЗ","sub":"Медрезерв в дефиците • поговорите с Мироновой"}
    if not bool(rec.get("supply_resolved",false)):
        return {"title":"ПОДГОТОВИТЬСЯ К РЕЙСУ","sub":"Сигнал ожидается в ближайшие сутки • проверьте воду, лечение и боезапас"}
    if bool(rec.get("recovery_pending",false)) and at_lazaret and not bool(rec.get("clinical_cargo_secured",false)):
        var attempts = int(rec.get("clinical_incapacitations",1))
        var note = "Эвакуация заняла 6 ч • проверьте лечение, воду и БК • M — клиника"
        if attempts > 1:
            note = "Повторная эвакуация • помощь больше не пополняется • M — клиника"
        return {"title":"ПЕРЕПРОВЕРИТЬ СНАРЯЖЕНИЕ","sub":note}
    if not bool(rec.get("clinical_discovered",false)):
        var readiness = clinical_readiness(inventory_counts)
        var prep_note = clinical_readiness_text(inventory_counts) + " • M — маршрут"
        if str(rec.get("supply_outcome","")) == "lost" and not bool(readiness.get("ready",false)):
            prep_note = "Рейс потерян • " + prep_note
        return {"title":"РАЗВЕДАТЬ КЛИНИЧЕСКИЙ КОМПЛЕКС №4","sub":prep_note}
    if not bool(rec.get("clinical_cargo_secured",false)):
        return {"title":"ДОБЫТЬ МЕДИЦИНСКИЙ РЕЗЕРВ","sub":"Ищите стерильные материалы в глубине комплекса"}
    if not contract_done:
        if at_lazaret:
            return {"title":"СДАТЬ АВАРИЙНЫЙ ЗАКАЗ","sub":"Доктор Миронова • доска снабжения"}
        return {"title":"ВЕРНУТЬСЯ В ЛАЗАРЕТ","sub":"Сдать аварийный заказ Мироновой"}
    if not bool(rec.get("shortage_resolved",false)):
        return {"title":"СТАБИЛИЗИРОВАТЬ МЕДРЕЗЕРВ","sub":"Торговля и поставки поднимают запасы поселения"}
    return {"title":"ПЕРВЫЙ ЦИКЛ ЗАВЕРШЁН","sub":"Лазарет вышел из дефицита"}

static func marker_target(state:Dictionary,world_day:int,at_lazaret:bool,clinical_discovered:bool,inventory_counts:Dictionary) -> Dictionary:
    var rec = refresh_progress(state,world_day,at_lazaret,clinical_discovered,inventory_counts)
    # The authored route is over. Keep the completion HUD for a short handoff, but
    # remove system map pins immediately so free exploration really becomes free.
    if bool(rec.get("completed",false)):
        return {}
    if not bool(rec.get("enabled",false)):
        return {}
    if not bool(rec.get("visited_settlement",false)) or bool(rec.get("clinical_cargo_secured",false)):
        return {"poi_id":SETTLEMENT_ID,"kind":"note","label":"ПОЛЕВОЙ МАРШРУТ • ЛАЗАРЕТ"}
    var active_event = state.get("supply_events",{}).get("active",{})
    if not bool(rec.get("supply_resolved",false)) and typeof(active_event) == TYPE_DICTIONARY and not active_event.is_empty() and str(active_event.get("faction","")) == FACTION_ID:
        return {}
    if not bool(rec.get("supply_resolved",false)):
        return {"poi_id":SETTLEMENT_ID,"kind":"note","label":"ПОЛЕВОЙ МАРШРУТ • ОЖИДАНИЕ РЕЙСА"}
    if bool(rec.get("recovery_pending",false)) and not bool(rec.get("clinical_cargo_secured",false)):
        return {"poi_id":HIGH_RISK_POI_ID,"kind":"danger","label":"ПОЛЕВОЙ МАРШРУТ • ПОВТОР КЛИНИКИ"}
    if bool(rec.get("met_doctor",false)) and (crisis_contract_active(state) or bool(rec.get("crisis_contract_completed",false))) and not bool(rec.get("clinical_cargo_secured",false)):
        return {"poi_id":HIGH_RISK_POI_ID,"kind":"danger","label":"ПОЛЕВОЙ МАРШРУТ • КЛИНИКА"}
    return {"poi_id":SETTLEMENT_ID,"kind":"note","label":"ПОЛЕВОЙ МАРШРУТ • ЛАЗАРЕТ"}
