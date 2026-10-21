extends Node
# Marauder squads around the survivor. A squad comes into the loaded world out
# of sight, walks a route along the roads through a few sectors, pilfers the
# containers it passes and leaves again; it fights when it finds the player.
# Squads are transient (like DayZ's roaming AI); their dead stay as bodies.

const Marauder = preload("res://world/marauder.gd")

const CHECK_EVERY = 30.0
const MAX_SQUADS = 2
const FIRST_DELAY = 240.0        # a fresh game gets four quiet minutes
const DESPAWN_DIST = 1250.0
const SPAWN_MIN = 470.0
const SPAWN_MAX = 900.0
# who walks together, with what (weights)
const SQUAD_TYPES = [
    {"outfit": "gopnik", "size": [1, 3], "weapons": ["makarov", "makarov", "shotgun"], "personality": "hostile", "w": 3},
    {"outfit": "gopnik", "size": [1, 1], "weapons": ["makarov"], "personality": "coward", "w": 2},
    {"outfit": "bandit", "size": [2, 3], "weapons": ["shotgun", "akm", "makarov"], "personality": "hostile", "w": 3},
    {"outfit": "bandit", "size": [1, 1], "weapons": ["shotgun"], "personality": "neutral", "w": 3},
    {"outfit": "deserter", "size": [2, 3], "weapons": ["akm", "akm", "shotgun"], "personality": "hostile", "w": 2},
    {"outfit": "deserter", "size": [1, 1], "weapons": ["akm"], "personality": "neutral", "w": 2},
    # dev66: Кузьмич the road trader with his guard (index 6)
    {"outfit": "gopnik", "outfits": ["gopnik", "deserter"], "size": [2, 2], "weapons": ["makarov", "akm"], "personality": "neutral", "trader": "wanderer_kuzmich", "w": 2},
]
const TRADER_TYPE = 6
const TRADER_STOP = 130.0       # the caravan halts for a customer this close
const TRADER_FAR = 170.0        # walk further off and the stall closes
const FORMATION = [Vector2.ZERO, Vector2(-26, 20), Vector2(-26, -20)]


class Squad:
    var director = null
    var members = []
    var route = []
    var leg = 0
    var bark_t = 0.0
    var looted = {}
    var kind = {}
    var hold = false

    func leader():
        for m in members:
            if is_instance_valid(m) and not m.dead:
                return m
        return null

    func alive() -> Array:
        var out = []
        for m in members:
            if is_instance_valid(m) and not m.dead:
                out.append(m)
        return out

    func may_bark() -> bool:
        var now = Time.get_ticks_msec() / 1000.0
        if now < bark_t:
            return false
        bark_t = now + 1.6
        return true

    func alert(from, pos: Vector2) -> void:
        for m in alive():
            if m != from:
                m.squad_alert(pos)

    func member_lost(m) -> void:
        var rest = alive()
        rest.erase(m)
        if not rest.is_empty() and m.dead:
            rest[0].mourn(m)

    func slot_target(m) -> Vector2:
        var lead = leader()
        if lead == null:
            return m.global_position
        if m == lead:
            if hold or leg >= route.size():
                return m.global_position
            var goal: Vector2 = route[leg]
            if m.global_position.distance_to(goal) < 18.0:
                leg += 1
                if leg >= route.size():
                    director.squad_finished(self)
                    return m.global_position
                goal = route[leg]
            return goal
        var heading = lead.facing if lead.facing.length() > 0.1 else Vector2.RIGHT
        var idx = clampi(m.slot, 0, FORMATION.size() - 1)
        return lead.global_position + FORMATION[idx].rotated(heading.angle())


var game = null
var squads = []
# dev66: what the raiders remember about the survivor - the men he let go
# (one of them may turn up again, grateful) and the ones he shot with their
# hands up (then nobody surrenders to him for a few days)
var memory = {"spared": [], "executions": 0, "execution_day": -99}
const SPARED_KEEP = 4
const REUNION_CHANCE = 0.35
const NO_MERCY_AT = 2
# the first people a new survivor meets on the road are Кузьмич and his guard:
# not every armed man out there is an enemy (about 13:30 on the first day)
const FIRST_TRADER_DELAY = 90.0
const MERCY_FORGET_DAYS = 3
var check_t = 0.0
var age = 0.0
var spawned_total = 0


