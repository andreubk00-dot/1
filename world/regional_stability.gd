extends RefCounted
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEndgame = preload("res://world/faction_endgame.gd")
const SettlementProjects = preload("res://world/settlement_projects.gd")
const SettlementCrisis = preload("res://world/settlement_crisis.gd")

# 1.26-dev1 — derived regional readiness. This is intentionally NOT a new quest
# currency and stores no state of its own. It reads systems that already existed in
# schema 122 so old saves acquire a truthful readiness report after load.
const STARTER_ROUTE_IDS = [
    "route_perron_zarya",
    "route_lazaret_hospital",
    "route_rubezh_police",
    "route_mechanics_depot"
]
const REQUIRED_PER_COMPONENT = 4
const STABLE_RESOURCE_MIN = SettlementCrisis.STABLE_MIN

static func _open_route_count(state:Dictionary) -> int:
    var routes = state.get("world_routes",{})
    if typeof(routes) != TYPE_DICTIONARY:
        return 0
    var count = 0
    for route_id in STARTER_ROUTE_IDS:
        var route = routes.get(route_id,{})
        if typeof(route) == TYPE_DICTIONARY and str(route.get("state","")) == "open":
            count += 1
    return count

static func _project_count(state:Dictionary) -> int:
    var count = 0
    for faction_id in FactionCatalog.ids():
        if SettlementProjects.is_completed(state,str(faction_id)):
            count += 1
    return count

static func _network_count(state:Dictionary) -> int:
    var count = 0
    for faction_id in FactionCatalog.ids():
        if FactionEndgame.is_finalized(state,str(faction_id)):
            count += 1
    return count

static func _stable_settlement_count(state:Dictionary) -> int:
    var count = 0
    for faction_id in FactionCatalog.ids():
        if str(SettlementCrisis.faction_status(state,str(faction_id)).get("stage","crisis")) == "stable":
            count += 1
    return count

static func _worst_resource(state:Dictionary) -> Dictionary:
    var worst = {"faction":"","resource":"food","value":101.0}
    for faction_id in FactionCatalog.ids():
        var resources = state.get("factions",{}).get(str(faction_id),{}).get("resources",{})
        if typeof(resources) != TYPE_DICTIONARY:
            continue
        for resource_id in ["food","medicine","technical","security"]:
            var value = float(resources.get(resource_id,0.0))
            if value < float(worst.get("value",101.0)):
                worst = {"faction":str(faction_id),"resource":resource_id,"value":value}
    return worst

static func active_supply_incident(state:Dictionary) -> bool:
    var supply = state.get("supply_events",{})
    if typeof(supply) != TYPE_DICTIONARY:
        return false
    var active = supply.get("active",{})
    return typeof(active) == TYPE_DICTIONARY and not active.is_empty()

static func report(state:Dictionary,world_day:int = 1) -> Dictionary:
    var route_count = _open_route_count(state)
    var project_count = _project_count(state)
    var network_count = _network_count(state)
    var stable_count = _stable_settlement_count(state)
    var component_total = route_count + project_count + network_count + stable_count
    var component_max = REQUIRED_PER_COMPONENT * 4
    var score = int(round(100.0 * float(component_total) / float(component_max)))
    var infrastructure_ready = route_count >= REQUIRED_PER_COMPONENT and project_count >= REQUIRED_PER_COMPONENT and network_count >= REQUIRED_PER_COMPONENT and stable_count >= REQUIRED_PER_COMPONENT
    var incident_clear = not active_supply_incident(state)
    var blockers = []
    if route_count < REQUIRED_PER_COMPONENT:
        blockers.append("наладить стартовые маршруты %d/%d" % [route_count,REQUIRED_PER_COMPONENT])
    if project_count < REQUIRED_PER_COMPONENT:
        blockers.append("завершить проекты поселений %d/%d" % [project_count,REQUIRED_PER_COMPONENT])
    if network_count < REQUIRED_PER_COMPONENT:
        blockers.append("закрыть фракционные сети %d/%d" % [network_count,REQUIRED_PER_COMPONENT])
    if stable_count < REQUIRED_PER_COMPONENT:
        var worst = _worst_resource(state)
        var faction_name = str(FactionCatalog.faction(str(worst.get("faction",""))).get("short_name",worst.get("faction","")))
        blockers.append("стабилизировать поселения %d/%d; минимум %s: %s %d" % [stable_count,REQUIRED_PER_COMPONENT,faction_name,SettlementCrisis.resource_label(str(worst.get("resource","food"))),int(round(float(worst.get("value",0.0))))])
    if infrastructure_ready and not incident_clear:
        blockers.append("закрыть текущий аварийный рейс снабжения")
    return {
        "score":score,
        "routes":route_count,
        "projects":project_count,
        "networks":network_count,
        "stable_settlements":stable_count,
        "infrastructure_ready":infrastructure_ready,
        "incident_clear":incident_clear,
        "ready":infrastructure_ready and incident_clear,
        "blockers":blockers,
        "world_day":max(1,world_day)
    }

static func summary(state:Dictionary,world_day:int = 1) -> String:
    var row = report(state,world_day)
    var suffix = " • ГОТОВО К ФИНАЛЬНОМУ СЕЗОНУ" if bool(row.get("ready",false)) else ""
    if bool(row.get("infrastructure_ready",false)) and not bool(row.get("incident_clear",true)):
        suffix = " • SOS НЕ ЗАКРЫТ"
    return "УСТОЙЧИВОСТЬ %d%% • маршруты %d/4 • проекты %d/4 • сети %d/4 • поселения %d/4%s" % [
        int(row.get("score",0)),int(row.get("routes",0)),int(row.get("projects",0)),int(row.get("networks",0)),int(row.get("stable_settlements",0)),suffix
    ]

static func board_text(state:Dictionary,world_day:int = 1) -> String:
    var row = report(state,world_day)
    var text = summary(state,world_day)
    var blockers = row.get("blockers",[])
    if bool(row.get("ready",false)):
        return text + "\nРегиональная сеть выдерживает обычную нагрузку. Следующий этап 1.26 сможет запустить кризисный сезон вручную."
    if typeof(blockers) == TYPE_ARRAY and not blockers.is_empty():
        text += "\nСледующий рубеж: %s." % str(blockers[0])
    return text
