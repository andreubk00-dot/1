extends SceneTree
# Godot 4.7.2: --headless --path . --script tests/test_ambience_audio_129.gd
const Harness = preload("res://tests/rest_harness.gd")
const KINDS = ["day","night","interior","rain"]
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
    root.add_child(game)
    await process_frame
    game._create_ambience_audio_layer()
    await process_frame
    check(game.ambience_audio_players.size() == 4,"ambience layer must contain four loop voices")
    for kind in KINDS:
        var path = str(game._ambience_audio_path(kind))
        check(path.begins_with("res://audio/ambience/"),kind+" path namespace")
        check(ResourceLoader.exists(path),kind+" WAV missing: "+path)
        var stream = game._cached_ambience_audio(kind)
        check(stream != null,kind+" failed to load")
        check(stream is AudioStreamWAV,kind+" must import as AudioStreamWAV")
        if stream is AudioStreamWAV:
            check(stream.get_length() >= 3.95 and stream.get_length() <= 4.05,kind+" loop must stay near four seconds")
            check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,kind+" loop mode must be forward")
            var expected_end = int(round(stream.get_length()*float(stream.mix_rate)))
            check(abs(int(stream.loop_end)-expected_end) <= 2,kind+" loop_end mismatch")
        else:
            check(false,kind+" duration unavailable")
            check(false,kind+" loop mode unavailable")
            check(false,kind+" loop end unavailable")
        var voice = game.ambience_audio_players.get(kind,null)
        check(voice != null and voice.stream == stream,kind+" voice stream mismatch")

    game.world_minutes = 12.0*60.0
    game.weather_state = "clear"
    game.is_sheltered = false
    var state = game._ambience_selection()
    check(str(state.get("base","")) == "day","midday outdoors must select day bed")
    check(not bool(state.get("rain",true)),"clear midday must not select rain")

    game.world_minutes = 23.0*60.0
    state = game._ambience_selection()
    check(str(state.get("base","")) == "night","late night must select night bed")

    game.is_sheltered = true
    state = game._ambience_selection()
    check(str(state.get("base","")) == "interior","shelter must select roomtone")

    game.is_sheltered = false
    game.weather_state = "rain"
    state = game._ambience_selection()
    check(bool(state.get("rain",false)),"outdoor rain must enable rain layer")

    game.is_sheltered = true
    state = game._ambience_selection()
    check(str(state.get("base","")) == "interior","rain shelter must keep roomtone")
    check(not bool(state.get("rain",true)),"rain layer must mute while sheltered")
    check(game._ambience_audio_path("unknown") == "","unknown ambience key must fail safely")

    for voice in game.ambience_audio_players.values():
        if is_instance_valid(voice):
            voice.stop()
            voice.stream = null
    game.ambience_audio_cache.clear()
    game.queue_free()
    await process_frame
    await process_frame
    print("AMBIENCE AUDIO 1.29-dev3: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
