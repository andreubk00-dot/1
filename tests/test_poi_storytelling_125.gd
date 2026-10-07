extends SceneTree
const PoiStoryCatalog = preload("res://world/poi_story_catalog.gd")
const EnvironmentalStoryCatalog = preload("res://world/environmental_story_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")

const FORBIDDEN_FIELDS = ["reward","loot","enemy_count","route","objective","target","reputation","items","spawn_id","map_marker"]
const BUILDING_MARGIN := 12.0
const OBJECT_CLEARANCE := 28.0

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func run() -> void:
    check(PoiStoryCatalog.ENTRIES.size() == 8,"dev2 must add exactly one trace to eight ordinary authored POIs")
    var ids = {}
    for raw_key in PoiStoryCatalog.ENTRIES.keys():
        var entry:Dictionary = PoiStoryCatalog.ENTRIES[raw_key]
        var poi_id = str(entry.get("poi_id",""))
        var cell:Vector2i = entry.get("cell",Vector2i(999,999))
        var clue = PoiStoryCatalog.clue_for(poi_id,cell)
        check(not clue.is_empty(),str(raw_key) + " catalog lookup failed")
        check(PoiCatalog.has_compound(poi_id),poi_id + " no longer resolves to authored compound")
        var cell_data = PoiCatalog.cell(poi_id,cell)
        check(not cell_data.is_empty(),str(raw_key) + " target authored cell missing")
        var story_id = str(clue.get("id",""))
        check(story_id != "" and not ids.has(story_id),str(raw_key) + " missing/duplicate story id")
        check(story_id not in EnvironmentalStoryCatalog.ids(),story_id + " collides with dev1 finite-encounter story id")
        ids[story_id] = true
        check(str(clue.get("title","")) != "" and str(clue.get("text","")) != "",story_id + " missing readable content")
        check(str(clue.get("prompt","")) != "" and str(clue.get("prompt","")).length() <= 12,story_id + " interaction prompt is too long")
        for forbidden in FORBIDDEN_FIELDS:
            check(not clue.has(forbidden),story_id + " leaked gameplay/quest field " + forbidden)
        var pos:Vector2 = clue.get("pos",Vector2.ZERO)
        check(pos.x >= 24.0 and pos.x <= 744.0 and pos.y >= 24.0 and pos.y <= 744.0,story_id + " trace leaves chunk-safe bounds")
        for spec in cell_data.get("buildings",[]):
            var center:Vector2 = spec.get("pos",Vector2.ZERO)
            var size:Vector2 = spec.get("size",Vector2.ZERO) + Vector2(BUILDING_MARGIN * 2.0,BUILDING_MARGIN * 2.0)
            check(not Rect2(center - size * 0.5,size).has_point(pos),story_id + " trace overlaps authored building footprint")
        for prop in cell_data.get("props",[]):
            check(pos.distance_to(prop.get("pos",Vector2.ZERO)) >= OBJECT_CLEARANCE,story_id + " trace overlaps authored prop")
        for loose in cell_data.get("loose_containers",[]):
            check(pos.distance_to(loose.get("pos",Vector2.ZERO)) >= OBJECT_CLEARANCE,story_id + " trace overlaps loose container")
        for bench in cell_data.get("workbenches",[]):
            check(pos.distance_to(bench) >= OBJECT_CLEARANCE,story_id + " trace overlaps workbench")
    check(ids.size() == 8,"dev2 POI story ids are not unique")
    check(PoiStoryCatalog.clue_for("regional_clinical_complex_4",Vector2i.ZERO).is_empty(),"dev2 ordinary POI traces leaked into High Risk")
    check(PoiStoryCatalog.clue_for("settlement_lazaret",Vector2i.ZERO).is_empty(),"dev2 ordinary POI traces leaked into faction settlement")
    check(PoiStoryCatalog.clue_for("central_clinic",Vector2i.ZERO).is_empty(),"dev2 unexpectedly altered starting clinic")
    print("AUTHORED POI STORYTELLING 1.25-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