func _physics_process(delta: float) -> void:
    if game == null or game.player == null:
        return
    age += delta
    for sq in squads.duplicate():
        _tick_squad(sq)
    check_t -= delta
    if check_t > 0.0:
        return
    check_t = CHECK_EVERY
    _maybe_spawn()


func _tick_squad(sq) -> void:
    var alive = sq.alive()
    if alive.is_empty():
        squads.erase(sq)
        return
    # walking away from the survivor and out of the fight: they leave
    var fighting = false
    var nearest = INF
    for m in alive:
        if m.state in ["combat", "flee", "surrender"]:
            fighting = true
        nearest = min(nearest, m.global_position.distance_to(game.player.global_position))
    if nearest > DESPAWN_DIST and not fighting:
        _remove(sq)
        return
    var lead = sq.leader()
    if str(sq.kind.get("trader", "")) != "":
        _tick_trader(sq)
    # at a town's walls they turn back; a fight does not follow the survivor in
    if lead != null and safe_chunk(game._world_to_chunk(lead.global_position)):
        for m in alive:
            if m.state in ["combat", "investigate", "search"]:
                m._set_state("patrol")
        if not sq.has_meta("turned"):
            sq.set_meta("turned", true)
            sq.route.reverse()
            sq.leg = 1
    if lead != null and lead.state == "patrol":
        _maybe_pilfer(sq, lead)


func remember_spared(m) -> void:
    var list: Array = memory["spared"]
    list.append({"nick": m.nick, "outfit": m.outfit, "weapon": m.weapon, "voice": m.voice_id, "day": game.world_day})
    while list.size() > SPARED_KEEP:
        list.pop_front()


func note_execution(m) -> void:
    _forget_executions()
    memory["executions"] = int(memory["executions"]) + 1
    memory["execution_day"] = game.world_day
    # whoever saw it will say so
    for sq in squads:
        for o in sq.alive():
            if o != m and o.global_position.distance_to(m.global_position) < 300.0:
                o._bark("no_mercy", true)
                return


func _forget_executions() -> void:
    # rumours fade: one step every few quiet days
    var since = game.world_day - int(memory["execution_day"])
    if int(memory["executions"]) > 0 and since >= MERCY_FORGET_DAYS:
        memory["executions"] = max(0, int(memory["executions"]) - int(since / MERCY_FORGET_DAYS))
        memory["execution_day"] = game.world_day


func no_mercy() -> bool:
    _forget_executions()
    return int(memory["executions"]) >= NO_MERCY_AT


func _reunion_type():
    # a man let go at least a day ago may come back along the road, alone
    for rec in memory["spared"]:
        if game.world_day >= int(rec["day"]) + 1 and not bool(rec.get("met", false)):
            return rec
    return null


func serialize_memory() -> Dictionary:
    return memory.duplicate(true)


func restore_memory(raw) -> void:
    memory = {"spared": [], "executions": 0, "execution_day": -99}
    if typeof(raw) != TYPE_DICTIONARY:
        return
    memory["executions"] = clampi(int(raw.get("executions", 0)), 0, 20)
    memory["met_trader"] = bool(raw.get("met_trader", false))
    memory["execution_day"] = int(raw.get("execution_day", -99))
    for rec in raw.get("spared", []) if typeof(raw.get("spared", [])) == TYPE_ARRAY else []:
        if typeof(rec) != TYPE_DICTIONARY:
            continue
        var outfit = str(rec.get("outfit", "bandit"))
        var weapon = str(rec.get("weapon", "makarov"))
        if outfit not in ["gopnik", "bandit", "deserter"] or not Marauder.ARMS.has(weapon):
            continue
        memory["spared"].append({"nick": str(rec.get("nick", "")).left(16), "outfit": outfit, "weapon": weapon,
            "voice": clampi(int(rec.get("voice", 0)), 0, 3), "day": int(rec.get("day", 1)), "met": bool(rec.get("met", false)),
            "paid": bool(rec.get("paid", false))})
    while memory["spared"].size() > SPARED_KEEP:
        memory["spared"].pop_front()


func spawn_reunion(rec, at: Vector2 = Vector2(INF, INF)):
    var t = {"outfit": rec["outfit"], "size": [1, 1], "weapons": [rec["weapon"]], "personality": "neutral", "w": 0}
    var sq = spawn_squad(t, at)
    if sq == null:
        return null
    var m = sq.members[0]
    m.nick = str(rec["nick"])
    m.voice_id = int(rec["voice"])
    m.set_meta("spared", true)
    m.set_meta("spared_rec", rec)
    rec["met"] = true
    return sq


