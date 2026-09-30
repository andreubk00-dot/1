extends SceneTree
const Main = preload("res://main_script_mod.gd")
const Store = preload("res://world/save_store.gd")
var checks = 0
var failures = 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
func _initialize():
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use isolated XDG_DATA_HOME and OSTАTOK_QA_SAVE_ROOT")
        quit(2)
        return
    call_deferred("run")
func run():
    var path = "user://qa_atomic_save.json"
    var first = {"inventory_entries":[],"world_day":6}
    var second = {"inventory_entries":[],"world_day":7}
    check(Store.write_save(path,first),"first save writes")
    check(Store.write_save(path,second),"second save replaces primary")
    check(int(Store.read_save(path).world_day) == 7,"read latest save")
    check(int(Store.read_save(path + ".bak").world_day) == 6,"backup keeps previous generation")
    var file = FileAccess.open(path,FileAccess.WRITE)
    file.store_string('{"inventory_entries":[')
    file.close()
    check(int(Store.read_save(path).world_day) == 6,"truncated primary recovers backup")
    check(Store.write_save(path,second),"recovered game can save again")
    check(int(Store.read_save(path + ".bak").world_day) == 6,"corrupt primary must not overwrite backup")
    file = FileAccess.open(path,FileAccess.WRITE)
    file.store_string(JSON.stringify({"inventory_entries":[null],"world_day":99}))
    file.close()
    check(int(Store.read_save(path).world_day) == 6,"invalid entry types recover backup before runtime access")
    DirAccess.remove_absolute(path)
    check(int(Store.read_save(path).world_day) == 6,"missing primary recovers backup")
    check(Store.write_save(path,second),"save after missing primary")
    # Simulate failure opening the temporary file, without changing permissions.
    DirAccess.make_dir_absolute(path + ".tmp")
    check(not Store.write_save(path,first),"failed temporary write is reported")
    check(int(Store.read_save(path).world_day) == 7,"failed write preserves primary")
    DirAccess.remove_absolute(path + ".tmp")
    # Full startup must distinguish an empty saved pack from a new game.
    var live = Main.SAVE_PATH
    check(Store.write_save(live,{"save_version":98,"inventory_entries":[],"equipment":{},"world_day":9}),"empty pack save writes")
    var game = Main.new()
    root.add_child(game)
    game.set_process(false)
    check(game.has_meta("loaded_save"),"startup recognizes saved game")
    check(game.inventory_entries.is_empty(),"loading empty pack must not grant another starter kit")
    check(game.world_day == 9,"empty pack load preserves world")
    game._qa_clear_infected()
    game._save_state()
    await physics_frame
    game.free()
    # Missing main file is recovered on the production startup path too.
    DirAccess.remove_absolute(live)
    game = Main.new()
    root.add_child(game)
    game.set_process(false)
    check(game.has_meta("loaded_save") and game.world_day == 9,"startup loads .bak if primary is missing")
    check(game.inventory_entries.is_empty(),"backup recovery grants no starter kit")
    await physics_frame
    game.free()
    print("SAVE RECOVERY: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
