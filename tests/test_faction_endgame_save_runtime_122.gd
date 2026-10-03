extends SceneTree
const Main = preload("res://main_script_mod.gd")

var failures := 0
var checks := 0
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

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.world_day = 21
    game.FactionEconomy.add_reputation(game.faction_state,"lazaret",220)
    for key in game.FactionEconomy.RESOURCE_KEYS:
        game.faction_state["factions"]["lazaret"]["resources"][key] = 90.0
    for template_id in ["lazaret_endgame_clinical_complex","lazaret_endgame_sterile_reserve","lazaret_endgame_medical_network"]:
        var outcome = game.FactionEndgame.apply_contract_outcome(game.faction_state,game.ContractCatalog.template(template_id),game.world_day)
        check(not outcome.is_empty(),"fixture endgame progression failed: " + template_id)
    check(game.FactionEndgame.is_finalized(game.faction_state,"lazaret"),"fixture Lazaret chain not finalized")
    var relation_before = game.FactionRelations.relation(game.faction_state,"lazaret","rubezh")
    game._save_state()

    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    check(loaded.FactionEndgame.is_finalized(loaded.faction_state,"lazaret"),"production save/load lost Lazaret finalization")
    check(loaded.FactionEndgame.effect_active(loaded.faction_state,"lazaret_medical_network"),"production save/load lost permanent medical effect")
    check(loaded.FactionRelations.relation(loaded.faction_state,"lazaret","rubezh") == relation_before,"production save/load changed endgame relation consequence")
    check(loaded.faction_state.get("faction_endgame",{}).get("history",[]).size() == 3,"production save/load lost endgame history")
    var medicine_before = float(loaded.faction_state["factions"]["lazaret"]["resources"]["medicine"])
    loaded.FactionEconomy.daily_tick(loaded.faction_state)
    check(float(loaded.faction_state["factions"]["lazaret"]["resources"]["medicine"]) > medicine_before - 0.7,"loaded permanent medical effect must apply on daily tick")

    loaded.free()
    game.queue_free()
    await process_frame
    await process_frame
    print("FACTION ENDGAME SAVE RUNTIME 1.22-dev8: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
