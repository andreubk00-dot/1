extends CharacterBody2D
# A marauder: a living survivor turned raider. Drawn on the player's rig with
# their own clothes (art/marauders/<outfit>_<weapon>_<clip>.png), they patrol
# with their squad along the roads, pilfer containers, notice the player by
# sight and sound, fight from range with cover and flanking, reload behind
# walls, flee or surrender when it goes badly, and leave a searchable body.
# Infected drawn by their shots maul them; they shoot back.

const Nav = preload("res://world/local_navigation.gd")

const CELL = 128
const SPRITE_SCALE = 0.5
const SPRITE_OFFSET = Vector2(0, -7.5)
const FRAMES = {"Idle": 8, "Walk": 12, "Run": 12, "Attack1": 8, "TakeDamage": 8, "Die": 8}
const WALK_SPEED = 36.0
const COMBAT_SPEED = 56.0
const RUN_SPEED = 74.0
const STRIDE = {"Walk": 34.0, "Run": 46.0}

# per weapon: preferred range, damage to the player per hit, rounds, timing
const ARMS = {
    "makarov": {"range": 120.0, "reach": 330.0, "damage": 8.0, "mag": 8, "burst": 1, "gap": [0.6, 1.1], "reload": 1.6, "pellets": 1, "accuracy": 0.6},
    "akm": {"range": 210.0, "reach": 470.0, "damage": 11.0, "mag": 30, "burst": 3, "gap": [0.9, 1.6], "reload": 2.6, "pellets": 1, "accuracy": 0.5},
    "shotgun": {"range": 80.0, "reach": 220.0, "damage": 4.0, "mag": 5, "burst": 1, "gap": [1.1, 1.5], "reload": 3.2, "pellets": 7, "accuracy": 0.55},
}

const BARKS = {
    "notice": ["Там кто-то есть...", "Слышал?", "Тихо... движение."],
    "spot": ["Вон он!", "Контакт!", "Стоять, сука!", "Видишь его?!"],
    "reload": ["Перезаряжаю!", "Прикрой!", "Пустой!"],
    "flank": ["Обходи слева!", "Захожу справа!", "Дави его!"],
    "hurt": ["А-а, задело!", "Меня зацепило!"],
    "flee": ["Отходим!", "Валим отсюда!", "Не, я пас!"],
    "surrender": ["Не стреляй! Сдаюсь!", "Всё, всё! Не надо!"],
    "lost": ["Ушёл, гад.", "Где он?..", "Проверь там."],
    "loot": ["Шмонаем.", "Глянь, что тут.", "Пусто почти."],
    "infected": ["Твари!", "Сзади мертвяк!", "Отбивайся!"],
    "warn": ["Иди своей дорогой.", "Не подходи.", "Мы тебя не трогаем."],
    "aim": ["Опусти ствол!", "Ствол убрал, быстро!"],
    "friend_down": ["Сеню завалили!", "Он наших кладёт!"],
}

var game = null
var squad = null
var outfit = "bandit"
var weapon = "makarov"
var personality = "hostile"   # hostile | coward | neutral
var slot = 0                  # 0 leader, 1.. followers
var hp = 100.0
var max_hp = 100.0
var state = "patrol"
var facing = Vector2.DOWN
var dir8 = 2
var mag = 8
var reserve = 16
var awareness = 0.0
var last_seen_pos = Vector2.ZERO
var last_seen_time = -999.0
var heard_pos = Vector2.ZERO
var think_t = 0.0
var fire_t = 0.0
var burst_left = 0
var reload_t = 0.0
var strafe_sign = 1.0
var strafe_t = 0.0
var state_t = 0.0
var path = []
var path_goal = Vector2(INF, INF)
var replan_t = 0.0
var walk_dist = 0.0
var attack_anim = 0.0
var hurt_anim = 0.0
var dead = false
var die_t = 0.0
var bark_cd = 0.0
var contact_t = 0.0
var aim_warn_t = 0.0
var hostile_to_player = true
var target_infected = null
var flee_t = 0.0
var surrendered = false
var cover_goal = Vector2(INF, INF)
var stuck_t = 0.0
var last_pos = Vector2.ZERO
var loot_t = 0.0
var weapon_dropped = false
var engaged_at = 0.0

var sprite: Sprite2D = null
var shadow: Polygon2D = null
var bark_label: Label = null
var bark_life = 0.0
var voice: AudioStreamPlayer2D = null
var lamp: PointLight2D = null
var _clip = ""
var _sheets = {}
# dev64: voice, steps, hit reactions, doors
var mouth: AudioStreamPlayer2D = null
var gear: AudioStreamPlayer2D = null
var voice_id = 0
var step_mark = 0.0
var stagger_t = 0.0
var knock = Vector2.ZERO
var flinch_t = 0.0
var door_t = 0.0
# dev65: base garrison - posts keep their men on a leash, towers see further
var leash_pos = Vector2(INF, INF)
var leash = 0.0
var sight_mult = 1.0
var post_id = ""


