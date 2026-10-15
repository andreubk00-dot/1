extends SceneTree
# dev65: the raiders' base «Чёрный двор». The layout stands on its own ground
# (no other site touches it), every authored piece finds its place, nothing
# overlaps, lanes, the gate and the breach stay passable, every stash and guard
# post is on free floor; the garrison spawns, holds its posts, raises the alarm,
# sends the reserve, the boss falls with his kit, the base is cleared, saved,
# and taken back after a few days; the Artel's contract is paid for it.
const Main = preload("res://main_script_mod.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const FSC = preload("res://world/faction_settlement_catalog.gd")
const MarauderBase = preload("res://world/marauder_base.gd")
const ContractSystem = preload("res://world/contract_system.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")

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

func _static_rects(node: Node, out: Array, skip_walls: bool, owner_tag = null) -> void:
    for child in node.get_children():
        if skip_walls and child.has_meta("settlement_wall"):
            continue
        var tag = owner_tag
        if child.has_meta("settlement_piece_kind") or child.has_meta("world_building"):
            tag = child
        if child is StaticBody2D:
            for shape_node in child.get_children():
                if shape_node is CollisionShape2D and shape_node.shape is RectangleShape2D:
                    var size = shape_node.shape.size
                    out.append({"rect": Rect2(shape_node.global_position - size * 0.5, size), "owner": tag})
        _static_rects(child, out, skip_walls, tag)

func _hits(rects: Array, area: Rect2) -> Variant:
    for r in rects:
        if r["rect"].intersects(area):
            return r["rect"]
    return null

func run():
    # ---------------------------------------------------------- catalog --
    var poi = RegionCatalog.poi_by_id("marauder_base")
    check(not poi.is_empty(), "base POI missing")
    var anchor: Vector2i = poi.get("coord", Vector2i.ZERO)
    var fp = PoiCatalog.footprint("marauder_base")
    check(fp.size() == 9, "base must be 3x3 sectors")
    for off in fp:
        var c = anchor + off
        check(str(RegionCatalog.poi_for_chunk(c).get("id", "")) == "marauder_base", "base sector not owned by the base " + str(c))
        # nothing else on or next to the base
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                var n = RegionCatalog.poi_for_chunk(c + Vector2i(dx, dy))
                check(n.is_empty() or str(n.get("id", "")) == "marauder_base", "another site touches the base at " + str(c + Vector2i(dx, dy)) + ": " + str(n.get("id", "")))
        var cell = PoiCatalog.cell("marauder_base", off)
        check(not bool(cell.get("safe_settlement", true)), "the base is not a safe settlement")
        check(int(cell.get("enemy_count", 1)) == 0, "no infected spawn inside the base")
    var gate = FSC.base_perimeter(Vector2i(-1, 0))
    check(gate.get("w", false) is bool and gate["w"], "west gate missing")
    check(typeof(FSC.base_perimeter(Vector2i(0, 1)).get("s")) == TYPE_DICTIONARY, "south breach missing")
    var stash_rules = 0
    for row in ContractCatalog.templates_for_faction("mechanics"):
        if str(row.get("kind", "")) == "clear_poi" and str(row.get("poi_id", "")) == "marauder_base":
            stash_rules += 1
    check(stash_rules == 1, "the Artel offers no contract for the base")

    var game = Main.new()
    root.add_child(game)
    await frames(6)
    game.developer_invulnerable = true
    for e in game.get_tree().get_nodes_in_group("infected"):
        e.queue_free()
    check(game.loot_tables.has("marauder_supply") and game.loot_tables.has("marauder_stash"), "base loot tables missing")
    check(game._target_farm_refresh_days(RegionCatalog.poi_by_id("marauder_base")) == 5, "base stash refresh is not 5 days")
    check(not game._target_farm_expected_container_keys(RegionCatalog.poi_by_id("marauder_base")).is_empty(), "base has no stash containers")

    # -------------------------------------------------------- layout --
    var models = {}
    var kinds = {}
    for off in fp:
        var coord = anchor + off
        var cell = PoiCatalog.cell("marauder_base", off)
        if game.loaded_chunks.has(coord):
            game._unload_chunk(coord)
            await process_frame
        game._load_chunk(coord)
        await physics_frame
        var chunk = game.loaded_chunks.get(coord)
        check(is_instance_valid(chunk), "base chunk failed " + str(off))
        if not is_instance_valid(chunk):
            continue
        var tag = "base " + str(off)
        check(bool(chunk.get_meta("marauder_base", false)), tag + " dressing missing")
        var skipped = chunk.get_meta("settlement_pieces_skipped", [])
        check(skipped.is_empty(), tag + " could not place " + str(skipped))
        for node in chunk.get_children():
            if node.has_meta("settlement_piece_kind"):
                kinds[str(node.get_meta("settlement_piece_kind"))] = true
            if node.has_meta("world_building"):
                models[str(node.get_meta("settlement_model", ""))] = true
        for spec in cell.get("buildings", []):
            var block = cell["blocks"][spec["block"]]
            var brect = Rect2(spec["pos"] - spec["size"] * 0.5, spec["size"])
            check(block["rect"].encloses(brect), tag + " building leaves its block: " + str(spec["sign"]))
            for other in cell.get("buildings", []):
                if other != spec:
                    check(not brect.intersects(Rect2(other["pos"] - other["size"] * 0.5, other["size"])), tag + " buildings overlap: " + str(spec["sign"]))
        var origin = chunk.global_position
        var inner = []
        _static_rects(chunk, inner, true)
        var all_rects = []
        _static_rects(chunk, all_rects, false)
        var lane = _hits(inner, Rect2(origin + Vector2(352, 40), Vector2(64, 688)))
        check(lane == null, tag + " north-south lane blocked by " + str(lane))
        lane = _hits(inner, Rect2(origin + Vector2(40, 352), Vector2(688, 64)))
        check(lane == null, tag + " west-east lane blocked by " + str(lane))
        if off == Vector2i(-1, 0):
            var g = _hits(all_rects, Rect2(origin + Vector2(0, 352), Vector2(80, 64)))
            check(g == null, "west gate blocked by " + str(g))
        if off == Vector2i(0, 1):
            var b = _hits(all_rects, Rect2(origin + Vector2(FSC.BASE_BREACH_X - 14.0, 690), Vector2(28, 78)))
            check(b == null, "the breach is not passable: " + str(b))
        # set pieces never stand in each other or in a building
        for i in range(all_rects.size()):
            var a = all_rects[i]
            if a["owner"] == null or not a["owner"].has_meta("settlement_piece_kind"):
                continue
            for j in range(all_rects.size()):
                var b2 = all_rects[j]
                if j == i or b2["owner"] == a["owner"]:
                    continue
                var inter = a["rect"].intersection(b2["rect"])
                if a["rect"].intersects(b2["rect"]) and inter.get_area() > 6.0:
                    check(false, tag + " piece %s overlaps %s" % [a["owner"].get_meta("settlement_piece_kind"), (b2["owner"].get_meta("settlement_piece_kind", "building") if b2["owner"] != null else "wall")])
        # containers stand on free floor and apart
        var spots = []
        for n in game.get_tree().get_nodes_in_group("interactable"):
            if not is_instance_valid(n) or n.get_parent() != chunk or str(n.get_meta("interaction_type", "")) != "container":
                continue
            var p = n.global_position
            var c = _hits(all_rects, Rect2(p - Vector2(3, 3), Vector2(6, 6)))
            check(c == null, tag + " container in a solid: " + str(n.get_meta("container_key", "")))
            for s in spots:
                check(s.distance_to(p) > 14.0, tag + " containers on top of each other")
            spots.append(p)
        for loose in cell.get("loose_containers", []):
            var lp = origin + loose["pos"]
            check(_hits(all_rects, Rect2(lp - Vector2(10, 10), Vector2(20, 20))) == null, tag + " stash boxed in: " + str(loose["name"]))
        # the rail bed stays clear of clutter
        for r in cell.get("keep_clear", []):
            for node in chunk.get_children():
                if node.has_meta("settlement_piece_kind") and not str(node.get_meta("settlement_piece_kind")).begins_with("poi:"):
                    check(not r.has_point(node.position), tag + " clutter on the rail bed: " + str(node.get_meta("settlement_piece_kind")))
        # guard posts and patrol points on free floor
        for p in MarauderBase.POSTS:
            if p["cell"] == off:
                var at = origin + p["pos"]
                var hit = _hits(all_rects, Rect2(at - Vector2(9, 9), Vector2(18, 18)))
                check(hit == null, "post %s stands in a solid %s" % [p["id"], str(hit)])
        for pt in MarauderBase.PATROLS:
            for raw in pt["route"]:
                if raw[0] == off:
                    var at2 = origin + raw[1]
                    check(_hits(all_rects, Rect2(at2 - Vector2(9, 9), Vector2(18, 18))) == null, "patrol point of %s in a solid at %s" % [pt["id"], str(raw[1])])
        if MarauderBase.RESERVE_DOOR[0] == off:
            var dp = origin + MarauderBase.RESERVE_DOOR[1]
            check(_hits(all_rects, Rect2(dp - Vector2(16, 9), Vector2(32, 18))) == null, "barracks door blocked")
        game._unload_chunk(coord)
        await process_frame
    check(models.size() >= 8, "the base needs >=8 distinct building models, got " + str(models.size()))
    check(kinds.size() >= 14, "the base needs >=14 distinct structures, got " + str(kinds.size()))
    for k in ["searchlight_tower", "poi:boxcar", "poi:tank_wagon", "bonfire", "radio_mast", "btr"]:
        check(kinds.has(k), "base missing signature structure " + k)

    # ------------------------------------------------------ garrison --
    var base = game.marauder_base
    check(base != null, "no base garrison node")
    game.world_minutes = 12.0 * 60.0
    game.player.global_position = base.world_pos(Vector2i(0, 0), Vector2(384, 384))
    game._refresh_chunks(true)
    await frames(30)
    var men = base.members()
    check(men.size() >= 18, "garrison too thin: " + str(men.size()))
    for m in men:
        check(base._free_at(m.global_position), "garrison member inside geometry: " + m.post_id)
        check(base.contains(m.global_position), "garrison member outside the walls: " + m.post_id)
    var boss = null
    for m in men:
        if m.post_id == "boss":
            boss = m
    check(boss != null and boss.hostile_to_player and boss.max_hp >= 250.0, "the boss is missing or harmless")
    # veterans: steadier, in vests; the boss sits in his office at the back of the HQ
    for m in men:
        check(m.aim_bonus > 0.0 and m.armor_mult < 1.0 and m.settle_time < 4.0, "garrison member is not a veteran: " + m.post_id)
    if boss != null:
        check(boss.armor_mult <= 0.6, "the boss wears no armor")
        var office = base.world_pos(Vector2i(1, 1), Vector2(232, 222))
        check(boss.global_position.distance_to(office) < 20.0, "the boss is not in his office")

    # sentries keep to their posts even in a fight
    var sentry = null
    for m in men:
        if m.post_id == "gate_n":
            sentry = m
    check(sentry != null, "gate sentry missing")
    if sentry != null:
        var post = sentry.get_meta("post_pos")
        sentry.last_seen_pos = post + Vector2(-900, 0)
        sentry.last_seen_time = Time.get_ticks_msec() / 1000.0 - 1.0
        sentry._set_state("combat")
        await frames(150)
        check(sentry.global_position.distance_to(post) <= sentry.leash + 12.0, "gate sentry left his post: " + str(sentry.global_position.distance_to(post)))

    # the alarm: siren, the men near come to look, the reserve follows
    var camp = []
    for m in base.members():
        if m.post_id.begins_with("camp"):
            camp.append(m)
            m._set_state("patrol")
    var gate_pos = base.world_pos(Vector2i(-1, 0), Vector2(200, 384))
    if sentry != null:
        sentry.squad.alert(sentry, gate_pos)
    check(base.alarm_active(), "alarm did not sound")
    check(base.siren.playing, "siren silent")
    base.reserve_t = 0.05
    await frames(12)
    check(base.groups.has("reserve") and base.groups["reserve"].alive().size() == MarauderBase.RESERVE_PER_DAY, "the barracks sent no reserve")
    var used = int(base.state["reserve_used"])
    base.reserve_t = 0.05
    await frames(4)
    check(int(base.state["reserve_used"]) == used, "the reserve came twice in a day")

    # the boss falls with his kit; the Artel's contract becomes ready
    check(not game._contract_known_sites().has("cleared:marauder_base"), "contract ready before the boss died")
    if boss != null and is_instance_valid(boss):
        game._damage_enemy(boss, 2000.0, Vector2.RIGHT)
    await frames(90)
    check(int(base.state["boss_dead_day"]) == game.world_day, "the boss' death was not recorded")
    var boss_body = game.player_bodies.filter(func(b): return str(b.get("name", "")) == "ГЛАВАРЬ «СЕДОЙ»")
    check(boss_body.size() == 1, "no body for the boss")
    if boss_body.size() == 1:
        var key = "%d:%d:container:%s" % [boss_body[0]["coord"][0], boss_body[0]["coord"][1], boss_body[0]["id"]]
        var ids = game.container_states.get(key, {}).get("items", []).map(func(e): return str(e.get("id", "")))
        check("akm_extmag" in ids and "trauma_kit" in ids, "the boss' kit is not on his body: " + str(ids))
    check(game._contract_known_sites().has("cleared:marauder_base"), "boss dead but the contract is not ready")
    var contract = ContractCatalog.template("mechanics_black_yard")
    check(ContractSystem.can_complete(contract, {}, game._contract_known_sites()), "clear_poi contract cannot complete")

    # wipe the garrison: the base is cleared and stays empty
    for id in base.garrison_ids():
        if not base.state["dead"].has(id):
            base.state["dead"][id] = game.world_day
    base._check_cleared()
    check(base.is_cleared(), "a broken garrison does not clear the base")
    for g in base.groups.keys():
        base._free_group(g)
    await frames(4)
    base.tick_t = 0.0
    await frames(4)
    check(base.members().is_empty(), "a cleared base still has a garrison")
    check(base.strength() == 0.0, "cleared base strength not zero")

    # saved and loaded: still cleared
    game._save_state()
    var g2 = Main.new()
    root.add_child(g2)
    await frames(5)
    check(g2.marauder_base.is_cleared(), "the cleared base was not saved")
    check(int(g2.marauder_base.state["boss_dead_day"]) >= 0, "the boss came back after a reload")
    g2.queue_free()
    await frames(2)

    # five days later new men take it back
    game.world_day += MarauderBase.RECLAIM_DAYS
    base.tick_t = 0.0
    await frames(40)
    check(not base.is_cleared() and base.strength() == 1.0, "the base was not taken back")
    check(base.members().size() >= 10, "no new garrison after the reclaim")

    # a standing base presses the roads and robs the Artel once it is known
    check(base.roaming_pressure(base.center()) > 1.0, "a standing base does not press the roads")
    game.discovered_pois["marauder_base"] = true
    base.state["last_raid_day"] = -99
    base.state["reserve_day"] = -1
    base._daily()
    check(int(base.state["last_raid_day"]) == game.world_day, "no raid on the Artel's road")
    # cleared: the roads thin out
    base.state["cleared_day"] = game.world_day
    check(base.roaming_pressure(base.center()) < 1.0, "a cleared base still presses the roads")
    base.state["cleared_day"] = -1

    # the map marks the base as a danger once known
    game.discovered_pois["marauder_base"] = true
    game.region_map_center = anchor
    var snap = game._region_map_snapshot() if game.has_method("_region_map_snapshot") else {}
    if not snap.is_empty():
        var marks = snap.get("pois", []).filter(func(p): return str(p.get("name", "")) == "ЧЁРНЫЙ ДВОР")
        check(marks.size() == 1 and str(marks[0].get("symbol", "")) == "danger", "the base is not marked as a danger on the map")

    print("MARAUDER BASE dev65: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
