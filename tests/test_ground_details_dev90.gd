extends SceneTree
# 1.54 (test): the small ground details - open ground carries a scatter of
# flat details, none inside a building or on a lot, the same every time the
# chunk is built, and none of them solid.
const Main = preload("res://main_script_mod.gd")
var game
var fails = 0

func _initialize():
    call_deferred("run")

func check(ok: bool, msg: String) -> void:
    if not ok:
        fails += 1
        print("FAIL ", msg)

func details(chunk) -> Array:
    var out = []
    for n in chunk.get_children():
        if n.has_meta("ground_detail") and not n.is_queued_for_deletion():
            out.append(n)
    return out

func run():
    Engine.set_meta("ostatok_new_game", true)
    game = Main.new()
    root.add_child(game)
    for i in 10: await process_frame
    game.developer_invulnerable = true
    var total = 0
    var with_details = 0
    var covers = 0
    for coord in [Vector2i(1,0), Vector2i(2,1), Vector2i(-2,1), Vector2i(0,-2), Vector2i(5,0), Vector2i(-1,-1), Vector2i(3,-3), Vector2i(-4,2), Vector2i(0,-5), Vector2i(-6,-2)]:
        game._qa_move_to_world_chunk(coord)
        for i in 12: await physics_frame
        var chunk = game.loaded_chunks.get(coord, null)
        if chunk == null:
            continue
        var ds = details(chunk)
        for n in chunk.get_children():
            if n.has_meta("ground_cover") and not n.is_queued_for_deletion():
                covers += 1
                check(n.z_index < 0 and n.get_child_count() == 0, "%s cover at %s is not a flat sprite" % [str(coord), str(n.position)])
                for b in chunk.get_children():
                    if b.has_meta("building_size") and typeof(b.get_meta("building_size")) == TYPE_VECTOR2:
                        var bsz: Vector2 = b.get_meta("building_size")
                        check(not Rect2(b.position - bsz * 0.5, bsz).grow(8.0).has_point(n.position), "%s cover at %s inside a building" % [str(coord), str(n.position)])
                    elif game._holds_ground(b):
                        check(not game._world_event_rect(b).has_point(n.position), "%s cover at %s on a lot" % [str(coord), str(n.position)])
        total += ds.size()
        if not ds.is_empty():
            with_details += 1
        var sig = []
        for d in ds:
            sig.append([d.position, d.get_meta("ground_detail")])
            check(not (d is CollisionObject2D) and d.get_child_count() == 0, "%s detail at %s is not a plain sprite" % [str(coord), str(d.position)])
            check(d.z_index < 0, "%s detail at %s draws over things" % [str(coord), str(d.position)])
            for b in chunk.get_children():
                if b.has_meta("building_size") and typeof(b.get_meta("building_size")) == TYPE_VECTOR2:
                    var sz: Vector2 = b.get_meta("building_size")
                    check(not Rect2(b.position - sz * 0.5, sz).has_point(d.position), "%s detail at %s inside a building" % [str(coord), str(d.position)])
                elif game._holds_ground(b):
                    check(not game._world_event_rect(b).has_point(d.position), "%s detail at %s on a lot" % [str(coord), str(d.position)])
        # a second scatter over the same chunk lands in the same places
        for d in ds:
            chunk.remove_child(d)
            d.free()
        game._scatter_ground_details(chunk, coord)
        var sig2 = []
        for d in details(chunk):
            sig2.append([d.position, d.get_meta("ground_detail")])
        # (a wandering animal or a dropped item may cover or free a spot)
        var differ = 0
        for e in sig:
            if not sig2.has(e):
                differ += 1
        for e in sig2:
            if not sig.has(e):
                differ += 1
        check(differ <= 3, "%s scatter is not deterministic (%d of %d differ)" % [str(coord), differ, sig.size()])
    check(with_details >= 4, "only %d of the visited chunks carry ground details" % with_details)
    check(total >= 80, "only %d ground details over the visited chunks" % total)
    check(covers >= 10, "only %d pieces of ground cover in the woods and dachas" % covers)
    print("ground details: %d in %d chunks, cover %d" % [total, with_details, covers])
    print("TEST PASSED" if fails == 0 else "TEST FAILED (%d)" % fails)
    quit(0 if fails == 0 else 1)