func setup(p_game, p_outfit: String, p_weapon: String, p_personality: String) -> void:
    game = p_game
    outfit = p_outfit
    weapon = p_weapon
    personality = p_personality
    hostile_to_player = personality in ["hostile", "coward"]
    var arms = ARMS[weapon]
    mag = int(arms["mag"])
    reserve = randi_range(int(arms["mag"]) / 2, int(arms["mag"]) * 2)
    max_hp = 110.0 if outfit == "deserter" else (90.0 if outfit == "gopnik" else 100.0)
    hp = max_hp
    state = "neutral" if personality == "neutral" else "patrol"
    voice_id = randi() % 4


func _ready() -> void:
    add_to_group("marauders")
    set_meta("is_enemy", true)
    set_meta("is_marauder", true)
    collision_layer = game.LAYER_ENEMY
    collision_mask = game.LAYER_WORLD
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    z_index = 9
    z_as_relative = false
    var shape = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = 6.0
    shape.shape = circle
    add_child(shape)
    shadow = Polygon2D.new()
    var pts = PackedVector2Array()
    for i in range(16):
        var a = TAU * i / 16.0
        pts.append(Vector2(cos(a) * 9.0, 12.0 + sin(a) * 3.5))
    shadow.polygon = pts
    shadow.color = Color(0.02, 0.02, 0.02, 0.26)
    shadow.z_index = -2
    add_child(shadow)
    sprite = Sprite2D.new()
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.region_enabled = true
    sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
    sprite.position = SPRITE_OFFSET
    sprite.z_index = 1
    add_child(sprite)
    bark_label = Label.new()
    bark_label.add_theme_font_size_override("font_size", 6)
    bark_label.add_theme_color_override("font_color", Color(0.93, 0.91, 0.84))
    bark_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05))
    bark_label.add_theme_constant_override("outline_size", 2)
    bark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bark_label.size = Vector2(150, 12)
    bark_label.position = Vector2(-75, -52)
    bark_label.z_index = 40
    bark_label.visible = false
    add_child(bark_label)
    voice = AudioStreamPlayer2D.new()
    voice.bus = "SFX"
    voice.max_distance = 1100.0
    voice.attenuation = 1.4
    add_child(voice)
    mouth = AudioStreamPlayer2D.new()
    mouth.bus = "SFX"
    mouth.max_distance = 700.0
    mouth.attenuation = 1.6
    add_child(mouth)
    gear = AudioStreamPlayer2D.new()
    gear.bus = "SFX"
    gear.max_distance = 420.0
    gear.attenuation = 1.8
    add_child(gear)
    if game.player_light != null and game.player_light.texture != null:
        lamp = PointLight2D.new()
        lamp.texture = game.player_light.texture
        lamp.energy = 0.0
        lamp.texture_scale = 0.55
        lamp.color = Color(1.0, 0.93, 0.78)
        add_child(lamp)
    last_pos = global_position
    _set_clip("Idle", 0)


# ----------------------------------------------------------------- frame --
func _physics_process(delta: float) -> void:
    if game == null or game.player == null:
        return
    if dead:
        _update_dying(delta)
        return
    bark_cd = max(0.0, bark_cd - delta)
    fire_t = max(0.0, fire_t - delta)
    attack_anim = max(0.0, attack_anim - delta)
    hurt_anim = max(0.0, hurt_anim - delta)
    state_t += delta
    _update_bark(delta)
    _update_lamp()
    if reload_t > 0.0:
        reload_t -= delta
        if reload_t <= 0.0:
            var arms = ARMS[weapon]
            var need = int(arms["mag"]) - mag
            var take = min(need, reserve)
            mag += take
            reserve -= take
    think_t -= delta
    flinch_t = max(0.0, flinch_t - delta)
    door_t = max(0.0, door_t - delta)
    if think_t <= 0.0:
        think_t = 0.15
        _perceive()
        _infected_contact(0.15)
    var move = Vector2.ZERO
    if stagger_t > 0.0:
        # knocked back by a hit: the body is carried, then the legs catch it
        stagger_t -= delta
        move = knock
        knock = knock.move_toward(Vector2.ZERO, delta * 520.0)
    else:
        move = _decide(delta)
        if move.length() > 5.0:
            _open_door_ahead(move)
    velocity = move
    move_and_slide()
    var moved = global_position.distance_to(last_pos)
    walk_dist += moved
    stuck_t = stuck_t + delta if (move.length() > 5.0 and moved < 0.2) else max(0.0, stuck_t - delta)
    last_pos = global_position
    _footsteps(move)
    _animate(move)


