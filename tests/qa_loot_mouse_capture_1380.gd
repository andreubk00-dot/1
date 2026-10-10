extends SceneTree

# Visual QA: real Godot 4.7.2 render of centered icon cards (not a mock).
const Harness = preload("res://tests/rest_harness.gd")
var output = ""

func _initialize():
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--qa-output="):
            output = a.trim_prefix("--qa-output=")
    call_deferred("run")

func _snap(name:String) -> int:
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image().save_png("%s/%s.png" % [output,name])

func run() -> void:
    if output == "":
        printerr("Expected --qa-output=<dir>")
        quit(2)
        return
    DirAccess.make_dir_recursive_absolute(output)
    var game = Harness.new()
    root.add_child(game)
    await process_frame
    game._create_hud()

    game._show_pickup_reveal("bandage",3)
    var a = await _snap("center_one_item")
    game._show_pickup_reveal("makarov",1)
    game._show_pickup_reveal("akm",1)
    var b = await _snap("center_three_items")
    print("LOOT QA SCREENSHOTS: ",output," errors=",a,", ",b)

    game.queue_free()
    await process_frame
    quit(0 if a == OK and b == OK else 3)
