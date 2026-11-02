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
    # a parked car covers a survivor who stands behind it (north of its body)
    # and lets him draw over it in front
    var car = null
    for c in game.get_tree().get_nodes_in_group("world_cars"):
        if is_instance_valid(c):
            car = c
            break
    check(car != null, "no parked car near the start")
    if car != null:
        game.player.global_position = car.global_position + Vector2(0, -24)
        game._update_car_depth()
        check(car.z_index > game.player.z_index + 2, "a survivor behind a car is drawn over its roof")
        game.player.global_position = car.global_position + Vector2(0, 30)
        game._update_car_depth()
        check(car.z_index < game.player.z_index, "a survivor in front of a car is hidden by it")
    # an infected nearer the camera than the survivor is drawn in front of him
    var inf = null
    for e in game.get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e):
            inf = e
            break
    if inf != null:
        game.player.global_position = inf.global_position + Vector2(0, -20)
        game._update_car_depth()
        check(inf.z_index > game.player.z_index + 3, "an infected in front of the survivor is drawn behind him")
        game.player.global_position = inf.global_position + Vector2(0, 20)
        game._update_car_depth()
        check(inf.z_index < game.player.z_index, "an infected behind the survivor is drawn over him")
    # dev86: an infected behind a parked car is covered by it too
    if car != null and inf != null:
        game.player.global_position = car.global_position + Vector2(0, 260)
        var old_inf = inf.global_position
        inf.global_position = car.global_position + Vector2(0, -24)
        game._update_car_depth()
        check(car.z_index > inf.z_index, "an infected behind a car is drawn over its roof")
        inf.global_position = car.global_position + Vector2(0, 26)
        game._update_car_depth()
        check(car.z_index < inf.z_index, "an infected in front of a car is hidden by it")
        inf.global_position = old_inf
    # dev85: the inventory windows stay off the vitals panel and on the screen
    var vitals = game.hud_world_root.get_node_or_null("VitalsPanel")
    if vitals != null:
        var vb = vitals.position.y + vitals.size.y
        check(game.inventory_panel.position.y >= vb, "the inventory covers the vitals panel (%.0f < %.0f)" % [game.inventory_panel.position.y, vb])
    for panel in [game.inventory_panel, game.equipment_panel]:
        check(panel.position.y + panel.size.y * panel.scale.y <= 360.0, "an inventory window runs off the screen")
    print("COHESION dev84: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
