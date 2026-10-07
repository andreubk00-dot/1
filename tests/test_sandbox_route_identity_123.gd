extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")

var checks := 0
var failures := 0

func check(ok:bool,msg:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)

func _initialize() -> void:
    call_deferred("run")

func _ids(rows:Array) -> Dictionary:
    var out = {}
    for row in rows:
        out[str(row.get("id",""))] = true
    return out

func run() -> void:
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var specs = {
        "perron_zarya_route":{"poi":"dacha_coop_zarya","risk":2,"profile":"rural_secure","days":4,"route":"route_perron_zarya","daily":"food"},
        "lazaret_hospital_route":{"poi":"district_hospital","risk":3,"profile":"medical_secure","days":5,"route":"route_lazaret_hospital","daily":"medicine"},
        "rubezh_police_route":{"poi":"district_police","risk":3,"profile":"police_secure","days":6,"route":"route_rubezh_police","daily":"security"},
        "mechanics_rail_depot":{"poi":"rail_depot","risk":4,"profile":"industrial_secure","days":7,"route":"route_mechanics_depot","daily":"technical"}
    }

    for template_id in specs.keys():
        var expected:Dictionary = specs[template_id]
        var contract = ContractCatalog.template(template_id)
        var poi = RegionCatalog.poi_by_id(str(expected["poi"]))
        check(not contract.is_empty(),template_id + " missing")
        check(not poi.is_empty(),str(expected["poi"]) + " missing")
        check(str(contract.get("poi_id","")) == str(expected["poi"]),template_id + " points at wrong POI")
        check(int(poi.get("risk",0)) == int(expected["risk"]),template_id + " risk identity drifted")
        check(game._target_farm_profile(poi) == str(expected["profile"]),template_id + " return profile mismatch")
        check(game._target_farm_refresh_days(poi) == int(expected["days"]),template_id + " return cadence mismatch")
        var keys = game._target_farm_expected_container_keys(poi)
        check(keys.size() == 1,template_id + " should have exactly one renewable authored reserve")
        var reward = contract.get("reward",{})
        var route = reward.get("route",{})
        check(str(route.get("id","")) == str(expected["route"]),template_id + " persistent route id drifted")
        check(float(route.get("daily_resources",{}).get(str(expected["daily"]),0.0)) > 0.0,template_id + " lost its faction-specific daily resource effect")

    # Loot identities are intentionally distinct and respect risk gating.
    var rural_secure = _ids(game.loot_tables.get("rural_secure",[]))
    var medical_secure = _ids(game.loot_tables.get("medical_secure",[]))
    var police_secure = _ids(game.loot_tables.get("police_secure",[]))
    var industrial_secure = _ids(game.loot_tables.get("industrial_secure",[]))
    check(rural_secure.has("canned_meat") and rural_secure.has("water") and rural_secure.has("grain"),"Zarya reserve lost civilian supply identity")
    check(rural_secure.has("hiking_backpack") and not rural_secure.has("ballistic_helmet") and not rural_secure.has("sks"),"Zarya reserve leaked combat-specialized loot")
    check(medical_secure.has("antibiotics") and medical_secure.has("trauma_kit"),"hospital reserve lost medical identity")
    check(police_secure.has("ammo_9x18") and police_secure.has("ballistic_helmet"),"police reserve lost security identity")
    check(industrial_secure.has("scrap") and industrial_secure.has("repair_kit"),"depot reserve lost technical identity")

    # Authored caches match the four profiles without turning the whole POI into a vending machine.
    var zarya_cell = PoiCatalog.cell("dacha_coop_zarya",Vector2i(-1,0))
    var depot_cell = PoiCatalog.cell("rail_depot",Vector2i(1,0))
    check(str(zarya_cell.get("loose_containers",[])[0].get("loot","")) == "rural_secure","Zarya target reserve is not authored")
    check(str(depot_cell.get("loose_containers",[])[0].get("loot","")) == "industrial_secure","depot target reserve is not authored")

    # Migration safety: a dev13 container keeps its exact items when dev14 attaches target-farm metadata.
    var zarya = RegionCatalog.poi_by_id("dacha_coop_zarya")
    var zarya_anchor:Vector2i = zarya.get("coord",Vector2i.ZERO)
    var zarya_coord = zarya_anchor + Vector2i(-1,0)
    var zkey = "%d:%d:container:cache_3" % [zarya_coord.x,zarya_coord.y]
    game.world_day = 12
    game.container_states[zkey] = {
        "name":"old dev13 cellar","loot_table":"rural","grid_w":game.CONTAINER_W,"grid_h":game.CONTAINER_H,
        "items":[{"id":"water","qty":1,"x":0,"y":0}]
    }
    var holder = Node2D.new()
    game.add_child(holder)
    game._create_container(holder,zarya_coord,Vector2.ZERO,"cache_3","rural_secure","Общий погребной резерв")
    check(str(game.container_states[zkey].get("loot_table","")) == "rural_secure","dev13 cellar did not adopt dev14 profile metadata")
    check(bool(game.container_states[zkey].get("target_farm",false)),"dev13 cellar did not become target reserve")
    check(game.container_states[zkey].get("items",[]).size() == 1 and str(game.container_states[zkey]["items"][0].get("id","")) == "water","dev14 migration rerolled existing player-visible cellar loot")

    # An already-empty old reserve starts its normal cooldown, but is not refilled for free on load.
    game.container_states[zkey]["items"] = []
    game.loot_refresh_sites = {}
    game._create_container(holder,zarya_coord,Vector2.ZERO,"cache_3","rural_secure","Общий погребной резерв")
    check(game.container_states[zkey].get("items",[]).is_empty(),"empty legacy reserve was silently rerolled")
    check(int(game._target_farm_site_state("dacha_coop_zarya").get("ready_day",0)) == 16,"empty legacy Zarya reserve did not schedule four-day recovery")
    game.world_day = 16
    check(game._prepare_target_farm_site(zarya),"Zarya reserve did not recover at authored cadence")
    check(not game.container_states[zkey].get("items",[]).is_empty(),"Zarya recovery produced no reserve")

    # Depot uses the same safe site-level machinery at a slower seven-day cadence.
    var depot = RegionCatalog.poi_by_id("rail_depot")
    var depot_anchor:Vector2i = depot.get("coord",Vector2i.ZERO)
    var depot_coord = depot_anchor + Vector2i(1,0)
    var dkey = "%d:%d:container:cache_3" % [depot_coord.x,depot_coord.y]
    game.world_day = 20
    game.loot_refresh_sites = {}
    game.container_states[dkey] = {
        "name":"dev14 depot reserve","loot_table":"industrial_secure","grid_w":game.CONTAINER_W,"grid_h":game.CONTAINER_H,
        "generated_day":20,"refresh_cycle":0,"poi_id":"rail_depot","target_farm":true,"items":[]
    }
    game._target_farm_schedule_if_cleared("rail_depot")
    check(int(game._target_farm_site_state("rail_depot").get("ready_day",0)) == 27,"depot reserve did not schedule seven-day recovery")
    game.world_day = 26
    check(not game._prepare_target_farm_site(depot),"depot reserve refreshed before seven-day cadence")
    game.world_day = 27
    check(game._prepare_target_farm_site(depot),"depot reserve did not recover at seven-day cadence")
    check(not game.container_states[dkey].get("items",[]).is_empty(),"depot recovery produced no technical reserve")

    holder.queue_free()
    game.queue_free()
    await process_frame
    print("SANDBOX ROUTE IDENTITY 1.23-dev14: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
