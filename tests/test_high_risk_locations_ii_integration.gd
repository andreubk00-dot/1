extends SceneTree

const Main = preload("res://main_script_mod.gd")
const Harness = preload("res://tests/rest_harness.gd")
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
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")

func _ids(table:Array) -> Dictionary:
    var out = {}
    for rec in table:
        out[str(rec.get("id",""))] = float(rec.get("chance",0.0))
    return out

func _prime_target_site(game, poi:Dictionary, empty:bool) -> Array:
    var keys = game._target_farm_expected_container_keys(poi)
    var profile = game._target_farm_profile(poi)
    for key in keys:
        game.container_states[key] = {
            "name":"QA integrated core",
            "loot_table":profile,
            "grid_w":game.CONTAINER_W,
            "grid_h":game.CONTAINER_H,
            "generated_day":game.world_day,
            "refresh_cycle":0,
            "poi_id":str(poi.get("id","")),
            "target_farm":true,
            "items":[] if empty else game._generate_loot(str(key),profile,game.CONTAINER_W,game.CONTAINER_H)
        }
    return keys

func _enemy_mix(game, profile:String, seed_value:int, samples:int) -> Dictionary:
    var rng = RandomNumberGenerator.new()
    rng.seed = seed_value
    var result = {"normal":0,"runner":0,"brute":0}
    for i in range(samples):
        var kind = game._infected_kind_for_encounter(profile,rng)
        result[kind] = int(result.get(kind,0)) + 1
    return result

func _total_pressure(poi_id:String) -> int:
    var total = 0
    for off in PoiCatalog.footprint(poi_id):
        total += int(PoiCatalog.cell(poi_id,off).get("enemy_count",0))
    return total

