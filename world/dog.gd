extends CharacterBody2D
# dev73: the dog (docs/DOG_DEV73.md). Found on a chain in a yard at the edge of
# town; fed, it follows the survivor along the way he walked. It senses the
# infected he cannot see and growls, barks at the ones that come close (the
# bark is a noise they hear), does not fight, eats and drinks, can be hurt and
# can die. When the survivor dies it stays by the body, a stranger to the next.
# Its record lives in game.dog_state["dog"]; the yards in dog_state["sites"].

const DogCatalog = preload("res://world/dog_catalog.gd")
const Nav = preload("res://world/local_navigation.gd")

const CELL = 128
const SPRITE_SCALE = 0.5
const SPRITE_OFFSET = Vector2(0, -14)
const FRAMES = {"walk": 12, "run": 8, "idle": 8, "sit": 4, "alert": 4, "lie": 2}
const STRIDE = {"walk": 30.0, "run": 46.0}
const TROT_SPEED = 66.0
const RUN_SPEED = 98.0
const GAP = 34.0              # it keeps this far behind
const CATCH_UP = 96.0         # beyond this it runs
const TELEPORT = 720.0        # beyond this (off screen) it catches up at once
const TRAIL_STEP = 12.0
const TRAIL_MAX = 90
const WHISTLE = 640.0         # how far a call carries
const SENSE = 380.0
const BARK_SEE = 210.0
const BARK_RADIUS = 300.0
const BITE_RANGE = 20.0
const WARY = 120.0            # a chained dog growls at a stranger this close

var game = null
var dog_name = ""
var site = ""
var mode = "follow"           # chained | follow | wait
var trusted = true
var hp = DogCatalog.MAX_HP
var food = 70.0
var water = 70.0
var dead = false

var facing = Vector2.DOWN
var dir8 = 2
var trail = []
var walk_dist = 0.0
var last_pos = Vector2.ZERO
var stuck_t = 0.0
var skip_t = 0.0
var think_t = 0.0
var bark_cd = 0.0
var growl_cd = 0.0
var bite_cd = 0.0
var hurt_t = 0.0
var flee_t = 0.0
var flee_from = Vector2.ZERO
var sensed = null             # the unseen infected it is turned to
var alert_t = 0.0
var last_minutes = -1.0
var mourning = false
var going_to = Vector2(INF, INF)
var nav_path = []
var nav_goal = Vector2(INF, INF)
var nav_t = 0.0
var _warned = {}
var _clip = ""
var _sheets = {}

var sprite: Sprite2D = null
var shadow: Polygon2D = null
var voice: AudioStreamPlayer2D = null
var chain: Line2D = null
var stake = Vector2(INF, INF)


func setup(p_game, record: Dictionary) -> void:
    game = p_game
    dog_name = str(record.get("name", "Найда"))
    site = str(record.get("site", ""))
    mode = str(record.get("mode", "follow"))
    trusted = bool(record.get("trusted", true))
    hp = float(record.get("hp", DogCatalog.MAX_HP))
    food = float(record.get("food", 70.0))
    water = float(record.get("water", 70.0))


func record() -> Dictionary:
    return {"name": dog_name, "site": site, "hp": hp, "food": food, "water": water,
        "mode": "wait" if mode in ["wait", "chained"] else "follow", "trusted": trusted,
        "x": global_position.x, "y": global_position.y}


func _ready() -> void:
    add_to_group("dog")
    collision_layer = 0
    collision_mask = game.LAYER_WORLD
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    z_index = 9
    z_as_relative = false
    var shape = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = 4.0
    shape.shape = circle
    add_child(shape)
    shadow = Polygon2D.new()
    var pts = PackedVector2Array()
    for i in range(16):
        var a = TAU * i / 16.0
        pts.append(Vector2(cos(a) * 10.0, 3.0 + sin(a) * 3.0))
    shadow.polygon = pts
    shadow.color = Color(0.02, 0.02, 0.02, 0.24)
    shadow.z_index = -2
    add_child(shadow)
    sprite = Sprite2D.new()
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.region_enabled = true
    sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
    sprite.position = SPRITE_OFFSET
    sprite.z_index = 1
    add_child(sprite)
    voice = AudioStreamPlayer2D.new()
    voice.bus = "SFX"
    voice.max_distance = 900.0
    voice.attenuation = 1.5
    add_child(voice)
    add_to_group("interactable")
    set_meta("interaction_type", "dog")
    set_meta("interaction_radius", 40.0)
    set_meta("display_name", dog_name)
    last_pos = global_position
    if mode == "chained":
        stake = get_meta("stake", global_position + Vector2(-16, -10))
        chain = Line2D.new()
        chain.width = 1.0
        chain.default_color = Color(0.36, 0.34, 0.31)
        chain.z_index = -1
        add_child(chain)
    _set_clip("idle" if mode != "wait" else "sit", 0)


