extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")

# 1.22-dev7 — resource-driven settlement crisis model.
# The crisis state is derived from canonical faction resources, so old saves need no migration.
const STABLE_MIN = 55.0
const STRAIN_MIN = 35.0
const SHORTAGE_MIN = 20.0

const STAGE_LABELS = {
    "stable":"СТАБИЛЬНО",
    "strain":"НАПРЯЖЕНИЕ",
    "shortage":"ДЕФИЦИТ",
    "crisis":"КРИЗИС"
}
const STAGE_RANK = {"stable":0,"strain":1,"shortage":2,"crisis":3}
const RESOURCE_LABELS = {
    "food":"еда",
    "medicine":"медицина",
    "technical":"техника",
    "security":"безопасность"
}

static func stage_for_value(value:float) -> String:
    if value >= STABLE_MIN:
        return "stable"
    if value >= STRAIN_MIN:
        return "strain"
    if value >= SHORTAGE_MIN:
        return "shortage"
    return "crisis"

static func stage_rank(stage:String) -> int:
    return int(STAGE_RANK.get(stage,0))

static func stage_label(stage:String) -> String:
    return str(STAGE_LABELS.get(stage,"СТАБИЛЬНО"))

static func resource_label(resource_id:String) -> String:
    return str(RESOURCE_LABELS.get(resource_id,resource_id))

static func resource_for_category(category:String) -> String:
    if category in ["food","water","household"]:
        return "food"
    if category in ["medicine","medical","chemicals"]:
        return "medicine"
    if category in ["parts","tools","electronics","technical","fuel"]:
        return "technical"
    if category in ["ammo","weapon","armor","security"]:
        return "security"
    return ""

static func resource_for_item(item_id:String) -> String:
    return resource_for_category(FactionCatalog.item_category(item_id))

static func resource_value(state:Dictionary,faction_id:String,resource_id:String) -> float:
    return float(state.get("factions",{}).get(faction_id,{}).get("resources",{}).get(resource_id,0.0))

static func resource_stage(state:Dictionary,faction_id:String,resource_id:String) -> String:
    return stage_for_value(resource_value(state,faction_id,resource_id))

static func item_stage(state:Dictionary,faction_id:String,item_id:String) -> String:
    var resource_id = resource_for_item(item_id)
    if resource_id == "":
        return "stable"
    return resource_stage(state,faction_id,resource_id)

static func faction_status(state:Dictionary,faction_id:String) -> Dictionary:
    var resources = state.get("factions",{}).get(faction_id,{}).get("resources",{})
    if typeof(resources) != TYPE_DICTIONARY:
        return {"stage":"crisis","worst_resource":"food","worst_value":0.0,"resources":{}}
    var worst_resource = "food"
    var worst_value = 999.0
    var worst_stage = "stable"
    var detail = {}
    for resource_id in ["food","medicine","technical","security"]:
        var value = float(resources.get(resource_id,0.0))
        var stage = stage_for_value(value)
        detail[resource_id] = {"value":value,"stage":stage}
        if stage_rank(stage) > stage_rank(worst_stage) or (stage_rank(stage) == stage_rank(worst_stage) and value < worst_value):
            worst_resource = resource_id
            worst_value = value
            worst_stage = stage
    return {"stage":worst_stage,"worst_resource":worst_resource,"worst_value":worst_value,"resources":detail}

static func market_buy_factor(state:Dictionary,faction_id:String,item_id:String) -> float:
    match item_stage(state,faction_id,item_id):
        "strain": return 1.07
        "shortage": return 1.18
        "crisis": return 1.34
    return 1.0

static func market_sell_factor(state:Dictionary,faction_id:String,item_id:String) -> float:
    # Settlements pay a modest premium for genuinely scarce categories. Keep this below
    # the retail crisis markup so selling and immediately buying back can never become profitable.
    match item_stage(state,faction_id,item_id):
        "strain": return 1.04
        "shortage": return 1.09
        "crisis": return 1.15
    return 1.0

static func restock_factor(state:Dictionary,faction_id:String,item_id:String) -> float:
    match item_stage(state,faction_id,item_id):
        "strain": return 0.78
        "shortage": return 0.50
        "crisis": return 0.22
    return 1.0

static func allows_restock(state:Dictionary,faction_id:String,item_id:String,required_rep:int) -> bool:
    var stage = item_stage(state,faction_id,item_id)
    # Existing stock is never deleted. This only controls creation of new stock on future restocks.
    if stage == "crisis" and required_rep >= 75:
        return false
    if stage == "shortage" and required_rep >= 150:
        return false
    return true

static func crisis_contract_available(state:Dictionary,faction_id:String,resource_id:String) -> bool:
    return stage_rank(resource_stage(state,faction_id,resource_id)) >= stage_rank("shortage")

static func crisis_priority_bonus(state:Dictionary,faction_id:String,resource_id:String) -> float:
    # Preserve the authored early/mid-game board order, but once the player reaches trusted
    # late-game status a real shortage interrupts strategic/endgame work and promotes emergency supply.
    var stage = resource_stage(state,faction_id,resource_id)
    var reputation = int(state.get("factions",{}).get(faction_id,{}).get("reputation",0))
    if reputation >= 150:
        if stage == "crisis":
            return 38.0
        if stage == "shortage":
            return 26.0
    if stage == "shortage" or stage == "crisis":
        return -0.25
    return 0.0

static func incident_interval_delta(state:Dictionary) -> int:
    var worst_security = 100.0
    for faction_id in FactionCatalog.ids():
        worst_security = min(worst_security,resource_value(state,str(faction_id),"security"))
    var stage = stage_for_value(worst_security)
    if stage == "crisis":
        return -2
    if stage == "shortage":
        return -1
    return 0

static func recent_reason(state:Dictionary,faction_id:String,world_day:int) -> String:
    var events = state.get("supply_events",{})
    if typeof(events) != TYPE_DICTIONARY:
        return ""
    var history = events.get("history",[])
    if typeof(history) != TYPE_ARRAY:
        return ""
    for i in range(history.size() - 1,-1,-1):
        var row = history[i]
        if typeof(row) != TYPE_DICTIONARY or str(row.get("faction","")) != faction_id:
            continue
        if world_day - int(row.get("closed_day",0)) > 4:
            break
        if str(row.get("outcome","")) == "lost":
            return "последняя проблема: потерян рейс снабжения"
        if str(row.get("outcome","")) == "recovered":
            return "последний рейс удалось спасти"
    return ""

static func summary(state:Dictionary,faction_id:String,world_day:int = 0) -> String:
    var status = faction_status(state,faction_id)
    var stage = str(status.get("stage","stable"))
    var worst_resource = str(status.get("worst_resource","food"))
    var worst_value = float(status.get("worst_value",0.0))
    var text = "%s • %s %d" % [stage_label(stage),resource_label(worst_resource),int(round(worst_value))]
    if world_day > 0:
        var reason = recent_reason(state,faction_id,world_day)
        if reason != "":
            text += " • " + reason
    return text
