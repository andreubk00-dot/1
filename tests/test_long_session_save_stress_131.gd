extends SceneTree
const Stress = preload("res://tests/save_stress_harness_131.gd")
const SaveStore = preload("res://world/save_store.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL ",why)
func _initialize()->void:
    call_deferred("run")
func _entry(id:String,qty:int)->Dictionary:
    return {"id":id,"qty":qty}
func run()->void:
    var game=Stress.new()
    root.add_child(game)
    await process_frame
    # Large but plausible late-game persistent state.
    game.inventory_entries=[]
    for i in range(100):
        game.inventory_entries.append(_entry("bandage" if i%3==0 else ("water" if i%3==1 else "ammo_9x18"),1 if i%3<2 else 12))
    game.base_objects=[]
    for i in range(160):
        game.base_objects.append({"id":i+1,"kind":"crate" if i%4 else "barricade","x":float((i%20)*24),"y":float((i/20)*22),"on":false,"fuel":0.0})
    game.next_base_id=161
    game.container_states={}
    for c in range(240):
        var items=[]
        for j in range(18):
            items.append(_entry("scrap" if j%3==0 else ("cloth" if j%3==1 else "water"),2+(j%4)))
        game.container_states["stress_container_%04d"%c]={"opened":true,"items":items}
    game.discovered_chunks={}
    for y in range(-20,21):
        for x in range(-20,21):
            game.discovered_chunks["%d:%d"%[x,y]]=true
    game.discovered_pois={}
    for i in range(64): game.discovered_pois["poi_stress_%02d"%i]=true
    game.picked_world_items={}
    game.defeated={}
    for i in range(1600):
        game.picked_world_items["picked:%d"%i]=true
        game.defeated["defeated:%d"%i]=true
    game.dropped_items=[]
    for i in range(320):
        game.dropped_items.append({"drop_id":i+1,"id":"scrap","qty":1+(i%3),"x":float((i%40)*15),"y":float((i/40)*15),"chunk_x":i%21-10,"chunk_y":i%17-8,"instance_id":""})
    game.next_drop_id=321
    game.map_markers=[]
    for i in range(120):
        game.map_markers.append({"x":i%21-10,"y":i%17-8,"label":"M%03d"%i})
    game.world_day=365
    game.world_minutes=1110.0
    var path=ProjectSettings.globalize_path(game.SAVE_PATH)
    for suffix in ["",".tmp",".bak"]:
        if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
    var sizes=[]
    var times=[]
    for i in range(20):
        var t0=Time.get_ticks_usec()
        game._save_state()
        times.append(Time.get_ticks_usec()-t0)
        check(FileAccess.file_exists(path),"save file missing after write "+str(i))
        sizes.append(FileAccess.get_file_as_bytes(path).size())
        check(not FileAccess.file_exists(path+".tmp"),"tmp file left after write "+str(i))
    var min_size=int(sizes.min())
    var max_size=int(sizes.max())
    var max_us=int(times.max())
    check(max_size-min_size<=16,"repeated identical save grew in size: %d..%d"%[min_size,max_size])
    check(max_size<5*1024*1024,"stress save exceeded 5 MiB: "+str(max_size))
    check(max_us<1500000,"single stress save exceeded 1.5 s: %d us"%max_us)
    var parsed=SaveStore.read_save(game.SAVE_PATH)
    check(not parsed.is_empty(),"stress save could not be read back")
    check(int(parsed.get("save_version",0))==122,"stress save schema changed")
    check(parsed.get("base_objects",[]).size()==160,"base object count changed on readback")
    check(parsed.get("container_states",{}).size()==240,"container state count changed on readback")
    check(parsed.get("discovered_chunks",{}).size()==1681,"discovered chunk count changed on readback")
    check(parsed.get("dropped_items",[]).size()==320,"dropped item count changed on readback")
    check(parsed.get("defeated",{}).size()==1600,"defeated count changed on readback")
    print("LONG SESSION SAVE STRESS 1.31-dev1: ",checks," checks / ",failures," failures / bytes=",min_size,"..",max_size," max_write_us=",max_us," containers=240 base=160 chunks=1681 drops=320")
    game.free()
    quit(1 if failures else 0)
