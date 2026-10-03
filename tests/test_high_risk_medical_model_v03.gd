extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const BuildingCatalog = preload("res://world/building_catalog.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _count_skin_layers(node:Node) -> int:
    var n := 1 if bool(node.get_meta("high_risk_model_layer",false)) else 0
    for child in node.get_children():
        n += _count_skin_layers(child)
    return n

func _count_collision_shapes(node:Node) -> int:
    var n := 1 if node is CollisionShape2D else 0
    for child in node.get_children():
        n += _count_collision_shapes(child)
    return n

func run() -> void:
    check(str(ProjectSettings.get_setting("application/config/version","")) == "1.23.0-dev1","visual branch version mismatch")
    for path in [
        "res://art/high_risk/medical_entry_v03/OSTATOK_HR_medical_entry_v03.glb",
        "res://art/high_risk/medical_entry_v03/exterior_roof_upper.png",
        "res://art/high_risk/medical_entry_v03/exterior_facade_lower.png",
        "res://art/high_risk/medical_entry_v03/interior_floor1_topdown.png"
    ]:
        check(ResourceLoader.exists(path),"missing approved medical v03 asset: " + path)

    var game = Harness.new()
    root.add_child(game)
    await process_frame
    var chunk = Node2D.new()
    game.add_child(chunk)
    var data = BuildingCatalog.by_id("clinic").duplicate(true)
    data["high_risk_skin"] = game.HIGH_RISK_SKIN_MEDICAL_ENTRY_V03
    data["door_x"] = 0.0
    var before_roofs = game.roof_records.size()
    var b = game._create_building(chunk,Vector2i.ZERO,"skin_test",Vector2(350,270),Vector2(610,390),"ПРИЁМНЫЙ КОРПУС",Color("4c5854"),true,"clinic",data)
    check(b != null,"medical v03 skin building was not created")
    check(str(b.get_meta("high_risk_skin","")) == game.HIGH_RISK_SKIN_MEDICAL_ENTRY_V03,"building lost skin id")
    check(is_equal_approx(float(b.get_meta("door_local_x",99.0)),0.0),"approved model entrance is not centered")
    check(game.roof_records.size() == before_roofs + 1,"skin building did not register roof/facade fade record")
    check(_count_skin_layers(chunk) >= 3,"model-derived floor/facade/roof layers were not all created")
    check(_count_collision_shapes(b) >= 20,"approved floor plan internal collision was not built")

    game.queue_free()
    await process_frame
    print("HIGH RISK MEDICAL MODEL V03: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
