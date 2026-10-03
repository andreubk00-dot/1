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

func _offer(game,faction_id:String,template_id:String) -> Dictionary:
    for row in game.ContractSystem.offers_for_faction(game.faction_state,faction_id,game.world_day):
        if str(row.get("template_id","")) == template_id:
            return row
    return {}

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.world_day = 6
    game.FactionEconomy.add_reputation(game.faction_state,"rubezh",100)
    game.FactionEconomy.add_reputation(game.faction_state,"lazaret",100)
    game.faction_state["factions"]["rubezh"]["resources"]["security"] = 5.0
    game.faction_state["factions"]["lazaret"]["resources"]["medicine"] = 5.0
    game.ContractSystem.ensure_state(game.faction_state,game.world_day)
    game.ContractSystem.refresh_offers(game.faction_state,game.world_day,true)

    var offer = _offer(game,"lazaret","lazaret_quarantine_policy")
    check(not offer.is_empty(),"Lazaret policy offer missing")
    var accepted = game.ContractSystem.accept(game.faction_state,str(offer.get("id","")),game.world_day)
    check(bool(accepted.get("ok",false)),"Lazaret policy acceptance failed")
    var finished = game.ContractSystem.complete(game.faction_state,str(offer.get("id","")),game.world_day)
    check(bool(finished.get("ok",false)),"Lazaret policy completion failed")
    check(str(game.FactionRelations.decision(game.faction_state,"quarantine_policy").get("choice","")) == "medical_corridor","runtime decision was not recorded")
    check(game.FactionRelations.relation(game.faction_state,"rubezh","lazaret") == -20,"runtime relation mutation missing")

    game._save_state()
    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    loaded.ContractSystem.ensure_state(loaded.faction_state,loaded.world_day)

    check(str(loaded.FactionRelations.decision(loaded.faction_state,"quarantine_policy").get("choice","")) == "medical_corridor","production save/load lost faction decision")
    check(loaded.FactionRelations.relation(loaded.faction_state,"rubezh","lazaret") == -20,"production save/load lost faction relation")
    loaded.ContractSystem.refresh_offers(loaded.faction_state,loaded.world_day,true)
    check(_offer(loaded,"rubezh","rubezh_quarantine_policy").is_empty(),"resolved opposing policy returned after save/load")
    check(_offer(loaded,"lazaret","lazaret_quarantine_policy").is_empty(),"resolved winning policy returned after save/load")

    loaded.free()
    game.queue_free()
    await process_frame
    await process_frame
    print("FACTION RELATIONS SAVE RUNTIME 1.22-dev5: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
