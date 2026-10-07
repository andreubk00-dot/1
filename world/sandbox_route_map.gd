extends RefCounted

# OSTATOK 1.23-dev17 — presentation-only map projection of already-open routes.
# It deliberately derives geography from authored contract/POI data and stores nothing.
const ContractCatalog = preload("res://world/contract_catalog.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

static func _template_for_route(route_id:String,record:Dictionary = {}) -> Dictionary:
    var source_contract = str(record.get("source_contract",""))
    if source_contract != "":
        var direct = ContractCatalog.template(source_contract)
        if str(direct.get("reward",{}).get("route",{}).get("id","")) == route_id:
            direct["template_id"] = source_contract
            return direct
    # Legacy/open-route records can lack source_contract. Route ids are authored and
    # unique, so fall back to catalog lookup without mutating the save.
    for template_id in ContractCatalog.TEMPLATES.keys():
        var candidate = ContractCatalog.template(str(template_id))
        if str(candidate.get("reward",{}).get("route",{}).get("id","")) == route_id:
            candidate["template_id"] = str(template_id)
            return candidate
    return {}

static func link_for_route(route_id:String,record:Dictionary) -> Dictionary:
    if str(record.get("state","")) != "open":
        return {}
    var template = _template_for_route(route_id,record)
    if template.is_empty():
        return {}
    # Only contracts that explicitly identify a geographic POI become map links.
    # Abstract network/final-delivery routes intentionally remain non-geographic.
    var target_poi_id = str(template.get("poi_id",""))
    if target_poi_id == "":
        return {}
    var faction_id = str(template.get("faction",""))
    var faction = FactionCatalog.faction(faction_id)
    var settlement_id = str(faction.get("settlement_id",""))
    var source = RegionCatalog.poi_by_id(settlement_id)
    var target = RegionCatalog.poi_by_id(target_poi_id)
    if source.is_empty() or target.is_empty():
        return {}
    var source_name = str(faction.get("short_name",source.get("short_name",source.get("name",settlement_id))))
    var target_name = str(target.get("short_name",target.get("name",target_poi_id)))
    return {
        "route_id":route_id,
        "template_id":str(template.get("template_id","")),
        "faction":faction_id,
        "source_poi_id":settlement_id,
        "target_poi_id":target_poi_id,
        "from":source.get("coord",Vector2i.ZERO),
        "to":target.get("coord",Vector2i.ZERO),
        "label":"%s ↔ %s" % [source_name,target_name]
    }

static func links(state:Dictionary,known_pois = null) -> Array:
    var result = []
    var routes = state.get("world_routes",{})
    if typeof(routes) != TYPE_DICTIONARY:
        return result
    var route_ids = routes.keys()
    route_ids.sort()
    var geographic_keys = {}
    for route_key in route_ids:
        var route_id = str(route_key)
        var record = routes.get(route_key,{})
        if typeof(record) != TYPE_DICTIONARY:
            continue
        var link = link_for_route(route_id,record)
        if link.is_empty():
            continue
        # Main gameplay always supplies discovered_pois. Requiring both endpoints
        # prevents a malformed/legacy save from revealing geography the player never saw.
        if typeof(known_pois) == TYPE_DICTIONARY:
            if not bool(known_pois.get(str(link.get("source_poi_id","")),false)):
                continue
            if not bool(known_pois.get(str(link.get("target_poi_id","")),false)):
                continue
        # Several personal/faction outcomes can improve the same physical connection.
        # The map shows geography, not economic stack count, so identical endpoints merge.
        var geographic_key = "%s>%s" % [str(link.get("source_poi_id","")),str(link.get("target_poi_id",""))]
        if geographic_keys.has(geographic_key):
            continue
        geographic_keys[geographic_key] = true
        result.append(link)
    return result

static func labels_at_coord(route_links:Array,coord:Vector2i) -> Array:
    var labels = []
    for link in route_links:
        if typeof(link) != TYPE_DICTIONARY:
            continue
        if link.get("from",Vector2i(999999,999999)) == coord or link.get("to",Vector2i(999999,999999)) == coord:
            var label = str(link.get("label",""))
            if label != "" and label not in labels:
                labels.append(label)
    return labels
