extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const HighRiskFloorCatalog = preload("res://world/high_risk_floor_catalog.gd")
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

func _dominant_area(specs:Array) -> float:
    var best := 0.0
    for spec in specs:
        var size:Vector2 = spec.get("size",Vector2.ZERO)
        best = max(best,size.x*size.y)
    return best

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    check(str(ProjectSettings.get_setting("application/config/version","")) == "1.37.1", "current build version mismatch")

    var ids = [
        "quarantine_center_12",
        "reserve_arsenal_bastion",
        "regional_clinical_complex_4",
        "underground_object_vector"
    ]
    var seen_layouts = {}
    for poi_id in ids:
        check(HighRiskFloorCatalog.has_poi(poi_id), poi_id + " missing multi-floor catalog")
        check(HighRiskFloorCatalog.max_floor(poi_id) == 3, poi_id + " must have three gameplay layers")
        var floor_ids = HighRiskFloorCatalog.floors(poi_id)
        check(floor_ids == [2,3], poi_id + " upper/deep layers mismatch")
        var f2 = HighRiskFloorCatalog.floor(poi_id,2)
        var f3 = HighRiskFloorCatalog.floor(poi_id,3)
        check(not f2.is_empty() and not f3.is_empty(), poi_id + " floor data missing")
        check(float(f2.get("size",Vector2.ZERO).x) >= 1300.0, poi_id + " floor 2 is not large-scale")
        check(float(f2.get("size",Vector2.ZERO).y) >= 860.0, poi_id + " floor 2 depth is too small")
        check(float(f3.get("size",Vector2.ZERO).x) >= 1180.0, poi_id + " floor 3 is not large-scale")
        check(float(f3.get("size",Vector2.ZERO).y) >= 800.0, poi_id + " floor 3 depth is too small")
        check(str(f2.get("layout","")) != str(f3.get("layout","")), poi_id + " floors duplicate the same layout")
        seen_layouts[str(f2.get("layout",""))] = true
        seen_layouts[str(f3.get("layout",""))] = true
        check(f2.get("containers",[]).size() >= 2 and f3.get("containers",[]).size() >= 2, poi_id + " floors lack persistent containers")
        check(int(f2.get("enemy_count",0)) == 10 and int(f3.get("enemy_count",0)) == 12, poi_id + " floor encounter budget mismatch after dev5 balance pass")

        var fs = HighRiskFloorCatalog.floor_set(poi_id)
        var entry_off:Vector2i = fs.get("entry_offset",Vector2i(999,999))
        var entry = HighRiskFloorCatalog.ground_entry(poi_id,entry_off)
        check(not entry.is_empty() and int(entry.get("target_floor",0)) == 2, poi_id + " ground stair entry broken")

        # Ground identity: at least one authored cell must read as a dominant mass,
        # not three equally-sized generic boxes.
        var fp = PoiCatalog.footprint(poi_id)
        var best_area := 0.0
        var best_ratio := 0.0
        for off in fp:
            var cell = PoiCatalog.cell(poi_id,off)
            var original = cell.get("buildings",[])
            var visual = game._high_risk_visual_specs(poi_id,off,original)
            check(visual.size() == original.size(), poi_id + " visual override changed stable building/container count")
            var areas=[]
            for spec in visual:
                var size:Vector2 = spec.get("size",Vector2.ZERO)
                areas.append(size.x*size.y)
            areas.sort()
            if areas.size() >= 2:
                var ratio = float(areas[-1]) / max(1.0,float(areas[-2]))
                best_ratio = max(best_ratio,ratio)
            best_area = max(best_area,_dominant_area(visual))
        check(best_area >= 120000.0, poi_id + " lacks a major architectural mass")
        check(best_ratio >= 1.45, poi_id + " still reads as equal-size modular building salad")

        # Build floor 2 and 3 through production runtime path; verify layer switch,
        # transition chain and persistent container keys are deterministic.
        var ground_pos = game.player.global_position
        check(game._enter_high_risk_floor(poi_id,2,ground_pos), poi_id + " cannot enter floor 2")
        check(game._high_risk_floor_active() and game.high_risk_floor_index == 2, poi_id + " floor 2 did not become active")
        check(game.high_risk_floor_root.get_tree().get_nodes_in_group("high_risk_floor_transitions").size() >= 2, poi_id + " floor 2 lacks up/down stairs")
        var anchor:Vector2i = game._high_risk_floor_anchor(poi_id)
        for rec in f2.get("containers",[]):
            var cid = "mf_%s_f2_%s" % [poi_id,str(rec.get("id","cache"))]
            var key = "%d:%d:container:%s" % [anchor.x,anchor.y,cid]
            check(game.container_states.has(key), poi_id + " floor 2 container persistence key missing: " + cid)
        check(game._enter_high_risk_floor(poi_id,3,ground_pos,Vector2(999999,999999),2), poi_id + " cannot enter floor 3")
        check(game.high_risk_floor_index == 3, poi_id + " floor 3 did not become active")
        check(game.high_risk_floor_root.get_tree().get_nodes_in_group("high_risk_floor_transitions").size() >= 1, poi_id + " floor 3 lacks return stairs")
        for rec in f3.get("containers",[]):
            var cid = "mf_%s_f3_%s" % [poi_id,str(rec.get("id","cache"))]
            var key = "%d:%d:container:%s" % [anchor.x,anchor.y,cid]
            check(game.container_states.has(key), poi_id + " floor 3 container persistence key missing: " + cid)
        var save_state = game._high_risk_floor_save_state()
        check(str(save_state.get("poi_id","")) == poi_id and int(save_state.get("floor",0)) == 3, poi_id + " save state lost active floor")
        game._exit_high_risk_floor(false)
        check(not game._high_risk_floor_active(), poi_id + " floor layer did not unload")

    check(seen_layouts.size() == 8, "high-risk floors reuse layout identities")

    print("HIGH-RISK VISUAL/MULTIFLOOR TEST: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
