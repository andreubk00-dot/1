extends Node
# dev65: the garrison of the raiders' base «Чёрный двор» (region POI
# "marauder_base"). Men stand on posts and towers, two patrols walk the
# streets and the wall lane past the breach, a few sit at the fire, the boss
# keeps to his HQ with two bodyguards. Anyone who sees the survivor raises
# the alarm: the siren on the HQ mast wails, everyone near comes to look, and
# a while later the barracks send out their reserve.
# Who died is remembered: a post stays empty for a couple of days, and once
# the boss is dead and the garrison broken the base stands empty for a few
# days before new men take it back. Loot refreshes as a target farm.

const Marauder = preload("res://world/marauder.gd")

const POI_ID = "marauder_base"
const TICK = 0.5
const POST_REFILL_DAYS = 2
const RECLAIM_DAYS = 5
const ALARM_TIME = 28.0
const ALARM_RADIUS = 560.0
const RESERVE_DELAY = 22.0
const RESERVE_PER_DAY = 3
const DESPAWN_DIST = 1700.0
# the boss' kit, found on his body
const BOSS_KIT = [["akm_extmag", 1], ["ammo_762", 30], ["trauma_kit", 1], ["military_vest", 1], ["emergency_ration", 2]]

# id, cell offset, local position, role, look (deg, 0 = east, 90 = south),
# outfit, weapon. Roles: post (holds the spot), tower (holds, sees further),
# camp (sits at the fire, answers the alarm), boss, patrol members are below.
const POSTS = [
    {"id": "gate_n", "cell": Vector2i(-1, 0), "pos": Vector2(100, 300), "role": "post", "look": 180.0, "outfit": "deserter", "weapon": "akm"},
    {"id": "gate_s", "cell": Vector2i(-1, 0), "pos": Vector2(112, 462), "role": "post", "look": 180.0, "outfit": "bandit", "weapon": "shotgun"},
    {"id": "gate_tower", "cell": Vector2i(-1, 0), "pos": Vector2(146, 612), "role": "tower", "look": 200.0, "outfit": "deserter", "weapon": "akm"},
    {"id": "tower_nw", "cell": Vector2i(-1, -1), "pos": Vector2(112, 104), "role": "tower", "look": 225.0, "outfit": "bandit", "weapon": "akm"},
    {"id": "tower_ne", "cell": Vector2i(1, -1), "pos": Vector2(658, 104), "role": "tower", "look": 315.0, "outfit": "deserter", "weapon": "akm"},
    {"id": "tower_sw", "cell": Vector2i(-1, 1), "pos": Vector2(106, 700), "role": "tower", "look": 135.0, "outfit": "bandit", "weapon": "akm"},
    {"id": "tower_se", "cell": Vector2i(1, 1), "pos": Vector2(656, 700), "role": "tower", "look": 45.0, "outfit": "deserter", "weapon": "akm"},
    {"id": "camp_a", "cell": Vector2i(0, 0), "pos": Vector2(528, 560), "role": "camp", "look": 0.0, "outfit": "gopnik", "weapon": "makarov"},
    {"id": "camp_b", "cell": Vector2i(0, 0), "pos": Vector2(578, 552), "role": "camp", "look": 180.0, "outfit": "bandit", "weapon": "shotgun"},
    {"id": "camp_c", "cell": Vector2i(0, 0), "pos": Vector2(556, 598), "role": "camp", "look": 270.0, "outfit": "gopnik", "weapon": "makarov"},
    {"id": "garage", "cell": Vector2i(-1, -1), "pos": Vector2(574, 204), "role": "camp", "look": 160.0, "outfit": "gopnik", "weapon": "shotgun"},
    {"id": "shop", "cell": Vector2i(0, -1), "pos": Vector2(262, 352), "role": "post", "look": 90.0, "outfit": "bandit", "weapon": "makarov"},
    {"id": "rail", "cell": Vector2i(1, 0), "pos": Vector2(584, 204), "role": "camp", "look": 90.0, "outfit": "gopnik", "weapon": "makarov"},
    {"id": "hq_l", "cell": Vector2i(1, 1), "pos": Vector2(146, 352), "role": "post", "look": 90.0, "outfit": "deserter", "weapon": "akm"},
    {"id": "hq_r", "cell": Vector2i(1, 1), "pos": Vector2(238, 352), "role": "post", "look": 90.0, "outfit": "deserter", "weapon": "shotgun"},
    {"id": "armory", "cell": Vector2i(1, 1), "pos": Vector2(578, 352), "role": "post", "look": 90.0, "outfit": "bandit", "weapon": "akm"},
    {"id": "boss", "cell": Vector2i(1, 1), "pos": Vector2(232, 222), "role": "boss", "look": 90.0, "outfit": "deserter", "weapon": "akm"},
]

