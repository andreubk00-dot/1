extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const PREFIXES = ["makarov","tt33","shotgun","toz34","sks","akm","pps43","izh81","aks74u","mosin","knife","pipe","axe"]
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func run()->void:
    var game=Harness.new(); root.add_child(game); await process_frame; await process_frame
    for prefix in PREFIXES:
        for clip in ["Idle","Idle2","Idle3"]:
            check(ResourceLoader.exists("res://survivor_%s_%s.png" % [prefix,clip]),"missing idle sheet "+prefix+"/"+clip)
    for clip in ["Idle","Idle2","Idle3"]:
        check(ResourceLoader.exists("res://survivor_%s.png" % clip),"missing unarmed idle fallback "+clip)
    game.modern_survivor_idle_time=0.0; check(game._modern_survivor_idle_sheet("")=="Idle","fresh idle did not start on Idle")
    game.modern_survivor_idle_time=5.5; check(game._modern_survivor_idle_sheet("")=="Idle2","first authored idle variation window missing")
    game.modern_survivor_idle_time=8.0; check(game._modern_survivor_idle_sheet("")=="Idle","idle did not return to base between variations")
    game.modern_survivor_idle_time=11.5; check(game._modern_survivor_idle_sheet("")=="Idle3","second authored idle variation window missing")
    game.modern_survivor_idle_time=14.0; check(game._modern_survivor_idle_sheet("")=="Idle","idle did not return to base after Idle3")
    game.reload_time=0.0; game.weapon_cycle_time=0.0; game.melee_swing_time=0.0; game.weapon_recoil_time=0.0; game.modern_survivor_hit_time=0.0
    check(game._modern_survivor_idle_can_advance(false),"clean stationary state does not advance idle timer")
    check(not game._modern_survivor_idle_can_advance(true),"movement does not block idle timer")
    game.reload_time=1.0; check(not game._modern_survivor_idle_can_advance(false),"reload does not block idle timer"); game.reload_time=0.0
    game.weapon_cycle_time=1.0; check(not game._modern_survivor_idle_can_advance(false),"weapon cycle does not block idle timer"); game.weapon_cycle_time=0.0
    game.melee_swing_time=1.0; check(not game._modern_survivor_idle_can_advance(false),"melee swing does not block idle timer"); game.melee_swing_time=0.0
    game.weapon_recoil_time=1.0; check(not game._modern_survivor_idle_can_advance(false),"firearm recoil does not block idle timer"); game.weapon_recoil_time=0.0
    game.modern_survivor_hit_time=1.0; check(not game._modern_survivor_idle_can_advance(false),"hit reaction does not block idle timer")
    game.queue_free(); await process_frame
    print("IDLE ANIMATION POLISH 1.27-dev1: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
