extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const EncounterCatalog = preload("res://world/encounter_catalog.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL ",why)
func _initialize()->void:
    call_deferred("run")
func _settle()->void:
    await process_frame
    await physics_frame
    await process_frame
func _find_event_coord(game)->Vector2i:
    for y in range(-8,9):
        for x in range(-8,9):
            var c=Vector2i(x,y)
            var profile=game._chunk_profile(c)
            var poi_id=str(profile.get("poi_id",""))
            var ev=EncounterCatalog.event_for(c,str(profile.get("zone","residential")),int(profile.get("risk",2)),poi_id)
            if not ev.is_empty() and int(ev.get("enemy_count",0))>0:
                return c
    return Vector2i(9999,9999)
func run()->void:
    var game=Harness.new()
    root.add_child(game)
    await process_frame
    game.roof_records.clear()
    var coord=_find_event_coord(game)
    check(coord.x<9000,"failed to find deterministic finite event coord")
    if coord.x>=9000:
        quit(1); return
    var base_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var first_enemy_count=-1
    var first_event_count=-1
    var max_nodes=base_nodes
    for cycle in range(24):
        game._load_chunk(coord)
        await _settle()
        var chunk=game.loaded_chunks.get(coord,null)
        check(is_instance_valid(chunk),"chunk missing after load cycle "+str(cycle))
        var enemies=[]
        var events=[]
        if is_instance_valid(chunk):
            for child in chunk.get_children():
                if bool(child.get_meta("is_enemy",false)):
                    enemies.append(child)
                if bool(child.get_meta("world_event_root",false)):
                    events.append(child)
        if cycle==0:
            first_enemy_count=enemies.size()
            first_event_count=events.size()
            check(first_enemy_count>0,"target encounter spawned no infected")
            check(first_event_count==1,"target encounter must have exactly one event root")
        else:
            check(enemies.size()==first_enemy_count,"enemy count drift on re-entry cycle "+str(cycle))
            check(events.size()==first_event_count,"event root count drift on re-entry cycle "+str(cycle))
        max_nodes=max(max_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
        var old_chunk=chunk
        var old_enemy=enemies[0] if not enemies.is_empty() else null
        var old_event=events[0] if not events.is_empty() else null
        game._unload_chunk(coord)
        await _settle()
        check(not game.loaded_chunks.has(coord),"loaded_chunks retained unloaded coord cycle "+str(cycle))
        check(not is_instance_valid(old_chunk),"chunk node survived unload cycle "+str(cycle))
        if old_enemy!=null:
            check(not is_instance_valid(old_enemy),"infected survived parent chunk unload cycle "+str(cycle))
        if old_event!=null:
            check(not is_instance_valid(old_event),"event root survived parent chunk unload cycle "+str(cycle))
        check(game.pending_spawn_chunks.is_empty(),"pending spawn queue retained chunk cycle "+str(cycle))
        check(game.roof_records.is_empty(),"roof records retained unloaded chunk cycle "+str(cycle))
    await _settle()
    var final_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    check(final_nodes<=base_nodes+12,"node count accumulated after entity cleanup: %d -> %d peak=%d" % [base_nodes,final_nodes,max_nodes])
    print("LONG SESSION ENTITY CLEANUP 1.31-dev1: ",checks," checks / ",failures," failures / coord=",coord," enemies=",first_enemy_count," events=",first_event_count," nodes=",base_nodes,"->",final_nodes," peak=",max_nodes)
    game.free()
    quit(1 if failures else 0)
