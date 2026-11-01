extends SceneTree
# dev83: an interaction prompt (a door, a crate, anything) lights up only when
# the survivor stands right at the object - measured from the object's own
# footprint, not its centre. A door used to answer from 88 px away.
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

func _place(game, node, local: Vector2) -> void:
    game.player.global_position = node.get_global_transform() * local
    await physics_frame

func _try(game, kind: String) -> void:
    var tried = 0
    for node in get_nodes_in_group("interactable"):
        if str(node.get_meta("interaction_type", "")) != kind or not node.is_visible_in_tree():
            continue
        var box: Rect2 = game._interaction_footprint(node)
        # the open side of the footprint: in front of the object (below it on screen)
        var front = Vector2(box.get_center().x, box.end.y)
        await _place(game, node, front + Vector2(0, game.INTERACT_BODY_RADIUS + 4.0))
        if not game._interactable_reachable(node):
            continue
        tried += 1
        check(game._nearest_interactable() == node, "%s: standing at it, no prompt (gap %.1f)" % [kind, game._interaction_gap(node)])
        await _place(game, node, front + Vector2(0, game.INTERACT_BODY_RADIUS + game.INTERACT_REACH + 14.0))
        check(game._nearest_interactable() != node, "%s: a prompt from %.1f px away" % [kind, game._interaction_gap(node)])
        # the old reach: 60 px from the centre is out of reach now
        await _place(game, node, Vector2(0, 60))
        check(game._nearest_interactable() != node, "%s: a prompt from 60 px off its centre" % kind)
        if tried >= 2:
            break
    check(tried > 0, "no reachable %s in the start sector to try" % kind)

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(20):
        await physics_frame
    game.developer_invulnerable = true
    for kind in ["door", "container"]:
        await _try(game, kind)
    # a footprint is the drawn part of the object, not its sprite's empty margin
    for node in get_nodes_in_group("interactable"):
        if str(node.get_meta("interaction_type", "")) == "container":
            var box: Rect2 = game._interaction_footprint(node)
            check(box.size.x < 48.0 and box.size.y < 48.0, "a crate's footprint is its whole sprite: %s" % box)
            break
    print("INTERACTION REACH dev83: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