func safe_chunk(coord: Vector2i) -> bool:
    return bool(game.RegionCatalog.poi_for_chunk(coord).get("safe_settlement", false))


func _tick_trader(sq) -> void:
    var trader = null
    for m in sq.alive():
        if m.has_meta("trader_id"):
            trader = m
    var tid = str(sq.kind.get("trader", ""))
    if trader == null or trader.hostile_to_player:
        # robbed or turned on: no more trade with this caravan
        if game.trader_open and game.active_trader_id == tid:
            game._close_trader()
        if trader != null and trader.is_in_group("interactable"):
            trader.remove_from_group("interactable")
        sq.hold = false
        return
    var d = trader.global_position.distance_to(game.player.global_position)
    sq.hold = d < TRADER_STOP
    if sq.hold:
        trader.facing = trader.facing.lerp((game.player.global_position - trader.global_position).normalized(), 0.2).normalized()
        if not sq.has_meta("greeted"):
            sq.set_meta("greeted", true)
            trader.say_line("Стой-стой, не стреляй! Торговлю ведём? Патроны, бинты, мелочь.", 4.0)
            if game.field_hints != null:
                game.field_hints.hint("road_trader", "Не каждый с оружием — враг. Кузьмич торгует с дороги ({interact} — ТОРГОВАТЬ), нейтральные бродяги не стреляют первыми. Но ствол на них не наводи.")
    if game.trader_open and game.active_trader_id == tid and d > TRADER_FAR:
        game._close_trader()


func on_player_respawn() -> void:
    # a fresh survivor with a knife gets a few quiet minutes again
    age = 0.0
    for sq in squads.duplicate():
        _remove(sq)


func squad_finished(sq) -> void:
    # end of the route: turn round along the same roads
    sq.route.reverse()
    sq.leg = 1


func _remove(sq) -> void:
    for m in sq.members:
        if is_instance_valid(m):
            m.queue_free()
    squads.erase(sq)


func _maybe_pilfer(sq, lead) -> void:
    for n in get_tree().get_nodes_in_group("interactable"):
        if str(n.get_meta("interaction_type", "")) != "container":
            continue
        var key = str(n.get_meta("container_key", ""))
        if key == "" or sq.looted.has(key) or key.find(":container:body_") >= 0 or key.find(":container:mbody_") >= 0:
            continue
        if n.global_position.distance_to(lead.global_position) > 70.0:
            continue
        sq.looted[key] = true
        if randf() > 0.4 or not game.container_states.has(key):
            continue
        # a padlock keeps a passing squad out (dev72)
        if bool(game.container_states[key].get("locked", false)):
            continue
        var items = game.container_states[key].get("items", [])
        var took = 0
        while took < 2 and not items.is_empty():
            items.remove_at(randi() % items.size())
            took += 1
        game.container_states[key]["items"] = items
        if items.is_empty():
            game.container_states[key]["emptied_day"] = game.world_day
        for m in sq.alive():
            m.loot_t = 3.5
            m._set_state("loot")
        lead._bark("loot", true)
        return


func _maybe_spawn() -> void:
    if not bool(memory.get("met_trader", false)) and age >= FIRST_TRADER_DELAY and squads.size() < MAX_SQUADS \
            and game.player_death_time <= 0.0 and not game._high_risk_floor_active():
        if spawn_squad(SQUAD_TYPES[TRADER_TYPE]) != null:
            memory["met_trader"] = true
            return
    if age < FIRST_DELAY or squads.size() >= MAX_SQUADS:
        return
    if game.player_death_time > 0.0 or game._high_risk_floor_active():
        return
    # about one squad every three or four minutes while fewer than two roam
    var chance = 0.18 * (1.0 - game._time_night_factor() * 0.45)
    # the raiders' base presses the roads around it; once it falls they thin out
    if game.marauder_base != null:
        chance *= game.marauder_base.roaming_pressure(game.player.global_position)
    # «ЭФИР»: told the truth, people stop sitting at home as easy prey
    if game.has_method("ether_roaming_factor"):
        chance *= game.ether_roaming_factor()
    if randf() > chance:
        return
    var rec = _reunion_type()
    if rec != null and randf() < REUNION_CHANCE:
        spawn_reunion(rec)
        return
    spawn_squad()


