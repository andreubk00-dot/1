extends SceneTree
# dev84: the cohesion pass - things that must agree with each other across
# the game (sizes of people, the prompt's place on screen, ...).
const Main = preload("res://main_script_mod.gd")
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

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(10)
    # people are one size: the survivor, a settlement resident, a raider, an infected
    var survivor_scale = game.SURVIVOR_SPRITE_SCALE * game.PLAYER_VISUAL_SCALE
    var n = Node2D.new()
    game.add_child(n)
    check(game._attach_npc_sprite(n, "resident_a"), "a resident has no sprite")
    var spr = n.get_node_or_null("NpcSprite")
    if spr != null:
        check(abs(spr.scale.x - survivor_scale) < 0.001, "a resident is drawn at %.3f, the survivor at %.3f" % [spr.scale.x, survivor_scale])
        # the feet (row 92 of the cell) stand on the node, as the survivor's do on his
        var feet_y = spr.position.y + (92.0 - 64.0) * spr.scale.y
        check(abs(feet_y) <= 1.0, "a resident's feet float %.1f px off the ground" % feet_y)
    check(abs(Marauder.SPRITE_SCALE - survivor_scale) < 0.001, "a raider is another size")
    check(abs(game.INFECTED_SPRITE_SCALE - survivor_scale) < 0.001, "an infected is another size")
    # the interaction prompt stays clear of the play area: below the survivor's
    # ground, over the quick bar
    check(game.PROMPT_RECT.position.y > 250.0, "the prompt sits in the play area")
    check(game.PROMPT_RECT.size.y <= 14.0, "the prompt is a card again, not a strip")
    # right click on a thing uses it - every hint says "ПКМ по воде"
    game._grid_add(game.inventory_entries, "water", 1, game.INV_W, game.INV_H)
    var wi = -1
    for i in range(game.inventory_entries.size()):
        if str(game.inventory_entries[i].get("id", "")) == "water":
            wi = i
    game.thirst = 40.0
    game._toggle_inventory()
    var ev = InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_RIGHT
    ev.pressed = true
    game._inventory_item_gui_input(ev, wi, "water")
    check(game.thirst > 45.0, "a right click on water did not drink it (thirst %.0f)" % game.thirst)
    game._close_inventory()
    print("COHESION dev84: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