# ------------------------------------------------------------ perception --
func _player_visible() -> bool:
    var p = game.player.global_position
    var to = p - global_position
    var d = to.length()
    var night = game._time_night_factor()
    var reach = lerp(330.0, 170.0, night)
    if game.flashlight_on and night > 0.3:
        reach = max(reach, 320.0)
    reach *= sight_mult
    if game.is_crouching:
        reach *= 0.7
    if d > reach:
        return false
    # alert eyes see all round, a patrol looks ahead
    var fov = -0.25 if state in ["combat", "investigate", "search"] else 0.35
    if d > 40.0 and facing.dot(to / max(d, 0.001)) < fov:
        return false
    return _clear_line(global_position, p)


func _clear_line(a: Vector2, b: Vector2) -> bool:
    var q = PhysicsRayQueryParameters2D.create(a, b)
    q.collision_mask = game.LAYER_WORLD
    q.exclude = [get_rid()]
    return game.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _perceive() -> void:
    if game.player_death_time > 0.0:
        return
    var now = Time.get_ticks_msec() / 1000.0
    if _player_visible():
        var d = global_position.distance_to(game.player.global_position)
        awareness = min(1.5, awareness + (0.55 + 1.6 * clamp(1.0 - d / 330.0, 0.0, 1.0)) * 0.15)
        last_seen_pos = game.player.global_position
        last_seen_time = now
    else:
        awareness = max(0.0, awareness - 0.04)
    if surrendered or state == "flee":
        return
    if not hostile_to_player:
        _neutral_watch()
        return
    if awareness >= 1.0 and state != "combat":
        _enter_combat(true)
    elif awareness >= 0.45 and state in ["patrol", "loot"]:
        _set_state("investigate")
        heard_pos = last_seen_pos
        _bark("notice")


func hear(origin: Vector2, radius: float, kind: String) -> void:
    if dead or surrendered:
        return
    var d = global_position.distance_to(origin)
    if d > radius:
        return
    if not hostile_to_player:
        # a shot close by makes a neutral wanderer an enemy
        if kind == "gunshot" and origin.distance_to(game.player.global_position) < 40.0 and d < 160.0:
            become_hostile()
        return
    if state == "combat":
        if kind == "gunshot" and origin.distance_to(game.player.global_position) < 60.0:
            last_seen_pos = origin
        return
    heard_pos = origin
    if kind == "gunshot":
        _enter_combat(false)
        last_seen_pos = origin
    elif state in ["patrol", "loot"]:
        _set_state("investigate")
        _bark("notice")


func _neutral_watch() -> void:
    var p = game.player.global_position
    var to = global_position - p
    var d = to.length()
    if d > 280.0 or not _clear_line(global_position, p):
        aim_warn_t = max(0.0, aim_warn_t - 0.15)
        return
    if d < 150.0 and state_t > 3.0:
        _bark("warn")
    # a gun pointed at them for long enough is a threat
    var aimed = game.aim_direction.dot(to / max(d, 0.001)) > 0.965 and (game.equipped_melee_id == "")
    aim_warn_t = aim_warn_t + 0.15 if aimed else max(0.0, aim_warn_t - 0.1)
    if aim_warn_t > 1.4 and aim_warn_t < 1.6:
        _bark("aim", true)
    if aim_warn_t > 4.2:
        become_hostile()


func become_hostile() -> void:
    if hostile_to_player or dead:
        return
    hostile_to_player = true
    personality = "hostile"
    _enter_combat(true)
    if squad != null:
        squad.alert(self, game.player.global_position)


func _enter_combat(seen: bool) -> void:
    if state == "combat":
        return
    _set_state("combat")
    # bringing the gun up and finding the target takes a moment
    fire_t = max(fire_t, randf_range(0.7, 1.2))
    if seen:
        _bark("spot", true)
    if squad != null:
        squad.alert(self, last_seen_pos if seen else heard_pos)


func squad_alert(pos: Vector2) -> void:
    if dead or surrendered or not hostile_to_player or state in ["combat", "flee"]:
        return
    last_seen_pos = pos
    heard_pos = pos
    _set_state("combat")
    fire_t = max(fire_t, randf_range(0.9, 1.5))


func _set_state(s: String) -> void:
    if state == s:
        return
    if s == "combat":
        engaged_at = Time.get_ticks_msec() / 1000.0
    state = s
    state_t = 0.0
    path = []
    path_goal = Vector2(INF, INF)
    cover_goal = Vector2(INF, INF)


