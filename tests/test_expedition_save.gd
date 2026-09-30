extends SceneTree

const Main = preload("res://main_script_mod.gd")
var checks = 0
var failures = 0

func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func same_entries(first,second):
    # JSON numbers load as floats. Compare item data after numeric normalization.
    var a = first.duplicate(true)
    var b = second.duplicate(true)
    for entries in [a,b]:
        for entry in entries:
            for key in ["qty","x","y"]:
                if entry.has(key):
                    entry[key] = int(entry[key])
    return a == b

func _initialize():
    # This integration test writes actual saves. Refuse normal player data.
    var isolated = OS.get_environment("OSTATOK_QA_SAVE_ROOT")
    if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
        printerr("Use a dedicated XDG_DATA_HOME and matching OSTATOK_QA_SAVE_ROOT.")
        quit(2)
        return
    call_deferred("run")

func run():
    var game = Main.new()
    root.add_child(game)
    game.set_process(false)
    game._qa_clear_infected()
    var home = game.roof_records[0]
    game.player.global_position = home["rect"].get_center()
    game.current_chunk = home["chunk_coord"]
    game.expedition_active = false
    game.expedition_journal = game.ExpeditionJournal.empty_state()
    check(game._claim_current_home(),"actual building can be claimed")
    game.region_map_selected_chunk = game.current_chunk + Vector2i(2,0)
    game._plan_selected_expedition()
    game.player.global_position += Vector2(200,0)
    game._update_expedition_progress()
    game.expedition_journal["returning"] = true
    game.base_objects.append({"id":999,"kind":"cot","x":home["rect"].get_center().x,"y":home["rect"].get_center().y})
    game.base_objects.append({"id":1000,"kind":"stash","x":home["rect"].get_center().x,"y":home["rect"].get_center().y})
    game.base_objects.append({"id":1001,"kind":"barricade","x":home["rect"].get_center().x + 20.0,"y":home["rect"].get_center().y,"rot":0.0,"condition":43.0})
    game.base_objects.append({"id":1002,"kind":"bedroll","x":home["rect"].get_center().x - 24.0,"y":home["rect"].get_center().y + 18.0,"rot":0.35})
    game.container_states["base_stash_1000"] = {"name":"Запас","items":[{"id":"water","qty":5,"x":0,"y":0},{"id":"flashlight","qty":1,"x":2,"y":0,"instance_id":"itm_00400001"},{"id":"trauma_kit","qty":2,"x":4,"y":0},{"id":"emergency_ration","qty":3,"x":6,"y":0}]}
    game.container_states["0:0:container:garage_all_items_0163"] = {
        "name":"ТЕСТ: ВСЕ ПРЕДМЕТЫ",
        "loot_table":"all_items_test",
        "grid_w":14,
        "grid_h":8,
        "items":game._generate_loot("0:0:container:garage_all_items_0163","all_items_test",14,8)
    }
    game.expedition_journal["supply_preset"] = 2
    game.shelter_breach_states["qa:defense:window"] = {"kind":"window","condition":83.0,"reinforced":true}
    # Real partial pickup, then disk serialization through the production writer.
    var pack_before_pickup = game.inventory_entries.duplicate(true)
    game.inventory_entries = []
    var cap = int(game.item_defs["bandage"]["stack"])
    for y in range(game.INV_H):
        for x in range(game.INV_W):
            game.inventory_entries.append({"id":"bandage","qty":cap,"x":x,"y":y})
    game.inventory_entries[0]["qty"] -= 2
    var fixed = game._spawn_world_item(game,Vector2i.ZERO,"bandage",5,Vector2(30,30),"qa:partial:fixed",-1)
    game._pickup_world_item(fixed)
    var remainder_id = int(fixed.get_meta("drop_id",-1))
    game.inventory_entries = pack_before_pickup
    fixed.queue_free()
    game.map_markers = {"-3:4":{"kind":"water","label":"Колодец"}}
    # instance firearm persistence: magazines, condition and mods belong to concrete items.
    check(game._grid_add(game.inventory_entries,"tt33",1,game.INV_W,game.INV_H) == 0,"TT fits test inventory")
    check(game._grid_add(game.inventory_entries,"toz34",1,game.INV_W,game.INV_H) == 0,"TOZ fits test inventory")
    check(game._grid_add(game.inventory_entries,"sks",1,game.INV_W,game.INV_H) == 0,"SKS fits test inventory")
    game._ensure_runtime_item_instance_ids()
    game._ensure_weapon_runtime_state(false)
    var tt_iid = game._find_inventory_weapon_instance("tt33")
    var toz_iid = game._find_inventory_weapon_instance("toz34")
    var sks_iid = game._find_inventory_weapon_instance("sks")
    for rec in [["tt33",tt_iid,3,81.5],["toz34",toz_iid,1,63.0],["sks",sks_iid,7,92.25]]:
        game._set_weapon_mag_value(str(rec[0]),int(rec[2]),str(rec[1]))
        var state = game._weapon_instance_state(str(rec[0]),str(rec[1]),true)
        state["condition"] = float(rec[3])
        game.weapon_instance_states[str(rec[1])] = state
    game.current_weapon_id = "sks"
    game.current_weapon_instance_id = sks_iid
    game.quick_slot_ids = ["mosin","aks74u","pps43","combat_knife","steel_pipe","fire_axe"]
    game.rig_quick_ids = ["bandage","emergency_ration"]
    # 1.10 equipment/item persistence uses the unchanged generic equipment/container schema.
    game.equipment = {"head":"ballistic_helmet","body":"military_vest","outerwear":"insulated_parka","rig":"assault_rig","backpack":"expedition_pack","utility":"flashlight"}
    # 1.13 target-farm site schedule is persistent progression state, but old saves
    # without it must still load as an empty dictionary.
    game.loot_refresh_sites["district_police"] = {"cycle":2,"ready_day":17,"cleared_day":11,"last_refresh_day":5}
    game._save_state()
    var data = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
    check(data.get("save_version",0) == 122 and data.has("water_container_states") and data.has("rig_quick_ids") and data.has("quick_slot_ids") and data.has("weapon_instance_states") and data.has("current_weapon_instance_id") and data.has("expedition_journal") and data.has("shelter_breach_states") and data.has("loot_refresh_sites") and data.has("faction_state") and not data.has("shelter_last_report"),"save writer must keep current journal/defense/target-farming/faction schema without obsolete assault-report state")
    check(not data.has("skill_levels") and not data.has("skill_xp"),"save writer must not persist removed character XP/skill state")
    var loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    check(bool(loaded.picked_world_items.get("qa:partial:fixed",false)),"partial fixed spawn remains retired after disk load")
    var disk_remainder = {}
    for rec in loaded.dropped_items:
        if int(rec.get("drop_id",-2)) == remainder_id:
            disk_remainder = rec
    check(int(disk_remainder.get("qty",0)) == 3,"partial ground stack survives disk load without regeneration")
    check(loaded.next_drop_id > remainder_id,"loaded counter cannot reuse remainder identity")
    check(loaded.map_markers == game.map_markers,"personal map markers survive actual disk save/load")
    check(loaded.current_weapon_id == "sks" and loaded.current_weapon_instance_id == sks_iid,"selected firearm instance must survive actual disk save/load")
    check(loaded.quick_slot_ids == game.quick_slot_ids,"custom quickbar loadout must survive actual disk save/load")
    check(loaded.rig_quick_ids == game.rig_quick_ids,"rig quick-pocket bindings must survive actual disk save/load")
    check(loaded._weapon_mag_value("tt33",tt_iid) == 3 and loaded._weapon_mag_value("toz34",toz_iid) == 1 and loaded._weapon_mag_value("sks",sks_iid) == 7,"per-instance firearm magazines must survive actual disk save/load")
    check(abs(loaded._weapon_condition_value("tt33",tt_iid) - 81.5) < 0.001 and abs(loaded._weapon_condition_value("toz34",toz_iid) - 63.0) < 0.001 and abs(loaded._weapon_condition_value("sks",sks_iid) - 92.25) < 0.001,"per-instance firearm condition must survive actual disk save/load")
    check(str(loaded.equipment.get("head","")) == "ballistic_helmet" and str(loaded.equipment.get("body","")) == "military_vest" and str(loaded.equipment.get("outerwear","")) == "insulated_parka" and str(loaded.equipment.get("rig","")) == "assault_rig" and str(loaded.equipment.get("backpack","")) == "expedition_pack","1.19 layered equipment must survive actual disk save/load")
    var loaded_bedroll = false
    for base_rec in loaded.base_objects:
        if int(base_rec.get("id",-1)) == 1002 and str(base_rec.get("kind","")) == "bedroll":
            loaded_bedroll = true
    check(loaded_bedroll,"portable bedroll must survive actual disk save/load")
    var loaded_farm = loaded.loot_refresh_sites.get("district_police",{})
    check(int(loaded_farm.get("cycle",-1)) == 2 and int(loaded_farm.get("ready_day",-1)) == 17 and int(loaded_farm.get("cleared_day",-1)) == 11 and int(loaded_farm.get("last_refresh_day",-1)) == 5,"1.13 target-farm schedule must survive actual disk save/load")
    check(loaded.expedition_active and loaded.expedition_journal["returning"],"actual loader must retain return leg")
    check(loaded.expedition_journal["home"] == game.expedition_journal["home"],"actual loader must retain exact home address")
    check(loaded.expedition_journal["departure"] == game.expedition_journal["departure"],"actual loader must retain baseline")
    check(loaded.get_meta("loaded_player_position") == game.player.global_position,"player position must survive save")
    check(loaded.base_objects.size() == game.base_objects.size(),"base records must survive save")
    var loaded_barrier_condition = -1.0
    for rec in loaded.base_objects:
        if int(rec.get("id",-1)) == 1001:
            loaded_barrier_condition = float(rec.get("condition",-1.0))
    check(abs(loaded_barrier_condition - 43.0) < 0.001,"barricade condition must survive actual disk load")
    check(abs(float(loaded.shelter_breach_states.get("qa:defense:window",{}).get("condition",-1.0)) - 83.0) < 0.001,"window breach condition must survive actual disk load")
    check(bool(loaded.shelter_breach_states.get("qa:defense:window",{}).get("reinforced",false)),"window reinforcement must survive actual disk load")
    check(loaded.expedition_journal["supply_preset"] == 2,"supply preset must survive actual disk load")
    check(loaded.expedition_journal["home"]["bounds"].size() == 4,"home bounds must survive actual disk load")
    check(same_entries(loaded.container_states["base_stash_1000"]["items"],game.container_states["base_stash_1000"]["items"]),"stash quantities and unique item identity must survive disk load")
    var loaded_qa_crate = loaded.container_states.get("0:0:container:garage_all_items_0163",{})
    check(int(loaded_qa_crate.get("grid_w",0)) == loaded.QA_ALL_ITEMS_CONTAINER_W and int(loaded_qa_crate.get("grid_h",0)) == loaded.QA_ALL_ITEMS_CONTAINER_H,"old QA crate must migrate to current all-items dimensions on load")
    var loaded_qa_ids = {}
    for rec in loaded_qa_crate.get("items",[]):
        loaded_qa_ids[str(rec.get("id",""))] = true
    for firearm_id in loaded.FIREARM_IDS:
        check(loaded_qa_ids.has(firearm_id),"saved QA crate lost firearm: " + firearm_id)
    loaded.free()

    # 1.02/1.03 compatibility: obsolete assault-report and furniture raid HP may
    # exist in a save, but the simplified build must ignore them cleanly.
    var old_103 = data.duplicate(true)
    old_103.erase("map_markers")
    old_103["shelter_last_report"] = {"hits":9,"peak_pressure":84.0,"damage":[]}
    for rec in old_103["base_objects"]:
        if int(rec.get("id",-1)) == 1000:
            rec["raid_condition"] = 0.0
    var old_103_file = FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
    old_103_file.store_string(JSON.stringify(old_103))
    old_103_file.close()
    loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    var old_stash_clean = false
    for rec in loaded.base_objects:
        if int(rec.get("id",-1)) == 1000:
            old_stash_clean = not rec.has("raid_condition")
    check(old_stash_clean,"1.03 furniture raid HP must be ignored and stripped on load")
    check(loaded.map_markers.is_empty(),"old saves without map annotations start with no invented notes")
    check(same_entries(loaded.container_states["base_stash_1000"]["items"],game.container_states["base_stash_1000"]["items"]),"1.03 cleanup must retain stash contents")
    loaded.free()

    # 0.96 had barricade durability but no dedicated door/window defense dictionary.
    var old_096 = data.duplicate(true)
    old_096["save_version"] = 96
    old_096.erase("shelter_breach_states")
    var old_096_file = FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
    old_096_file.store_string(JSON.stringify(old_096))
    old_096_file.close()
    loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    check(loaded.shelter_breach_states.is_empty(),"0.96 migration must start new door/window integrity cleanly")
    check(loaded.base_objects.size() == game.base_objects.size(),"0.96 migration must retain existing shelter objects")
    loaded.free()

    game.expedition_target_reached = true
    game.player.global_position = home["rect"].get_center()
    game._update_expedition_progress()
    loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    check(not loaded.expedition_active and loaded.expedition_journal["last_report"]["reached"],"completed report must survive actual disk reload")
    check(loaded.expedition_journal["last_report"] == game.expedition_journal["last_report"],"disk report must preserve quantities and condition")
    loaded.free()

    # 0.93 home identity remains valid without the new optional bounds/preset.
    var old_093 = data.duplicate(true)
    old_093["save_version"] = 93
    old_093["expedition_journal"]["schema"] = 1
    old_093["expedition_journal"].erase("supply_preset")
    old_093["expedition_journal"]["home"].erase("bounds")
    var old_file = FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
    old_file.store_string(JSON.stringify(old_093))
    old_file.close()
    loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    check(loaded._has_home() and loaded.expedition_active,"0.93 migration must retain home and ongoing expedition")
    check(loaded.expedition_journal["supply_preset"] == 0 and loaded.expedition_journal["home"]["bounds"].is_empty(),"0.93 migration must default optional supply fields")
    check(same_entries(loaded.container_states["base_stash_1000"]["items"],game.container_states["base_stash_1000"]["items"]),"0.93 migration must retain actual supplies")
    loaded.free()

    # Real 0.92 schema: no journal key, save_version still 86.
    data.erase("expedition_journal")
    data["save_version"] = 86
    var file = FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()
    loaded = Main.new()
    loaded._load_data()
    loaded._load_state()
    check(loaded.expedition_active and not loaded._has_home(),"0.92 active expedition must survive without invented home")
    check(loaded.expedition_origin_chunk == game._home_chunk(),"0.92 original return sector must survive")
    check(loaded.base_objects.size() == data["base_objects"].size(),"migration must keep old shelter objects")
    check(loaded.inventory_entries.size() == data["inventory_entries"].size(),"migration must keep old inventory")
    loaded.free()
    game.free()
    print("EXPEDITION SAVE INTEGRATION: ",checks," checks, ",failures," failures")
    quit(1 if failures > 0 else 0)
