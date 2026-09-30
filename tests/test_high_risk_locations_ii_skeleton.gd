extends SceneTree

const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func run():
    # Operation 5 boundary: both tier-2 locations are active together and their
    # deepest core caches now participate in the existing target-farming system.
    var clinical = RegionCatalog.poi_by_id("regional_clinical_complex_4")
    var vector = RegionCatalog.poi_by_id("underground_object_vector")
    check(not clinical.is_empty(), "clinical complex missing after operation 4")
    check(not vector.is_empty(), "Vector did not leave dev skeleton")
    check(int(clinical.get("dungeon_tier",0)) == 2 and int(vector.get("dungeon_tier",0)) == 2, "tier-2 identity mismatch")
    check(str(clinical.get("status","")) == "active_integrated", "clinical integration status mismatch")
    check(str(vector.get("status","")) == "active_integrated", "Vector integration status mismatch")
    check(clinical.get("hard_requirements",["bad"]).is_empty() and vector.get("hard_requirements",["bad"]).is_empty(), "tier-2 no-self-key contract broken")
    check(PoiCatalog.has_compound("regional_clinical_complex_4"), "clinical authored compound missing")
    check(PoiCatalog.has_compound("underground_object_vector"), "Vector authored compound missing")
    check(RegionCatalog.HIGH_RISK_DEV_SKELETONS.is_empty(), "operation 4 must leave no high-risk skeleton")
    check(RegionCatalog.planned_high_risk_poi_by_id("underground_object_vector").is_empty(), "active Vector still exposed as planned skeleton")
    check(str(vector.get("kind","")) == "underground_endgame_dungeon", "Vector kind mismatch")
    check(str(vector.get("activation_operation","")) == "operation_4", "Vector operation identity mismatch")
    check(str(vector.get("district","")) == "outer_industrial", "Vector district mismatch")
    check(RegionCatalog.DISTRICTS.has(str(vector.get("district",""))), "Vector references unknown district")
    check(int(vector.get("risk",0)) == 5 and bool(vector.get("high_risk",false)), "Vector risk identity mismatch")
    check(str(vector.get("spatial_identity","")) == "sealed_underground_node", "Vector spatial identity changed")
    check(str(vector.get("loot","")) == "vector_core", "Vector loot identity mismatch")
    check(str(clinical.get("farm_profile","")) == "clinical_core" and int(clinical.get("refresh_days",0)) == 12, "clinical operation-5 farming metadata missing")
    check(str(vector.get("farm_profile","")) == "vector_core" and int(vector.get("refresh_days",0)) == 14, "Vector operation-5 farming metadata missing")

    # No overlap between the two new tier-2 locations; Vector keeps the reserved 2x3 shape.
    var clinical_cells = {}
    var ca:Vector2i = clinical.get("coord",Vector2i.ZERO)
    for off in clinical.get("footprint",[]): clinical_cells[ca + off] = true
    var va:Vector2i = vector.get("coord",Vector2i.ZERO)
    var xs = {}; var ys = {}
    for off in vector.get("footprint",[]):
        xs[off.x] = true; ys[off.y] = true
        check(not clinical_cells.has(va + off), "Vector overlaps clinical complex")
    check(Vector2i(xs.size(),ys.size()) == Vector2i(2,3), "Vector footprint must remain 2x3")

    print("HIGH RISK LOCATIONS II BOUNDARY: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
