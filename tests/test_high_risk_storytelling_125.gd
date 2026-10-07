extends SceneTree
const HighRiskStoryCatalog = preload("res://world/high_risk_story_catalog.gd")
const EnvironmentalStoryCatalog = preload("res://world/environmental_story_catalog.gd")
const PoiStoryCatalog = preload("res://world/poi_story_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const HighRiskFloorCatalog = preload("res://world/high_risk_floor_catalog.gd")
const HighRiskSiteCatalog = preload("res://world/high_risk_site_catalog.gd")

const FORBIDDEN_FIELDS = ["reward","loot","enemy_count","route","objective","target","reputation","items","spawn_id","map_marker","strategic_item","cache_id","access"]
const FORBIDDEN_TEXT = ["cache_3","strategic","стратегичес","ключ к","лежит в"]
const BUILDING_MARGIN := 12.0
const OBJECT_CLEARANCE := 56.0
var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func run() -> void:
    check(HighRiskStoryCatalog.GROUND.size() == 4,"dev3 must add one ground trace per High Risk site")
    check(HighRiskStoryCatalog.FLOORS.size() == 4,"dev3 must add one deep-floor trace per High Risk site")
    var ids = {}
    var earlier = {}
    for id in EnvironmentalStoryCatalog.ids(): earlier[str(id)] = true
    for id in PoiStoryCatalog.ids(): earlier[str(id)] = true
    for entry in HighRiskStoryCatalog.GROUND.values():
        var poi_id = str(entry.get("poi_id",""))
        var cell:Vector2i = entry.get("cell",Vector2i(999,999))
        var clue = HighRiskStoryCatalog.ground_clue(poi_id,cell)
        check(HighRiskFloorCatalog.has_poi(poi_id),poi_id + " is not an existing High Risk site")
        check(HighRiskSiteCatalog.has(poi_id),poi_id + " has no High Risk site dressing")
        var cell_data = PoiCatalog.cell(poi_id,cell)
        check(not cell_data.is_empty(),poi_id + " ground story target cell missing")
        var story_id = str(clue.get("id",""))
        check(story_id != "" and not ids.has(story_id),poi_id + " missing/duplicate ground story id")
        check(not earlier.has(story_id),story_id + " collides with earlier 1.25 story id")
        ids[story_id] = true
        for forbidden in FORBIDDEN_FIELDS: check(not clue.has(forbidden),story_id + " leaked gameplay field " + forbidden)
        var safe_text = (str(clue.get("title","")) + " " + str(clue.get("text",""))).to_lower()
        for token in FORBIDDEN_TEXT: check(token not in safe_text,story_id + " contains forbidden progression hint " + token)
        var pos:Vector2 = clue.get("pos",Vector2.ZERO)
        check(pos.x >= 24.0 and pos.x <= 744.0 and pos.y >= 24.0 and pos.y <= 744.0,story_id + " leaves chunk-safe bounds")
        for spec in cell_data.get("buildings",[]):
            var center:Vector2 = spec.get("pos",Vector2.ZERO)
            var size:Vector2 = spec.get("size",Vector2.ZERO) + Vector2(BUILDING_MARGIN*2.0,BUILDING_MARGIN*2.0)
            check(not Rect2(center-size*0.5,size).has_point(pos),story_id + " overlaps a building footprint")
        for loose in cell_data.get("loose_containers",[]): check(pos.distance_to(loose.get("pos",Vector2.ZERO)) >= OBJECT_CLEARANCE,story_id + " is too close to loose container")
    for entry in HighRiskStoryCatalog.FLOORS.values():
        var poi_id = str(entry.get("poi_id",""))
        var floor_index = int(entry.get("floor",0))
        var clue = HighRiskStoryCatalog.floor_clue(poi_id,floor_index)
        check(floor_index == HighRiskFloorCatalog.max_floor(poi_id) and floor_index == 3,poi_id + " story must stay on existing deepest floor 3")
        check(HighRiskStoryCatalog.floor_clue(poi_id,2).is_empty(),poi_id + " dev3 must not alter mandatory floor-2 route")
        var story_id = str(clue.get("id",""))
        check(story_id != "" and not ids.has(story_id),poi_id + " missing/duplicate floor story id")
        check(not earlier.has(story_id),story_id + " collides with earlier 1.25 story id")
        ids[story_id] = true
        for forbidden in FORBIDDEN_FIELDS: check(not clue.has(forbidden),story_id + " leaked gameplay field " + forbidden)
        var safe_text = (str(clue.get("title","")) + " " + str(clue.get("text",""))).to_lower()
        for token in FORBIDDEN_TEXT: check(token not in safe_text,story_id + " contains forbidden progression hint " + token)
        var floor_data = HighRiskFloorCatalog.floor(poi_id,floor_index)
        var pos:Vector2 = clue.get("pos",Vector2.ZERO)
        var size:Vector2 = floor_data.get("size",Vector2(1000,700))
        check(abs(pos.x) <= size.x*0.5-48.0 and abs(pos.y) <= size.y*0.5-48.0,story_id + " leaves floor-safe bounds")
        check(pos.distance_to(Vector2(0,size.y*0.40)) >= 120.0,story_id + " is too close to floor transition")
        for container in floor_data.get("containers",[]): check(pos.distance_to(container.get("pos",Vector2.ZERO)) >= OBJECT_CLEARANCE,story_id + " is too close to floor container")
    check(ids.size() == 8,"dev3 High Risk story ids are not unique")
    check(HighRiskStoryCatalog.ground_clue("district_hospital",Vector2i.ZERO).is_empty(),"High Risk stories leaked into ordinary POI")
    print("HIGH RISK STORYTELLING 1.25-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