# patrols walk their loop for ever: points are [cell offset, local position]
const PATROLS = [
    {"id": "patrol_streets", "outfits": ["bandit", "gopnik"], "weapons": ["akm", "makarov"],
     "route": [[Vector2i(-1, -1), Vector2(384, 384)], [Vector2i(0, -1), Vector2(384, 384)], [Vector2i(1, -1), Vector2(384, 384)],
               [Vector2i(1, 0), Vector2(384, 384)], [Vector2i(1, 1), Vector2(384, 384)], [Vector2i(0, 1), Vector2(384, 384)],
               [Vector2i(-1, 1), Vector2(384, 384)], [Vector2i(-1, 0), Vector2(384, 384)]]},
    {"id": "patrol_wall", "outfits": ["deserter", "bandit"], "weapons": ["akm", "shotgun"],
     "route": [[Vector2i(-1, 1), Vector2(384, 728)], [Vector2i(0, 1), Vector2(200, 728)], [Vector2i(0, 1), Vector2(600, 728)],
               [Vector2i(1, 1), Vector2(384, 728)], [Vector2i(1, 1), Vector2(384, 384)], [Vector2i(0, 1), Vector2(384, 384)],
               [Vector2i(0, 1), Vector2(384, 600)]]},
]
const RESERVE_DOOR = [Vector2i(-1, 1), Vector2(130, 350)]
const SIREN_AT = [Vector2i(1, 1), Vector2(684, 520)]
const FORMATION = [Vector2.ZERO, Vector2(-24, 18), Vector2(-24, -18)]

const BARKS_BASE = {
    "alarm": ["Тревога! Чужой на базе!", "Подъём! К оружию!", "Нас шмонают! Все сюда!"],
    "boss": ["Ну давай, подходи!", "Седой тебе не по зубам.", "Валите его!"],
    "idle": ["Холодно, зараза...", "Когда смена?", "Седой опять не в духе.", "Курить есть?"],
}


# A group of the garrison: one post, the HQ, a patrol or the reserve. It speaks
# the same language as a roaming squad, so marauder.gd needs nothing else.
class Group:
    var base = null
    var kind = "post"
    var members = []
    var route = []
    var leg = 0
    var bark_t = 0.0
    var look = {}

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
        bark_t = now + 1.8
        return true

    func alert(from, pos: Vector2) -> void:
        for m in alive():
            if m != from:
                m.squad_alert(pos)
        base.raise_alarm(pos, from)

    func member_lost(m) -> void:
        base.member_lost(self, m)

    func slot_target(m) -> Vector2:
        if kind != "patrol" and kind != "reserve":
            return m.get_meta("post_pos", m.global_position)
        var lead = leader()
        if lead == null:
            return m.global_position
        if m == lead:
            if route.is_empty():
                return m.global_position
            var goal: Vector2 = route[leg % route.size()]
            if m.global_position.distance_to(goal) < 18.0:
                leg = (leg + 1) % route.size()
                goal = route[leg]
            return goal
        var heading = lead.facing if lead.facing.length() > 0.1 else Vector2.RIGHT
        return lead.global_position + FORMATION[clampi(m.slot, 0, 2)].rotated(heading.angle())

    func idle_look(m, delta: float) -> void:
        # a man on post looks out over his sector, turning slowly
        var base_dir = m.get_meta("post_look", Vector2.ZERO)
        if base_dir == Vector2.ZERO:
            return
        var t = Time.get_ticks_msec() / 1000.0 + float(m.get_instance_id() % 97)
        var swing = 0.7 if m.get_meta("post_role", "") == "tower" else 0.45
        m.facing = m.facing.lerp(base_dir.rotated(sin(t * 0.35) * swing), clamp(delta * 2.0, 0.0, 1.0)).normalized()


