extends SceneTree

const RegionCatalog = preload("res://world/region_catalog.gd")
const EncounterCatalog = preload("res://world/encounter_catalog.gd")
const EncounterSceneVariety = preload("res://world/encounter_scene_variety.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func run() -> void:
    check(EncounterSceneVariety.VARIANT_COUNT == 3,"dev2 must keep three cosmetic encounter variants")
    var expected = ["abandoned_camp","failed_evacuation","repair_breakdown","looted_convoy","feeding_site"]
    for event_id in expected:
        check(event_id in EncounterSceneVariety.SUPPORTED_EVENTS,event_id + " missing from dev2 variety scope")
        for variant in range(EncounterSceneVariety.VARIANT_COUNT):
            var accents = EncounterSceneVariety.PROFILES[event_id][variant]
            check(accents.size() == 2,event_id + " variant must add exactly two cosmetic accents")
            for accent in accents:
                for forbidden in ["loot","enemy_count","spawn_id","container_id","interaction_type","collision","risk","refresh_days"]:
                    check(not accent.has(forbidden),event_id + " accent leaked gameplay field " + forbidden)

    check(EncounterSceneVariety.variant_for(Vector2i(4,4),"supply_convoy") == -1,"dynamic supply convoy entered finite-scene variety layer")
    check(EncounterSceneVariety.accents_for(Vector2i(4,4),"supply_convoy").is_empty(),"dynamic supply convoy fabricated cosmetic accents")

    # Reference 41x41 world sample used by the dev2 audit. Event selection itself
    # is untouched; only the derived cosmetic variant is measured here.
    var event_counts = {}
    var variants = {}
    for y in range(-20,21):
        for x in range(-20,21):
            var coord = Vector2i(x,y)
            var profile = RegionCatalog.chunk_profile(coord)
            var event = EncounterCatalog.event_for(coord,str(profile.get("zone","residential")),int(profile.get("risk",2)),str(profile.get("poi_id","")))
            if event.is_empty():
                continue
            var event_id = str(event.get("id",""))
            event_counts[event_id] = int(event_counts.get(event_id,0)) + 1
            if not variants.has(event_id): variants[event_id] = {}
            variants[event_id][EncounterSceneVariety.variant_for(coord,event_id)] = true
    check(int(event_counts.get("abandoned_camp",0)) == 46,"reference encounter population drifted: abandoned_camp")
    check(int(event_counts.get("failed_evacuation",0)) == 4,"reference encounter population drifted: failed_evacuation")
    check(int(event_counts.get("repair_breakdown",0)) == 14,"reference encounter population drifted: repair_breakdown")
    check(int(event_counts.get("feeding_site",0)) == 24,"reference encounter population drifted: feeding_site")
    check(int(event_counts.get("looted_convoy",0)) == 12,"reference encounter population drifted: looted_convoy")
    for event_id in expected:
        check(variants.get(event_id,{}).size() == 3,event_id + " did not exercise all three cosmetic variants in reference world sample")

    # Canonical encounter semantics remain authored in EncounterCatalog.
    for event_id in expected:
        var spec = EncounterCatalog.EVENTS[event_id]
        check(not spec.has("scene_variant"),event_id + " leaked derived variety into canonical encounter catalog")
        check(int(spec.get("enemy_count",-1)) >= 0,event_id + " enemy budget disappeared")
    print("ENCOUNTER SCENE VARIETY 1.24-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
