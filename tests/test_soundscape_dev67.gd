extends SceneTree
# dev67: the world beyond the screen. Every new sound is in place; shooting
# far off, dogs after dusk, wind gusts outdoors, thunder after the lightning
# flash, crows taking off (not a chorus), fires crackling and generators
# humming in loops where people keep them, and the base has the danger score.
const Main = preload("res://main_script_mod.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

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
        await physics_frame

func _loops_under(node: Node, name: String) -> Array:
    var out = []
    for c in node.find_children("*", "AudioStreamPlayer2D", true, false):
        if str(c.get_meta("world_loop", "")) == name:
            out.append(c)
    return out

func run():
    for n in ["dog_bark_1", "dog_bark_2", "dog_bark_3", "crow_1", "crow_2", "fire_loop", "generator_loop",
            "thunder_1", "thunder_2", "thunder_3", "gunfire_far_1", "gunfire_far_2", "gunfire_far_3",
            "gunfire_far_4", "wind_gust_1", "wind_gust_2"]:
        check(ResourceLoader.exists("res://audio/world/%s.wav" % n), "missing sound " + n)

    var game = Main.new()
    root.add_child(game)
    await frames(8)
    game.developer_invulnerable = true
    var sc = game.soundscape
    check(sc != null, "no soundscape")
    game.world_minutes = 12.0 * 60.0
    game.weather_state = "clear"

    # shooting far off
    sc.gunfire_t = 0.0
    await frames(2)
    check(int(sc.heard.get("gunfire_far", 0)) == 1, "no distant gunfire")
    check(sc.gunfire_t > 20.0, "distant gunfire does not wait between volleys")

    # dogs only after dusk
    sc.dogs_t = 0.0
    await frames(3)
    check(int(sc.heard.get("dog_bark", 0)) == 0, "dogs bark at noon")
    game.world_minutes = 23.0 * 60.0
    sc.dogs_t = 0.0
    await frames(150)
    check(int(sc.heard.get("dog_bark", 0)) >= 1, "no dogs at night")

    # wind outdoors only
    var was = int(sc.heard.get("wind_gust", 0))
    sc.wind_t = 0.0
    await frames(2)
    var outdoors_gust = int(sc.heard.get("wind_gust", 0)) - was
    check(outdoors_gust == (0 if game.is_sheltered else 1), "wind gust out of place (sheltered=%s)" % game.is_sheltered)

    # thunder: the flash, then the rumble
    game.world_minutes = 14.0 * 60.0
    game.weather_state = "rain"
    sc.thunder_t = 0.0
    await frames(2)
    check(sc.flash > 0.0 and sc.thunder_pending > 0.0, "no lightning in the rain")
    check(int(sc.heard.get("thunder", 0)) == 0, "thunder came with the flash, not after it")
    await frames(220)
    check(int(sc.heard.get("thunder", 0)) == 1, "no thunder after the lightning")
    check(sc.flash == 0.0, "the flash does not fade")
    game.weather_state = "clear"
    sc.thunder_t = 0.0
    await frames(3)
    check(sc.thunder_pending <= 0.0 and int(sc.heard.get("thunder", 0)) == 1, "thunder in clear weather")

    # crows: one caw for a flock, not a chorus
    var c0 = int(sc.heard.get("crow", 0))
    for i in range(5):
        sc.crows_took_off(game.player.global_position + Vector2(40, 0))
    check(int(sc.heard.get("crow", 0)) == c0 + 1, "a flock caws as a chorus")

    # fires in a settlement crackle, in loops
    var town: Vector2i = RegionCatalog.poi_by_id("settlement_perron").get("coord", Vector2i.ZERO)
    game.player.global_position = Vector2(town) * game.CHUNK_SIZE + Vector2(384, 384)
    game._refresh_chunks(true)
    await frames(10)
    var fires = 0
    var looping = true
    for n in game.get_tree().get_nodes_in_group("settlement_pieces"):
        if str(n.get_meta("settlement_piece_kind", "")) in ["fire_barrel", "bonfire"]:
            var l = _loops_under(n, "fire_loop")
            fires += l.size()
            for p in l:
                if not (p.stream is AudioStreamWAV and p.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD):
                    looping = false
    check(fires >= 1, "no fire crackles in the town")
    check(looping, "a fire's crackle does not loop")

    # the base: generators hum, the score turns to danger
    var base = game.marauder_base
    game.player.global_position = base.world_pos(Vector2i(1, -1), Vector2(384, 384))
    game._refresh_chunks(true)
    await frames(10)
    var hums = 0
    for chunk in game.loaded_chunks.values():
        for n in chunk.get_children():
            if n.has_meta("base_generator"):
                hums += _loops_under(n, "generator_loop").size()
    check(hums >= 1, "the base's generators are silent")
    game._music_site_chunk = Vector2i(999999, 999999)
    check(game._music_mood() == "danger", "the base does not carry the danger score")

    print("SOUNDSCAPE dev67: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