var game = null
var anchor = Vector2i(12, 1)
var groups = {}            # id -> Group
var state = {}             # saved: dead posts, boss, cleared, reserve
var tick_t = 0.0
var alarm_t = 0.0
var alarm_pos = Vector2.ZERO
var reserve_t = -1.0
var siren: AudioStreamPlayer2D = null
var idle_bark_t = 12.0
var announced_today = -1


func _ready() -> void:
    var poi = game.RegionCatalog.poi_by_id(POI_ID)
    if not poi.is_empty():
        anchor = poi.get("coord", anchor)
    if state.is_empty():
        state = default_state()
    siren = AudioStreamPlayer2D.new()
    siren.bus = "SFX"
    siren.max_distance = 2600.0
    siren.attenuation = 1.1
    siren.volume_db = -4.0
    var path = "res://audio/world/base_siren.wav"
    if ResourceLoader.exists(path):
        siren.stream = load(path)
    add_child(siren)
    siren.global_position = world_pos(SIREN_AT[0], SIREN_AT[1])
    siren.finished.connect(func():
        if alarm_active():
            siren.play())


static func default_state() -> Dictionary:
    return {"dead": {}, "boss_dead_day": -1, "cleared_day": -1, "reserve_day": -1, "reserve_used": 0, "alarms": 0, "visited": false, "last_raid_day": -99}


func load_state(raw) -> void:
    state = default_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return
    if typeof(raw.get("dead")) == TYPE_DICTIONARY:
        for k in raw["dead"].keys():
            state["dead"][str(k)] = int(raw["dead"][k])
    for k in ["boss_dead_day", "cleared_day", "reserve_day", "reserve_used", "alarms", "last_raid_day"]:
        state[k] = int(raw.get(k, state[k]))
    state["visited"] = bool(raw.get("visited", false))


func serialize() -> Dictionary:
    return state.duplicate(true)


func world_pos(cell: Vector2i, local: Vector2) -> Vector2:
    return Vector2(anchor + cell) * float(game.CHUNK_SIZE) + local


func center() -> Vector2:
    return world_pos(Vector2i.ZERO, Vector2(384, 384))


func contains(p: Vector2) -> bool:
    var size = float(game.CHUNK_SIZE)
    var r = Rect2(Vector2(anchor - Vector2i(1, 1)) * size, Vector2(3, 3) * size)
    return r.has_point(p)


# ------------------------------------------------------------- lifecycle --
func is_cleared() -> bool:
    return int(state["cleared_day"]) >= 0


func post_available(id: String) -> bool:
    if is_cleared():
        return false
    var day = int(state["dead"].get(id, -999))
    return game.world_day >= day + POST_REFILL_DAYS


func garrison_ids() -> Array:
    var out = []
    for p in POSTS:
        out.append(str(p["id"]))
    for pt in PATROLS:
        for i in range(pt["outfits"].size()):
            out.append("%s_%d" % [pt["id"], i])
    return out


func strength() -> float:
    # share of the garrison standing (for the radio, the map and the tests)
    var ids = garrison_ids()
    var up = 0
    for id in ids:
        if post_available(id):
            up += 1
    return float(up) / float(ids.size())


