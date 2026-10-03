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
    var result = {"normal":0,"runner":0,"brute":0,"screamer":0,"spitter":0,"carrier":0}
    for i in range(samples):
        var kind = game._infected_kind_for_encounter(profile,rng)
        result[kind] = int(result.get(kind,0)) + 1
    return result

func _hazards(game) -> Array:
    return game.get_tree().get_nodes_in_group("infected_death_hazard")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    check(str(ProjectSettings.get_setting("application/config/version","")) == "1.22.0", "current build version mismatch")
    check(game.INFECTED_ARCHETYPES.has("carrier"), "Carrier archetype missing")
    var spec = game.INFECTED_ARCHETYPES["carrier"]
    var normal = game.INFECTED_ARCHETYPES["normal"]
    check(str(spec.get("label","")) == "НОСИТЕЛЬ", "Carrier label missing")
    check(str(spec.get("special_role","")) == "carrier", "Carrier special role mismatch")
    check(float(spec.get("hp_mult",9.0)) < float(normal.get("hp_mult",1.0)), "Carrier became a bullet sponge")
    check(float(spec.get("damage",99.0)) < float(normal.get("damage",8.0)), "Carrier melee damage should not be its main threat")
    check(float(spec.get("speed_mult",9.0)) < float(normal.get("speed_mult",1.0)), "Carrier should not duplicate Runner speed pressure")
    check(float(spec.get("stagger_mult",0.0)) > 1.0, "Carrier should be easy to interrupt/reposition")
    check(float(spec.get("knockback_mult",0.0)) > 1.0, "Carrier should reward shove/knockback counterplay")
    check(float(spec.get("cloud_delay",0.0)) >= 0.25, "Carrier cloud needs an escape telegraph after death")
    check(float(spec.get("cloud_delay",9.0)) <= 0.60, "Carrier cloud delay is too forgiving")
    check(float(spec.get("cloud_radius",0.0)) >= 45.0 and float(spec.get("cloud_radius",999.0)) <= 75.0, "Carrier cloud radius outside tactical band")
    check(float(spec.get("cloud_duration",0.0)) >= 2.5 and float(spec.get("cloud_duration",0.0)) <= 4.5, "Carrier cloud duration outside short denial window")
    check(float(spec.get("cloud_damage_per_sec",99.0)) <= 2.5, "Carrier cloud should punish positioning, not burst-kill")
    check(float(spec.get("cloud_stamina_per_sec",0.0)) >= 4.0, "Carrier cloud needs meaningful escape pressure")
    check(float(spec.get("cloud_contamination_per_sec",99.0)) <= 6.0, "Carrier cloud contamination pressure too high")

    # Dev3 still keeps all qualitative variants out of generic/open perimeter encounters.
    var standard = _sample_mix(game,"standard",121301,1200)
    var high_perimeter = _sample_mix(game,"high_perimeter",121302,1200)
    var clinical_perimeter = _sample_mix(game,"clinical_perimeter",121303,1200)
    var vector_access = _sample_mix(game,"vector_access",121304,1200)
    check(int(standard.get("carrier",0)) == 0, "Carrier leaked into standard encounters")
    check(int(high_perimeter.get("carrier",0)) == 0, "Carrier leaked onto high-risk perimeter")
    check(int(clinical_perimeter.get("carrier",0)) == 0, "Carrier leaked onto clinical perimeter")
    check(int(vector_access.get("carrier",0)) == 0, "Carrier leaked into Vector access")

    var high_interior = _sample_mix(game,"high_interior",121305,4000)
    var high_core = _sample_mix(game,"high_core",121306,4000)
    var clinical_interior = _sample_mix(game,"clinical_interior",121307,4000)
    var clinical_core = _sample_mix(game,"clinical_core",121308,4000)
    var vector_tunnels = _sample_mix(game,"vector_tunnels",121309,4000)
    var vector_core = _sample_mix(game,"vector_core",121310,4000)
    check(int(high_interior.get("carrier",0)) > 120 and int(high_interior.get("carrier",0)) < 300, "high_interior Carrier share outside rare authored band")
    check(int(high_core.get("carrier",0)) > 150 and int(high_core.get("carrier",0)) < 350, "high_core Carrier share outside rare authored band")
    check(int(clinical_interior.get("carrier",0)) > 120 and int(clinical_interior.get("carrier",0)) < 300, "clinical_interior Carrier share outside authored band")
    check(int(clinical_core.get("carrier",0)) > 150 and int(clinical_core.get("carrier",0)) < 350, "clinical_core Carrier share outside authored band")
    check(int(vector_tunnels.get("carrier",0)) > 120 and int(vector_tunnels.get("carrier",0)) < 300, "vector_tunnels Carrier share outside authored band")
    check(int(vector_core.get("carrier",0)) > 180 and int(vector_core.get("carrier",0)) < 420, "vector_core Carrier share outside authored band")
    check(int(clinical_core.get("runner",0)) > int(clinical_core.get("brute",0)), "Clinical runner-heavy identity lost")
    check(int(vector_core.get("brute",0)) > int(vector_core.get("runner",0)), "Vector brute-heavy identity lost")
    check(int(vector_core.get("carrier",0)) >= int(clinical_core.get("carrier",0)), "Vector should not have less close-quarter Carrier pressure than Clinical core")

    var chunk = Node2D.new()
    game.add_child(chunk)
    game.player.global_position = Vector2(400,200)
    var carrier = game._spawn_enemy(chunk,Vector2i(32,32),930,Vector2(220,200),"carrier")
    var ordinary = game._spawn_enemy(chunk,Vector2i(32,32),931,Vector2(300,200),"normal")
    check(str(carrier.get_meta("infected_kind","")) == "carrier", "spawn lost Carrier identity")
    check(str(carrier.get_meta("special_role","")) == "carrier", "spawn lost Carrier role")
    check(float(carrier.get_meta("hp",999.0)) < float(ordinary.get_meta("hp",0.0)), "runtime Carrier tougher than normal")
    check(float(carrier.get_meta("attack_damage",99.0)) < float(ordinary.get_meta("attack_damage",0.0)), "runtime Carrier melee damage too high")
    check(is_equal_approx(float(carrier.get_meta("cloud_radius",0.0)),float(spec.get("cloud_radius",-1.0))), "runtime cloud radius mismatch")
    check(is_equal_approx(float(carrier.get_meta("cloud_duration",0.0)),float(spec.get("cloud_duration",-1.0))), "runtime cloud duration mismatch")
    check(is_equal_approx(float(carrier.get_meta("cloud_delay",0.0)),float(spec.get("cloud_delay",-1.0))), "runtime cloud delay mismatch")
    check(not bool(carrier.get_meta("carrier_cloud_spawned",true)), "Carrier death cloud starts pre-spawned")
    check(float(carrier.get_meta("call_radius",0.0)) == 0.0, "Carrier inherited Screamer call")
    check(float(carrier.get_meta("spit_max_range",0.0)) == 0.0, "Carrier inherited Spitter ranged attack")
    check(not game._infected_update_special_action(carrier,"chase",true,160.0,0.1), "Carrier incorrectly uses active special windup")

    # Carrier is intentionally more shoveable than a normal infected.
    game._apply_enemy_impulse(carrier,Vector2.RIGHT,100.0,0.25)
    game._apply_enemy_impulse(ordinary,Vector2.RIGHT,100.0,0.25)
    var carrier_push = carrier.get_meta("knockback_velocity",Vector2.ZERO).length()
    var ordinary_push = ordinary.get_meta("knockback_velocity",Vector2.ZERO).length()
    check(carrier_push > ordinary_push, "Carrier does not reward knockback repositioning")
    check(float(carrier.get_meta("stagger",0.0)) > float(ordinary.get_meta("stagger",0.0)), "Carrier does not reward stagger counterplay")

    # Normal infected death must not create a hazard.
    var normal_hp = float(ordinary.get_meta("hp",1.0))
    game._damage_enemy(ordinary,normal_hp + 5.0)
    check(_hazards(game).is_empty(), "normal infected death spawned Carrier cloud")

    # Lethal Carrier damage creates exactly one delayed cloud and still records persistence.
    game.player.global_position = carrier.global_position
    game.health = 100.0
    game.stamina = 100.0
    game.bleeding = false
    game.wound_contamination = 0.0
    var carrier_hp = float(carrier.get_meta("hp",1.0))
    game._damage_enemy(carrier,carrier_hp + 5.0)
    var hazards = _hazards(game)
    check(hazards.size() == 1, "Carrier death did not spawn exactly one cloud")
    check(bool(carrier.get_meta("carrier_cloud_spawned",false)), "Carrier death-spawn guard missing")
    check(bool(game.defeated.get("32:32:930",false)), "Carrier death persistence key missing")
    game._damage_enemy(carrier,10.0)
    check(_hazards(game).size() == 1, "repeated lethal damage duplicated Carrier cloud")

    var cloud = hazards[0]
    check(is_instance_valid(cloud), "Carrier cloud node invalid")
    check(cloud.is_in_group("infected_death_hazard"), "Carrier cloud hazard group missing")
    check(float(cloud.get_meta("cloud_delay",0.0)) >= 0.25, "Carrier cloud armed instantly")
    check(is_equal_approx(float(cloud.get_meta("cloud_radius",0.0)),float(spec.get("cloud_radius",-1.0))), "spawned cloud radius mismatch")
    check(float(cloud.get_meta("cloud_time",0.0)) >= 3.0, "spawned cloud duration too short")

    var hp_before_delay = game.health
    var stamina_before_delay = game.stamina
    game._update_infected_death_hazards(0.20)
    check(is_equal_approx(game.health,hp_before_delay), "Carrier cloud damaged player during warning delay")
    check(is_equal_approx(game.stamina,stamina_before_delay), "Carrier cloud drained stamina during warning delay")
    game._update_infected_death_hazards(0.20)
    check(is_equal_approx(game.health,hp_before_delay), "Carrier cloud damaged on the frame it finished arming")

    # Once armed, staying on the corpse costs health/stamina but does not instantly infect a closed wound.
    game._update_infected_death_hazards(1.0)
    check(game.health < hp_before_delay and game.health > hp_before_delay - 3.0, "Carrier cloud damage outside low-DPS denial role")
    check(game.stamina <= stamina_before_delay - 5.5, "Carrier cloud stamina pressure missing")
    check(is_equal_approx(game.wound_contamination,0.0), "Carrier cloud contaminated a player without an open wound")

    # Existing bleeding wound makes lingering in the cloud medically costly.
    game.bleeding = true
    var contam_before = game.wound_contamination
    game._update_infected_death_hazards(0.5)
    check(game.wound_contamination > contam_before, "Carrier cloud failed to contaminate an open wound")
    check(game.wound_contamination - contam_before <= 3.0, "Carrier cloud contamination spike too large")

    # Leaving the radius is the primary counterplay.
    game.player.global_position = cloud.global_position + Vector2(float(spec.get("cloud_radius",62.0)) + 40.0,0)
    var hp_outside = game.health
    var stamina_outside = game.stamina
    var contam_outside = game.wound_contamination
    game._update_infected_death_hazards(0.5)
    check(is_equal_approx(game.health,hp_outside), "Carrier cloud damaged player outside radius")
    check(is_equal_approx(game.stamina,stamina_outside), "Carrier cloud drained stamina outside radius")
    check(is_equal_approx(game.wound_contamination,contam_outside), "Carrier cloud contaminated wound outside radius")

    # Developer invulnerability covers environmental consequences of the new role.
    game.player.global_position = cloud.global_position
    game.developer_invulnerable = true
    var hp_god = game.health
    var stamina_god = game.stamina
    var contam_god = game.wound_contamination
    game._update_infected_death_hazards(0.5)
    check(is_equal_approx(game.health,hp_god), "Developer invulnerability allowed Carrier cloud damage")
    check(is_equal_approx(game.stamina,stamina_god), "Developer invulnerability allowed Carrier stamina drain")
    check(is_equal_approx(game.wound_contamination,contam_god), "Developer invulnerability allowed Carrier contamination")
    game.developer_invulnerable = false

    # Cloud is transient combat state and cleans itself up.
    game._update_infected_death_hazards(5.0)
    check(cloud.is_queued_for_deletion(), "Carrier cloud did not expire")
    await process_frame
    check(_hazards(game).is_empty(), "expired Carrier cloud remained in scene tree")

    # The three 1.21 roles remain mechanically disjoint.
    var screamer = game._spawn_enemy(chunk,Vector2i(32,32),932,Vector2(160,260),"screamer")
    var spitter = game._spawn_enemy(chunk,Vector2i(32,32),933,Vector2(240,260),"spitter")
    check(str(screamer.get_meta("special_role","")) == "caller", "Screamer role changed while adding Carrier")
    check(str(spitter.get_meta("special_role","")) == "spitter", "Spitter role changed while adding Carrier")
    var carrier2 = game._spawn_enemy(chunk,Vector2i(32,32),934,Vector2(320,260),"carrier")
    check(float(screamer.get_meta("cloud_radius",0.0)) == 0.0, "Screamer inherited Carrier cloud")
    check(float(spitter.get_meta("cloud_radius",0.0)) == 0.0, "Spitter inherited Carrier cloud")
    check(float(carrier2.get_meta("call_radius",0.0)) == 0.0 and float(carrier2.get_meta("spit_max_range",0.0)) == 0.0, "Carrier inherited an active 1.21 special")

    chunk.queue_free()
    game.free()
    print("INFECTED VARIETY CARRIER: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
