extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var checks = 0
var failures = 0

func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func pack(game,free_stack):
    game.inventory_entries = []
    var cap = int(game.item_defs["bandage"]["stack"])
    for y in range(game.INV_H):
        for x in range(game.INV_W):
            game.inventory_entries.append({"id":"bandage","qty":cap,"x":x,"y":y})
    game.inventory_entries[0]["qty"] -= free_stack

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    pack(game,2)
    var before = game._inventory_count("bandage")
    game.dropped_items = [{"drop_id":10,"id":"bandage","qty":5,"x":0.0,"y":0.0}]
    game.next_drop_id = 11
    var drop = game._spawn_world_item(game,Vector2i.ZERO,"bandage",5,Vector2.ZERO,"",10)
    game._pickup_world_item(drop)
    check(game._inventory_count("bandage") == before + 2,"partial pickup moves only available capacity")
    check(int(drop.get_meta("qty")) == 3,"visible remainder updated")
    check(int(game.dropped_items[0]["qty"]) == 3,"persistent dropped remainder updated")
    check(game._inventory_count("bandage") + int(game.dropped_items[0]["qty"]) == before + 5,"quantity conserved across inventory and world")
    var no_space_records = game.dropped_items.duplicate(true)
    game._pickup_world_item(drop)
    check(game.dropped_items == no_space_records,"full inventory does not mutate world")
    drop.free()
    var chunk = Node2D.new()
    game.add_child(chunk)
    game._spawn_saved_drops_for_chunk(chunk,Vector2i.ZERO)
    check(chunk.get_child_count() == 1 and int(chunk.get_child(0).get_meta("qty")) == 3,"chunk reload respawns remainder only")
    chunk.free()
    game.dropped_items.clear()
    pack(game,2)
    var fixed = game._spawn_world_item(game,Vector2i.ZERO,"bandage",5,Vector2(-10,-10),"-1:-1:pickup:test",-1)
    game._pickup_world_item(fixed)
    check(bool(game.picked_world_items.get("-1:-1:pickup:test",false)),"partial fixed pickup retires original spawn")
    check(game.dropped_items.size() == 1,"fixed remainder gets one persistent record")
    if game.dropped_items.size() == 1:
        check(int(game.dropped_items[0]["qty"]) == 3,"fixed remainder stores actual quantity")
        check(game.dropped_items[0]["x"] == -10 and game.dropped_items[0]["y"] == -10,"remainder preserves world position")
        check(int(fixed.get_meta("drop_id")) == 11,"live node links to new persistent record")
    fixed.free()
    var restored = Harness.new()
    root.add_child(restored)
    var data = JSON.parse_string(JSON.stringify({"picked":game.picked_world_items,"drops":game.dropped_items}))
    restored.picked_world_items = data["picked"]
    restored.dropped_items = data["drops"]
    var other_chunk = Node2D.new()
    other_chunk.position = Vector2(-768,-768)
    restored.add_child(other_chunk)
    restored._spawn_fixed_item(other_chunk,Vector2i(-1,-1),Vector2(758,758),"test","bandage",5)
    restored._spawn_saved_drops_for_chunk(other_chunk,Vector2i(-1,-1))
    check(other_chunk.get_child_count() == 1,"saved negative-coordinate chunk has no duplicate fixed spawn")
    if other_chunk.get_child_count() > 0:
        var item = other_chunk.get_child(0)
        check(int(item.get_meta("qty")) == 3,"JSON reload preserves remainder")
        check(item.global_position == Vector2(-10,-10),"chunk origin is applied exactly once")
        restored.inventory_entries = []
        restored._pickup_world_item(item)
        var once = restored._inventory_count("bandage")
        restored._pickup_world_item(item)
        check(restored._inventory_count("bandage") == once,"queued item cannot be picked twice in one frame")
        check(restored.dropped_items.is_empty(),"full pickup removes persistent remainder")
    restored.free()
    game.free()
    print("WORLD PERSISTENCE: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
