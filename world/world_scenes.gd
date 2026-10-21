extends Node
# dev71: the six new world scenes (docs/SCENES_DEV71.md) - building them into
# a sector, what the survivor can do there, and what the world remembers.
# State: game.world_scene_state = {"x,y": state}; containers and infected use
# the game's own persistence keys.

const SceneCatalog = preload("res://world/scene_catalog.gd")
const EncounterCatalog = preload("res://world/encounter_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const StoryDialog = preload("res://world/story_dialog.gd")

const CAMP_NEAR = 760.0
const TICK = 0.5

var game = null
var _t = 0.0
var _camps = {}          # "x,y" -> squad
var _told = {}           # "x,y" -> true once the survivor called out


func _init():
    name = "WorldScenes"


static func key(coord:Vector2i) -> String:
    return "%d,%d" % [coord.x, coord.y]


func state_of(coord:Vector2i) -> String:
    return str(game.world_scene_state.get(key(coord), ""))


func set_state(coord:Vector2i, value:String) -> void:
    game.world_scene_state[key(coord)] = value


# ------------------------------------------------------------------ build --
func build(chunk, coord:Vector2i, profile:Dictionary, scene:Dictionary) -> bool:
    if scene.is_empty() or game._chunk_has_player_base(coord):
        return false
    var center = game._world_event_anchor(chunk, scene, coord)
    if center.x < -9000.0:
        return false
    var id = str(scene.get("id", ""))
    var zone = str(profile.get("zone", "residential"))
    var risk = int(profile.get("risk", 2))
    var root = Node2D.new()
    root.name = "WorldScene_%s" % id
    root.position = center
    root.z_index = 5
    root.z_as_relative = false
    # the same footprint contract as the old scenes: trees, pumps, cars and
    # street art step round it
    root.set_meta("world_event_root", true)
    root.set_meta("world_event_id", id)
    root.set_meta("world_scene", true)
    root.set_meta("world_event_label", str(scene.get("label", id)))
    root.set_meta("world_event_footprint", scene.get("footprint", Vector2(140, 96)))
    root.add_to_group("world_events")
    chunk.add_child(root)
    chunk.set_meta("world_event_id", id)
    chunk.set_meta("world_event_label", str(scene.get("label", id)))
    var flip = EncounterCatalog._hash(coord, 83) % 2 == 0
    var spawn_base = 1100 + (EncounterCatalog._hash(coord, 101) % 200) * 10
    var st = state_of(coord)
    match id:
        "trapped_survivor":
            # a saloon, not a burnt shell: the HD lada picks its paint from its
            # position (_settlement_piece), so nudge it onto a painted one
            var car_off = Vector2(0, -6)
            for dx in range(6):
                var cp = (center + Vector2(dx, -6)).round()
                if int(abs(cp.x * 7.0 + cp.y * 13.0)) % 5 >= 2:
                    car_off = Vector2(dx, -6)
                    break
            _piece(chunk, center, {"kind":"burnt_car", "pos":car_off, "solid":Vector2(70, 24), "scale":0.5})
            game._event_prop(root, "blood_smear", Vector2(-40, 20), 0.5, 1)
            game._event_prop(root, "shattered_glass", Vector2(30, 18), 0.45, 1)
            game._event_prop(root, "traffic_cone", Vector2(-62, -22), 0.46, 4)
            if st == "":
                _interactable(root, Vector2(0, 14), "survivor", "ГОВОРИТЬ  •  ВЫЖИВШИЙ В МАШИНЕ", coord)
            var offs = [Vector2(-52, -30), Vector2(56, -26), Vector2(-10, 44)]
            for i in range(3):
                game._spawn_world_event_enemy(chunk, coord, spawn_base + i, center + offs[i], "normal")
        "bait_ambush":
            game._event_prop(root, "blood_pool_large", Vector2(-6, 10), 0.5, 1)
            game._event_prop(root, "road_barrier", Vector2(-58, -24), 0.52, 4)
            game._event_prop(root, "newspapers_wide", Vector2(36, -20), 0.42, 2)
            var bait = SceneCatalog.SCENES[id]
            var loot = str(bait.get("loot_by_zone", {}).get(zone, bait.get("loot", "garage")))
            var node = game._create_container(chunk, coord, center + Vector2(4, 6), "scene_bait", loot, "Ящик посреди дороги")
            if node != null:
                node.set_meta("scene_bait", key(coord))
            var clue = SceneCatalog.BAIT_CLUE.duplicate(true)
            clue["id"] = "scene_bait_%s" % key(coord)
            clue["pos"] = Vector2(-48 if flip else 50, 30)
            game._create_environmental_story_clue(root, clue)
        "abandoned_checkpoint":
            _piece(chunk, center, {"kind":"poi:guard_booth", "pos":Vector2(-56, -10), "solid":Vector2(30, 18), "flip":flip})
            _piece(chunk, center, {"kind":"poi:boom_barrier", "pos":Vector2(24, -22), "solid":Vector2(0, 0), "flip":flip})
            game._event_prop(root, "sandbags", Vector2(48, 20), 0.6, 4)
            game._event_prop(root, "sandbags", Vector2(-20, 26), 0.55, 4)
            game._event_prop(root, "road_sign", Vector2(70, -30), 0.5, 4)
            var cp = SceneCatalog.SCENES[id]
            var cp_loot = str(cp.get("loot_by_zone", {}).get(zone, cp.get("loot", "police")))
            if game._loot_profile_risk(cp_loot) <= risk:
                game._create_container(chunk, coord, center + Vector2(10, 40), "scene_checkpoint", cp_loot, "Ящик блокпоста")
            var note = SceneCatalog.CHECKPOINT_NOTE.duplicate(true)
            note["id"] = "scene_checkpoint_order"
            note["pos"] = Vector2(-34, 6)
            game._create_environmental_story_clue(root, note)
            if st != "radio_used":
                _interactable(root, Vector2(-74, 8), "radio", "ПОЛЕВАЯ РАЦИЯ  •  ПОСЛУШАТЬ", coord)
            var kinds = ["normal", "normal", "armored"]
            var cp_offs = [Vector2(-90, -40), Vector2(84, -36), Vector2(0, 60)]
            for i in range(3):
                game._spawn_world_event_enemy(chunk, coord, spawn_base + i, center + cp_offs[i], kinds[i])
        "pharmacy_van":
            _piece(chunk, center, {"kind":"ambulance", "pos":Vector2(4, -10), "solid":Vector2(64, 24), "scale":0.5, "flip":flip})
            game._event_prop(root, "med_supply_stack", Vector2(-46, 22), 0.48, 4)
            game._event_prop(root, "stretcher", Vector2(50, 24), 0.5, 4)
            game._event_prop(root, "blood_smear", Vector2(10, 26), 0.5, 1)
            game._create_container(chunk, coord, center + Vector2(-12, 34), "scene_van", "pharmacy", "Кузов «буханки»")
            var van_kinds = ["normal", "normal", "carrier"]
            var van_offs = [Vector2(-80, -36), Vector2(78, -30), Vector2(20, 58)]
            for i in range(3):
                game._spawn_world_event_enemy(chunk, coord, spawn_base + i, center + van_offs[i], van_kinds[i])
        "living_camp":
            _piece(chunk, center, {"kind":"bonfire", "pos":Vector2(0, 6), "solid":Vector2(20, 10), "scale":0.4})
            _piece(chunk, center, {"kind":"tarp_shelter", "pos":Vector2(-44, -24), "solid":Vector2(44, 18), "scale":0.45, "flip":flip})
            game._event_prop(root, "old_mattress", Vector2(42, -18), 0.5, 3)
            game._event_prop(root, "gas_can", Vector2(52, 20), 0.42, 4)
            game._event_prop(root, "folded_blanket", Vector2(-30, 28), 0.44, 3)
        "burn_pit":
            _piece(chunk, center, {"kind":"rubble_pile", "pos":Vector2(0, -4), "solid":Vector2(40, 16), "scale":0.45})
            game._event_prop(root, "body_bag", Vector2(-44, 18), 0.5, 3)
            game._event_prop(root, "body_bag", Vector2(36, 24), 0.5, 3)
            game._event_prop(root, "blood_pool_large", Vector2(4, 6), 0.46, 1)
            var pit = SceneCatalog.PIT_NOTE.duplicate(true)
            pit["id"] = "scene_pit_list"
            pit["pos"] = Vector2(-20, 36)
            game._create_environmental_story_clue(root, pit)
            _interactable(root, Vector2(48, -14), "pit_radio", "РАДИОПРИЁМНИК  •  ПОСЛУШАТЬ", coord)
            var pit_kinds = ["normal", "screamer" if risk >= 3 else "normal"]
            var pit_offs = [Vector2(-82, -34), Vector2(80, -38)]
            for i in range(2):
                game._spawn_world_event_enemy(chunk, coord, spawn_base + i, center + pit_offs[i], pit_kinds[i])
    return true


func _piece(chunk, center:Vector2, piece:Dictionary):
    # big pieces (vehicles, booths, fires) are placed in the sector's own
    # space, as settlements place them; they go with the sector when it unloads
    var p = piece.duplicate()
    p["pos"] = center + Vector2(piece.get("pos", Vector2.ZERO))
    var node = game._settlement_piece(chunk, p)
    if node != null:
        node.set_meta("world_scene_piece", true)
    return node


func _interactable(root:Node2D, pos:Vector2, action:String, prompt:String, coord:Vector2i) -> Node2D:
    var n = Node2D.new()
    n.name = "Scene_%s" % action
    n.position = pos
    n.z_index = 8
    n.z_as_relative = false
    n.add_to_group("interactable")
    n.set_meta("interaction_type", "world_scene")
    n.set_meta("interaction_radius", 64.0)
    n.set_meta("scene_action", action)
    n.set_meta("scene_prompt", prompt)
    n.set_meta("scene_coord", coord)
    n.set_meta("display_name", prompt)
    root.add_child(n)
    if action in ["radio", "pit_radio"]:
        game._world_prop_sprite("electrical_box", n, Vector2.ZERO, 0, 0.32)
    return n


# --------------------------------------------------------------- actions --
func interact(target:Node) -> void:
    var coord:Vector2i = target.get_meta("scene_coord", Vector2i.ZERO)
    match str(target.get_meta("scene_action", "")):
        "survivor":
            _survivor(target, coord)
        "radio":
            _patrol_radio(target, coord)
        "pit_radio":
            _pit_radio(coord)


func _infected_near(pos:Vector2, radius:float) -> int:
    var n = 0
    for e in game.get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e) and float(e.get_meta("hp", 1.0)) > 0.0 and e.global_position.distance_to(pos) < radius:
            n += 1
    return n


