extends SceneTree
# dev72: the crowbar and locked places (docs/LOCKS_DEV72.md).
# - the crowbar is a full melee weapon: item, stats, icons, held like the pipe,
#   found, sold, broken down; it hits
# - about one door in six and one cache in seven of the ordinary town is
#   locked; never near the start; a door that already existed never locks
# - a locked door: pried with the crowbar (a beat, some noise) or shouldered
#   in (stamina, a lot of noise); too tired - refused
# - a locked cache: only the crowbar; it holds a second helping
# - stepping away breaks the work off; raiders kick locks in, a neutral cannot
# - saved
const Main = preload("res://main_script_mod.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", msg)

func _initialize():
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func secs(t: float) -> void:
    await create_timer(t).timeout

func give(game, id: String, qty: int = 1) -> void:
    game._grid_add(game.inventory_entries, id, qty, game.INV_W, game.INV_H)

func drop_all(game, id: String) -> void:
    for i in range(game.inventory_entries.size() - 1, -1, -1):
        if str(game.inventory_entries[i]["id"]) == id:
            game.inventory_entries.remove_at(i)

const SAMPLE = [Vector2i(4, 0), Vector2i(-4, 1), Vector2i(0, 5), Vector2i(5, -4), Vector2i(-5, -3), Vector2i(3, 6), Vector2i(-6, 4), Vector2i(6, 3), Vector2i(1, -6), Vector2i(-3, 7), Vector2i(7, -1), Vector2i(-7, -6)]

func loaded_locked_door(game):
    # a locked door in a loaded sector, loading the sample sectors one by one
    for coord in [null] + SAMPLE:
        if coord != null:
            game.player.global_position = Vector2(coord) * game.CHUNK_SIZE + Vector2(384, 384)
            game._refresh_chunks(true)
            await frames(2)
        for k in game.locked_doors.keys():
            var d = door_node(game, k)
            if d != null:
                return [k, d]
    return ["", null]