# ------------------------------------------------------------------ frame --
func _physics_process(delta: float) -> void:
    if game == null or game.player == null:
        return
    if dead:
        _set_clip("lie", 1)
        return
    bark_cd = max(0.0, bark_cd - delta)
    growl_cd = max(0.0, growl_cd - delta)
    bite_cd = max(0.0, bite_cd - delta)
    hurt_t = max(0.0, hurt_t - delta)
    flee_t = max(0.0, flee_t - delta)
    alert_t = max(0.0, alert_t - delta)
    _needs()
    if dead:
        return
    if mode == "chained":
        _chained(delta)
        return
    _watch_survivor()
    think_t -= delta
    if think_t <= 0.0:
        think_t = 0.25
        _sense()
        _bitten()
    var move = _decide(delta)
    velocity = move
    move_and_slide()
    var moved = global_position.distance_to(last_pos)
    walk_dist += moved
    stuck_t = stuck_t + delta if (move.length() > 5.0 and moved < 0.25 * delta * 60.0) else max(0.0, stuck_t - delta)
    last_pos = global_position
    # the survivor's steps are kept while it waits too: called, it comes the
    # way he went, round the walls, not through them
    if mode in ["follow", "wait"] and game.player_death_time <= 0.0 and not mourning and trusted:
        _record_trail()
    _animate(move)


# ------------------------------------------------------------------ needs --
func _world_total_minutes() -> float:
    return float(game.world_day) * 1440.0 + float(game.world_minutes)


func _needs() -> void:
    var now = _world_total_minutes()
    if last_minutes < 0.0 or mode == "chained":
        last_minutes = now
        return
    var dm = clamp(now - last_minutes, 0.0, 4320.0)
    last_minutes = now
    if dm <= 0.0:
        return
    advance(dm)


func advance(minutes: float) -> void:
    # food and water run down with the world's clock (sleep included); rain
    # fills its water outside; only the time spent at the bottom costs health,
    # only the time spent fed and watered heals
    var food_rate = 100.0 / DogCatalog.FOOD_MINUTES
    var water_rate = 100.0 / DogCatalog.WATER_MINUTES
    var raining = str(game.weather_state) == "rain" and not (mode == "follow" and bool(game.is_sheltered))
    var food_left = food / food_rate                     # minutes until empty
    var water_left = INF if raining else water / water_rate
    var well = min(max(0.0, (food - 50.0) / food_rate), INF if raining else max(0.0, (water - 50.0) / water_rate))
    food = max(0.0, food - minutes * food_rate)
    if raining:
        water = min(100.0, water + minutes * 1.5)
    else:
        water = max(0.0, water - minutes * water_rate)
    var starving = max(0.0, minutes - food_left)
    var parched = max(0.0, minutes - water_left)
    hp -= (parched * 4.0 + max(0.0, starving - parched) * 2.5) / 60.0
    hp = min(DogCatalog.MAX_HP, hp + min(minutes, well) * 1.5 / 60.0)
    if mode == "follow" or global_position.distance_to(game.player.global_position) < 500.0:
        _complain()
    if hp <= 0.0:
        die("голод" if food <= 0.0 and parched <= 0.0 else "жажда")


func weak() -> bool:
    return food < DogCatalog.LOW or water < DogCatalog.LOW


func limping() -> bool:
    return hp < DogCatalog.MAX_HP * 0.5


