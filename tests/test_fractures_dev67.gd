extends SceneTree
# dev67: broken bones. A heavy blow breaks an arm or a leg; a broken leg limps
# and cannot run, a broken arm shakes the aim, slows the reload and weakens the
# swing; painkillers take the edge off. A splint item, an improvised splint
# (rigid + binding) or a trauma kit sets the bone; a set bone knits in about a
# day and a half (faster under a roof), a broken one never does. Saved. The
# splint is a full item: icon, ground art, recipe, loot, a trader.
const Main = preload("res://main_script_mod.gd")
const TraderCatalog = preload("res://world/trader_catalog.gd")

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

func _give(game, id: String, qty: int) -> void:
    game._grid_add(game.inventory_entries, id, qty, game.INV_W, game.INV_H)

func _use(game, id: String) -> void:
    for i in range(game.inventory_entries.size()):
        if str(game.inventory_entries[i]["id"]) == id:
            game.selected_inventory_index = i
            game._use_selected_inventory()
            return

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(6)

    # the item is complete
    check(game.item_defs.has("splint") and str(game.item_defs["splint"]["use"]) == "splint", "no splint item")
    check(game.inventory_icon_regions.has("splint") and game._make_item_icon("splint") != null, "the splint has no icon")
    check(game.loot_icon_cells.has("splint") and game._make_world_loot_texture("splint") != null, "the splint has no ground art")
    check(game.recipe_defs.has("splint") and str(game.recipe_defs["splint"]["output"]) == "splint", "the splint cannot be made at a bench")
    var in_loot = 0
    for t in game.loot_tables.keys():
        for rule in game.loot_tables[t]:
            if str(rule.get("id", "")) == "splint":
                in_loot += 1
    check(in_loot >= 3, "the splint is not found in the world")
    check(TraderCatalog.stock_spec("lazaret_supplier", "splint").size() > 0 and TraderCatalog.base_value("splint") > 2, "nobody sells splints")

    # a light blow never breaks a bone; a crushing one can
    game._clear_fractures()
    for i in range(200):
        game.body_condition["legs"] = 100.0
        game._apply_body_injury("legs", 6.0)
    check(int(game.fractures["legs"]) == 0, "a light blow broke a leg")
    var broke = false
    for i in range(80):
        game.body_condition["legs"] = 100.0
        game._apply_body_injury("legs", 34.0)
        if int(game.fractures["legs"]) == 1:
            broke = true
            break
    check(broke, "crushing blows never break a leg")
    check(int(game.fractures["arms"]) == 0, "a blow to the leg broke an arm")
    game._apply_body_injury("torso", 60.0)
    check(not game.fractures.has("torso"), "the torso grew a fracture slot")

    # a broken leg: a limp, no running; painkillers help a little
    game.painkiller_time = 0.0
    game.body_condition = {"head": 100.0, "torso": 100.0, "arms": 100.0, "legs": 100.0}
    var limp = game._injury_move_multiplier()
    check(limp <= 0.56, "a broken leg barely slows: " + str(limp))
    check(not game._injury_can_sprint(), "running on a broken leg")
    game.painkiller_time = 120.0
    check(game._injury_move_multiplier() > limp, "painkillers do nothing for a broken leg")
    game.painkiller_time = 0.0

    # a broken arm: shaky aim, slow reload, weak swing
    game._break_bone("arms")
    check(game._injury_aim_spread_multiplier() >= 1.69, "a broken arm aims steady")
    var base_reload = float(game.weapon_defs["makarov"]["reload"]) * game._rig_reload_multiplier()
    check(game._reload_duration_for_weapon("makarov") > base_reload * 1.4, "a broken arm reloads at full speed")
    check(game._fracture_melee_multiplier() < 0.7, "a broken arm swings as hard")
    check(game._broken_limb() == "legs", "the leg is not splinted first")
    check(game._fracture_summary().find("НОГА") >= 0 and game._fracture_summary().find("РУКА") >= 0, "the HUD does not name the breaks")

    # nothing to splint with: the item use says what is needed
    game.inventory_entries = []
    _give(game, "cloth", 1)
    _use(game, "cloth")
    check(int(game.fractures["legs"]) == 1, "a splint came out of nothing")
    # improvised: firewood + two cloths
    _give(game, "cloth", 1)
    _give(game, "firewood", 1)
    _use(game, "cloth")
    check(int(game.fractures["legs"]) == 2, "an improvised splint did not set the leg")
    check(game._inventory_count("cloth") == 0 and game._inventory_count("firewood") == 0, "the improvised splint did not use its materials")
    check(game.fracture_heal["legs"] > game.FRACTURE_HEAL_MINUTES, "a field splint knits as fast as a proper one")
    check(game._injury_move_multiplier() > limp and not game._injury_can_sprint(), "a splinted leg runs or limps like a broken one")
    # the splint item sets the arm
    _give(game, "splint", 1)
    _use(game, "splint")
    check(int(game.fractures["arms"]) == 2 and game._inventory_count("splint") == 0, "the splint item did not set the arm")
    _give(game, "splint", 1)
    _use(game, "splint")
    check(game._inventory_count("splint") == 1, "a splint was spent with no break to set")

    # the trauma kit sets a break too
    game._clear_fractures()
    game._break_bone("legs")
    game.health = 100.0
    game.pain = 0.0
    _give(game, "trauma_kit", 1)
    _use(game, "trauma_kit")
    check(int(game.fractures["legs"]) == 2, "the trauma kit did not set the break")

    # a broken bone left alone does not mend; a set one knits
    game._clear_fractures()
    game._break_bone("legs")
    game.body_condition["legs"] = 20.0
    game.is_sheltered = true
    game.hunger = 100.0
    game.thirst = 100.0
    for i in range(400):
        game._update_injuries(1.0)
    check(game.body_condition["legs"] <= 35.0, "a broken leg healed without a splint")
    check(int(game.fractures["legs"]) == 1, "a broken leg mended by itself")
    game._set_splint("legs")
    var outdoors_need = game.FRACTURE_HEAL_MINUTES / game.day_speed
    game.is_sheltered = true
    for i in range(int(outdoors_need / 1.5 / 10.0) + 3):
        game._update_fractures(10.0)
    check(int(game.fractures["legs"]) == 0 and game.body_condition["legs"] >= 60.0, "a splinted leg did not knit in time under a roof")

    # saved with the survivor
    game._break_bone("arms")
    game._set_splint("arms")
    var left = float(game.fracture_heal["arms"])
    game._break_bone("legs")
    game._save_state()
    var g2 = Main.new()
    root.add_child(g2)
    await frames(5)
    check(int(g2.fractures["arms"]) == 2 and int(g2.fractures["legs"]) == 1, "breaks lost on reload")
    check(abs(float(g2.fracture_heal["arms"]) - left) < 1.0, "the knitting time lost on reload")
    g2.queue_free()
    await frames(2)
    # clearing (a new survivor) leaves nothing broken
    game._break_bone("legs")
    game._clear_fractures()
    check(game._broken_limb() == "" and game._fracture_summary() == "", "fractures do not clear")

    print("FRACTURES dev67: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