# ------------------------------------------------------------- decisions --
func _decide(delta: float) -> Vector2:
    match state:
        "neutral":
            return _patrol_move(delta, WALK_SPEED * 0.9)
        "patrol":
            return _patrol_move(delta, WALK_SPEED)
        "loot":
            loot_t -= delta
            if loot_t <= 0.0:
                _set_state("patrol")
            return Vector2.ZERO
        "investigate":
            if global_position.distance_to(heard_pos) < 22.0 or state_t > 12.0:
                _set_state("search" if state_t <= 12.0 else "patrol")
                return Vector2.ZERO
            return _go_to(heard_pos, WALK_SPEED * 1.15, delta)
        "search":
            if state_t > 12.0:
                _bark("lost")
                _set_state("patrol")
                return Vector2.ZERO
            # go and look where the target was last seen, then look round
            if global_position.distance_to(heard_pos) > 26.0 and state_t < 9.0:
                return _go_to(heard_pos, WALK_SPEED * 1.2, delta)
            facing = facing.rotated(delta * 1.6)
            return Vector2.ZERO
        "combat":
            return _combat_move(delta)
        "flee":
            flee_t -= delta
            var away = (global_position - game.player.global_position).normalized()
            if flee_t <= 0.0 and not _player_visible():
                hp = min(max_hp, hp + 30.0)
                _set_state("combat" if hostile_to_player and not surrendered else "patrol")
            return _go_to(global_position + away * 140.0, RUN_SPEED, delta)
        "surrender":
            if state_t > 6.0:
                flee_t = 30.0
                _set_state("flee")
            facing = (game.player.global_position - global_position).normalized()
            return Vector2.ZERO
    return Vector2.ZERO


func _patrol_move(delta: float, speed: float) -> Vector2:
    if squad == null:
        return Vector2.ZERO
    var goal = squad.slot_target(self)
    if global_position.distance_to(goal) < 8.0:
        if squad.has_method("idle_look"):
            squad.idle_look(self, delta)
        return Vector2.ZERO
    var s = speed * (1.25 if slot > 0 and global_position.distance_to(goal) > 40.0 else 1.0)
    return _go_to(goal, s, delta)


func _combat_move(delta: float) -> Vector2:
    var now = Time.get_ticks_msec() / 1000.0
    var p = game.player.global_position
    var arms = ARMS[weapon]
    # infected right on top of them come first
    target_infected = _threatening_infected()
    var sees = (now - last_seen_time) < 0.35
    if hp < max_hp * 0.3 and personality != "fanatic":
        set_meta("flee_reason", "hp")
        flee_t = 9.0
        _bark("flee", true)
        _set_state("flee")
        return Vector2.ZERO
    if personality == "coward" and hp < max_hp * 0.55 and not surrendered:
        _surrender()
        return Vector2.ZERO
    if target_infected != null:
        var ti = target_infected.global_position
        facing = (ti - global_position).normalized()
        _try_fire_at(ti, target_infected)
        return (global_position - ti).normalized() * COMBAT_SPEED * 0.6
    if game.player_death_time > 0.0:
        _set_state("patrol")
        return Vector2.ZERO
    if mag <= 0:
        if reserve <= 0:
            set_meta("flee_reason", "ammo")
            flee_t = 12.0
            _bark("flee", true)
            _set_state("flee")
            return Vector2.ZERO
        if reload_t <= 0.0:
            reload_t = float(arms["reload"])
            _bark("reload")
            _play_gear(game._weapon_reload_audio_path(weapon), -9.0)
        # reload from behind something
        return _seek_cover(p, delta)
    if reload_t > 0.0:
        return _seek_cover(p, delta)
    if not sees:
        if now - last_seen_time > 14.0:
            heard_pos = last_seen_pos
            _set_state("search")
            _bark("lost")
            return Vector2.ZERO
        # close in on the last known position (followers come round the side)
        var lk = last_seen_pos + _flank_offset(last_seen_pos) * 0.5
        return _go_to(lk, COMBAT_SPEED, delta)
    var to = p - global_position
    var d = to.length()
    facing = to / max(d, 0.001)
    if d <= float(arms["reach"]):
        _try_fire_at(p, null)
    # hold the weapon's range; followers drift round the flanks
    var want = float(arms["range"])
    var goal = p - facing * want + _flank_offset(p)
    var move = Vector2.ZERO
    if abs(d - want) > 35.0 or slot > 0:
        move = _go_to(goal, COMBAT_SPEED, delta)
    strafe_t -= delta
    if strafe_t <= 0.0:
        strafe_t = randf_range(1.2, 2.6)
        strafe_sign = -strafe_sign
    var side = Vector2(-facing.y, facing.x) * strafe_sign * COMBAT_SPEED * 0.55
    if _free_step(side * 0.25):
        move += side
    return move.limit_length(COMBAT_SPEED)


func _flank_offset(p: Vector2) -> Vector2:
    if slot == 0 or squad == null or squad.leader() == null:
        return Vector2.ZERO
    var lead_dir = (squad.leader().global_position - p)
    if lead_dir.length() < 1.0:
        lead_dir = Vector2.RIGHT
    var ang = (1.0 if slot % 2 == 1 else -1.0) * deg_to_rad(70.0)
    var want = lead_dir.normalized().rotated(ang) * ARMS[weapon]["range"]
    return want - (global_position - p).normalized() * ARMS[weapon]["range"]


func _seek_cover(p: Vector2, delta: float) -> Vector2:
    if cover_goal.x == INF or state_t > 6.0 and global_position.distance_to(cover_goal) < 6.0:
        cover_goal = _find_cover(p)
        if cover_goal.x == INF:
            # nowhere to hide: back away
            return (global_position - p).normalized() * COMBAT_SPEED * 0.7
    if global_position.distance_to(cover_goal) < 6.0:
        facing = (p - global_position).normalized()
        return Vector2.ZERO
    return _go_to(cover_goal, RUN_SPEED * 0.9, delta)


