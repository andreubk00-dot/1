extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const KINDS = ["open","close","confirm"]
var checks := 0
var failures := 0
func check(ok:bool, why:String)->void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL ",why)
func slice_func(src:String,name:String)->String:
    var start = src.find("func "+name+"(")
    if start < 0:
        return ""
    var next = src.find("\nfunc ",start+6)
    return src.substr(start,(src.length()-start) if next < 0 else (next-start))
func _initialize()->void:
    call_deferred("run")
func run()->void:
    var game = Harness.new()
    game.test_world_audio_enabled = true
    root.add_child(game)
    await process_frame
    game._create_world_audio_layer()
    check(game.world_audio_players.size() == 6,"UI feedback reuses six-voice world audio pool")
    for kind in KINDS:
        var sfx = "ui_"+kind
        var path = str(game._world_sfx_path(sfx))
        check(path.begins_with("res://audio/ui/"),kind+" UI namespace")
        check(ResourceLoader.exists(path),kind+" UI WAV missing")
        var stream = game._cached_world_audio(sfx)
        check(stream != null,kind+" UI WAV failed to load")
        if stream != null:
            check(stream.get_length() >= 0.10 and stream.get_length() <= 0.20,kind+" UI duration outside compact range")
        else:
            check(false,kind+" UI duration unavailable")
        var before = game.world_audio_cursor
        check(bool(game._play_ui_sfx(kind)),kind+" UI playback rejected")
        check(game.world_audio_cursor == (before+1)%6,kind+" UI cursor did not advance")
    check(not bool(game._play_ui_sfx("unknown")),"unknown UI cue must fail safely")
    check(game._world_sfx_path("ui_unknown") == "","unknown UI path must be empty")

    var src = FileAccess.get_file_as_string("res://main_script_mod.gd")
    var integrations = {
        "_open_crafting":"_play_ui_sfx(\"open\")",
        "_close_crafting":"_play_ui_sfx(\"close\")",
        "_open_region_map":"_play_ui_sfx(\"open\")",
        "_close_region_map":"_play_ui_sfx(\"close\")",
        "_toggle_inventory":"_play_ui_sfx(\"open\")",
        "_close_inventory":"_play_ui_sfx(\"close\")",
        "_open_trader":"_play_ui_sfx(\"open\")",
        "_close_trader":"_play_ui_sfx(\"close\")",
        "_open_contract_board":"_play_ui_sfx(\"open\")",
        "_close_contract_board":"_play_ui_sfx(\"close\")",
        "_craft_selected_recipe":"_play_ui_sfx(\"confirm\")",
        "_trade_buy_selected":"_play_ui_sfx(\"confirm\")",
        "_contract_accept_selected":"_play_ui_sfx(\"confirm\")",
        "_contract_complete_selected":"_play_ui_sfx(\"confirm\")"
    }
    for fname in integrations.keys():
        check(slice_func(src,fname).find(str(integrations[fname])) >= 0,fname+" missing authored UI cue")

    for voice in game.world_audio_players:
        if is_instance_valid(voice):
            voice.stop(); voice.stream = null
    game.world_audio_cache.clear()
    game.queue_free()
    await process_frame
    await process_frame
    print("UI AUDIO FEEDBACK 1.29-dev4: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