func _complain() -> void:
    # a whine once on the way down, so the survivor knows without a bar
    var lines = []
    if water < DogCatalog.LOW and not _warned.has("water"):
        _warned["water"] = true
        lines.append("%s скулит и лижет губы - хочет пить." % dog_name)
    if food < DogCatalog.LOW and not _warned.has("food"):
        _warned["food"] = true
        lines.append("%s не отходит от рюкзака - %s." % [dog_name, DogCatalog.g(dog_name, "голодный", "голодная")])
    if water > 50.0:
        _warned.erase("water")
    if food > 50.0:
        _warned.erase("food")
    if not lines.is_empty():
        _voice("whine_1", -10.0)
        game._set_survival_feedback(" ".join(lines), 3.2)


# ---------------------------------------------------------------- chained --
func _chained(delta: float) -> void:
    var to = game.player.global_position - global_position
    var d = to.length()
    var clip = "idle"
    if d < 170.0 and game.player_death_time <= 0.0:
        facing = to / max(d, 0.001)
        if d < WARY:
            clip = "alert"
            if growl_cd <= 0.0:
                growl_cd = randf_range(2.6, 3.6)
                _voice("growl_%d" % (randi() % 2 + 1), -12.0)
    if facing.length() > 0.1:
        dir8 = int(round(fposmod(facing.angle(), TAU) / (PI * 0.25))) % 8
    var t = Time.get_ticks_msec() / 1000.0
    _set_clip(clip, int(t * (8.0 if clip == "alert" else 5.0)) % FRAMES[clip])
    if chain != null:
        var collar = Vector2(facing.x * 5.0, -8.0 + facing.y * 2.0)
        chain.points = PackedVector2Array([stake - global_position, (stake - global_position + collar) * 0.5 + Vector2(0, 3), collar])


func unchain() -> void:
    mode = "follow"
    trusted = true
    if chain != null:
        chain.queue_free()
        chain = null
    trail = []
    last_minutes = _world_total_minutes()


# --------------------------------------------------------------- survivor --
func _watch_survivor() -> void:
    # the survivor fell: it goes to him and stays; the next one is a stranger
    if game.player_death_time > 0.0:
        if not mourning:
            mourning = true
            trusted = false
            if mode == "follow":
                going_to = game.player.global_position + Vector2(18, 8)
            mode = "wait"
            trail = []
        return
    mourning = false


func _start_following() -> void:
    mode = "follow"
    going_to = Vector2(INF, INF)
    stuck_t = 0.0
    nav_path = []
    _rejoin_trail()


func _rejoin_trail() -> void:
    # pick up the survivor's trail at the nearest point it can see
    if trail.is_empty():
        return
    var order = range(trail.size())
    order.sort_custom(func(a, b): return global_position.distance_squared_to(trail[a]) < global_position.distance_squared_to(trail[b]))
    var start = order[0]
    for n in range(min(8, order.size())):
        if _clear_line(global_position, trail[order[n]]):
            start = order[n]
            break
    for k in range(start):
        trail.pop_front()


func command() -> String:
    # the wait / come key: returns what happened
    if dead or mode == "chained":
        return ""
    if not trusted:
        game._set_survival_feedback("%s не подходит: вы для %s чужой. Накормите." % [dog_name, DogCatalog.g(dog_name, "него", "неё")], 2.6)
        return "stranger"
    if mode == "follow":
        mode = "wait"
        going_to = Vector2(INF, INF)
        game._set_survival_feedback("%s, ждать. - %s садится и замирает." % [dog_name, dog_name], 2.2)
        return "wait"
    var d = global_position.distance_to(game.player.global_position)
    if d > WHISTLE:
        game._set_survival_feedback("Свист тонет вдали: %s слишком далеко." % dog_name, 2.4)
        return "far"
    _start_following()
    game._set_survival_feedback("%s, ко мне! - %s срывается с места." % [dog_name, dog_name], 2.2)
    return "come"


# ------------------------------------------------------------------ moving --
func _speed_mult() -> float:
    var m = 1.0
    if weak():
        m *= 0.85
    if limping():
        m *= 0.7
    return m


