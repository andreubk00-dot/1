extends SceneTree
# 1.66 (test): the High Risk hazards - every site carries its own, and each
# works: gas chokes, a tripwire walked into blows (crouched it is stepped
# over, cut it gives wire), an alarm walked past sounds (crouched it is
# switched off), a steam vent burns only while it blows.
const Main = preload("res://main_script_mod.gd")
var game
var fails = 0

func _initialize():
    call_deferred("run")

func check(ok: bool, msg: String) -> void:
    if not ok:
        fails += 1
        print("FAIL ", msg)

func site_hazards(id: String) -> Array:
    var out = []
    var poi = game.RegionCatalog.poi_by_id(id)
    var base: Vector2i = poi.get("coord")
    for off in game.PoiCatalog.footprint(id):
        var c = base + off
        game._qa_move_to_world_chunk(c)
        for k in 6: await process_frame
        var ch = game.loaded_chunks.get(c)
        if ch == null:
            continue
        for n in ch.get_children():
            if n.has_meta("hr_hazard"):
                out.append(n)
    return out

func tick(hz, seconds: float) -> void:
    var t = 0.0
    while t < seconds:
        hz._process(0.05)
        t += 0.05

func run():
    Engine.set_meta("ostatok_new_game", true)
    game = Main.new()
    root.add_child(game)
    for i in 10: await process_frame
    game.developer_invulnerable = false
    var kinds = {"quarantine_center_12":"gas","reserve_arsenal_bastion":"tripwire","regional_clinical_complex_4":"alarm","underground_object_vector":"steam"}
    for id in kinds:
        var hz = await site_hazards(id)
        check(hz.size() >= 6, "%s has only %d hazards" % [id, hz.size()])
        for h in hz:
            check(h.kind == kinds[id], "%s carries a %s" % [id, h.kind])
        if hz.is_empty():
            continue
        var h = hz[0]
        game.health = 100.0
        game.is_crouching = false
        match h.kind:
            "gas":
                game.player.global_position = h.global_position
                tick(h, 2.0)
                check(game.health < 99.0, "the gas did not choke (%.1f)" % game.health)
                game.health = 100.0
                game.player.global_position = h.global_position + Vector2(200, 0)
                tick(h, 2.0)
                check(game.health >= 99.9, "the gas reached 200 units out")
            "tripwire":
                var other = hz[1]
                # crouched: stepped over, nothing happens
                game.is_crouching = true
                game.player.global_position = other.global_position + Vector2(other.length * 0.5, -12)
                tick(other, 0.5)
                check(not other.spent and other._fuse < 0.0, "a crouched step set the wire off")
                # cut it
                other.disarm()
                check(other.spent, "the wire could not be cut")
                check(game._inventory_count("wire") >= 1, "no wire from the tripwire")
                # walked into: the pin, the blast
                game.is_crouching = false
                game.player.global_position = h.global_position + Vector2(h.length * 0.5, -12)
                tick(h, 1.0)
                check(h.spent, "walking into the wire did nothing")
                check(game.health < 100.0, "the blast at the wire did not hurt")
            "alarm":
                var other = hz[1]
                game.is_crouching = true
                game.player.global_position = other.global_position + Vector2(0, 26)
                tick(other, 0.3)
                check(other._siren_left <= 0.0, "a crouched approach set the alarm off")
                other.disarm()
                check(other.spent, "the sensor could not be switched off")
                game.is_crouching = false
                game.player.global_position = h.global_position + Vector2(0, 20)
                tick(h, 0.3)
                check(h._siren_left > 0.0, "walking past the sensor did not sound it")
                tick(h, 8.0)
                check(h.spent, "the siren never stopped")
            "steam":
                game.player.global_position = h.global_position
                h._state = "idle"
                h._state_t = 10.0
                tick(h, 1.0)
                check(game.health >= 99.9, "the vent burned while idle")
                h._state = "burst"
                h._state_t = 1.5
                tick(h, 1.0)
                check(game.health < 98.0, "the steam burst did not burn (%.1f)" % game.health)
    print("TEST PASSED" if fails == 0 else "TEST FAILED (%d)" % fails)
    quit(0 if fails == 0 else 1)
