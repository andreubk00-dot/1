extends Node
# dev67: the world beyond the screen. Shooting far off (more of it at night
# and toward the raiders' base), dogs after dusk near where people live, gusts
# of wind outdoors (harder in the cold and the snow), thunder with lightning in
# the rain, crows taking off, and the steady crackle of fires and hum of
# generators where people keep them. All from audio/world (CC0, see
# audio/CREDITS_CC0.md); one-shots ride the Ambience bus.

const ONE_SHOT_VOICES = 6
const GUNFIRE_EVERY = Vector2(55.0, 130.0)     # real seconds, day; night halves it
const DOGS_EVERY = Vector2(45.0, 120.0)
const WIND_EVERY = Vector2(16.0, 38.0)
const THUNDER_EVERY = Vector2(18.0, 42.0)
const CROW_GAP = 1.2

var game = null
var voices = []
var next_voice = 0
var gunfire_t = 40.0
var dogs_t = 30.0
var wind_t = 10.0
var thunder_t = 12.0
var thunder_pending = -1.0
var crow_t = 0.0
var flash = 0.0                 # lightning: 1 at the strike, fades fast
var heard = {}                  # kind -> count (for the tests)
var _streams = {}


func _ready() -> void:
    for i in range(ONE_SHOT_VOICES):
        var p = AudioStreamPlayer2D.new()
        p.bus = "Ambience"
        p.max_distance = 2400.0
        p.attenuation = 1.0
        add_child(p)
        voices.append(p)


func stream(name: String, looped: bool = false):
    var key = name + ("#loop" if looped else "")
    if _streams.has(key):
        return _streams[key]
    var path = "res://audio/world/%s.wav" % name
    if not ResourceLoader.exists(path):
        _streams[key] = null
        return null
    var s = load(path)
    if looped and s is AudioStreamWAV:
        s = s.duplicate()
        s.loop_mode = AudioStreamWAV.LOOP_FORWARD
        s.loop_begin = 0
        s.loop_end = s.data.size() / (2 * (2 if s.stereo else 1))
    _streams[key] = s
    return s


func one_shot(name: String, at: Vector2, db: float, pitch: float = 1.0) -> void:
    var s = stream(name)
    if s == null:
        return
    var p = voices[next_voice]
    next_voice = (next_voice + 1) % voices.size()
    p.stream = s
    p.global_position = at
    p.volume_db = db
    p.pitch_scale = pitch
    p.play()
    var kind = name.rstrip("0123456789").trim_suffix("_")
    heard[kind] = int(heard.get(kind, 0)) + 1


func attach_loop(node: Node, name: String, db: float, max_distance: float, offset: Vector2 = Vector2.ZERO):
    # a steady source on a world object (a fire, a generator); it plays while
    # the object stands and dies with it
    var s = stream(name, true)
    if s == null or not is_instance_valid(node):
        return null
    var p = AudioStreamPlayer2D.new()
    p.stream = s
    p.bus = "Ambience"
    p.volume_db = db
    p.max_distance = max_distance
    p.attenuation = 1.6
    p.position = offset
    p.autoplay = true
    p.set_meta("world_loop", name)
    node.add_child(p)
    # start at a random point so neighbouring fires do not crackle in step
    p.ready.connect(func():
        if p.is_inside_tree():
            p.play(randf() * max(0.1, s.get_length() - 0.1)))
    return p


func _quiet() -> bool:
    return game == null or game.player == null or game.player_death_time > 0.0 or game._high_risk_floor_active()


func _around(dist: float) -> Vector2:
    return game.player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * dist


func _physics_process(delta: float) -> void:
    flash = max(0.0, flash - delta * 5.0)
    crow_t = max(0.0, crow_t - delta)
    if _quiet():
        return
    var night = game._time_night_factor()
    var indoors = bool(game.is_sheltered) if "is_sheltered" in game else false
    _tick_gunfire(delta, night)
    _tick_dogs(delta, night)
    _tick_wind(delta, indoors)
    _tick_thunder(delta, indoors)


func _tick_gunfire(delta: float, night: float) -> void:
    # someone is always fighting somewhere: more at night, and the raiders'
    # base makes its corner of the map loud
    var rate = 1.0 + night
    if game.marauder_base != null:
        rate *= game.marauder_base.roaming_pressure(game.player.global_position)
    gunfire_t -= delta * rate
    if gunfire_t > 0.0:
        return
    gunfire_t = randf_range(GUNFIRE_EVERY.x, GUNFIRE_EVERY.y)
    var at = _around(randf_range(900.0, 1500.0))
    if game.marauder_base != null and not game.marauder_base.is_cleared() and randf() < 0.5:
        var to_base = game.marauder_base.center() - game.player.global_position
        if to_base.length() < 9000.0:
            at = game.player.global_position + to_base.normalized() * randf_range(1000.0, 1500.0)
    one_shot("gunfire_far_%d" % (randi() % 4 + 1), at, randf_range(-6.0, -1.0), randf_range(0.94, 1.04))


func _tick_dogs(delta: float, night: float) -> void:
    if night < 0.3:
        return
    # strays howl where people live or lived: towns, villages, dachas
    var zone = game._chunk_profile(game.current_chunk).get("zone", "")
    var rate = 1.4 if zone in ["residential", "rural", "settlement"] else 0.6
    dogs_t -= delta * rate
    if dogs_t > 0.0:
        return
    dogs_t = randf_range(DOGS_EVERY.x, DOGS_EVERY.y)
    var at = _around(randf_range(700.0, 1200.0))
    var n = randi_range(1, 3)
    for i in range(n):
        get_tree().create_timer(i * randf_range(0.5, 0.9)).timeout.connect(func():
            if not _quiet():
                one_shot("dog_bark_%d" % (randi() % 3 + 1), at, randf_range(-8.0, -3.0), randf_range(0.92, 1.08)))


func _tick_wind(delta: float, indoors: bool) -> void:
    var cold = game._is_snowing() or float(game.thermal_effective_temperature if "thermal_effective_temperature" in game else 10.0) < 2.0
    wind_t -= delta * (1.6 if cold else 1.0)
    if wind_t > 0.0:
        return
    wind_t = randf_range(WIND_EVERY.x, WIND_EVERY.y)
    if indoors:
        return
    # a gust passes by: from one side, close and broad
    one_shot("wind_gust_%d" % (randi() % 2 + 1), _around(160.0), randf_range(-10.0, -5.0) + (3.0 if cold else 0.0), randf_range(0.9, 1.1))


func _tick_thunder(delta: float, indoors: bool) -> void:
    if thunder_pending > 0.0:
        thunder_pending -= delta
        if thunder_pending <= 0.0:
            one_shot("thunder_%d" % (randi() % 3 + 1), _around(500.0), -2.0 if not indoors else -8.0, randf_range(0.9, 1.05))
        return
    if game.weather_state != "rain" or game._is_snowing():
        thunder_t = max(thunder_t, 8.0)
        return
    thunder_t -= delta
    if thunder_t > 0.0:
        return
    thunder_t = randf_range(THUNDER_EVERY.x, THUNDER_EVERY.y)
    # the flash first; the rumble follows, later the further the strike
    flash = 1.0 if not indoors else 0.45
    thunder_pending = randf_range(0.4, 3.0)


func crows_took_off(at: Vector2) -> void:
    if crow_t > 0.0 or _quiet():
        return
    crow_t = CROW_GAP
    one_shot("crow_%d" % (randi() % 2 + 1), at, -6.0, randf_range(0.9, 1.1))
