extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _shots_to_kill(hp, per_trigger_damage):
    if per_trigger_damage <= 0.0:
        return 999
    return int(ceil(float(hp) / float(per_trigger_damage)))

func _full_trigger_damage(cfg):
    return float(cfg.get("damage",0.0)) * max(1,int(cfg.get("pellets",1)))

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    var runner_hp = 70.0 * float(game.INFECTED_ARCHETYPES["runner"].get("hp_mult",1.0))
    var normal_hp = 70.0
    var brute_hp = 70.0 * float(game.INFECTED_ARCHETYPES["brute"].get("hp_mult",1.0))

    var pps = game.weapon_defs["pps43"]
    var izh = game.weapon_defs["izh81"]
    var aksu = game.weapon_defs["aks74u"]
    var mosin = game.weapon_defs["mosin"]
    var akm = game.weapon_defs["akm"]
    var base_shotgun = game.weapon_defs["shotgun"]

    # Intentional body-shot breakpoints against the three current infected archetypes.
    check(_shots_to_kill(runner_hp,float(pps.get("damage",0.0))) == 2,"PPS-43 runner breakpoint drifted")
    check(_shots_to_kill(normal_hp,float(pps.get("damage",0.0))) == 3,"PPS-43 normal breakpoint drifted")
    check(_shots_to_kill(brute_hp,float(pps.get("damage",0.0))) == 4,"PPS-43 brute breakpoint drifted")

    check(_shots_to_kill(runner_hp,float(aksu.get("damage",0.0))) == 2,"AKS-74U runner breakpoint drifted")
    check(_shots_to_kill(normal_hp,float(aksu.get("damage",0.0))) == 2,"AKS-74U normal breakpoint drifted")
    check(_shots_to_kill(brute_hp,float(aksu.get("damage",0.0))) == 3,"AKS-74U brute breakpoint drifted")

    check(_shots_to_kill(runner_hp,float(mosin.get("damage",0.0))) == 1,"Mosin must reward a clean runner hit")
    check(_shots_to_kill(normal_hp,float(mosin.get("damage",0.0))) == 1,"Mosin must one-shot a normal infected on clean body hit")
    check(_shots_to_kill(brute_hp,float(mosin.get("damage",0.0))) == 2,"Mosin must not erase brute durability in one body hit")

    # Shotgun comparison is a close-range all-pellet ceiling, not guaranteed damage at range.
    var izh_full = _full_trigger_damage(izh)
    var base_full = _full_trigger_damage(base_shotgun)
    check(_shots_to_kill(brute_hp,izh_full) == 1,"IZH-81 lost close-range stopping identity")
    check(izh_full <= base_full,"IZH-81 became a strict damage upgrade over base shotgun")
    check(float(izh.get("spread",0.0)) < float(base_shotgun.get("spread",0.0)),"IZH-81 precision tradeoff missing")
    check(float(izh.get("interval",0.0)) > float(base_shotgun.get("interval",0.0)),"IZH-81 deliberate pump cost missing")

    # Automatic weapons should overlap in raw sustained DPS but separate by handling costs.
    var pps_dps = float(pps.get("damage",0.0)) / float(pps.get("interval",1.0))
    var aksu_dps = float(aksu.get("damage",0.0)) / float(aksu.get("interval",1.0))
    var akm_dps = float(akm.get("damage",0.0)) / float(akm.get("interval",1.0))
    check(abs(pps_dps - akm_dps) / akm_dps < 0.08,"PPS-43 automatic DPS left intended band")
    check(abs(aksu_dps - akm_dps) / akm_dps < 0.08,"AKS-74U automatic DPS left intended band")
    check(float(pps.get("range",0.0)) < float(aksu.get("range",0.0)) and float(aksu.get("range",0.0)) < float(akm.get("range",0.0)),"automatic range ladder broken")
    check(float(pps.get("spread",0.0)) > float(aksu.get("spread",0.0)) and float(aksu.get("spread",0.0)) > float(akm.get("spread",0.0)),"automatic stability ladder broken")
    check(float(pps.get("noise",0.0)) < float(aksu.get("noise",0.0)) and float(aksu.get("noise",0.0)) < float(akm.get("noise",0.0)),"automatic noise ladder broken")

    # Ammo burden is part of capability cost: the hardest-hitting rifle ammunition is heaviest.
    check(float(game.item_defs["ammo_545"].get("weight",0.0)) < float(game.item_defs["ammo_762"].get("weight",0.0)),"5.45 carry advantage missing")
    check(float(game.item_defs["ammo_762"].get("weight",0.0)) < float(game.item_defs["ammo_762x54r"].get("weight",0.0)),"7.62R carry cost missing")
    check(float(game.item_defs["mosin"].get("weight",0.0)) > float(game.item_defs["aks74u"].get("weight",0.0)),"Mosin power lacks carry-weight cost")

    # Discovery-first remains a hard rule: role/balance data may exist internally but UI text must not expose sources.
    var source_leaks = ["spawn chance","шанс выпадения","ищи в","добывается в","loot source"]
    var ui_text = (game._entry_description({"id":"pps43","qty":1}) + " " + game._entry_description({"id":"mosin","qty":1})).to_lower()
    for leak in source_leaks:
        check(ui_text.find(leak) == -1,"item description leaks acquisition guidance: " + leak)

    game.free()
    print("ARSENAL COMBAT ROLES: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
