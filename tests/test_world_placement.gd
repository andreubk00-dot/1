extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var checks = 0
var failures = 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
func _initialize():
    call_deferred("run")
func run():
    var game = Harness.new()
    root.add_child(game)
    game.inventory_entries = []
    for id in ["scrap","cloth","tape"]:
        game._grid_add(game.inventory_entries,id,10,game.INV_W,game.INV_H)
    game.base_objects = []
    game.aim_direction = Vector2.RIGHT
    game.player.position = Vector2(30,0)
    check(not game._base_build_allowed("heater"),"indoor heater must not be built outside from under roof")
    var before = game.inventory_entries.duplicate(true)
    game.base_build_open = true
    game._build_base_object("heater")
    check(game.inventory_entries == before and game.base_objects.is_empty(),"rejected placement consumes no materials")
    game.player.position = Vector2(65,0)
    game.aim_direction = Vector2.LEFT
    check(not game._base_build_allowed("rain_collector"),"outdoor player cannot place collector under roof")
    game.aim_direction = Vector2.RIGHT
    check(game._base_build_allowed("rain_collector"),"collector still builds outdoors")
    game.player.position = Vector2.ZERO
    check(game._base_build_allowed("heater"),"heater still builds within shelter")
    game.roof_records = [{"rect":Rect2(-150,-150,300,300)}]
    # Center ray passes below this wall, but the actual horizontal barricade
    # footprint intersects it. A point-only placement check would accept it.
    var wall = game._add_static_rect(game,Vector2(46,8),Vector2(35,4))
    await physics_frame
    await physics_frame
    check(not game._base_build_allowed("barricade"),"full barricade collider must not overlap wall")
    before = game.inventory_entries.duplicate(true)
    check(not game._build_base_object("barricade"),"actual build action must reject intersecting footprint")
    check(game.inventory_entries == before and game.base_objects.is_empty(),"blocked barrier does not consume materials or create record")
    wall.free()
    await physics_frame
    check(game._base_build_allowed("barricade"),"clear barricade position remains valid")
    game.aim_direction = Vector2.DOWN
    wall = game._add_static_rect(game,Vector2(8,46),Vector2(4,35))
    await physics_frame
    await physics_frame
    check(not game._base_build_allowed("barricade"),"rotated barricade footprint must be checked")
    wall.free()
    await physics_frame
    var scrap_before = game._inventory_count("scrap")
    check(game._build_base_object("barricade"),"valid placement commits through production action")
    check(game.base_objects.size() == 1 and game._inventory_count("scrap") == scrap_before - 3,"successful build creates one record and charges exact cost")
    game.free()
    print("WORLD PLACEMENT: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
