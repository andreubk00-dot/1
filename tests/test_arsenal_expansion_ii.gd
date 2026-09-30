extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _model_hash(game, id):
    var tex = game._weapon_model_texture(id)
    if tex == null:
        return 0
    var img = tex.get_image()
    if img == null:
        return 0
    return hash(img.get_data())


func _sheet_hash(path):
    var tex = load(path)
    if tex == null:
        return 0
    var img = tex.get_image()
    if img == null:
        return 0
    return hash(img.get_data())

func _loot_has(game, table_id, item_id):
    for rec in game.loot_tables.get(table_id,[]):
        if str(rec.get("id","")) == item_id:
            return true
    return false

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var added = ["pps43","izh81","aks74u","mosin"]
    var expected = ["makarov","tt33","pps43","shotgun","toz34","izh81","sks","akm","aks74u","mosin"]
    check(game.FIREARM_IDS == expected,"1.18 canonical firearm order mismatch")

    check(game.item_defs.has("ammo_545"),"5.45x39 ammo missing")
    check(game.item_defs.has("ammo_762x54r"),"7.62x54R ammo missing")
    check(game._hud_ammo_display_name("ammo_545") == "5,45 мм","5.45 HUD label mismatch")
    check(game._hud_ammo_display_name("ammo_762x54r") == "7,62R","7.62R HUD label mismatch")

    var hashes = {}
    for id in expected:
        var h = _model_hash(game,id)
        check(h != 0,"missing model art: " + id)
        check(not hashes.has(h),"duplicate model art: " + id)
        hashes[h] = id

    # Audible layer is mandatory for the entire canonical firearm catalogue, not only new guns.
    for id in expected:
        check(ResourceLoader.exists(game._weapon_shot_audio_path(id)),"canonical firearm has no shot audio: " + id)
        check(ResourceLoader.exists(game._weapon_reload_audio_path(id)),"canonical firearm has no reload audio: " + id)
        check(str(game.weapon_defs[id].get("reload_audio","")) != "","canonical firearm missing reload profile: " + id)

    for id in added:
        check(game.item_defs.has(id),"missing item def: " + id)
        check(game.weapon_defs.has(id),"missing weapon def: " + id)
        check(game._make_item_icon(id) != null,"missing inventory art: " + id)
        check(game._make_world_loot_texture(id) != null,"missing world art: " + id)
        check(game._hud_display_texture(id) != null,"missing HUD art: " + id)
        check(game._world_loot_art_extent(id) <= 34,"world art too large: " + id)
        var cfg = game.weapon_defs[id]
        check(game.item_defs.has(str(cfg.get("ammo",""))),"unknown ammo: " + id)
        check(str(cfg.get("sound_profile","")) != "","missing sound profile: " + id)
        check(str(cfg.get("fx_profile","")) != "","missing FX profile: " + id)
        check(str(cfg.get("reload_audio","")) != "","missing reload audio profile: " + id)
        check(ResourceLoader.exists(game._weapon_shot_audio_path(id)),"missing audible gunshot asset: " + id)
        check(ResourceLoader.exists(game._weapon_reload_audio_path(id)),"missing audible reload asset: " + id)
        check(str(cfg.get("anim_prefix","")) == id,"weapon does not own animation prefix: " + id)

        # Static hand-placement contract: every authored grip/reload/muzzle point must be
        # inside the standardized source frame, and the muzzle must stay forward of both hands.
        var visual_cfg = game._held_visual_config(id,false)
        var source_size = visual_cfg.get("source_size",Vector2.ZERO)
        for point_key in ["rear_px","front_px","reload_px","muzzle_px"]:
            var point = visual_cfg.get(point_key,Vector2(-1,-1))
            check(point.x >= 0.0 and point.y >= 0.0 and point.x <= source_size.x and point.y <= source_size.y,"held visual point outside source frame: %s %s" % [id,point_key])
        check(float(visual_cfg.get("muzzle_px",Vector2.ZERO).x) > float(visual_cfg.get("front_px",Vector2.ZERO).x),"muzzle point is not forward of front hand: " + id)
        check(float(visual_cfg.get("front_px",Vector2.ZERO).x) > float(visual_cfg.get("rear_px",Vector2.ZERO).x),"front/rear hand order invalid: " + id)
        var quick_layout = game._hud_quick_icon_layout(id)
        check(float(quick_layout.get("size",Vector2.ZERO).x) >= 32.0,"new firearm quickbar art is undersized: " + id)

        for clip in ["Attack1","Attack2","Attack3","Attack4","CrouchIdle","CrouchRun","Die","Idle","Idle2","Idle3","Run","RunAttack","RunBackwards","RunBackwardsAttack","StrafeLeft","StrafeLeftAttack","StrafeRight","StrafeRightAttack","TakeDamage","Taunt","Walk"]:
            check(ResourceLoader.exists("res://survivor_%s_%s.png" % [id,clip]),"missing baked animation %s %s" % [id,clip])

        # 1.18 dev4: a dedicated prefix is not enough. The baked in-hands art itself
        # must differ from the legacy class template, otherwise different guns look identical.
        var clone_parent = {"pps43":"akm","izh81":"shotgun","aks74u":"akm","mosin":"akm"}[id]
        for visual_clip in ["Idle","Attack1","Taunt","Run"]:
            var own_hash = _sheet_hash("res://survivor_%s_%s.png" % [id,visual_clip])
            var parent_hash = _sheet_hash("res://survivor_%s_%s.png" % [clone_parent,visual_clip])
            check(own_hash != 0,"cannot read baked animation: %s %s" % [id,visual_clip])
            check(own_hash != parent_hash,"new firearm still clones legacy in-hands art: %s %s" % [id,visual_clip])

    var pps = game.weapon_defs["pps43"]
    var tt = game.weapon_defs["tt33"]
    check(str(pps.get("ammo","")) == "ammo_762x25","PPS-43 ammo mismatch")
    check(bool(pps.get("automatic",false)),"PPS-43 must be automatic")
    check(int(pps.get("mag",0)) == 35,"PPS-43 magazine mismatch")
    check(float(pps.get("interval",1.0)) < float(tt.get("interval",1.0)),"PPS-43 must fire faster than TT")
    check(float(pps.get("spread",0.0)) > float(tt.get("spread",0.0)),"PPS-43 must trade accuracy for volume")
    check(float(pps.get("damage",999.0)) < float(tt.get("damage",0.0)),"PPS-43 must not out-damage TT per bullet")
    check(float(pps.get("noise",9999.0)) < float(game.weapon_defs["akm"].get("noise",0.0)),"PPS-43 compact role needs lower gunshot footprint than AKM")

    var pump = game.weapon_defs["shotgun"]
    var izh = game.weapon_defs["izh81"]
    check(str(izh.get("ammo","")) == "ammo_12g","IZH-81 ammo mismatch")
    check(bool(izh.get("shellwise",false)),"IZH-81 must reload shell by shell")
    check(float(izh.get("spread",1.0)) < float(pump.get("spread",1.0)),"IZH-81 must be tighter than base shotgun")
    check(float(izh.get("interval",0.0)) > float(pump.get("interval",0.0)),"IZH-81 deliberate pump cadence missing")
    check(float(izh.get("range",0.0)) > float(pump.get("range",0.0)),"IZH-81 precision role needs longer reach")
    check(int(izh.get("pellets",99)) < int(pump.get("pellets",0)),"IZH-81 must trade pellet count for tighter precision")
    check(float(izh.get("damage",0.0)) * int(izh.get("pellets",0)) <= float(pump.get("damage",0.0)) * int(pump.get("pellets",0)),"IZH-81 must not be a strict per-shot damage upgrade")

    var akm = game.weapon_defs["akm"]
    var aksu = game.weapon_defs["aks74u"]
    check(str(aksu.get("ammo","")) == "ammo_545","AKS-74U ammo mismatch")
    check(bool(aksu.get("automatic",false)),"AKS-74U must be automatic")
    check(float(game.item_defs["aks74u"].get("weight",99.0)) < float(game.item_defs["akm"].get("weight",0.0)),"AKS-74U must be lighter than AKM")
    check(float(aksu.get("range",0.0)) < float(akm.get("range",0.0)),"AKS-74U must trade range for compactness")
    check(float(aksu.get("damage",999.0)) < float(akm.get("damage",0.0)),"AKS-74U must trade per-shot power for compactness")
    check(float(aksu.get("spread",0.0)) > float(akm.get("spread",0.0)),"AKS-74U must be less stable than full-length AKM")
    check(float(aksu.get("noise",9999.0)) < float(akm.get("noise",0.0)),"AKS-74U should carry a smaller noise footprint than AKM")

    var mosin = game.weapon_defs["mosin"]
    var sks = game.weapon_defs["sks"]
    check(str(mosin.get("ammo","")) == "ammo_762x54r","Mosin ammo mismatch")
    check(not bool(mosin.get("automatic",true)),"Mosin cannot be automatic")
    check(bool(mosin.get("shellwise",false)),"Mosin must reload individual rounds")
    check(int(mosin.get("mag",0)) == 5,"Mosin internal magazine mismatch")
    check(float(mosin.get("damage",0.0)) > float(sks.get("damage",0.0)),"Mosin must reward precision with damage")
    check(float(mosin.get("range",0.0)) > float(sks.get("range",0.0)),"Mosin must outrange SKS")
    check(float(mosin.get("noise",0.0)) > float(sks.get("noise",0.0)),"Mosin power needs noise cost")
    check(float(mosin.get("interval",0.0)) > float(sks.get("interval",0.0)),"Mosin bolt-action cadence must be slower than SKS")
    check(float(game.item_defs["mosin"].get("weight",0.0)) > float(game.item_defs["sks"].get("weight",99.0)),"Mosin long-range role needs a carry-weight cost")

    # Reload mechanics must use the normal production path.
    check(game._reload_transfer_amount("pps43",0,60) == 35,"PPS reload mismatch")
    check(game._reload_transfer_amount("izh81",0,20) == 1,"IZH shell reload mismatch")
    check(game._reload_transfer_amount("aks74u",0,60) == 30,"AKS-74U reload mismatch")
    check(game._reload_transfer_amount("mosin",0,20) == 1,"Mosin shell reload mismatch")

    # All additions are obtainable through authored internal pools without exposing those sources in UI.
    check(_loot_has(game,"police_secure","pps43") or _loot_has(game,"military","pps43"),"PPS-43 has no authored source")
    check(_loot_has(game,"hunting_secure","izh81") or _loot_has(game,"police_secure","izh81"),"IZH-81 has no authored source")
    check(_loot_has(game,"military_secure","aks74u") or _loot_has(game,"arsenal_core","aks74u"),"AKS-74U has no authored source")
    check(_loot_has(game,"hunting_secure","mosin") or _loot_has(game,"arsenal_core","mosin"),"Mosin has no authored source")

    # Production fire path: ammo, condition and cadence are instance-specific.
    game.inventory_open = false
    game.reload_time = 0.0
    game.equipped_melee_id = ""
    game.aim_direction = Vector2.RIGHT
    if game.tracer == null:
        game.tracer = Line2D.new()
        game.add_child(game.tracer)
    if game.muzzle_flash == null:
        game.muzzle_flash = Node2D.new()
        game.add_child(game.muzzle_flash)
    for id in added:
        game.inventory_entries = [{"id":id,"qty":1,"x":0,"y":0}]
        game.current_weapon_id = id
        var iid = game.set_test_weapon_state(id,2,100.0)
        game._switch_weapon(id,iid)
        game.fire_cooldown = 0.0
        game._fire_weapon()
        check(game._weapon_mag_value(id,iid) == 1,"live fire did not consume round: " + id)
        check(game._weapon_condition_value(id,iid) < 100.0,"live fire did not wear weapon: " + id)

    # QA catalogue is data-driven: every new gun and caliber appears automatically.
    var qa_entries = game._generate_loot("qa:test:arsenal2","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var qa_ids = {}
    for rec in qa_entries:
        qa_ids[str(rec.get("id",""))] = true
    for id in added + ["ammo_545","ammo_762x54r"]:
        check(qa_ids.has(id),"QA all-items missing: " + id)

    # Stop/clear the temporary audio layer created by the production fire-path checks.
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
    await create_timer(0.25).timeout

    # Let AudioServer retire playback objects after the production fire-path checks.
    var exit_code := 1 if failures else 0
    game.free()
    game = null
    print("ARSENAL EXPANSION II: ",checks," checks, ",failures," failures")
    call_deferred("_finish_test", exit_code)

func _finish_test(exit_code: int) -> void:
    await create_timer(0.25).timeout
    quit(exit_code)
