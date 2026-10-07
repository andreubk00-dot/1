extends SceneTree
const Main = preload("res://main_script_mod.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String):
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize():
    var isolated=OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated=="" or not OS.get_user_data_dir().begins_with(isolated+"/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2); return
    call_deferred("run")
func _fund(game,faction_id:String):
    game.faction_state["factions"][faction_id]["reputation"]=75
    for r in game.SettlementProjects.RESOURCE_KEYS:
        game.faction_state["factions"][faction_id]["resources"][r]=100.0
func run():
    var game=Main.new(); root.add_child(game)
    await process_frame; await process_frame
    game.faction_state=game.FactionEconomy.default_state()
    game.high_risk_state=game.HighRiskMechanics.default_state()
    game.world_day=31; game.world_minutes=710.0
    _fund(game,"mechanics")
    var spec=game.SettlementProjects.project("mechanics")
    var install=game.SettlementProjects.install_strategic_item(game.faction_state,"mechanics",str(spec.get("strategic_item","")),31)
    check(bool(install.get("ok",false)),"save fixture could not install strategic item")
    var guard=0
    while not game.SettlementProjects.is_completed(game.faction_state,"mechanics") and guard<30:
        var c=game.SettlementProjects.commit_resources(game.faction_state,"mechanics",31)
        check(bool(c.get("ok",false)),"save fixture warehouse commit stalled")
        guard+=1
    check(game.SettlementProjects.is_completed(game.faction_state,"mechanics"),"save fixture project not completed")
    check(game.HighRiskMechanics.mark_strategic_spawned(game.high_risk_state,"underground_object_vector"),"save fixture strategic source flag not set")
    game.HighRiskMechanics.unlock_access(game.high_risk_state,"underground_object_vector",2,31)
    game._save_state()
    var raw=game.SaveStore.read_save(game.SAVE_PATH)
    check(not raw.is_empty(),"production SaveStore could not read dev6 save")
    check(int(raw.get("save_version",0))==122,"dev6 changed save schema instead of extending schema 122")
    check(typeof(raw.get("faction_state",{}).get("settlement_projects",{}))==TYPE_DICTIONARY,"settlement projects missing from production save")
    check(bool(raw.get("high_risk_state",{}).get("underground_object_vector",{}).get("strategic_spawned",false)),"strategic source flag missing from production save")
    game.queue_free(); await process_frame; await process_frame

    var loaded=Main.new(); root.add_child(loaded)
    await process_frame; await process_frame
    loaded._load_data(); loaded._load_state()
    check(loaded.SettlementProjects.is_completed(loaded.faction_state,"mechanics"),"production load lost completed settlement project")
    var rec=loaded.SettlementProjects.record(loaded.faction_state,"mechanics")
    check(bool(rec.get("strategic_installed",false)),"production load lost installed strategic item")
    check(int(rec.get("completed_day",0))==31,"production load changed strategic project completion day")
    check(loaded.HighRiskMechanics.strategic_spawned(loaded.high_risk_state,"underground_object_vector"),"production load lost spent High Risk strategic source")
    check(loaded.HighRiskMechanics.access_unlocked(loaded.high_risk_state,"underground_object_vector",2),"production load lost unrelated High Risk access state")
    var rep=int(loaded.faction_state["factions"]["mechanics"]["reputation"])
    loaded._save_state(); loaded.queue_free(); await process_frame; await process_frame

    var again=Main.new(); root.add_child(again)
    await process_frame; await process_frame
    again._load_data(); again._load_state()
    check(again.SettlementProjects.is_completed(again.faction_state,"mechanics"),"completed project resurrected/reset on second load")
    check(int(again.faction_state["factions"]["mechanics"]["reputation"])==rep,"second load duplicated completion reputation")

    # Controlled migration: a dev5-style state with no settlement_projects and no strategic_spawned field remains safe.
    var legacy=again.FactionEconomy.default_state()
    legacy.erase("settlement_projects")
    var migrated=again.FactionEconomy.sanitize_state(legacy)
    check(migrated.has("settlement_projects"),"dev5 faction state did not gain default project state")
    check(not again.SettlementProjects.is_completed(migrated,"perron"),"migration gifted a completed project")
    var old_hr={"quarantine_center_12":{"access_cycle":1,"access_day":8}}
    var clean_hr=again.HighRiskMechanics.sanitize_state(old_hr)
    check(not bool(clean_hr["quarantine_center_12"].get("strategic_spawned",true)),"dev5 High Risk migration falsely spent strategic source")
    check(int(clean_hr["quarantine_center_12"].get("access_cycle",-1))==1,"dev5 High Risk migration lost existing access cycle")

    again.queue_free(); await process_frame
    print("STRATEGIC PROJECTS SAVE RUNTIME 1.23-dev6: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