func nearest_settlement(from:Vector2) -> Dictionary:
    var best = {}
    var bd = INF
    for poi in RegionCatalog.POIS:
        if str(poi.get("kind", "")) != "faction_settlement":
            continue
        var p = Vector2(poi.get("coord", Vector2i.ZERO)) * game.CHUNK_SIZE
        var d = p.distance_to(from)
        if d < bd:
            bd = d
            best = poi
    return best


func _survivor(target:Node, coord:Vector2i) -> void:
    if state_of(coord) != "":
        return
    if _infected_near(target.global_position, 230.0) > 0:
        game._set_survival_feedback("Из машины, шёпотом: «Они ещё здесь... Убери их — тогда открою».", 3.2)
        return
    var who = SceneCatalog.survivor(coord)
    var town = nearest_settlement(target.global_position)
    var town_name = str(town.get("short_name", "людям"))
    var faction = str(town.get("faction", ""))
    if game.hud_interaction_panel != null:
        game.hud_interaction_panel.visible = false
    var dialog = StoryDialog.new()
    game.get_tree().root.add_child(dialog)
    dialog.open("ВЫЖИВШИЙ В МАШИНЕ", str(who["who"]).to_upper(), str(who["line"]) % town_name, [
        ["ОТПУСТИТЬ", func(): resolve_survivor(coord, "freed", faction, town_name, target)],
        ["ЗАБРАТЬ РЮКЗАК", func(): resolve_survivor(coord, "robbed", faction, town_name, target)],
        ["УЙТИ", func(): pass],
    ])


