extends SceneTree
const EnvironmentalStoryCatalog = preload("res://world/environmental_story_catalog.gd")
const EncounterCatalog = preload("res://world/encounter_catalog.gd")
const EncounterSceneVariety = preload("res://world/encounter_scene_variety.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const WorldChronicle = preload("res://world/world_chronicle.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")


const BASE_SCENE_PROP_POSITIONS = {
    "abandoned_camp":[Vector2(-18,4),Vector2(30,18),Vector2(50,-12),Vector2(-54,-8),Vector2(6,34)],
    "repair_breakdown":[Vector2(-28,2),Vector2(32,12),Vector2(54,-14),Vector2(12,-28),Vector2(-58,24)],
    "looted_convoy":[Vector2(44,18),Vector2(-42,20),Vector2(8,18),Vector2(-62,-24),Vector2(22,-12)],
    "feeding_site":[Vector2(0,12),Vector2(-34,-8),Vector2(38,16),Vector2(10,-24)]
}
const STORY_PROP_CLEARANCE := 22.0

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func run() -> void:
    check(EnvironmentalStoryCatalog.CLUES.size() == 8,"dev1 must keep the first story layer sparse and authored")
    var ids = {}
    for raw_key in EnvironmentalStoryCatalog.CLUES.keys():
        var key = str(raw_key)
        var parts = key.split(",")
        check(parts.size() == 2,"story anchor key malformed: " + key)
        if parts.size() != 2: continue
        var coord = Vector2i(int(parts[0]),int(parts[1]))
        var profile = RegionCatalog.chunk_profile(coord)
        check(str(profile.get("poi_id","")) == "",key + " story anchor overlaps authored POI")
        var event = EncounterCatalog.event_for(coord,str(profile.get("zone","residential")),int(profile.get("risk",2)),str(profile.get("poi_id","")))
        var clue = EnvironmentalStoryCatalog.clue_for(coord,str(event.get("id","")))
        check(not event.is_empty(),key + " no longer resolves to a finite encounter")
        check(not clue.is_empty(),key + " story clue no longer matches production encounter")
        var story_id = str(clue.get("id",""))
        check(story_id != "" and not ids.has(story_id),key + " missing/duplicate story id")
        ids[story_id] = true
        check(str(clue.get("text","")) != "" and str(clue.get("title","")) != "",story_id + " missing readable content")
        check(str(clue.get("prompt","")) in ["ЛИСТОК","ЖУРНАЛ","НАКЛАДНАЯ","ЗАПИСКА"],story_id + " interaction prompt is too verbose/unknown")
        var footprint:Vector2 = event.get("footprint",Vector2(128,86))
        var pos:Vector2 = clue.get("pos",Vector2.ZERO)
        check(abs(pos.x) <= footprint.x * 0.5 and abs(pos.y) <= footprint.y * 0.5,story_id + " readable prop leaves encounter footprint")
        var event_id = str(event.get("id",""))
        for base_pos in BASE_SCENE_PROP_POSITIONS.get(event_id,[]):
            check(pos.distance_to(base_pos) >= STORY_PROP_CLEARANCE,story_id + " readable prop overlaps base encounter dressing")
        for variant in EncounterSceneVariety.PROFILES.get(event_id,[]):
            for accent in variant:
                check(pos.distance_to(accent.get("pos",Vector2.ZERO)) >= STORY_PROP_CLEARANCE,story_id + " readable prop overlaps cosmetic encounter accent")
        for forbidden in ["reward","loot","enemy_count","route","objective","target","reputation","items","spawn_id","map_marker"]:
            check(not clue.has(forbidden),story_id + " leaked quest/gameplay field " + forbidden)
    check(ids.size() == 8,"story ids are not unique")
    check(EnvironmentalStoryCatalog.clue_for(Vector2i(1,-2),"feeding_site").is_empty(),"story clue leaks onto wrong encounter type")
    check(EnvironmentalStoryCatalog.clue_for(Vector2i(0,0),"abandoned_camp").is_empty(),"non-authored coordinate fabricated a story clue")

    var state = FactionEconomy.default_state()
    check(not WorldChronicle.story_seen(state,"north_camp_rain_log"),"new world starts with story clue already seen")
    var first = WorldChronicle.append_story(state,2,120,"north_camp_rain_log","Промокший листок","Текст")
    check(bool(first.get("new",false)),"first story read did not append")
    check(WorldChronicle.story_seen(state,"north_camp_rain_log"),"story seen state did not update")
    var history_size = WorldChronicle.entries(state,100).size()
    var repeat = WorldChronicle.append_story(state,2,125,"north_camp_rain_log","Промокший листок","Текст")
    check(not bool(repeat.get("new",true)),"repeat story read appended a duplicate")
    check(WorldChronicle.entries(state,100).size() == history_size,"repeat story read grew chronicle history")
    var migrated = FactionEconomy.sanitize_state({"world_chronicle":{"serial":0,"last_read_serial":0,"history":[]}})
    check(not WorldChronicle.story_seen(migrated,"north_camp_rain_log"),"old chronicle without story_seen did not migrate cleanly")

    print("ENVIRONMENTAL STORYTELLING 1.25-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
