extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize():
    call_deferred("run")

func _poi_contains_chunk(poi:Dictionary,coord:Vector2i) -> bool:
    var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
    for off in poi.get("footprint",[Vector2i.ZERO]):
        if anchor + off == coord:
            return true
    return false

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var original_version = ProjectSettings.get_setting("application/config/version","")
    check(str(original_version) == "1.22.0-dev3", "1.22-dev3 project version mismatch")
    check(game._developer_pois().size() == RegionCatalog.POIS.size(), "developer POI list must cover all active main POIs")
    check(RegionCatalog.POIS.size() >= 13, "main POI catalog unexpectedly shrank")

    # Stable release guard is still tested explicitly even though this branch is a dev build.
    ProjectSettings.set_setting("application/config/version","1.22.0")
    check(not game._developer_tools_available(), "developer tools must be unavailable in a stable build")
    game.developer_invulnerable = false
    game._developer_set_invulnerable(true)
    check(not game.developer_invulnerable, "stable guard allowed invulnerability")
    game.developer_no_aggro = false
    game._developer_set_no_aggro(true)
    check(not game.developer_no_aggro, "stable guard allowed no-aggro")
    check(not game._developer_teleport_to_poi("central_clinic"), "stable guard allowed developer teleport")
    ProjectSettings.set_setting("application/config/version",original_version)
    check(game._developer_tools_available(), "developer tools did not enable in 1.22-dev3")

    # Invulnerability blocks direct enemy hits and normalizes combat/medical damage state.
    game.developer_invulnerable = true
    game.health = 13.0
    game.bleeding = true
    game.bleed_damage_taken = 12.0
    game.pain = 77.0
    game.wound_contamination = 66.0
    game.wound_infection = 44.0
    game.body_condition = {"head":12.0,"torso":23.0,"arms":34.0,"legs":45.0}
    game._developer_apply_invulnerability()
    check(is_equal_approx(game.health,100.0), "invulnerability did not restore health")
    check(not game.bleeding and is_equal_approx(game.bleed_damage_taken,0.0), "invulnerability did not clear bleeding")
    check(is_equal_approx(game.pain,0.0), "invulnerability did not clear pain")
    check(is_equal_approx(game.wound_contamination,0.0) and is_equal_approx(game.wound_infection,0.0), "invulnerability did not clear wound state")
    for zone in ["head","torso","arms","legs"]:
        check(is_equal_approx(float(game.body_condition.get(zone,0.0)),100.0), "invulnerability did not restore body zone " + zone)
    var before_hit = game.health
    game._apply_enemy_hit(999.0)
    check(is_equal_approx(game.health,before_hit), "enemy hit bypassed developer invulnerability")

    # Hunger/thirst remain real so survival systems can still be tested under god mode.
    game.hunger = 22.0
    game.thirst = 17.0
    game._developer_apply_invulnerability()
    check(is_equal_approx(game.hunger,22.0) and is_equal_approx(game.thirst,17.0), "god mode should not freeze hunger/thirst")

    # No-aggro must neutralize an already alerted infected, not merely prevent new vision.
    var enemy = CharacterBody2D.new()
    enemy.global_position = Vector2(12,0)
    enemy.add_to_group("infected")
    enemy.set_meta("spawn_pending",false)
    enemy.set_meta("ai_state","chase")
    enemy.set_meta("ai_state_time",5.0)
    enemy.set_meta("suspicion",100.0)
    enemy.set_meta("lost_sight_time",1.0)
    enemy.set_meta("can_see_player",true)
    enemy.set_meta("attack_cd",0.2)
    enemy.set_meta("attack_anim",0.2)
    enemy.set_meta("home_position",Vector2(40,40))
    enemy.velocity = Vector2(50,0)
    game.add_child(enemy)
    game.developer_no_aggro = true
    game._developer_force_enemy_passive(enemy)
    check(str(enemy.get_meta("ai_state","")) == "idle", "no-aggro did not reset chase")
    check(is_equal_approx(float(enemy.get_meta("suspicion",-1.0)),0.0), "no-aggro did not clear suspicion")
    check(not bool(enemy.get_meta("can_see_player",true)), "no-aggro left player visible")
    check(enemy.velocity == Vector2.ZERO, "no-aggro did not stop infected movement")
    check(not game._enemy_detects_player(enemy,1.0), "no-aggro vision guard failed")
    game._update_enemies(0.1)
    check(str(enemy.get_meta("ai_state","")) == "idle" and enemy.velocity == Vector2.ZERO, "enemy update escaped passive dev state")

    # Turning no-aggro on through the public toggle immediately neutralizes current infected.
    enemy.set_meta("ai_state","search")
    enemy.set_meta("suspicion",60.0)
    game.developer_no_aggro = false
    game._developer_set_no_aggro(true)
    check(game.developer_no_aggro, "dev no-aggro toggle did not enable")
    check(str(enemy.get_meta("ai_state","")) == "idle" and is_equal_approx(float(enemy.get_meta("suspicion",1.0)),0.0), "toggle did not neutralize existing infected")

    # Teleport destinations must land inside the declared footprint for every active POI.
    var seen = {}
    for poi in game._developer_pois():
        var poi_id = str(poi.get("id",""))
        check(poi_id != "" and not seen.has(poi_id), "developer teleport list contains missing/duplicate POI id")
        seen[poi_id] = true
        var destination:Vector2 = game._developer_poi_entry_position(poi)
        var destination_chunk = game._world_to_chunk(destination)
        check(_poi_contains_chunk(poi,destination_chunk), "teleport destination leaves POI footprint: " + poi_id)
        var local_pos = destination - Vector2(destination_chunk.x * game.CHUNK_SIZE,destination_chunk.y * game.CHUNK_SIZE)
        check(local_pos.x >= 24.0 and local_pos.x <= game.CHUNK_SIZE - 24.0 and local_pos.y >= 24.0 and local_pos.y <= game.CHUNK_SIZE - 24.0, "teleport destination too close to chunk edge: " + poi_id)

    var clinical = RegionCatalog.poi_by_id("regional_clinical_complex_4")
    var vector = RegionCatalog.poi_by_id("underground_object_vector")
    check(game._world_to_chunk(game._developer_poi_entry_position(clinical)) == Vector2i(-9,1), "Clinical teleport must use authored entry sector")
    check(game._world_to_chunk(game._developer_poi_entry_position(vector)) == Vector2i(7,-7), "Vector teleport must use authored entry sector")

    # UI is a dedicated dev-only layer with separate mode/teleport tabs and one button per POI.
    game.inventory_open = false
    game._create_developer_ui()
    check(game.developer_panel != null and game.developer_hud_button != null, "developer panel/HUD button not created")
    check(game.developer_panel.name == "DeveloperPanel", "developer panel name mismatch")
    check(game.developer_hud_button.text.find("F10") >= 0, "developer HUD button must advertise F10")
    var tabs = game.developer_panel.get_node_or_null("DeveloperTabs") if game.developer_panel != null else null
    check(tabs != null and tabs.get_tab_count() == 2, "developer UI must expose separate mode and teleport tabs")
    check(game.developer_teleport_list != null, "developer teleport list missing")
    check(game.developer_teleport_list.get_child_count() == game._developer_pois().size(), "teleport UI button count does not match POI catalog")
    var button_ids = {}
    if game.developer_teleport_list != null:
        for child in game.developer_teleport_list.get_children():
            var id = str(child.get_meta("developer_poi_id",""))
            check(id != "" and not button_ids.has(id), "teleport UI has missing/duplicate target id")
            button_ids[id] = true
    check(button_ids.size() == RegionCatalog.POIS.size(), "teleport UI does not cover every main POI")

    game._open_developer_panel()
    check(game.developer_panel_open and game.developer_panel.visible, "F10 panel open state failed")
    game._close_developer_panel()
    check(not game.developer_panel_open and not game.developer_panel.visible, "developer panel close state failed")

    # Public teleport path uses production chunk refresh. Central clinic is a light smoke target.
    game.developer_invulnerable = true
    var teleported = game._developer_teleport_to_poi("central_clinic")
    check(teleported, "developer teleport action failed")
    check(game.current_chunk == Vector2i(0,0), "developer teleport did not refresh current chunk")
    check(game._world_to_chunk(game.player.global_position) == Vector2i(0,0), "player did not arrive in target POI chunk")
    check(not game._developer_teleport_to_poi("does_not_exist"), "unknown POI teleport should fail safely")

    game._developer_disable_all()
    check(not game.developer_invulnerable and not game.developer_no_aggro, "disable-all did not clear developer toggles")
    check(game._developer_tools_available(), "developer tools unexpectedly disabled before dev test cleanup")

    ProjectSettings.set_setting("application/config/version",original_version)
    check(game._developer_tools_available(), "dev tools must remain enabled after stable-guard test cleanup")
    enemy.queue_free()
    game.free()
    print("DEVELOPER MODE: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
