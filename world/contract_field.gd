extends Node
# dev70: what the new contract kinds put into the world (docs/CONTRACTS_DEV70.md).
#   retrieve - a cache with the sealed parcel at the site's central sector
#   hunt     - one named, tougher special infected haunting that sector
#   raiders  - a hostile squad set down near the site when the survivor nears
# Everything exists only while its contract is active and not yet done; it is
# re-placed whenever the sector is loaded again (chunk children go with the
# chunk). Progress: faction_state.contract_field = {contract_id: {"done": bool}}.

const ContractSystem = preload("res://world/contract_system.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

const FIELD_KINDS = ["retrieve", "hunt", "raiders"]
const HUNT_HP_MULT = 2.2
const HUNT_SPAWN_ID = 940            # clear of a chunk's ordinary spawn ids
const RAIDERS_NEAR = 900.0           # set the squad down when the survivor is this close
const SPAWN_CLEAR_OF_PLAYER = 300.0
const TICK = 0.5

var game = null
var _t = 0.0
var _squads = {}                     # contract_id -> squad
var _seen = {}                       # contract_id -> true once the target was sighted


func _init():
    name = "ContractField"


static func default_state() -> Dictionary:
    return {}


static func sanitize(raw) -> Dictionary:
    var out = {}
    if typeof(raw) != TYPE_DICTIONARY:
        return out
    for k in raw.keys():
        var v = raw[k]
        if typeof(v) == TYPE_DICTIONARY:
            out[str(k)] = {"done": bool(v.get("done", false))}
    return out


func state() -> Dictionary:
    if not game.faction_state.has("contract_field") or typeof(game.faction_state["contract_field"]) != TYPE_DICTIONARY:
        game.faction_state["contract_field"] = {}
    return game.faction_state["contract_field"]


func is_done(contract_id: String) -> bool:
    return bool(state().get(contract_id, {}).get("done", false))


func mark_done(contract: Dictionary, message: String) -> void:
    var id = str(contract.get("id", ""))
    if id == "" or is_done(id):
        return
    state()[id] = {"done": true}
    if game.has_method("_set_survival_feedback"):
        game._set_survival_feedback(message, 3.6)


func facts() -> Dictionary:
    # merged into the contract system's known-facts map as done:<contract_id>
    var out = {}
    for id in state().keys():
        if bool(state()[id].get("done", false)):
            out["done:" + str(id)] = true
    return out


func active_field_contracts() -> Array:
    var out = []
    var active = game.faction_state.get("contracts", {}).get("active", {})
    if typeof(active) != TYPE_DICTIONARY:
        return out
    for c in active.values():
        if typeof(c) == TYPE_DICTIONARY and str(c.get("kind", "")) in FIELD_KINDS:
            out.append(c)
    return out


static func site_coord(contract: Dictionary) -> Vector2i:
    var poi = RegionCatalog.poi_by_id(str(contract.get("poi_id", "")))
    return poi.get("coord", Vector2i(999999, 999999)) if not poi.is_empty() else Vector2i(999999, 999999)


static func cache_id(contract: Dictionary) -> String:
    return "contract_" + str(contract.get("id", "")).replace(":", "_")


func _physics_process(delta: float) -> void:
    if game == null or game.player == null or game.player_death_time > 0.0:
        return
    _t -= delta
    if _t > 0.0:
        return
    _t = TICK
    tick()


func tick() -> void:
    var live = {}
    for c in active_field_contracts():
        var id = str(c.get("id", ""))
        live[id] = true
        if is_done(id):
            continue
        match str(c.get("kind", "")):
            "retrieve":
                _tend_cache(c)
            "hunt":
                _tend_hunt(c)
            "raiders":
                _tend_raiders(c)
    # a contract handed in, abandoned or failed takes its traces with it
    for id in state().keys().duplicate():
        if not live.has(id):
            state().erase(id)
    for id in _squads.keys().duplicate():
        if not live.has(id):
            _squads.erase(id)


# ------------------------------------------------------------- placement --
func _site_chunk(contract: Dictionary):
    return game.loaded_chunks.get(site_coord(contract), null)


func _placed(chunk: Node, contract_id: String) -> Node:
    for n in chunk.get_children():
        if str(n.get_meta("contract_id", "")) == contract_id:
            return n
    return null


func free_spot(coord: Vector2i, seed_text: String, clear_of_player: float) -> Vector2:
    # a walkable spot in the sector, away from the survivor if it can be
    var rng = RandomNumberGenerator.new()
    rng.seed = hash(seed_text)
    var base = Vector2(coord) * game.CHUNK_SIZE
    var fallback = Vector2.INF
    for i in range(80):
        var local = Vector2(rng.randf_range(70.0, game.CHUNK_SIZE - 70.0), rng.randf_range(70.0, game.CHUNK_SIZE - 70.0))
        if i < 40:
            # the streets of the sector first: open ground, reachable
            local = game._safe_enemy_spawn(rng)
        var p = base + local
        if not game.marauder_director._free_at(p):
            continue
        if fallback == Vector2.INF:
            fallback = p
        if p.distance_to(game.player.global_position) >= clear_of_player:
            return p
    return fallback


func _tend_cache(contract: Dictionary) -> void:
    var chunk = _site_chunk(contract)
    if chunk == null:
        return
    var id = str(contract.get("id", ""))
    var coord = site_coord(contract)
    var key = "%d:%d:container:%s" % [coord.x, coord.y, cache_id(contract)]
    var node = _placed(chunk, id)
    if node == null:
        var p = free_spot(coord, id + ":cache", 0.0)
        if p == Vector2.INF:
            return
        var fresh = not game.container_states.has(key)
        node = game._create_container(chunk, coord, p - chunk.global_position, cache_id(contract), "contract_cache", str(contract.get("cache_name", "Тайник")))
        node.set_meta("contract_id", id)
        if fresh:
            var items = []
            game._grid_add(items, ContractSystem.PARCEL_ITEM, 1, int(game.container_states[key]["grid_w"]), int(game.container_states[key]["grid_h"]))
            game.container_states[key]["items"] = items
            game.container_states[key]["contract_id"] = id
    # taken out of the cache: the parcel is on its way
    var has_parcel = false
    for e in game.container_states.get(key, {}).get("items", []):
        if str(e.get("id", "")) == ContractSystem.PARCEL_ITEM:
            has_parcel = true
    if not has_parcel and game.container_states.has(key):
        mark_done(contract, "%s у вас. Отнесите заказчику." % str(contract.get("parcel_name", "Груз")))


func _tend_hunt(contract: Dictionary) -> void:
    var chunk = _site_chunk(contract)
    if chunk == null:
        return
    var id = str(contract.get("id", ""))
    var target = _placed(chunk, id)
    if target == null:
        var coord = site_coord(contract)
        var p = free_spot(coord, id + ":hunt", SPAWN_CLEAR_OF_PLAYER)
        if p == Vector2.INF:
            return
        game._spawn_enemy(chunk, coord, HUNT_SPAWN_ID, p - chunk.global_position, str(contract.get("target_kind", "brute")), "standard")
        for n in chunk.get_children():
            if int(n.get_meta("spawn_id", -1)) == HUNT_SPAWN_ID and not n.has_meta("contract_id") and n.is_in_group("infected"):
                target = n
        if target == null:
            return
        target.set_meta("contract_id", id)
        target.set_meta("contract_target_name", str(contract.get("target_name", "Цель")))
        var hp = float(target.get_meta("hp", 70.0)) * HUNT_HP_MULT
        target.set_meta("hp", hp)
        target.set_meta("max_hp", hp)
        target.scale *= 1.08
        return
    if not _seen.has(id) and is_instance_valid(target) and target.global_position.distance_to(game.player.global_position) < 240.0:
        _seen[id] = true
        game._set_survival_feedback("Вот он — %s" % str(contract.get("target_name", "цель")), 2.6)


func on_infected_killed(enemy) -> void:
    var id = str(enemy.get_meta("contract_id", ""))
    if id == "":
        return
    for c in active_field_contracts():
        if str(c.get("id", "")) == id:
            mark_done(c, "%s мёртв. Можно возвращаться за наградой." % str(c.get("target_name", "Цель")))


func _tend_raiders(contract: Dictionary) -> void:
    var id = str(contract.get("id", ""))
    var sq = _squads.get(id, null)
    var dir = game.marauder_director
    if sq != null and not (sq in dir.squads):
        # walked off unbroken (or the survivor fell): set down again next time
        if _broken(sq):
            mark_done(contract, "Отряд разбит. Дорога свободна — можно докладывать.")
            return
        _squads.erase(id)
        sq = null
    if sq == null:
        var coord = site_coord(contract)
        var centre = Vector2(coord) * game.CHUNK_SIZE + Vector2(game.CHUNK_SIZE, game.CHUNK_SIZE) * 0.5
        if game.player.global_position.distance_to(centre) > RAIDERS_NEAR or not game.loaded_chunks.has(coord):
            return
        var p = free_spot(coord, id + ":squad", SPAWN_CLEAR_OF_PLAYER)
        if p == Vector2.INF:
            return
        var t = clampi(int(contract.get("squad_type", 2)), 0, dir.SQUAD_TYPES.size() - 1)
        sq = dir.spawn_squad(dir.SQUAD_TYPES[t], p)
        if sq == null:
            return
        sq.set_meta("contract_id", id)
        # they hold the place: no wandering off down the road
        sq.route = [p]
        sq.leg = 0
        for m in sq.members:
            m.set_meta("contract_id", id)
        _squads[id] = sq
        return
    if _broken(sq):
        mark_done(contract, "Отряд разбит. Дорога свободна — можно докладывать.")


func _broken(sq) -> bool:
    # every member dead, surrendered or running. A member's last known state is
    # kept, so a body cleared away still counts as fallen, and a squad the
    # director sent away whole does not count as broken.
    var seen = sq.get_meta("member_state", {})
    var broken = true
    for m in sq.members:
        var key = str(m.get_instance_id()) if is_instance_valid(m) else ""
        var st = "active"
        if is_instance_valid(m):
            key = str(m.get_instance_id())
            if m.dead:
                st = "dead"
            elif m.surrendered:
                st = "surrendered"
            elif m.state == "flee":
                st = "flee"
            seen[key] = st
        else:
            st = "gone"
        if st == "active":
            broken = false
    sq.set_meta("member_state", seen)
    if not broken:
        return false
    # gone members must have fallen or given up before they went
    var ids = seen.keys()
    if ids.size() < sq.members.size():
        return false
    for k in ids:
        if str(seen[k]) == "active":
            return false
    return true
