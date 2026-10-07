extends SceneTree

const Main = preload("res://main_script_mod.gd")
const HighRiskMechanics = preload("res://world/high_risk_mechanics.gd")
const SaveStore = preload("res://world/save_store.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")

func _cleanup(path:String) -> void:
    for suffix in ["",".bak",".tmp"]:
        var full = ProjectSettings.globalize_path(path + suffix)
        if FileAccess.file_exists(path + suffix):
            DirAccess.remove_absolute(full)

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame
    await process_frame
    _cleanup(game.SAVE_PATH)
    game.world_day = 37
    game.world_minutes = 900.0
    game.loot_refresh_sites["underground_object_vector"] = {"cycle":2,"ready_day":0,"cleared_day":20,"last_refresh_day":35}
    game.high_risk_state = HighRiskMechanics.default_state()
    check(HighRiskMechanics.unlock_access(game.high_risk_state,"underground_object_vector",2,37),"save fixture access unlock failed")
    check(HighRiskMechanics.mark_incident_announced(game.high_risk_state,"underground_object_vector",2),"save fixture incident announcement failed")
    check(HighRiskMechanics.mark_incident_resolved(game.high_risk_state,"underground_object_vector",2),"save fixture incident resolution failed")
    check(HighRiskMechanics.mark_depleted(game.high_risk_state,"underground_object_vector",2,36),"save fixture depleted mark failed")
    check(HighRiskMechanics.mark_reoccupied(game.high_risk_state,"underground_object_vector",2,37),"save fixture reoccupied mark failed")
    game._save_state()

    var raw = SaveStore.read_save(game.SAVE_PATH)
    check(not raw.is_empty(),"production save store rejected dev5 save")
    check(int(raw.get("save_version",0)) == 122,"dev5 changed production save schema")
    check(typeof(raw.get("high_risk_state",null)) == TYPE_DICTIONARY,"dev5 save lacks high_risk_state dictionary")

    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    var rec = HighRiskMechanics.record(loaded.high_risk_state,"underground_object_vector")
    check(int(rec.get("access_cycle",-1)) == 2,"production load lost High Risk access cycle")
    check(int(rec.get("access_day",0)) == 37,"production load lost High Risk access day")
    check(int(rec.get("incident_resolved_cycle",-1)) == 2,"production load lost incident resolution")
    check(int(rec.get("depleted_cycle",-1)) == 2 and int(rec.get("depleted_day",0)) == 36,"production load lost depletion state")
    check(int(rec.get("reoccupied_cycle",-1)) == 2 and int(rec.get("reoccupied_day",0)) == 37,"production load lost reoccupation state")
    check(int(loaded.loot_refresh_sites.get("underground_object_vector",{}).get("cycle",0)) == 2,"production load desynchronized target-farm cycle")

    # Legacy schema-122 save with no dev5 block must remain readable and initialize safely.
    var file = FileAccess.open(game.SAVE_PATH,FileAccess.READ)
    var legacy = JSON.parse_string(file.get_as_text())
    file.close()
    legacy.erase("high_risk_state")
    var writer = FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
    writer.store_string(JSON.stringify(legacy))
    writer.close()
    var legacy_loaded = Main.new()
    legacy_loaded._load_data()
    legacy_loaded._load_state()
    check(legacy_loaded.high_risk_state.size() == HighRiskMechanics.SITE_IDS.size(),"legacy schema-122 save did not initialize High Risk state")
    check(not HighRiskMechanics.access_unlocked(legacy_loaded.high_risk_state,"underground_object_vector",2),"legacy save received free deep access")

    # SaveStore rejects a malformed new top-level block instead of feeding it to gameplay.
    var malformed = legacy.duplicate(true)
    malformed["high_risk_state"] = []
    writer = FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
    writer.store_string(JSON.stringify(malformed))
    writer.close()
    if FileAccess.file_exists(game.SAVE_PATH + ".bak"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SAVE_PATH + ".bak"))
    check(SaveStore.read_save(game.SAVE_PATH).is_empty(),"SaveStore accepted malformed high_risk_state")

    legacy_loaded.free()
    loaded.free()
    game.queue_free()
    await process_frame
    await process_frame
    print("HIGH RISK MECHANICS SAVE RUNTIME 1.23-dev5: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
