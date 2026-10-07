extends SceneTree
# Production save boundary: audible world SFX is transient and must never become persistence.
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
    # Runtime audio fields exist and are transient.
    check(game.world_audio_players is Array,"world audio voice pool exists")
    check(typeof(game.world_audio_cursor) == TYPE_INT,"world audio cursor exists")
    check(game.world_audio_cache is Dictionary,"world audio cache exists")
    var src = FileAccess.get_file_as_string("res://main_script_mod.gd")
    var save_start = src.find("func _save_state")
    var load_start = src.find("func _load_state",save_start)
    var save_slice = src.substr(save_start,load_start-save_start) if save_start >= 0 and load_start > save_start else ""
    check(save_slice.find("world_audio_players") < 0,"voice pool leaked into save writer")
    check(save_slice.find("world_audio_cursor") < 0,"audio cursor leaked into save writer")
    check(save_slice.find("world_audio_cache") < 0,"audio cache leaked into save writer")
    check(src.find('"save_version":122') >= 0,"production save schema must remain 122")
    game.queue_free()
    await process_frame
    print("WORLD AUDIO SAVE BOUNDARY 1.29-dev1: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
