extends RefCounted
const RegionalStability = preload("res://world/regional_stability.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const SettlementCrisis = preload("res://world/settlement_crisis.gd")

# 1.26-dev4 — persistent crisis-season lifecycle, pressure and frozen consequence ending.
# This state lives inside faction_state and is sanitized under the existing save schema 122.
# Pressure stays on canonical settlement resources; the final outcome is a one-shot snapshot, not a new progression gate.
const PHASE_DORMANT = "dormant"
const PHASE_ACTIVE = "crisis_season"
const PHASE_COMPLETE = "season_complete"
const DURATION_DAYS = 21
const HISTORY_LIMIT = 16
const RESOURCE_KEYS = ["food","medicine","technical","security"]
const PRESSURE = {
    "perron":{"food":0.55,"security":0.25},
    "rubezh":{"security":1.10,"technical":0.30},
    "mechanics":{"technical":1.10,"security":0.30},
    "lazaret":{"medicine":0.95,"food":0.30}
}
const PRESSURE_PRIMARY = {"perron":"food","rubezh":"security","mechanics":"technical","lazaret":"medicine"}
const CHECKPOINT_DAYS = [7,14]
const CHECKPOINT_PRIMARY = 3.0
const CHECKPOINT_SECONDARY = 1.5
const FACTION_OUTCOME_IDS = ["secure","strained","scarred","critical"]
const GLOBAL_OUTCOMES = {
    "cohesive":{"title":"ОБЩИЙ КОНТУР","text":"Все четыре поселения выдержали кризис как единая сеть. Дефициты остались локальными, а маршруты и резервы не разорвались."},
    "holding_network":{"title":"СЕТЬ УДЕРЖАНА","text":"Общий контур пережил три недели нагрузки. Несколько поселений вышли из сезона на пределе, но ни одно звено не пришлось бросить."},
    "fragile_balance":{"title":"ХРУПКОЕ РАВНОВЕСИЕ","text":"Регион удержался, но часть сети прошла через тяжёлые дефициты. Связи работают, однако запас прочности теперь заметно меньше."},
    "fractured_region":{"title":"РАЗОРВАННЫЙ КОНТУР","text":"Часть поселений пережила сезон только ценой глубоких провалов снабжения. Общая сеть сохранилась, но фактически работает отдельными плечами."},
    "survival_islands":{"title":"ОСТРОВА ВЫЖИВАНИЯ","text":"Кризисный сезон разорвал большую часть общего контура. Поселения выстояли не как система, а как отдельные острова, каждый на собственных остатках."}
}

static func default_state() -> Dictionary:
    return {
        "phase":PHASE_DORMANT,
        "started_day":0,
        "ends_day":0,
        "last_tick_day":0,
        "completion_day":0,
        "pressure_applied_day":0,
        "checkpoints":[],
        "hardship_days":{},
        "resource_minima":{},
        "outcome":{},
        "history":[]
    }

static func sanitize_state(raw) -> Dictionary:
    var clean = default_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    var phase = str(raw.get("phase",PHASE_DORMANT))
    if phase not in [PHASE_DORMANT,PHASE_ACTIVE,PHASE_COMPLETE]:
        phase = PHASE_DORMANT
    clean["phase"] = phase
    clean["started_day"] = max(0,int(raw.get("started_day",0)))
    clean["ends_day"] = max(0,int(raw.get("ends_day",0)))
    clean["last_tick_day"] = max(0,int(raw.get("last_tick_day",0)))
    clean["completion_day"] = max(0,int(raw.get("completion_day",0)))
    if phase == PHASE_ACTIVE:
        if int(clean["started_day"]) <= 0:
            return default_state()
        clean["ends_day"] = max(int(clean["started_day"]) + 1,int(clean["ends_day"]))
        clean["completion_day"] = 0
    elif phase == PHASE_COMPLETE:
        clean["started_day"] = max(1,int(clean["started_day"]))
        clean["ends_day"] = max(int(clean["started_day"]) + 1,int(clean["ends_day"]))
        clean["completion_day"] = max(int(clean["ends_day"]),int(clean["completion_day"]))
    else:
        clean["started_day"] = 0
        clean["ends_day"] = 0
        clean["last_tick_day"] = 0
        clean["completion_day"] = 0
    clean["pressure_applied_day"] = max(0,int(raw.get("pressure_applied_day",clean["started_day"])))
    if phase == PHASE_DORMANT:
        clean["pressure_applied_day"] = 0
    else:
        clean["pressure_applied_day"] = clamp(int(clean["pressure_applied_day"]),int(clean["started_day"]),max(int(clean["started_day"]),int(clean["ends_day"])))
    var raw_checkpoints = raw.get("checkpoints",[])
    if typeof(raw_checkpoints) == TYPE_ARRAY:
        for raw_day in raw_checkpoints:
            var checkpoint = int(raw_day)
            if checkpoint in CHECKPOINT_DAYS and checkpoint not in clean["checkpoints"]:
                clean["checkpoints"].append(checkpoint)
    var raw_hardship = raw.get("hardship_days",{})
    var raw_minima = raw.get("resource_minima",{})
    for faction_id in FactionCatalog.ids():
        var fid = str(faction_id)
        clean["hardship_days"][fid] = clampi(int(raw_hardship.get(fid,0)) if typeof(raw_hardship) == TYPE_DICTIONARY else 0,0,DURATION_DAYS)
        var minima = {}
        var src_minima = raw_minima.get(fid,{}) if typeof(raw_minima) == TYPE_DICTIONARY else {}
        for resource_id in RESOURCE_KEYS:
            minima[resource_id] = clamp(float(src_minima.get(resource_id,100.0)) if typeof(src_minima) == TYPE_DICTIONARY else 100.0,0.0,100.0)
        clean["resource_minima"][fid] = minima
    var raw_outcome = raw.get("outcome",{})
    if phase == PHASE_COMPLETE and typeof(raw_outcome) == TYPE_DICTIONARY:
        var outcome_id = str(raw_outcome.get("id",""))
        if GLOBAL_OUTCOMES.has(outcome_id):
            var faction_rows = {}
            var valid_outcome = true
            var incoming_factions = raw_outcome.get("factions",{})
            if typeof(incoming_factions) == TYPE_DICTIONARY:
                for faction_id in FactionCatalog.ids():
                    var fid = str(faction_id)
                    var src = incoming_factions.get(fid,{})
                    if typeof(src) != TYPE_DICTIONARY:
                        continue
                    var category = str(src.get("category","critical"))
                    if category not in FACTION_OUTCOME_IDS:
                        valid_outcome = false
                        break
                    faction_rows[fid] = {
                        "category":category,
                        "final_worst":clamp(float(src.get("final_worst",0.0)),0.0,100.0),
                        "min_seen":clamp(float(src.get("min_seen",0.0)),0.0,100.0),
                        "hardship_days":clampi(int(src.get("hardship_days",0)),0,DURATION_DAYS),
                        "supply_recovered":max(0,int(src.get("supply_recovered",0))),
                        "supply_lost":max(0,int(src.get("supply_lost",0)))
                    }
            if valid_outcome and faction_rows.size() == FactionCatalog.ids().size() and _global_outcome_id(faction_rows) == outcome_id:
                clean["outcome"] = {
                    "id":outcome_id,
                    "resolved_day":int(clean["completion_day"]),
                    "factions":faction_rows
                }
    var history = raw.get("history",[])
    if typeof(history) == TYPE_ARRAY:
        for row in history:
            if typeof(row) != TYPE_DICTIONARY:
                continue
            var event = str(row.get("event",""))
            if event not in ["started","completed"]:
                continue
            clean["history"].append({"day":max(1,int(row.get("day",1))),"event":event})
    while clean["history"].size() > HISTORY_LIMIT:
        clean["history"].remove_at(0)
    return clean

static func ensure_state(state:Dictionary) -> void:
    state["regional_endgame"] = sanitize_state(state.get("regional_endgame",{}))

static func phase(state:Dictionary) -> String:
    ensure_state(state)
    return str(state["regional_endgame"].get("phase",PHASE_DORMANT))

static func is_active(state:Dictionary) -> bool:
    return phase(state) == PHASE_ACTIVE

static func is_complete(state:Dictionary) -> bool:
    return phase(state) == PHASE_COMPLETE

static func can_start(state:Dictionary,world_day:int) -> Dictionary:
    ensure_state(state)
    var current = phase(state)
    if current == PHASE_ACTIVE:
        return {"ok":false,"reason":"already_active"}
    if current == PHASE_COMPLETE:
        return {"ok":false,"reason":"already_complete"}
    var readiness = RegionalStability.report(state,world_day)
    if not bool(readiness.get("infrastructure_ready",false)):
        return {"ok":false,"reason":"not_ready","readiness":readiness}
    if not bool(readiness.get("incident_clear",false)):
        return {"ok":false,"reason":"active_supply","readiness":readiness}
    return {"ok":true,"reason":"","readiness":readiness}

static func _initialize_metrics(state:Dictionary,row:Dictionary) -> void:
    row["hardship_days"] = {}
    row["resource_minima"] = {}
    for faction_id in FactionCatalog.ids():
        var fid = str(faction_id)
        row["hardship_days"][fid] = 0
        var resources = state.get("factions",{}).get(fid,{}).get("resources",{})
        var minima = {}
        for resource_id in RESOURCE_KEYS:
            minima[resource_id] = clamp(float(resources.get(resource_id,0.0)) if typeof(resources) == TYPE_DICTIONARY else 0.0,0.0,100.0)
        row["resource_minima"][fid] = minima

static func _adjust_resource(state:Dictionary,faction_id:String,resource_id:String,amount:float) -> void:
    if not state.get("factions",{}).has(faction_id) or resource_id not in RESOURCE_KEYS:
        return
    var rec = state["factions"][faction_id]
    var resources = rec.get("resources",{})
    if typeof(resources) != TYPE_DICTIONARY:
        return
    resources[resource_id] = clamp(float(resources.get(resource_id,0.0)) + amount,0.0,100.0)
    rec["resources"] = resources
    state["factions"][faction_id] = rec

static func _apply_pressure_day(state:Dictionary,row:Dictionary,season_day:int) -> Dictionary:
    var checkpoint = season_day in CHECKPOINT_DAYS and season_day not in row.get("checkpoints",[])
    for faction_id in PRESSURE.keys():
        var entries = PRESSURE[faction_id]
        for raw_resource_id in entries.keys():
            var resource_id = str(raw_resource_id)
            var drain = float(entries[resource_id])
            if checkpoint:
                drain += CHECKPOINT_PRIMARY if resource_id == str(PRESSURE_PRIMARY.get(faction_id,"")) else CHECKPOINT_SECONDARY
            _adjust_resource(state,str(faction_id),resource_id,-drain)
    if checkpoint:
        row["checkpoints"].append(season_day)
    for faction_id in FactionCatalog.ids():
        var fid = str(faction_id)
        var resources = state.get("factions",{}).get(fid,{}).get("resources",{})
        var minima = row.get("resource_minima",{}).get(fid,{})
        for resource_id in RESOURCE_KEYS:
            minima[resource_id] = min(float(minima.get(resource_id,100.0)),float(resources.get(resource_id,0.0)) if typeof(resources) == TYPE_DICTIONARY else 0.0)
        row["resource_minima"][fid] = minima
        var stage = str(SettlementCrisis.faction_status(state,fid).get("stage","crisis"))
        if SettlementCrisis.stage_rank(stage) >= SettlementCrisis.stage_rank("shortage"):
            row["hardship_days"][fid] = min(DURATION_DAYS,int(row["hardship_days"].get(fid,0)) + 1)
    return {"season_day":season_day,"checkpoint":checkpoint}

static func start(state:Dictionary,world_day:int) -> Dictionary:
    var allowed = can_start(state,world_day)
    if not bool(allowed.get("ok",false)):
        return allowed
    var day = max(1,world_day)
    var row = default_state()
    row["phase"] = PHASE_ACTIVE
    row["started_day"] = day
    row["ends_day"] = day + DURATION_DAYS
    row["last_tick_day"] = day
    row["pressure_applied_day"] = day
    row["history"] = [{"day":day,"event":"started"}]
    _initialize_metrics(state,row)
    state["regional_endgame"] = row
    return {"ok":true,"phase":PHASE_ACTIVE,"started_day":day,"ends_day":day + DURATION_DAYS,"duration":DURATION_DAYS}

static func days_left(state:Dictionary,world_day:int) -> int:
    ensure_state(state)
    if not is_active(state):
        return 0
    return max(0,int(state["regional_endgame"].get("ends_day",world_day)) - max(1,world_day))

static func _supply_counts(state:Dictionary,faction_id:String,started_day:int,completion_day:int) -> Dictionary:
    var recovered = 0
    var lost = 0
    var supply = state.get("supply_events",{})
    var history = supply.get("history",[]) if typeof(supply) == TYPE_DICTIONARY else []
    if typeof(history) == TYPE_ARRAY:
        for row in history:
            if typeof(row) != TYPE_DICTIONARY or str(row.get("faction","")) != faction_id:
                continue
            var closed_day = int(row.get("closed_day",0))
            if closed_day <= started_day or closed_day > completion_day:
                continue
            var outcome = str(row.get("outcome",""))
            if outcome == "recovered":
                recovered += 1
            elif outcome == "lost":
                lost += 1
    return {"recovered":recovered,"lost":lost}

static func _faction_outcome(state:Dictionary,row:Dictionary,faction_id:String) -> Dictionary:
    var resources = state.get("factions",{}).get(faction_id,{}).get("resources",{})
    var final_worst = 0.0
    if typeof(resources) == TYPE_DICTIONARY:
        final_worst = 100.0
        for resource_id in RESOURCE_KEYS:
            final_worst = min(final_worst,float(resources.get(resource_id,0.0)))
    var minima = row.get("resource_minima",{}).get(faction_id,{})
    var min_seen = 100.0
    if typeof(minima) == TYPE_DICTIONARY:
        for resource_id in RESOURCE_KEYS:
            min_seen = min(min_seen,float(minima.get(resource_id,100.0)))
    var hardship = clampi(int(row.get("hardship_days",{}).get(faction_id,0)),0,DURATION_DAYS)
    var severity = 0
    if final_worst < SettlementCrisis.SHORTAGE_MIN:
        severity = 3
    elif final_worst < SettlementCrisis.STRAIN_MIN:
        severity = 2
    elif final_worst < SettlementCrisis.STABLE_MIN:
        severity = 1
    var hardship_severity = 0 if hardship <= 2 else (1 if hardship <= 7 else (2 if hardship <= 14 else 3))
    severity = max(severity,hardship_severity)
    var minimum_severity = 0 if min_seen >= SettlementCrisis.STRAIN_MIN else (1 if min_seen >= SettlementCrisis.SHORTAGE_MIN else 2)
    severity = max(severity,minimum_severity)
    var supply = _supply_counts(state,faction_id,int(row.get("started_day",1)),int(row.get("completion_day",row.get("ends_day",1))))
    var recovered = int(supply.get("recovered",0))
    var lost = int(supply.get("lost",0))
    if lost - recovered >= 2:
        severity = min(3,severity + 1)
    elif recovered - lost >= 2 and final_worst >= SettlementCrisis.STRAIN_MIN:
        severity = max(0,severity - 1)
    return {
        "category":FACTION_OUTCOME_IDS[severity],"final_worst":final_worst,"min_seen":min_seen,
        "hardship_days":hardship,"supply_recovered":recovered,"supply_lost":lost
    }

static func _global_outcome_id(factions:Dictionary) -> String:
    var counts = {"secure":0,"strained":0,"scarred":0,"critical":0}
    for row in factions.values():
        var category = str(row.get("category","critical")) if typeof(row) == TYPE_DICTIONARY else "critical"
        counts[category] = int(counts.get(category,0)) + 1
    if int(counts["secure"]) == 4:
        return "cohesive"
    if int(counts["critical"]) == 0 and int(counts["scarred"]) == 0:
        return "holding_network"
    if int(counts["critical"]) == 0:
        return "fragile_balance"
    if int(counts["critical"]) <= 2:
        return "fractured_region"
    return "survival_islands"

static func resolve_outcome(state:Dictionary,world_day:int) -> Dictionary:
    ensure_state(state)
    var row = state["regional_endgame"]
    if str(row.get("phase",PHASE_DORMANT)) != PHASE_COMPLETE:
        return {}
    var existing = row.get("outcome",{})
    if typeof(existing) == TYPE_DICTIONARY and GLOBAL_OUTCOMES.has(str(existing.get("id",""))):
        return existing.duplicate(true)
    var faction_rows = {}
    for faction_id in FactionCatalog.ids():
        faction_rows[str(faction_id)] = _faction_outcome(state,row,str(faction_id))
    var outcome_id = _global_outcome_id(faction_rows)
    var resolved_day = max(1,int(row.get("completion_day",world_day)))
    var resolved = {"id":outcome_id,"resolved_day":resolved_day,"factions":faction_rows}
    row["outcome"] = resolved
    state["regional_endgame"] = row
    return resolved.duplicate(true)

static func outcome_definition(state:Dictionary) -> Dictionary:
    ensure_state(state)
    var outcome = state["regional_endgame"].get("outcome",{})
    var outcome_id = str(outcome.get("id","")) if typeof(outcome) == TYPE_DICTIONARY else ""
    return GLOBAL_OUTCOMES.get(outcome_id,{}).duplicate(true)

static func faction_outcome_label(category:String) -> String:
    match category:
        "secure": return "УДЕРЖАНО"
        "strained": return "НАПРЯЖЕНО"
        "scarred": return "ИЗМОТАНО"
        "critical": return "КРИТИЧНО"
    return "КРИТИЧНО"

static func board_text(state:Dictionary,world_day:int) -> String:
    ensure_state(state)
    var current = phase(state)
    if current == PHASE_ACTIVE:
        return summary(state,world_day) + "\nПоддерживай слабые резервы и спасай рейсы: итог фиксируется по реальному состоянию мира."
    if current == PHASE_COMPLETE:
        var outcome = resolve_outcome(state,world_day)
        var definition = GLOBAL_OUTCOMES.get(str(outcome.get("id","")),{})
        return "ИТОГ РЕГИОНА • %s\n%s Sandbox продолжается; итог зафиксирован." % [str(definition.get("title","СЕЗОН ЗАВЕРШЁН")),str(definition.get("text",""))]
    return RegionalStability.board_text(state,world_day)

static func daily_tick(state:Dictionary,world_day:int) -> Dictionary:
    ensure_state(state)
    if not is_active(state):
        var current_phase = phase(state)
        if current_phase == PHASE_COMPLETE:
            var had_outcome = GLOBAL_OUTCOMES.has(str(state["regional_endgame"].get("outcome",{}).get("id","")))
            var resolved = resolve_outcome(state,world_day)
            return {"active":false,"completed":false,"phase":current_phase,"checkpoints":[],"outcome":resolved,"outcome_generated":not had_outcome}
        return {"active":false,"completed":false,"phase":current_phase,"checkpoints":[]}
    var row = state["regional_endgame"]
    var day = max(1,world_day)
    var end_day = int(row.get("ends_day",day + 1))
    var last_pressure = max(int(row.get("started_day",day)),int(row.get("pressure_applied_day",row.get("started_day",day))))
    var pressure_until = min(day,end_day)
    var checkpoint_hits = []
    if pressure_until > last_pressure:
        for pressure_day in range(last_pressure + 1,pressure_until + 1):
            var season_day = pressure_day - int(row.get("started_day",pressure_day))
            var applied = _apply_pressure_day(state,row,season_day)
            if bool(applied.get("checkpoint",false)):
                checkpoint_hits.append(season_day)
        row["pressure_applied_day"] = pressure_until
    row["last_tick_day"] = max(int(row.get("last_tick_day",0)),day)
    if day >= end_day:
        row["phase"] = PHASE_COMPLETE
        row["completion_day"] = day
        var history = row.get("history",[])
        if history.is_empty() or str(history[-1].get("event","")) != "completed":
            history.append({"day":day,"event":"completed"})
        while history.size() > HISTORY_LIMIT:
            history.remove_at(0)
        row["history"] = history
        state["regional_endgame"] = row
        # The final outcome is deliberately resolved by the production day-rollover
        # after same-day supply recovery has been applied. Direct callers may still
        # resolve it explicitly (or via board_text) once their day effects are done.
        return {"active":false,"completed":true,"phase":PHASE_COMPLETE,"completion_day":day,"checkpoints":checkpoint_hits,"outcome":{},"outcome_generated":false}
    state["regional_endgame"] = row
    return {"active":true,"completed":false,"phase":PHASE_ACTIVE,"days_left":days_left(state,day),"checkpoints":checkpoint_hits}

static func summary(state:Dictionary,world_day:int) -> String:
    ensure_state(state)
    var current = phase(state)
    if current == PHASE_ACTIVE:
        return "КРИЗИСНЫЙ СЕЗОН • осталось %d дн." % days_left(state,world_day)
    if current == PHASE_COMPLETE:
        var definition = outcome_definition(state)
        return "ИТОГ РЕГИОНА • %s" % str(definition.get("title","СЕЗОН ЗАВЕРШЁН"))
    var readiness = RegionalStability.report(state,world_day)
    if bool(readiness.get("ready",false)):
        return "РЕГИОН ГОТОВ • кризисный сезон можно начать вручную"
    return RegionalStability.summary(state,world_day)