func _cleanup_save(path:String):
    for suffix in ["",".bak",".tmp"]:
        var full = ProjectSettings.globalize_path(path + suffix)
        if FileAccess.file_exists(path + suffix):
            DirAccess.remove_absolute(full)

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var clinical_id = "regional_clinical_complex_4"
    var vector_id = "underground_object_vector"
    var clinical = RegionCatalog.poi_by_id(clinical_id)
    var vector = RegionCatalog.poi_by_id(vector_id)
    check(not clinical.is_empty() and not vector.is_empty(), "tier-2 endgame POIs must both be active")
    check(str(clinical.get("status","")) == "active_integrated" and str(vector.get("status","")) == "active_integrated", "operation-5 integration status missing")
    check(clinical.get("hard_requirements",["bad"]).is_empty() and vector.get("hard_requirements",["bad"]).is_empty(), "no-self-key contract broken during integration")
    check(game._target_farm_profile(clinical) == "clinical_core" and game._target_farm_refresh_days(clinical) == 12, "clinical core cooldown integration mismatch")
    check(game._target_farm_profile(vector) == "vector_core" and game._target_farm_refresh_days(vector) == 14, "Vector core cooldown integration mismatch")
    check(int(game.LOOT_PROFILE_RISK.get("clinical_core",0)) == 5 and int(game.LOOT_PROFILE_RISK.get("vector_core",0)) == 5, "tier-2 loot profiles must stay risk 5")

    # Loot identity stays distinct: hospital = medical survival, Vector = technical autonomy.
    var clinical_loot = _ids(game.loot_tables.get("clinical_core",[]))
    var vector_loot = _ids(game.loot_tables.get("vector_core",[]))
    for id in ["sterile_bandage","antiseptic","antibiotics","trauma_kit"]:
        check(clinical_loot.has(id), "clinical core lost medical identity item " + id)
    for id in ["scrap","tape","repair_kit","water_filter","flashlight"]:
        check(vector_loot.has(id), "Vector core lost technical identity item " + id)
    for weapon_id in game.weapon_defs.keys():
        check(not clinical_loot.has(str(weapon_id)), "clinical core became an armory: " + str(weapon_id))
        check(not vector_loot.has(str(weapon_id)), "Vector core became an armory: " + str(weapon_id))
    var overlap = 0
    for id in clinical_loot.keys():
        if vector_loot.has(id):
            overlap += 1
    check(overlap <= 1, "tier-2 core loot identities overlap too heavily")
    check(vector_loot.has("expedition_pack") and not clinical_loot.has("expedition_pack"), "Vector should retain expedition-gear identity")
    check(clinical_loot.has("trauma_kit") and not vector_loot.has("trauma_kit"), "clinical complex should retain trauma-care identity")

    # Only the deepest core caches are renewable; intermediate secure loot remains finite.
    var clinical_keys = game._target_farm_expected_container_keys(clinical)
    var vector_keys = game._target_farm_expected_container_keys(vector)
    check(clinical_keys.size() == 3, "clinical core must expose exactly three renewable caches")
    check(vector_keys.size() == 3, "Vector core must expose exactly three renewable caches")
    var all_keys = {}
    for spec in [[clinical_id,clinical,clinical_keys,"clinical_core"],[vector_id,vector,vector_keys,"vector_core"]]:
        var poi_id = str(spec[0])
        var poi:Dictionary = spec[1]
        var keys:Array = spec[2]
        var profile = str(spec[3])
        var lookup = {}
        for key in keys:
            check(not all_keys.has(str(key)), "cross-location target cache key collision: " + str(key))
            all_keys[str(key)] = true
            lookup[str(key)] = true
        var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
        var compound = PoiCatalog.compound(poi_id)
        var core_offset:Vector2i = compound.get("core_offset",Vector2i(999,999))
        for off in PoiCatalog.footprint(poi_id):
            var cell = PoiCatalog.cell(poi_id,off)
            var coord = anchor + off
            for b in cell.get("buildings",[]):
                var cid = str(b.get("container_id",""))
                if cid == "":
                    continue
                var key = "%d:%d:container:%s" % [coord.x,coord.y,cid]
                var should_refresh = off == core_offset and str(b.get("loot","")) == profile
                check(lookup.has(key) == should_refresh, poi_id + " building target selection leaked outside core: " + key)
            for c in cell.get("loose_containers",[]):
                var cid = str(c.get("id",""))
                if cid == "":
                    continue
                var key = "%d:%d:container:%s" % [coord.x,coord.y,cid]
                var should_refresh = off == core_offset and str(c.get("loot","")) == profile
                check(lookup.has(key) == should_refresh, poi_id + " loose target selection leaked outside core: " + key)

    # Existing dev2/dev3 saves may contain the core caches without target-farm metadata.
    # Production authored build must attach metadata without rerolling player/container contents.
    for spec in [[clinical_id,clinical,clinical_keys],[vector_id,vector,vector_keys]]:
        var poi_id = str(spec[0])
        var poi:Dictionary = spec[1]
        var keys:Array = spec[2]
        game.container_states = {}
        game.loot_refresh_sites = {}
        game.world_day = 50
        for key in keys:
            game.container_states[str(key)] = {
                "name":"legacy tier-2 cache","loot_table":game._target_farm_profile(poi),
                "grid_w":game.CONTAINER_W,"grid_h":game.CONTAINER_H,
                "generated_day":12,"refresh_cycle":0,"target_farm":false,"items":[]
            }
        var core_offset:Vector2i = PoiCatalog.compound(poi_id).get("core_offset",Vector2i.ZERO)
        var coord:Vector2i = poi.get("coord",Vector2i.ZERO) + core_offset
        var chunk = Node2D.new()
        game.add_child(chunk)
        check(game._build_major_poi_chunk(chunk,coord,game._chunk_profile(coord)), poi_id + " core production build failed during metadata migration")
        for key in keys:
            check(bool(game.container_states[str(key)].get("target_farm",false)), poi_id + " old core cache did not adopt target-farm metadata")
            check(str(game.container_states[str(key)].get("poi_id","")) == poi_id, poi_id + " old core cache did not adopt poi id")
            check(game.container_states[str(key)].get("items",[1]).is_empty(), poi_id + " migration rerolled an already emptied core cache")
        var site = game._target_farm_site_state(poi_id)
        check(int(site.get("cleared_day",0)) == 50, poi_id + " migrated empty core did not schedule clear day")
        check(int(site.get("ready_day",0)) == 50 + game._target_farm_refresh_days(poi), poi_id + " migrated empty core scheduled wrong cooldown")
        chunk.queue_free()

    # Final integrated pressure: tier-2 sites are denser than generation-one dungeons,
    # while their composition remains tactically different rather than just more HP.
    check(_total_pressure(clinical_id) == 54, "clinical integrated infected budget changed unexpectedly")
    check(_total_pressure(vector_id) == 58, "Vector integrated infected budget changed unexpectedly")
    check(_total_pressure(clinical_id) > _total_pressure("quarantine_center_12"), "clinical tier-2 pressure must exceed quarantine tier-1")
    check(_total_pressure(vector_id) > _total_pressure("reserve_arsenal_bastion"), "Vector tier-2 pressure must exceed Bastion tier-1")
    var clinical_mix = _enemy_mix(game,"clinical_core",120005,2000)
    var vector_mix = _enemy_mix(game,"vector_core",120006,2000)
    check(int(clinical_mix.get("runner",0)) > int(clinical_mix.get("brute",0)), "clinical core must remain runner-heavy")
    check(int(vector_mix.get("brute",0)) > int(vector_mix.get("runner",0)), "Vector core must remain brute-heavy")
    check(int(vector_mix.get("brute",0)) > int(clinical_mix.get("brute",0)), "Vector core needs stronger brute pressure than clinical core")
    check(int(clinical_mix.get("runner",0)) > int(vector_mix.get("runner",0)), "clinical core needs stronger runner pressure than Vector core")

    # Independent site-level cooldowns. A full core clear schedules refresh; partial
    # looting does not. Reoccupation always restores deep/core pressure, while the
    # outer perimeter may stay partly cleared; another POI must remain untouched.
    game.container_states = {}
    game.loot_refresh_sites = {}
    game.defeated = {}
    game.world_day = 30
    clinical_keys = _prime_target_site(game,clinical,true)
    vector_keys = _prime_target_site(game,vector,true)
    game.container_states[clinical_keys[0]]["items"] = [{"id":"bandage","qty":1,"x":0,"y":0}]
    game._target_farm_schedule_if_cleared(clinical_id)
    check(int(game._target_farm_site_state(clinical_id).get("ready_day",0)) == 0, "partial clinical clear started cooldown")
    game.container_states[clinical_keys[0]]["items"] = []
    game._target_farm_note_container_change(clinical_keys[0],false)
    check(int(game._target_farm_site_state(clinical_id).get("ready_day",0)) == 42, "clinical cooldown must be 12 days")
    game.world_day = 31
    game._target_farm_schedule_if_cleared(vector_id)
    check(int(game._target_farm_site_state(vector_id).get("ready_day",0)) == 45, "Vector cooldown must be 14 days")

    var clinical_anchor:Vector2i = clinical.get("coord",Vector2i.ZERO)
    var vector_anchor:Vector2i = vector.get("coord",Vector2i.ZERO)
    var clinical_core_coord = clinical_anchor + PoiCatalog.compound(clinical_id).get("core_offset",Vector2i.ZERO)
    var vector_core_coord = vector_anchor + PoiCatalog.compound(vector_id).get("core_offset",Vector2i.ZERO)
    var clinical_dead = "%d:%d:%d" % [clinical_core_coord.x,clinical_core_coord.y,0]
    var vector_dead = "%d:%d:%d" % [vector_core_coord.x,vector_core_coord.y,0]
    var unrelated_dead = "99:99:0"
    game.defeated[clinical_dead] = true
    game.defeated[vector_dead] = true
    game.defeated[unrelated_dead] = true
    game.world_day = 41
    check(not game._prepare_target_farm_site(clinical), "clinical refreshed before day 42")
    game.world_day = 42
    check(game._prepare_target_farm_site(clinical), "clinical did not refresh at day 42")
    check(not game.defeated.has(clinical_dead), "clinical refresh did not restore local threat")
    check(game.defeated.has(vector_dead), "clinical refresh incorrectly reset Vector threat")
    check(game.defeated.has(unrelated_dead), "clinical refresh erased unrelated threat")
    check(int(game._target_farm_site_state(clinical_id).get("cycle",0)) == 1, "clinical refresh cycle did not advance")
    var clinical_refilled = false
    for key in clinical_keys:
        clinical_refilled = clinical_refilled or not game.container_states[key].get("items",[]).is_empty()
    check(clinical_refilled, "clinical refresh produced no core loot")
    game.world_day = 44
    check(not game._prepare_target_farm_site(vector), "Vector refreshed before day 45")
    game.world_day = 45
    check(game._prepare_target_farm_site(vector), "Vector did not refresh at day 45")
    check(not game.defeated.has(vector_dead), "Vector refresh did not restore local threat")
    check(game.defeated.has(unrelated_dead), "Vector refresh erased unrelated threat")
    check(int(game._target_farm_site_state(vector_id).get("cycle",0)) == 1, "Vector refresh cycle did not advance")
    var vector_refilled = false
    for key in vector_keys:
        vector_refilled = vector_refilled or not game.container_states[key].get("items",[]).is_empty()
    check(vector_refilled, "Vector refresh produced no core loot")

    # Discovery-first survives target farming: map reveals discovered danger/place,
    # never the internal profile, cache contents, route solution, or cooldown.
    for spec in [[clinical_id,clinical],[vector_id,vector]]:
        var poi_id = str(spec[0])
        var poi:Dictionary = spec[1]
        var coord:Vector2i = poi.get("coord",Vector2i.ZERO)
        var hidden_tip = game._region_map_cell_tooltip(coord)
        check(hidden_tip.find(str(poi.get("short_name",""))) < 0, poi_id + " name leaked before POI discovery")
        game.discovered_chunks[game._zone_chunk_key(coord)] = true
        game.discovered_pois[poi_id] = true
        var tip = game._region_map_cell_tooltip(coord)
        check(tip.find("ОПАСНОСТЬ 5/5") >= 0, poi_id + " discovered map lost danger rating")
        for forbidden in ["Целевая добыча","восстанов","refresh","clinical_core","vector_core","Хирургический аварийный резерв","Аварийный инженерный резерв"]:
            check(tip.find(forbidden) < 0, poi_id + " map leaks operation-5 farming knowledge: " + forbidden)

    # Production disk round-trip: both new site schedules, discovery, core state and
    # defeated records survive while remaining compatible with the current save schema.
    var saver = Main.new()
    saver._load_data()
    saver.player = CharacterBody2D.new()
    saver.add_child(saver.player)
    saver.player.global_position = Vector2(-1234.0,5678.0)
    saver.world_day = 77
    saver.loot_refresh_sites = {
        clinical_id:{"cycle":2,"ready_day":88,"cleared_day":76,"last_refresh_day":64},
        vector_id:{"cycle":3,"ready_day":91,"cleared_day":77,"last_refresh_day":63}
    }
    saver.discovered_pois = {clinical_id:true,vector_id:true}
    saver.discovered_chunks = {
        saver._zone_chunk_key(clinical_anchor):true,
        saver._zone_chunk_key(vector_anchor):true
    }
    var clinical_save_key = str(game._target_farm_expected_container_keys(clinical)[0])
    var vector_save_key = str(game._target_farm_expected_container_keys(vector)[0])
    saver.container_states = {
        clinical_save_key:{"name":"clinical","loot_table":"clinical_core","grid_w":8,"grid_h":8,"poi_id":clinical_id,"target_farm":true,"items":[]},
        vector_save_key:{"name":"vector","loot_table":"vector_core","grid_w":8,"grid_h":8,"poi_id":vector_id,"target_farm":true,"items":[{"id":"repair_kit","qty":1,"x":0,"y":0}]}
    }
    saver.defeated = {clinical_dead:true,vector_dead:true}
    _cleanup_save(saver.SAVE_PATH)
    saver._save_state()
    check(FileAccess.file_exists(saver.SAVE_PATH), "operation-5 production save was not written")
    var raw = JSON.parse_string(FileAccess.get_file_as_string(saver.SAVE_PATH))
    check(int(raw.get("save_version",0)) == 122 and raw.has("faction_state"), "current 1.22 save schema must include faction economy")
    check(raw.get("loot_refresh_sites",{}).has(clinical_id) and raw.get("loot_refresh_sites",{}).has(vector_id), "tier-2 farm schedules missing from serialized save")

    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    check(int(loaded.loot_refresh_sites.get(clinical_id,{}).get("ready_day",0)) == 88, "clinical cooldown lost on production load")
    check(int(loaded.loot_refresh_sites.get(vector_id,{}).get("ready_day",0)) == 91, "Vector cooldown lost on production load")
    check(bool(loaded.discovered_pois.get(clinical_id,false)) and bool(loaded.discovered_pois.get(vector_id,false)), "tier-2 discovery state lost on production load")
    check(loaded.container_states.has(clinical_save_key) and loaded.container_states.has(vector_save_key), "tier-2 core container state lost on production load")
    check(loaded.container_states[clinical_save_key].get("items",[1]).is_empty(), "empty clinical core cache regenerated during save/load")
    check(str(loaded.container_states[vector_save_key].get("items",[])[0].get("id","")) == "repair_kit", "Vector core player/container contents changed on load")
    check(loaded.defeated.has(clinical_dead) and loaded.defeated.has(vector_dead), "tier-2 defeated persistence lost on production load")
    _cleanup_save(saver.SAVE_PATH)
    saver.free()
    loaded.free()

    game.free()
    print("HIGH RISK LOCATIONS II INTEGRATION: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
