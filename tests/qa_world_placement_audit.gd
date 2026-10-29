extends SceneTree
# World placement audit: loads a square of sectors and reports outdoor pieces
# standing where they cannot be - a street lamp, a tree, a car, a fence or a
# yard piece inside a building's walls, a car on a roof. Prints one line per
# finding plus a per-kind summary.
# godot --headless --script tests/qa_world_placement_audit.gd -- [--qa-radius=8]
const Main = preload("res://main_script_mod.gd")

var radius = 8

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-radius="):
            radius = int(arg.trim_prefix("--qa-radius="))
    call_deferred("run")

func _kind(n) -> String:
    if n.has_meta("world_lamp"):
        return "lamp"
    if n.has_meta("world_tree"):
        return "tree"
    if n.has_meta("world_car"):
        return "car"
    if n.has_meta("world_fence"):
        return "fence"
    if n.has_meta("world_name_sign"):
        return "sign"
    if n.has_meta("settlement_piece_kind"):
        return "piece:" + str(n.get_meta("settlement_piece_kind"))
    return ""

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(4):
        await process_frame
    var counts = {}
    var total = 0
    var signs = 0
    for y in range(-radius,radius + 1):
        for x in range(-radius,radius + 1):
            var c = Vector2i(x,y)
            if not game.loaded_chunks.has(c):
                game._load_chunk(c)
            var chunk = game.loaded_chunks.get(c,null)
            if chunk == null:
                continue
            var rects = []
            for b in chunk.get_children():
                if is_instance_valid(b) and b.has_meta("world_building"):
                    var size = b.get_meta("building_size",Vector2.ZERO)
                    if typeof(size) == TYPE_VECTOR2 and size != Vector2.ZERO:
                        # the walls proper, a little inside the footprint
                        rects.append([Rect2(b.position - size * 0.5 + Vector2(8,8),size - Vector2(16,16)),str(b.get_meta("building_name",b.get_meta("building_id","")))])
            for n in chunk.get_children():
                if not (n is Node2D) or not is_instance_valid(n):
                    continue
                var k = _kind(n)
                if k == "sign":
                    signs += 1
                if k == "":
                    continue
                for r in rects:
                    if r[0].has_point(n.position):
                        total += 1
                        counts[k] = int(counts.get(k,0)) + 1
                        print("INSIDE %s %s at %s in '%s' district=%s" % [k,str(c),str(n.position.round()),r[1],str(chunk.get_meta("district_id",""))])
                        break
            game._unload_chunk(c)
        await process_frame
    print("PLACEMENT AUDIT: ",total," findings ",counts," name signs: ",signs)
    quit(0)
