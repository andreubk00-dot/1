extends SceneTree

const CHUNK := 768.0
const OUT := "/mnt/data/ostatok_1230_dev1_hr_visual/screenshots"

func _initialize() -> void:
    call_deferred("_run")

func _settle(frames:int = 12) -> void:
    for _i in range(frames):
        await process_frame
        await RenderingServer.frame_post_draw

func _shot(name:String) -> void:
    await RenderingServer.frame_post_draw
    var img = root.get_texture().get_image()
    img.save_png(OUT + "/" + name)

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(OUT)
    change_scene_to_file("res://main.tscn")
    await _settle(36)
    var main = current_scene
    if main == null:
        push_error("capture: main scene missing")
        quit(2)
        return
    # dev branch deliberately keeps the teleport helper available for capture.
    if not main._developer_teleport_to_poi("regional_clinical_complex_4"):
        push_error("capture: teleport failed")
        quit(3)
        return
    await _settle(36)
    main._developer_set_invulnerable(true)
    main._developer_set_no_aggro(true)
    main._qa_force_daylight()
    if is_instance_valid(main.developer_hud_button):
        main.developer_hud_button.visible = false
    for enemy in get_nodes_in_group("enemies"):
        if is_instance_valid(enemy):
            main._developer_force_enemy_passive(enemy)

    var base = Vector2(-9.0 * CHUNK,1.0 * CHUNK)
    main.camera.position_smoothing_enabled = false
    main.camera.zoom = Vector2(1.42,1.42)

    # Exterior: player stands south of the reception, camera looks slightly north.
    main.player.global_position = base + Vector2(350,520)
    main._refresh_chunks(true)
    main.camera.position = Vector2(0,-172)
    await _settle(28)
    await _shot("hr_medical_v03_ingame_exterior.png")

    # Interior: stand in reception so roof/facade fade using the real gameplay rule.
    main.player.global_position = base + Vector2(220,300)
    main._refresh_chunks(true)
    main.camera.position = Vector2(130,0)
    await _settle(50)
    await _shot("hr_medical_v03_ingame_interior.png")

    # One wider in-engine composition check (same scene, temporarily wider camera only).
    main.player.global_position = base + Vector2(350,600)
    main._refresh_chunks(true)
    main.camera.zoom = Vector2(0.78,0.78)
    main.camera.position = Vector2(0,-288)
    await _settle(36)
    await _shot("hr_medical_v03_ingame_overview.png")
    quit()
