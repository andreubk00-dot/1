extends SceneTree
const RegionalEndgame = preload("res://world/regional_endgame.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok: failures+=1; printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func run()->void:
    var state=FactionEconomy.default_state()
    check(RegionalEndgame.GLOBAL_OUTCOMES.size()==5,"regional ending count drifted from five")
    check(RegionalEndgame.FACTION_OUTCOME_IDS==["secure","strained","scarred","critical"],"faction ending categories drifted")
    check(RegionalEndgame.DURATION_DAYS==21,"crisis season duration drifted")
    for key in ["escape","exit_route","outside_region","credits","game_over"]:
        check(not state.has(key),"regional endgame introduced forbidden global-exit state: "+key)
    check(int(ProjectSettings.get_setting("application/config/version","0").split("-dev")[-1])==5,"dev5 version gate mismatch")
    print("REGIONAL ENDGAME CLOSURE 1.26-dev5: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
