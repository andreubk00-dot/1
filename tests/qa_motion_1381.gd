extends SceneTree
const Main = preload("res://main_script_mod.gd")
func _initialize(): call_deferred("run")
func run():
    var out = OS.get_environment("OSTATOK_MOTION_CAPTURE")
    if out == "": quit(2); return
    DirAccess.make_dir_recursive_absolute(out)
    var g = Main.new()
    root.add_child(g)
    g.set_process(false)
    g.qa_visual_mode = true
    g.qa_locked_aim = Vector2.DOWN
    g.developer_invulnerable = true
    g._qa_prepare_visual_state()
    g._qa_force_daylight()
    g._qa_clear_infected()
    g.player.global_position = Vector2(384,440)
    g._refresh_chunks(true)
    for actor in get_nodes_in_group("marauders"): actor.queue_free()
    await process_frame
    g.qa_forced_move_direction = Vector2.DOWN
    g.qa_force_sprint = false
    g.set_process(true)
    var metrics = []
    for frame in range(150):
        if frame == 45: g.qa_force_sprint = true
        if frame == 120:
            g.qa_forced_move_direction = Vector2.ZERO
            g.qa_force_sprint = false
        await process_frame
        await RenderingServer.frame_post_draw
        get_root().get_texture().get_image().save_png(out+"/frame_%03d.png"%frame)
        metrics.append({"frame":frame,"x":g.player.global_position.x,"y":g.player.global_position.y,"phase":g.walk_phase,"speed":g.visual_move_speed,"sprinting":g.is_sprinting})
    var file = FileAccess.open(out+"/metrics.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(metrics,"  "))
    file.close()
    g.free()
    await process_frame
    quit(0)
