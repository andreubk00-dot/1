extends SceneTree
# Godot 4.7.2: --headless --path . --script tests/test_world_interaction_sfx_129.gd
const Harness = preload("res://tests/rest_harness.gd")
const KINDS = [
    "door_open","door_close","footstep_walk","footstep_sprint",
    "item_drop","melee_swing","melee_hit","workbench"
]
var checks := 0
var failures := 0
func check(ok:bool, why:String)->void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL ",why)
func _initialize()->void:
    call_deferred("run")
func run()->void:
    var game = Harness.new()
    game.test_world_audio_enabled = true
    root.add_child(game)
    await process_frame
    game._create_world_audio_layer()
    check(game.world_audio_players.size() == 6,"world audio voice pool must contain 6 voices")
    var seen = {}
    for kind in KINDS:
        var path = str(game._world_sfx_path(kind))
        check(path.begins_with("res://audio/world/"),kind+" path namespace")
        check(ResourceLoader.exists(path),kind+" WAV missing: "+path)
        var stream = game._cached_world_audio(kind)
        check(stream != null,kind+" failed to load")
        if stream != null:
            check(stream.get_length() >= 0.16 and stream.get_length() <= 0.50,kind+" implausible duration")
        var before = game.world_audio_cursor
        check(bool(game._play_world_sfx(kind,-12.0,0.0)),kind+" playback rejected")
        check(game.world_audio_cursor == (before + 1) % 6,kind+" cursor did not advance")
        var voice_index = before % 6
        var voice = game.world_audio_players[voice_index]
        check(voice.stream == stream,kind+" voice stream mismatch")
        check(abs(float(voice.pitch_scale)-1.0) < 0.0001,kind+" zero-variation pitch must be exact")
        seen[kind] = true
    check(game.world_audio_cache.size() == KINDS.size(),"all world clips should be cached exactly once")
    check(not bool(game._play_world_sfx("unknown_world_sfx")),"unknown SFX must fail safely")
    check(game._world_sfx_path("unknown_world_sfx") == "","unknown SFX path must be empty")
    for voice in game.world_audio_players:
        if is_instance_valid(voice):
            voice.stop()
            voice.stream = null
    game.world_audio_cache.clear()
    game.queue_free()
    await process_frame
    await process_frame
    print("WORLD INTERACTION SFX 1.29-dev1: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
