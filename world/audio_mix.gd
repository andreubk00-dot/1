extends Node
# dev69: the mix director. Sits above the three game buses and moves them as
# the moment changes, without touching the player's own volume sliders (those
# are the bus volumes; the director works through an Amplify and a LowPass
# effect it owns on each bus):
#
#   menu    pause, title, the console dialog: the world goes far away and
#           muffled, the music carries on a little quieter (it keeps playing
#           and keeps picking pieces while the tree is paused)
#   focus   inventory, map, trader, crafting: the world steps back a little
#   dying   everything sinks under water, the music goes quiet
#   critical  near death: a slight tunnel on the world
#
# Master gets a hard limiter so a shotgun, a scream and a thunderclap on the
# same frame never clip.

const BUSES = ["Music", "SFX", "Ambience"]
const OPEN_HZ = 20500.0

# state -> bus -> [gain dB, low-pass Hz]
const STATES = {
    "play": {"Music": [0.0, OPEN_HZ], "SFX": [0.0, OPEN_HZ], "Ambience": [0.0, OPEN_HZ]},
    "focus": {"Music": [0.0, OPEN_HZ], "SFX": [-2.0, OPEN_HZ], "Ambience": [-4.0, 6000.0]},
    "critical": {"Music": [-3.0, OPEN_HZ], "SFX": [-1.0, 2600.0], "Ambience": [-3.0, 2200.0]},
    "menu": {"Music": [-4.0, OPEN_HZ], "SFX": [-8.0, 900.0], "Ambience": [-9.0, 700.0]},
    "dying": {"Music": [-24.0, 900.0], "SFX": [-6.0, 520.0], "Ambience": [-12.0, 420.0]},
}

var game = null
var state = "play"
var _gain = {}
var _hz = {}
var _ready_buses = false


func _init():
    name = "AudioMix"
    process_mode = Node.PROCESS_MODE_ALWAYS


static func setup_buses() -> void:
    # idempotent: one Amplify + one LowPass per game bus, a limiter on Master
    for bus in BUSES:
        var i = AudioServer.get_bus_index(bus)
        if i < 0:
            continue
        if _find(i, "AudioEffectAmplify") < 0:
            AudioServer.add_bus_effect(i, AudioEffectAmplify.new())
        if _find(i, "AudioEffectLowPassFilter") < 0:
            var lp = AudioEffectLowPassFilter.new()
            lp.cutoff_hz = OPEN_HZ
            AudioServer.add_bus_effect(i, lp)
            AudioServer.set_bus_effect_enabled(i, _find(i, "AudioEffectLowPassFilter"), false)
    var m = AudioServer.get_bus_index("Master")
    if m >= 0 and _find(m, "AudioEffectHardLimiter") < 0:
        var lim = AudioEffectHardLimiter.new()
        lim.ceiling_db = -0.8
        lim.pre_gain_db = 0.0
        AudioServer.add_bus_effect(m, lim)


static func _find(bus: int, cls: String) -> int:
    for k in range(AudioServer.get_bus_effect_count(bus)):
        if AudioServer.get_bus_effect(bus, k).get_class() == cls:
            return k
    return -1


func _ready():
    setup_buses()
    for bus in BUSES:
        _gain[bus] = 0.0
        _hz[bus] = OPEN_HZ
    _ready_buses = true


func target_state() -> String:
    if game == null or not is_instance_valid(game):
        return "play"
    if float(game.get("player_death_time")) > 0.0:
        return "dying"
    if get_tree().paused:
        return "menu"
    for flag in ["inventory_open", "region_map_open", "trader_open", "contract_open", "crafting_open", "base_build_open", "rest_open", "mod_panel_open"]:
        if bool(game.get(flag)):
            return "focus"
    if float(game.get("health")) < 20.0:
        return "critical"
    return "play"


func bus_gain(bus: String) -> float:
    return float(_gain.get(bus, 0.0))


func bus_cutoff(bus: String) -> float:
    return float(_hz.get(bus, OPEN_HZ))


func _process(delta: float) -> void:
    if not _ready_buses:
        return
    state = target_state()
    var want = STATES[state]
    # into a state fast, back out slower, the way an ear readjusts
    for bus in BUSES:
        var g = float(want[bus][0])
        var hz = float(want[bus][1])
        var rate = 40.0 if g < _gain[bus] else 14.0
        _gain[bus] = move_toward(_gain[bus], g, rate * delta)
        # the cutoff moves on a log scale so the sweep sounds even
        var cur = log(_hz[bus])
        var tgt = log(hz)
        _hz[bus] = exp(move_toward(cur, tgt, (6.0 if tgt < cur else 2.5) * delta))
        _apply(bus)
    if get_tree().paused and game != null and is_instance_valid(game) and game.has_method("_update_music"):
        # the game's own loop is frozen; the score keeps going in the menus
        game._update_music(delta)


func _apply(bus: String) -> void:
    var i = AudioServer.get_bus_index(bus)
    if i < 0:
        return
    var a = _find(i, "AudioEffectAmplify")
    if a >= 0:
        (AudioServer.get_bus_effect(i, a) as AudioEffectAmplify).volume_db = _gain[bus]
    var l = _find(i, "AudioEffectLowPassFilter")
    if l >= 0:
        var open = _hz[bus] >= OPEN_HZ - 1.0
        AudioServer.set_bus_effect_enabled(i, l, not open)
        (AudioServer.get_bus_effect(i, l) as AudioEffectLowPassFilter).cutoff_hz = _hz[bus]
