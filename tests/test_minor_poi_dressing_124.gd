extends SceneTree
const MinorPoiDressing = preload("res://world/minor_poi_dressing.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")

var checks := 0
var failures := 0
func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize() -> void: call_deferred("run")

func run() -> void:
    check(MinorPoiDressing.target_cell_count() == 6,"dev3 target cell count drifted")
    var expected = {
        "dacha_coop_zarya":[Vector2i(-1,0),Vector2i(0,1),Vector2i(-1,1)],
        "military_checkpoint":[Vector2i(0,-1)],
        "district_police":[Vector2i(1,0)],
        "hunting_cordon":[Vector2i(1,0)]
    }
    var valid_kinds = {
        "rain_collector":true,"wooden_debris":true,"plant":true,"cardboard_boxes":true,
        "campfire":true,"trash_bag":true,"sandbags":true,"ammo_crate":true,
        "gas_can":true,"toolbox":true
    }
    for poi_id in expected.keys():
        check(PoiCatalog.has_compound(poi_id),poi_id + " dev3 target is not an authored compound")
        for cell_offset in expected[poi_id]:
            var accents = MinorPoiDressing.accents_for(poi_id,cell_offset)
            check(accents.size() == 2,poi_id + " " + str(cell_offset) + " must add exactly two cosmetic accents")
            for accent in accents:
                var kind = str(accent.get("kind",""))
                var pos:Vector2 = accent.get("pos",Vector2.ZERO)
                check(valid_kinds.has(kind),poi_id + " uses unknown dev3 prop kind " + kind)
                check(pos.x >= 32.0 and pos.x <= 736.0 and pos.y >= 32.0 and pos.y <= 736.0,poi_id + " accent leaves chunk safe bounds")
                for forbidden in ["loot","container_id","enemy_mult","collision","door","risk","farm_profile","refresh_days","items","save_key"]:
                    check(not accent.has(forbidden),poi_id + " cosmetic accent leaked gameplay field " + forbidden)
    check(MinorPoiDressing.accents_for("factory_7",Vector2i.ZERO).is_empty(),"already-dressed factory received dev3 overlay")
    check(MinorPoiDressing.accents_for("regional_clinical_complex_4",Vector2i.ZERO).is_empty(),"High Risk site received dev3 overlay")
    check(MinorPoiDressing.accents_for("settlement_lazaret",Vector2i.ZERO).is_empty(),"faction settlement received dev3 overlay")
    print("MINOR POI DRESSING 1.24-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