func _decide(delta: float) -> Vector2:
    var p = game.player.global_position
    if flee_t > 0.0:
        # bitten: it bolts behind the survivor, away from the teeth
        var behind = p + (p - flee_from).normalized() * 30.0
        return _toward(behind, RUN_SPEED * _speed_mult())
    if mode == "wait":
        if going_to.x < INF:
            if global_position.distance_to(going_to) < 8.0 or stuck_t > 2.0:
                going_to = Vector2(INF, INF)
                return Vector2.ZERO
            return _steer(going_to, TROT_SPEED * _speed_mult(), delta)
        return Vector2.ZERO
    var d = global_position.distance_to(p)
    if d > TELEPORT or (stuck_t > 1.6 and d > 220.0 and not _on_screen(global_position)) or (stuck_t > 4.0 and d > 120.0):
        _catch_up()
        return Vector2.ZERO
    if d < GAP:
        _prune_trail(18.0)
        return Vector2.ZERO
    skip_t -= delta
    if skip_t <= 0.0:
        skip_t = 0.3
        _skip_ahead()
    var target = p
    while not trail.is_empty() and global_position.distance_to(trail[0]) < 7.0:
        trail.pop_front()
    if not trail.is_empty():
        target = trail[0]
    var speed = RUN_SPEED if d > CATCH_UP else TROT_SPEED
    if d < GAP + 22.0:
        # settling in behind: ease off so it does not run into his heels
        speed *= clamp((d - GAP) / 22.0, 0.35, 1.0)
    return _steer(target, speed * _speed_mult(), delta)


func _steer(target: Vector2, speed: float, delta: float) -> Vector2:
    # straight when the way is open; round a wall on a short planned path
    var to = target - global_position
    nav_t -= delta
    if _clear_line(global_position, target) and not test_move(global_transform, to.limit_length(40.0)):
        nav_path = []
        return _toward(target, speed)
    if nav_path.is_empty() or nav_t <= 0.0 or nav_goal.distance_to(target) > 30.0:
        nav_t = 0.6
        nav_goal = target
        var res = Nav.plan(global_position, target, func(a, b):
            var t = global_transform
            t.origin = a
            return not test_move(t, b - a))
        nav_path = res.get("path", [])
    while not nav_path.is_empty() and global_position.distance_to(nav_path[0]) < 6.0:
        nav_path.pop_front()
    if nav_path.is_empty():
        return _toward(target, speed)
    return _toward(nav_path[0], speed)


func _toward(target: Vector2, speed: float) -> Vector2:
    var to = target - global_position
    if to.length() < 1.0:
        return Vector2.ZERO
    facing = to.normalized()
    return facing * speed


func _record_trail() -> void:
    var p = game.player.global_position
    if trail.is_empty() or trail[-1].distance_to(p) >= TRAIL_STEP:
        trail.append(p)
        while trail.size() > TRAIL_MAX:
            trail.pop_front()


func _prune_trail(r: float) -> void:
    while not trail.is_empty() and global_position.distance_to(trail[0]) < r:
        trail.pop_front()


func _skip_ahead() -> void:
    # cut the corner when the way ahead is clear: the newest point it can
    # see straight to (a handful of rays, newest first)
    if trail.size() < 2:
        return
    var checks = 0
    var i = trail.size() - 1
    while i > 0 and checks < 6:
        if _clear_line(global_position, trail[i]):
            for k in range(i):
                trail.pop_front()
            return
        checks += 1
        i -= max(1, trail.size() / 6)


func _catch_up() -> void:
    # out of sight it closes up at once - to a point on his trail the
    # survivor cannot see, so it is never seen to appear
    var spot = Vector2(INF, INF)
    var cut = -1
    for i in range(trail.size() - 1, -1, -1):
        var q = trail[i]
        if q.distance_to(game.player.global_position) >= 90.0 and not _on_screen(q):
            spot = q
            cut = i
            break
    if spot.x == INF:
        if not trail.is_empty():
            spot = trail[0]
            cut = 0
        else:
            spot = game.player.global_position - game.aim_direction.normalized() * 40.0
    global_position = spot
    last_pos = spot
    stuck_t = 0.0
    for k in range(max(0, cut + 1)):
        trail.pop_front()


