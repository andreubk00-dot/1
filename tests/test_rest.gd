extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var failures = 0
var checks = 0

func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func fresh():
    var game = Harness.new()
    root.add_child(game)
    return game

func _initialize():
    call_deferred("run")

func run():
    var game = fresh()
    game.add_source("campfire",10.0)
    game.add_source("heater",20.0)
    game._advance_base_time_for_rest(1.0)
    check(not game.base_objects[1]["on"] and game.base_objects[1]["fuel"] == 0.0,"campfire must run out during rest")
    check(is_equal_approx(game.base_objects[2]["fuel"],5.0),"heater must use 15 fuel per game hour")
    game.free()

    game = fresh()
    game.weather_state = "rain"
    game.add_source("campfire",100.0,Vector2(80,0))
    game.base_objects.append({"id":3,"kind":"rain_collector","x":100.0,"y":0.0,"stored_water":0.0})
    game.base_objects.append({"id":4,"kind":"rain_collector","x":0.0,"y":0.0,"stored_water":0.0})
    game._advance_base_time_for_rest(1.0)
    check(is_equal_approx(game.base_objects[1]["fuel"],62.5),"rain must burn outdoor fuel 2.5 times faster")
    check(is_equal_approx(game.base_objects[2]["stored_water"],0.375),"outdoor collector must fill during rest")
    check(game.base_objects[3]["stored_water"] == 0.0,"roof must block rain collection")
    game.base_objects[2]["stored_water"] = 7.99
    game._advance_base_time_for_rest(1.0)
    check(game.base_objects[2]["stored_water"] == 8.0,"collector must not overflow")
    game.free()

    game = fresh()
    game.weather_state = "rain"
    game.weather_timer = 0.5
    game.weather_cycle_index = 3 # Next state is cloudy.
    game.base_objects.append({"id":2,"kind":"rain_collector","x":100.0,"y":0.0,"stored_water":0.0})
    var result = game._simulate_rest(1)
    check(is_equal_approx(game.base_objects[1]["stored_water"],0.0125),"collector must stop at rain boundary inside sleep")
    check(game.weather_state == "cloudy","weather must advance during rest")
    check(is_equal_approx(result["hours"],1.0),"normal sleep must finish requested hour")
    game.free()

    game = fresh()
    game.world_minutes = 23.0 * 60.0 + 30.0
    game.painkiller_time = 2.0
    game.antibiotic_time = 3.0
    game.warm_drink_time = 1.0
    game.well_fed_time = 4.0
    game.add_source("heater",100.0)
    check(is_equal_approx(game._rest_heat_minutes_remaining(),400.0),"fuel forecast must use world clock")
    result = game._simulate_rest(1)
    check(game.world_day == 2 and abs(game.world_minutes - 30.0) < 0.001,"rest must cross midnight once")
    check(game.painkiller_time == 0.0 and game.antibiotic_time == 0.0,"medication must expire during sleep")
    check(game.warm_drink_time == 0.0 and game.well_fed_time == 0.0,"nutrition buffs must expire during sleep")
    check(game.stamina <= game._survival_stamina_cap(),"wake stamina must use final condition")
    game.free()

    game = fresh()
    game.world_minutes = 120.0
    game.weather_state = "rain"
    game.wetness = 100.0
    game.body_temperature = 34.51
    result = game._simulate_rest(8)
    check(result["reason"] == "переохлаждение","wet cold sleep must wake player")
    check(result["hours"] > 0.0 and result["hours"] < 1.0,"unsafe sleep must advance only elapsed time")
    check(game.wetness > 90.0,"interrupted rest cannot grant full eight-hour drying")
    check(game.fatigue > 70.0,"interrupted rest cannot grant full eight-hour recovery")
    game.free()

    var cold = fresh()
    var warm = fresh()
    for g in [cold,warm]:
        g.world_minutes = 120.0
        g.weather_state = "rain"
        g.wetness = 80.0
        g.body_temperature = 35.6
    warm.add_source("heater",1000.0)
    cold._simulate_rest(4)
    warm._simulate_rest(4)
    check(warm.wetness < cold.wetness,"heat must dry clothing faster than an unheated roof")
    check(warm.body_temperature > cold.body_temperature,"maintained heat must improve body temperature")
    cold.free()
    warm.free()

    var short_fire = fresh()
    var long_fire = fresh()
    for g in [short_fire,long_fire]:
        g.world_minutes = 120.0
        g.weather_state = "rain"
        g.wetness = 80.0
        g.body_temperature = 35.6
    short_fire.add_source("heater",1.0)
    long_fire.add_source("heater",1000.0)
    short_fire._simulate_rest(4)
    long_fire._simulate_rest(4)
    check(short_fire.wetness > long_fire.wetness,"expired fuel must not provide a full night of drying")
    check(short_fire.body_temperature < long_fire.body_temperature,"expired fuel must not provide a full night of warming")
    short_fire.free()
    long_fire.free()

    game = fresh()
    game.day_speed = 2.0
    game.add_source("heater",100.0)
    game._simulate_rest(1)
    check(abs(game.base_objects[1]["fuel"] - 70.0) < 0.001,"rest must respect changed world time scale")
    game.free()

    game = fresh()
    game.health = 70.0
    game.wound_infection = 90.0
    game.wound_contamination = 80.0
    game._simulate_rest(1)
    check(game.health < 70.0,"sleep must not heal away systemic infection damage")
    check(game.wound_infection > 90.0,"untreated contaminated wound must progress during sleep")
    game.free()

    game = fresh()
    game.add_source("campfire",100.0)
    var enemy = CharacterBody2D.new()
    game.add_child(enemy)
    enemy.position = Vector2(120,0)
    enemy.add_to_group("infected")
    result = game._simulate_rest(4)
    check(result["reason"] == "рядом заражённые","fire sound must wake player when it alerts nearby infected")
    check(result["hours"] < 1.0,"fire danger must interrupt instead of granting full rest")
    game.free()

    var whole_night = fresh()
    var hourly = fresh()
    whole_night._simulate_rest(8)
    for hour in range(8):
        hourly._simulate_rest(1)
    check(abs(whole_night.wetness - hourly.wetness) < 0.001,"splitting sleep must not change drying")
    check(abs(whole_night.body_temperature - hourly.body_temperature) < 0.001,"splitting sleep must not grant extra warming")
    check(abs(whole_night.hunger - hourly.hunger) < 0.001,"splitting sleep must not change food cost")
    whole_night.free()
    hourly.free()

    game = fresh()
    game.bleeding = true
    check(not game._perform_rest(4) and game.save_calls == 0,"blocked rest must not save or advance time")
    game.bleeding = false
    check(game._perform_rest(1) and game.save_calls == 1,"successful rest must save once")
    check(not game.rest_open and not game.inventory_open,"waking must close rest UI")
    game.free()

    game = fresh()
    game._create_rest_ui()
    game.add_source("heater",120.0)
    game._refresh_rest_ui()
    check(game.rest_status.text.contains("8 ч 00 мин"),"rest panel must show fuel forecast")
    check(game.rest_status.get_minimum_size().x <= 232.0,"rest forecast must fit panel width")
    check(game.rest_status.get_minimum_size().y <= 48.0,"rest forecast must fit panel height")
    game.free()

    print("REST REGRESSION: ",checks," checks, ",failures," failures")
    quit(1 if failures > 0 else 0)
