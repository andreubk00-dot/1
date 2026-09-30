extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var checks = 0
var failures = 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
func _initialize():
    call_deferred("run")
func run():
    var g = Harness.new()
    root.add_child(g)
    g.equipment = {"head":"","body":"military_vest","backpack":"","utility":""}
    g.inventory_entries = [{"id":"military_vest","qty":1,"x":0,"y":0}]
    g.container_states["qa:stash"] = {"items":[]}
    g.active_container_key = "qa:stash"
    g.selected_inventory_index = 0
    g._store_selected_inventory()
    check(g.equipment.body == "military_vest","storing a spare vest must not delete worn vest")
    g.equipment.body = "military_vest"
    g.inventory_entries = [{"id":"military_vest","qty":1,"x":0,"y":0}]
    g.selected_inventory_index = 0
    g._drop_selected_inventory()
    check(g.equipment.body == "military_vest","dropping a spare vest must not delete worn vest")
    g.inventory_entries = [{"id":"makarov","qty":1,"x":0,"y":0}]
    g.current_weapon_id = "makarov"
    g.equipped_melee_id = ""
    g.container_states["qa:stash"]["items"] = []
    check(not g._drag_inventory_to_container(0,0,0),"drag must enforce last-weapon protection")
    g.inventory_entries = []
    g.inventory_open = false
    g.tracer = Line2D.new()
    g.add_child(g.tracer)
    g.muzzle_flash = Polygon2D.new()
    g.add_child(g.muzzle_flash)
    g.weapon_mags.makarov = 8
    g._fire_weapon()
    check(g.weapon_mags.makarov == 8,"cannot fire a gun left in storage")
    g.inventory_entries = [{"id":"ammo_9x18","qty":10,"x":0,"y":0}]
    g.weapon_mags.makarov = 0
    g.reload_weapon_id = "makarov"
    g._finish_reload()
    check(g.weapon_mags.makarov == 0 and g._inventory_count("ammo_9x18") == 10,"reload must not consume ammo for absent gun")
    g.inventory_entries = [{"id":"makarov","qty":1,"x":0,"y":0},{"id":"makarov","qty":1,"x":2,"y":0}]
    check(g._prepare_item_for_drop("makarov"),"spare copy of last weapon can leave inventory")
    g.inventory_entries = []
    g.active_container_key = "qa:loot"
    g.container_states["qa:loot"] = {"items":[{"id":"bandage","qty":1,"x":0,"y":0}]}
    g.selected_container_index = 0
    g._take_selected_container()
    # 1.17.2 progression has no character XP/skill state. Discovery only marks
    # a world container as already inspected; moving your own items cannot create progression.
    var prop_names = {}
    for prop in g.get_property_list():
        prop_names[str(prop.get("name",""))] = true
    check(not prop_names.has("skill_levels") and not prop_names.has("skill_xp"),"legacy XP/skill state is still active")
    check(bool(g.container_states["qa:loot"].get("scavenged",false)),"first container take must mark the container inspected")
    g.selected_inventory_index = 0
    g._store_selected_inventory()
    g.selected_container_index = 0
    g._take_selected_container()
    check(bool(g.container_states["qa:loot"].get("scavenged",false)),"own container transfer must not reset discovery state")

    # Every take control records the same one-time inspection state, without XP rewards.
    for method in ["all","drag"]:
        g.inventory_entries = []
        g.active_container_key = "qa:" + method
        g.container_states[g.active_container_key] = {"items":[{"id":"bandage","qty":1,"x":0,"y":0}]}
        if method == "all":
            g._take_all_container()
        else:
            g._drag_container_to_inventory(0,0,0)
        check(bool(g.container_states[g.active_container_key].get("scavenged",false)),"container inspection not recorded via " + method)
        g.selected_inventory_index = 0
        g._store_selected_inventory()
        if method == "all":
            g._take_all_container()
        else:
            g._drag_container_to_inventory(0,0,0)
        check(bool(g.container_states[g.active_container_key].get("scavenged",false)),"repeat transfer changed discovery state via " + method)

    g.inventory_entries = []
    g.active_container_key = "base_stash_555"
    g.container_states[g.active_container_key] = {"items":[{"id":"bandage","qty":1,"x":0,"y":0}]}
    g._take_all_container()
    check(bool(g.container_states[g.active_container_key].get("scavenged",false)),"home storage should still track inspected state without progression rewards")
    var drop = Node2D.new()
    g.add_child(drop)
    drop.set_meta("item_id","bandage")
    drop.set_meta("qty",1)
    drop.set_meta("drop_id",999)
    g._pickup_world_item(drop)
    check(not prop_names.has("skill_xp"),"personal pickup reintroduced XP state")
    g.inventory_entries = [{"id":"flashlight","qty":1,"x":0,"y":0}]
    g.equipment.utility = "flashlight"
    g.flashlight_on = true
    g.selected_inventory_index = 0
    g._store_selected_inventory()
    check(g.equipment.utility == "flashlight" and g.flashlight_on,"storing spare flashlight preserves worn light")
    var groups = g.SupplyPlan.groups(0)
    check("emergency_ration" in groups[1].ids,"home supplies must recognize emergency ration as ready food")
    # Surviving spawn IDs must keep their variant/position when an earlier enemy died.
    var a = Node2D.new()
    g.add_child(a)
    g._spawn_chunk_enemies(a,Vector2i(5,5),8,12345,"arsenal_core")
    var snapshot = {}
    for e in a.get_children():
        snapshot[int(e.get_meta("spawn_id"))] = [e.position,e.get_meta("infected_kind")]
    a.free()
    g.defeated["5:5:0"] = true
    var b = Node2D.new()
    g.add_child(b)
    g._spawn_chunk_enemies(b,Vector2i(5,5),8,12345,"arsenal_core")
    for e in b.get_children():
        check(snapshot[int(e.get_meta("spawn_id"))] == [e.position,e.get_meta("infected_kind")],"defeated predecessor must not reroll survivor %d" % int(e.get_meta("spawn_id")))
    g.free()
    print("AUDIT REGRESSION: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
