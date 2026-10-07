extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
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

func _floor_keys(game,poi_id:String,floor_index:int) -> Array:
    var out = []
    var anchor = game._high_risk_floor_anchor(poi_id)
    var count = int(HighRiskFloorCatalog.floor(poi_id,floor_index).get("enemy_count",0))
    for i in range(count):
        out.append("%d:%d:%d" % [anchor.x,anchor.y,2000 + floor_index * 100 + i])
    return out

func _incident_enemy_count(chunk:Node) -> int:
    var total = 0
    for child in chunk.get_children():
        if bool(child.get_meta("high_risk_incident",false)):
            total += 1
    return total

func run() -> void:
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    check(HighRiskMechanics.SITE_IDS.size() == 4,"High Risk mechanic roster must cover four authored sites")
    for poi_id in HighRiskMechanics.SITE_IDS:
        var poi = RegionCatalog.poi_by_id(poi_id)
        var spec = HighRiskMechanics.site(poi_id)
        check(not poi.is_empty(),poi_id + " missing from region catalog")
        check(int(poi.get("risk",0)) == 5,poi_id + " must remain risk 5")
        check(str(poi.get("farm_profile","")) == str(spec.get("core_profile","")),poi_id + " mechanics/core profile mismatch")
        check(poi.get("hard_requirements",[]).is_empty(),poi_id + " reintroduced a self-key hard requirement")
        check(float(spec.get("reoccupation_ratio",0.0)) > 0.0 and float(spec.get("reoccupation_ratio",1.0)) < 1.0,poi_id + " perimeter reoccupation ratio must be partial")
        check(int(spec.get("incident_count",0)) >= 3,poi_id + " local incident has no meaningful threat budget")

    var poi_id = "regional_clinical_complex_4"
    var poi = RegionCatalog.poi_by_id(poi_id)
    var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
    game.high_risk_state = HighRiskMechanics.default_state()
    game.loot_refresh_sites = {poi_id:{"cycle":0,"ready_day":0,"cleared_day":0,"last_refresh_day":0}}
    game.world_day = 17
    game.world_minutes = 780.0

    # Deep access is locked until the current floor is explicitly cleared.
    var target_keys = game._target_farm_expected_container_keys(poi)
    check(target_keys.size() == 3,"clinical core must retain three target-farm caches")
    game.container_states[target_keys[0]] = {"target_farm":true,"poi_id":poi_id,"items":[]}
    check(game._high_risk_container_locked(target_keys[0]),"core cache must start locked")
    check(not game._high_risk_unlock_access(poi_id,2),"uncleared floor 2 incorrectly opened deep access")
    for key in _floor_keys(game,poi_id,2):
        game.defeated[key] = true
    check(game._high_risk_floor_threats_cleared(poi_id,2),"floor-2 clear state not recognized")
    check(game._high_risk_unlock_access(poi_id,2),"cleared floor 2 did not unlock emergency override")
    check(game._high_risk_access_unlocked(poi_id),"access unlock did not persist in runtime state")
    check(not game._high_risk_container_locked(target_keys[0]),"unlocked core cache remained locked")
    check(int(HighRiskMechanics.record(game.high_risk_state,poi_id).get("access_day",0)) == 17,"access day not recorded")

    # Reoccupation starts a new access cycle, so an old breach is never permanent.
    game.loot_refresh_sites[poi_id]["cycle"] = 1
    check(not game._high_risk_access_unlocked(poi_id),"old access breach leaked into new reoccupation cycle")
    check(game._high_risk_container_locked(target_keys[0]),"new cycle must relock the secure cache")

    # Repeat-cycle loot is salvage, not a renewable source of best-in-slot trade goods.
    var authored = [
        {"id":"akm","qty":1,"x":0,"y":0},
        {"id":"military_vest","qty":1,"x":1,"y":0},
        {"id":"trauma_kit","qty":3,"x":2,"y":0},
        {"id":"bandage","qty":6,"x":3,"y":0},
        {"id":"scrap","qty":8,"x":4,"y":0}
    ]
    var recovered = game._high_risk_recovery_loot(authored,poi_id,"qa:clinical:core",1)
    check(not recovered.is_empty(),"reoccupied core produced no salvage at all")
    for entry in recovered:
        var item_id = str(entry.get("id",""))
        check(not game._item_rarity_key(item_id) in ["specialized","unique"],"repeat core restored specialized/unique item " + item_id)
        var original_qty = 999
        for raw in authored:
            if str(raw.get("id","")) == item_id:
                original_qty = int(raw.get("qty",1))
        check(int(entry.get("qty",1)) <= original_qty,"repeat salvage increased authored quantity")
    check(HighRiskMechanics.recovery_keep_chance("specialized",1) == 0.0,"specialized repeat chance must stay zero")
    check(HighRiskMechanics.recovery_keep_chance("rare",2) < HighRiskMechanics.recovery_keep_chance("rare",1),"later repeat cycles must further reduce rare recovery")

    # Reoccupation restores the dangerous interior but only part of the old perimeter.
    game.defeated = {}
    var ground_keys = []
    for off in PoiCatalog.footprint(poi_id):
        var cell = PoiCatalog.cell(poi_id,off)
        var coord = anchor + off
        for i in range(int(cell.get("enemy_count",0))):
            var key = "%d:%d:%d" % [coord.x,coord.y,i]
            ground_keys.append(key)
            game.defeated[key] = true
    for key in _floor_keys(game,poi_id,2) + _floor_keys(game,poi_id,3):
        game.defeated[key] = true
    game._reset_target_farm_threats(poi,1)
    var outer_still_dead = 0
    var outer_restored = 0
    var core_coord:Vector2i = anchor + HighRiskMechanics.site(poi_id).get("core_offset",Vector2i.ZERO)
    for key in ground_keys:
        var parts = str(key).split(":")
        var coord = Vector2i(int(parts[0]),int(parts[1]))
        if coord == core_coord:
            check(not game.defeated.has(key),"deep core ground threat failed to reoccupy")
        elif game.defeated.has(key):
            outer_still_dead += 1
        else:
            outer_restored += 1
    check(outer_still_dead > 0,"reoccupation erased all evidence of perimeter clear")
    check(outer_restored > 0,"reoccupation restored no perimeter pressure")
    for key in _floor_keys(game,poi_id,2) + _floor_keys(game,poi_id,3):
        check(not game.defeated.has(key),"deep-floor threat failed to return on reoccupation")

    # A discovered site's local incident is deterministic and defeated members stay dead.
    var spec = HighRiskMechanics.site(poi_id)
    var incident_coord:Vector2i = anchor + spec.get("incident_offset",Vector2i.ZERO)
    game.discovered_pois[poi_id] = true
    game.high_risk_state = HighRiskMechanics.default_state()
    game.loot_refresh_sites[poi_id] = {"cycle":0,"ready_day":0,"cleared_day":0,"last_refresh_day":0}
    game.defeated = {}
    var incident_chunk = Node2D.new()
    game.add_child(incident_chunk)
    game._spawn_high_risk_local_incident(incident_chunk,incident_coord,poi_id,spec.get("incident_offset",Vector2i.ZERO))
    var incident_count = int(spec.get("incident_count",0))
    check(_incident_enemy_count(incident_chunk) == incident_count,"local incident spawn budget mismatch")
    check(int(HighRiskMechanics.record(game.high_risk_state,poi_id).get("incident_announced_cycle",-1)) == 0,"local incident announcement cycle not recorded")
    var first_key = "%d:%d:%d" % [incident_coord.x,incident_coord.y,HighRiskMechanics.incident_spawn_id(0)]
    game.defeated[first_key] = true
    var rebuilt = Node2D.new()
    game.add_child(rebuilt)
    game._spawn_high_risk_local_incident(rebuilt,incident_coord,poi_id,spec.get("incident_offset",Vector2i.ZERO))
    check(_incident_enemy_count(rebuilt) == incident_count - 1,"defeated incident member resurrected during chunk rebuild")

    # Migration: schema-122 defeated IDs from a pre-dev5 save are adopted silently.
    game.high_risk_state = HighRiskMechanics.default_state()
    for i in range(incident_count):
        game.defeated["%d:%d:%d" % [incident_coord.x,incident_coord.y,HighRiskMechanics.incident_spawn_id(i)]] = true
    var migrated = Node2D.new()
    game.add_child(migrated)
    var news_before_migration = game.WorldChronicle.entries(game.faction_state,64,false).size()
    game._spawn_high_risk_local_incident(migrated,incident_coord,poi_id,spec.get("incident_offset",Vector2i.ZERO))
    check(_incident_enemy_count(migrated) == 0,"old defeated incident IDs respawned after migration")
    check(game.WorldChronicle.entries(game.faction_state,64,false).size() == news_before_migration,"old defeated incident emitted a false new danger report")
    check(HighRiskMechanics.incident_resolved(game.high_risk_state,poi_id,0),"old defeated incident IDs were not adopted as resolved")

    # Discovery UI exposes state, but never loot profile or the solution to the lock.
    game.discovered_chunks[game._zone_chunk_key(anchor)] = true
    game.discovered_pois[poi_id] = true
    var tip = game._region_map_cell_tooltip(anchor)
    check(tip.find("ОПАСНОСТЬ 5/5") >= 0,"discovered High Risk tooltip lost risk rating")
    check(tip.find("СОСТОЯНИЕ") >= 0,"discovered High Risk tooltip lost systemic state")
    for forbidden in ["clinical_core","АВАРИЙНЫЙ ДОПУСК","этаж 2","три кеша"]:
        check(tip.find(forbidden) < 0,"map tooltip leaks High Risk solution/loot: " + forbidden)

    for node in [incident_chunk,rebuilt,migrated]:
        node.queue_free()
    game.queue_free()
    await process_frame
    print("HIGH RISK MECHANICS 1.23-dev5: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
