extends SceneTree
const StoryThreadCatalog = preload("res://world/story_thread_catalog.gd")
const EnvironmentalStoryCatalog = preload("res://world/environmental_story_catalog.gd")
const PoiStoryCatalog = preload("res://world/poi_story_catalog.gd")
const HighRiskStoryCatalog = preload("res://world/high_risk_story_catalog.gd")
const WorldChronicle = preload("res://world/world_chronicle.gd")
const FORBIDDEN_FIELDS = ["reward","loot","objective","route","target","reputation","items","spawn_id","map_marker","strategic_item","access"]
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok: failures+=1; printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func run()->void:
    check(StoryThreadCatalog.THREADS.size()==5,"dev4 must contain exactly five narrative thread summaries")
    var clue_ids={}
    for id in EnvironmentalStoryCatalog.ids(): clue_ids[str(id)]=true
    for id in PoiStoryCatalog.ids(): clue_ids[str(id)]=true
    for id in HighRiskStoryCatalog.ids(): clue_ids[str(id)]=true
    var thread_ids={}
    for row in StoryThreadCatalog.THREADS:
        var tid=str(row.get("id","")); var req=row.get("requires",[])
        check(tid!="" and not thread_ids.has(tid),"missing/duplicate thread id")
        check(not clue_ids.has(tid),tid+" collides with authored story clue id")
        thread_ids[tid]=true
        check(req.size()==3,tid+" must synthesize exactly three existing clues")
        var local={}
        for raw in req:
            var rid=str(raw)
            check(clue_ids.has(rid),tid+" requires unknown story id "+rid)
            check(not local.has(rid),tid+" repeats prerequisite "+rid)
            local[rid]=true
        for forbidden in FORBIDDEN_FIELDS: check(not row.has(forbidden),tid+" leaked gameplay field "+forbidden)
        var combined="%s — %s" % [str(row.get("title","")),str(row.get("text",""))]
        check(combined.length()<=WorldChronicle.TEXT_LIMIT,tid+" would be truncated by WorldChronicle")
        var partial=[req[0],req[1]]
        check(StoryThreadCatalog.ready_unseen(partial).filter(func(x): return str(x.get("id",""))==tid).is_empty(),tid+" triggers before all prerequisites")
        var ready=StoryThreadCatalog.ready_unseen(req)
        check(ready.filter(func(x): return str(x.get("id",""))==tid).size()==1,tid+" did not trigger with all prerequisites")
        var seen=req.duplicate(); seen.append(tid)
        check(StoryThreadCatalog.ready_unseen(seen).filter(func(x): return str(x.get("id",""))==tid).is_empty(),tid+" retriggers after synthetic id is seen")
    check(thread_ids.size()==5,"dev4 thread ids are not unique")
    print("STORY THREAD ECHOES 1.25-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
