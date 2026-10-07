extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const WorldChronicle = preload("res://world/world_chronicle.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok: failures+=1; printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func _fake(id:String,title:String)->Node2D:
    var n=Node2D.new(); n.set_meta("story_id",id); n.set_meta("story_title",title); n.set_meta("story_text","QA prerequisite "+id); n.set_meta("display_name","ЗАПИСКА"); return n
func _count_history(game:Node,needle:String)->int:
    var count=0
    for row in WorldChronicle.entries(game.faction_state,64,false):
        if str(row.get("text",""))==needle: count+=1
    return count
func run()->void:
    var game=Harness.new(); root.add_child(game); await process_frame; await process_frame
    game.faction_state["world_chronicle"]=WorldChronicle.default_state()
    var ids=["district_hospital_triage_sheet","clinical_wards_transfer_sheet","clinical_surgery_last_board"]
    for i in range(ids.size()):
        var n=_fake(ids[i],"QA %d"%i); game.add_child(n); game._read_story_clue(n)
        if i<2: check(not WorldChronicle.story_seen(game.faction_state,"thread_medical_collapse"),"medical summary triggered too early")
    check(WorldChronicle.story_seen(game.faction_state,"thread_medical_collapse"),"medical summary did not trigger after third prerequisite")
    var expected="Полевая сводка: медицинский контур — Районная больница ещё считала расходники, когда областной комплекс уже переносил тяжёлых вручную и терял питание секциями. Медицинская сеть распалась не сразу, а звено за звеном."
    check(_count_history(game,expected)==1,"medical summary history entry missing/duplicated")
    var again=_fake(ids[2],"QA repeat"); game.add_child(again); game._read_story_clue(again)
    check(_count_history(game,expected)==1,"rereading prerequisite duplicated summary")
    game.queue_free(); await process_frame
    print("STORY THREAD ECHOES RUNTIME 1.25-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
