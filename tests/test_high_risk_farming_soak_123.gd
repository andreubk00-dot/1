extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const HighRiskFloorCatalog = preload("res://world/high_risk_floor_catalog.gd")
const HighRiskMechanics = preload("res://world/high_risk_mechanics.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _clear_floor_two(game,poi_id:String) -> void:
    var anchor = game._high_risk_floor_anchor(poi_id)
    var count = int(HighRiskFloorCatalog.floor(poi_id,2).get("enemy_count",0))
    for i in range(count):
        game.defeated["%d:%d:%d" % [anchor.x,anchor.y,2200 + i]] = true

func _prime_empty_core(game,poi:Dictionary) -> Array:
    var keys = game._target_farm_expected_container_keys(poi)
    var profile = game._target_farm_profile(poi)
    for key in keys:
        game.container_states[key] = {
            "name":"QA High Risk core",
            "loot_table":profile,
            "grid_w":game.CONTAINER_W,
            "grid_h":game.CONTAINER_H,
            "generated_day":1,
            "refresh_cycle":0,
            "poi_id":str(poi.get("id","")),
            "target_farm":true,
            "items":[]
        }
    return keys

func run() -> void:
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var total_cycles = 0
    for poi_id in HighRiskMechanics.SITE_IDS:
        var poi = RegionCatalog.poi_by_id(poi_id)
        var refresh = game._target_farm_refresh_days(poi)
        game.container_states = {}
        game.loot_refresh_sites = {}
        game.high_risk_state = HighRiskMechanics.default_state()
        game.defeated = {}
        game.world_day = 1
        var keys = _prime_empty_core(game,poi)
        check(keys.size() == 3,poi_id + " must keep exactly three renewable deep caches")

        # Simulate a completed first run: access was breached and the deep incident cleared.
        _clear_floor_two(game,poi_id)
        check(game._high_risk_unlock_access(poi_id,2),poi_id + " initial access fixture failed")
        var spec = HighRiskMechanics.site(poi_id)
        var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
        var incident_coord = anchor + spec.get("incident_offset",Vector2i.ZERO)
        for i in range(int(spec.get("incident_count",0))):
            game.defeated["%d:%d:%d" % [incident_coord.x,incident_coord.y,HighRiskMechanics.incident_spawn_id(i)]] = true
        HighRiskMechanics.mark_incident_resolved(game.high_risk_state,poi_id,0)
        # In a completed dev6 first run the one-off strategic source has already
        # existed in cache_3. This suite measures renewable farming, not dev5 migration.
        HighRiskMechanics.mark_strategic_spawned(game.high_risk_state,poi_id)
        game._target_farm_schedule_if_cleared(poi_id)
        check(int(game._target_farm_site_state(poi_id).get("ready_day",0)) == 1 + refresh,poi_id + " initial cooldown mismatch")

        var cycles = 0
        var checkpoint_cycles = {30:0,60:0,180:0}
        var recovered_entries = 0
        var recovered_qty = 0
        var top_tier_recovered = 0
        for day in range(2,181):
            game.world_day = day
            if game._prepare_target_farm_site(poi):
                cycles += 1
                total_cycles += 1
                var state = game._target_farm_site_state(poi_id)
                check(int(state.get("cycle",0)) == cycles,poi_id + " refresh cycle skipped/duplicated at day " + str(day))
                check(not game._high_risk_access_unlocked(poi_id),poi_id + " old secure access remained open after reoccupation")
                # Incident IDs must be restored too; the local event is dangerous again in a new cycle.
                var restored_incident = true
                for i in range(int(spec.get("incident_count",0))):
                    var k = "%d:%d:%d" % [incident_coord.x,incident_coord.y,HighRiskMechanics.incident_spawn_id(i)]
                    if game.defeated.has(k):
                        restored_incident = false
                check(restored_incident,poi_id + " local incident failed to return after reoccupation")
                check(not HighRiskMechanics.incident_resolved(game.high_risk_state,poi_id,cycles),poi_id + " new incident cycle inherited resolved state")

                for key in keys:
                    for entry in game.container_states[key].get("items",[]):
                        recovered_entries += 1
                        recovered_qty += int(entry.get("qty",1))
                        if game._item_rarity_key(str(entry.get("id",""))) in ["specialized","unique"]:
                            top_tier_recovered += 1
                check(top_tier_recovered == 0,poi_id + " repeat farming restored specialized/unique loot")

                # Simulate risking the interior again, then emptying salvage caches.
                _clear_floor_two(game,poi_id)
                check(game._high_risk_unlock_access(poi_id,2),poi_id + " current-cycle access could not be earned again")
                for key in keys:
                    game.container_states[key]["items"] = []
                for i in range(int(spec.get("incident_count",0))):
                    game.defeated["%d:%d:%d" % [incident_coord.x,incident_coord.y,HighRiskMechanics.incident_spawn_id(i)]] = true
                HighRiskMechanics.mark_incident_resolved(game.high_risk_state,poi_id,cycles)
                game._target_farm_schedule_if_cleared(poi_id)
                check(int(game._target_farm_site_state(poi_id).get("ready_day",0)) == day + refresh,poi_id + " repeat cooldown shortened/exploded")
            if checkpoint_cycles.has(day):
                checkpoint_cycles[day] = cycles

        var expected_cycles = int(floor(179.0 / float(refresh)))
        check(cycles == expected_cycles,poi_id + " 180-day refresh count changed: " + str(cycles) + " vs " + str(expected_cycles))
        check(int(checkpoint_cycles[30]) > 0,poi_id + " no High Risk recovery cycle by day 30")
        check(int(checkpoint_cycles[60]) > int(checkpoint_cycles[30]),poi_id + " 60-day cycle count did not progress")
        check(int(checkpoint_cycles[180]) > int(checkpoint_cycles[60]),poi_id + " 180-day cycle count did not progress")
        check(top_tier_recovered == 0,poi_id + " generated top-tier repeat loot across 180-day soak")
        check(recovered_entries > 0 and recovered_qty > 0,poi_id + " anti-farm tuning accidentally removed all repeat salvage")
        check(int(game._target_farm_site_state(poi_id).get("ready_day",0)) > 180,poi_id + " final clear did not retain a future cooldown")

    check(total_cycles >= 50,"180-day soak exercised too few High Risk recovery cycles")
    game.queue_free()
    await process_frame
    print("HIGH RISK FARMING SOAK 30/60/180 1.23-dev6: ",checks," checks, ",failures," failures; cycles=",total_cycles)
    quit(1 if failures else 0)
