extends SceneTree
const Stress = preload("res://tests/save_stress_harness_131.gd")
const EncounterCatalog = preload("res://world/encounter_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL ",why)
func _initialize()->void:
    call_deferred("run")
func _settle(frames:int=1)->void:
    for i in range(frames): await process_frame
    await physics_frame
    await process_frame
func _entry(id:String,qty:int)->Dictionary:
    return {"id":id,"qty":qty}
func _find_event_coord(game)->Vector2i:
    for y in range(-7,8):
        for x in range(-7,8):
            var c=Vector2i(x,y)
            var p=game._chunk_profile(c)
            var ev=EncounterCatalog.event_for(c,str(p.get("zone","residential")),int(p.get("risk",2)),str(p.get("poi_id","")))
            if not ev.is_empty(): return c
    return Vector2i(9999,9999)
func run()->void:
    var game=Stress.new(); root.add_child(game); await process_frame
    game.roof_records.clear()
    # Late-game but not pathological persistent state.
    game.inventory_entries=[]
    for i in range(72): game.inventory_entries.append(_entry("bandage" if i%2==0 else "ammo_9x18",1 if i%2==0 else 10))
    game.base_objects=[]
    for i in range(96): game.base_objects.append({"id":i+1,"kind":"crate" if i%3 else "barricade","x":float((i%16)*26),"y":float((i/16)*24),"on":false,"fuel":0.0})
    game.next_base_id=97
    game.container_states={}
    for c in range(120):
        var items=[]
        for j in range(12): items.append(_entry("scrap" if j%2==0 else "water",2+(j%3)))
        game.container_states["mixed_container_%03d"%c]={"opened":true,"items":items}
    game.discovered_chunks={}
    for y in range(-12,13):
        for x in range(-12,13): game.discovered_chunks["%d:%d"%[x,y]]=true
    game.dropped_items=[]
    for i in range(160): game.dropped_items.append({"drop_id":i+1,"id":"scrap","qty":1,"x":float(i%32*16),"y":float(i/32*16),"chunk_x":i%13-6,"chunk_y":i%11-5,"instance_id":""})
    game.next_drop_id=161
    game.defeated={}; game.picked_world_items={}
    for i in range(800):
        game.defeated["def:%d"%i]=true
        game.picked_world_items["pick:%d"%i]=true
    var save_path=ProjectSettings.globalize_path(game.SAVE_PATH)
    for suffix in ["",".tmp",".bak"]:
        if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(save_path+suffix)
    game.player.global_position=Vector2(384,384)
    game._refresh_chunks(true); await _settle(3)
    var start_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var start_roofs=game.roof_records.size()
    var event_coord=_find_event_coord(game)
    check(event_coord.x<9000,"mixed session found no finite event")
    var max_nodes=start_nodes
    var save_sizes=[]
    var save_times=[]
    var transitions=0
    # 48 ordinary transitions + periodic production saves.
    for y in range(-3,3):
        var xs=range(-4,4) if ((y+3)&1)==0 else range(3,-5,-1)
        for x in xs:
            game.player.global_position=Vector2(x*game.CHUNK_SIZE+384,y*game.CHUNK_SIZE+384)
            game._refresh_chunks(true); await _settle(1)
            transitions+=1
            max_nodes=max(max_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
            check(game.loaded_chunks.size()<=9,"mixed active chunks exceeded 9")
            if transitions%8==0:
                game.world_day += 1
                FactionEconomy.daily_tick(game.faction_state)
                var t0=Time.get_ticks_usec(); game._save_state(); save_times.append(Time.get_ticks_usec()-t0)
                save_sizes.append(FileAccess.get_file_as_bytes(save_path).size())
                check(not FileAccess.file_exists(save_path+".tmp"),"mixed save left tmp")
    # Explicit finite-event cold load/unload in the same long-lived game instance.
    for i in range(8):
        if game.loaded_chunks.has(event_coord): game._unload_chunk(event_coord); await _settle(1)
        game._load_chunk(event_coord); await _settle(1)
        var event_chunk=game.loaded_chunks.get(event_coord,null)
        check(is_instance_valid(event_chunk),"mixed event chunk missing cycle "+str(i))
        game._unload_chunk(event_coord); await _settle(1)
        check(not game.loaded_chunks.has(event_coord),"mixed event chunk retained cycle "+str(i))
    game.player.global_position=Vector2(384,384); game._refresh_chunks(true); await _settle(5)
    var final_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var final_roofs=game.roof_records.size()
    check(game.loaded_chunks.size()==9,"mixed final active chunk count mismatch")
    check(game.pending_spawn_chunks.is_empty(),"mixed pending spawn queue leaked")
    check(final_nodes<=start_nodes+40,"mixed node count failed to recover: %d -> %d peak=%d"%[start_nodes,final_nodes,max_nodes])
    check(final_roofs<=start_roofs+8,"mixed roof record growth: %d -> %d"%[start_roofs,final_roofs])
    check(save_sizes.size()==6,"mixed session expected six production saves")
    if not save_sizes.is_empty():
        # First-time exploration is allowed to materialize deterministic container/door/window state.
        check(int(save_sizes.max())<2*1024*1024,"mixed first-pass save exceeded 2 MiB")
        check(int(save_sizes.max())-int(save_sizes.min())<512*1024,"mixed first-pass materialization grew unexpectedly large: "+str(save_sizes))
    if not save_times.is_empty(): check(int(save_times.max())<1500000,"mixed save write exceeded 1.5 s")
    # Save after the explicit event cold-load; this is the fully materialized baseline.
    game._save_state()
    var materialized_size=FileAccess.get_file_as_bytes(save_path).size()
    # Repeat exactly the same 48-chunk tour. No new persistence should be created now.
    for y in range(-3,3):
        var xs2=range(-4,4) if ((y+3)&1)==0 else range(3,-5,-1)
        for x in xs2:
            game.player.global_position=Vector2(x*game.CHUNK_SIZE+384,y*game.CHUNK_SIZE+384)
            game._refresh_chunks(true); await _settle(1)
    game.player.global_position=Vector2(384,384); game._refresh_chunks(true); await _settle(4)
    game._save_state()
    var revisit_size=FileAccess.get_file_as_bytes(save_path).size()
    check(revisit_size<=materialized_size+2048,"revisiting materialized chunks kept growing save: %d -> %d"%[materialized_size,revisit_size])
    check(game.pending_spawn_chunks.is_empty(),"mixed revisit left pending spawn queue")
    var revisit_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    check(revisit_nodes<=start_nodes+40,"mixed revisit node count drift: %d -> %d"%[start_nodes,revisit_nodes])
    print("MIXED LONG SESSION CLOSURE 1.31-dev2: ",checks," checks / ",failures," failures / transitions=",transitions," nodes=",start_nodes,"->",final_nodes," revisit=",revisit_nodes," peak=",max_nodes," roofs=",start_roofs,"->",final_roofs," first_pass_saves=",save_sizes," materialized/revisit=",materialized_size,"/",revisit_size," max_save_us=",int(save_times.max()) if not save_times.is_empty() else 0)
    game.free(); quit(1 if failures else 0)
