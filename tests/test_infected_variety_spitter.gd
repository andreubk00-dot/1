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
    check(game.INFECTED_ARCHETYPES.has("spitter"), "Spitter archetype missing")
    var spec = game.INFECTED_ARCHETYPES["spitter"]
    var normal = game.INFECTED_ARCHETYPES["normal"]
    check(str(spec.get("label","")) == "ПЛЕВУН", "Spitter label missing")
    check(str(spec.get("special_role","")) == "spitter", "Spitter special role mismatch")
    check(float(spec.get("hp_mult",9.0)) < float(normal.get("hp_mult",1.0)), "Spitter became a bullet sponge")
    check(float(spec.get("damage",99.0)) < float(normal.get("damage",8.0)), "Spitter melee damage should not be its main threat")
    check(float(spec.get("spit_windup",0.0)) >= 0.60, "Spit needs a readable windup")
    check(float(spec.get("spit_cooldown",0.0)) >= 6.0, "Spit cooldown is too short")
    check(float(spec.get("spit_min_range",0.0)) >= 70.0, "Spitter should not replace melee pressure at point blank")
    check(float(spec.get("spit_max_range",0.0)) >= 240.0, "Spitter ranged threat is too short")
    check(float(spec.get("spit_max_range",0.0)) > float(spec.get("spit_min_range",999.0)), "Spit range band invalid")
    check(float(spec.get("spit_impact_radius",99.0)) <= 30.0, "Spit dodge radius too forgiving for attacker")
    check(float(spec.get("spit_slow_mult",1.0)) <= 0.82, "Spit must create meaningful short mobility pressure")
    check(float(spec.get("spit_slow_time",0.0)) >= 2.0 and float(spec.get("spit_slow_time",0.0)) <= 3.5, "Spit slow duration outside readable tactical window")

    # Dev2 keeps qualitative variants out of generic/open perimeter encounters.
    var standard = _sample_mix(game,"standard",121201,1000)
    var high_perimeter = _sample_mix(game,"high_perimeter",121202,1000)
    var clinical_perimeter = _sample_mix(game,"clinical_perimeter",121203,1000)
    var vector_access = _sample_mix(game,"vector_access",121204,1000)
    check(int(standard.get("spitter",0)) == 0, "Spitter leaked into standard encounters")
    check(int(high_perimeter.get("spitter",0)) == 0, "Spitter leaked onto high-risk perimeter")
    check(int(clinical_perimeter.get("spitter",0)) == 0, "Spitter leaked onto clinical perimeter")
    check(int(vector_access.get("spitter",0)) == 0, "Spitter leaked into Vector access")

    var high_core = _sample_mix(game,"high_core",121205,3000)
    var clinical_core = _sample_mix(game,"clinical_core",121206,3000)
    var vector_core = _sample_mix(game,"vector_core",121207,3000)
    check(int(high_core.get("spitter",0)) > 120 and int(high_core.get("spitter",0)) < 300, "high_core Spitter share outside rare authored band")
    check(int(clinical_core.get("spitter",0)) > 180 and int(clinical_core.get("spitter",0)) < 400, "clinical_core Spitter share outside authored band")
    check(int(vector_core.get("spitter",0)) > 60 and int(vector_core.get("spitter",0)) < 220, "vector_core Spitter share outside rare authored band")
    check(int(clinical_core.get("runner",0)) > int(clinical_core.get("brute",0)), "Clinical runner-heavy identity lost")
    check(int(vector_core.get("brute",0)) > int(vector_core.get("runner",0)), "Vector brute-heavy identity lost")
    check(int(clinical_core.get("spitter",0)) > int(vector_core.get("spitter",0)), "Clinical should expose more ranged-pressure Spitters than tight Vector core")

    var chunk = Node2D.new()
    game.add_child(chunk)
    game.player.global_position = Vector2(420,180)
    var spitter = game._spawn_enemy(chunk,Vector2i(31,31),920,Vector2(180,180),"spitter")
    var ordinary = game._spawn_enemy(chunk,Vector2i(31,31),921,Vector2(250,180),"normal")
    check(str(spitter.get_meta("infected_kind","")) == "spitter", "spawn lost Spitter identity")
    check(str(spitter.get_meta("special_role","")) == "spitter", "spawn lost Spitter role")
    check(float(spitter.get_meta("hp",999.0)) < float(ordinary.get_meta("hp",0.0)), "runtime Spitter tougher than normal")
    check(is_equal_approx(float(spitter.get_meta("spit_min_range",-1.0)),float(spec.get("spit_min_range",0.0))), "runtime minimum range mismatch")
    check(is_equal_approx(float(spitter.get_meta("spit_max_range",-1.0)),float(spec.get("spit_max_range",0.0))), "runtime maximum range mismatch")
    check(is_equal_approx(float(spitter.get_meta("spit_slow_mult",0.0)),float(spec.get("spit_slow_mult",1.0))), "runtime slow multiplier mismatch")
    check(int(spitter.get_meta("spit_count",-1)) == 0, "Spit count not initialized")
    check(not game._infected_is_spitting(spitter), "Spitter starts in windup unexpectedly")

    # Special only starts in a visible chase and within a deliberate distance band.
    check(not game._infected_update_special_action(spitter,"idle",true,200.0,0.01), "idle Spitter started a ranged attack")
    check(not game._infected_update_special_action(spitter,"chase",false,200.0,0.01), "blind Spitter started a ranged attack")
    check(not game._infected_update_special_action(spitter,"chase",true,50.0,0.01), "Spitter fired inside minimum range")
    check(not game._infected_update_special_action(spitter,"chase",true,360.0,0.01), "Spitter fired beyond maximum range")

    spitter.set_meta("spit_cd",0.0)
    game.player.global_position = Vector2(420,180)
    var start_target = game.player.global_position
    var locked = game._infected_update_special_action(spitter,"chase",true,240.0,0.01)
    check(locked, "Spitter did not enter windup at valid range")
    check(game._infected_is_spitting(spitter), "Spitter windup state missing")
    check(float(spitter.get_meta("spit_timer",0.0)) >= 0.60, "Spit windup timer too short")
    check(spitter.get_meta("spit_target",Vector2.ZERO).distance_to(start_target) < 0.1, "Spitter did not lock initial ground target")
    check(int(spitter.get_meta("spit_count",0)) == 0, "Spit fired before windup completed")

    # Moving off the locked point must dodge; the attack must not retarget mid-windup.
    game.player.global_position = Vector2(420,245)
    var health_before_dodge = game.health
    var target_before_finish = spitter.get_meta("spit_target",Vector2.ZERO)
    var still_locked = game._infected_update_special_action(spitter,"chase",true,250.0,1.0)
    check(not still_locked, "completed spit kept movement lock")
    check(spitter.get_meta("spit_target",Vector2.ZERO).distance_to(target_before_finish) < 0.1, "Spit retargeted after player moved")
    check(int(spitter.get_meta("spit_count",0)) == 1, "Spit completion count incorrect")
    check(not bool(spitter.get_meta("spit_last_hit",true)), "Dodged locked-target spit still hit player")
    check(is_equal_approx(game.health,health_before_dodge), "Dodged spit dealt damage")
    check(float(spitter.get_meta("spit_cd",0.0)) >= 7.0, "Successful attack cooldown not applied")
    check(game.infected_spit_slow_time <= 0.0, "Dodged spit applied slow")

    # Cooldown prevents ranged spam.
    check(not game._infected_update_special_action(spitter,"chase",true,220.0,0.1), "Spitter ignored cooldown")

    # Damage interrupts the windup and buys a reaction window.
    spitter.set_meta("spit_cd",0.0)
    game.player.global_position = Vector2(420,180)
    check(game._infected_update_special_action(spitter,"chase",true,240.0,0.01), "interrupt test windup did not start")
    var hp_before = float(spitter.get_meta("hp",0.0))
    game._damage_enemy(spitter,1.0)
    check(float(spitter.get_meta("hp",0.0)) < hp_before, "damage did not reach Spitter")
    check(not game._infected_is_spitting(spitter), "damage failed to interrupt spit")
    check(float(spitter.get_meta("spit_cd",0.0)) >= 3.0, "damage interrupt cooldown too short")
    check(bool(spitter.get_meta("spit_interrupted",false)), "damage interruption flag missing")

    # Stopping power also interrupts without needing lethal damage.
    spitter.set_meta("spit_cd",0.0)
    spitter.set_meta("spit_timer",float(spec.get("spit_windup",0.72)))
    game._apply_enemy_impulse(spitter,Vector2.RIGHT,40.0,0.25)
    check(not game._infected_is_spitting(spitter), "stopping impact failed to interrupt spit")
    check(float(spitter.get_meta("spit_cd",0.0)) >= 3.0, "impact interrupt cooldown not applied")

    # Stationary player on locked point is hit and briefly slowed; slow is transient, not progression.
    spitter.set_meta("stagger",0.0)
    spitter.set_meta("knockback_velocity",Vector2.ZERO)
    spitter.set_meta("spit_cd",0.0)
    game.player.global_position = Vector2(420,180)
    game.health = 100.0
    game.stamina = 100.0
    game.infected_spit_slow_time = 0.0
    game.infected_spit_slow_mult = 1.0
    var baseline_speed = game._current_move_speed()
    check(game._infected_update_special_action(spitter,"chase",true,240.0,0.01), "hit test windup did not start")
    game._infected_update_special_action(spitter,"chase",true,240.0,1.0)
    check(bool(spitter.get_meta("spit_last_hit",false)), "stationary player was not hit by locked spit")
    check(game.health < 100.0 and game.health >= 92.0, "Spit damage outside low-damage control role")
    check(game.stamina < 100.0, "Spit should tax stamina slightly")
    check(game.infected_spit_slow_time >= 2.0, "Spit slow duration missing")
    check(game.infected_spit_slow_mult <= 0.82, "Spit slow multiplier missing")
    check(game._current_move_speed() < baseline_speed * 0.85, "Spit failed to reduce movement speed meaningfully")
    game.infected_spit_slow_time = 0.0
    game.infected_spit_slow_mult = 1.0
    check(is_equal_approx(game._current_move_speed(),baseline_speed), "Spit mobility debuff did not clear cleanly")

    # Developer invulnerability must cover the new ranged attack too.
    game.developer_invulnerable = true
    game.health = 100.0
    game.infected_spit_slow_time = 0.0
    check(not game._apply_infected_spit_hit(spitter), "Developer invulnerability allowed Spitter hit")
    check(is_equal_approx(game.health,100.0) and game.infected_spit_slow_time <= 0.0, "Developer invulnerability did not block Spitter consequences")
    game.developer_invulnerable = false

    # No-aggro must cancel a pending ranged action rather than resume it later.
    spitter.set_meta("spit_cd",0.0)
    spitter.set_meta("spit_timer",float(spec.get("spit_windup",0.72)))
    game._developer_force_enemy_passive(spitter)
    check(not game._infected_is_spitting(spitter), "Developer no-aggro left a pending Spitter windup")
    check(str(spitter.get_meta("ai_state","")) == "idle", "Developer no-aggro did not reset Spitter AI")

    # The two 1.21 roles remain mechanically distinct.
    var caller = game._spawn_enemy(chunk,Vector2i(31,31),922,Vector2(200,260),"screamer")
    check(str(caller.get_meta("special_role","")) == "caller", "Screamer role changed while adding Spitter")
    check(float(caller.get_meta("call_radius",0.0)) > 0.0 and float(caller.get_meta("spit_max_range",0.0)) == 0.0, "Screamer inherited Spitter mechanics")
    check(float(spitter.get_meta("call_radius",0.0)) == 0.0 and float(spitter.get_meta("spit_max_range",0.0)) > 0.0, "Spitter inherited caller mechanics")

    chunk.queue_free()
    game.free()
    print("INFECTED VARIETY SPITTER: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
