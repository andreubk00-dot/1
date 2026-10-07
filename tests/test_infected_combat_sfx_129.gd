extends SceneTree
# Godot 4.7.2: --headless --path . --script tests/test_infected_combat_sfx_129.gd
const Harness = preload("res://tests/rest_harness.gd")
const KINDS = ["infected_attack","infected_hurt","infected_death","infected_call","infected_spit","player_hit","spit_hit"]
var checks := 0
var failures := 0
func check(ok:bool, why:String)->void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL ",why)
func _initialize()->void:
    call_deferred("run")
func _last_voice(game,before:int):
    return game.world_audio_players[before % game.world_audio_players.size()]
func run()->void:
    var game = Harness.new()
    game.test_world_audio_enabled = true
    root.add_child(game)
    await process_frame
    game._create_world_audio_layer()
    for kind in KINDS:
        var path = str(game._world_sfx_path(kind))
        check(path.begins_with("res://audio/infected/"),kind+" wrong audio namespace")
        check(ResourceLoader.exists(path),kind+" WAV missing")
        var stream = game._cached_world_audio(kind)
        check(stream != null,kind+" failed to load")
        if stream != null:
            check(stream.get_length() >= 0.20 and stream.get_length() <= 0.90,kind+" implausible duration")

    game.player.global_position = Vector2.ZERO
    var before = game.world_audio_cursor
    check(bool(game._play_distance_sfx("infected_hurt",Vector2.ZERO,-10.0,100.0,0.0)),"near distance playback failed")
    var near_voice = _last_voice(game,before)
    check(abs(float(near_voice.volume_db) - (-10.0)) < 0.01,"near volume should be unattenuated")
    before = game.world_audio_cursor
    check(bool(game._play_distance_sfx("infected_hurt",Vector2(50,0),-10.0,100.0,0.0)),"mid distance playback failed")
    var mid_voice = _last_voice(game,before)
    check(abs(float(mid_voice.volume_db) - (-14.5)) < 0.05,"mid-distance attenuation mismatch")
    before = game.world_audio_cursor
    check(not bool(game._play_distance_sfx("infected_hurt",Vector2(101,0),-10.0,100.0,0.0)),"far source should be culled")
    check(game.world_audio_cursor == before,"culled source advanced voice cursor")

    # Real nonlethal damage path must mirror the hit with infected_hurt without changing mechanics.
    var enemy = Node2D.new()
    game.add_child(enemy)
    enemy.global_position = Vector2(16,0)
    enemy.set_meta("hp",40.0)
    enemy.set_meta("chunk_coord",Vector2i(77,77))
    enemy.set_meta("spawn_id",177)
    enemy.set_meta("special_role","")
    before = game.world_audio_cursor
    game._damage_enemy(enemy,1.0)
    check(is_equal_approx(float(enemy.get_meta("hp",0.0)),39.0),"audio wiring changed enemy damage")
    check(game.world_audio_cursor == (before + 1) % 6,"nonlethal damage did not play hurt SFX")
    check(str(_last_voice(game,before).stream.resource_path).ends_with("infected_hurt.wav"),"nonlethal damage selected wrong SFX")

    # Real player melee-hit path must retain health damage and add player feedback only.
    game.health = 100.0
    game.developer_invulnerable = false
    game.qa_visual_mode = false
    before = game.world_audio_cursor
    game._apply_enemy_hit(1.0)
    check(game.health < 100.0,"enemy hit no longer damages player")
    check(game.world_audio_cursor == (before + 1) % 6,"player hit did not play feedback")
    check(str(_last_voice(game,before).stream.resource_path).ends_with("player_hit.wav"),"player hit selected wrong SFX")

    # Completed Screamer call keeps the authored AI emission while adding audible presentation.
    var caller = Node2D.new()
    game.add_child(caller)
    caller.global_position = Vector2(48,0)
    caller.set_meta("call_cooldown",13.0)
    caller.set_meta("call_radius",440.0)
    caller.set_meta("call_timer",0.2)
    caller.set_meta("call_count",0)
    caller.set_meta("call_interrupted",false)
    before = game.world_audio_cursor
    game._infected_finish_call(caller)
    check(int(caller.get_meta("call_count",0)) == 1,"call SFX wiring changed call completion")
    check(float(caller.get_meta("call_cd",0.0)) >= 12.0,"call cooldown changed")
    check(game.world_audio_cursor == (before + 1) % 6,"completed call did not play SFX")
    check(str(_last_voice(game,before).stream.resource_path).ends_with("infected_call.wav"),"call selected wrong SFX")

    for voice in game.world_audio_players:
        if is_instance_valid(voice):
            voice.stop()
            voice.stream = null
    game.world_audio_cache.clear()
    enemy.queue_free(); caller.queue_free(); game.queue_free()
    await process_frame
    print("INFECTED COMBAT SFX 1.29-dev2: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