func _physics_process(delta: float) -> void:
    if game == null or game.player == null:
        return
    if alarm_t > 0.0:
        alarm_t -= delta
        if alarm_t <= 0.0 and siren != null:
            siren.stop()
    if reserve_t > 0.0:
        reserve_t -= delta
        if reserve_t <= 0.0:
            _send_reserve()
    tick_t -= delta
    if tick_t > 0.0:
        return
    tick_t = TICK
    _daily()
    _sync_groups()
    _idle_chatter(TICK)
    if not bool(state["visited"]) and contains(game.player.global_position):
        state["visited"] = true
    # the first look at the walls: what this place is and how it can be taken
    if not is_cleared() and game.field_hints != null and game.player.global_position.distance_to(center()) < 1500.0:
        game.field_hints.hint("marauder_base", "«ЧЁРНЫЙ ДВОР» — база мародёров. Часовые на вышках видят дальше, на тревогу выходит резерв. В южной стене есть пролом; ночью и пригнувшись тебя заметят позже.")


func _daily() -> void:
    # a broken base is taken back by new men after a few days
    if is_cleared() and game.world_day >= int(state["cleared_day"]) + RECLAIM_DAYS:
        state["cleared_day"] = -1
        state["boss_dead_day"] = -1
        state["dead"] = {}
        state["reserve_used"] = 0
        game._marauder_base_news("reclaimed")
    if int(state["reserve_day"]) != game.world_day:
        state["reserve_day"] = game.world_day
        state["reserve_used"] = 0
        _raid_the_road()


# While the base stands, Седой's men rob the Artel's convoys on the east road.
# The survivor hears about it once he knows the place (before that it is just
# the world's background). Every third day: a chronicle line, the Artel's
# stores thinner.
func _raid_the_road() -> void:
    if is_cleared() or not game.discovered_pois.has(POI_ID):
        return
    if int(state.get("last_raid_day", -99)) + 3 > game.world_day:
        return
    state["last_raid_day"] = game.world_day
    game.FactionEconomy.adjust_resource(game.faction_state, "mechanics", "technical", -3.0)
    game.FactionEconomy.adjust_resource(game.faction_state, "mechanics", "security", -2.0)
    game._marauder_base_news("raid")


# How hard the roads are pressed by raiders around a point: more roaming squads
# near a standing base, far fewer for the days after it fell.
func roaming_pressure(at: Vector2) -> float:
    if is_cleared():
        return 0.55
    var sectors = at.distance_to(center()) / float(game.CHUNK_SIZE)
    return 1.5 if sectors < 7.0 else 1.0


func _chunk_loaded(cell: Vector2i) -> bool:
    return game.loaded_chunks.has(anchor + cell)


func _sync_groups() -> void:
    var near = game.player.global_position.distance_to(center()) < DESPAWN_DIST
    # a group whose men are all dead is gone; its post refills in time
    for id in groups.keys():
        if groups[id].alive().is_empty():
            groups.erase(id)
    # posts
    for p in POSTS:
        var id = str(p["id"])
        var g = groups.get(id, null)
        var loaded = near and _chunk_loaded(p["cell"])
        if g != null:
            if not loaded and not _fighting(g):
                _free_group(id)
            continue
        if loaded and post_available(id) and game.player_death_time <= 0.0:
            _spawn_post(p)
    # patrols
    for pt in PATROLS:
        var id = str(pt["id"])
        var g = groups.get(id, null)
        if g != null:
            var lead = g.leader()
            var lead_loaded = lead != null and game.loaded_chunks.has(game._world_to_chunk(lead.global_position))
            if (not near or not lead_loaded) and not _fighting(g):
                _free_group(id)
            continue
        if not near or game.player_death_time > 0.0:
            continue
        var start = pt["route"][0]
        if not _chunk_loaded(start[0]):
            continue
        var ids = []
        for i in range(pt["outfits"].size()):
            if post_available("%s_%d" % [id, i]):
                ids.append(i)
        if not ids.is_empty():
            _spawn_patrol(pt, ids)
    # the reserve goes home when it is over
    if groups.has("reserve") and not near and not _fighting(groups["reserve"]):
        _free_group("reserve")


