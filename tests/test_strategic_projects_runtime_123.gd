extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const HighRiskMechanics = preload("res://world/high_risk_mechanics.gd")
const SettlementProjects = preload("res://world/settlement_projects.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String):
    checks+=1
    if not ok:
        failures+=1
        printerr("FAIL: ",msg)
func _initialize(): call_deferred("run")
func _count(entries:Array,item_id:String)->int:
    var n=0
    for e in entries:
        if str(e.get("id",""))==item_id: n += int(e.get("qty",1))
    return n
func run():
    var game=Harness.new()
    root.add_child(game)
    await process_frame
    game.faction_state = game.FactionEconomy.default_state()
    game.high_risk_state = HighRiskMechanics.default_state()
    game.world_day=20

    # New-game authored cache must have physical grid room for its guaranteed strategic item.
    # This uses each site's real world container key/profile, so a too-dense loot roll cannot
    # silently delay the progression item until a later reoccupation.
    for new_poi_id in HighRiskMechanics.SITE_IDS:
        game.container_states = {}
        game.high_risk_state = HighRiskMechanics.default_state()
        var new_poi=game.RegionCatalog.poi_by_id(str(new_poi_id))
        var new_keys=game._target_farm_expected_container_keys(new_poi)
        var cache3_key=""
        for raw_key in new_keys:
            if str(raw_key).ends_with(":cache_3"):
                cache3_key=str(raw_key)
                break
        check(cache3_key!="",str(new_poi_id)+" authored target-farm set has no cache_3")
        if cache3_key!="":
            var profile=game._target_farm_profile(new_poi)
            game.container_states[cache3_key]={"name":"authored cache","loot_table":profile,"grid_w":8,"grid_h":8,"items":game._generate_loot(cache3_key,profile,8,8)}
            check(game._ensure_high_risk_strategic_cache_item(str(new_poi_id),"cache_3",cache3_key),str(new_poi_id)+" real authored cache has no room for guaranteed strategic item")
            check(_count(game.container_states[cache3_key]["items"],HighRiskMechanics.strategic_item(str(new_poi_id)))==1,str(new_poi_id)+" authored first-run cache missing guaranteed strategic item")

    game.container_states = {}
    game.high_risk_state = HighRiskMechanics.default_state()

    # One-off authored cache injection and migration-safe duplication guard.
    for poi_id in HighRiskMechanics.SITE_IDS:
        var item_id=HighRiskMechanics.strategic_item(str(poi_id))
        var key="qa:%s:cache_3" % poi_id
        game.container_states[key]={"name":"QA","loot_table":HighRiskMechanics.site(str(poi_id)).get("core_profile",""),"grid_w":8,"grid_h":8,"items":[]}
        check(game._ensure_high_risk_strategic_cache_item(str(poi_id),"cache_3",key),str(poi_id)+" did not inject strategic item")
        check(_count(game.container_states[key]["items"],item_id)==1,str(poi_id)+" strategic cache quantity != 1")
        check(HighRiskMechanics.strategic_spawned(game.high_risk_state,str(poi_id)),str(poi_id)+" spawned bit not persisted")
        check(not game._ensure_high_risk_strategic_cache_item(str(poi_id),"cache_3",key),str(poi_id)+" duplicated strategic item on second cache build")
        check(_count(game.container_states[key]["items"],item_id)==1,str(poi_id)+" strategic item duplicated")
        check(game._make_item_icon(item_id)!=null,str(poi_id)+" strategic inventory schematic icon missing")
        check(game._make_world_loot_texture(item_id)!=null,str(poi_id)+" strategic world schematic icon missing")

    # Old save migration: if the item already exists in inventory, mark source spent instead of cloning it.
    game.high_risk_state = HighRiskMechanics.default_state()
    var qid="quarantine_center_12"
    var qitem=HighRiskMechanics.strategic_item(qid)
    var qkey="qa:migration:cache_3"
    game.container_states[qkey]={"grid_w":8,"grid_h":8,"items":[]}
    check(game._grid_add(game.inventory_entries,qitem,1,game.INV_W,game.INV_H)==0,"could not prepare migration strategic inventory fixture")
    check(not game._ensure_high_risk_strategic_cache_item(qid,"cache_3",qkey),"migration duplicated strategic item already held by player")
    check(HighRiskMechanics.strategic_spawned(game.high_risk_state,qid),"migration did not mark held strategic item as spawned")
    check(_count(game.container_states[qkey]["items"],qitem)==0,"migration cloned held strategic item into cache")

    # Old emptied core cache stays empty on migration, then receives the new progression
    # item only through the site's ordinary reoccupation cooldown/refill.
    for i in range(game.inventory_entries.size()-1,-1,-1):
        if str(game.inventory_entries[i].get("id",""))==qitem:
            game.inventory_entries.remove_at(i)
    game.container_states = {}
    game.dropped_items = []
    game.high_risk_state = HighRiskMechanics.default_state()
    var qpoi=game.RegionCatalog.poi_by_id(qid)
    var qkeys=game._target_farm_expected_container_keys(qpoi)
    check(qkeys.size()==3,"quarantine migration fixture lost three core caches")
    for key in qkeys:
        game.container_states[str(key)]={"name":"legacy emptied core","loot_table":game._target_farm_profile(qpoi),"grid_w":8,"grid_h":8,"generated_day":5,"refresh_cycle":0,"poi_id":qid,"target_farm":true,"items":[]}
    game.loot_refresh_sites[qid]={"cycle":0,"ready_day":20,"cleared_day":5,"last_refresh_day":0}
    game.world_day=20
    check(game._prepare_target_farm_site(qpoi),"legacy emptied core did not perform ordinary cooldown refill")
    var strategic_after_refresh=0
    for key in qkeys:
        strategic_after_refresh += _count(game.container_states[str(key)].get("items",[]),qitem)
    check(strategic_after_refresh==1,"reoccupation did not introduce exactly one missing strategic item")
    check(HighRiskMechanics.strategic_spawned(game.high_risk_state,qid),"reoccupation did not persist strategic source spent bit")
    for key in qkeys:
        game.container_states[str(key)]["items"]=[]
    game._target_farm_schedule_if_cleared(qid)
    var next_ready=int(game._target_farm_site_state(qid).get("ready_day",0))
    game.world_day=next_ready
    check(game._prepare_target_farm_site(qpoi),"post-migration second reoccupation did not run")
    var strategic_second_refresh=0
    for key in qkeys:
        strategic_second_refresh += _count(game.container_states[str(key)].get("items",[]),qitem)
    check(strategic_second_refresh==0,"strategic migration item became renewable on later High Risk cycles")

    # The common contract board exposes projects; personal boards never do.
    var packed=load("res://main.tscn")
    check(packed!=null,"main scene failed to load")
    var main=packed.instantiate()
    root.add_child(main)
    await process_frame
    await process_frame
    main.faction_state=main.FactionEconomy.default_state()
    main.faction_state["factions"]["perron"]["reputation"]=75
    main._open_contract_board("perron","Диспетчер","perron_dispatcher")
    await process_frame
    check(main.contract_project_button.visible,"common settlement board hides strategic project button")
    check(bool(main._contract_toggle_project_mode()),"common board could not enter strategic project mode")
    check(main.contract_project_mode,"strategic project mode flag missing")
    check(main.contract_title.text.find("СТРАТЕГИЧЕСКИЙ ПРОЕКТ")>=0,"strategic project title missing")
    check(main.contract_status.text.find("защищённый остаток склада")>=0,"project UI does not explain protected warehouse reserve")
    check(main.contract_project_install_button.visible and main.contract_project_commit_button.visible,"project action buttons not visible")
    check(main.contract_status.get_visible_line_count() == main.contract_status.get_line_count(),"project status text is vertically clipped")
    check(main.contract_status.position.y + main.contract_status.size.y < main.contract_project_install_button.position.y,"project status overlaps bottom action buttons")
    var pspec=main.SettlementProjects.project("perron")
    var pitem=str(pspec.get("strategic_item",""))
    check(main._grid_add(main.inventory_entries,pitem,1,main.INV_W,main.INV_H)==0,"could not add strategic item to UI fixture inventory")
    for r in main.SettlementProjects.RESOURCE_KEYS:
        main.faction_state["factions"]["perron"]["resources"][r]=100.0
    var ui_rep_before=main.FactionEconomy.reputation(main.faction_state,"perron")
    check(bool(main._settlement_project_install_item()),"project UI failed to hand over strategic node")
    check(main._inventory_count(pitem)==0,"project UI did not consume handed-over strategic item")
    var project_guard=0
    while not main.SettlementProjects.is_completed(main.faction_state,"perron") and project_guard<10:
        check(bool(main._settlement_project_commit_resources()),"project UI warehouse contribution stalled")
        project_guard+=1
    check(main.SettlementProjects.is_completed(main.faction_state,"perron"),"project UI could not complete project")
    check(main.FactionEconomy.reputation(main.faction_state,"perron")==ui_rep_before+int(pspec.get("completion_reputation",0)),"project UI completion reward missing/duplicated")
    check(main.contract_status.text.find("ЗАВЕРШЁН")>=0,"completed project UI did not show terminal state")
    check(main.contract_status.get_visible_line_count() == main.contract_status.get_line_count(),"completed project status text is vertically clipped")
    check(main.contract_status.position.y + main.contract_status.size.y < main.contract_project_install_button.position.y,"completed project status overlaps action buttons")
    var project_news=false
    for row in main.WorldChronicle.entries(main.faction_state,32,false):
        if str(row.get("kind",""))=="project" and str(row.get("text",""))==str(pspec.get("completion_news","")):
            project_news=true
            break
    check(project_news,"project completion did not enter world chronicle")
    main._close_contract_board()
    main._open_contract_board("perron","Лёнька","perron_radio")
    await process_frame
    check(not main.contract_project_button.visible,"personal NPC board exposes settlement strategic project")
    check(not bool(main._contract_toggle_project_mode()),"personal board entered strategic project mode")

    main.queue_free()
    game.queue_free()
    await process_frame
    print("STRATEGIC PROJECTS RUNTIME 1.23-dev6: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
