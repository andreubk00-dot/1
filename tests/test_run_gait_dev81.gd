extends SceneTree
# dev81: the step keeps pace with the ground. Moving the survivor for real
# (input held), the gait cycles counted must equal the distance covered over
# the stride the sheet takes (world/gait_strides.gd) - at a jog, at a sprint,
# across the screen and toward the camera (where the sprite's ground is drawn
# foreshortened); raiders walk on patrol, jog in a fight and sprint to close.
const Main = preload("res://main_script_mod.gd")
const GaitStrides = preload("res://world/gait_strides.gd")
const Marauder = preload("res://world/marauder.gd")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", msg)

func _initialize():
    call_deferred("run")

func _run_leg(game, actions: Array, secs: float) -> Array:
    # returns [distance, cycles]
    for a in actions:
        Input.action_press(a)
    var start = game.player.global_position
    var last = game.walk_phase
    var cycles = 0.0
    var t = 0.0
    while t < secs:
        await physics_frame
        t += 1.0 / 60.0
        var ph = game.walk_phase
        # signed: on the stop the phase eases back to the nearest contact
        cycles += angle_difference(last, ph) / TAU
        last = ph
    for a in actions:
        Input.action_release(a)
    for i in range(20):
        await physics_frame
    return [game.player.global_position.distance_to(start), cycles]

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(10):
        await physics_frame
    game.developer_invulnerable = true
    # face where the survivor runs (headless, the mouse would aim anywhere and
    # the legs rightly play a strafe or a backpedal)
    game.qa_bot_driver = true
    game.stamina = 100.0
    # open carriageway of the start sector, running east-west and north-south
    for leg in [["move_right"], ["move_right", "sprint"], ["move_down"], ["move_left", "sprint"]]:
        game.player.global_position = Vector2(150, 384) if leg[0] != "move_down" else Vector2(384, 120)
        game.stamina = 100.0
        game.qa_locked_aim = {"move_right": Vector2.RIGHT, "move_left": Vector2.LEFT, "move_down": Vector2.DOWN}[leg[0]]
        await physics_frame
        var res = await _run_leg(game, leg, 1.6)
        var dist: float = res[0]
        var cycles: float = res[1]
        var sprint = leg.has("sprint")
        var gclip = "Run" if sprint else "Jog"
        var stride = float(GaitStrides.SURVIVOR[gclip]) * float(GaitStrides.CADENCE.get(gclip, GaitStrides.CADENCE_EASE))
        if leg[0] == "move_down":
            stride *= GaitStrides.VIEW_YK
        var want = dist / stride
        check(dist > 40.0, "%s: the survivor barely moved (%.1f)" % [leg, dist])
        # the start and the stop ease in and out; allow a little either way
        check(abs(cycles - want) <= max(0.25, want * 0.12), "%s: %.2f gait cycles over %.1f px, the stride wants %.2f" % [leg, cycles, dist, want])
        print("%s: %.1f px, %.2f cycles (%.2f per second)" % [leg, dist, cycles, cycles / 1.6])
        # dev82: a runner's rhythm - about 160-190 steps a minute, never a patter
        var spm = cycles / 1.6 * 120.0 * (dist / max(1.0, dist))
        if leg[0] != "move_down":
            check(spm > 130.0 and spm < 215.0, "%s: %.0f steps a minute is not a runner's cadence" % [leg, spm])

    # --- raiders ---------------------------------------------------------------
    var m = Marauder.new()
    check(m._gait_clip(Vector2(Marauder.WALK_SPEED, 0)) == "Walk", "a patrol does not walk")
    check(m._gait_clip(Vector2(Marauder.COMBAT_SPEED, 0)) == "Jog", "a raider in a fight does not jog")
    check(m._gait_clip(Vector2(Marauder.RUN_SPEED, 0)) == "Run", "a raider closing in does not sprint")
    m.free()
    for o in ["gopnik", "bandit", "deserter"]:
        for w in ["makarov", "akm", "shotgun", "none"]:
            var p = "res://art/marauders/%s_%s_Jog.png" % [o, w]
            check(ResourceLoader.exists(p), "missing " + p)
            if ResourceLoader.exists(p):
                check(load(p).get_width() == 128 * 16, "a jog sheet is not 16 frames: " + p)
    print("RUN GAIT dev81: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
