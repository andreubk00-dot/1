extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var checks = 0
var failures = 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
func _initialize(): call_deferred("run")
func run():
    var g = Harness.new()
    root.add_child(g)
    g.add_source("campfire",100.0,Vector2(60,0))
    g.inventory_entries = [{"id":"grain","qty":1,"x":0,"y":0},{"id":"water","qty":1,"x":2,"y":0}]
    var wall = StaticBody2D.new()
    wall.collision_layer = g.LAYER_WORLD
    wall.position = Vector2(30,0)
    var shape_node = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(10,120)
    shape_node.shape = shape
    wall.add_child(shape_node)
    g.add_child(wall)
    await physics_frame
    check(not g._player_near_active_fire(),"closed wall must block cooking access")
    var inventory_before = g.inventory_entries.duplicate(true)
    check(not g._cook_inventory_product("grain",true,"hot_meal","QA"),"cannot cook through a wall")
    check(g.inventory_entries == inventory_before,"blocked cooking preserves ingredients")
    wall.queue_free()
    await physics_frame
    check(g._player_near_active_fire(),"open approach permits cooking")
    g.inventory_entries = inventory_before
    check(g._cook_inventory_product("grain",true,"hot_meal","QA"),"reachable fire cooks meal")
    check(g._inventory_count("hot_meal") == 1 and g._inventory_count("water") == 0 and g._inventory_count("grain") == 0,"cooking consumes ingredients once")
    g.base_objects[1].fuel = 0.0
    check(not g._player_near_active_fire(),"extinguished fire cannot cook")
    g.free()
    print("FIRE ACCESS: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
