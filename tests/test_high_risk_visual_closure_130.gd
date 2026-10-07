extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const HighRiskBuildingModels = preload("res://world/high_risk_building_models.gd")

var checks := 0
var failures := 0

func check(ok:bool, why:String)->void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL ",why)

func _initialize()->void:
    call_deferred("run")

func run()->void:
    var game = Harness.new()
    root.add_child(game)
    await process_frame
    var ids = [
        "regional_clinical_complex_4",
        "quarantine_center_12",
        "reserve_arsenal_bastion",
        "underground_object_vector"
    ]
    var site_atlases := {}
    var model_ids := {}
    var total_models := 0
    for poi_id in ids:
        var atlases := {}
        var cell_signatures := {}
        var fp = PoiCatalog.footprint(poi_id)
        check(fp.size() == 6,poi_id + " footprint must remain six authored sectors")
        for off in fp:
            var cell = PoiCatalog.cell(poi_id,off)
            var original:Array = cell.get("buildings",[])
            var visual:Array = game._high_risk_visual_specs(poi_id,off,original)
            check(visual.size() == original.size(),poi_id + " visual override changed building count at " + str(off))
            check(visual.size() >= 3,poi_id + " sector lost authored architectural masses at " + str(off))
            var sig=[]
            for spec in visual:
                var building_id = str(spec.get("id",""))
                var model_id = HighRiskBuildingModels.model_id(poi_id,off,building_id)
                check(model_id != "",poi_id + " missing authored exterior model at " + str(off) + " / " + building_id)
                if model_id == "":
                    continue
                check(not model_ids.has(model_id),"duplicate High Risk model id " + model_id)
                model_ids[model_id] = true
                total_models += 1
                var model = HighRiskBuildingModels.model(model_id)
                var expected_size:Vector2 = spec.get("size",Vector2.ZERO)
                check(model.get("size",Vector2.ZERO) == expected_size,model_id + " model footprint drift")
                var atlas = str(model.get("atlas",""))
                check(atlas != "" and ResourceLoader.exists(atlas),model_id + " atlas missing")
                atlases[atlas] = true
                var roof:Rect2 = model.get("roof_region",Rect2())
                var facade:Rect2 = model.get("facade_region",Rect2())
                check(roof.size.x > 0 and roof.size.y > 0,model_id + " roof region empty")
                check(facade.size.x > 0 and facade.size.y > 0,model_id + " facade region empty")
                sig.append("%s:%dx%d" % [str(spec.get("archetype","")),int(expected_size.x),int(expected_size.y)])
            cell_signatures[str(off)] = "|".join(sig)
        check(atlases.size() == 1,poi_id + " should use one coherent authored exterior atlas family")
        if not atlases.is_empty():
            site_atlases[poi_id] = str(atlases.keys()[0])
        var unique_signatures := {}
        for signature in cell_signatures.values():
            unique_signatures[str(signature)] = true
        check(unique_signatures.size() >= 5,poi_id + " ground sectors repeat the same architectural composition")
    check(total_models == 72,"expected complete 4x6x3 High Risk model coverage")
    var unique_atlases := {}
    for atlas in site_atlases.values():
        unique_atlases[str(atlas)] = true
    check(site_atlases.size() == 4 and unique_atlases.size() == 4,"High Risk sites do not have four distinct visual families")
    game.free()
    print("HIGH RISK VISUAL CLOSURE 1.30-dev2: %d checks / %d failures / models=%d / atlases=%d" % [checks,failures,total_models,unique_atlases.size()])
    quit(1 if failures else 0)
