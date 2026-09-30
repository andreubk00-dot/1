extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func _model_hash(game, id):
    var tex = game._weapon_model_texture(id)
    if tex == null:
        return 0
    var img = tex.get_image()
    if img == null:
        return 0
    return hash(img.get_data())

func _loot_ids(table):
    var out = {}
    for rec in table:
        out[str(rec.get("id",""))] = float(rec.get("chance",0.0))
    return out

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var expected = ["makarov","tt33","pps43","shotgun","toz34","izh81","sks","akm","aks74u","mosin"]
    check(game.FIREARM_IDS == expected, "canonical firearm order changed")
    for id in expected:
        check(game.weapon_defs.has(id), "missing weapon def: " + id)
        check(game.item_defs.has(id), "missing inventory item: " + id)
        check(game.weapon_mags.has(id), "missing runtime magazine state: " + id)
        check(game.weapon_condition.has(id), "missing runtime condition state: " + id)
        check(game.weapon_mods.has(id), "missing runtime mod state: " + id)
        check(game._weapon_model_texture(id) != null, "missing model texture: " + id)
        check(game._make_item_icon(id) != null, "missing inventory icon: " + id)
        check(game._make_world_loot_texture(id) != null, "missing world-loot icon: " + id)
        check(game._hud_display_texture(id) != null, "missing HUD art: " + id)
        check(game._world_loot_art_extent(id) <= 34, "world-loot art too large: " + id)
        var cfg = game.weapon_defs[id]
        check(game.item_defs.has(str(cfg.get("ammo",""))), "unknown ammo for: " + id)
        check(float(cfg.get("damage",0.0)) > 0.0, "zero damage: " + id)
        check(float(cfg.get("range",0.0)) > 100.0, "invalid range: " + id)
        check(float(cfg.get("reload",0.0)) > 0.0, "invalid reload time: " + id)
        check(float(cfg.get("recoil",0.0)) > 0.0, "invalid recoil duration: " + id)
        check(str(cfg.get("anim_prefix","")) != "", "missing animation prefix: " + id)

    check(game.item_defs.has("ammo_762x25"), "7.62x25 ammo item missing")
    check(game._make_item_icon("ammo_762x25") != null, "7.62x25 inventory icon missing")
    check(game._make_world_loot_texture("ammo_762x25") != null, "7.62x25 world icon missing")
    check(game._hud_ammo_display_name("ammo_762x25") == "7,62 ТТ", "7.62x25 HUD label mismatch")

    var pm = game.weapon_defs["makarov"]
    var tt = game.weapon_defs["tt33"]
    check(str(tt.get("ammo","")) == "ammo_762x25", "TT must use 7.62x25")
    check(int(tt.get("mag",0)) == 8, "TT magazine must be 8")
    check(float(tt.get("damage",0)) > float(pm.get("damage",0)), "TT must hit harder than PM")
    check(float(tt.get("spread",1)) < float(pm.get("spread",1)), "TT should be slightly more accurate than PM")
    check(float(tt.get("noise",0)) > float(pm.get("noise",0)), "TT power must carry a noise cost")
    check(game._player_pose_class("tt33") == "pistol", "TT must use pistol pose class")
    check(game._reload_transfer_amount("tt33",0,20) == 8, "TT reload must fill eight-round magazine")

    var pump = game.weapon_defs["shotgun"]
    var toz = game.weapon_defs["toz34"]
    check(str(toz.get("ammo","")) == "ammo_12g", "TOZ must share 12 gauge")
    check(int(toz.get("mag",0)) == 2, "TOZ must be double-barrel")
    check(int(toz.get("pellets",0)) >= int(pump.get("pellets",0)), "TOZ shot must not be weaker pellet-count wise")
    check(float(toz.get("damage",0)) > float(pump.get("damage",0)), "TOZ pellet damage must exceed pump shotgun")
    check(float(toz.get("spread",1)) < float(pump.get("spread",1)), "TOZ should have tighter hunting spread")
    check(not bool(toz.get("shellwise",true)), "TOZ break-action reload must not use pump shell loop")
    check(game._reload_transfer_amount("toz34",0,20) == 2, "TOZ reload must load both barrels")
    check(game._reload_duration_for_weapon("toz34") > game._reload_duration_for_weapon("shotgun"), "TOZ full reload must be slower than one pump-shell step")
    check(game._hud_fire_mode_label("toz34",toz) == "ПЕРЕЛОМ", "TOZ HUD mode must identify break action")

    var akm = game.weapon_defs["akm"]
    var sks = game.weapon_defs["sks"]
    check(str(sks.get("ammo","")) == "ammo_762", "SKS must share 7.62x39")
    check(int(sks.get("mag",0)) == 10, "SKS magazine must be 10")
    check(not bool(sks.get("automatic",true)), "SKS must remain semi-auto")
    check(float(sks.get("damage",0)) > float(akm.get("damage",0)), "SKS must reward deliberate shots with higher damage")
    check(float(sks.get("range",0)) > float(akm.get("range",0)), "SKS must have longer effective range than AKM")
    check(float(sks.get("interval",0)) > float(akm.get("interval",0)), "SKS must fire slower than AKM")
    check(float(sks.get("spread",1)) < float(akm.get("spread",1)), "SKS must be more accurate than AKM")
    check(game._reload_transfer_amount("sks",0,30) == 10, "SKS reload must fill 10-round internal magazine")

    # New weapon rows must be real distinct art, not empty aliases in model/HUD/world layers.
    var hashes = {}
    for id in expected:
        var h = _model_hash(game,id)
        check(h != 0, "empty model row: " + id)
        check(not hashes.has(h), "duplicate weapon model row: " + id)
        hashes[h] = id

    # Dedicated baked prefixes must exist for every clip used by the runtime.
    for id in ["tt33","toz34","sks"]:
        game.current_weapon_id = id
        game.equipped_melee_id = ""
        check(game._modern_survivor_firearm_variant_prefix() == id + "_", "wrong baked prefix: " + id)
        for clip in ["Attack1","Attack2","Attack3","Attack4","CrouchIdle","CrouchRun","Die","Idle","Idle2","Idle3","Run","RunAttack","RunBackwards","RunBackwardsAttack","StrafeLeft","StrafeLeftAttack","StrafeRight","StrafeRightAttack","TakeDamage","Taunt","Walk"]:
            check(ResourceLoader.exists("res://survivor_%s_%s.png" % [id,clip]), "missing baked sheet %s %s" % [id,clip])
            check(game._modern_survivor_sheet(clip) != null, "runtime cannot load baked sheet %s %s" % [id,clip])

    # Real firing path: each new weapon must consume its own magazine, apply
    # wear/cooldown and build the expected projectile/pellet pattern.
    game.inventory_open = false
    game.reload_time = 0.0
    game.equipped_melee_id = ""
    game.aim_direction = Vector2.RIGHT
    # The lightweight regression harness does not construct HUD-only fire FX.
    # Provide the same node interfaces so the production firing path can run.
    if game.tracer == null:
        game.tracer = Line2D.new()
        game.add_child(game.tracer)
    if game.muzzle_flash == null:
        game.muzzle_flash = Node2D.new()
        game.add_child(game.muzzle_flash)
    for id in ["tt33","toz34","sks"]:
        game.inventory_entries = [{"id":id,"qty":1,"x":0,"y":0}]
        game.current_weapon_id = id
        var live_iid = game.set_test_weapon_state(id,2,100.0)
        game._switch_weapon(id,live_iid)
        game.fire_cooldown = 0.0
        var cfg = game.weapon_defs[id]
        var dirs = game._weapon_shot_directions(cfg,Vector2.RIGHT)
        check(dirs.size() == int(cfg.get("pellets",1)), "wrong projectile count: " + id)
        game._fire_weapon()
        check(game._weapon_mag_value(id,live_iid) == 1, "live fire did not consume magazine: " + id)
        check(game._weapon_condition_value(id,live_iid) < 100.0, "live fire did not apply wear: " + id)
        check(abs(float(game.fire_cooldown) - float(cfg.get("interval",0.0))) < 0.001, "live fire cooldown mismatch: " + id)

    # Inventory equip path works without adding another hotbar system.
    game.inventory_entries = [
        {"id":"tt33","qty":1,"x":0,"y":0},
        {"id":"toz34","qty":1,"x":2,"y":0},
        {"id":"sks","qty":1,"x":5,"y":0}
    ]
    for id in ["tt33","toz34","sks"]:
        game._switch_weapon(id)
        check(game.current_weapon_id == id and game.equipped_melee_id == "", "inventory weapon switch failed: " + id)

    # Runtime-state migration: a pre-1.09 save has no new firearm dictionary keys.
    game.inventory_entries = []
    game.weapon_instance_states = {}
    game.current_weapon_instance_id = ""
    game.weapon_mags = {"makarov":4,"shotgun":1,"akm":7}
    game.weapon_condition = {"makarov":91.0,"shotgun":72.0,"akm":83.0}
    game._ensure_weapon_runtime_state(true)
    for id in ["tt33","toz34","sks"]:
        check(game.weapon_mags.has(id) and int(game.weapon_mags[id]) == 0, "old-save magazine migration failed: " + id)
        check(game.weapon_condition.has(id) and abs(float(game.weapon_condition[id])-100.0) < 0.001, "old-save condition migration failed: " + id)

    # Themed distribution prepares later rarity work without turning this stage into rarity itself.
    var police = _loot_ids(game.loot_tables.get("police",[]))
    var forest = _loot_ids(game.loot_tables.get("forest_cache",[]))
    var rural = _loot_ids(game.loot_tables.get("rural",[]))
    var hunting_secure = _loot_ids(game.loot_tables.get("hunting_secure",[]))
    var military = _loot_ids(game.loot_tables.get("military",[]))
    check(police.has("tt33") and police.has("ammo_762x25"), "police pool must support TT family")
    check(not police.has("sks") and not police.has("toz34"), "police pool must stay focused")
    check(not forest.has("toz34") and not forest.has("sks") and hunting_secure.has("toz34") and hunting_secure.has("sks"), "hunting long guns must be concentrated in the cordon secure pool")
    check(not rural.has("toz34") and not rural.has("sks"), "generic rural pool must not leak targeted hunting long guns")
    check(military.has("tt33") and military.has("sks"), "military pool must carry legacy service arms")
    check(float(hunting_secure.get("toz34",0.0)) >= 0.10 and float(hunting_secure.get("sks",0.0)) >= 0.05, "targeted hunting pool odds are too low")

    # Legacy quickbar stays deliberately stable.
    game.inventory_entries = [
        {"id":"makarov","qty":1,"x":0,"y":0},
        {"id":"shotgun","qty":1,"x":2,"y":0},
        {"id":"akm","qty":1,"x":5,"y":0}
    ]
    game.inventory_open = false
    check(game._select_quick_slot(1) and game.current_weapon_id == "makarov", "quickbar slot 1 changed")
    check(game._select_quick_slot(2) and game.current_weapon_id == "shotgun", "quickbar slot 2 changed")
    check(game._select_quick_slot(3) and game.current_weapon_id == "akm", "quickbar slot 3 changed")

    # 1.09.1 QA crate: only the authored all-items test fixture grows. Normal
    # gameplay containers remain 8x8 and use the same transfer/grid logic.
    check(game.CONTAINER_W == 8 and game.CONTAINER_H == 8, "normal container dimensions changed")
    check(game.QA_ALL_ITEMS_CONTAINER_W >= 16 and game.QA_ALL_ITEMS_CONTAINER_H == 8, "QA crate dimensions mismatch")
    check(game._container_grid_size({}) == Vector2i(8,8), "default container grid is not 8x8")
    check(game._container_grid_size({"grid_w":14,"grid_h":8}) == Vector2i(14,8), "custom QA grid size is not honored")
    var qa_entries = game._generate_loot("qa:test:arsenal","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var qa_ids = {}
    for rec in qa_entries:
        qa_ids[str(rec.get("id",""))] = true
    check(qa_ids.size() == game.item_defs.size(), "QA crate cannot physically pack the whole item catalogue")
    for id in expected:
        check(qa_ids.has(id), "QA crate missing firearm: " + id)
        check(qa_ids.has(str(game.weapon_defs[id].get("ammo",""))), "QA crate missing ammo for: " + id)

    # Existing saves may carry the old truncated 8x8 version of the same test box.
    # Spawning the authored showcase must expand/repack that fixture without
    # touching ordinary containers or requiring a save-version bump.
    var qa_chunk = Node2D.new()
    game.add_child(qa_chunk)
    var qa_key = "0:0:container:garage_all_items_0163"
    game.container_states[qa_key] = {
        "name":"ТЕСТ: ВСЕ ПРЕДМЕТЫ",
        "loot_table":"all_items_test",
        "items":[{"id":"makarov","qty":1,"x":0,"y":0}]
    }
    game._create_container(qa_chunk,Vector2i(0,0),Vector2.ZERO,"garage_all_items_0163","all_items_test","ТЕСТ: ВСЕ ПРЕДМЕТЫ",14,8)
    var migrated = game.container_states[qa_key]
    check(game._container_grid_size(migrated) == Vector2i(game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H), "old QA crate was not expanded")
    var migrated_ids = {}
    for rec in migrated.get("items",[]):
        migrated_ids[str(rec.get("id",""))] = true
    for id in expected:
        check(migrated_ids.has(id), "migrated QA crate missing firearm: " + id)
        check(migrated_ids.has(str(game.weapon_defs[id].get("ammo",""))), "migrated QA crate missing ammo for: " + id)

    # The test fires three real weapon samples in rapid succession and exits immediately.
    # Explicitly stop/clear the temporary audio voices before SceneTree shutdown so
    # the headless AudioServer does not retain playback/stream references at exit.
    for voice in game.weapon_audio_players:
        if is_instance_valid(voice):
            voice.stop()
            voice.stream = null
    if is_instance_valid(game.reload_audio_player):
        game.reload_audio_player.stop()
        game.reload_audio_player.stream = null
    if is_instance_valid(game.cycle_audio_player):
        game.cycle_audio_player.stop()
        game.cycle_audio_player.stream = null
    game.weapon_audio_cache.clear()
    # Give the headless AudioServer real time to retire playback objects; frame-only
    # waits can be too fast for the audio thread when the test runs uncapped.
    await create_timer(0.25).timeout

    # Defer SceneTree shutdown until this large test function has returned.
    var exit_code := 1 if failures else 0
    game.free()
    game = null
    print("ARSENAL EXPANSION: ", checks, " checks, ", failures, " failures")
    call_deferred("_finish_test", exit_code)

func _finish_test(exit_code: int) -> void:
    # Let AudioServer observe freed AudioStreamPlayer nodes before process exit.
    await create_timer(0.25).timeout
    quit(exit_code)
