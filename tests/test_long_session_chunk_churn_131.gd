extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0
func check(ok:bool, why:String)->void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL ",why)
func _initialize()->void:
    call_deferred("run")
func _chunk_nodes(game)->int:
    var n=0
    for child in game.get_children():
        if str(child.name).begins_with("Chunk_"):
            n += 1
    return n
func _settle(frames:int=2)->void:
    for i in range(frames):
        await process_frame
    await physics_frame
    await process_frame
func run()->void:
    var game=Harness.new()
    root.add_child(game)
    await process_frame
    game.roof_records.clear()
    game.player.global_position=Vector2(384,384)
    game._refresh_chunks(true)
    await _settle(3)
    var initial_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var initial_roofs=game.roof_records.size()
    check(game.loaded_chunks.size()==9,"initial active chunk set must be 9")
    check(_chunk_nodes(game)==9,"initial direct chunk node count mismatch")
    var max_loaded=game.loaded_chunks.size()
    var max_pending=game.pending_spawn_chunks.size()
    var max_nodes=initial_nodes
    var visits=0
    var total_refresh_us=0
    var max_refresh_us=0
    # 12x8 serpentine = 96 long-session chunk transitions.
    for y in range(-4,4):
        var xs=range(-6,6)
        if ((y+4)&1)==1:
            xs=range(5,-7,-1)
        for x in xs:
            game.player.global_position=Vector2(x*game.CHUNK_SIZE+384,y*game.CHUNK_SIZE+384)
            var t0=Time.get_ticks_usec()
            game._refresh_chunks(true)
            var refresh_us=Time.get_ticks_usec()-t0
            total_refresh_us += refresh_us
            max_refresh_us=max(max_refresh_us,refresh_us)
            await _settle(1)
            visits += 1
            max_loaded=max(max_loaded,game.loaded_chunks.size())
            max_pending=max(max_pending,game.pending_spawn_chunks.size())
            max_nodes=max(max_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
            check(game.loaded_chunks.size()<=9,"active chunk count grew above 9 at visit "+str(visits))
            check(_chunk_nodes(game)==game.loaded_chunks.size(),"chunk dictionary/node drift at visit "+str(visits))
    game.player.global_position=Vector2(384,384)
    game._refresh_chunks(true)
    await _settle(5)
    var final_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var final_roofs=game.roof_records.size()
    check(game.loaded_chunks.size()==9,"final active chunk set must return to 9")
    check(_chunk_nodes(game)==9,"final direct chunk node count mismatch")
    check(game.pending_spawn_chunks.is_empty(),"pending spawn queue leaked after settle")
    check(final_roofs <= initial_roofs + 8,"roof records accumulated across churn: initial=%d final=%d" % [initial_roofs,final_roofs])
    # Same start area after a long tour should return close to its original live-node budget.
    check(final_nodes <= initial_nodes + 40,"live node count did not return near baseline: initial=%d final=%d max=%d" % [initial_nodes,final_nodes,max_nodes])
    var avg_refresh_us=int(total_refresh_us/max(1,visits))
    check(avg_refresh_us<150000,"average chunk refresh exceeded 150 ms: %d us"%avg_refresh_us)
    check(max_refresh_us<750000,"single chunk refresh exceeded 750 ms: %d us"%max_refresh_us)
    print("LONG SESSION CHUNK CHURN 1.31-dev1: ",checks," checks / ",failures," failures / visits=",visits," max_loaded=",max_loaded," max_pending=",max_pending," nodes=",initial_nodes,"->",final_nodes," peak=",max_nodes," roofs=",initial_roofs,"->",final_roofs," refresh_us(avg/max)=",avg_refresh_us,"/",max_refresh_us)
    game.free()
    quit(1 if failures else 0)
