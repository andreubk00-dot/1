extends SceneTree
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionNpcState = preload("res://world/faction_npc_state.gd")

var checks := 0
var failures := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var state = FactionEconomy.default_state()
    var records = state.get("named_npcs",{}).get("records",{})
    check(records.size() == 16,"default state must contain all 16 authored named NPCs")
    for faction_id in FactionCatalog.ids():
        for raw in FactionCatalog.faction(str(faction_id)).get("npc_roster",[]):
            var npc_id = str(raw.get("id",""))
            var rec = FactionNpcState.record(state,npc_id,3)
            check(not rec.is_empty(),"missing canonical NPC state: " + npc_id)
            check(str(rec.get("name","")) == str(raw.get("name","")),"canonical name mismatch: " + npc_id)
            check(str(rec.get("role","")) == str(raw.get("role","")),"canonical role mismatch: " + npc_id)
            check(str(rec.get("faction_id","")) == str(faction_id),"canonical faction mismatch: " + npc_id)
            check(str(rec.get("status","")) == "alive","new NPC must start alive: " + npc_id)

    var status_result = FactionNpcState.set_status(state,"perron_trader","wounded",5,"Ранен при вылазке.")
    check(bool(status_result.get("ok",false)) and bool(status_result.get("changed",false)),"wounded transition failed")
    check(FactionNpcState.is_present(state,"perron_trader",5),"wounded NPC should remain physically present")
    check(FactionNpcState.service_available(state,"perron_trader",5),"wounded NPC should keep current service in dev3")
    check(FactionNpcState.history(state,"perron_trader",5).size() == 1,"status transition must enter NPC history")
    check(int(FactionNpcState.record(state,"perron_trader",5).get("interaction_count",-1)) == 0,"status change must not count as player interaction")

    status_result = FactionNpcState.set_status(state,"perron_trader","missing",6,"Не вернулся с дороги.")
    check(not FactionNpcState.is_present(state,"perron_trader",6),"missing NPC must not be present")
    check(not FactionNpcState.service_available(state,"perron_trader",6),"missing NPC service must be unavailable")
    status_result = FactionNpcState.set_status(state,"perron_trader","dead",7,"Гибель подтверждена.")
    check(not FactionNpcState.is_present(state,"perron_trader",7),"dead NPC must not be present")
    status_result = FactionNpcState.set_status(state,"perron_trader","alive",8,"Вернулся после ошибочного сообщения.")
    check(FactionNpcState.is_present(state,"perron_trader",8),"alive recovery must restore presence")

    var personal = FactionNpcState.record_interaction(state,"perron_steward",9,"contract_complete","Помощь общине.",4)
    check(int(personal.get("attitude",0)) == 4,"interaction attitude delta not applied")
    check(int(personal.get("interaction_count",0)) == 1,"interaction count not incremented")
    check(int(personal.get("last_interaction_day",0)) == 9,"last interaction day not stored")
    check(FactionNpcState.attitude_label(FactionNpcState.attitude_score(state,"perron_steward",150,9)) == "РАСПОЛОЖЕН","faction reputation should influence personal attitude display")

    for i in range(20):
        FactionNpcState.record_interaction(state,"perron_radio",10 + i,"talk","Разговор %d" % i,0)
    var radio = FactionNpcState.record(state,"perron_radio",30)
    check(int(radio.get("interaction_count",0)) == 20,"interaction count must keep full total")
    check(radio.get("history",[]).size() == FactionNpcState.HISTORY_LIMIT,"NPC history must be capped")
    check(str(radio.get("history",[])[0].get("text","")) == "Разговор 8","history cap must discard oldest rows")

    var corrupted = {
        "records":{
            "perron_steward":{
                "name":"Подмена","role":"Подмена","faction_id":"rubezh","status":"zombie","attitude":999,
                "interaction_count":-20,"last_interaction_day":-5,"history":[{"day":-9,"kind":"x","text":"ok"}]
            }
        }
    }
    var clean = FactionNpcState.sanitize_state(corrupted,12)
    var steward = clean.get("records",{}).get("perron_steward",{})
    check(str(steward.get("name","")) == "Вера Андреевна","save must not override canonical NPC identity")
    check(str(steward.get("faction_id","")) == "perron","save must not move NPC between factions")
    check(str(steward.get("status","")) == "alive","invalid NPC status must sanitize to alive")
    check(int(steward.get("attitude",0)) == FactionNpcState.ATTITUDE_MAX,"attitude must clamp")
    check(int(steward.get("interaction_count",0)) == 0,"interaction count must sanitize non-negative")
    check(int(steward.get("history",[])[0].get("day",0)) == 1,"history day must sanitize")

    var faction_clean = FactionEconomy.sanitize_state(state)
    check(str(FactionNpcState.record(faction_clean,"perron_trader",8).get("status","")) == "alive","FactionEconomy sanitize lost named NPC state")
    check(int(FactionNpcState.record(faction_clean,"perron_steward",9).get("attitude",0)) == 4,"FactionEconomy sanitize lost NPC attitude")

    print("NAMED NPC STATE 1.23-dev3: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