func resolve_survivor(coord:Vector2i, outcome:String, faction:String, town_name:String, target:Node) -> void:
    if state_of(coord) != "":
        return
    set_state(coord, outcome)
    var items = SceneCatalog.survivor_gift(coord)
    if outcome == "robbed":
        items += SceneCatalog.SURVIVOR_BAG_EXTRA.duplicate(true)
    for it in items:
        game._grid_add(game.inventory_entries, str(it["id"]), int(it["qty"]), game.INV_W, game.INV_H)
    if faction != "":
        FactionEconomy.add_reputation(game.faction_state, faction, 3 if outcome == "freed" else -5)
    var news = ""
    if outcome == "freed":
        news = "До %s дошёл человек, просидевший трое суток в машине. Говорит, кто-то разогнал заражённых и отпустил его." % town_name
        game._set_survival_feedback("Выживший ушёл к %s. Это запомнят." % town_name, 3.4)
    else:
        news = "До %s дошёл человек без вещей: его выпустили из машины — и забрали рюкзак." % town_name
        game._set_survival_feedback("Вы забрали рюкзак. Он ушёл к %s с пустыми руками — и расскажет." % town_name, 3.6)
    game._record_world_news("world", faction, news, game.world_day, int(game.world_minutes), false)
    if is_instance_valid(target):
        target.queue_free()
    if game.has_method("_refresh_inventory_ui"):
        game._refresh_inventory_ui()


