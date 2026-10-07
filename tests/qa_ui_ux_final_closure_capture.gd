extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var output := ""
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")
func run() -> void:
    if output == "":
        printerr("Pass --qa-output=<dir>")
        quit(1)
        return
    for action in ["developer_panel","region_map","reload","quick_slot_1","quick_slot_2","quick_slot_3","quick_slot_4","quick_slot_5","quick_slot_6","rig_quick_1","rig_quick_2"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    DirAccess.make_dir_recursive_absolute(output)
    var game = Harness.new()
    root.add_child(game)
    await process_frame
    game._create_hover_inspector()
    Input.warp_mouse(Vector2(632,352))
    await process_frame
    game._hover_show_item("police_vest",1,"equipment","")
    await process_frame
    game._update_hover_position()
    await process_frame
    var rect = Rect2(game.hover_panel.position,game.hover_panel.size)
    var viewport_rect = Rect2(Vector2.ZERO,game.get_viewport_rect().size)
    var safe = viewport_rect.encloses(rect)
    await RenderingServer.frame_post_draw
    var path = output + "/tooltip_bottom_right.png"
    var err = root.get_texture().get_image().save_png(path)
    print("UI/UX CLOSURE CAPTURE: ",path," safe=",safe," rect=",rect," err=",err)
    game.queue_free()
    await process_frame
    quit(0 if err == OK and safe else 2)
