extends SceneTree
const Main = preload("res://main_script_mod.gd")

var checks := 0
var failures := 0
const QA_KEY = "0:0:container:garage_all_items_0163"

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")

func _clear_save() -> void:
    for suffix in ["",".bak",".tmp"]:
        var path = Main.SAVE_PATH + suffix
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)

func _dispose(game) -> void:
    if is_instance_valid(game):
        game._qa_clear_infected()
        await physics_frame
        game.free()
        await process_frame

func run() -> void:
    var original_version = str(ProjectSettings.get_setting("application/config/version",""))
    _clear_save()

    # Stable/RC surface first, before any dev-only InputMap action can be created in this process.
    ProjectSettings.set_setting("application/config/version","1.33.0")
    var stable = Main.new()
    root.add_child(stable)
    stable.set_process(false)
    await process_frame
    await process_frame
    check(not stable._developer_tools_available(),"stable version unexpectedly enables developer tools")
    check(not stable.container_states.has(QA_KEY),"stable world exposed TEST: ALL ITEMS container")
    var stable_chunk = stable.loaded_chunks.get(Vector2i.ZERO,null)
    if stable_chunk != null:
        var leaked_label = false
        for child in stable_chunk.get_children():
            if child is Label and str(child.text).find("ТЕСТ-ЯЩИК: ВСЕ ПРЕДМЕТЫ") >= 0:
                leaked_label = true
                break
        check(not leaked_label,"stable world exposed TEST: ALL ITEMS label")
    await _dispose(stable)
    _clear_save()

    ProjectSettings.set_setting("application/config/version","1.33.0-dev1")
    var dev = Main.new()
    root.add_child(dev)
    dev.set_process(false)
    await process_frame
    await process_frame
    check(dev._developer_tools_available(),"dev version lost developer tools")
    check(dev.container_states.has(QA_KEY),"dev build lost TEST: ALL ITEMS QA container")
    var state = dev.container_states.get(QA_KEY,{})
    check(str(state.get("loot_table","")) == "all_items_test","dev QA container changed loot table")
    check(dev._container_grid_size(state) == Vector2i(dev.QA_ALL_ITEMS_CONTAINER_W,dev.QA_ALL_ITEMS_CONTAINER_H),"dev QA container changed capacity")
    await _dispose(dev)
    _clear_save()

    ProjectSettings.set_setting("application/config/version",original_version)
    print("FEATURE LOCK RELEASE SURFACE 1.33: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
