extends SceneTree

const BuildingCatalog = preload("res://world/building_catalog.gd")
const WorldContentVariety = preload("res://world/world_content_variety.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func _variants(archetype_id:String,index:int) -> Dictionary:
    var out = {}
    for y in range(-8,9):
        for x in range(-8,9):
            var variant = WorldContentVariety.variant_for(Vector2i(x,y),archetype_id,index)
            if variant >= 0:
                out[variant] = true
    return out

func run() -> void:
    check(WorldContentVariety.VARIANT_COUNT == 3,"dev1 must keep a small three-variant dressing budget")
    var expected_groups = {
        "panel_block":"residential","panel_entry":"residential","utility_house":"residential","country_house":"residential","dacha":"residential",
        "grocery":"commercial","pharmacy":"commercial","cafe":"commercial","service_shop":"commercial",
        "garage_row":"garage","repair_bay":"garage",
        "workshop":"warehouse","warehouse":"warehouse","factory_admin":"warehouse","rail_store":"warehouse","rail_service":"warehouse"
    }
    for archetype_id in expected_groups.keys():
        check(str(WorldContentVariety.group_for_archetype(archetype_id)) == str(expected_groups[archetype_id]),archetype_id + " assigned to wrong variety group")
        check(_variants(archetype_id,0).size() == 3,archetype_id + " does not exercise all three variants over ordinary coordinates")
        for variant in range(WorldContentVariety.VARIANT_COUNT):
            var profile = WorldContentVariety.profile_for(archetype_id,variant)
            check(not profile.is_empty(),archetype_id + " missing profile variant " + str(variant))
            check(profile.get("interior",[]).size() == 1,archetype_id + " variant must add exactly one interior accent")
            check(profile.get("facade",[]).size() == 1,archetype_id + " variant must add exactly one facade accent")
            check(profile.get("yard",[]).size() == 1,archetype_id + " variant must add exactly one yard accent")
            for forbidden in ["loot","container_id","door_x","size_min","size_max","collision","risk","farm_profile","refresh_days"]:
                check(not profile.has(forbidden),archetype_id + " variety profile leaked gameplay field " + forbidden)

    check(WorldContentVariety.variant_for(Vector2i(2,2),"barracks",0) == -1,"military authored role was modified by dev1 scope")
    check(WorldContentVariety.profile_for("barracks",0).is_empty(),"unsupported archetype fabricated a dressing profile")
    var a = WorldContentVariety.variant_for(Vector2i(3,3),"warehouse",1)
    var b = WorldContentVariety.variant_for(Vector2i(3,3),"warehouse",1)
    check(a == b,"content variant is not deterministic")
    check(WorldContentVariety.visual_seed_key(Vector2i(3,3),"warehouse",1) != WorldContentVariety.visual_seed_key(Vector2i(4,3),"warehouse",1),"visual seed ignores chunk coordinate")

    # Catalog semantics stay untouched; variety is layered after archetype selection.
    var warehouse = BuildingCatalog.by_id("warehouse")
    check(str(warehouse.get("loot","")) == "industrial","warehouse loot profile drifted")
    check(str(warehouse.get("layout","")) == "warehouse","warehouse room layout drifted")
    check(not warehouse.has("content_variant") and not warehouse.has("content_seed"),"derived variety leaked into canonical building catalog")

    print("WORLD CONTENT VARIETY 1.24-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
