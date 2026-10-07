extends SceneTree
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
    var game = Harness.new(); root.add_child(game); await process_frame
    var src = FileAccess.get_file_as_string("res://main_script_mod.gd")
    var a = src.find("func _save_state")
    var b = src.find("func _load_state",a)
    var save_slice = src.substr(a,b-a) if a >= 0 and b > a else ""
    check(save_slice.find("world_audio_players") < 0,"world voice pool leaked into save")
    check(save_slice.find("world_audio_cache") < 0,"world audio cache leaked into save")
    check(save_slice.find("ambience_audio_players") < 0,"ambience voices leaked into save")
    check(save_slice.find("ambience_audio_cache") < 0,"ambience cache leaked into save")
    check(save_slice.find("ui_") < 0,"UI cue state leaked into save")
    check(src.find('"save_version":122') >= 0,"schema must remain 122")
    game.queue_free(); await process_frame
    print("AUDIO CLOSURE SAVE BOUNDARY 1.29-dev4: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
