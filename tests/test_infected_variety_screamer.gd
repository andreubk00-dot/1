extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize():
    call_deferred("run")

func _sample_mix(game, profile:String, seed_value:int, samples:int) -> Dictionary:
    var rng = RandomNumberGenerator.new()
    rng.seed = seed_value
    var result = {"normal":0,"runner":0,"brute":0,"screamer":0,"spitter":0}
    for i in range(samples):
        var kind = game._infected_kind_for_encounter(profile,rng)
        result[kind] = int(result.get(kind,0)) + 1
    return result

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    check(str(ProjectSettings.get_setting("application/config/version","")) == "1.22.0-dev3", "current build version mismatch")
    check(game.INFECTED_ARCHETYPES.has("screamer"), "Screamer archetype missing")
    var screamer_def = game.INFECTED_ARCHETYPES["screamer"]
    check(str(screamer_def.get("label","")) == "КРИКУН", "Screamer label missing")
    check(str(screamer_def.get("special_role","")) == "caller", "Screamer must use caller role")
    check(float(screamer_def.get("hp_mult",9.0)) < float(game.INFECTED_ARCHETYPES["normal"].get("hp_mult",1.0)), "Screamer must be fragile, not a bullet sponge")
    check(float(screamer_def.get("damage",99.0)) < float(game.INFECTED_ARCHETYPES["normal"].get("damage",8.0)), "Screamer melee damage should not be its main threat")
    check(float(screamer_def.get("call_windup",0.0)) >= 0.60, "Screamer call needs readable windup")
    check(float(screamer_def.get("call_cooldown",0.0)) >= 10.0, "Screamer call cooldown too short")
    check(float(screamer_def.get("call_radius",0.0)) > float(screamer_def.get("call_trigger_range",999.0)), "Screamer alarm should reach farther than its trigger range")
    check(game._sound_suspicion_gain("infected_call") > game._sound_suspicion_gain("sprint"), "infected call must be a major AI-hearing event")
    check(game._sound_hearing_cap_multiplier("infected_call") > game._sound_hearing_cap_multiplier("sprint"), "infected call hearing cap too small")
    check(game._sound_weather_multiplier("infected_call") < 1.0 if game.weather_state == "rain" else true, "rain call attenuation contract invalid")

    # New role is authored-risk content, not a global replacement for common infected.
    var standard = _sample_mix(game,"standard",121001,800)
    check(int(standard.get("normal",0)) == 800, "Screamer leaked into standard encounters")
    check(int(standard.get("screamer",0)) == 0, "standard profile rolled Screamer")
    var high_perimeter = _sample_mix(game,"high_perimeter",121002,800)
    check(int(high_perimeter.get("screamer",0)) == 0, "Screamer should not spawn on high-risk perimeter in dev1")
    var clinical_perimeter = _sample_mix(game,"clinical_perimeter",121003,800)
    check(int(clinical_perimeter.get("screamer",0)) == 0, "Screamer should not spawn on clinical perimeter in dev1")
    var vector_access = _sample_mix(game,"vector_access",121004,800)
    check(int(vector_access.get("screamer",0)) == 0, "Screamer should not spawn at Vector access in dev1")

    var high_core = _sample_mix(game,"high_core",121005,2000)
    var clinical_core = _sample_mix(game,"clinical_core",121006,2000)
    var vector_core = _sample_mix(game,"vector_core",121007,2000)
    check(int(high_core.get("screamer",0)) > 50 and int(high_core.get("screamer",0)) < 220, "high_core Screamer share outside rare authored band")
    check(int(clinical_core.get("screamer",0)) > 50 and int(clinical_core.get("screamer",0)) < 220, "clinical_core Screamer share outside rare authored band")
    check(int(vector_core.get("screamer",0)) > 40 and int(vector_core.get("screamer",0)) < 200, "vector_core Screamer share outside rare authored band")
    check(int(clinical_core.get("runner",0)) > int(clinical_core.get("brute",0)), "Clinical runner-heavy identity lost after Screamer insertion")
    check(int(vector_core.get("brute",0)) > int(vector_core.get("runner",0)), "Vector brute-heavy identity lost after Screamer insertion")

    # Runtime special-role metadata.
    var chunk = Node2D.new()
    game.add_child(chunk)
    var caller = game._spawn_enemy(chunk,Vector2i(30,30),900,Vector2(180,180),"screamer")
    var listener = game._spawn_enemy(chunk,Vector2i(30,30),901,Vector2(270,180),"normal")
    var far_listener = game._spawn_enemy(chunk,Vector2i(30,30),902,Vector2(700,180),"normal")
    check(str(caller.get_meta("infected_kind","")) == "screamer", "spawn lost Screamer identity")
    check(str(caller.get_meta("special_role","")) == "caller", "spawn lost caller role")
    check(float(caller.get_meta("hp",999.0)) < float(listener.get_meta("hp",0.0)), "runtime Screamer became tougher than normal")
    check(float(caller.get_meta("call_radius",0.0)) == float(screamer_def.get("call_radius",-1.0)), "runtime call radius mismatch")
    check(int(caller.get_meta("call_count",-1)) == 0 and is_equal_approx(float(caller.get_meta("call_timer",-1.0)),0.0), "Screamer call state not initialized")

    # A visible chase begins a telegraphed stationary call, not an instant alarm.
    caller.set_meta("ai_state","chase")
    caller.set_meta("can_see_player",true)
    caller.set_meta("call_cd",0.0)
    var locked = game._infected_update_special_action(caller,"chase",true,120.0,0.05)
    check(locked, "Screamer did not enter call windup")
    check(float(caller.get_meta("call_timer",0.0)) >= 0.60, "call windup missing after trigger")
    check(int(caller.get_meta("call_count",0)) == 0, "alarm fired before windup completed")

    # Any real damage interrupts the windup and buys a meaningful reaction window.
    var hp_before = float(caller.get_meta("hp",0.0))
    game._damage_enemy(caller,1.0)
    check(float(caller.get_meta("hp",0.0)) < hp_before, "damage did not reach Screamer")
    check(not game._infected_is_calling(caller), "damage failed to interrupt Screamer call")
    check(float(caller.get_meta("call_cd",0.0)) >= 5.0, "interrupt cooldown too short")
    check(bool(caller.get_meta("call_interrupted",false)), "interruption flag missing")

    # Stagger/impact also interrupts, so stopping power has tactical value beyond raw DPS.
    caller.set_meta("call_cd",0.0)
    caller.set_meta("call_timer",float(screamer_def.get("call_windup",0.78)))
    game._apply_enemy_impulse(caller,Vector2.RIGHT,40.0,0.25)
    check(not game._infected_is_calling(caller), "stopping impact failed to interrupt call")
    check(float(caller.get_meta("call_cd",0.0)) >= 5.0, "impact interrupt did not apply cooldown")

    # Let a fresh call complete: nearby infected investigate the scream origin, not omnisciently chase player.
    caller.set_meta("call_cd",0.0)
    caller.set_meta("call_timer",0.0)
    caller.set_meta("call_interrupted",false)
    listener.set_meta("ai_state","idle")
    listener.set_meta("suspicion",0.0)
    listener.set_meta("last_sound_kind","")
    far_listener.set_meta("ai_state","idle")
    far_listener.set_meta("suspicion",0.0)
    far_listener.set_meta("last_sound_kind","")
    check(game._infected_update_special_action(caller,"chase",true,120.0,0.01), "second call did not start")
    var still_locked = game._infected_update_special_action(caller,"chase",true,120.0,1.0)
    check(not still_locked, "completed call kept Screamer locked")
    check(int(caller.get_meta("call_count",0)) == 1, "completed call count incorrect")
    check(float(caller.get_meta("call_cd",0.0)) >= 12.0, "completed call cooldown not applied")
    check(str(listener.get_meta("last_sound_kind","")) == "infected_call", "nearby infected did not hear Screamer")
    check(float(listener.get_meta("suspicion",0.0)) >= 34.0, "Screamer failed to raise nearby suspicion")
    check(str(listener.get_meta("ai_state","")) == "investigate", "nearby infected should investigate call origin")
    check(listener.get_meta("heard_position",Vector2.ZERO).distance_to(caller.global_position) < 0.1, "listener did not investigate Screamer location")
    check(str(far_listener.get_meta("last_sound_kind","")) != "infected_call", "Screamer alerted infected outside call radius")
    check(str(caller.get_meta("last_sound_kind","")) != "infected_call", "Screamer reacted to its own call")

    # Cooldown prevents alarm spam during a sustained chase.
    check(not game._infected_update_special_action(caller,"chase",true,120.0,0.1), "Screamer restarted call during cooldown")
    check(not game._infected_update_special_action(caller,"idle",true,120.0,20.0), "idle Screamer should not call even after cooldown expires")

    chunk.queue_free()
    game.free()
    print("INFECTED VARIETY SCREAMER: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
