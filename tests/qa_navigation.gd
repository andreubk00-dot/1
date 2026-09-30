extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var output = ""
func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")
func capture(name):
    await RenderingServer.frame_post_draw
    var result = root.get_texture().get_image().save_png(output + "/" + name + ".png")
    print("NAV_CAPTURE ",name," result=",result)
func run():
    if output == "":
        printerr("Pass --qa-output with an existing screenshot directory")
        quit(1)
        return
    var game = Harness.new()
    root.add_child(game)
    game.player.position = Vector2(1000,1000)
    game._rect(Vector2.ZERO,Vector2(1200,800),Color("1a2421"),game)
    var camera = Camera2D.new()
    camera.position = Vector2(25,0)
    camera.zoom = Vector2(1.35,1.35)
    game.add_child(camera)
    for spec in [[Vector2(60,0),Vector2(10,160)],[Vector2(0,-80),Vector2(130,10)],[Vector2(0,80),Vector2(130,10)]]:
        game._add_static_rect(game,spec[0],spec[1])
        game._rect(spec[0],spec[1],Color("62665b"),game)
    game._rect(Vector2(140,0),Vector2(8,8),Color("bfad59"),game)
    var trace = Line2D.new()
    trace.width = 1.0
    trace.default_color = Color("80947f")
    trace.z_index = 1
    game.add_child(trace)
    var enemy = game._spawn_enemy(game,Vector2i.ZERO,900,Vector2.ZERO)
    var canvas = CanvasLayer.new()
    game.add_child(canvas)
    var label = Label.new()
    label.text = "1.06 • ПРОВЕРКА НАВИГАЦИИ\nП-образная стена • жёлтый квадрат — запомненная цель"
    label.position = Vector2(12,12)
    label.add_theme_font_size_override("font_size",12)
    canvas.add_child(label)
    await physics_frame
    await capture("navigation_start")
    for i in range(900):
        await physics_frame
        game._enemy_move_toward(enemy,Vector2(140,0),game.ENEMY_SPEED,[enemy])
        if i % 8 == 0:
            trace.add_point(enemy.position)
        if i == 300:
            await capture("navigation_detour")
    label.text += "\nРезультат: " + ("ЦЕЛЬ ДОСТИГНУТА" if enemy.position.distance_to(Vector2(140,0)) < 15 else "НЕ ДОСТИГНУТА")
    await capture("navigation_arrival")
    quit(0 if enemy.position.distance_to(Vector2(140,0)) < 15 else 1)
