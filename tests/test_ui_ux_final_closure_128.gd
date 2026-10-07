extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame
    check(game.get_viewport_rect().size == Vector2(640,360),"UI closure must validate the 640x360 base viewport")

    game._create_hover_inspector()
    var max_h := 0.0
    var max_lines := 0
    for raw_id in game.item_defs.keys():
        var id = str(raw_id)
        game._hover_show_item(id,1,"storage","")
        await process_frame
        var panel_h = float(game.hover_panel.size.y)
        max_h = max(max_h,panel_h)
        max_lines = max(max_lines,game.hover_body.text.count("\n") + 1)
        check(panel_h <= 348.0,"tooltip taller than safe viewport area: " + id)
        var font = game.hover_title.get_theme_font("font")
        var fs = game.hover_title.get_theme_font_size("font_size")
        var title_w = float(game.hover_title.text.length()) * float(fs) * 0.56
        if font != null:
            title_w = font.get_string_size(game.hover_title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
        check(title_w <= game.hover_title.size.x + 0.1,"tooltip title exceeds title area: " + id)
    check(game.item_defs.size() == 66,"item tooltip audit catalogue changed unexpectedly")
    check(max_h <= 232.0,"tooltip closure height regressed beyond audited maximum")
    check(max_lines <= 10,"tooltip closure line count regressed beyond audited maximum")

    game._create_inventory_ui()
    check(game.inventory_panel.position.y + game.inventory_panel.size.y * game.inventory_panel.scale.y <= 360.0,"inventory panel exceeds viewport")
    check(game.equipment_panel.position.y + game.equipment_panel.size.y * game.equipment_panel.scale.y <= 360.0,"equipment panel exceeds viewport")
    game._apply_container_panel_layout(Vector2i(8,8))
    check(game.container_panel.position.y + game.container_panel.size.y * game.container_panel.scale.y <= 360.0,"default container panel exceeds viewport")

    game.queue_free()
    await process_frame
    print("UI/UX FINAL CLOSURE 1.28: ",checks," checks, ",failures," failures; max tooltip h=",max_h," lines=",max_lines)
    quit(1 if failures else 0)
