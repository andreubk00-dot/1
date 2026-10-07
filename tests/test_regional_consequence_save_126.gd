extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
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
func _valid_outcome()->Dictionary:
    var rows={}
    for faction_id in FactionCatalog.ids():
        rows[str(faction_id)]={"category":"secure","final_worst":68.0,"min_seen":57.0,"hardship_days":1,"supply_recovered":1,"supply_lost":0}
    return {"id":"cohesive","resolved_day":71,"factions":rows}
func _completed_state(outcome:Dictionary)->Dictionary:
    var state=FactionEconomy.default_state()
    var hardship={}; var minima={}
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); hardship[fid]=1; minima[fid]={"food":57.0,"medicine":57.0,"technical":57.0,"security":57.0}
    state["regional_endgame"]={"phase":"season_complete","started_day":50,"ends_day":71,"last_tick_day":71,"completion_day":71,"pressure_applied_day":71,"checkpoints":[7,14],"hardship_days":hardship,"resource_minima":minima,"outcome":outcome,"history":[{"day":50,"event":"started"},{"day":71,"event":"completed"}]}
    return state
func run()->void:
    var state=_completed_state(_valid_outcome())
    var clean=FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(state)))
    var outcome=clean.get("regional_endgame",{}).get("outcome",{})
    check(str(outcome.get("id",""))=="cohesive","valid outcome lost through schema-122 faction-state roundtrip")
    check(int(outcome.get("resolved_day",0))==71,"outcome resolved day drifted on save roundtrip")
    check(outcome.get("factions",{}).size()==FactionCatalog.ids().size(),"outcome faction snapshots were not preserved")

    var bad=_valid_outcome(); bad["id"]="survival_islands"
    var bad_clean=RegionalEndgame.sanitize_state(_completed_state(bad)["regional_endgame"])
    check(bad_clean.get("outcome",{}).is_empty(),"sanitizer accepted outcome id inconsistent with faction snapshots")

    var partial=_valid_outcome(); partial["factions"].erase("perron")
    var partial_clean=RegionalEndgame.sanitize_state(_completed_state(partial)["regional_endgame"])
    check(partial_clean.get("outcome",{}).is_empty(),"sanitizer accepted partial frozen outcome")

    var legacy=_completed_state({})
    var legacy_clean=FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(legacy)))
    check(legacy_clean.get("regional_endgame",{}).get("outcome",{}).is_empty(),"old dev3 completed save unexpectedly fabricated outcome during sanitize")
    var generated=RegionalEndgame.daily_tick(legacy_clean,100)
    check(bool(generated.get("outcome_generated",false)),"old completed save did not lazily generate dev4 outcome")
    check(int(generated.get("outcome",{}).get("resolved_day",0))==71,"old completed save migration stamped outcome with load/current day")
    print("REGIONAL CONSEQUENCE SAVE 1.26-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
