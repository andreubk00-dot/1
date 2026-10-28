extends SceneTree
# dev75: what a walk through the game turned up.
# - a hint card never sits over the open map / inventory; it waits and returns
# - a warning whose danger has passed (a new survivor after a death) goes
# - the message card fits between the vitals and the weather card
# - every chained dog has its kennel, off the carriageway and clear of doors
const Main = preload("res://main_script_mod.gd")
const DogCatalog = preload("res://world/dog_catalog.gd")

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

func secs(t: float) -> void:
    # the hints run on the game's _process, which in a headless run ticks
    # less often than the physics: wait on the clock, not on frames
    await create_timer(t).timeout

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(8)
    game.developer_invulnerable = true
    var fh = game.field_hints
    fh.enabled = true

    # --- a hint over the map ---------------------------------------------------
    fh.hint("test_card", "Проверка.")
    await secs(0.5)
    check(fh._panel != null and fh._panel.visible and fh._panel.modulate.a > 0.0, "the hint card did not show")
    game._toggle_region_map()
    await secs(0.3)
    check(fh._panel.modulate.a == 0.0, "a hint card sits over the open map")
    var left = fh._time_left
    await secs(0.5)
    check(abs(fh._time_left - left) < 0.001, "a hidden hint kept running down")
    game._toggle_region_map()
    await secs(0.6)
    check(fh._panel.visible and fh._panel.modulate.a > 0.0, "the hint did not come back after the map")

    # --- a stale warning -----------------------------------------------------------
    # (developer invulnerability heals at once - it would clear the danger)
    game.developer_invulnerable = false
    game.health = 10.0
    fh._warn_next.clear()
    fh._check_warnings()
    fh._time_left = 0.0
    await secs(0.5)
    check(fh._panel.visible and str(fh._panel.get_meta("id", "")) == "health", "no low-health warning")
    game.health = 100.0
    await process_frame
    await create_timer(0.6).timeout
    check(not fh._panel.visible or str(fh._panel.get_meta("id", "")) != "health", "the low-health warning outlived the danger")
    game.player_death_time = 1.0
    game.bleeding = true
    fh._warn_next.clear()
    fh._check_warnings()
    check(fh._queue.filter(func(q): return q["warn"]).is_empty(), "warnings queue up while the survivor is dying")
    game.player_death_time = 0.0
    game.bleeding = false
    game.developer_invulnerable = true

    # --- the message card ----------------------------------------------------------
    game._set_survival_feedback("Новый выживший. Ваше тело с вещами лежит там, где вы погибли (метка на карте, M). И ещё немного текста.", 3.0)
    game._update_hud()
    var fp = game.hud_feedback_panel
    var vit = game.hud_world_root.get_node("VitalsPanel")
    var env = game.hud_world_root.get_node("EnvironmentPanel")
    check(fp.position.x >= vit.position.x + vit.size.x and fp.position.x + fp.size.x <= env.position.x, "the message card runs over the side panels: %s .. %s" % [fp.position.x, fp.position.x + fp.size.x])

    # --- kennels ---------------------------------------------------------------------
    for k in DogCatalog.sites():
        var p = k.split(",")
        var c = Vector2i(int(p[0]), int(p[1]))
        game.player.global_position = Vector2(c) * game.CHUNK_SIZE + Vector2(384, 384)
        game._refresh_chunks(true)
        await frames(2)
        var chunk = game.loaded_chunks.get(c, null)
        if chunk == null:
            check(false, "sector %s did not load" % k)
            continue
        var center = Vector2(INF, INF)
        for ch in chunk.get_children():
            if str(ch.get_meta("dog_yard", "")) == k:
                center = ch.position
        check(center.x < INF, "no yard in %s" % k)
        if center.x == INF:
            continue
        var on_asphalt = (center.x > game.DIRT_TRACK_MIN and center.x < game.DIRT_TRACK_MAX) or (center.y > game.DIRT_TRACK_MIN and center.y < game.DIRT_TRACK_MAX)
        check(not on_asphalt, "the yard in %s stands on the carriageway: %s" % [k, center])
        var kennel = false
        for ch in chunk.get_children():
            if str(ch.get_meta("settlement_piece_kind", "")) == "dog_kennel" and ch.position.distance_to(center) < 40.0:
                kennel = true
        check(kennel, "the yard in %s has no kennel" % k)

    print("WALKTHROUGH FIXES dev75: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
