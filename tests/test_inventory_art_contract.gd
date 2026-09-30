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

    check(game.inventory_icon_regions.size() == 59,"exact inventory icon catalogue must contain 59 non-melee items")
    check(game.melee_icon_regions.size() == 3,"melee icon catalogue must contain 3 items")

    for item_id in game.item_defs.keys():
        var sid = str(item_id)
        check(game.inventory_icon_regions.has(sid) or game.melee_icon_regions.has(sid),"missing exact inventory art: " + sid)

    for item_id in game.inventory_icon_regions.keys():
        var sid = str(item_id)
        if not game.item_defs.has(sid):
            continue
        var region = game.inventory_icon_regions[sid]
        var item = game.item_defs[sid]
        var max_w = int(item.get("w",1)) * game.CELL - 6
        var max_h = int(item.get("h",1)) * game.CELL - 6
        check(region.size.x <= max_w,"inventory art too wide for item grid: %s (%d > %d)" % [sid,region.size.x,max_w])
        check(region.size.y <= max_h,"inventory art too tall for item grid: %s (%d > %d)" % [sid,region.size.y,max_h])

    check(game.inventory_icon_regions["aks74u"].size.x == 74,"AKS-74U exact icon width must remain compact")
    check(game.inventory_icon_regions["mosin"].size.x == 104,"Mosin exact icon width must fit 4-cell inventory footprint")
    check(game.inventory_icon_regions["bedroll"].size.x == 66,"bedroll exact icon width must fit 3-cell inventory footprint")

    game.free()
    print("INVENTORY ART CONTRACT: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
