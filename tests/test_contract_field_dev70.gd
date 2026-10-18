extends SceneTree
# dev70: three new contract kinds (docs/CONTRACTS_DEV70.md).
#   retrieve - a cache with the sealed parcel appears at the site while the
#              contract is active; taking the parcel marks it, handing it in
#              removes it and pays; afterwards nothing is left behind
#   hunt     - a named special infected with ×2.2 health haunts the site; its
#              death marks the contract; it does not come back
#   raiders  - a hostile squad is set down when the survivor nears the site;
#              broken (dead, surrendered, running) marks it; a squad sent away
#              whole is set down again
# Progress survives a save; an abandoned contract takes its traces with it.
const Main = preload("res://main_script_mod.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")
const ContractSystem = preload("res://world/contract_system.gd")
const ContractField = preload("res://world/contract_field.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

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

func activate(game, template_id: String) -> Dictionary:
    var t = ContractCatalog.template(template_id)
    var inst = ContractSystem._new_instance(game.faction_state, t, game.world_day)
    inst["accepted_day"] = game.world_day
    game.faction_state["contracts"]["active"][inst["id"]] = inst
    return inst

func go_near(game, contract: Dictionary, offset: Vector2) -> void:
    var coord = ContractField.site_coord(contract)
    game.player.global_position = Vector2(coord) * game.CHUNK_SIZE + Vector2(384, 384) + offset
    game._refresh_chunks(true)
    await frames(4)
    game.contract_field.tick()
    await frames(2)

func run():
    # --- the catalogue -------------------------------------------------------
    var kinds = {"retrieve": 0, "hunt": 0, "raiders": 0}
    var factions = {}
    for id in ContractCatalog.TEMPLATES.keys():
        var t = ContractCatalog.template(id)
        var k = str(t.get("kind", ""))
        if not kinds.has(k):
            continue
        kinds[k] += 1
        factions[str(t["faction"])] = true
        check(not RegionCatalog.poi_by_id(str(t.get("poi_id", ""))).is_empty(), "%s points at no site" % id)
        check(str(t.get("hint", "")).length() > 30 and str(t.get("description", "")).length() > 30, "%s has no proper text" % id)
        check(int(t.get("reward", {}).get("tickets", 0)) > 0, "%s pays nothing" % id)
        if k == "retrieve":
            check(str(t.get("parcel_name", "")) != "" and str(t.get("cache_name", "")) != "", "%s: no parcel or cache name" % id)
        if k == "hunt":
            check(str(t.get("target_kind", "")) in ["brute", "screamer", "spitter", "armored", "runner", "carrier"], "%s hunts an unknown kind" % id)
        if k == "raiders":
            check(int(t.get("squad_type", -1)) in [0, 2, 4], "%s sends a squad that is not hostile" % id)
    for k in kinds.keys():
        check(kinds[k] >= 3, "too few %s contracts: %d" % [k, kinds[k]])
    check(factions.size() == 4, "not every settlement offers the new work: " + str(factions.keys()))

    var game = Main.new()
    root.add_child(game)
    await frames(8)
    game.developer_invulnerable = true
    check(game.contract_field != null, "no contract field")
    check(game.item_defs.has(ContractSystem.PARCEL_ITEM) and game._make_item_icon(ContractSystem.PARCEL_ITEM) != null and game._make_world_loot_texture(ContractSystem.PARCEL_ITEM) != null, "the parcel is not a complete item")
    check(str(game.item_defs[ContractSystem.PARCEL_ITEM]["category"]) == "strategic", "the parcel can be sold or broken down")

    # --- the boards: field work has its own slot, routes keep theirs ---------
    for fid in ["perron", "rubezh", "mechanics", "lazaret"]:
        game.FactionEconomy.add_reputation(game.faction_state, fid, 40)
    ContractSystem.refresh_offers(game.faction_state, game.world_day, true)
    for fid in ["perron", "rubezh", "mechanics", "lazaret"]:
        var offers = ContractSystem.offers_for_faction(game.faction_state, fid, game.world_day)
        var field = offers.filter(func(o): return str(o.get("kind", "")) in ContractSystem.FIELD_KINDS).size()
        var classic = offers.size() - field
        check(field == 1, "%s offers %d field contracts" % [fid, field])
        check(classic >= 1 and classic <= ContractSystem.OFFER_SLOTS_PER_FACTION, "%s lost its deliveries and scouting: %d" % [fid, classic])

    # --- retrieve ------------------------------------------------------------
    var rc = activate(game, "perron_dacha_parcel")
    var rid = str(rc["id"])
    var coord = ContractField.site_coord(rc)
    var key = "%d:%d:container:%s" % [coord.x, coord.y, ContractField.cache_id(rc)]
    check(not game.container_states.has(key), "the cache existed before the contract")
    await go_near(game, rc, Vector2(-250, 0))
    var cache = null
    for n in game.get_tree().get_nodes_in_group("interactable"):
        if str(n.get_meta("contract_id", "")) == rid:
            cache = n
    check(cache != null, "no cache at the site")
    if cache != null:
        check(game.marauder_director._free_at(cache.global_position), "the cache stands in a wall")
        check(str(cache.get_meta("interaction_type", "")) == "container", "the cache cannot be opened")
    var items = game.container_states.get(key, {}).get("items", [])
    check(items.size() == 1 and str(items[0]["id"]) == ContractSystem.PARCEL_ITEM, "the cache does not hold the parcel: " + str(items))
    check(not game._contract_is_ready(rc), "a retrieve contract is ready before anything was taken")
    check(ContractSystem.progress_text(rc, game._contract_inventory_counts(), game._contract_known_sites()).find("на месте") >= 0, "progress does not say the parcel is still there")
    # take it
    game.container_states[key]["items"] = []
    game._grid_add(game.inventory_entries, ContractSystem.PARCEL_ITEM, 1, game.INV_W, game.INV_H)
    game.contract_field.tick()
    check(game.contract_field.is_done(rid), "taking the parcel did not count")
    check(game._contract_is_ready(rc), "carrying the parcel is not ready to hand in")
    # hand it in through the board
    var tickets0 = int(game.faction_state.get("tickets", 0))
    game.contract_open = true
    game.contract_project_mode = false
    game.selected_contract_source = "active"
    game.selected_contract_id = rid
    var done = game._contract_complete_selected()
    check(done, "the board would not take the parcel: " + str(game.contract_status.text))
    check(game._inventory_count(ContractSystem.PARCEL_ITEM) == 0, "the parcel stayed in the pack")
    check(not game.faction_state["contracts"]["active"].has(rid), "the contract stayed active")
    game.contract_open = false
    game.contract_field.tick()
    check(not game.contract_field.state().has(rid), "the finished contract left its trace in the save")

    # --- hunt ---------------------------------------------------------------
    var hc = activate(game, "lazaret_hospital_spitter")
    var hid = str(hc["id"])
    await go_near(game, hc, Vector2(0, 0))
    var target = null
    for e in game.get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e) and str(e.get_meta("contract_id", "")) == hid:
            target = e
    check(target != null, "no hunted infected at the site")
    if target != null:
        check(str(target.get_meta("infected_kind", "")) == "spitter", "the wrong kind is hunted")
        check(float(target.get_meta("hp", 0.0)) > 100.0, "the hunted one is no tougher than any other")
        check(target.global_position.distance_to(game.player.global_position) >= ContractField.SPAWN_CLEAR_OF_PLAYER * 0.9 or not game.marauder_director._free_at(game.player.global_position), "the hunted one appeared beside the survivor")
        game._damage_enemy(target, 99999.0, Vector2.RIGHT)
        await frames(2)
    check(game.contract_field.is_done(hid), "the kill did not count")
    check(game._contract_is_ready(hc), "a done hunt is not ready to hand in")
    # it does not come back
    game.player.global_position = Vector2(60, 60) * game.CHUNK_SIZE
    game._refresh_chunks(true)
    await frames(3)
    await go_near(game, hc, Vector2(0, 0))
    var again = 0
    for e in game.get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e) and str(e.get_meta("contract_id", "")) == hid:
            again += 1
    check(again == 0, "the hunted one came back")

    # --- raiders -------------------------------------------------------------
    var qc = activate(game, "rubezh_police_raiders")
    var qid = str(qc["id"])
    await go_near(game, qc, Vector2(-700, 0))
    await frames(2)
    game.contract_field.tick()
    var sq = game.contract_field._squads.get(qid, null)
    check(sq != null and sq.members.size() >= 2, "no squad at the site")
    if sq != null:
        for m in sq.members:
            check(game.marauder_director._free_at(m.global_position), "a raider stands in a wall")
            check(m.global_position.distance_to(game.player.global_position) >= 250.0, "the squad appeared beside the survivor")
        # sent away whole: not done, set down again on the way back
        game.marauder_director._remove(sq)
        game.contract_field.tick()
        check(not game.contract_field.is_done(qid), "a squad sent away whole counted as broken")
        await frames(2)
        game.contract_field.tick()
        sq = game.contract_field._squads.get(qid, null)
        check(sq != null and sq in game.marauder_director.squads, "the squad was not set down again")
    if sq != null:
        for m in sq.members:
            if is_instance_valid(m):
                game._damage_enemy(m, 500.0, Vector2.RIGHT)
        await frames(10)
        game.contract_field.tick()
        await frames(80)
        game.contract_field.tick()
    check(game.contract_field.is_done(qid), "breaking the squad did not count")
    check(game._contract_is_ready(qc), "a broken squad is not ready to hand in")

    # --- saved; abandoned work leaves no trace -------------------------------
    game._save_state()
    var g2 = Main.new()
    root.add_child(g2)
    await frames(6)
    check(g2.contract_field.is_done(hid) and g2.contract_field.is_done(qid), "contract progress lost on reload")
    check(g2._contract_is_ready(g2.faction_state["contracts"]["active"][hid]), "a done hunt is not ready after reload")
    g2.queue_free()
    await frames(2)
    var ac = activate(game, "mechanics_depot_crate")
    var aid = str(ac["id"])
    game.contract_field.state()[aid] = {"done": false}
    ContractSystem.abandon(game.faction_state, aid, game.world_day)
    game.contract_field.tick()
    check(not game.contract_field.state().has(aid), "an abandoned contract left its trace")

    print("CONTRACT FIELD dev70: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
