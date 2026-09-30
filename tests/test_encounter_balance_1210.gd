extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const Floors = preload("res://world/high_risk_floor_catalog.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func _sample_mix(game, profile:String, seed_value:int, samples:int) -> Dictionary:
    var rng = RandomNumberGenerator.new()
    rng.seed = seed_value
    var out = {"normal":0,"runner":0,"brute":0,"screamer":0,"spitter":0,"carrier":0}
    for i in range(samples):
        var kind = game._infected_kind_for_encounter(profile,rng)
        out[kind] = int(out.get(kind,0)) + 1
    return out

func _special_total(mix:Dictionary) -> int:
    return int(mix.get("screamer",0)) + int(mix.get("spitter",0)) + int(mix.get("carrier",0))

func run():
    print("BALANCE TEST START")
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    check(str(ProjectSettings.get_setting("application/config/version","")) == "1.22.0-dev3", "current build version mismatch")

    print("BALANCE HARNESS READY")
    # Ordinary world remains readable: qualitative specials stay authored high-risk content.
    for profile in ["standard","high_perimeter","clinical_perimeter","vector_access"]:
        var mix = _sample_mix(game,profile,121500 + checks,5000)
        check(_special_total(mix) == 0, profile + " leaked qualitative specials")
        check(int(mix.get("normal",0)) > 2500, profile + " baseline bodies no longer dominate recoverable encounter")

    print("BALANCE PERIM DONE")
    # Interior/core pressure is meaningful but avoids chain-special spam.
    var profiles = ["high_interior","high_core","clinical_interior","clinical_core","vector_tunnels","vector_core"]
    var mixes = {}
    for i in range(profiles.size()):
        var profile = profiles[i]
        var mix = _sample_mix(game,profile,121520 + i,10000)
        mixes[profile] = mix
        var specials = _special_total(mix)
        check(specials >= 850, profile + " qualitative pressure too rare")
        check(specials <= 2200, profile + " qualitative pressure became spam")
        check(int(mix.get("normal",0)) >= 2600, profile + " lost baseline recovery bodies")
        check(int(mix.get("screamer",0)) <= 750, profile + " Screamer share too high")
        check(int(mix.get("spitter",0)) <= 1050, profile + " Spitter share too high")
        check(int(mix.get("carrier",0)) <= 750, profile + " Carrier share too high")

    print("BALANCE MIXES DONE")
    check(int(mixes["clinical_core"].get("runner",0)) > int(mixes["clinical_core"].get("brute",0)), "Clinical core lost runner-heavy identity")
    check(int(mixes["vector_core"].get("brute",0)) > int(mixes["vector_core"].get("runner",0)), "Vector core lost brute-heavy identity")
    check(_special_total(mixes["high_core"]) > _special_total(mixes["high_interior"]), "generic core should escalate special pressure")

    print("BALANCE IDENTITY DONE")
    # Archetypes must change tactics without becoming raw-stat walls.
    var normal = game.INFECTED_ARCHETYPES["normal"]
    var runner = game.INFECTED_ARCHETYPES["runner"]
    var brute = game.INFECTED_ARCHETYPES["brute"]
    var screamer = game.INFECTED_ARCHETYPES["screamer"]
    var spitter = game.INFECTED_ARCHETYPES["spitter"]
    var carrier = game.INFECTED_ARCHETYPES["carrier"]
    check(float(runner.get("speed_mult",9.0)) <= 1.18, "Runner speed creates unavoidable sprint race")
    check(float(brute.get("hp_mult",9.0)) <= 1.35, "Brute drifted into bullet sponge")
    check(float(brute.get("stagger_mult",0.0)) >= 0.65, "Brute became excessively immune to stopping power")
    check(float(screamer.get("call_radius",9999.0)) <= 400.0, "Screamer call radius chains too much of a floor")
    check(float(screamer.get("call_cooldown",0.0)) >= 14.0, "Screamer repeat pressure too frequent")
    check(float(spitter.get("spit_max_range",9999.0)) <= 285.0, "Spitter controls too much of a room")
    check(float(spitter.get("spit_slow_mult",0.0)) >= 0.80, "Spitter slow too punitive")
    check(float(carrier.get("cloud_radius",9999.0)) <= 58.0, "Carrier corpse denial too wide")
    check(float(carrier.get("cloud_duration",9999.0)) <= 3.2, "Carrier corpse denial lasts too long")
    check(float(carrier.get("knockback_mult",0.0)) >= 1.20, "Carrier no longer rewards repositioning before kill")

    print("BALANCE ARCH DONE")
    # Upper floors must be dangerous without turning every raid into pure ammo attrition.
    for poi_id in ["quarantine_center_12","reserve_arsenal_bastion","regional_clinical_complex_4","underground_object_vector"]:
        var f2 = Floors.floor(poi_id,2)
        var f3 = Floors.floor(poi_id,3)
        check(int(f2.get("enemy_count",99)) == 10, poi_id + " floor2 attrition budget mismatch")
        check(int(f3.get("enemy_count",99)) == 12, poi_id + " floor3 attrition budget mismatch")
        check(int(f3.get("enemy_count",0)) > int(f2.get("enemy_count",0)), poi_id + " vertical escalation missing")
        check(str(f2.get("enemy_profile","")) != str(f3.get("enemy_profile","")), poi_id + " floor2/floor3 encounter identity collapsed")

    print("BALANCE FLOORS DONE")
    # Weapon roles: stopping power and noise must carry meaningful tradeoffs.
    var w = game.weapon_defs
    check(float(w["makarov"].get("noise",0.0)) < float(w["akm"].get("noise",0.0)), "compact pistol not quieter than AKM")
    check(float(w["pps43"].get("noise",0.0)) < float(w["akm"].get("noise",0.0)), "SMG noise tradeoff missing")
    check(float(w["mosin"].get("noise",0.0)) > float(w["akm"].get("noise",0.0)), "Mosin should carry highest acoustic cost")
    check(game._weapon_stopping_label(w["makarov"]) == "НИЗКАЯ", "PM stopping role drifted")
    check(game._weapon_stopping_label(w["sks"]) == "СРЕДНЯЯ", "SKS stopping role drifted")
    check(game._weapon_stopping_label(w["toz34"]) == "ВЫСОКАЯ", "TOZ stopping role drifted")
    check(float(w["shotgun"].get("impact",0.0)) > float(w["akm"].get("impact",0.0)), "shotgun no longer rewards close stopping power")
    check(float(w["akm"].get("damage",0.0)) > float(w["pps43"].get("damage",0.0)), "rifle/SMG damage identity collapsed")

    print("BALANCE WEAPONS DONE")
    game.free()
    print("ENCOUNTER BALANCE 1.21 STABLE: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
