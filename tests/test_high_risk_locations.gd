extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const BuildingCatalog = preload("res://world/building_catalog.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func _loot_odds(table:Array) -> Dictionary:
    var out = {}
    for rec in table:
        out[str(rec.get("id",""))] = float(rec.get("chance",0.0))
    return out

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var dungeon_specs = {
        "quarantine_center_12":{
            "anchor":Vector2i(-6,-5),"kind":"quarantine_dungeon","loot":"quarantine_core","core":Vector2i(2,1),"entry":Vector2i(0,0)
        },
        "reserve_arsenal_bastion":{
            "anchor":Vector2i(4,5),"kind":"arsenal_dungeon","loot":"arsenal_core","core":Vector2i(2,1),"entry":Vector2i(0,0)
        }
    }

    # World placement: high-risk compounds are large, authored and do not overlap any existing POI.
    var occupied = {}
    for poi in RegionCatalog.POIS:
        var id = str(poi.get("id",""))
        var anchor:Vector2i = poi.get("coord",Vector2i(9999,9999))
        for offset in poi.get("footprint",[Vector2i.ZERO]):
            var c = anchor + offset
            var key = "%d:%d" % [c.x,c.y]
            check(not occupied.has(key), "POI overlap at " + key + " between " + id + " and " + str(occupied.get(key,"")))
            occupied[key] = id

    for id in dungeon_specs.keys():
        var spec = dungeon_specs[id]
        var poi = RegionCatalog.poi_for_chunk(spec["anchor"])
        check(str(poi.get("id","")) == id, id + " anchor lookup failed")
        check(str(poi.get("kind","")) == spec["kind"], id + " kind mismatch")
        check(int(poi.get("risk",0)) == 5, id + " must be risk 5")
        check(bool(poi.get("high_risk",false)), id + " missing high_risk flag")
        check(int(poi.get("dungeon_tier",0)) == 1, id + " dungeon tier mismatch")
        check(str(poi.get("loot","")) == spec["loot"], id + " core loot profile mismatch")
        check(poi.get("hard_requirements",["bad"]).is_empty(), id + " must not hard-gate entry behind dungeon loot")
        check(not poi.has("readiness"), id + " should not carry explicit readiness instructions")
        check(PoiCatalog.has_compound(id), id + " authored compound missing")
        var fp = PoiCatalog.footprint(id)
        check(fp.size() == 6, id + " should span six sectors")

        var danger_counts = {"high_perimeter":0,"high_interior":0,"high_core":0}
        var total_enemies = 0
        var rotated_fence_found = false
        for off in fp:
            var cell = PoiCatalog.cell(id,off)
            check(not cell.is_empty(), id + " missing cell " + str(off))
            check(str(cell.get("role","")).strip_edges() != "", id + " cell role missing " + str(off))
            check(int(cell.get("enemy_count",0)) >= 6, id + " cell is not high-density enough " + str(off))
            var ep = str(cell.get("enemy_profile",""))
            check(danger_counts.has(ep), id + " invalid encounter profile " + ep)
            if danger_counts.has(ep):
                danger_counts[ep] += 1
            total_enemies += int(cell.get("enemy_count",0))
            var seen = {}
            for b in cell.get("buildings",[]):
                var cid = str(b.get("container_id",""))
                check(cid != "" and not seen.has(cid), id + " duplicate/missing building container id in " + str(off))
                seen[cid] = true
                check(not BuildingCatalog.by_id(str(b.get("archetype",""))).is_empty(), id + " missing building archetype")
            for loose in cell.get("loose_containers",[]):
                var cid = str(loose.get("id",""))
                check(cid != "" and not seen.has(cid), id + " loose container id collision in " + str(off))
                seen[cid] = true
            for fence in cell.get("fences",[]):
                if abs(float(fence.get("rotation",0.0))) > 0.1:
                    rotated_fence_found = true
        check(total_enemies >= 48, id + " total authored threat too low for dungeon scale")
        check(danger_counts["high_perimeter"] >= 2, id + " lacks recoverable perimeter sectors")
        check(danger_counts["high_interior"] >= 2, id + " lacks escalating interior sectors")
        check(danger_counts["high_core"] == 1, id + " must have exactly one hardest core sector")
        check(rotated_fence_found, id + " lacks rotated chokepoint fencing")

        var entry_cell = PoiCatalog.cell(id,spec["entry"])
        var core_cell = PoiCatalog.cell(id,spec["core"])
        check(str(entry_cell.get("enemy_profile","")) == "high_perimeter", id + " entry should be difficult but recoverable")
        check(str(core_cell.get("enemy_profile","")) == "high_core", id + " deep core should carry hardest encounter mix")
        check(int(core_cell.get("enemy_count",0)) > int(entry_cell.get("enemy_count",0)), id + " threat must escalate toward core")
        var entry_has_core_loot = false
        for b in entry_cell.get("buildings",[]):
            entry_has_core_loot = entry_has_core_loot or str(b.get("loot","")) == spec["loot"]
        for c in entry_cell.get("loose_containers",[]):
            entry_has_core_loot = entry_has_core_loot or str(c.get("loot","")) == spec["loot"]
        check(not entry_has_core_loot, id + " top reward leaks to perimeter")
        var core_loot_count = 0
        for b in core_cell.get("buildings",[]):
            if str(b.get("loot","")) == spec["loot"]:
                core_loot_count += 1
        for c in core_cell.get("loose_containers",[]):
            if str(c.get("loot","")) == spec["loot"]:
                core_loot_count += 1
        check(core_loot_count >= 2, id + " deep core does not concentrate rewards")

        # Production builder must accept every authored sector, including rotated barriers.
        for off in fp:
            var coord:Vector2i = spec["anchor"] + off
            var chunk = Node2D.new()
            game.add_child(chunk)
            var profile = game._chunk_profile(coord)
            check(game._build_major_poi_chunk(chunk,coord,profile), id + " production build failed at " + str(coord))
            check(chunk.get_child_count() > 0, id + " production build empty at " + str(coord))
            chunk.queue_free()

    # Full production generation must apply authored enemy counts/profiles and POI risk, not just render the compound.
    for id in dungeon_specs.keys():
        var spec = dungeon_specs[id]
        var core_coord:Vector2i = spec["anchor"] + spec["core"]
        var profile = game._chunk_profile(core_coord)
        check(int(profile.get("risk",0)) == 5, id + " chunk profile did not inherit POI risk 5")
        check(str(profile.get("loot_theme","")) == spec["loot"], id + " chunk profile did not inherit POI loot theme")
        var prod_chunk = Node2D.new()
        prod_chunk.name = "Prod_%s" % id
        prod_chunk.position = Vector2(core_coord.x * game.CHUNK_SIZE,core_coord.y * game.CHUNK_SIZE)
        game.add_child(prod_chunk)
        game._build_procedural_chunk(prod_chunk,core_coord)
        var infected_count = 0
        var special_count = 0
        for child in prod_chunk.get_children():
            if child.has_meta("infected_kind"):
                infected_count += 1
                if str(child.get_meta("infected_kind","normal")) != "normal":
                    special_count += 1
        var authored_core = PoiCatalog.cell(id,spec["core"])
        check(infected_count == int(authored_core.get("enemy_count",0)), id + " production enemy count ignored authored core count")
        check(special_count > 0, id + " production core did not spawn dangerous infected")
        prod_chunk.queue_free()

    # Reward curve: dungeon cores are materially better target-farming sources, not a new stat multiplier.
    check(game.loot_tables.has("quarantine_core"), "quarantine core loot table missing")
    check(game.loot_tables.has("arsenal_core"), "arsenal core loot table missing")
    check(game._loot_profile_risk("quarantine_core") == 5 and game._loot_profile_risk("arsenal_core") == 5, "dungeon core loot must be risk 5")
    var med = _loot_odds(game.loot_tables.get("medical_secure",[]))
    var qcore = _loot_odds(game.loot_tables.get("quarantine_core",[]))
    check(float(qcore.get("trauma_kit",0.0)) > float(med.get("trauma_kit",0.0)), "quarantine core must improve trauma-kit odds")
    check(float(qcore.get("antibiotics",0.0)) > float(med.get("antibiotics",0.0)), "quarantine core must improve antibiotics odds")
    var mil = _loot_odds(game.loot_tables.get("military_secure",[]))
    var acore = _loot_odds(game.loot_tables.get("arsenal_core",[]))
    check(float(acore.get("akm",0.0)) > float(mil.get("akm",0.0)), "arsenal core must improve AKM odds")
    check(float(acore.get("military_vest",0.0)) > float(mil.get("military_vest",0.0)), "arsenal core must improve military-vest odds")
    check(float(acore.get("expedition_pack",0.0)) > float(mil.get("expedition_pack",0.0)), "arsenal core must improve expedition-pack odds")
    for profile in ["quarantine_core","arsenal_core"]:
        for rec in game.loot_tables[profile]:
            var item_id = str(rec.get("id",""))
            check(game.item_defs.has(item_id), "unknown dungeon loot item " + item_id)
            if game.item_defs.has(item_id):
                check(game._item_min_loot_risk(item_id) <= 5, "dungeon loot item has impossible risk " + item_id)

    # Combat balance: variants change pressure, not player progression or impossible HP scaling.
    check(game.INFECTED_ARCHETYPES.has("runner") and game.INFECTED_ARCHETYPES.has("brute"), "dangerous infected profiles missing")
    var runner = game.INFECTED_ARCHETYPES["runner"]
    var brute = game.INFECTED_ARCHETYPES["brute"]
    var runner_speed = game.ENEMY_SPEED * float(runner.get("speed_mult",1.0))
    var sprint_speed = game.MOVE_SPEED * game.SPRINT_SPEED_MULT
    check(runner_speed > game.MOVE_SPEED, "runner should force sprint/repositioning")
    check(runner_speed < sprint_speed, "runner must not invalidate a healthy player's sprint")
    check(float(runner.get("hp_mult",1.0)) < 1.0, "runner should pay for speed with lower durability")
    check(float(brute.get("hp_mult",1.0)) <= 1.40, "brute became a bullet sponge")
    check(float(brute.get("speed_mult",1.0)) < 1.0, "brute must trade power for speed")
    check(float(brute.get("damage",0.0)) <= 12.0, "brute hit damage exceeds planned survival balance")
    check(float(brute.get("stagger_mult",1.0)) >= 0.55, "brute stagger resistance is too absolute")

    var enemy_chunk = Node2D.new()
    game.add_child(enemy_chunk)
    var runner_node = game._spawn_enemy(enemy_chunk,Vector2i(-6,-5),100,Vector2(320,360),"runner")
    var brute_node = game._spawn_enemy(enemy_chunk,Vector2i(-6,-5),101,Vector2(380,360),"brute")
    check(str(runner_node.get_meta("infected_kind","")) == "runner", "runner spawn metadata missing")
    check(str(brute_node.get_meta("infected_kind","")) == "brute", "brute spawn metadata missing")
    check(float(runner_node.get_meta("hp",999.0)) < 70.0, "runner HP not reduced")
    check(float(brute_node.get_meta("hp",0.0)) < 105.0, "brute HP exceeds 1.5x normal")
    check(float(brute_node.get_meta("attack_damage",0.0)) == 12.0, "brute damage profile not applied")
    enemy_chunk.queue_free()

    # Deterministic high-core encounter must contain both dangerous roles; ordinary profile remains ordinary.
    var mix_chunk = Node2D.new()
    game.add_child(mix_chunk)
    game._spawn_chunk_enemies(mix_chunk,Vector2i(20,20),24,112024,"high_core")
    var mix = {"normal":0,"runner":0,"brute":0}
    for n in mix_chunk.get_children():
        if n.has_meta("infected_kind"):
            var k = str(n.get_meta("infected_kind","normal"))
            mix[k] = int(mix.get(k,0)) + 1
    check(int(mix["runner"]) > 0 and int(mix["brute"]) > 0, "high-core deterministic mix lacks dangerous infected")
    mix_chunk.queue_free()
    var normal_chunk = Node2D.new()
    game.add_child(normal_chunk)
    game._spawn_chunk_enemies(normal_chunk,Vector2i(21,20),12,112025,"standard")
    var special_in_standard = false
    for n in normal_chunk.get_children():
        if n.has_meta("infected_kind") and str(n.get_meta("infected_kind","normal")) != "normal":
            special_in_standard = true
    check(not special_in_standard, "dangerous infected leaked into standard encounter profile")
    normal_chunk.queue_free()

    # The map may show discovered danger, but must not solve the dungeon or reveal rewards.
    for id in dungeon_specs.keys():
        var anchor:Vector2i = dungeon_specs[id]["anchor"]
        game.discovered_chunks[game._zone_chunk_key(anchor)] = true
        game.discovered_pois[id] = true
        var tip = game._region_map_cell_tooltip(anchor)
        check(tip.find("ОПАСНОСТЬ 5/5") >= 0, id + " map tooltip lacks discovered danger 5")
        check(tip.find("ДАНЖ") < 0 and tip.find("АРСЕНАЛ CORE") < 0 and tip.find("Целевая добыча") < 0, id + " map tooltip reveals dungeon solution/reward")

    game._create_region_map_ui()
    var ui_anchor = Vector2i(4,5)
    game.discovered_chunks[game._zone_chunk_key(ui_anchor)] = true
    game.discovered_pois["reserve_arsenal_bastion"] = true
    game.region_map_selected_chunk = ui_anchor
    game.current_chunk = Vector2i.ZERO
    game._refresh_region_map_ui()
    var map_detail = str(game.region_map_detail_label.text)
    check(map_detail.find("Опасность: 5/5") >= 0, "selected dungeon card uses district risk instead of POI risk")
    check(map_detail.find("БЕЗ ОБЯЗАТЕЛЬНЫХ") < 0, "selected dungeon card explains the solution instead of letting player test it")
    check(map_detail.find("ВНУТРЕННИЙ АРСЕНАЛ") < 0 and map_detail.find("Целевая добыча") < 0, "selected dungeon card reveals target loot")

    # QA crate remains complete; the dungeon stage adds locations, not hidden test-only items.
    var qa_entries = game._generate_loot("qa:112:all","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var qa_ids = {}
    for rec in qa_entries:
        qa_ids[str(rec.get("id",""))] = true
    check(qa_ids.size() == game.item_defs.size(), "QA crate no longer contains complete catalogue")

    game.free()
    print("HIGH RISK LOCATIONS: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