func _on_screen(pos: Vector2) -> bool:
    var vp = get_viewport()
    if vp == null:
        return false
    var xf = vp.get_canvas_transform()
    var sc = xf.get_scale()
    if sc.x <= 0.0:
        return false
    var rect = Rect2(-xf.origin / sc, vp.get_visible_rect().size / sc)
    return rect.grow(16.0).has_point(pos)


func _clear_line(a: Vector2, b: Vector2) -> bool:
    var q = PhysicsRayQueryParameters2D.create(a, b)
    q.collision_mask = game.LAYER_WORLD
    q.exclude = [get_rid()]
    return game.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


# ----------------------------------------------------------------- senses --
func _alive_infected() -> Array:
    var out = []
    for e in get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e) and float(e.get_meta("hp", 1.0)) > 0.0 and not e.is_queued_for_deletion():
            out.append(e)
    return out


func survivor_sees(e) -> bool:
    var p = game.player.global_position
    var d = p.distance_to(e.global_position)
    var night = game._time_night_factor()
    var lit = game.flashlight_on and night > 0.3
    var reach = game.fog_sight_limit(lit)
    if night > 0.5 and not lit:
        reach = min(reach, lerp(420.0, 150.0, night))
    if d > reach or not _on_screen(e.global_position):
        return false
    var q = PhysicsRayQueryParameters2D.create(p, e.global_position)
    q.collision_mask = game.LAYER_WORLD
    q.exclude = [game.player.get_rid()]
    return game.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _sense() -> void:
    if game.player_death_time > 0.0:
        sensed = null
        return
    var nose = SENSE * (0.6 if weak() else 1.0)
    var best = null
    var best_d = INF
    var bark_at = null
    var bark_d = INF
    for e in _alive_infected():
        var d = global_position.distance_to(e.global_position)
        if d > nose:
            continue
        if not survivor_sees(e):
            if d < best_d:
                best_d = d
                best = e
        elif d < BARK_SEE and d < bark_d and _clear_line(global_position, e.global_position):
            var st = str(e.get_meta("ai_state", "idle"))
            if st in ["chase", "investigate", "search"] or d < 120.0:
                bark_d = d
                bark_at = e
    sensed = best
    if best != null:
        alert_t = 0.6
        if velocity.length() < 5.0:
            facing = (best.global_position - global_position).normalized()
        if growl_cd <= 0.0:
            growl_cd = randf_range(3.0, 4.6)
            _voice("growl_%d" % (randi() % 2 + 1), -11.0 if best_d < 200.0 else -15.0)
    if bark_at != null:
        _maybe_bark(bark_at, bark_d)


func _maybe_bark(e, d: float) -> void:
    if bark_cd > 0.0 or mode == "wait":
        return
    # while the survivor sneaks it holds its tongue - unless they are on it
    if game.is_crouching and d > 70.0:
        return
    bark_cd = randf_range(2.4, 4.2)
    if velocity.length() < 5.0:
        facing = (e.global_position - global_position).normalized()
    alert_t = 0.8
    _voice("bark_%d" % (randi() % 3 + 1), -6.0)
    game._emit_ai_sound(global_position, BARK_RADIUS, "dog_bark", 1.0, self)


func _bitten() -> void:
    if bite_cd > 0.0:
        return
    for e in _alive_infected():
        if e.global_position.distance_to(global_position) >= BITE_RANGE:
            continue
        if not str(e.get_meta("ai_state", "idle")) in ["chase", "investigate", "search"]:
            continue
        bite_cd = 1.0
        take_damage(float(e.get_meta("attack_damage", 8.0)), e.global_position)
        return


func take_damage(amount: float, from: Vector2) -> void:
    if dead or mode == "chained":
        return
    hp -= amount
    hurt_t = 0.3
    flee_t = 1.4
    flee_from = from
    _voice("yelp_1", -7.0)
    if game.has_method("_blood_hit"):
        game._blood_hit(global_position, (global_position - from).normalized(), hp <= 0.0)
    if mode == "wait" and trusted and hp > 0.0:
        # left alone and bitten, it runs to the survivor
        _start_following()
    if hp <= 0.0:
        die("заражённые")


