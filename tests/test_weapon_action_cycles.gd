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

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    # This suite intentionally validates authored pump/bolt cycle audio.
    game.test_audio_enabled = true
    game._create_weapon_audio_layer()
    check(game.cycle_audio_player != null,"post-shot cycle audio player missing")
    check(ResourceLoader.exists("res://audio/weapons/pump_cycle.wav"),"pump-cycle audio asset missing")
    check(ResourceLoader.exists("res://audio/weapons/bolt_cycle.wav"),"bolt-cycle audio asset missing")
    check(game._weapon_cycle_audio_path("pump").ends_with("pump_cycle.wav"),"pump cycle path wrong")
    check(game._weapon_cycle_audio_path("bolt").ends_with("bolt_cycle.wav"),"bolt cycle path wrong")
    check(game._weapon_cycle_audio_path("invalid") == "","unknown cycle profile must not resolve")

    for record in [["shotgun","pump"],["izh81","pump"],["mosin","bolt"]]:
        var weapon_id = str(record[0])
        var profile = str(record[1])
        var cfg = game.weapon_defs[weapon_id]
        check(str(cfg.get("action_cycle","")) == profile,weapon_id + " cycle profile missing")
        check(float(cfg.get("cycle_delay",-1.0)) >= 0.0,weapon_id + " cycle delay invalid")
        check(float(cfg.get("cycle_duration",0.0)) > 0.0,weapon_id + " cycle duration invalid")
        check(float(cfg.get("cycle_delay",0.0)) + float(cfg.get("cycle_duration",0.0)) < float(cfg.get("interval",0.0)),weapon_id + " cycle must finish before next allowed shot")
        game.current_weapon_id = weapon_id
        game.equipped_melee_id = ""
        game._schedule_weapon_cycle(weapon_id,cfg)
        check(game.weapon_cycle_time > game.weapon_cycle_duration,weapon_id + " cycle must start with authored delay")
        check(game.weapon_cycle_audio_pending,weapon_id + " cycle audio was not armed")
        check(game._weapon_cycle_progress() < 0.0,weapon_id + " Attack2 must not start before cycle delay")
        game.weapon_cycle_time = game.weapon_cycle_duration * 0.5
        var p = game._weapon_cycle_progress()
        check(p > 0.45 and p < 0.55,weapon_id + " cycle progress mapping broken")
        check(game._modern_survivor_clip(weapon_id,Vector2.RIGHT,Vector2.ZERO,false) == "Attack2",weapon_id + " cycle must select Attack2 baked animation")
        game._play_weapon_cycle_audio(profile)
        check(game.cycle_audio_player.stream != null,weapon_id + " cycle audio did not load")
        game._cancel_weapon_cycle()
        check(game.weapon_cycle_time == 0.0 and game.weapon_cycle_profile == "",weapon_id + " cycle did not cancel cleanly")

    # Self-loading and break-action guns must not invent a pump/bolt action.
    for weapon_id in ["makarov","tt33","pps43","toz34","sks","akm","aks74u"]:
        check(str(game.weapon_defs[weapon_id].get("action_cycle","")) == "",weapon_id + " incorrectly has a manual post-shot action")

    # Reload cannot overlap an unfinished pump/bolt action on the same weapon.
    # The shared rest harness starts with a modal inventory/rest state, so enter
    # normal combat mode before testing reload priority.
    game.inventory_open = false
    game.rest_open = false
    game.crafting_open = false
    game.base_build_open = false
    game.mod_panel_open = false
    game.region_map_open = false
    game.inventory_entries = [{"id":"izh81","qty":1,"x":0,"y":0},{"id":"ammo_12g","qty":4,"x":2,"y":0}]
    var iid = game.set_test_weapon_state("izh81",1,100.0)
    game._switch_weapon("izh81",iid)
    game._schedule_weapon_cycle("izh81",game.weapon_defs["izh81"])
    check(game._reload_block_reason("izh81",iid) == "Механика оружия ещё в движении","reload must wait for pump action")
    game._cancel_weapon_cycle()
    check(game._reload_block_reason("izh81",iid) == "","reload should unlock after pump action")

    var exit_code := 1 if failures else 0
    # Explicitly release AudioServer-backed streams before freeing the harness.
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
    await process_frame
    game.free()
    game = null
    await process_frame
    print("WEAPON ACTION CYCLES: ",checks," checks, ",failures," failures")
    call_deferred("_finish_test", exit_code)

func _finish_test(exit_code: int) -> void:
    await create_timer(0.25).timeout
    quit(exit_code)