func _find_cover(p: Vector2) -> Vector2:
    var best = Vector2(INF, INF)
    var best_d = INF
    for i in range(12):
        var a = TAU * i / 12.0
        for r in [36.0, 64.0, 92.0]:
            var c = global_position + Vector2(cos(a), sin(a)) * r
            if _clear_line(c, p):
                continue
            if not _free_at(c):
                continue
            var dd = c.distance_to(global_position) + (0.0 if c.distance_to(p) > 90.0 else 200.0)
            if dd < best_d:
                best_d = dd
                best = c
    return best


func _free_at(c: Vector2) -> bool:
    var q = PhysicsShapeQueryParameters2D.new()
    var sh = CircleShape2D.new()
    sh.radius = 7.0
    q.shape = sh
    q.transform = Transform2D(0, c)
    q.collision_mask = game.LAYER_WORLD
    return game.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _free_step(v: Vector2) -> bool:
    return not test_move(global_transform, v)


func _go_to(goal: Vector2, speed: float, delta: float) -> Vector2:
    if leash > 0.0 and goal.distance_to(leash_pos) > leash:
        # a sentry fights from his post, he does not leave it
        goal = leash_pos + (goal - leash_pos).limit_length(leash)
    var to = goal - global_position
    if to.length() < 4.0:
        return Vector2.ZERO
    replan_t -= delta
    if path.is_empty() or replan_t <= 0.0 or path_goal.distance_to(goal) > 30.0 or stuck_t > 0.6:
        replan_t = 0.7
        path_goal = goal
        stuck_t = 0.0
        if _clear_line(global_position, goal) and not test_move(global_transform, to.limit_length(60.0)):
            path = [goal]
        else:
            var res = Nav.plan(global_position, goal, func(a, b):
                var t = global_transform
                t.origin = a
                return not test_move(t, b - a))
            path = res.get("path", [])
            if path.is_empty():
                # the goal is behind walls: make for the door that leads there
                var door = _door_toward(goal)
                if door != null:
                    # through the doorway: a step in front of it, the gap
                    # itself (the leaf sits in the wall), a step beyond
                    var dp = door.global_position
                    var approach = dp + (global_position - dp).normalized() * 22.0
                    var beyond = dp + (goal - dp).normalized() * 24.0
                    path = []
                    if global_position.distance_to(dp) > 30.0:
                        var r2 = Nav.plan(global_position, approach, func(a, b):
                            var t2 = global_transform
                            t2.origin = a
                            return not test_move(t2, b - a))
                        path = r2.get("path", [])
                        if path.is_empty():
                            path = [approach]
                    path.append(dp)
                    path.append(beyond)
                else:
                    path = [global_position + to.limit_length(40.0).rotated(randf_range(-1.0, 1.0))]
    while not path.is_empty() and global_position.distance_to(path[0]) < 6.0:
        path.pop_front()
    if path.is_empty():
        return Vector2.ZERO
    var dir = (path[0] - global_position).normalized()
    if state != "combat" or (Time.get_ticks_msec() / 1000.0 - last_seen_time) > 0.35:
        facing = facing.lerp(dir, 0.25).normalized()
    return dir * speed


# ---------------------------------------------------------------- weapon --
func _try_fire_at(target_pos: Vector2, infected) -> void:
    if weapon_dropped or fire_t > 0.0 or reload_t > 0.0 or mag <= 0:
        return
    if not _clear_line(global_position, target_pos):
        return
    var arms = ARMS[weapon]
    if burst_left <= 0:
        burst_left = int(arms["burst"])
    _fire(target_pos, infected)
    burst_left -= 1
    fire_t = 0.11 if burst_left > 0 else randf_range(float(arms["gap"][0]), float(arms["gap"][1]))