func die(cause: String) -> void:
    if dead:
        return
    dead = true
    hp = 0.0
    remove_from_group("interactable")
    _set_clip("lie", 1)
    if cause != "заражённые":
        _voice("whine_1", -12.0)
    if game.has_method("_on_dog_died"):
        game._on_dog_died(self, cause)


# ---------------------------------------------------------------- care (E) --
func need() -> String:
    # what E on it does now, or "" when there is nothing to do
    if dead:
        return ""
    if mode == "chained":
        return "adopt"
    if not trusted:
        return "befriend"
    if limping() and _first(DogCatalog.BANDAGES) != "":
        return "bandage"
    if water < DogCatalog.FEED_BELOW and _drink_source() != "":
        return "water"
    if food < DogCatalog.FEED_BELOW and _first(DogCatalog.FOODS) != "":
        return "food"
    if mode == "wait":
        return "call"
    return ""


func prompt_text() -> String:
    match need():
        "adopt":
            if game.dog != null and is_instance_valid(game.dog) and not game.dog.dead:
                return "ПЁС НА ЦЕПИ  •  ВТОРОГО НЕ ПРОКОРМИТЬ"
            return "НАКОРМИТЬ И ОТВЯЗАТЬ  •  ПЁС НА ЦЕПИ" if _first(DogCatalog.FOODS) != "" else "ПЁС НА ЦЕПИ  •  НУЖНА ЕДА"
        "befriend":
            return "НАКОРМИТЬ  •  %s ВАС НЕ ЗНАЕТ" % dog_name.to_upper() if _first(DogCatalog.FOODS) != "" else "%s ВАС НЕ ЗНАЕТ  •  НУЖНА ЕДА" % dog_name.to_upper()
        "bandage":
            return "ПЕРЕВЯЗАТЬ  •  %s" % dog_name.to_upper()
        "water":
            return "НАПОИТЬ  •  %s" % dog_name.to_upper()
        "food":
            return "НАКОРМИТЬ  •  %s" % dog_name.to_upper()
        "call":
            return "ПОЗВАТЬ  •  %s ЖДЁТ" % dog_name.to_upper()
    return dog_name.to_upper()


func wants_attention() -> bool:
    # a dog at heel that needs nothing stays out of the E prompt (G works)
    if dead:
        return false
    if mode == "chained" or mode == "wait" or not trusted:
        return true
    # at heel it asks only when it really needs it - a top-up stays possible
    # at a pump, and the prompt does not hang over it all day
    match need():
        "bandage":
            return true
        "water":
            return water < DogCatalog.ASK_BELOW
        "food":
            return food < DogCatalog.ASK_BELOW
    return false


func care() -> String:
    var n = need()
    match n:
        "adopt", "befriend":
            if n == "adopt" and game.dog != null and is_instance_valid(game.dog) and not game.dog.dead:
                game._set_survival_feedback("Одного пса бы прокормить. Этот пусть ждёт.", 2.6)
                return ""
            var f = _first(DogCatalog.FOODS)
            if f == "":
                game._set_survival_feedback("%s скалится. Без еды не подпустит." % ("Пёс" if n == "adopt" else dog_name), 2.4)
                return ""
            game._consume_inventory_item(f, 1)
            food = min(100.0, food + 45.0)
            if n == "adopt":
                game._adopt_dog(self)
            else:
                trusted = true
                trail = []
                _start_following()
                game._set_survival_feedback("%s нюхает руку, съедает всё - и идёт за вами." % dog_name, 3.0)
        "bandage":
            var b = _first(DogCatalog.BANDAGES)
            game._consume_inventory_item(b, 1)
            hp = min(DogCatalog.MAX_HP, hp + (40.0 if b == "sterile_bandage" else 30.0))
            game._play_world_sfx("bandage", -10.0, 0.03)
            game._set_survival_feedback("Вы перевязали %s. %s лижет вам руку." % [_acc(), dog_name], 2.4)
        "water":
            _drink_from_pack()
            game._play_world_sfx("drink", -12.0, 0.03)
            game._set_survival_feedback("%s жадно лакает." % dog_name, 2.0)
        "food":
            var f2 = _first(DogCatalog.FOODS)
            game._consume_inventory_item(f2, 1)
            food = min(100.0, food + 45.0)
            game._set_survival_feedback("%s съедает всё в два глотка." % dog_name, 2.0)
        "call":
            _start_following()
            game._set_survival_feedback("%s вскакивает и идёт за вами." % dog_name, 2.0)
        _:
            return ""
    if game.has_method("_refresh_inventory_ui"):
        game._refresh_inventory_ui()
    return n


