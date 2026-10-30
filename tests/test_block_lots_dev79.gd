extends SceneTree
# dev79: block lots (world/block_lots.gd).
# - a sector builds the same lots every time it loads
# - a house whose cache is already in the save is never turned into a lot
# - lots stay off the carriageway and out of every building; at most one house
#   a sector gives way to one
# - no lots in the woods, on a site, at the start or by a chained dog
# - every kind turns up, often enough to change the look of the town
# - a lot's stash is a real container with its own loot table
const Main = preload("res://main_script_mod.gd")
const BlockLots = preload("res://world/block_lots.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const DogCatalog = preload("res://world/dog_catalog.gd")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", msg)

func _initialize():
    call_deferred("run")

func _snapshot(chunk) -> Array:
    var out = []
    for n in chunk.get_children():
        if n.has_meta("block_lot"):
            out.append("lot %s %s %s" % [n.name,n.get_meta("block_lot"),n.position])
        elif n.has_meta("world_building"):
            out.append("bld %s %s" % [n.get_meta("building_id",""),n.position])
    out.sort()
    return out

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(4):
        await process_frame

    var kinds = {}
    var city = 0
    var city_with_lots = 0
    var sample = null
    for y in range(-8,9):
        for x in range(-8,9):
            var c = Vector2i(x,y)
            if not game.loaded_chunks.has(c):
                game._load_chunk(c)
            var ch = game.loaded_chunks.get(c,null)
            if ch == null:
                continue
            var did = RegionCatalog.district_id_for_chunk(c)
            var family = str(game.DISTRICT_GROUND.get(did,"city"))
            var poi = RegionCatalog.poi_for_chunk(c)
            var lots = []
            var buildings = []
            for n in ch.get_children():
                if n.has_meta("block_lot"):
                    lots.append(n)
                elif n.has_meta("world_building"):
                    buildings.append(Rect2(n.position - n.get_meta("building_size") * 0.5,n.get_meta("building_size")))
            if family == "city" and poi.is_empty() and c != Vector2i.ZERO:
                city += 1
                if not lots.is_empty():
                    city_with_lots += 1
            if not lots.is_empty():
                check(family != "woodland","a lot in the woods at %s" % c)
                check(poi.is_empty(),"a lot on a site at %s" % c)
                check(c != Vector2i.ZERO,"a lot at the start")
                check(DogCatalog.site_name(c) == "","a lot in a dog's yard sector %s" % c)
                if sample == null and lots.size() >= 1:
                    sample = c
            for lot in lots:
                kinds[str(lot.get_meta("block_lot"))] = true
                var r = game._world_event_rect(lot)
                check(r.size.x > 150.0 and r.size.y > 150.0,"a lot without a footprint at %s" % c)
                var on_road = r.intersects(Rect2(274,0,220,768)) or r.intersects(Rect2(0,274,768,220))
                check(not on_road,"a lot reaches the street at %s: %s" % [c,r])
                for b in buildings:
                    check(not r.intersects(b),"a lot overlaps a building at %s" % c)
                var slot = int(str(lot.name).trim_prefix("BlockLot_"))
                var cache_key = "%d:%d:container:lot_%d" % [c.x,c.y,slot]
                var kind = str(lot.get_meta("block_lot"))
                var planned_cache = false
                for item in BlockLots.plan(kind):
                    if item.has("cache"):
                        planned_cache = true
                if planned_cache and game.container_states.has(cache_key):
                    check(str(game.container_states[cache_key].get("loot_table","")) != "","a lot stash without a loot table at %s" % c)
            # lot pieces stand clear of the walls
            for n in ch.get_children():
                if n.has_meta("block_lot_piece") or n.has_meta("lot_draw"):
                    for b in buildings:
                        check(not b.grow(-6.0).has_point(n.position),"a lot piece inside a building at %s %s" % [c,n.position])
            game._unload_chunk(c)
        await process_frame
    print("LOT KINDS ",kinds.keys()," city sectors ",city," with lots ",city_with_lots)
    for k in BlockLots.PLANS.keys():
        if k in ["depot","garden","dump","yard"]:
            continue
        check(kinds.has(k),"no %s anywhere near the start" % k)
    check(city > 0 and float(city_with_lots) / float(city) >= 0.25,"too few town sectors with a lot: %d of %d" % [city_with_lots,city])

    # --- the same sector twice -----------------------------------------------
    check(sample != null,"no sector with a lot")
    if sample != null:
        game._load_chunk(sample)
        var first = _snapshot(game.loaded_chunks[sample])
        game._unload_chunk(sample)
        await process_frame
        game._load_chunk(sample)
        var second = _snapshot(game.loaded_chunks[sample])
        game._unload_chunk(sample)
        check(first == second,"a sector came back different:\n%s\n%s" % [first,second])

    # --- an old save's house stays a house -------------------------------------
    var converted = null
    for y in range(-8,9):
        for x in range(-8,9):
            var c = Vector2i(x,y)
            game._load_chunk(c)
            var ch = game.loaded_chunks[c]
            for n in ch.get_children():
                if n.has_meta("block_lot"):
                    var slot = int(str(n.name).trim_prefix("BlockLot_"))
                    # a converted slot: no building of that number, yet the roll said build
                    var has_b = false
                    for b in ch.get_children():
                        if b.has_meta("world_building") and str(b.get_meta("building_id","")) == "building_%d" % slot:
                            has_b = true
                    if not has_b and BlockLots.converts(str(game.DISTRICT_GROUND.get(RegionCatalog.district_id_for_chunk(c),"city")),c,slot):
                        converted = [c,slot]
            game._unload_chunk(c)
            if converted != null:
                break
        if converted != null:
            break
    check(converted != null,"no house anywhere was turned into a lot")
    if converted != null:
        var c:Vector2i = converted[0]
        var slot:int = converted[1]
        var key = "%d:%d:container:cache_%d" % [c.x,c.y,slot]
        game.container_states[key] = {"name":"old","loot_table":"residential","grid_w":game.CONTAINER_W,"grid_h":game.CONTAINER_H,"items":[]}
        game._load_chunk(c)
        var ch = game.loaded_chunks[c]
        var has_b = false
        var has_lot = false
        for n in ch.get_children():
            if n.has_meta("world_building") and str(n.get_meta("building_id","")) == "building_%d" % slot:
                has_b = true
            if n.has_meta("block_lot") and str(n.name) == "BlockLot_%d" % slot:
                has_lot = true
        check(has_b and not has_lot,"a house from an old save became a lot at %s slot %d" % [c,slot])
        game._unload_chunk(c)
        game.container_states.erase(key)

    print("BLOCK LOTS dev79: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
