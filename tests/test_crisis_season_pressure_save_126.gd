extends SceneTree
const FactionEconomy = preload("res://world/faction_economy.gd")
const RegionalEndgame = preload("res://world/regional_endgame.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func run()->void:
    var state=FactionEconomy.default_state()
    state["regional_endgame"]={
        "phase":"crisis_season","started_day":50,"ends_day":71,"last_tick_day":57,"completion_day":0,
        "pressure_applied_day":57,"checkpoints":[7],"hardship_days":{"perron":2,"rubezh":3,"mechanics":1,"lazaret":0},
        "resource_minima":{"perron":{"food":44.0,"medicine":55.0,"technical":60.0,"security":48.0},"rubezh":{"food":40.0,"medicine":50.0,"technical":46.0,"security":33.0},"mechanics":{"food":45.0,"medicine":51.0,"technical":37.0,"security":47.0},"lazaret":{"food":49.0,"medicine":42.0,"technical":52.0,"security":50.0}},
        "history":[{"day":50,"event":"started"}]
    }
    var clean=FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(state)))
    var row=clean.get("regional_endgame",{})
    check(str(row.get("phase",""))==RegionalEndgame.PHASE_ACTIVE,"active pressure phase lost on save roundtrip")
    check(int(row.get("pressure_applied_day",0))==57,"pressure_applied_day lost on save roundtrip")
    check(row.get("checkpoints",[])==[7],"checkpoint history lost on save roundtrip")
    check(int(row.get("hardship_days",{}).get("rubezh",0))==3,"hardship day metric lost on save roundtrip")
    check(abs(float(row.get("resource_minima",{}).get("mechanics",{}).get("technical",0.0))-37.0)<0.001,"resource minimum lost on save roundtrip")
    var dirty=RegionalEndgame.sanitize_state({"phase":"crisis_season","started_day":50,"ends_day":71,"pressure_applied_day":999,"checkpoints":[7,7,8,14],"hardship_days":{"perron":999},"resource_minima":{"perron":{"food":-50.0}}})
    check(int(dirty.get("pressure_applied_day",0))==71,"pressure day sanitizer did not clamp to season end")
    check(dirty.get("checkpoints",[])==[7,14],"checkpoint sanitizer accepted duplicates/non-checkpoint days")
    check(int(dirty.get("hardship_days",{}).get("perron",0))==RegionalEndgame.DURATION_DAYS,"hardship sanitizer did not clamp")
    check(abs(float(dirty.get("resource_minima",{}).get("perron",{}).get("food",1.0)))<0.001,"resource minima sanitizer did not clamp")
    print("CRISIS SEASON PRESSURE SAVE 1.26-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