func _patrol_radio(target:Node, coord:Vector2i) -> void:
    if state_of(coord) == "radio_used":
        return
    set_state(coord, "radio_used")
    # the nearest site the survivor has not found yet
    var here = target.global_position
    var best = {}
    var bd = INF
    for poi in RegionCatalog.POIS:
        var pid = str(poi.get("id", ""))
        if pid == "" or game.discovered_pois.has(pid) or str(poi.get("kind", "")) == "faction_settlement":
            continue
        var d = (Vector2(poi.get("coord", Vector2i.ZERO)) * game.CHUNK_SIZE).distance_to(here)
        if d < bd:
            bd = d
            best = poi
    if best.is_empty():
        game._set_survival_feedback("Рация шипит. Никто больше не выходит на связь.", 3.0)
    else:
        game.discovered_pois[str(best["id"])] = true
        game._set_survival_feedback("Сквозь треск — чужой патруль: «...у %s чисто не будет, обходите...» Отмечено на карте." % str(best.get("short_name", best.get("name", "объекта"))), 4.6)
        if game.has_method("_refresh_region_map_ui"):
            game._refresh_region_map_ui()
    if is_instance_valid(target):
        target.queue_free()


func _pit_radio(coord:Vector2i) -> void:
    var choice = str(game.story_ether.get("choice", ""))
    game._set_survival_feedback("РАДИОПРИЁМНИК\n" + SceneCatalog.pit_radio(choice), 5.0)
    if state_of(coord) == "":
        set_state(coord, "heard")


func on_container_opened(container_key:String) -> void:
    # the bait: open the crate and the ones who were waiting stand up
    if container_key.find(":container:scene_bait") < 0:
        return
    var parts = container_key.split(":")
    var coord = Vector2i(int(parts[0]), int(parts[1]))
    if state_of(coord) == "sprung":
        return
    set_state(coord, "sprung")
    var dir = game.marauder_director
    if dir == null:
        return
    var t = 0 if EncounterCatalog._hash(coord, 263) % 2 == 0 else 2
    var spot = _cover_spot(coord)
    if spot == Vector2.INF:
        return
    var sq = dir.spawn_squad(dir.SQUAD_TYPES[t], spot)
    if sq == null:
        return
    for m in sq.members:
        m.awareness = 1.0 if "awareness" in m else 0.0
        m.facing = (game.player.global_position - m.global_position).normalized()
        if m.has_method("_set_state"):
            m._set_state("combat")
    game._set_survival_feedback("«Ну, здравствуй». Из-за укрытия поднимаются люди с оружием.", 3.2)


func _cover_spot(coord:Vector2i) -> Vector2:
    var rng = RandomNumberGenerator.new()
    rng.seed = hash("bait" + key(coord))
    var p0 = game.player.global_position
    for i in range(60):
        var p = p0 + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(170.0, 240.0)
        if game.marauder_director._free_at(p):
            return p
    return Vector2.INF


# ------------------------------------------------------------------ tick --
func _physics_process(delta:float) -> void:
    if game == null or game.player == null or game.player_death_time > 0.0:
        return
    _t -= delta
    if _t > 0.0:
        return
    _t = TICK
    tick()


func tick() -> void:
    for root in game.get_tree().get_nodes_in_group("world_events"):
        if not is_instance_valid(root) or not bool(root.get_meta("world_scene", false)):
            continue
        var coord = game._world_to_chunk(root.global_position)
        var d = root.global_position.distance_to(game.player.global_position)
        match str(root.get_meta("world_event_id", "")):
            "trapped_survivor":
                if state_of(coord) == "" and d < 300.0 and not _told.has(key(coord)):
                    _told[key(coord)] = true
                    game._set_survival_feedback("Из машины кто-то стучит в стекло: «Эй! Помогите!»", 3.0)
            "living_camp":
                _tend_camp(root, coord, d)


func _tend_camp(root:Node2D, coord:Vector2i, d:float) -> void:
    var k = key(coord)
    var dir = game.marauder_director
    if state_of(coord) == "camp_dead" or dir == null:
        _camps.erase(k)
        return
    var sq = _camps.get(k, null)
    if sq != null and not (sq in dir.squads):
        # sent away by the director, or fallen: count the dead
        if _all_dead(sq):
            set_state(coord, "camp_dead")
        _camps.erase(k)
        sq = null
    if sq == null:
        if d > CAMP_NEAR:
            return
        var spot = root.global_position + Vector2(0, 30)
        if not dir._free_at(spot):
            spot = root.global_position + Vector2(30, 34)
        var t = 3 if EncounterCatalog._hash(coord, 271) % 2 == 0 else 5
        sq = dir.spawn_squad(dir.SQUAD_TYPES[t], spot)
        if sq == null:
            return
        sq.route = [spot]
        sq.leg = 0
        sq.set_meta("scene_camp", k)
        _camps[k] = sq
        return
    if _all_dead(sq):
        set_state(coord, "camp_dead")
        _camps.erase(k)


func _all_dead(sq) -> bool:
    var seen = sq.get_meta("dead_seen", {})
    var all = true
    for m in sq.members:
        if is_instance_valid(m):
            seen[str(m.get_instance_id())] = m.dead
            if not m.dead:
                all = false
    sq.set_meta("dead_seen", seen)
    if seen.size() < sq.members.size():
        return false
    for v in seen.values():
        if not v:
            return false
    return all
