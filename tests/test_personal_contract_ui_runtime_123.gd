extends SceneTree
var failures := 0
var checks := 0
var main

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _row(source:String) -> int:
    for i in range(main.contract_list.item_count):
        var meta = main.contract_list.get_item_metadata(i)
        if typeof(meta) == TYPE_DICTIONARY and str(meta.get("source","")) == source:
            return i
    return -1

func run() -> void:
    var packed = load("res://main.tscn")
    check(packed != null,"main scene failed to load")
    if packed == null:
        quit(1)
        return
    main = packed.instantiate()
    root.add_child(main)
    await process_frame
    await process_frame
    main.faction_state = main.FactionEconomy.default_state()
    main.FactionEconomy.add_reputation(main.faction_state,"perron",25)
    main.ContractSystem.ensure_state(main.faction_state,main.world_day)

    main._open_contract_board("perron","Лёнька","perron_radio")
    await process_frame
    check(main.contract_open and main.contract_panel.visible,"personal contract board did not open")
    check(main.contract_title.text.find("ЛИЧНЫЙ ЭФИР") >= 0,"personal board did not use authored board label")
    check(main.contract_subtitle.text.find("Лёнька") >= 0,"personal board subtitle lost owner name")
    check(main.contract_status.text.find("личные поручения") >= 0,"personal board did not explain deadline/consequence rules")
    var offer_row = _row("offer")
    check(offer_row >= 0,"personal board has no offer row")
    if offer_row >= 0:
        check(main.contract_list.get_item_text(offer_row).find("[ЛИЧНО]") >= 0,"personal offer row lacks personal marker")
        main._contract_selected(offer_row)
        check(main.contract_status.text.find("ЛИЧНЫЙ СРОК") >= 0,"personal selection does not show deadline warning")
        check(main.contract_status.text.find("ОТКАЗ ПОСЛЕ ПРИНЯТИЯ") >= 0,"personal selection does not show abandon consequence")
        var selected_id = main.selected_contract_id
        var attitude_before = int(main.FactionNpcState.record(main.faction_state,"perron_radio",main.world_day).get("attitude",0))
        check(bool(main._contract_accept_selected()),"personal UI accept failed")
        var accepted = main.ContractSystem.contract_by_id(main.faction_state,selected_id)
        check(int(accepted.get("deadline_day",0)) > main.world_day,"personal UI accept did not assign active deadline")
        check(int(main.FactionNpcState.record(main.faction_state,"perron_radio",main.world_day).get("attitude",0)) == attitude_before + 1,"personal UI accept double-counted or missed NPC attitude")
        var active_row = _row("active")
        check(active_row >= 0,"personal accepted row missing")
        if active_row >= 0:
            check(main.contract_list.get_item_text(active_row).find("срок до дня") >= 0,"personal active row does not show deadline")
            main._contract_selected(active_row)
            var requirements = accepted.get("requirements",[])
            if not requirements.is_empty():
                for req in requirements[0]:
                    var item_id = str(req.get("id",""))
                    var need = int(req.get("qty",0))
                    var have = main._inventory_count(item_id)
                    if have < need:
                        main._grid_add(main.inventory_entries,item_id,need-have,main.INV_W,main.INV_H)
                main._refresh_contract_ui()
                active_row = _row("active")
                if active_row >= 0:
                    main._contract_selected(active_row)
                var attitude_pre_complete = int(main.FactionNpcState.record(main.faction_state,"perron_radio",main.world_day).get("attitude",0))
                check(bool(main._contract_complete_selected()),"personal UI completion failed")
                var attitude_post_complete = int(main.FactionNpcState.record(main.faction_state,"perron_radio",main.world_day).get("attitude",0))
                check(attitude_post_complete == attitude_pre_complete + 7,"personal UI completion duplicated NPC attitude reward")
                var next_offer = main.ContractSystem.offers_for_npc(main.faction_state,"perron_radio",main.world_day)
                check(next_offer.size() == 1 and str(next_offer[0].get("template_id","")) == "perron_radio_dead_frequency","personal UI completion did not unlock chain step 2")
                var news = main.WorldChronicle.entries(main.faction_state,10)
                var saw_personal_news = false
                for row in news:
                    if str(row.get("text","")).find("личное поручение") >= 0:
                        saw_personal_news = true
                        break
                check(saw_personal_news,"personal completion did not enter world chronicle")

    # Abandon feedback is no longer the old misleading "without reputation penalty" text.
    main._close_contract_board()
    main.faction_state = main.FactionEconomy.default_state()
    main.FactionEconomy.add_reputation(main.faction_state,"mechanics",25)
    main.ContractSystem.ensure_state(main.faction_state,main.world_day)
    main._open_contract_board("mechanics","Клык","mechanics_storekeeper")
    await process_frame
    offer_row = _row("offer")
    check(offer_row >= 0,"Mechanics personal board has no offer")
    if offer_row >= 0:
        main._contract_selected(offer_row)
        check(bool(main._contract_accept_selected()),"Mechanics personal UI accept failed")
        var active_row2 = _row("active")
        check(active_row2 >= 0,"Mechanics personal active row missing")
        if active_row2 >= 0:
            main._contract_selected(active_row2)
            var rep_before = main.FactionEconomy.reputation(main.faction_state,"mechanics")
            check(bool(main._contract_abandon_selected()),"personal UI abandon failed")
            check(main.FactionEconomy.reputation(main.faction_state,"mechanics") == rep_before - 1,"personal UI abandon did not apply authored reputation consequence")

    main.queue_free()
    await process_frame
    print("PERSONAL CONTRACT UI RUNTIME 1.23-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
