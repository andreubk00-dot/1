extends SceneTree
# Atmosphere loops are derived from existing world state and must remain transient.
const Harness = preload("res://tests/rest_harness.gd")
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
    check(game.ambience_audio_players is Dictionary,"ambience player map exists")
    check(game.ambience_audio_cache is Dictionary,"ambience cache exists")
    var src = FileAccess.get_file_as_string("res://main_script_mod.gd")
    var save_start = src.find("func _save_state")
    var load_start = src.find("func _load_state",save_start)
    var save_slice = src.substr(save_start,load_start-save_start) if save_start >= 0 and load_start > save_start else ""
    check(save_slice.find("ambience_audio_players") < 0,"ambience voices leaked into save writer")
    check(save_slice.find("ambience_audio_cache") < 0,"ambience cache leaked into save writer")
    check(save_slice.find("ambience_selection") < 0,"derived ambience selection leaked into save writer")
    check(src.find('"save_version":122') >= 0,"production save schema must remain 122")
    game.queue_free()
    await process_frame
    print("AMBIENCE AUDIO SAVE BOUNDARY 1.29-dev3: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
