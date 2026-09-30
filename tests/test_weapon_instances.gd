extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    game.inventory_open = false
    game.reload_time = 0.0
    game.equipped_melee_id = ""
    game.mod_status = Label.new()
    game.add_child(game.mod_status)
    game.inventory_entries = [
        {"id":"makarov","qty":1,"x":0,"y":0},
        {"id":"makarov","qty":1,"x":2,"y":0},
        {"id":"makarov_extmag","qty":1,"x":4,"y":0}
    ]
    game._ensure_runtime_item_instance_ids()
    game._ensure_weapon_runtime_state(false)
    var ids = game._inventory_weapon_instance_ids("makarov")
    check(ids.size() == 2,"two PM copies must receive two instance IDs")
    if ids.size() < 2:
        game.free()
        print("WEAPON INSTANCES: ",checks," checks, ",failures," failures")
        quit(1)
        return

    var a = str(ids[0])
    var b = str(ids[1])
    game._set_weapon_mag_value("makarov",8,a)
    game._set_weapon_mag_value("makarov",2,b)
    var state_a = game._weapon_instance_state("makarov",a,true)
    state_a["condition"] = 90.0
    game.weapon_instance_states[a] = state_a
    var state_b = game._weapon_instance_state("makarov",b,true)
    state_b["condition"] = 40.0
    game.weapon_instance_states[b] = state_b

    check(game._weapon_mag_value("makarov",a) == 8 and game._weapon_mag_value("makarov",b) == 2,"magazines are independent")
    check(abs(game._weapon_condition_value("makarov",a) - 90.0) < 0.001 and abs(game._weapon_condition_value("makarov",b) - 40.0) < 0.001,"condition is independent")

    game._switch_weapon("makarov",a)
    game.fire_cooldown = 0.0
    if game.tracer == null:
        game.tracer = Line2D.new()
        game.add_child(game.tracer)
    if game.muzzle_flash == null:
        game.muzzle_flash = Node2D.new()
        game.add_child(game.muzzle_flash)
    game._fire_weapon()
    check(game._weapon_mag_value("makarov",a) == 7,"firing selected copy consumes its round")
    check(game._weapon_mag_value("makarov",b) == 2,"firing selected copy does not touch spare magazine")
    check(game._weapon_condition_value("makarov",a) < 90.0 and abs(game._weapon_condition_value("makarov",b) - 40.0) < 0.001,"wear applies only to selected copy")

    # Reload is also bound to the concrete selected copy. Switching to an identical
    # sibling cancels it instead of finishing into the wrong magazine.
    check(game._grid_add(game.inventory_entries,"ammo_9x18",2,game.INV_W,game.INV_H) == 0,"reload ammo fits test inventory")
    game._start_reload()
    check(game.reload_weapon_instance_id == a,"reload captures selected firearm instance")
    game._switch_weapon("makarov",b)
    check(game.reload_weapon_instance_id == "" and game._weapon_mag_value("makarov",a) == 7 and game._weapon_mag_value("makarov",b) == 2,"switching identical firearm cancels reload without cross-loading")
    game._switch_weapon("makarov",a)
    game._start_reload()
    game._finish_reload()
    check(game._weapon_mag_value("makarov",a) == 8 and game._weapon_mag_value("makarov",b) == 2,"reload fills only selected firearm instance")
    game._set_weapon_mag_value("makarov",7,a)

    # Workbench service must repair only the chosen concrete firearm.
    check(game._grid_add(game.inventory_entries,"repair_kit",1,game.INV_W,game.INV_H) == 0,"repair kit fits test inventory")
    check(game._grid_add(game.inventory_entries,"scrap",1,game.INV_W,game.INV_H) == 0,"scrap fits test inventory")
    check(game._grid_add(game.inventory_entries,"cloth",1,game.INV_W,game.INV_H) == 0,"cloth fits test inventory")
    var a_before_service = game._weapon_condition_value("makarov",a)
    var b_before_service = game._weapon_condition_value("makarov",b)
    check(game._perform_weapon_service("makarov","maintenance",b),"service accepts selected duplicate")
    check(abs(game._weapon_condition_value("makarov",a) - a_before_service) < 0.001 and game._weapon_condition_value("makarov",b) > b_before_service,"service changes only selected duplicate")

    check(game._install_weapon_mod("makarov","makarov_extmag",a),"module installs on selected copy")
    check(str(game._weapon_mod_state("makarov",a).get("magazine","")) == "makarov_extmag","selected copy keeps installed module")
    check(str(game._weapon_mod_state("makarov",b).get("magazine","")) == "","spare copy does not inherit module")
    check(game._weapon_mag_capacity("makarov",a) > game._weapon_mag_capacity("makarov",b),"module capacity is instance-specific")

    game.container_states["qa:stash"] = {"name":"QA","items":[]}
    game.active_container_key = "qa:stash"
    game.selected_inventory_index = -1
    for i in range(game.inventory_entries.size()):
        if str(game.inventory_entries[i].get("instance_id","")) == a:
            game.selected_inventory_index = i
            break
    game._store_selected_inventory()
    check(game.current_weapon_instance_id == b,"storing active duplicate switches to the other concrete copy")
    check(game._inventory_has_weapon_instance(b,"makarov"),"spare remains in backpack after active copy transfer")
    check(not game._inventory_has_weapon_instance(a,"makarov"),"transferred copy leaves backpack")
    check(game.weapon_instance_states.has(a),"state follows transferred copy outside backpack")
    check(game._weapon_mag_value("makarov",a) == 7 and str(game._weapon_mod_state("makarov",a).get("magazine","")) == "makarov_extmag","transferred copy retains magazine and module state")

    game.selected_container_index = 0
    game._take_selected_container()
    game._ensure_weapon_runtime_state(false)
    check(game._inventory_has_weapon_instance(a,"makarov"),"taking firearm back preserves the same instance ID")
    check(game._weapon_mag_value("makarov",a) == 7,"returned copy keeps its exact magazine")

    # Pre-instance-state migration: one old type-level state must be assigned to exactly one copy.
    game.inventory_entries = [
        {"id":"akm","qty":1,"x":0,"y":0,"instance_id":"itm_90000001"},
        {"id":"akm","qty":1,"x":3,"y":0,"instance_id":"itm_90000002"}
    ]
    game.container_states = {}
    game.dropped_items = []
    game.weapon_instance_states = {}
    game.current_weapon_id = "akm"
    game.current_weapon_instance_id = ""
    game.weapon_mags["akm"] = 12
    game.weapon_condition["akm"] = 72.0
    game.weapon_mods["akm"] = {"magazine":"akm_extmag","muzzle":"muzzle_brake"}
    game._ensure_weapon_runtime_state(true)
    var migrated_ids = game._inventory_weapon_instance_ids("akm")
    var legacy_count = 0
    var clean_count = 0
    for iid in migrated_ids:
        var st = game._weapon_instance_state("akm",str(iid),false)
        if int(st.get("mag",0)) == 12 and abs(float(st.get("condition",0.0)) - 72.0) < 0.001 and str(st.get("mods",{}).get("magazine","")) == "akm_extmag" and str(st.get("mods",{}).get("muzzle","")) == "muzzle_brake":
            legacy_count += 1
        if int(st.get("mag",-1)) == 0 and abs(float(st.get("condition",0.0)) - 100.0) < 0.001 and str(st.get("mods",{}).get("magazine","")) == "" and str(st.get("mods",{}).get("muzzle","")) == "":
            clean_count += 1
    check(legacy_count == 1,"legacy rounds/modules must migrate to one concrete AKM only")
    check(clean_count == 1,"second duplicate must start with clean independent state")

    game.free()
    print("WEAPON INSTANCES: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
