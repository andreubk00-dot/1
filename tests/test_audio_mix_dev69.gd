extends SceneTree
# dev69: the sound mix. Levels are checked as heard: the loudest 50 ms of each
# recording (read straight from the WAV) plus the gain the game plays it at.
# The order must hold - a gunshot over a club, a suppressed pistol over a
# footstep, steps of one surface even, reloads alike, rain under the steps,
# thunder no louder than a rifle. The mix director ducks and muffles the
# world in menus, on death and near death without touching the player's
# sliders; the score and the ambience bed keep playing under a pause; the
# title does not sit silent; menu clicks ride their own bus; Master is limited.
const Main = preload("res://main_script_mod.gd")
const PauseMenu = preload("res://world/pause_menu.gd")
const AudioMix = preload("res://world/audio_mix.gd")

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
        await process_frame

func secs(t: float) -> void:
    await create_timer(t, true).timeout

func st_db(path: String) -> float:
    # loudest 50 ms window of a 16-bit PCM WAV, in dBFS
    var f = FileAccess.open(path, FileAccess.READ)
    if f == null:
        return -200.0
    var bytes = f.get_buffer(f.get_length())
    var pos = 12
    var channels = 1
    var rate = 44100
    var bits = 16
    var data_at = -1
    var data_len = 0
    while pos + 8 <= bytes.size():
        var id = bytes.slice(pos, pos + 4).get_string_from_ascii()
        var size = bytes.decode_u32(pos + 4)
        if id == "fmt ":
            channels = bytes.decode_u16(pos + 10)
            rate = bytes.decode_u32(pos + 12)
            bits = bytes.decode_u16(pos + 22)
        elif id == "data":
            data_at = pos + 8
            data_len = min(size, bytes.size() - data_at)
            break
        pos += 8 + size + (size % 2)
    if data_at < 0 or bits != 16:
        return -200.0
    var frames_n = data_len / (2 * channels)
    var win = int(rate * 0.05)
    var best = 0.0
    var acc = 0.0
    var n = 0
    for i in range(frames_n):
        var v = 0.0
        for c in range(channels):
            v += bytes.decode_s16(data_at + (i * channels + c) * 2) / 32768.0
        v /= channels
        acc += v * v
        n += 1
        if n == win:
            best = max(best, acc / win)
            acc = 0.0
            n = 0
    return 10.0 * log(max(best, 1e-12)) / log(10.0)