func door_node(game, key: String):
    for d in game.get_tree().get_nodes_in_group("doors"):
        if is_instance_valid(d) and str(d.get_meta("door_key", "")) == key:
            return d
    return null

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(8)
    game.developer_invulnerable = true
    for e in game.get_tree().get_nodes_in_group("infected"):
        e.queue_free()

    # --- the crowbar ------------------------------------------------------------
    check(game.item_defs.has("crowbar") and str(game.item_defs["crowbar"]["category"]) == "melee", "no crowbar item")
    check(game.melee_defs.has("crowbar"), "no crowbar stats")
    var cb = game.melee_defs["crowbar"]
    var pipe = game.melee_defs["steel_pipe"]
    check(float(cb["damage"]) < float(pipe["damage"]) and float(cb["stagger"]) > float(pipe["stagger"]), "the crowbar is not the softer, staggering bar")
    check(game._make_item_icon("crowbar") != null and game._make_world_loot_texture("crowbar") != null, "the crowbar has no icon or ground art")
    check(game._melee_model_texture("crowbar") != null and game._hud_display_texture("crowbar") != null, "the crowbar has no model")
    check(game._melee_model_texture("crowbar").region.position.y == 96.0, "the crowbar shows another weapon's model")
    check(game._melee_is_two_handed("crowbar") and game._melee_look("crowbar") == "steel_pipe", "the crowbar is not held like the pipe")
    var tables = 0
    for t in game.loot_tables.keys():
        for rule in game.loot_tables[t]:
            if str(rule.get("id", "")) == "crowbar":
                tables += 1
    check(tables >= 4, "the crowbar is hardly found: %d tables" % tables)
    check(TraderCatalog.stock_spec("mechanics_parts", "crowbar").size() > 0 and TraderCatalog.accepts_item("mechanics_parts", "crowbar"), "the Artel neither sells nor buys crowbars")
    check(int(game._salvage_outputs("crowbar").get("scrap", 0)) > 0, "a crowbar cannot be broken down")
    give(game, "crowbar")
    game.equipped_melee_id = "crowbar"
    check(game._modern_survivor_firearm_variant_prefix() == "pipe_", "the survivor does not hold the crowbar as a bar")
    var target = Node2D.new()
    game.add_child(target)

    # --- where locks are ---------------------------------------------------------
    var doors = 0
    var locked = 0
    var caches = 0
    var locked_caches = 0
    var near_start_locks = 0
    for coord in SAMPLE:
        game.player.global_position = Vector2(coord) * game.CHUNK_SIZE + Vector2(384, 384)
        game._refresh_chunks(true)
        await frames(2)
    for k in game.door_states.keys():
        var parts = str(k).split(":")
        var c = Vector2i(int(parts[0]), int(parts[1]))
        if not str(parts[3]).begins_with("building_"):
            continue
        if max(abs(c.x), abs(c.y)) <= 2:
            near_start_locks += int(game.locked_doors.has(k))
            continue
        if not game._lock_allowed_here(c):
            continue
        doors += 1
        locked += int(game.locked_doors.has(k))
    for k in game.container_states.keys():
        if str(k).find(":container:cache_") < 0:
            continue
        var parts = str(k).split(":")
        var c = Vector2i(int(parts[0]), int(parts[1]))
        if max(abs(c.x), abs(c.y)) <= 2:
            near_start_locks += int(game._container_locked(k))
            continue
        caches += 1
        locked_caches += int(game._container_locked(k))
    check(doors > 30 and caches > 30, "too few buildings sampled: %d doors %d caches" % [doors, caches])
    var dr = float(locked) / max(1, doors)
    var cr = float(locked_caches) / max(1, caches)
    check(dr > 0.06 and dr < 0.30, "locked door share off: %d/%d" % [locked, doors])
    check(cr > 0.04 and cr < 0.28, "locked cache share off: %d/%d" % [locked_caches, caches])
    check(near_start_locks == 0, "something is locked near the start")

    # --- a locked door: crowbar ----------------------------------------------------
    var found = await loaded_locked_door(game)
    var lk = str(found[0])
    check(lk != "", "no locked door loaded to test")
    var dn = found[1]
    if dn != null:
        game.player.global_position = dn.global_position + Vector2(0, 30)
        game._update_hud()
        game._toggle_door(dn)
        check(not game.lock_work.is_empty() and str(game.lock_work["tool"]) == "crowbar", "the crowbar was not used")
        check(not bool(game.door_states.get(lk, false)), "the door opened at once")
        await secs(game.LOCK_PRY_DOOR + 0.4)
        check(game.lock_work.is_empty() and not game.locked_doors.has(lk) and bool(game.door_states.get(lk, false)), "the pried door did not open")

    # --- a locked door: shoulder, and too tired ---------------------------------------
    drop_all(game, "crowbar")
    game.equipped_melee_id = ""
    var found2 = await loaded_locked_door(game)
    var lk2 = str(found2[0])
    var dn2 = found2[1]
    if dn2 != null:
        game.player.global_position = dn2.global_position + Vector2(0, 30)
        game.developer_invulnerable = false
        game.stamina = 10.0
        game._toggle_door(dn2)
        check(game.lock_work.is_empty() and game.locked_doors.has(lk2), "a spent survivor shouldered a door in")
        game.stamina = 100.0
        game._toggle_door(dn2)
        check(str(game.lock_work.get("tool", "")) == "shoulder", "no shouldering without a crowbar")
        # stepping away breaks it off
        game.player.global_position += Vector2(0, 80)
        await frames(3)
        check(game.lock_work.is_empty() and game.locked_doors.has(lk2), "walking off did not break the work off")
        game.player.global_position = dn2.global_position + Vector2(0, 30)
        game._toggle_door(dn2)
        await secs(0.7)
        check(not game.locked_doors.has(lk2) and bool(game.door_states.get(lk2, false)), "the door was not shouldered in")
        check(game.stamina <= 100.0 - game.LOCK_SHOULDER_STAMINA + 5.0, "shouldering cost no stamina")
        game.developer_invulnerable = true
    else:
        check(false, "no second locked door to shoulder")

    # --- a locked cache ------------------------------------------------------------
    var ck = ""
    for k in game.container_states.keys():
        if game._container_locked(k):
            ck = k
            break
    check(ck != "", "no locked cache to test")
    if ck != "":
        var plain = []
        for k in game.container_states.keys():
            if str(k).find(":container:cache_") >= 0 and not game._container_locked(k) and str(game.container_states[k].get("loot_table", "")) == str(game.container_states[ck].get("loot_table", "")):
                plain.append(game.container_states[k].get("items", []).size())
        var avg = 0.0
        for n in plain:
            avg += n
        avg /= max(1, plain.size())
        check(float(game.container_states[ck].get("items", []).size()) >= avg, "a locked cache holds no more than an open one")
        game._open_container(ck)
        check(not game.inventory_open and game._container_locked(ck), "a locked cache opened without a crowbar")
        give(game, "crowbar")
        var cnode = null
        for n in game.get_tree().get_nodes_in_group("interactable"):
            if str(n.get_meta("container_key", "")) == ck:
                cnode = n
        if cnode != null:
            game.player.global_position = cnode.global_position + Vector2(0, 20)
        game._open_container(ck)
        await secs(game.LOCK_PRY_CACHE + 0.4)
        check(not game._container_locked(ck), "the crowbar did not open the cache")
        game._close_inventory()

    # --- raiders --------------------------------------------------------------------
    var found3 = await loaded_locked_door(game)
    var rk = str(found3[0])
    if rk != "":
        var rn = found3[1]
        check(not game._npc_open_door(rn, rn.global_position + Vector2(0, 30), false), "a calm raider walked through a lock")
        check(game._npc_open_door(rn, rn.global_position + Vector2(0, 30), true) and not game.locked_doors.has(rk), "a kicked-in lock stayed")

    # --- a door that already existed never locks ----------------------------------------
    var fresh = Vector2i(12, -9)
    for b in range(8):
        game.door_states["%d:%d:door:building_%d" % [fresh.x, fresh.y, b]] = false
    game.player.global_position = Vector2(fresh) * game.CHUNK_SIZE + Vector2(384, 384)
    game._refresh_chunks(true)
    await frames(2)
    var new_locks = 0
    for b in range(8):
        new_locks += int(game.locked_doors.has("%d:%d:door:building_%d" % [fresh.x, fresh.y, b]))
    check(new_locks == 0, "a door from before the update became locked")

    # --- saved ---------------------------------------------------------------------------
    var still = game.locked_doors.keys()
    game._save_state()
    var g2 = Main.new()
    root.add_child(g2)
    await frames(5)
    check(g2.locked_doors.size() == still.size(), "locks lost on reload")
    if ck != "":
        check(not g2._container_locked(ck), "a forced cache locked itself again")
    g2.queue_free()
    await frames(2)

    print("CROWBAR LOCKS dev72: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
