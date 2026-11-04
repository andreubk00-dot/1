extends SceneTree
# Visual QA (1.41): icons in their frames - the quick bar, the backpack grid,
# the worn-equipment slots, a container - with every kind of item.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_icons_capture.gd -- --qa-output=<dir> [--qa-set=N]
const Main = preload("res://main_script_mod.gd")
var output = ""
var set_index = 0
var game = null

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-set="):
            set_index = int(arg.trim_prefix("--qa-set="))
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await process_frame

func snap(name: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("%s/%s.png" % [output, name])

func run():
    game = Main.new()
    root.add_child(game)
    await frames(20)
    game.developer_invulnerable = true
    game.world_minutes = 12.0 * 60.0
    game.inventory_entries = []
    var ids = game.item_defs.keys()
    ids.sort()
    # fill the backpack with a slice of the catalogue
    var start = set_index * 24
    for i in range(start, min(ids.size(), start + 24)):
        var id = str(ids[i])
        if str(game.item_defs[id].get("category", "")) == "strategic":
            continue
        game._grid_add(game.inventory_entries, id, 1, game.INV_W, game.INV_H)
    for g in ["field_backpack", "ballistic_helmet", "military_vest", "insulated_parka", "assault_rig", "flashlight"]:
        game._grid_add(game.inventory_entries, g, 1, game.INV_W, game.INV_H)
        game._equip_item(g)
    for w in ["akm", "mosin", "izh81", "combat_knife", "fire_axe", "makarov"]:
        game._grid_add(game.inventory_entries, w, 1, game.INV_W, game.INV_H)
    game._grid_add(game.inventory_entries, "bandage", 3, game.INV_W, game.INV_H)
    game._grid_add(game.inventory_entries, "water", 1, game.INV_W, game.INV_H)
    game.quick_slot_ids = ["akm", "", "bandage", "combat_knife", "water", "makarov"] if set_index % 2 == 0 else ["mosin", "izh81", "fire_axe", "tool_kit", "canned_meat", ""]
    for i in range(6):
        game._refresh_hud_quick_slot_binding(i)
    game._update_hud()
    await frames(5)
    await snap("hud_%d" % set_index)
    game._toggle_inventory()
    await frames(8)
    await snap("inventory_%d" % set_index)
    quit(0)
