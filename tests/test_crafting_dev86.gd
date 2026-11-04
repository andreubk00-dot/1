extends SceneTree
# 1.40 crafting II: where (by hand anywhere / at a workbench, one of which can
# be built at home), with what (tools), from what knowledge (schematics found
# in the world); new materials in the loot where they belong; every recipe and
# item whole.
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

func give(game, id: String, qty: int) -> void:
    game._grid_add(game.inventory_entries, id, qty, game.INV_W, game.INV_H)

func clear_inv(game) -> void:
    game.inventory_entries = []

func run():
    var game = Main.new()
    root.add_child(game)
    await frames(10)
    game.developer_invulnerable = true
    # the data holds together
    check(game.recipe_defs.size() >= 30, "only %d recipes" % game.recipe_defs.size())
    var groups = {}
    for rid in game.recipe_defs:
        var r = game.recipe_defs[rid]
        groups[str(r.get("group",""))] = true
        check(str(r.get("group","")) in game.CRAFT_GROUPS, "%s has no group" % rid)
        check(str(r.get("station","")) in ["hand","bench"], "%s has no station" % rid)
        check(game.item_defs.has(str(r.get("output",""))), "%s makes an unknown item" % rid)
        for ing in r.get("ingredients",{}):
            check(game.item_defs.has(str(ing)), "%s needs an unknown %s" % [rid, ing])
        for t in r.get("tools",[]):
            check(game.item_defs.has(str(t)), "%s needs an unknown tool %s" % [rid, t])
        var sch = str(r.get("schematic",""))
        check(sch == "" or game.SCHEMATIC_NAMES.has(sch), "%s needs an unknown schematic %s" % [rid, sch])
    check(groups.size() == game.CRAFT_GROUPS.size(), "a group holds no recipe")
    for topic in game.SCHEMATIC_ITEMS:
        var item = str(game.SCHEMATIC_ITEMS[topic])
        check(game.item_defs.has(item) and str(game.item_defs[item].get("teaches","")) == topic, "schematic item for %s is wrong" % topic)
        var opened = 0
        for rid in game.recipe_defs:
            if str(game.recipe_defs[rid].get("schematic","")) == topic:
                opened += 1
        check(opened >= 2, "%s opens only %d recipes" % [topic, opened])
    for id in ["nails","wire","alcohol","gunpowder","tool_kit","sch_gunsmith","sch_tailor","sch_medic","sch_tech","sch_reload"]:
        check(game._make_item_icon(id) != null and game._make_world_loot_texture(id) != null, "%s has no art" % id)
        var found = false
        for table in game.loot_tables:
            for rule in game.loot_tables[table]:
                if str(rule.get("id","")) == id:
                    found = true
        check(found, "%s turns up nowhere" % id)

    # by hand: a bandage from cloth, but not a bench recipe
    clear_inv(game)
    give(game, "cloth", 2)
    game._open_hand_crafting()
    check(game.crafting_open and game.crafting_station == "hand", "K does not open crafting by hand")
    game.selected_recipe_id = "field_bandage"
    game._craft_selected_recipe()
    check(game._inventory_count("bandage") == 1 and game._inventory_count("cloth") == 0, "a bandage was not made by hand")
    give(game, "scrap", 2)
    give(game, "tape", 1)
    check(not game._can_craft("repair_kit"), "a repair kit is made by hand")
    check(game._recipe_status_text("repair_kit").find("верстак") >= 0, "a bench recipe does not say it wants a bench")
    game._close_crafting()

    # at a bench, with a tool, from knowledge
    game.crafting_station = "bench"
    check(game._can_craft("repair_kit"), "a repair kit cannot be made at a bench")
    give(game, "scrap", 3)
    give(game, "cloth", 1)
    give(game, "tape", 2)
    check(not game._can_craft("suppressor"), "a suppressor without the tool and the schematic")
    give(game, "tool_kit", 1)
    check(not game._can_craft("suppressor"), "a suppressor without the schematic")
    check(game._recipe_status_text("suppressor").find("схема") >= 0, "a locked recipe does not name its schematic")
    # reading the schematic
    give(game, "sch_gunsmith", 1)
    for i in range(game.inventory_entries.size()):
        if str(game.inventory_entries[i].get("id","")) == "sch_gunsmith":
            game.selected_inventory_index = i
    game._use_selected_inventory()
    check(game.known_schematics.has("gunsmith") and game._inventory_count("sch_gunsmith") == 0, "reading a schematic did not teach it")
    check(game._can_craft("suppressor"), "a suppressor cannot be made once known, with tools and parts")
    game.selected_recipe_id = "suppressor"
    game._craft_selected_recipe()
    check(game._inventory_count("suppressor") == 1 and game._inventory_count("tool_kit") == 1, "the suppressor was not made, or the tool was used up")
    # the knowledge is saved
    game._save_state()
    var saved = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
    check(typeof(saved) == TYPE_DICTIONARY and saved.get("known_schematics",{}).has("gunsmith"), "the known schematics are not saved")

    # ammunition is a powder matter
    clear_inv(game)
    game.known_schematics["reload"] = true
    give(game, "tool_kit", 1)
    give(game, "scrap", 2)
    check(not game._can_craft("ammo_9x18"), "rounds without powder")
    give(game, "gunpowder", 1)
    check(game._can_craft("ammo_9x18"), "rounds cannot be made with powder, metal, tool and schematic")

    # a workbench of one's own
    check(game._base_object_name("workbench") == "ВЕРСТАК", "the workbench has no name")
    check(game._base_build_costs("workbench").has("nails"), "the workbench costs nothing")
    var rec = {"id": 999, "kind": "workbench", "x": 0.0, "y": 0.0}
    game.base_objects = [rec]
    game._sanitize_base_objects()
    check(game.base_objects.size() == 1, "a saved workbench is thrown away on load")
    # salvage gives the new materials back
    check(game._salvage_outputs("flashlight").has("wire"), "a flashlight gives no wire back")
    print("CRAFTING dev86: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
