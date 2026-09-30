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

    # This is the one suite that intentionally exercises real AudioStreamPlayer playback.
    game.test_audio_enabled = true
    game._create_weapon_audio_layer()
    check(game.weapon_audio_players.size() == 6,"automatic-fire audio pool must have six voices")
    check(game.reload_audio_player != null,"reload audio player missing")

    var seen_shot_paths = {}
    for weapon_id in game.FIREARM_IDS:
        var cfg = game.weapon_defs.get(weapon_id,{})
        var shot_path = game._weapon_shot_audio_path(weapon_id)
        var reload_path = game._weapon_reload_audio_path(weapon_id)
        check(ResourceLoader.exists(shot_path),"shot asset missing: " + weapon_id)
        check(ResourceLoader.exists(reload_path),"reload asset missing: " + weapon_id)
        check(game._cached_weapon_audio(shot_path) != null,"shot asset cannot load: " + weapon_id)
        check(game._cached_weapon_audio(reload_path) != null,"reload asset cannot load: " + weapon_id)
        check(str(cfg.get("sound_profile","")) != "","AI sound profile missing: " + weapon_id)
        check(str(cfg.get("reload_audio","")) in ["pistol","rifle","smg","shell","bolt"],"invalid reload profile: " + weapon_id)
        check(not seen_shot_paths.has(shot_path),"firearms must not share one audible gunshot file: " + weapon_id)
        seen_shot_paths[shot_path] = true

        var before_cursor = game.weapon_audio_cursor
        game._play_weapon_shot_audio(weapon_id,cfg)
        check(game.weapon_audio_cursor != before_cursor or game.weapon_audio_players.size() == 1,"shot did not advance voice pool: " + weapon_id)
        var used_index = (game.weapon_audio_cursor - 1 + game.weapon_audio_players.size()) % game.weapon_audio_players.size()
        check(game.weapon_audio_players[used_index].stream != null,"shot voice has no stream: " + weapon_id)

        game._play_weapon_reload_audio(weapon_id)
        check(game.reload_audio_player.stream != null,"reload voice has no stream: " + weapon_id)

    check(game._weapon_reload_audio_path("makarov").ends_with("pistol_reload.wav"),"PM must use pistol reload mechanics")
    check(game._weapon_reload_audio_path("pps43").ends_with("smg_reload.wav"),"PPS-43 must use SMG reload mechanics")
    check(game._weapon_reload_audio_path("izh81").ends_with("shell_reload.wav"),"IZH-81 must use shell reload mechanics")
    check(game._weapon_reload_audio_path("mosin").ends_with("bolt_reload.wav"),"Mosin must use bolt reload mechanics")
    check(ResourceLoader.exists("res://audio/weapons/dry_fire.wav"),"dry-fire click asset missing")
    check(ResourceLoader.exists("res://audio/weapons/makarov_suppressed_shot.wav"),"suppressed PM shot asset missing")

    # Existing suppressor must affect audible output as well as AI noise radius.
    game.inventory_entries = [{"id":"makarov","qty":1,"x":0,"y":0}]
    var suppressor_iid = game.set_test_weapon_state("makarov",1,100.0)
    var normal_pm_path = game._weapon_shot_audio_path("makarov",suppressor_iid)
    game._set_weapon_mod_slot("makarov","muzzle","suppressor",suppressor_iid)
    var suppressed_pm_path = game._weapon_shot_audio_path("makarov",suppressor_iid)
    check(normal_pm_path != suppressed_pm_path,"suppressor must select a different audible shot")
    check(suppressed_pm_path.ends_with("makarov_suppressed_shot.wav"),"wrong suppressed PM asset")

    # Empty trigger should click locally, consume no ammunition and emit no gunshot noise event.
    game.inventory_entries = [{"id":"makarov","qty":1,"x":0,"y":0}]
    game.current_weapon_id = "makarov"
    var empty_iid = game.set_test_weapon_state("makarov",0,100.0)
    game._switch_weapon("makarov",empty_iid)
    game.inventory_open = false
    game.reload_time = 0.0
    game.equipped_melee_id = ""
    game.fire_cooldown = 0.0
    game.last_player_noise_kind = "quiet"
    game._fire_weapon()
    check(game._weapon_mag_value("makarov",empty_iid) == 0,"dry fire consumed ammunition")
    check(game.fire_cooldown > 0.0,"dry fire needs anti-spam cooldown")
    check(game.last_player_noise_kind != "gunshot","dry fire must not emit AI gunshot hearing event")

    # AudioStreamPlayer playback objects are retired by AudioServer after their
    # nodes leave the tree. Do not terminate the headless process in the same
    # stack/frame, otherwise Godot reports resource-at-exit diagnostics.
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
    print("WEAPON AUDIO: ",checks," checks, ",failures," failures")
    call_deferred("_finish_test", exit_code)

func _finish_test(exit_code: int) -> void:
    await create_timer(0.25).timeout
    quit(exit_code)