func _fighting(g) -> bool:
    for m in g.alive():
        if m.state in ["combat", "investigate", "search", "flee"]:
            return true
    return false


func _free_group(id: String) -> void:
    var g = groups.get(id, null)
    if g == null:
        return
    for m in g.members:
        if is_instance_valid(m) and not m.dead:
            m.queue_free()
    groups.erase(id)


func _make(outfit: String, weapon: String, personality: String, at: Vector2, g, slot: int):
    var m = Marauder.new()
    m.setup(game, outfit, weapon, personality)
    m.squad = g
    m.slot = slot
    m.position = at if _free_at(at) else _nearest_free(at)
    m.set_meta("base_member", true)
    # the garrison is the raiders' best: steadier hands, vests on the deserters
    m.aim_bonus = 0.12
    m.settle_time = 2.0
    m.aim_in = Vector2(0.4, 0.75)
    m.armor_mult = 0.72 if outfit == "deserter" else 0.88
    game.add_child(m)
    g.members.append(m)
    return m


func _spawn_post(p: Dictionary) -> void:
    var g = Group.new()
    g.base = self
    g.kind = str(p["role"])
    var id = str(p["id"])
    var at = world_pos(p["cell"], p["pos"])
    var personality = "fanatic" if g.kind == "boss" else "hostile"
    var m = _make(str(p["outfit"]), str(p["weapon"]), personality, at, g, 0)
    m.post_id = id
    m.set_meta("post_pos", m.position)
    m.set_meta("post_role", g.kind)
    var look = Vector2.RIGHT.rotated(deg_to_rad(float(p["look"])))
    m.set_meta("post_look", look)
    m.facing = look
    if g.kind in ["post", "tower", "boss"]:
        m.leash_pos = m.position
        m.leash = 70.0 if g.kind == "tower" else (90.0 if g.kind == "boss" else 120.0)
    if g.kind == "tower":
        m.sight_mult = 1.35
    if g.kind == "boss":
        m.hostile_to_player = true
        m.max_hp = 260.0
        m.hp = 260.0
        m.reserve = 90
        m.set_meta("body_name", "ГЛАВАРЬ «СЕДОЙ»")
        m.set_meta("body_extra", BOSS_KIT)
        m.scale = Vector2(1.06, 1.06)
        m.armor_mult = 0.55
        m.aim_bonus = 0.18
    groups[id] = g


func _spawn_patrol(pt: Dictionary, ids: Array) -> void:
    var g = Group.new()
    g.base = self
    g.kind = "patrol"
    for raw in pt["route"]:
        g.route.append(world_pos(raw[0], raw[1]))
    var start = g.route[0]
    var slot = 0
    for i in ids:
        var m = _make(str(pt["outfits"][i]), str(pt["weapons"][i]), "hostile", start + FORMATION[slot], g, slot)
        m.post_id = "%s_%d" % [pt["id"], i]
        slot += 1
    g.leg = 1
    groups[str(pt["id"])] = g


func _send_reserve() -> void:
    if is_cleared() or groups.has("reserve") or game.player_death_time > 0.0:
        return
    var left = RESERVE_PER_DAY - int(state["reserve_used"])
    if left <= 0 or not _chunk_loaded(RESERVE_DOOR[0]):
        return
    var g = Group.new()
    g.base = self
    g.kind = "reserve"
    var door = world_pos(RESERVE_DOOR[0], RESERVE_DOOR[1])
    var kit = [["deserter", "akm"], ["bandit", "shotgun"], ["gopnik", "makarov"]]
    for i in range(left):
        var m = _make(kit[i][0], kit[i][1], "hostile", door + FORMATION[i], g, i)
        m.post_id = "reserve"
        m.last_seen_pos = alarm_pos
        m.heard_pos = alarm_pos
        m._set_state("investigate")
        m._bark("flank")
    g.route = [alarm_pos]
    state["reserve_used"] = int(state["reserve_used"]) + left
    groups["reserve"] = g


