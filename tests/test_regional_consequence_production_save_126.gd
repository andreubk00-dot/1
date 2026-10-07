extends SceneTree
const Main = preload("res://main_script_mod.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const RegionalEndgame = preload("res://world/regional_endgame.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize()->void:
    var isolated=OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated=="" or not OS.get_user_data_dir().begins_with(isolated+"/"):
        printerr("Use dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")
func _prime(game)->Dictionary:
    var hardship={}; var minima={}
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id); hardship[fid]=0; minima[fid]={}
        for resource_id in RegionalEndgame.RESOURCE_KEYS:
            var rid=str(resource_id); game.faction_state["factions"][fid]["resources"][rid]=70.0; minima[fid][rid]=60.0
    game.faction_state["regional_endgame"]={"phase":"season_complete","started_day":50,"ends_day":71,"last_tick_day":71,"completion_day":71,"pressure_applied_day":71,"checkpoints":[7,14],"hardship_days":hardship,"resource_minima":minima,"outcome":{},"history":[{"day":50,"event":"started"},{"day":71,"event":"completed"}]}
    return RegionalEndgame.resolve_outcome(game.faction_state,71)
func run()->void:
    var game=Main.new(); root.add_child(game); await process_frame; await process_frame
    game.faction_state=game.FactionEconomy.default_state(); game.world_day=90; game.world_minutes=600.0
    var first=_prime(game); check(str(first.get("id",""))=="cohesive","production-save fixture did not resolve cohesive ending")
    game._save_state()
    var raw=game.SaveStore.read_save(game.SAVE_PATH)
    check(not raw.is_empty(),"production SaveStore could not read consequence-ending fixture")
    check(int(raw.get("save_version",0))==122,"dev4 changed production save schema")
    var saved=raw.get("faction_state",{}).get("regional_endgame",{}).get("outcome",{})
    check(str(saved.get("id",""))=="cohesive","production save lost frozen regional outcome")
    check(int(saved.get("resolved_day",0))==71,"production save drifted outcome resolution day")
    check(saved.get("factions",{}).size()==FactionCatalog.ids().size(),"production save lost faction outcome snapshots")
    check(not raw.has("regional_outcome") and not raw.has("ending_state") and not raw.has("crisis_season_state"),"dev4 introduced top-level endgame persistence")
    game.queue_free(); await process_frame; await process_frame

    var loaded=Main.new(); root.add_child(loaded); await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    var loaded_outcome=loaded.faction_state.get("regional_endgame",{}).get("outcome",{}).duplicate(true)
    check(str(loaded_outcome.get("id",""))=="cohesive","schema-122 reload lost regional outcome")
    for faction_id in FactionCatalog.ids():
        var fid=str(faction_id)
        for resource_id in RegionalEndgame.RESOURCE_KEYS:
            loaded.faction_state["factions"][fid]["resources"][str(resource_id)]=0.0
    var frozen=RegionalEndgame.resolve_outcome(loaded.faction_state,365)
    check(frozen==loaded_outcome,"post-season sandbox resource changes recalculated saved ending")
    loaded.queue_free(); await process_frame
    print("REGIONAL CONSEQUENCE PRODUCTION SAVE 1.26-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