func _acc() -> String:
    # «Найду», «Альму»; the male names do not change
    if dog_name.ends_with("а"):
        return dog_name.substr(0, dog_name.length() - 1) + "у"
    return dog_name


func _first(ids: Array) -> String:
    for id in ids:
        if game._inventory_count(id) > 0:
            return id
    return ""


func _drink_source() -> String:
    var id = _first(DogCatalog.DRINKS)
    if id != "":
        return id
    game._ensure_runtime_item_instance_ids()
    for entry in game.inventory_entries:
        var item_id = str(entry.get("id", ""))
        if game._is_water_container_item(item_id) and game._water_container_fill_l(item_id, str(entry.get("instance_id", ""))) >= 0.5:
            return "flask"
    return ""


func _drink_from_pack() -> void:
    var id = _first(DogCatalog.DRINKS)
    if id != "":
        game._consume_inventory_item(id, 1)
        water = 100.0
        return
    for entry in game.inventory_entries:
        var item_id = str(entry.get("id", ""))
        var iid = str(entry.get("instance_id", ""))
        if game._is_water_container_item(item_id):
            var fill = game._water_container_fill_l(item_id, iid)
            if fill >= 0.5:
                game._set_water_container_fill_l(item_id, iid, fill - 0.5)
                water = 100.0
                return


func drink_at_pump(pump_pos: Vector2) -> bool:
    # the survivor works the pump: the dog drinks too, if it is with him
    if dead or mode == "chained" or global_position.distance_to(pump_pos) > 220.0:
        return false
    water = 100.0
    _warned.erase("water")
    return true


# -------------------------------------------------------------- animation --
func _sheet(clip: String) -> Texture2D:
    if not _sheets.has(clip):
        _sheets[clip] = load("res://art/dog/dog_%s.png" % clip)
    return _sheets[clip]


func _set_clip(clip: String, frame: int) -> void:
    if _clip != clip:
        _clip = clip
        sprite.texture = _sheet(clip)
    sprite.region_rect = Rect2(frame * CELL, dir8 * CELL, CELL, CELL)


func current_clip() -> String:
    return _clip


func _animate(move: Vector2) -> void:
    if facing.length() > 0.1:
        dir8 = int(round(fposmod(facing.angle(), TAU) / (PI * 0.25))) % 8
    var t = Time.get_ticks_msec() / 1000.0
    if move.length() > 5.0:
        var clip = "run" if move.length() > TROT_SPEED * 1.08 else "walk"
        var n = FRAMES[clip]
        # a limp: the stride drags
        var stride = STRIDE[clip] * (1.3 if limping() else 1.0)
        _set_clip(clip, int(fposmod(walk_dist / stride, 1.0) * n) % n)
    elif mode == "wait":
        _set_clip("sit", int(t * 3.0) % FRAMES["sit"])
    elif alert_t > 0.0 or sensed != null:
        _set_clip("alert", int(t * 8.0) % FRAMES["alert"])
    else:
        _set_clip("idle", int(t * 5.0 + get_instance_id() % 5) % FRAMES["idle"])
    sprite.position = SPRITE_OFFSET


# ------------------------------------------------------------------ voice --
func _voice(clip: String, db: float) -> void:
    if voice == null or bool(game.get("self_test_silent")):
        return
    var stream = game._cached_weapon_audio("res://audio/dog/%s.wav" % clip)
    if stream == null:
        return
    voice.stream = stream
    voice.volume_db = db
    voice.pitch_scale = randf_range(0.95, 1.05)
    voice.play()
