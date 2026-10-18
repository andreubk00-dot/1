extends SceneTree
# dev70: fog hides the survivor from the raiders as it hides them from him.
# A raider looking straight at a survivor in the open sees him at 200 px on a
# clear day; in thick fog he does not (the fog wall is nearer than that), at
# arm's length he still does; a lamp glows a little further through the fog;
# the base garrison's sharper eyes are bound by the same wall.
const Main = preload("res://main_script_mod.gd")

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

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(8)
    game.developer_invulnerable = true
    for e in game.get_tree().get_nodes_in_group("infected"):
        e.queue_free()
    var dir = game.marauder_director
    var p = game.player.global_position
    # an open line of 200 px
    var at = Vector2.INF
    for k in range(32):
        var c = p + Vector2(200, 0).rotated(TAU * k / 32.0)
        var q = PhysicsRayQueryParameters2D.create(c, p)
        q.collision_mask = game.LAYER_WORLD
        if dir._free_at(c) and game.get_world_2d().direct_space_state.intersect_ray(q).is_empty():
            at = c
            break
    check(at.x != INF, "no open line near the start")
    var sq = dir.spawn_squad(dir.SQUAD_TYPES[2], at)
    check(sq != null, "no squad")
    if sq == null:
        quit(1)
        return
    var m = sq.members[0]
    m.global_position = at
    m.facing = (p - at).normalized()
    m.state = "patrol"
    game.world_minutes = 12.0 * 60.0
    game.flashlight_on = false

    game._qa_fog = 0.0
    game.fog_density = 0.0
    check(game.fog_sight_limit() == INF, "fog limits sight on a clear day")
    check(m._player_visible(), "a raider does not see a survivor 200 px off in clear daylight")

    game._qa_fog = 0.95
    game.fog_density = 0.95
    check(game.fog_sight_limit() < 200.0, "thick fog still lets eyes carry 200 px: %.0f" % game.fog_sight_limit())
    check(not m._player_visible(), "a raider sees through thick fog")
    # the fog wall is where the survivor stops seeing too: the shader's pocket
    check(abs(game._fog_clear_radius() - lerpf(300.0, 72.0, 0.95)) < 0.01, "sight limit is not tied to the drawn pocket")
    # close in, he sees
    m.global_position = p + (at - p).normalized() * 60.0
    m.facing = (p - m.global_position).normalized()
    check(m._player_visible(), "a raider at arm's length is blind in the fog")
    # a lamp at night glows further than the bare silhouette
    game.world_minutes = 23.0 * 60.0
    check(game.fog_sight_limit(true) > game.fog_sight_limit(false), "a lamp does not show through the fog")
    # the garrison's sharp eyes are bound by the same wall
    m.global_position = at
    m.facing = (p - at).normalized()
    m.sight_mult = 1.35
    game.world_minutes = 12.0 * 60.0
    check(not m._player_visible(), "a sharp-eyed guard sees through thick fog")
    # light fog only shortens sight a little
    game._qa_fog = 0.2
    game.fog_density = 0.2
    check(m._player_visible(), "light mist blinds a raider at 200 px in daylight")
    # inside a high-risk site there is no fog limit
    game._qa_fog = -1.0
    print("FOG MARAUDERS dev70: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
