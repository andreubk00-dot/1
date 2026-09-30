extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func _shots_to_kill(hp, damage):
    return int(ceil(float(hp) / max(0.001,float(damage))))

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    # Existing six-gun architecture stays intact; this stage changes combat feel,
    # not the inventory/weapon ownership model.
    var expected = ["makarov","tt33","pps43","shotgun","toz34","izh81","sks","akm","aks74u","mosin"]
    check(game.FIREARM_IDS == expected, "firearm catalogue changed unexpectedly")
    for id in expected:
        check(game.weapon_defs.has(id), "missing firearm: " + id)
        var w = game.weapon_defs[id]
        check(float(w.get("impact",0.0)) > 0.0, "missing firearm impact: " + id)
        check(float(w.get("stagger",0.0)) > 0.0, "missing firearm stagger: " + id)
        check(game._weapon_stopping_label(w) in ["НИЗКАЯ","СРЕДНЯЯ","ВЫСОКАЯ"], "invalid stopping label: " + id)

    var pm = game.weapon_defs["makarov"]
    var tt = game.weapon_defs["tt33"]
    var pump = game.weapon_defs["shotgun"]
    var toz = game.weapon_defs["toz34"]
    var sks = game.weapon_defs["sks"]
    var akm = game.weapon_defs["akm"]

    # Meaningful firearm roles without RPG damage inflation.
    check(_shots_to_kill(70.0,pm.get("damage",0.0)) == 3, "PM should need three body hits on a normal infected")
    check(_shots_to_kill(70.0,tt.get("damage",0.0)) == 2, "TT should earn a two-hit breakpoint")
    check(_shots_to_kill(70.0,sks.get("damage",0.0)) == 2, "SKS should keep a two-hit breakpoint")
    check(_shots_to_kill(70.0,akm.get("damage",0.0)) == 2, "AKM should keep a two-hit breakpoint")
    check(float(toz.get("impact",0.0)) > float(pump.get("impact",0.0)), "TOZ should have the strongest close-range stopping impulse")
    check(float(pump.get("impact",0.0)) > float(sks.get("impact",0.0)), "pump shotgun should stop harder than a single rifle bullet")
    check(float(sks.get("impact",0.0)) > float(pm.get("impact",0.0)), "rifle stopping power should exceed PM")
    check(game._weapon_stopping_label(pm) == "НИЗКАЯ", "PM stopping class mismatch")
    check(game._weapon_stopping_label(sks) == "СРЕДНЯЯ", "SKS stopping class mismatch")
    check(game._weapon_stopping_label(toz) == "ВЫСОКАЯ", "TOZ stopping class mismatch")

    # Physical hit response uses the production stagger/knockback path. One stray
    # shotgun pellet cannot behave like a complete close-range blast.
    var enemy = CharacterBody2D.new()
    game.add_child(enemy)
    enemy.set_meta("stagger",0.0)
    enemy.set_meta("knockback_velocity",Vector2.ZERO)
    enemy.set_meta("stagger_mult",1.0)
    enemy.set_meta("knockback_mult",1.0)
    game._firearm_hit_response(toz,enemy,Vector2.RIGHT,1)
    var graze_stagger = float(enemy.get_meta("stagger",0.0))
    var graze_push = enemy.get_meta("knockback_velocity",Vector2.ZERO).length()
    enemy.set_meta("stagger",0.0)
    enemy.set_meta("knockback_velocity",Vector2.ZERO)
    game._firearm_hit_response(toz,enemy,Vector2.RIGHT,10)
    var full_stagger = float(enemy.get_meta("stagger",0.0))
    var full_push = enemy.get_meta("knockback_velocity",Vector2.ZERO).length()
    check(graze_stagger > 0.0 and graze_stagger < full_stagger * 0.45, "single pellet stagger is too strong")
    check(graze_push > 0.0 and graze_push < full_push * 0.45, "single pellet knockback is too strong")
    check(full_stagger >= 0.54 and full_push >= 140.0, "full TOZ blast lacks close-range stopping power")

    # Brute resistance reuses its existing archetype modifiers and remains partial,
    # not immunity.
    enemy.set_meta("stagger",0.0)
    enemy.set_meta("knockback_velocity",Vector2.ZERO)
    enemy.set_meta("stagger_mult",game.INFECTED_ARCHETYPES["brute"].get("stagger_mult",1.0))
    enemy.set_meta("knockback_mult",game.INFECTED_ARCHETYPES["brute"].get("knockback_mult",1.0))
    game._firearm_hit_response(toz,enemy,Vector2.RIGHT,10)
    var brute_stagger = float(enemy.get_meta("stagger",0.0))
    var brute_push = enemy.get_meta("knockback_velocity",Vector2.ZERO).length()
    check(brute_stagger > 0.25 and brute_stagger < full_stagger, "brute stagger resistance is not meaningful/partial")
    check(brute_push > 80.0 and brute_push < full_push, "brute knockback resistance is not meaningful/partial")
    enemy.queue_free()
    await process_frame

    # Real raycast firing path: impact aggregation must survive the actual physics
    # query and leave a living target staggered instead of being test-helper only.
    var live_enemy = CharacterBody2D.new()
    live_enemy.position = Vector2(90,0)
    live_enemy.collision_layer = game.LAYER_ENEMY
    live_enemy.collision_mask = 0
    live_enemy.set_meta("is_enemy",true)
    live_enemy.set_meta("hp",70.0)
    live_enemy.set_meta("stagger",0.0)
    live_enemy.set_meta("knockback_velocity",Vector2.ZERO)
    live_enemy.set_meta("stagger_mult",1.0)
    live_enemy.set_meta("knockback_mult",1.0)
    live_enemy.set_meta("chunk_coord",Vector2i(99,99))
    live_enemy.set_meta("spawn_id",999)
    var live_shape = CollisionShape2D.new()
    var live_capsule = CapsuleShape2D.new()
    live_capsule.radius = 12.0
    live_capsule.height = 32.0
    live_shape.shape = live_capsule
    live_enemy.add_child(live_shape)
    game.add_child(live_enemy)
    await physics_frame
    game.player.position = Vector2.ZERO
    game.aim_direction = Vector2.RIGHT
    game.inventory_open = false
    game.reload_time = 0.0
    game.fire_cooldown = 0.0
    game.inventory_entries = [{"id":"makarov","qty":1,"x":0,"y":0}]
    game.current_weapon_id = "makarov"
    game.equipped_melee_id = ""
    var live_pm_iid = game.set_test_weapon_state("makarov",1)
    game._switch_weapon("makarov",live_pm_iid)
    if game.tracer == null:
        game.tracer = Line2D.new(); game.add_child(game.tracer)
    if game.muzzle_flash == null:
        game.muzzle_flash = Node2D.new(); game.add_child(game.muzzle_flash)
    game._fire_weapon()
    check(float(live_enemy.get_meta("hp",70.0)) < 70.0, "live firearm raycast did not damage target")
    check(float(live_enemy.get_meta("stagger",0.0)) > 0.0, "live firearm raycast did not apply stagger")
    check(live_enemy.get_meta("knockback_velocity",Vector2.ZERO).length() > 0.0, "live firearm raycast did not apply knockback")
    live_enemy.queue_free()

    # Armor is now anatomical. A helmet protects the head only; a plate carrier
    # protects the torso strongly but does not magically armor legs/head.
    game.equipment = {"head":"ballistic_helmet","body":"","backpack":"","utility":""}
    check(game._armor_value_for_zone("head") >= 0.37, "ballistic helmet head protection too low")
    check(game._armor_value_for_zone("torso") == 0.0, "helmet incorrectly protects torso")
    check(game._armor_value_for_zone("legs") == 0.0, "helmet incorrectly protects legs")
    check(game._damage_after_armor(12.0,"head") < 8.0, "helmet does not materially reduce a heavy head hit")
    check(abs(game._damage_after_armor(12.0,"torso") - 12.0) < 0.001, "helmet reduced torso damage")

    game.equipment = {"head":"","body":"military_vest","backpack":"","utility":""}
    check(game._armor_value_for_zone("torso") >= 0.54, "military vest torso protection too low")
    check(game._armor_value_for_zone("arms") > 0.0 and game._armor_value_for_zone("arms") <= 0.10, "military vest arm coverage should be limited")
    check(game._armor_value_for_zone("legs") == 0.0, "military vest incorrectly protects legs")
    check(game._armor_value_for_zone("head") == 0.0, "military vest incorrectly protects head")
    check(game._damage_after_armor(12.0,"torso") <= 5.5, "military vest should strongly reduce a torso hit")
    check(abs(game._damage_after_armor(12.0,"legs") - 12.0) < 0.001, "vest reduced leg damage")
    check(game._bleed_resistance_for_zone("torso") > game._bleed_resistance_for_zone("arms"), "vest bleed protection should follow coverage")
    check(game._bleed_resistance_for_zone("legs") < game._bleed_resistance_for_zone("arms"), "leg bleed protection should remain weakest")

    # Civilian jackets keep broad but weak coverage instead of becoming obsolete.
    game.equipment = {"head":"","body":"","outerwear":"light_jacket","backpack":"","utility":""}
    check(game._armor_value_for_zone("torso") > game._armor_value_for_zone("arms"), "jacket torso/arm coverage ordering broken")
    check(game._armor_value_for_zone("arms") > game._armor_value_for_zone("legs"), "jacket arm/leg coverage ordering broken")
    check(game._armor_value_for_zone("legs") > 0.0, "civilian jacket should retain slight broad protection")

    # Heavy gear is no longer a pure upgrade. Its speed cost is moderate: walking
    # in the full heavy kit is dangerous, but a healthy sprint can still escape a runner.
    game.equipment = {"head":"ballistic_helmet","body":"military_vest","backpack":"expedition_pack","utility":""}
    var heavy_mult = game._equipment_move_multiplier()
    check(heavy_mult < 0.91 and heavy_mult > 0.88, "full heavy-kit mobility tradeoff outside intended band")
    game.inventory_entries = []
    game.hunger = 100.0
    game.thirst = 100.0
    game.stamina = 100.0
    game.health = 100.0
    game.pain = 0.0
    game.fatigue = 0.0
    game.body_temperature = 37.0
    game.body_condition = {"head":100.0,"torso":100.0,"arms":100.0,"legs":100.0}
    game.is_sprinting = false
    var heavy_walk = game._current_move_speed()
    game.is_sprinting = true
    var heavy_sprint = game._current_move_speed()
    var runner_speed = game.ENEMY_SPEED * float(game.INFECTED_ARCHETYPES["runner"].get("speed_mult",1.0))
    check(heavy_walk < game.ENEMY_SPEED, "heavy kit should make careless walking unsafe")
    check(heavy_sprint > runner_speed, "healthy heavy-kit sprint must still escape the runner")
    check(heavy_sprint - runner_speed >= 3.0, "heavy-kit sprint margin is too unforgiving")

    game.equipment = {"head":"wool_hat","body":"","outerwear":"rain_jacket","backpack":"hiking_backpack","utility":""}
    check(game._equipment_move_multiplier() >= 0.98, "civilian exploration kit is penalized too heavily")

    # Graphical safety: long localized combat/gear tooltips must enlarge their real
    # panel rather than drawing text/footer over each other or outside the frame.
    game._create_hover_inspector()
    game._hover_show_item("military_vest",1,"container")
    check(game.hover_panel.size.y >= 220.0, "military-vest tooltip did not grow for extra stat rows")
    check(game.hover_footer.position.y >= game.hover_body.position.y + game.hover_body.size.y + 4.0, "gear tooltip footer overlaps body")
    check(game.hover_footer.position.y + game.hover_footer.size.y + 4.0 <= game.hover_panel.size.y, "gear tooltip footer leaves panel")
    game._hover_show_item("akm",1,"container")
    check(game.hover_panel.size.y >= 220.0, "AKM tooltip did not reserve enough height")
    check(game.hover_footer.position.y >= game.hover_body.position.y + game.hover_body.size.y + 4.0, "weapon tooltip footer overlaps body")

    # QA crate remains the permanent test surface for the complete catalogue.
    var qa_entries = game._generate_loot("qa:test:combat114","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var qa_ids = {}
    for rec in qa_entries:
        qa_ids[str(rec.get("id",""))] = true
    check(qa_ids.size() == game.item_defs.size(), "QA all-items crate lost catalogue coverage")
    for id in expected:
        check(qa_ids.has(id), "QA crate missing balanced firearm: " + id)

    game.free()
    print("COMBAT & GEAR BALANCE: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