func _fire(target_pos: Vector2, infected) -> void:
    var arms = ARMS[weapon]
    mag -= 1
    attack_anim = 0.3
    var dir = (target_pos - global_position).normalized()
    facing = dir
    var muzzle = global_position + Vector2(0, -9) + dir * 15.0
    var stream = game._cached_weapon_audio("res://audio/weapons/%s_shot.wav" % weapon)
    if stream != null:
        voice.stream = stream
        voice.volume_db = float(game.weapon_defs.get(weapon, {}).get("shot_volume_db", -8.0)) + 1.0
        voice.pitch_scale = randf_range(0.97, 1.03)
        voice.play()
    game._emit_ai_sound(global_position, float(game.weapon_defs.get(weapon, {}).get("noise", 600.0)), "gunshot", 1.0, self)
    _muzzle_flash(muzzle, dir)
    var d = global_position.distance_to(target_pos)
    if infected != null:
        if randf() < 0.6:
            game._damage_enemy(infected, float(game.weapon_defs.get(weapon, {}).get("damage", 30.0)), dir)
            game._spawn_temp_tracer(muzzle, target_pos, 0.06)
        else:
            game._spawn_temp_tracer(muzzle, target_pos + dir.rotated(PI * 0.5) * randf_range(-14.0, 14.0), 0.06)
        return
    # against the player: range, the player's motion, crouching and the dark all help
    var settle = clamp((Time.get_ticks_msec() / 1000.0 - engaged_at) / 4.0, 0.0, 1.0)
    var chance = float(arms["accuracy"]) * lerp(0.6, 1.0, settle) - d / float(arms["reach"]) * 0.4
    if game.player.velocity.length() > 40.0:
        chance -= 0.16 if game.is_sprinting else 0.08
    if game.is_crouching:
        chance -= 0.1
    chance -= game._time_night_factor() * (0.05 if game.flashlight_on else 0.18)
    if flinch_t > 0.0:
        chance *= 0.55
    chance = clamp(chance, 0.06, 0.85)
    var hits = 0
    for i in range(int(arms["pellets"])):
        if randf() < chance * (1.0 if int(arms["pellets"]) == 1 else clamp(1.15 - d / 200.0, 0.1, 1.0)):
            hits += 1
    var end = target_pos
    if hits > 0:
        game._apply_enemy_hit(float(arms["damage"]) * hits)
    else:
        var miss = randf_range(6.0, 26.0) * (1.0 if randf() < 0.5 else -1.0)
        end = target_pos + dir.rotated(PI * 0.5) * miss + dir * randf_range(10.0, 60.0)
        # a near miss: the crack of the round going past, a flinch of the view
        if abs(miss) < 20.0:
            game._play_world_sfx("flyby_%d" % (randi() % 3 + 1), -7.0, 0.06)
            if bool(game.get_meta("settings", {}).get("camera_shake", true)) if game.has_meta("settings") else true:
                game.camera_kick += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
    game._spawn_temp_tracer(muzzle, end, 0.07)


