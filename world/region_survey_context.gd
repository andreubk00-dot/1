extends RefCounted

# OSTATOK 1.23-dev18 — presentation-only survey context for already-known districts.
# The map derives this from discovery state and authored region identity. Nothing here
# is persisted and no hidden loot/spawn/farming metadata is exposed to the player.
const RegionCatalog = preload("res://world/region_catalog.gd")

static func _chunk_key(coord:Vector2i) -> String:
    return "%d:%d" % [coord.x,coord.y]

static func _coord_from_key(key_value) -> Vector2i:
    var parts = str(key_value).split(":")
    if parts.size() != 2:
        return Vector2i(999999,999999)
    return Vector2i(int(parts[0]),int(parts[1]))

static func visible_district_id_for_coord(coord:Vector2i,known_pois:Dictionary) -> String:
    # A discovered authored POI may intentionally override the procedural outskirts
    # district at its footprint (notably faction settlements). Unknown POIs never do.
    var poi = RegionCatalog.poi_for_chunk(coord)
    if not poi.is_empty():
        var poi_id = str(poi.get("id",""))
        if poi_id != "" and bool(known_pois.get(poi_id,false)):
            var authored = str(poi.get("district",""))
            if authored != "":
                return authored
    return RegionCatalog.district_id_for_chunk(coord)

static func _known_landmarks(district_id:String,known_pois:Dictionary) -> Array:
    var result = []
    for poi in RegionCatalog.POIS:
        var poi_id = str(poi.get("id",""))
        if poi_id == "" or not bool(known_pois.get(poi_id,false)):
            continue
        if str(poi.get("district","")) != district_id:
            continue
        var label = str(poi.get("short_name",poi.get("name",poi_id)))
        if label != "" and label not in result:
            result.append(label)
    result.sort()
    return result

static func _route_count(district_id:String,route_links:Array) -> int:
    var count := 0
    for link in route_links:
        if typeof(link) != TYPE_DICTIONARY:
            continue
        var source = RegionCatalog.poi_by_id(str(link.get("source_poi_id","")))
        var target = RegionCatalog.poi_by_id(str(link.get("target_poi_id","")))
        var touches = (not source.is_empty() and str(source.get("district","")) == district_id) or (not target.is_empty() and str(target.get("district","")) == district_id)
        if touches:
            count += 1
    return count

static func context_for_coord(coord:Vector2i,known_chunks:Dictionary,known_pois:Dictionary,route_links:Array = []) -> Dictionary:
    # Discovery-first: never derive district identity for an unknown sector.
    if not bool(known_chunks.get(_chunk_key(coord),false)):
        return {}
    var district_id = visible_district_id_for_coord(coord,known_pois)
    var profile = RegionCatalog.district_profile(district_id)
    var known_sector_count := 0
    for key_value in known_chunks.keys():
        if not bool(known_chunks.get(key_value,false)):
            continue
        var known_coord = _coord_from_key(key_value)
        if known_coord.x >= 900000:
            continue
        if visible_district_id_for_coord(known_coord,known_pois) == district_id:
            known_sector_count += 1
    return {
        "district_id":district_id,
        "name":str(profile.get("name",district_id)),
        "description":str(profile.get("description","")),
        "risk":int(profile.get("risk",2)),
        "known_sectors":known_sector_count,
        "known_landmarks":_known_landmarks(district_id,known_pois),
        "established_links":_route_count(district_id,route_links)
    }

static func landmark_text(context:Dictionary,max_names:int = 3) -> String:
    var landmarks = context.get("known_landmarks",[])
    if typeof(landmarks) != TYPE_ARRAY or landmarks.is_empty():
        return ""
    var shown = []
    for i in range(min(max_names,landmarks.size())):
        shown.append(str(landmarks[i]))
    var text = ", ".join(shown)
    if landmarks.size() > shown.size():
        text += " +%d" % (landmarks.size() - shown.size())
    return text