# --------------------------------------------------------------- alarm --
func raise_alarm(pos: Vector2, from) -> void:
    alarm_pos = pos
    if alarm_t <= 0.0:
        state["alarms"] = int(state["alarms"]) + 1
        if siren != null and siren.stream != null:
            siren.play()
        if is_instance_valid(from):
            var lines: Array = BARKS_BASE["boss"] if from.post_id == "boss" else BARKS_BASE["alarm"]
            from.say_line(lines[randi() % lines.size()], 2.6)
        if reserve_t <= 0.0:
            reserve_t = RESERVE_DELAY
    alarm_t = ALARM_TIME
    for g in groups.values():
        for m in g.alive():
            if m == from or m.state in ["combat", "flee", "surrender"]:
                continue
            if m.global_position.distance_to(pos) > ALARM_RADIUS:
                continue
            # they know where the noise was, not where the survivor is now
            m.heard_pos = pos
            m._set_state("investigate")


func alarm_active() -> bool:
    return alarm_t > 0.0


func notify_sound(origin: Vector2, radius: float, kind: String, source) -> void:
    for g in groups.values():
        for m in g.alive():
            if m != source:
                m.hear(origin, radius, kind)


func member_lost(g, m) -> void:
    var rest = g.alive()
    rest.erase(m)
    if m.dead:
        if not rest.is_empty():
            rest[0].mourn(m)
        if m.post_id != "" and m.post_id != "reserve":
            state["dead"][m.post_id] = game.world_day
        if m.post_id == "boss":
            state["boss_dead_day"] = game.world_day
            game._marauder_base_news("boss")
        _check_cleared()


func _check_cleared() -> void:
    if is_cleared() or int(state["boss_dead_day"]) < 0:
        return
    var ids = garrison_ids()
    var down = 0
    for id in ids:
        if state["dead"].has(id) and game.world_day < int(state["dead"][id]) + POST_REFILL_DAYS:
            down += 1
    if float(down) / float(ids.size()) >= 0.7:
        state["cleared_day"] = game.world_day
        game._marauder_base_news("cleared")


func on_player_respawn() -> void:
    alarm_t = 0.0
    reserve_t = -1.0
    if siren != null:
        siren.stop()
    for id in groups.keys():
        _free_group(id)


func _idle_chatter(dt: float) -> void:
    idle_bark_t -= dt
    if idle_bark_t > 0.0 or alarm_active():
        return
    idle_bark_t = randf_range(14.0, 26.0)
    var near = []
    for g in groups.values():
        for m in g.alive():
            if m.state == "patrol" and m.global_position.distance_to(game.player.global_position) < 260.0:
                near.append(m)
    if near.is_empty():
        return
    var m = near[randi() % near.size()]
    m.say_line(BARKS_BASE["idle"][randi() % BARKS_BASE["idle"].size()], 2.4)


func members() -> Array:
    var out = []
    for g in groups.values():
        out += g.alive()
    return out


func _free_at(c: Vector2) -> bool:
    var q = PhysicsShapeQueryParameters2D.new()
    var sh = CircleShape2D.new()
    sh.radius = 8.0
    q.shape = sh
    q.transform = Transform2D(0, c)
    q.collision_mask = game.LAYER_WORLD
    return game.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _nearest_free(at: Vector2) -> Vector2:
    for r in [10.0, 20.0, 32.0, 46.0]:
        for k in range(8):
            var c = at + Vector2.RIGHT.rotated(TAU * k / 8.0) * r
            if _free_at(c):
                return c
    return at