func spawn_squad(force_type: Dictionary = {}, at: Vector2 = Vector2(INF, INF)):
    var spot = at if at.x != INF else _spawn_spot()
    if spot.x == INF:
        return null
    var t = force_type if not force_type.is_empty() else _pick_type()
    var sq = Squad.new()
    sq.director = self
    sq.kind = t
    sq.route = _route_from(spot)
    var n = randi_range(int(t["size"][0]), int(t["size"][1]))
    for i in range(n):
        var m = Marauder.new()
        var weapons: Array = t["weapons"]
        var outfits: Array = t.get("outfits", [t["outfit"]])
        m.setup(game, str(outfits[i % outfits.size()]), str(weapons[i % weapons.size()]), str(t["personality"]))
        m.squad = sq
        m.slot = i
        if i == 0 and str(t.get("trader", "")) != "":
            _make_trader(m, str(t["trader"]))
        var p = spot + FORMATION[i].rotated(randf() * TAU)
        m.position = p if _free_at(p) else spot
        game.add_child(m)
        sq.members.append(m)
    squads.append(sq)
    spawned_total += 1
    return sq


func _make_trader(m, trader_id: String) -> void:
    m.nick = str(game.TraderCatalog.trader(trader_id).get("name", "Торговец"))
    m.set_meta("trader_id", trader_id)
    # the stall opens with fresh goods each time the caravan comes by
    game._restock_wanderer(trader_id)


func _pick_type() -> Dictionary:
    var total = 0
    for t in SQUAD_TYPES:
        total += int(t["w"])
    var r = randi() % total
    for t in SQUAD_TYPES:
        r -= int(t["w"])
        if r < 0:
            return t
    return SQUAD_TYPES[0]


func _spawn_spot() -> Vector2:
    # a road crossing or a street point in a loaded sector, far enough and
    # outside the camera, not in a settlement or an authored site
    var cam = game.get_viewport().get_camera_2d()
    var view = Rect2(cam.get_screen_center_position() - Vector2(260, 160), Vector2(520, 320)) if cam != null else Rect2()
    var candidates = []
    for coord in game.loaded_chunks.keys():
        var poi = game.RegionCatalog.poi_for_chunk(coord)
        if not poi.is_empty():
            continue
        var base = Vector2(coord) * game.CHUNK_SIZE
        for local in [Vector2(384, 384), Vector2(384, 150), Vector2(384, 620), Vector2(150, 384), Vector2(620, 384)]:
            var p = base + local
            var d = p.distance_to(game.player.global_position)
            if d < SPAWN_MIN or d > SPAWN_MAX or view.has_point(p):
                continue
            if _free_at(p):
                candidates.append(p)
    if candidates.is_empty():
        return Vector2(INF, INF)
    return candidates[randi() % candidates.size()]


