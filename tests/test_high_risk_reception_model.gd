extends SceneTree

# Clinical Complex №4 reception block: the v03 render skin is gone, the building
# is an authored Blender model (tools/wa_hr_buildings.py c_reception) like every
# other High Risk building, with the entrance kept on the axis.

const Harness = preload("res://tests/rest_harness.gd")
const BuildingCatalog = preload("res://world/building_catalog.gd")
const HighRiskBuildingModels = preload("res://world/high_risk_building_models.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    check(not ResourceLoader.exists("res://art/high_risk/medical_entry_v03/exterior_facade_lower.png"),"old v03 render skin is still shipped")
    var mid = HighRiskBuildingModels.model_id("regional_clinical_complex_4",Vector2i(0,0),"building_0")
    check(mid == "hr_clinic_00_b0","reception block has no authored model: " + mid)
    var model = HighRiskBuildingModels.model(mid)
    check(model.get("size",Vector2.ZERO) == Vector2(610,390),"reception model does not match the gameplay footprint")
    check(is_equal_approx(float(model.get("door_x",99.0)),0.0),"reception entrance is not on the axis")
    check(ResourceLoader.exists(str(model.get("atlas",""))),"reception model atlas is missing")

    var game = Harness.new()
    root.add_child(game)
    await process_frame
    check(not ("HIGH_RISK_SKIN_MEDICAL_ENTRY_V03" in game),"v03 skin constant is still in the game script")
    var chunk = Node2D.new()
    game.add_child(chunk)
    var data = BuildingCatalog.by_id("clinic").duplicate(true)
    data["settlement_model"] = mid
    data["door_x"] = 0.0
    var before_roofs = game.roof_records.size()
    var b = game._create_building(chunk,Vector2i.ZERO,"building_0",Vector2(350,270),Vector2(610,390),"ПРИЁМНЫЙ КОРПУС",Color("4c5854"),true,"clinic",data)
    check(b != null,"reception building was not created")
    check(str(b.get_meta("settlement_model","")) == mid,"reception building does not wear its model")
    check(is_equal_approx(float(b.get_meta("door_local_x",99.0)),0.0),"reception door moved off the axis")
    check(game.roof_records.size() == before_roofs + 1,"reception roof/facade fade record missing")

    game.queue_free()
    await process_frame
    print("HIGH RISK RECEPTION MODEL: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