func run():
    var game = Main.new()
    root.add_child(game)
    # the start-up self tests (bones, guns) are not heard
    var thump = false
    for v in game.world_audio_players + game.weapon_audio_players:
        thump = thump or v.playing
    check(not thump and not game.self_test_silent, "the start-up self test is heard")
    await frames(8)
    game.developer_invulnerable = true

    # --- levels as heard -----------------------------------------------------
    var shots = {}
    for w in ["makarov", "tt33", "izh81", "toz34", "akm", "sks", "pps43", "mosin", "aks74u"]:
        if game.weapon_defs.has(w):
            shots[w] = st_db("res://audio/weapons/%s_shot.wav" % w) + float(game.weapon_defs[w].get("shot_volume_db", -8.0))
    check(shots.size() >= 8, "weapons missing from the mix check")
    var quietest_shot = 0.0
    var loudest_shot = -200.0
    for w in shots.keys():
        quietest_shot = min(quietest_shot, shots[w])
        loudest_shot = max(loudest_shot, shots[w])
        check(shots[w] > -23.0 and shots[w] < -15.0, "%s shot out of the gunshot band: %.1f" % [w, shots[w]])
    var pm = float(game.weapon_defs["makarov"].get("shot_volume_db", -8.0))
    var suppressed = st_db("res://audio/weapons/makarov_suppressed_shot.wav") + pm + 2.5
    var step = st_db("res://audio/world/steps/stone_1.wav") - 16.0 + float(game.SFX_TRIM.get("step_stone_1", 0.0))
    check(suppressed > step + 3.0, "a suppressed pistol is drowned by a footstep: %.1f vs %.1f" % [suppressed, step])
    check(suppressed < shots["makarov"] - 6.0, "the suppressor does not quieten the pistol: %.1f vs %.1f" % [suppressed, shots["makarov"]])
    var club = st_db("res://audio/world/melee_hit.wav") - 9.5 + float(game.SFX_TRIM["melee_hit"])
    check(club < quietest_shot - 1.0, "a club hit outshouts a gunshot: %.1f vs %.1f" % [club, quietest_shot])
    # reloads at one handling level
    var reloads = []
    for prof in ["pistol", "rifle", "smg", "shell", "bolt"]:
        reloads.append(st_db("res://audio/weapons/%s_reload.wav" % prof) + float(game.RELOAD_DB[prof]))
    check(reloads.max() - reloads.min() <= 2.5, "reloads differ too much: " + str(reloads))
    check(reloads.max() < quietest_shot - 2.0, "a reload is as loud as a shot")
    # steps of one surface are even after the trims
    for surface in game.STEP_TAKES.keys():
        var lv = []
        for i in range(int(game.STEP_TAKES[surface])):
            var take = "step_%s_%d" % [surface, i + 1]
            lv.append(st_db("res://audio/world/steps/%s_%d.wav" % [surface, i + 1]) + float(game.SFX_TRIM.get(take, 0.0)))
        check(lv.max() - lv.min() <= 3.6, "%s steps uneven: %.1f dB spread" % [surface, lv.max() - lv.min()])
    # the beds and the weather
    var rain = st_db("res://audio/ambience/rain.wav") + game._ambience_target_volume("rain", {"base": "day", "rain": true})
    check(rain < step - 2.0, "rain louder than a footstep: %.1f vs %.1f" % [rain, step])
    var day = st_db("res://audio/ambience/outdoor_day.wav") + game._ambience_target_volume("day", {"base": "day"})
    var night = st_db("res://audio/ambience/outdoor_night.wav") + game._ambience_target_volume("night", {"base": "night"})
    check(abs(day - night) <= 2.5, "the night bed falls away: day %.1f night %.1f" % [day, night])
    var thunder = -200.0
    for i in range(3):
        thunder = max(thunder, st_db("res://audio/world/thunder_%d.wav" % (i + 1)) - 8.0)
    check(thunder <= loudest_shot + 2.0, "thunder outshouts every gun: %.1f vs %.1f" % [thunder, loudest_shot])
    var hum = st_db("res://audio/world/generator_loop.wav") - 15.0
    check(hum < -26.0, "a generator drones over everything: %.1f" % hum)
    for kind in game.SFX_TRIM.keys():
        check(game._world_sfx_path(kind) != "" and ResourceLoader.exists(game._world_sfx_path(kind)), "a trim for a sound that does not exist: " + kind)
        check(abs(float(game.SFX_TRIM[kind])) <= 4.0, "a trim too large to be a trim: " + kind)
    # the trim reaches the voice
    game.player.global_position = Vector2.ZERO
    var before = game.world_audio_cursor
    game._play_world_sfx("container_close", -14.0, 0.0)
    check(abs(float(game.world_audio_players[before].volume_db) - (-10.0)) < 0.01, "the trim does not reach the voice")

    # --- buses ---------------------------------------------------------------
    for bus in ["Music", "SFX", "Ambience", "UI"]:
        check(AudioServer.get_bus_index(bus) >= 0, "no bus " + bus)
    var counts = []
    for bus in ["Music", "SFX", "Ambience", "Master"]:
        counts.append(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(bus)))
    AudioMix.setup_buses()
    AudioMix.setup_buses()
    var counts2 = []
    for bus in ["Music", "SFX", "Ambience", "Master"]:
        counts2.append(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(bus)))
    check(counts == counts2, "bus effects pile up on a second setup: %s -> %s" % [counts, counts2])
    var master = AudioServer.get_bus_index("Master")
    check(AudioMix._find(master, "AudioEffectHardLimiter") >= 0, "Master has no limiter")
    for bus in ["Music", "SFX", "Ambience"]:
        var i = AudioServer.get_bus_index(bus)
        check(AudioMix._find(i, "AudioEffectAmplify") >= 0 and AudioMix._find(i, "AudioEffectLowPassFilter") >= 0, "no duck/muffle on " + bus)
    check(AudioServer.get_bus_send(AudioServer.get_bus_index("UI")) == "Master", "the UI bus goes nowhere")

    # --- states ----------------------------------------------------------------
    var mix = game.audio_mix
    check(mix != null and mix.process_mode == Node.PROCESS_MODE_ALWAYS, "no mix director")
    var s = PauseMenu.load_settings()
    s["music"] = 0.5
    PauseMenu.apply_settings(s)
    var music_bus = AudioServer.get_bus_index("Music")
    var slider_db = AudioServer.get_bus_volume_db(music_bus)
    check(abs(slider_db - linear_to_db(0.5)) < 0.01, "the music slider does not set the bus")
    await frames(5)
    check(mix.state == "play" and abs(mix.bus_gain("SFX")) < 0.01, "the world starts ducked")
    var sfx_i = AudioServer.get_bus_index("SFX")
    check(not AudioServer.is_bus_effect_enabled(sfx_i, AudioMix._find(sfx_i, "AudioEffectLowPassFilter")), "the world starts muffled")
    game._toggle_inventory()
    await frames(3)
    check(mix.state == "focus", "the inventory does not step the world back")
    game._toggle_inventory()
    game._open_menu("pause")
    await secs(1.5)
    check(mix.state == "menu", "the pause does not move the mix")
    check(mix.bus_gain("Ambience") <= -8.5 and mix.bus_cutoff("Ambience") < 900.0, "the world is not muffled under the pause: %.1f dB %.0f Hz" % [mix.bus_gain("Ambience"), mix.bus_cutoff("Ambience")])
    check(AudioServer.is_bus_effect_enabled(sfx_i, AudioMix._find(sfx_i, "AudioEffectLowPassFilter")), "the low-pass is not switched on")
    check(abs(AudioServer.get_bus_volume_db(music_bus) - slider_db) < 0.01, "the duck moved the player's slider")
    check(mix.bus_gain("Music") > -5.0 and mix.bus_gain("Music") < -3.0, "the score is not just a little under the pause")
    check(game.music_player != null and game.music_player.process_mode == Node.PROCESS_MODE_ALWAYS, "the score stops under the pause")
    for kind in game.ambience_audio_players.keys():
        check(game.ambience_audio_players[kind].process_mode == Node.PROCESS_MODE_ALWAYS, "the ambience bed stops under the pause: " + kind)
    # the score keeps being chosen while paused
    var waited = game.music_wait
    await secs(0.5)
    check(game.music_player.playing or game.music_wait < waited, "the score is frozen under the pause")
    # menu clicks ride the UI bus
    var menu = game.pause_menu
    menu._open_settings("sound")
    menu._tab_buttons["display"].emit_signal("pressed")
    check(menu._click_player != null and menu._click_player.bus == "UI", "menu clicks are not on the UI bus")
    menu.close()
    await secs(3.5)
    check(mix.state == "play" and abs(mix.bus_gain("SFX")) < 0.01 and mix.bus_cutoff("SFX") >= AudioMix.OPEN_HZ - 1.0, "the world does not come back after the pause: %.1f dB %.0f Hz" % [mix.bus_gain("SFX"), mix.bus_cutoff("SFX")])
    check(not AudioServer.is_bus_effect_enabled(sfx_i, AudioMix._find(sfx_i, "AudioEffectLowPassFilter")), "the low-pass stays on after the pause")

    # the title starts its music within seconds
    game.music_player.stop()
    game.music_track = ""
    game.music_wait = 30.0
    game._open_menu("title")
    await frames(4)
    check(game.music_wait <= 2.5, "the title sits in silence for half a minute")
    game.pause_menu.close()
    await frames(2)

    # near death and death
    game.developer_invulnerable = false
    game.health = 12.0
    await secs(1.5)
    var near_state = mix.state
    check(near_state == "critical" and mix.bus_cutoff("SFX") < 4000.0, "near death sounds like any other moment: " + near_state)
    game.health = 100.0
    game.developer_invulnerable = true
    game.player_death_time = 0.5
    check(mix.target_state() == "dying", "death does not sink the sound")
    game.player_death_time = 0.0
    await frames(2)

    # broken bones still crack, louder than any step
    var crack = st_db("res://audio/world/melee_hit.wav") - 5.0 + float(game.SFX_TRIM["melee_hit"])
    check(crack > step + 10.0, "a breaking bone is not heard over the steps")

    PauseMenu.apply_settings(PauseMenu.DEFAULTS)
    print("AUDIO MIX dev69: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