func _route_from(spot: Vector2) -> Array:
    # along the road grid: the crossings of neighbouring sectors, mostly
    # passing near the survivor's sector (they are going somewhere)
    var size = float(game.CHUNK_SIZE)
    var coord = Vector2i(floor(spot.x / size), floor(spot.y / size))
    var route = [spot]
    var here = coord
    var toward = game._world_to_chunk(game.player.global_position)
    for i in range(4):
        var options = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
        var best = options[randi() % 4]
        if randf() < 0.6:
            var d = toward - here
            if d != Vector2i.ZERO:
                best = Vector2i(signi(d.x), 0) if abs(d.x) >= abs(d.y) else Vector2i(0, signi(d.y))
        # raiders keep out of the guarded towns (dev65)
        if safe_chunk(here + best):
            options.shuffle()
            best = Vector2i.ZERO
            for o in options:
                if not safe_chunk(here + o):
                    best = o
                    break
            if best == Vector2i.ZERO:
                break
        here += best
        route.append(Vector2(here) * size + Vector2(384, 384) + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
    return route


func _free_at(c: Vector2) -> bool:
    var q = PhysicsShapeQueryParameters2D.new()
    var sh = CircleShape2D.new()
    sh.radius = 9.0
    q.shape = sh
    q.transform = Transform2D(0, c)
    q.collision_mask = game.LAYER_WORLD
    return game.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func notify_sound(origin: Vector2, radius: float, kind: String, source) -> void:
    for sq in squads:
        for m in sq.alive():
            if m != source:
                m.hear(origin, radius, kind)


# ------------------------------------------------------------- dev64: saving --
# Squads near the survivor are part of the moment: a save in the middle of a
# fight brings the same men back, where they stood, as wounded and as angry.
func serialize() -> Array:
    var out = []
    if game == null or game.player == null:
        return out
    for sq in squads:
        var members = []
        var near = false
        for m in sq.alive():
            if m.global_position.distance_to(game.player.global_position) < DESPAWN_DIST:
                near = true
            members.append({
                "outfit": m.outfit, "weapon": m.weapon, "personality": m.personality,
                "hostile": m.hostile_to_player, "x": m.global_position.x, "y": m.global_position.y,
                "hp": m.hp, "mag": m.mag, "reserve": m.reserve, "slot": m.slot,
                "combat": m.state == "combat", "surrendered": m.surrendered, "dropped": m.weapon_dropped,
                "voice": m.voice_id, "nick": m.nick, "spared": m.has_meta("spared"),
                "traded": bool(m.get_meta("traded", false)),
            })
        if not near or members.is_empty():
            continue
        var route = []
        for p in sq.route:
            route.append([p.x, p.y])
        out.append({"members": members, "route": route, "leg": sq.leg, "trader": str(sq.kind.get("trader", ""))})
    return out


func restore(data: Array) -> void:
    for raw in data:
        if typeof(raw) != TYPE_DICTIONARY or typeof(raw.get("members")) != TYPE_ARRAY:
            continue
        var sq = Squad.new()
        sq.director = self
        var tid = str(raw.get("trader", ""))
        if tid != "" and game.TraderCatalog.is_wanderer(tid):
            sq.kind = SQUAD_TYPES[TRADER_TYPE]
        for p in raw.get("route", []):
            if typeof(p) == TYPE_ARRAY and p.size() == 2:
                sq.route.append(Vector2(float(p[0]), float(p[1])))
        sq.leg = clampi(int(raw.get("leg", 0)), 0, max(0, sq.route.size() - 1))
        for md in raw["members"]:
            if typeof(md) != TYPE_DICTIONARY:
                continue
            var outfit = str(md.get("outfit", "bandit"))
            var weapon = str(md.get("weapon", "makarov"))
            if outfit not in ["gopnik", "bandit", "deserter"] or not Marauder.ARMS.has(weapon):
                continue
            var m = Marauder.new()
            m.setup(game, outfit, weapon, str(md.get("personality", "hostile")))
            m.hostile_to_player = bool(md.get("hostile", m.hostile_to_player))
            m.hp = clamp(float(md.get("hp", m.max_hp)), 1.0, m.max_hp)
            m.mag = clampi(int(md.get("mag", m.mag)), 0, int(Marauder.ARMS[weapon]["mag"]))
            m.reserve = clampi(int(md.get("reserve", m.reserve)), 0, 120)
            m.slot = clampi(int(md.get("slot", 0)), 0, 2)
            m.voice_id = clampi(int(md.get("voice", 0)), 0, 3)
            if str(md.get("nick", "")) != "":
                m.nick = str(md["nick"]).left(16)
            if bool(md.get("traded", false)):
                m.set_meta("traded", true)
            if bool(md.get("spared", false)):
                m.set_meta("spared", true)
                m.set_meta("greeted", true)
                for rec in memory["spared"]:
                    if str(rec["nick"]) == m.nick:
                        m.set_meta("spared_rec", rec)
            m.surrendered = bool(md.get("surrendered", false))
            m.weapon_dropped = bool(md.get("dropped", false))
            m.squad = sq
            if m.slot == 0 and str(sq.kind.get("trader", "")) != "" and not m.surrendered:
                m.nick = str(game.TraderCatalog.trader(tid).get("name", "Торговец"))
                m.set_meta("trader_id", tid)
            var p = Vector2(float(md.get("x", 0.0)), float(md.get("y", 0.0)))
            m.position = p if _free_at(p) else p + Vector2(12, 0)
            game.add_child(m)
            if bool(md.get("combat", false)) and m.hostile_to_player:
                m.last_seen_pos = game.player.global_position
                m.last_seen_time = Time.get_ticks_msec() / 1000.0
                m._set_state("combat")
                m.fire_t = 1.2
            elif m.surrendered:
                m.flee_t = 20.0
                m._set_state("flee")
            sq.members.append(m)
        if not sq.members.is_empty():
            if sq.route.is_empty():
                sq.route = [sq.members[0].global_position]
            squads.append(sq)