func _muzzle_flash(at: Vector2, dir: Vector2) -> void:
    var f = Polygon2D.new()
    f.polygon = PackedVector2Array([Vector2(0, -1.5), Vector2(6, 0), Vector2(0, 1.5), Vector2(-1, 0)])
    f.color = Color(1.0, 0.86, 0.5, 0.95)
    f.rotation = dir.angle()
    f.global_position = at
    f.z_index = 30
    f.z_as_relative = false
    game.add_child(f)
    var tw = f.create_tween()
    tw.tween_property(f, "modulate:a", 0.0, 0.06)
    tw.tween_callback(f.queue_free)
    # the flash lights the shooter and the walls round him for a moment
    if lamp != null and game._time_night_factor() > 0.2:
        var flash = PointLight2D.new()
        flash.texture = lamp.texture
        flash.texture_scale = 0.35
        flash.energy = 1.4
        flash.color = Color(1.0, 0.8, 0.5)
        flash.global_position = at
        game.add_child(flash)
        var tl = flash.create_tween()
        tl.tween_property(flash, "energy", 0.0, 0.07)
        tl.tween_callback(flash.queue_free)
    # a spent case flicks out to the right and rolls to a stop
    if weapon != "shotgun" or randf() < 0.5:
        var case = Polygon2D.new()
        case.polygon = PackedVector2Array([Vector2(0, 0), Vector2(1.5, 0), Vector2(1.5, 1), Vector2(0, 1)])
        case.color = Color(0.82, 0.66, 0.3) if weapon != "shotgun" else Color(0.7, 0.2, 0.16)
        case.z_index = -5
        case.z_as_relative = false
        case.global_position = (global_position + Vector2(0, 4)).round()
        game.add_child(case)
        var side = Vector2(-dir.y, dir.x)
        var land = case.global_position + side * randf_range(10.0, 18.0) - dir * randf_range(0.0, 6.0) + Vector2(0, 6)
        var tc = case.create_tween()
        tc.tween_property(case, "global_position", land.round(), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tc.tween_interval(8.0)
        tc.tween_property(case, "modulate:a", 0.0, 1.5)
        tc.tween_callback(case.queue_free)


func _threatening_infected():
    var best = null
    var bd = 120.0
    for e in get_tree().get_nodes_in_group("infected"):
        if not is_instance_valid(e):
            continue
        if str(e.get_meta("ai_state", "idle")) not in ["chase", "investigate", "search"]:
            continue
        var d = e.global_position.distance_to(global_position)
        if d < bd:
            bd = d
            best = e
    return best


func _infected_contact(dt: float) -> void:
    contact_t -= dt
    if contact_t > 0.0:
        return
    for e in get_tree().get_nodes_in_group("infected"):
        if not is_instance_valid(e):
            continue
        if e.global_position.distance_to(global_position) < 22.0 and str(e.get_meta("ai_state", "idle")) in ["chase", "investigate", "search"]:
            contact_t = 0.9
            take_damage(float(e.get_meta("attack_damage", 8.0)), (global_position - e.global_position).normalized(), false)
            _bark("infected")
            if state not in ["combat", "flee"]:
                _set_state("combat")
            return


# ---------------------------------------------------------------- damage --
func marauder_take_damage(amount: float, hit_dir: Vector2) -> void:
    take_damage(amount, hit_dir, true)


func take_damage(amount: float, hit_dir: Vector2, from_player: bool) -> void:
    if dead:
        return
    hp -= amount
    hurt_anim = 0.25
    game._blood_hit(global_position, hit_dir, hp <= 0.0)
    # the hit shoves the body back and spoils the aim for a moment; a load of
    # buckshot can knock a man off his feet for a beat
    var shove = clamp(amount * 3.2, 30.0, 170.0)
    if hit_dir.length() > 0.01 and _free_step(hit_dir.normalized() * 6.0):
        knock = hit_dir.normalized() * shove
        stagger_t = clamp(0.1 + amount / 120.0, 0.12, 0.45)
    flinch_t = 1.0
    fire_t = max(fire_t, 0.35)
    if from_player:
        if not hostile_to_player:
            become_hostile()
        last_seen_pos = game.player.global_position
        last_seen_time = Time.get_ticks_msec() / 1000.0
        if state not in ["combat", "flee", "surrender"]:
            _enter_combat(true)
        if surrendered and state == "surrender":
            # shot while begging: they run
            flee_t = 20.0
            _set_state("flee")
    if hp <= 0.0:
        _die(hit_dir)
    elif amount >= 8.0:
        _bark("hurt")
        _say("hurt")


func _surrender() -> void:
    surrendered = true
    hostile_to_player = false
    _bark("surrender", true)
    # the gun goes down on the ground in front of them
    game._marauder_drop_weapon(self)
    weapon_dropped = true
    _set_state("surrender")
    if squad != null:
        squad.member_lost(self)


func _die(hit_dir: Vector2) -> void:
    dead = true
    _say("death")
    die_t = 0.0
    collision_layer = 0
    remove_from_group("marauders")
    _set_clip("Die", 0)
    if squad != null:
        squad.member_lost(self)


func _update_dying(delta: float) -> void:
    die_t += delta
    var frame = min(FRAMES["Die"] - 1, int(die_t / 0.11))
    _set_clip("Die", frame)
    if die_t >= 1.0:
        game._leave_marauder_body(self)
        queue_free()


# ------------------------------------------------------------- animation --
func _sheet(clip: String) -> Texture2D:
    var held = "none" if weapon_dropped and clip in ["Idle", "Walk", "Run", "Die", "TakeDamage"] else weapon
    if held == "none" and clip == "TakeDamage":
        clip = "Idle"
    var key = "%s_%s_%s" % [outfit, held, clip]
    if not _sheets.has(key):
        _sheets[key] = load("res://art/marauders/%s.png" % key)
    return _sheets[key]


func _set_clip(clip: String, frame: int) -> void:
    var key = clip + ("_bare" if weapon_dropped else "")
    if _clip != key:
        _clip = key
        sprite.texture = _sheet(clip)
    sprite.region_rect = Rect2(frame * CELL, dir8 * CELL, CELL, CELL)


func _animate(move: Vector2) -> void:
    if facing.length() > 0.1:
        dir8 = int(round(fposmod(facing.angle(), TAU) / (PI * 0.25))) % 8
    var t = Time.get_ticks_msec() / 1000.0
    if attack_anim > 0.0:
        _set_clip("Attack1", clamp(int((0.3 - attack_anim) / 0.3 * FRAMES["Attack1"]), 0, FRAMES["Attack1"] - 1))
    elif hurt_anim > 0.0:
        _set_clip("TakeDamage", clamp(int((0.25 - hurt_anim) / 0.25 * 4.0), 0, 3))
    elif move.length() > 5.0:
        var clip = "Run" if move.length() > COMBAT_SPEED + 4.0 else "Walk"
        var n = FRAMES[clip]
        _set_clip(clip, int(fposmod(walk_dist / STRIDE[clip], 1.0) * n) % n)
    else:
        _set_clip("Idle", int(t * 6.0 + get_instance_id() % 7) % FRAMES["Idle"])
    # pixel-crisp: the sprite never sits between screen pixels
    sprite.position = SPRITE_OFFSET
    position = position


# ------------------------------------------------------------ barks, lamp --
func _bark(kind: String, force: bool = false) -> void:
    if bark_cd > 0.0 and not force:
        return
    if squad != null and not force and not squad.may_bark():
        return
    var lines = BARKS.get(kind, [])
    if lines.is_empty():
        return
    bark_label.text = lines[randi() % lines.size()]
    bark_label.visible = true
    bark_life = 2.2
    bark_cd = 4.0
    if kind in ["spot", "flank", "friend_down", "flee", "surrender", "infected", "aim"]:
        _say("shout")


func _update_bark(delta: float) -> void:
    if bark_life <= 0.0:
        return
    bark_life -= delta
    bark_label.modulate.a = clamp(bark_life / 0.4, 0.0, 1.0)
    # the world's night tint must not swallow the words
    if game.canvas_modulate != null:
        var cm: Color = game.canvas_modulate.color
        bark_label.self_modulate = Color(min(4.0, 1.0 / max(cm.r, 0.25)), min(4.0, 1.0 / max(cm.g, 0.25)), min(4.0, 1.0 / max(cm.b, 0.25)), 1.0)
    if bark_life <= 0.0:
        bark_label.visible = false


func _update_lamp() -> void:
    if lamp == null:
        return
    var night = game._time_night_factor()
    lamp.energy = 0.55 * night if state != "flee" else 0.0
    lamp.offset = facing * 26.0


# ------------------------------------------------------------- dev64 additions --
func _say(kind: String) -> void:
    if mouth == null:
        return
    var path = ""
    match kind:
        "hurt":
            path = "res://audio/marauders/v%d_hurt_%d.wav" % [voice_id, randi() % 3 + 1]
        "shout":
            path = "res://audio/marauders/v%d_shout_%d.wav" % [voice_id, randi() % 3 + 1]
        "death":
            path = "res://audio/marauders/death_%d.wav" % (randi() % 6 + 1)
    if path == "" or (mouth.playing and kind == "shout"):
        return
    var stream = game._cached_weapon_audio(path)
    if stream == null:
        return
    mouth.stream = stream
    mouth.volume_db = -6.0 if kind == "death" else -8.0
    mouth.pitch_scale = randf_range(0.96, 1.04)
    mouth.play()


func _play_gear(path: String, db: float) -> void:
    if gear == null or path == "":
        return
    var stream = game._cached_weapon_audio(path)
    if stream == null:
        return
    gear.stream = stream
    gear.volume_db = db
    gear.pitch_scale = randf_range(0.97, 1.03)
    gear.play()


func _footsteps(move: Vector2) -> void:
    # two footfalls per gait cycle, on the surface underfoot; running is louder
    if move.length() < 5.0:
        return
    var clip = "Run" if move.length() > COMBAT_SPEED + 4.0 else "Walk"
    var half = STRIDE[clip] * 0.5
    if walk_dist - step_mark < half:
        return
    step_mark = walk_dist
    var surface = game._footstep_surface_at(global_position)
    var take = "step_%s_%d" % [surface, randi() % int(game.STEP_TAKES.get(surface, 1)) + 1]
    game._play_distance_sfx(take, global_position, -13.0 if clip == "Run" else -17.0, 380.0, 0.05)


func _open_door_ahead(move: Vector2) -> void:
    if door_t > 0.0:
        return
    var ahead = move.normalized()
    for d in get_tree().get_nodes_in_group("doors"):
        if not is_instance_valid(d) or bool(d.get_meta("door_open", false)):
            continue
        var to = d.global_position - global_position
        if to.length() > 34.0 or (to.length() > 10.0 and ahead.dot(to.normalized()) < 0.2):
            continue
        var kicked = state == "combat"
        if game._npc_open_door(d, global_position, kicked):
            door_t = 0.6
            # a kicked-in door costs a beat; an opened one a little less
            stagger_t = 0.25 if kicked else 0.15
            knock = Vector2.ZERO
            path = []
        return


func _door_toward(goal: Vector2):
    # the door (open or shut) that best leads to a goal inside a building
    var best = null
    var best_cost = INF
    for d in get_tree().get_nodes_in_group("doors"):
        if not is_instance_valid(d):
            continue
        var dg = d.global_position.distance_to(goal)
        var ds = d.global_position.distance_to(global_position)
        if dg > 240.0 or ds > 420.0:
            continue
        if dg + ds < best_cost:
            best_cost = dg + ds
            best = d
    return best


func unaware_of(from_pos: Vector2) -> bool:
    # not fighting, not looking this way: a blade from behind ends it quietly
    if dead or state in ["combat", "flee", "surrender"] or awareness >= 0.45:
        return false
    var to_attacker = (from_pos - global_position).normalized()
    return facing.dot(to_attacker) < 0.25


func silent_takedown(dir: Vector2) -> void:
    if dead:
        return
    hp = 0.0
    game._blood_hit(global_position, dir, true)
    game._play_world_sfx("melee_hit", -14.0, 0.03)
    # only those who saw it raise the alarm
    if squad != null:
        for m in squad.alive():
            if m == self:
                continue
            if m.global_position.distance_to(global_position) < 200.0 and m._clear_line(m.global_position, global_position) and m.facing.dot((global_position - m.global_position).normalized()) > 0.0:
                m.squad_alert(game.player.global_position)
                m._bark("friend_down", true)
    dead = true
    die_t = 0.0
    collision_layer = 0
    remove_from_group("marauders")
    _set_clip("Die", 0)
    if squad != null:
        squad.member_lost(self)
